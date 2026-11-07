import '../../data/models/deepiod_model_c_mobile_weights.dart';
import '../../data/models/deepiod_model_c_weights.dart';
import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_model_c.dart';

/// Supported variants of DeepIOD Model C for evaluation and deployment.
enum DeepIodVariant {
  /// Published 8-channel Model C (DWS-Conv2D) from DeepIOD (Table 1, Sensors 2024; DOI: 10.3390/s24165125).
  /// Features: [RSRP, RSRQ, Light, Mag, Acc, Sound, Proximity, Daytime].
  /// Genuinely missing mobile channels are imputed with population mean (normalized 0.0) following standard ablation.
  complete8Channel,

  /// Dedicated 4-channel Model C-Mobile retrained strictly on genuinely available mobile sensors.
  /// Features: [Light, Mag, Acc, Daytime]. Zero reliance on unprivileged cellular PHY, audio, or proxied sensors.
  mobile4Channel,
}

/// Neural network-based Indoor-Outdoor Detection classifier reproducing DeepIOD
/// (Dastagir, Tariq, & Han, KAIST; Sensors 2024, 24(16), 5125; DOI: 10.3390/s24165125).
///
/// Architecture & Methodology:
/// - Evaluated on the University of Cambridge CIOD Benchmark (Bakirtzis et al., 2022).
/// - Deploys Model C (PMC11360063 Table 1): 2D Depth-Wise Separable CNN (DWS-Conv2D)
///   specifically engineered for low-latency on-device mobile smartphone inference.
/// - 10-step temporal sliding window with zero temporal data leakage.
/// - Published Decision Rule: Strictly binary boundary:
///   `P(Outdoor) >= 0.50 -> Outdoor; else Indoor`.
/// - Observational Mode: Strictly observational with zero side-effects on workout tracking,
///   GPS trajectory, EKF smoothing, pace, distance, or calories.
class DeepIodNeuralClassifier {
  final DeepIodModelC _model;
  final int windowSize;
  final DeepIodVariant variant;
  final double classificationThreshold;
  final List<List<double>> _historyWindow = [];

  String get modelVersion => variant == DeepIodVariant.mobile4Channel
      ? 'deepiod-neural-c-mobile-v1.0'
      : 'deepiod-neural-c-v1.0';

  DeepIodNeuralClassifier({
    DeepIodModelC? model,
    this.windowSize = 10,
    this.classificationThreshold = 0.50,
    DeepIodVariant? variant,
  })  : _model = model ??
            (variant == DeepIodVariant.complete8Channel
                ? DeepIodModelC.fromJson(kDeepIodModelCWeights)
                : DeepIodModelC.fromJson(kDeepIodModelCMobileWeights)),
        variant = variant ??
            (model != null
                ? (model.mean.length == 8
                    ? DeepIodVariant.complete8Channel
                    : DeepIodVariant.mobile4Channel)
                : DeepIodVariant.mobile4Channel);

  factory DeepIodNeuralClassifier.mobile({
    int windowSize = 10,
    double classificationThreshold = 0.50,
  }) =>
      DeepIodNeuralClassifier(
        model: DeepIodModelC.fromJson(kDeepIodModelCMobileWeights),
        windowSize: windowSize,
        classificationThreshold: classificationThreshold,
        variant: DeepIodVariant.mobile4Channel,
      );

  factory DeepIodNeuralClassifier.complete({int windowSize = 10}) =>
      DeepIodNeuralClassifier(
        model: DeepIodModelC.fromJson(kDeepIodModelCWeights),
        windowSize: windowSize,
        variant: DeepIodVariant.complete8Channel,
      );

  void reset() {
    _historyWindow.clear();
  }

