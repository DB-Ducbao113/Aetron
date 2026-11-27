import 'dart:math' as math;

import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_baseline_classifier.dart';
import 'deepiod_framework_classifier.dart';
import 'deepiod_neural_classifier.dart';
import 'ios_multisensor_iod_classifier.dart';
import 'seamless_transition_detector.dart';

/// Supported operation modes for the Aetron Indoor-Outdoor Detection subsystem.
enum IodClassifierMode {
  /// Live, availability-gated cross-platform IOD:
  /// - Android (with ambient light sensor): DeepIOD Model C-Mobile (4-channel).
  /// - iOS / Light-free devices: iOS Multi-Sensor MagIO + IMU + CoreLocation + Barometer Causal HMM.
  liveMobile,

  /// Dedicated iOS / Light-Free Multi-Sensor Classifier (Ashraf 2018 MagIO +
  /// Esmaeili Kelishomi 2019 IMU/Baro + Bui 2020 GPS + Zhu 2019 Causal HMM).
  iosMultiSensorHmm,

  /// Pure MagIO Magnetometer Gaussian Naive Bayes + Causal HMM research mode
  /// (Ashraf et al. 2018, Micromachines 9(10), 534, DOI: 10.3390/mi9100534).
  magIoResearch,

  /// Composite Production Default: Dedicated Model C-Mobile (4 unprivileged sensors)
  /// with Yoo (2025) probabilistic transition boundary telemetry reported as an auxiliary signal.
  compositeDefault,

  /// Separate Explicit Experiment: GNSS-Assisted Composite Classifier
  /// Fuses Model C-Mobile with continuous GNSS C/N0 line-of-sight sigmoid (Yoo 2025)
  /// when GNSS telemetry is available. Falls back gracefully to calibrated Model C-Mobile
  /// when GNSS is unavailable (as in CIOD benchmark).
  compositeGnssAssistedExperimental,

  /// Full DeepIOD Framework: Adaptive Majority Voting (AMV) consensus across
  /// Model A (CNN-LSTM), Model B (CNN-MHA), Model C (DWS-Conv2D), Adaptive Light, and GPS modules.
  deepiodFull,

  /// Dedicated Model C-Mobile: Retrained strictly on 4 unprivileged smartphone channels
  /// (Light, Mag, Acc, Daytime). Explicitly labeled adapted mobile baseline.
  deepiodMobile,

  /// Complete 8-Channel Model C: DeepIOD Table 1 DWS-Conv2D evaluated on all 8 channels.
  deepiodModelCResearch,

  /// Yoo Seamless Transition Detector (Electronics 2025, 14(13), 2598):
  /// Probabilistic fusion of GNSS C/N0 boundaries, doorway proximity, and handover tracking.
  yooTransition,
}

/// Unified coordinator for Indoor–Outdoor Detection and Transition Handover.
///
/// Features:
/// 1. Explicit model selection via [IodClassifierMode].
/// 2. Version reporting per mode.
/// 3. Zero side-effects on production GPS, EKF, workout distance, pace, or calories.
class IodCompositeClassifier {
  static const String modelVersion = 'aetron-iod-composite-v2.0';
  static const String liveModelVersion = 'aetron-deepiod-c-mobile-live-v1.0';
  static const String iosLiveModelVersion =
      IosMultiSensorIodClassifier.liveFusionModelVersion;
  static const String gpsFallbackModelVersion =
      'aetron-deepiod-gps-table4-adapted-v1.0';

  final IodClassifierMode mode;
  final DeepIodFrameworkClassifier _frameworkClassifier;
  final DeepIodNeuralClassifier _mobileClassifier;
  final DeepIodNeuralClassifier _completeClassifier;
  final DeepIodBaselineClassifier _heuristicBaseline;
  final SeamlessTransitionDetector _yooTransition;
  final IosMultiSensorIodClassifier _iosLiveClassifier;
  final IosMultiSensorIodClassifier _magIoResearchClassifier;
  int _liveEpochCount = 0;
  DateTime? _lastLiveEpoch;

