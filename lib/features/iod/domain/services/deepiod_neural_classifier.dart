import '../../data/models/deepiod_model_c_weights.dart';
import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_model_c.dart';

/// Neural network-based Indoor-Outdoor Detection classifier reproducing DeepIOD
/// (Dastagir, Tariq, & Han, KAIST; Sensors 2024, 24(16), 5125; DOI: 10.3390/s24165125).
///
/// Architecture & Methodology:
/// - Evaluated on the University of Cambridge CIOD Benchmark (Bakirtzis et al., 2022).
/// - Deploys Model C (PMC11360063 Table 1): 2D Depth-Wise Separable CNN (DWS-Conv2D)
///   specifically engineered for on-device mobile smartphone inference.
/// - 8-channel temporal feature vector: [RSRP, RSRQ, Light, Mag, Acc, Sound, Proximity, Daytime].
/// - 10-step temporal sliding window with zero temporal data leakage.
/// - Published Decision Rule: Strictly binary boundary:
///   `P(Outdoor) >= 0.50 -> Outdoor; else Indoor`.
/// - Observational Mode: Strictly observational with zero side-effects on workout tracking,
///   GPS trajectory, EKF smoothing, pace, distance, or calories.
class DeepIodNeuralClassifier {
  static const String modelVersion = 'deepiod-neural-v1.0';

  final DeepIodModelC _model;
  final int windowSize;
  final List<List<double>> _historyWindow = [];

  DeepIodNeuralClassifier({
    DeepIodModelC? model,
    this.windowSize = 10,
  }) : _model = model ?? DeepIodModelC.fromJson(kDeepIodModelCWeights);

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

    final Map<String, bool> availability = {
      'light': hasLight,
      'mag': hasMag,
      'acc': hasAcc,
      'gnss_status': snapshot.hasGnssStatus,
      'gps': hasGps,
      'rsrp': hasGnss, // Informed by GNSS carrier power proxy
      'rsrq': hasGnss,
    };

    // If completely deprived of all sensors
    if (!hasLight && !hasMag && !hasAcc && !hasGnss && !hasGps) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    // 1. Feature normalization using training scaler parameters
    // Features: [RSRP, RSRQ, Light, Mag, Acc, Sound, Proximity, Daytime]
    final mean = _model.mean;
    final std = _model.std;

    // Cellular RF Signal Proxy: Unprivileged Android APIs do not expose cellular PHY (RSRP/RSRQ).
    // When GNSS carrier power (top4Cn0DbHz) is available, it provides the physical RF power indicator.
    double normRsrp = 0.0;
    double normRsrq = 0.0;
    if (hasGnss) {
      final cn0 = snapshot.top4Cn0DbHz!;
      final rfRatio = ((cn0 - 15.0) / 27.0).clamp(0.0, 1.0);
      final rsrpProxy = -125.0 + rfRatio * 60.0; // [-125 dBm, -65 dBm]
      final rsrqProxy = -18.0 + rfRatio * 13.0; // [-18 dB, -5 dB]
      normRsrp = (rsrpProxy - mean[0]) / std[0];
      normRsrq = (rsrqProxy - mean[1]) / std[1];
    }

    final double normLight = hasLight ? (snapshot.ambientLux! - mean[2]) / std[2] : 0.0;
    final double normMag = hasMag ? (snapshot.magneticMagnitudeMean! - mean[3]) / std[3] : 0.0;
    final double normAcc = hasAcc ? (snapshot.accelMagnitudeMean! - mean[4]) / std[4] : 0.0;
    const double normSound = 0.0; // Imputed population mean
    final double proximity = snapshot.isScreenOff ? 0.0 : 5.0;
    final double normProx = (proximity - mean[6]) / std[6];
    final double daytime = snapshot.isNightTime ? 0.0 : 1.0;
    final double normDaytime = (daytime - mean[7]) / std[7];

    final currentVec = [
      normRsrp,
      normRsrq,
      normLight,
      normMag,
      normAcc,
      normSound,
      normProx,
      normDaytime,
    ];

    // Maintain temporal sliding window
    _historyWindow.add(currentVec);
    if (_historyWindow.length > windowSize) {
      _historyWindow.removeAt(0);
    }

    // 2. Prepare 10x8 temporal window for neural evaluation
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

    // 3. Compute DeepIOD Model C Feed-Forward Inference with Trained Weights
    final double outdoorProbability = _model.predict(evalWindow);

    // 4. Published Decision Rule: Strictly binary boundary at 0.50 (PMC11360063 Eq. 29)
    final bool isOutdoor = outdoorProbability >= 0.50;
    final IndoorOutdoorState state = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
    final double confidence = isOutdoor
        ? ((outdoorProbability - 0.5) * 2.0).clamp(0.0, 1.0)
        : (((1.0 - outdoorProbability) - 0.5) * 2.0).clamp(0.0, 1.0);

    stopwatch.stop();

    final reasoning = 'DeepIOD-Neural [Model C DWS-Conv2D P(Out)=${(outdoorProbability * 100).toStringAsFixed(1)}%] '
        'lux=${snapshot.ambientLux?.toStringAsFixed(0) ?? "N/A"} '
        'top4Cn0=${snapshot.top4Cn0DbHz?.toStringAsFixed(1) ?? "N/A"} '
        'mag=${snapshot.magneticMagnitudeMean?.toStringAsFixed(1) ?? "N/A"}';

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