  /// Evaluates a 1-second multi-sensor snapshot using the trained DeepIOD Model C neural network.
  IodPrediction classify(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    final bool hasLight = snapshot.hasLightSensor && snapshot.ambientLux != null;
    final bool hasMag = snapshot.hasImuData && snapshot.magneticMagnitudeMean != null;
    final bool hasAcc = snapshot.hasImuData && snapshot.accelMagnitudeMean != null;
    final bool hasGnss = snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null;
    final bool hasGps = snapshot.hasGpsFix;
    final bool hasLte = snapshot.hasTelephonyLte && snapshot.lteRsrpDbm != null && snapshot.lteRsrqDb != null;
    final bool hasProx = snapshot.hasProximitySensor && snapshot.proximityCm != null;

    final Map<String, bool> availability = {
      'light': hasLight,
      'mag': hasMag,
      'acc': hasAcc,
      'gnss_status': snapshot.hasGnssStatus,
      'gps': hasGps,
      'rsrp': hasLte,
      'rsrq': hasLte,
      'sound': false, // Audio recording is not acquired for user privacy
      'proximity': hasProx,
      'daytime': true,
      'telephony_lte': snapshot.hasTelephonyLte,
    };

    // If completely deprived of all sensors
    if (!hasLight && !hasMag && !hasAcc && !hasGnss && !hasGps && !hasLte) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    final mean = _model.mean;
    final std = _model.std;
    final double daytime = snapshot.isNightTime ? 0.0 : 1.0;

    List<double> currentVec;

    if (variant == DeepIodVariant.mobile4Channel) {
      // 4-Sensor Dedicated Mobile Variant: ['Light', 'Mag', 'Acc', 'Daytime']
      // Features are genuinely available on standard unprivileged smartphones.
      final double normLight = hasLight ? (snapshot.ambientLux! - mean[0]) / std[0] : 0.0;
      final double normMag = hasMag ? (snapshot.magneticMagnitudeMean! - mean[1]) / std[1] : 0.0;
      final double normAcc = hasAcc ? (snapshot.accelMagnitudeMean! - mean[2]) / std[2] : 0.0;
      final double normDaytime = (daytime - mean[3]) / std[3];

      currentVec = [normLight, normMag, normAcc, normDaytime];
    } else {
      // 8-Sensor Complete Variant: ['RSRP', 'RSRQ', 'Light', 'Mag', 'Acc', 'Sound', 'Proximity', 'Daytime']
      // Missing or unprivileged mobile telemetry is kept as missing (imputed with population mean 0.0),
      // strictly avoiding invalid proxies (GNSS C/N0 is never substituted for cellular PHY;
      // screen power state is never substituted for hardware proximity).
      final double normRsrp = hasLte ? (snapshot.lteRsrpDbm! - mean[0]) / std[0] : 0.0;
      final double normRsrq = hasLte ? (snapshot.lteRsrqDb! - mean[1]) / std[1] : 0.0;
      final double normLight = hasLight ? (snapshot.ambientLux! - mean[2]) / std[2] : 0.0;
      final double normMag = hasMag ? (snapshot.magneticMagnitudeMean! - mean[3]) / std[3] : 0.0;
      final double normAcc = hasAcc ? (snapshot.accelMagnitudeMean! - mean[4]) / std[4] : 0.0;
      const double normSound = 0.0;
      final double normProx = hasProx ? (snapshot.proximityCm! - mean[6]) / std[6] : 0.0;
      final double normDaytime = (daytime - mean[7]) / std[7];

      currentVec = [
        normRsrp,
        normRsrq,
        normLight,
        normMag,
        normAcc,
        normSound,
        normProx,
        normDaytime,
      ];
    }

    // Maintain temporal sliding window
    _historyWindow.add(currentVec);
    if (_historyWindow.length > windowSize) {
      _historyWindow.removeAt(0);
    }

    // Prepare 10xW temporal window for neural evaluation
    List<List<double>> evalWindow;
    if (_historyWindow.length == windowSize) {
      evalWindow = _historyWindow;
    } else {
      // Warmup phase: pad window with current vector to maintain valid tensor input
      evalWindow = List.generate(
        windowSize,
        (i) => i < windowSize - _historyWindow.length ? currentVec : _historyWindow[i - (windowSize - _historyWindow.length)],
      );
    }

    // Compute DeepIOD Model C Feed-Forward Inference with Trained Weights
    final double outdoorProbability = _model.predict(evalWindow);

    // Decision Rule: Threshold comparison (default 0.50 per PMC11360063 Eq. 29)
    final bool isOutdoor = outdoorProbability >= classificationThreshold;
    final IndoorOutdoorState state = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
    final double confidence = isOutdoor
        ? ((outdoorProbability - classificationThreshold) / (1.0 - classificationThreshold)).clamp(0.0, 1.0)
        : ((classificationThreshold - outdoorProbability) / classificationThreshold).clamp(0.0, 1.0);

    stopwatch.stop();

    final modelTag = variant == DeepIodVariant.mobile4Channel ? 'Model C-Mobile (4-Sensor)' : 'Model C (8-Sensor)';
    final reasoning = 'DeepIOD-Neural [$modelTag P(Out)=${(outdoorProbability * 100).toStringAsFixed(1)}%] '
        'lux=${snapshot.ambientLux?.toStringAsFixed(0) ?? "N/A"} '
        'mag=${snapshot.magneticMagnitudeMean?.toStringAsFixed(1) ?? "N/A"} '
        'daytime=${snapshot.isNightTime ? "night" : "day"}';

    return IodPrediction(
      state: state,
      confidence: confidence,
      deepIodOutdoorProbability: outdoorProbability,
      nativeClass: state.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }
}