  String get activeModelVersion {
    switch (mode) {
      case IodClassifierMode.liveMobile:
        return liveModelVersion;
      case IodClassifierMode.iosMultiSensorHmm:
        return iosLiveModelVersion;
      case IodClassifierMode.magIoResearch:
        return IosMultiSensorIodClassifier.magIoModelVersion;
      case IodClassifierMode.compositeDefault:
        return modelVersion;
      case IodClassifierMode.compositeGnssAssistedExperimental:
        return 'aetron-iod-gnss-assisted-exp-v1.0';
      case IodClassifierMode.deepiodFull:
        return DeepIodFrameworkClassifier.modelVersion;
      case IodClassifierMode.deepiodMobile:
        return 'deepiod-neural-c-mobile-v1.0';
      case IodClassifierMode.deepiodModelCResearch:
        return 'deepiod-neural-c-v1.0';
      case IodClassifierMode.yooTransition:
        return SeamlessTransitionDetector.modelVersion;
    }
  }

  IodCompositeClassifier({
    this.mode = IodClassifierMode.compositeDefault,
    DeepIodFrameworkClassifier? frameworkClassifier,
    DeepIodNeuralClassifier? mobileClassifier,
    DeepIodNeuralClassifier? completeClassifier,
    DeepIodBaselineClassifier? heuristicBaseline,
    SeamlessTransitionDetector? yooTransition,
    IosMultiSensorIodClassifier? iosLiveClassifier,
    IosMultiSensorIodClassifier? magIoResearchClassifier,
  }) : _frameworkClassifier =
           frameworkClassifier ?? DeepIodFrameworkClassifier(),
       _mobileClassifier = mobileClassifier ?? DeepIodNeuralClassifier.mobile(),
       _completeClassifier =
           completeClassifier ?? DeepIodNeuralClassifier.complete(),
       _heuristicBaseline = heuristicBaseline ?? DeepIodBaselineClassifier(),
       _yooTransition = yooTransition ?? SeamlessTransitionDetector(),
       _iosLiveClassifier =
           iosLiveClassifier ??
           IosMultiSensorIodClassifier(
             mode: IosIodEvaluationMode.liveMultiSensorFusion,
           ),
       _magIoResearchClassifier =
           magIoResearchClassifier ??
           IosMultiSensorIodClassifier(mode: IosIodEvaluationMode.magIoOnly);

  factory IodCompositeClassifier.fullDeepIod({
    SeamlessTransitionDetector? yooTransition,
  }) => IodCompositeClassifier(
    mode: IodClassifierMode.deepiodFull,
    yooTransition: yooTransition,
  );

  factory IodCompositeClassifier.mobileOnly() =>
      IodCompositeClassifier(mode: IodClassifierMode.deepiodMobile);

  factory IodCompositeClassifier.liveMobile() =>
      IodCompositeClassifier(mode: IodClassifierMode.liveMobile);

  factory IodCompositeClassifier.iosMultiSensor() =>
      IodCompositeClassifier(mode: IodClassifierMode.iosMultiSensorHmm);

  factory IodCompositeClassifier.magIoResearch() =>
      IodCompositeClassifier(mode: IodClassifierMode.magIoResearch);

  factory IodCompositeClassifier.research8Channel() =>
      IodCompositeClassifier(mode: IodClassifierMode.deepiodModelCResearch);

  factory IodCompositeClassifier.yooOnly({
    SeamlessTransitionDetector? yooTransition,
  }) => IodCompositeClassifier(
    mode: IodClassifierMode.yooTransition,
    yooTransition: yooTransition,
  );

  factory IodCompositeClassifier.gnssAssistedExperimental({
    SeamlessTransitionDetector? yooTransition,
  }) => IodCompositeClassifier(
    mode: IodClassifierMode.compositeGnssAssistedExperimental,
    yooTransition: yooTransition,
  );

  DeepIodFrameworkClassifier get frameworkClassifier => _frameworkClassifier;
  DeepIodNeuralClassifier get mobileClassifier => _mobileClassifier;
  DeepIodNeuralClassifier get completeClassifier => _completeClassifier;
  DeepIodBaselineClassifier get heuristicBaseline => _heuristicBaseline;
  SeamlessTransitionDetector get yooTransition => _yooTransition;

