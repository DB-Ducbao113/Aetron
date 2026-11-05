import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';

/// Probabilistic transition detection algorithm from:
/// *Seamless Indoor–Outdoor Localization Through Transition Detection*
/// (Yoo, Electronics 2025, 14(13), 2598; DOI: 10.3390/electronics14132598).
///
/// Models environmental boundaries explicitly by evaluating:
/// 1. GNSS Carrier-to-Noise density ratio (C/N0 in dB-Hz).
/// 2. Active satellite count used in positioning fix.
/// 3. Motion continuity (pedometer step deltas and acceleration dynamics).
///
/// Output classifies states into:
/// - [IndoorOutdoorState.outdoor]: Direct line-of-sight GNSS.
/// - [IndoorOutdoorState.indoor]: Deeply obstructed signals.
/// - [IndoorOutdoorState.transition]: Boundary zone (building entrance, doorway,
///   threshold, covered porch, bridge underpass).
class SeamlessTransitionDetector {
  static const String modelVersion = 'yoo-transition-2025-v1.0';

  // Physical GNSS boundaries from Yoo (2025)
  static const double kCn0OutdoorMinDbHz = 28.0;
  static const double kCn0IndoorMaxDbHz = 20.0;
  static const int kMinSatellitesOutdoor = 5;
  static const int kMaxSatellitesIndoor = 2;

  // Historical memory for tracking signal gradients across epochs
  double? _lastTop4Cn0;
  int? _lastUsedSatCount;

  void reset() {
    _lastTop4Cn0 = null;
    _lastUsedSatCount = null;
  }

  /// Evaluates transition state probability for a 1 Hz snapshot.
  IodPrediction evaluate(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    final Map<String, bool> availability = {
      'gnss_status': snapshot.hasGnssStatus,
      'gps': snapshot.hasGpsFix,
      'imu': snapshot.hasImuData,
    };

    if (!snapshot.hasGnssStatus && !snapshot.hasGpsFix) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_gnss_or_gps_data',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    // 1. Compute Base Probabilities from Satellite Metrics
    final currentCn0 = snapshot.top4Cn0DbHz ??
        _estimateCn0FromAccuracy(snapshot.horizontalAccuracy);
    final currentSatUsed = snapshot.usedInFixCount ??
        (snapshot.hasGpsFix ? 4 : 0);

    final double pOutdoor;
    final double pIndoor;
    final double pTransition;

    if (currentCn0 >= kCn0OutdoorMinDbHz &&
        currentSatUsed >= kMinSatellitesOutdoor) {
      // Strong GNSS line-of-sight -> High probability Outdoor
      pOutdoor = 0.85;
      pIndoor = 0.05;
      pTransition = 0.10;
    } else if (currentCn0 <= kCn0IndoorMaxDbHz || currentSatUsed <= kMaxSatellitesIndoor) {
      // Heavily attenuated or zero GNSS -> High probability Indoor
      pOutdoor = 0.05;
      pIndoor = 0.85;
      pTransition = 0.10;
    } else {
      // Intermediate signal region: 20 <= C/N0 < 28 or 3-4 satellites
      // Evaluate signal gradient + motion continuity
      double transitionBoost = 0.40;

      // Check if user is actively walking (motion continuity)
      final isMoving = snapshot.stepDelta > 0 ||
          (snapshot.speed != null && snapshot.speed! > 0.4);

      if (isMoving) {
        transitionBoost += 0.20;
      }

      // Check for rapid signal drop or surge (entering or exiting a building)
      if (_lastTop4Cn0 != null) {
        final cn0Delta = (currentCn0 - _lastTop4Cn0!).abs();
        if (cn0Delta >= 4.0) {
          transitionBoost += 0.15;
        }
      }

      // Check for abrupt change in used satellites
      if (_lastUsedSatCount != null) {
        final satDelta = (currentSatUsed - _lastUsedSatCount!).abs();
        if (satDelta >= 2) {
          transitionBoost += 0.10;
        }
      }

      pTransition = transitionBoost.clamp(0.0, 0.90);
      final remaining = 1.0 - pTransition;
      final normalizedCn0 = (currentCn0 - kCn0IndoorMaxDbHz) /
          (kCn0OutdoorMinDbHz - kCn0IndoorMaxDbHz);
      pOutdoor = (remaining * normalizedCn0).clamp(0.0, 1.0);
      pIndoor = (remaining * (1.0 - normalizedCn0)).clamp(0.0, 1.0);
    }

    // Update gradient history
    _lastTop4Cn0 = currentCn0;
    _lastUsedSatCount = currentSatUsed;

    // Determine leading state
    final IndoorOutdoorState state;
    final double confidence;

    if (pTransition >= 0.50) {
      state = IndoorOutdoorState.transition;
      confidence = pTransition;
    } else if (pOutdoor >= pIndoor) {
      state = IndoorOutdoorState.outdoor;
      confidence = pOutdoor;
    } else {
      state = IndoorOutdoorState.indoor;
      confidence = pIndoor;
    }

    stopwatch.stop();

    final reasoning = 'Yoo-2025 cn0=${currentCn0.toStringAsFixed(1)}dB '
        'sats=$currentSatUsed '
        'P(out)=${(pOutdoor * 100).toStringAsFixed(0)}% '
        'P(in)=${(pIndoor * 100).toStringAsFixed(0)}% '
        'P(trans)=${(pTransition * 100).toStringAsFixed(0)}%';

    return IodPrediction(
      state: state,
      confidence: confidence,
      deepIodOutdoorProbability: pOutdoor,
      transitionProbability: pTransition,
      nativeClass: state.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }

  /// Mathematical approximation when only Geolocator horizontal accuracy is available.
  double _estimateCn0FromAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null || accuracyMeters <= 0.0) return 18.0;
    // Strong accuracy (<10m) corresponds roughly to 30+ dB-Hz C/N0
    // Poor accuracy (>40m) corresponds to <20 dB-Hz C/N0
    final estimated = 35.0 - (accuracyMeters * 0.40);
    return estimated.clamp(12.0, 38.0);
  }
}
