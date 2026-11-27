import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingEnvironment { detecting, outdoor, indoor }

class ClassifierEvent {
  final TrackingEnvironment environment;
  final String reason;
  final double confidence;
  final bool fallbackSuggested;

  const ClassifierEvent(
    this.environment,
    this.reason, {
    this.confidence = 0.0,
    this.fallbackSuggested = false,
  });
}

const int _kMinWindowSize = 3;
const int _kWindowSize = 10;
const Duration _kGpsBlackoutThreshold = Duration(seconds: 8);
const int _kMinStepsDuringGpsBlackout = 10;

/// Probabilistic GPS + Pedometer Indoor/Outdoor Classifier with Causal 2-State HMM.
///
/// Replaces ad-hoc linear score weights with peer-reviewed formulations:
/// 1. Continuous sigmoid GNSS accuracy & speed likelihoods:
///    Bui et al. (Applied Sciences 2020, 10(2), 500, doi:10.3390/app10020500) and
///    Dastagir et al. (DeepIOD, Sensors 2024, 24(16), 5125, doi:10.3390/s24165125).
/// 2. Path Straightness Index S = d_net / max(d_path, 1.0) in [0, 1]:
///    Benhamou (Journal of Theoretical Biology 2004, 229(2), 209–220,
///    doi:10.1016/j.jtbi.2004.03.016).
/// 3. Confidence-weighted multi-cue emission fusion:
///    Li et al. (IODetector, ACM TOSN 2014, 11(2), 28, doi:10.1145/2659466).
/// 4. Causal 2-state Hidden Markov Model forward filter:
///    Zhu et al. (Sensors 2019, 19(4), 786, doi:10.3390/s19040786).
class EnvironmentClassifier {
  EnvironmentClassifier({required this.activityType});

  final String activityType;
  final _window = Queue<Position>();
  int _stepsDeltaSinceLastEval = 0;
  int _stepsDuringGpsSilence = 0;
  DateTime? _lastPositionTimestamp;
  DateTime? _firstStepWithoutGpsAt;
  TrackingEnvironment _hint = TrackingEnvironment.detecting;
  final _controller = StreamController<ClassifierEvent>.broadcast();

  // Causal 2-state HMM posterior belief: P(Outdoor | o_{1:t})
  double _alphaIndoor = 0.5;
  double _alphaOutdoor = 0.5;

  Stream<ClassifierEvent> get stateStream => _controller.stream;
  TrackingEnvironment get currentState => _hint;

  void addPosition(Position p) {
    if (_controller.isClosed) return;

    _lastPositionTimestamp = p.timestamp;
    _stepsDuringGpsSilence = 0;
    _firstStepWithoutGpsAt = null;

    _window.addLast(p);
    if (_window.length > _kWindowSize) _window.removeFirst();

    if (_window.length < _kMinWindowSize) {
      _emit(
        TrackingEnvironment.detecting,
        'warming_up samples=${_window.length}',
        confidence: 0.0,
      );
      return;
    }

    _evaluate();
  }

  void addStepDelta(int delta, {DateTime? now}) {
    if (delta <= 0 || _controller.isClosed) return;
    _stepsDeltaSinceLastEval += delta;

    // iOS CoreLocation blackout gate: inside deep indoor structures or gyms,
    // CLLocationManager can stop emitting fixes altogether. When GPS has been
    // silent >= 8s while verified pedometer steps accumulate, update the causal
    // HMM with strong indoor emission without waiting for a 3rd GPS fix.
    final evalNow = now ?? DateTime.now();
    final lastPosAt = _lastPositionTimestamp;
    if (lastPosAt == null) {
      _firstStepWithoutGpsAt ??= evalNow;
      _stepsDuringGpsSilence += delta;
      final silence = evalNow.difference(_firstStepWithoutGpsAt!);
      if (!silence.isNegative &&
          silence >= _kGpsBlackoutThreshold &&
          _stepsDuringGpsSilence >= _kMinStepsDuringGpsBlackout) {
        final pOut = _stepHmm(0.06, strongSignal: true);
        _emit(
          TrackingEnvironment.indoor,
          'gps_unacquired_active_steps silence=${silence.inSeconds}s '
          'steps=$_stepsDuringGpsSilence pOut=${pOut.toStringAsFixed(2)}',
          confidence: ((0.5 - pOut).abs() * 2.0).clamp(0.65, 1.0),
          fallbackSuggested: true,
        );
        _stepsDuringGpsSilence = 0;
        _firstStepWithoutGpsAt = evalNow;
      }
    } else {
      final outage = evalNow.difference(lastPosAt);
      if (!outage.isNegative && outage >= _kGpsBlackoutThreshold) {
        _stepsDuringGpsSilence += delta;
        if (_stepsDuringGpsSilence >= _kMinStepsDuringGpsBlackout) {
          final pOut = _stepHmm(0.05, strongSignal: true);
          _emit(
            TrackingEnvironment.indoor,
            'gps_blackout_active_steps outage=${outage.inSeconds}s '
            'steps=$_stepsDuringGpsSilence pOut=${pOut.toStringAsFixed(2)}',
            confidence: ((0.5 - pOut).abs() * 2.0).clamp(0.70, 1.0),
            fallbackSuggested: true,
          );
          _stepsDuringGpsSilence = 0;
        }
      } else {
        _stepsDuringGpsSilence = 0;
      }
    }
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }

  void _evaluate() {
    final metrics = _computeMetrics();
    final activity = activityType.toLowerCase();

    final accMidpoint = _accuracyInflectionMeters(activity);
    final outdoorDisplacement = _outdoorMinDisplacement(activity);
    final outdoorSpeed = _outdoorMinSpeed(activity);
    final indoorAccuracy = _indoorMinAccuracy(activity);
    final indoorDisplacement = _indoorMaxDisplacement(activity);

    // 1. Continuous sigmoid GNSS horizontal accuracy likelihood (Bui 2020 / DeepIOD 2024)
    final pAccOut = _sigmoid(-0.14 * (metrics.avgAccuracy - accMidpoint));

    // 2. Kinematic displacement & speed likelihoods
    final pDispOut = _sigmoid(
      0.35 * (metrics.netDisplacement - 0.5 * (outdoorDisplacement + indoorDisplacement)),
    );
    final pSpeedOut = _sigmoid(2.2 * (metrics.avgSpeed - outdoorSpeed));

    // 3. Benhamou (2004) Straightness Index S = d_net / max(d_path, 1.0) in [0, 1]
    final pStraightOut = _sigmoid(5.0 * (metrics.straightnessIndex - 0.35));

    // 4. Confidence-weighted multi-cue emission (IODetector, Li et al. 2014)
    var weightedSum =
        0.45 * pAccOut +
        0.25 * pDispOut +
        0.15 * pSpeedOut +
        0.15 * pStraightOut;
    var totalWeight = 1.0;

    // Pedometer–GPS kinematic discordance: active steps without spatial GPS displacement
    final fallbackSuggested =
        metrics.avgAccuracy >= indoorAccuracy &&
        metrics.netDisplacement <= indoorDisplacement &&
        metrics.stepsIncreasing;
    if (fallbackSuggested) {
      weightedSum += 0.45 * 0.05;
      totalWeight += 0.45;
    }

    final emissionOutdoor = (weightedSum / totalWeight).clamp(0.02, 0.98);
    final strongCue = (emissionOutdoor - 0.5).abs() >= 0.30;
    final pPostOut = _stepHmm(emissionOutdoor, strongSignal: strongCue);

    final nextHint = pPostOut >= 0.5
        ? TrackingEnvironment.outdoor
        : TrackingEnvironment.indoor;
    final confidence = ((pPostOut - 0.5).abs() * 2.0).clamp(0.0, 1.0);
    final reason =
        'hmm_pOut=${pPostOut.toStringAsFixed(2)} '
        'acc=${metrics.avgAccuracy.toStringAsFixed(1)}m '
        'disp=${metrics.netDisplacement.toStringAsFixed(1)}m '
        'S=${metrics.straightnessIndex.toStringAsFixed(2)} '
        'speed=${metrics.avgSpeed.toStringAsFixed(2)}m/s '
        'steps=$_stepsDeltaSinceLastEval';

    _emit(
      nextHint,
      reason,
      confidence: confidence,
      fallbackSuggested: fallbackSuggested,
    );
    _stepsDeltaSinceLastEval = 0;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x.clamp(-20.0, 20.0)));

  /// Causal 2-state HMM forward filter (Zhu et al. 2019, Sensors 19(4), 786).
  double _stepHmm(double emissionOutdoor, {required bool strongSignal}) {
    final bOut = emissionOutdoor.clamp(0.02, 0.98);
    final bIn = 1.0 - bOut;
    final pStayOut = strongSignal ? 0.90 : 0.97;
    final pStayIn = strongSignal ? 0.90 : 0.97;

    final predIn = _alphaIndoor * pStayIn + _alphaOutdoor * (1.0 - pStayOut);
    final predOut = _alphaIndoor * (1.0 - pStayIn) + _alphaOutdoor * pStayOut;
    _alphaIndoor = predIn * bIn;
    _alphaOutdoor = predOut * bOut;
    final norm = _alphaIndoor + _alphaOutdoor;
    if (norm > 0) {
      _alphaIndoor /= norm;
      _alphaOutdoor /= norm;
    } else {
      _alphaIndoor = 0.5;
      _alphaOutdoor = 0.5;
    }
    return _alphaOutdoor;
  }

  void _emit(
    TrackingEnvironment environment,
    String reason, {
    required double confidence,
    bool fallbackSuggested = false,
  }) {
    if (_controller.isClosed) return;
    final changed = environment != _hint;
    _hint = environment;
    if (changed || kDebugMode) {
      debugPrint(
        '[Classifier] hint=$environment confidence=${confidence.toStringAsFixed(2)} '
        'fallbackSuggested=$fallbackSuggested $reason',
      );
    }
    _controller.add(
      ClassifierEvent(
        environment,
        reason,
        confidence: confidence,
        fallbackSuggested: fallbackSuggested,
      ),
    );
  }

  _WindowMetrics _computeMetrics() {
    final pts = _window.toList();
    final netDisplacement = Geolocator.distanceBetween(
      pts.first.latitude,
      pts.first.longitude,
      pts.last.latitude,
      pts.last.longitude,
    );

    double totalPath = 0;
    double totalSpeed = 0;
    double totalAccuracy = 0;

    for (int i = 0; i < pts.length; i++) {
      totalAccuracy += pts[i].accuracy;
      totalSpeed += pts[i].speed.clamp(0.0, 50.0);
      if (i > 0) {
        totalPath += Geolocator.distanceBetween(
          pts[i - 1].latitude,
          pts[i - 1].longitude,
          pts[i].latitude,
          pts[i].longitude,
        );
      }
    }

    // Benhamou (2004) Straightness Index S = d_net / max(d_path, 1.0) in [0, 1]
    final straightness =
        (netDisplacement / math.max(totalPath, 1.0)).clamp(0.0, 1.0);

    return _WindowMetrics(
      netDisplacement: netDisplacement,
      totalPath: totalPath,
      avgAccuracy: totalAccuracy / pts.length,
      avgSpeed: totalSpeed / pts.length,
      straightnessIndex: straightness,
      stepsIncreasing: _stepsDeltaSinceLastEval > 2,
    );
  }

  double _accuracyInflectionMeters(String activity) {
    if (kDebugLocationMode) return 55.0;
    switch (activity) {
      case 'walking':
        return 30.0;
      case 'running':
        return 26.0;
      case 'cycling':
        return 22.0;
      default:
        return 26.0;
    }
  }

  double _outdoorMinDisplacement(String activity) {
    if (kDebugLocationMode) return 2.0;
    switch (activity) {
      case 'walking':
        return 6.0;
      case 'running':
        return 10.0;
      case 'cycling':
        return 18.0;
      default:
        return 8.0;
    }
  }

  double _outdoorMinSpeed(String activity) {
    if (kDebugLocationMode) return 0.15;
    switch (activity) {
      case 'walking':
        return 0.35;
      case 'running':
        return 0.85;
      case 'cycling':
        return 1.8;
      default:
        return 0.5;
    }
  }

  double _indoorMinAccuracy(String activity) {
    switch (activity) {
      case 'walking':
        return 45.0;
      case 'running':
        return 40.0;
      case 'cycling':
        return 35.0;
      default:
        return 40.0;
    }
  }

  double _indoorMaxDisplacement(String activity) {
    switch (activity) {
      case 'walking':
        return 5.0;
      case 'running':
        return 6.5;
      case 'cycling':
        return 10.0;
      default:
        return 6.0;
    }
  }
}

class _WindowMetrics {
  final double netDisplacement;
  final double totalPath;
  final double avgAccuracy;
  final double avgSpeed;
  final double straightnessIndex;
  final bool stepsIncreasing;

  const _WindowMetrics({
    required this.netDisplacement,
    required this.totalPath,
    required this.avgAccuracy,
    required this.avgSpeed,
    required this.straightnessIndex,
    required this.stepsIncreasing,
  });
}