  void reset() {
    _frameworkClassifier.reset();
    _mobileClassifier.reset();
    _completeClassifier.reset();
    _yooTransition.reset();
    _iosLiveClassifier.reset();
    _magIoResearchClassifier.reset();
    _liveEpochCount = 0;
    _lastLiveEpoch = null;
  }

  /// Applies the existing CIOD-trained 4-channel Model C adaptation without
  /// substituting GPS, LTE, proximity, or invented light for trained inputs.
  /// The 10-epoch warm-up and discontinuity reset are input-integrity safeguards,
  /// not new learned parameters or paper-original validation claims.
  IodPrediction _predictLive(IodSensorSnapshot snapshot) {
    final availability = <String, bool>{
      'light':
          snapshot.hasLightSensor &&
          (snapshot.ambientLux?.isFinite ?? false) &&
          snapshot.ambientLux! >= 0,
      'mag':
          snapshot.hasImuData &&
          (snapshot.magneticMagnitudeMean?.isFinite ?? false) &&
          snapshot.magneticMagnitudeMean! >= 0,
      'acc':
          snapshot.hasImuData &&
          (snapshot.accelMagnitudeMean?.isFinite ?? false) &&
          snapshot.accelMagnitudeMean! >= 0,
      'daytime': true,
      'gnss_status': snapshot.hasGnssStatus,
      'gps': snapshot.hasGpsFix,
      'rsrp':
          snapshot.hasTelephonyLte && (snapshot.lteRsrpDbm?.isFinite ?? false),
      'rsrq':
          snapshot.hasTelephonyLte && (snapshot.lteRsrqDb?.isFinite ?? false),
      'sound': false,
      'proximity':
          snapshot.hasProximitySensor &&
          (snapshot.proximityCm?.isFinite ?? false),
    };
    final missing = [
      'light',
      'mag',
      'acc',
    ].where((channel) => availability[channel] != true).toList();
    if (missing.isNotEmpty) {
      _mobileClassifier.reset();
      _liveEpochCount = 0;
      _lastLiveEpoch = null;

      // On iOS / light-free smartphones where Magnetometer + Accelerometer are
      // active, route through the CIOD-validated iOS Multi-Sensor + Causal HMM
      // pipeline instead of failing open to an uncalibrated GPS-only threshold.
      if (availability['light'] != true &&
          availability['mag'] == true &&
          availability['acc'] == true) {
        final iosPred = _iosLiveClassifier.classify(snapshot);
        if (_iosLiveClassifier.bufferedEpochs >=
            IosMultiSensorIodClassifier.minLiveWarmupEpochs) {
          return iosPred;
        }
        return _liveFallback(
          snapshot,
          availability,
          'ios_magio_hmm_warmup:${_iosLiveClassifier.bufferedEpochs}/${IosMultiSensorIodClassifier.minLiveWarmupEpochs}',
        );
      }

      _iosLiveClassifier.reset();
      return _liveFallback(
        snapshot,
        availability,
        'deepiod_c_mobile_missing:${missing.join(",")}',
      );
    }
    final previous = _lastLiveEpoch;
    if (previous != null) {
      final gap = snapshot.timestamp.difference(previous);
      // A gap longer than two nominal 1 Hz epochs means the causal input
      // window is no longer contiguous. Never bridge it with invented samples.
      if (gap <= Duration.zero || gap > const Duration(seconds: 2)) {
        _mobileClassifier.reset();
        _liveEpochCount = 0;
      }
    }
    _lastLiveEpoch = snapshot.timestamp;
    _liveEpochCount++;
    final prediction = _mobileClassifier.classify(snapshot);
    if (_liveEpochCount < _mobileClassifier.windowSize) {
      return _liveFallback(
        snapshot,
        availability,
        'deepiod_c_mobile_warmup:$_liveEpochCount/${_mobileClassifier.windowSize}',
      );
    }
    return IodPrediction(
      state: prediction.state,
      confidence: prediction.confidence,
      deepIodOutdoorProbability: prediction.deepIodOutdoorProbability,
      nativeClass: 'deepiod_c_mobile_adapted:${prediction.nativeClass}',
      modelVersion: liveModelVersion,
      inferenceLatencyMs: prediction.inferenceLatencyMs,
      sensorAvailability: availability,
      reasoningSummary:
          'CIOD-trained Model C adaptation, real 4-channel '
          'input window; ${prediction.reasoningSummary}',
      isObservationalOnly: true,
    );
  }

  /// DeepIOD (Sensors 2024, DOI 10.3390/s24165125), Section 4.5,
  /// Equation 34 / Table 4: Android horizontal accuracy >5 m suggests
  /// indoor, <5 m suggests outdoor. This is a single-modality adaptation,
  /// not a calibrated classifier or independent corroboration of GNSS.
  /// In particular, iOS accuracy has not been calibrated for this rule.
  IodPrediction _liveFallback(
    IodSensorSnapshot snapshot,
    Map<String, bool> availability,
    String reason,
  ) {
    final accuracy = snapshot.horizontalAccuracy;
    if (snapshot.hasGpsFix &&
        accuracy != null &&
        accuracy.isFinite &&
        accuracy > 0 &&
        accuracy != 5) {
      final state = accuracy < 5
          ? IndoorOutdoorState.outdoor
          : IndoorOutdoorState.indoor;
      return IodPrediction(
        state: state,
        confidence: 0.0, // No calibrated probability in the published rule.
        nativeClass: 'deepiod_gps_table4_adapted:${state.code}',
        modelVersion: gpsFallbackModelVersion,
        inferenceLatencyMs: 0,
        sensorAvailability: availability,
        reasoningSummary:
            '$reason; GPS-only Table 4 adaptation '
            '(Android-derived, uncalibrated on iOS); '
            'accuracy=${accuracy.toStringAsFixed(2)}m; advisory only',
        isObservationalOnly: true,
      );
    }
    return IodPrediction.unknown(
      reason: '$reason; fallback_required',
      modelVersion: liveModelVersion,
      sensorAvailability: availability,
    );
  }

  /// Evaluates models according to the selected [mode].
  IodPrediction predict(IodSensorSnapshot snapshot) {
    switch (mode) {
      case IodClassifierMode.liveMobile:
        return _predictLive(snapshot);
      case IodClassifierMode.iosMultiSensorHmm:
        return _iosLiveClassifier.classify(snapshot);
      case IodClassifierMode.magIoResearch:
        return _magIoResearchClassifier.classify(snapshot);
      case IodClassifierMode.deepiodFull:
        final pred = _frameworkClassifier.classify(snapshot);
        final yooPred = _yooTransition.evaluate(snapshot);
        return IodPrediction(
          state: pred.state,
          confidence: pred.confidence,
          deepIodOutdoorProbability: pred.deepIodOutdoorProbability,
          transitionProbability: yooPred.transitionProbability,
          nativeClass: 'deepiod_full:${pred.nativeClass}',
          modelVersion: activeModelVersion,
          inferenceLatencyMs: pred.inferenceLatencyMs,
          sensorAvailability: pred.sensorAvailability,
          reasoningSummary: pred.reasoningSummary,
          isObservationalOnly: true,
        );

      case IodClassifierMode.deepiodMobile:
        return _mobileClassifier.classify(snapshot);

      case IodClassifierMode.deepiodModelCResearch:
        return _completeClassifier.classify(snapshot);

      case IodClassifierMode.yooTransition:
        return _yooTransition.evaluate(snapshot);

      case IodClassifierMode.compositeGnssAssistedExperimental:
        final stopwatch = Stopwatch()..start();

        final neuralPred = _mobileClassifier.classify(snapshot);
        final double pMobile = neuralPred.deepIodOutdoorProbability ?? 0.50;

        final bool hasGnss =
            snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null;
        double pFused;
        String gnssTag;

        if (hasGnss) {
          // Yoo (2025, Electronics Eq. 4) continuous line-of-sight sigmoid model:
          // Center: 35.0 dB-Hz, Scale: 0.5
          final double cn0 = snapshot.top4Cn0DbHz!;
          final double pGnss = 1.0 / (1.0 + math.exp(-0.5 * (cn0 - 35.0)));
          pFused = (0.5 * pMobile) + (0.5 * pGnss);
          gnssTag =
              'GNSS(C/N0=${cn0.toStringAsFixed(1)}dB-Hz,P=${(pGnss * 100).toStringAsFixed(0)}%)';
        } else {
          // When GNSS is unavailable (as in CIOD), operate in sensor-deprived mode
          // using the validation-calibrated operating point (theta_val = 0.25).
          pFused = pMobile;
          gnssTag = 'GNSS(Unavailable)';
        }

        final double effectiveThreshold = hasGnss ? 0.50 : 0.25;
        final bool isOutdoor = pFused >= effectiveThreshold;
        final IndoorOutdoorState resolvedState = isOutdoor
            ? IndoorOutdoorState.outdoor
            : IndoorOutdoorState.indoor;
        final double resolvedConfidence = isOutdoor
            ? ((pFused - effectiveThreshold) / (1.0 - effectiveThreshold))
                  .clamp(0.0, 1.0)
            : ((effectiveThreshold - pFused) / effectiveThreshold).clamp(
                0.0,
                1.0,
              );

        final yooPred = _yooTransition.evaluate(snapshot);
        stopwatch.stop();

        final availability = Map<String, bool>.from(
          neuralPred.sensorAvailability,
        )..addAll(yooPred.sensorAvailability);

        final summary =
            'GNSS-Assisted Exp: [${resolvedState.code.toUpperCase()}] '
            'P(Fused)=${(pFused * 100).toStringAsFixed(1)}% | '
            'ModelC-Mobile=${(pMobile * 100).toStringAsFixed(1)}% | $gnssTag';

        return IodPrediction(
          state: resolvedState,
          confidence: resolvedConfidence,
          deepIodOutdoorProbability: pFused,
          transitionProbability: yooPred.transitionProbability,
          nativeClass: 'composite(gnss_assisted_exp)',
          modelVersion: activeModelVersion,
          inferenceLatencyMs: stopwatch.elapsedMilliseconds,
          sensorAvailability: availability,
          reasoningSummary: summary,
          isObservationalOnly: true,
        );

      case IodClassifierMode.compositeDefault:
        final stopwatch = Stopwatch()..start();

        // 1. Run primary Model C-Mobile (4 unprivileged mobile sensors)
        final neuralPred = _mobileClassifier.classify(snapshot);

        // 2. Run literature heuristic baseline
        final heuristicPred = _heuristicBaseline.classify(snapshot);

        // 3. Run secondary Yoo transition boundary detector
        final yooPred = _yooTransition.evaluate(snapshot);

        stopwatch.stop();

        final IndoorOutdoorState resolvedState = neuralPred.state;
        final double resolvedConfidence = neuralPred.confidence;
        final double yooTransitionProb = yooPred.transitionProbability ?? 0.0;

        final availability = Map<String, bool>.from(
          neuralPred.sensorAvailability,
        )..addAll(yooPred.sensorAvailability);

        final combinedReasoning =
            'Composite: [State=${resolvedState.code.toUpperCase()}] '
            'ModelC-Mobile=${neuralPred.state.code}(${(neuralPred.confidence * 100).toStringAsFixed(0)}%, '
            'P(Out)=${((neuralPred.deepIodOutdoorProbability ?? 0.0) * 100).toStringAsFixed(1)}%) | '
            'YooTrans=${(yooTransitionProb * 100).toStringAsFixed(0)}% | '
            'Baseline=${heuristicPred.state.code}';

        return IodPrediction(
          state: resolvedState,
          confidence: resolvedConfidence,
          deepIodOutdoorProbability: neuralPred.deepIodOutdoorProbability,
          transitionProbability: yooTransitionProb,
          nativeClass: 'composite(mobile+yoo)',
          modelVersion: activeModelVersion,
          inferenceLatencyMs: stopwatch.elapsedMilliseconds,
          sensorAvailability: availability,
          reasoningSummary: combinedReasoning,
          isObservationalOnly: true,
        );
    }
  }
}
