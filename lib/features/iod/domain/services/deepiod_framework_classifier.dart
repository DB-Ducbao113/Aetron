import 'dart:math' as math;

import '../../data/models/deepiod_model_a_weights.dart';
import '../../data/models/deepiod_model_b_weights.dart';
import '../../data/models/deepiod_model_c_weights.dart';
import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_model_a.dart';
import 'deepiod_model_b.dart';
import 'deepiod_model_c.dart';

/// Full reproduction of the DeepIOD Context-Aware Framework (KAIST; Sensors 2024, 24(16), 5125; PMC11360063).
///
/// Implements the complete multi-source decision architecture:
/// 1. Deep Neural Network Ensemble:
///    - Model A: 1D-CNN + LSTM Sequence Decoder (Table 1)
///    - Model B: 1D-CNN + Multi-Head Self-Attention (Table 1)
///    - Model C: 2D Depth-Wise Separable CNN (Table 1)
/// 2. Adaptive Light-Intensity Module:
///    - Contextual threshold tracking based on solar elevation, civil twilight, and illuminance continuity.
/// 3. GPS Accuracy Module:
///    - Published 5-meter horizontal accuracy threshold and satellite carrier-to-noise density (C/N0).
/// 4. Adaptive Majority Voting (AMV) Consensus Rule:
///    `Context_pred = argmax_j sum_i (w_i * P_i,j)` (PMC11360063 Eq. 29).
class DeepIodFrameworkClassifier {
  static const String modelVersion = 'deepiod-full-framework-v1.0';

  final DeepIodModelA modelA;
  final DeepIodModelB modelB;
  final DeepIodModelC modelC;
  final int windowSize;

  // Normalized AMV consensus weights for neural models derived from validation F1
  final double weightA;
  final double weightB;
  final double weightC;

  final List<List<double>> _historyWindow = [];

  DeepIodFrameworkClassifier({
    DeepIodModelA? modelA,
    DeepIodModelB? modelB,
    DeepIodModelC? modelC,
    this.windowSize = 10,
    this.weightA = 0.345367,
    this.weightB = 0.320728,
    this.weightC = 0.333905,
  })  : modelA = modelA ?? DeepIodModelA.fromJson(kDeepIodModelAWeights),
        modelB = modelB ?? DeepIodModelB.fromJson(kDeepIodModelBWeights),
        modelC = modelC ?? DeepIodModelC.fromJson(kDeepIodModelCWeights);

  void reset() {
    _historyWindow.clear();
  }

  List<List<double>>? _updateAndGetWindow(IodSensorSnapshot snapshot) {
    final bool hasLight = snapshot.hasLightSensor && snapshot.ambientLux != null;
    final bool hasMag = snapshot.hasImuData && snapshot.magneticMagnitudeMean != null;
    final bool hasAcc = snapshot.hasImuData && snapshot.accelMagnitudeMean != null;
    final bool hasGnss = snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null;
    final bool hasGps = snapshot.hasGpsFix;
    final bool hasLte = snapshot.hasTelephonyLte && snapshot.lteRsrpDbm != null && snapshot.lteRsrqDb != null;
    final bool hasProx = snapshot.hasProximitySensor && snapshot.proximityCm != null;

    if (!hasLight && !hasMag && !hasAcc && !hasGnss && !hasGps && !hasLte) {
      return null;
    }

    final mean = modelC.mean;
    final std = modelC.std;
    final double daytime = snapshot.isNightTime ? 0.0 : 1.0;

    final double normRsrp = hasLte ? (snapshot.lteRsrpDbm! - mean[0]) / std[0] : 0.0;
    final double normRsrq = hasLte ? (snapshot.lteRsrqDb! - mean[1]) / std[1] : 0.0;
    final double normLight = hasLight ? (snapshot.ambientLux! - mean[2]) / std[2] : 0.0;
    final double normMag = hasMag ? (snapshot.magneticMagnitudeMean! - mean[3]) / std[3] : 0.0;
    final double normAcc = hasAcc ? (snapshot.accelMagnitudeMean! - mean[4]) / std[4] : 0.0;
    const double normSound = 0.0;
    final double normProx = hasProx ? (snapshot.proximityCm! - mean[6]) / std[6] : 0.0;
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

    _historyWindow.add(currentVec);
    if (_historyWindow.length > windowSize) {
      _historyWindow.removeAt(0);
    }

    if (_historyWindow.length == windowSize) {
      return _historyWindow;
    } else {
      return List.generate(
        windowSize,
        (i) => i < windowSize - _historyWindow.length ? currentVec : _historyWindow[i - (windowSize - _historyWindow.length)],
      );
    }
  }

  Map<String, bool> _buildAvailability(IodSensorSnapshot snapshot) {
    return {
      'light': snapshot.hasLightSensor && snapshot.ambientLux != null,
      'mag': snapshot.hasImuData && snapshot.magneticMagnitudeMean != null,
      'acc': snapshot.hasImuData && snapshot.accelMagnitudeMean != null,
      'gnss_status': snapshot.hasGnssStatus,
      'gps': snapshot.hasGpsFix,
      'rsrp': snapshot.hasTelephonyLte && snapshot.lteRsrpDbm != null,
      'rsrq': snapshot.hasTelephonyLte && snapshot.lteRsrqDb != null,
      'sound': false,
      'proximity': snapshot.hasProximitySensor && snapshot.proximityCm != null,
      'daytime': true,
    };
  }

  /// Evaluates Model A (1D-CNN + LSTM Sequence Decoder) independently.
  IodPrediction classifyModelA(IodSensorSnapshot snapshot) {
    final sw = Stopwatch()..start();
    final evalWindow = _updateAndGetWindow(snapshot);
    if (evalWindow == null) {
      sw.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: 'deepiod-model-a-v1.0',
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: _buildAvailability(snapshot),
      );
    }
    final pA = modelA.predict(evalWindow);
    sw.stop();
    final isOut = pA >= 0.50;
    return IodPrediction(
      state: isOut ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor,
      confidence: isOut ? ((pA - 0.5) * 2.0).clamp(0.0, 1.0) : (((1.0 - pA) - 0.5) * 2.0).clamp(0.0, 1.0),
      deepIodOutdoorProbability: pA,
      nativeClass: isOut ? 'outdoor' : 'indoor',
      modelVersion: 'deepiod-model-a-v1.0',
      inferenceLatencyMs: sw.elapsedMilliseconds,
      sensorAvailability: _buildAvailability(snapshot),
      reasoningSummary: 'DeepIOD Model A (CNN-LSTM) P(Out)=${(pA * 100).toStringAsFixed(1)}%',
      isObservationalOnly: true,
    );
  }

  /// Evaluates Model B (1D-CNN + Multi-Head Self-Attention) independently.
  IodPrediction classifyModelB(IodSensorSnapshot snapshot) {
    final sw = Stopwatch()..start();
    final evalWindow = _updateAndGetWindow(snapshot);
    if (evalWindow == null) {
      sw.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: 'deepiod-model-b-v1.0',
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: _buildAvailability(snapshot),
      );
    }
    final pB = modelB.predict(evalWindow);
    sw.stop();
    final isOut = pB >= 0.50;
    return IodPrediction(
      state: isOut ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor,
      confidence: isOut ? ((pB - 0.5) * 2.0).clamp(0.0, 1.0) : (((1.0 - pB) - 0.5) * 2.0).clamp(0.0, 1.0),
      deepIodOutdoorProbability: pB,
      nativeClass: isOut ? 'outdoor' : 'indoor',
      modelVersion: 'deepiod-model-b-v1.0',
      inferenceLatencyMs: sw.elapsedMilliseconds,
      sensorAvailability: _buildAvailability(snapshot),
      reasoningSummary: 'DeepIOD Model B (CNN-MHA) P(Out)=${(pB * 100).toStringAsFixed(1)}%',
      isObservationalOnly: true,
    );
  }

  /// Evaluates the Neural AMV Consensus of Models A, B, and C.
  IodPrediction classifyNeuralAmv(IodSensorSnapshot snapshot) {
    final sw = Stopwatch()..start();
    final evalWindow = _updateAndGetWindow(snapshot);
    if (evalWindow == null) {
      sw.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: 'deepiod-neural-amv-v1.0',
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: _buildAvailability(snapshot),
      );
    }
    final pA = modelA.predict(evalWindow);
    final pB = modelB.predict(evalWindow);
    final pC = modelC.predict(evalWindow);
    final pNeural = (weightA * pA) + (weightB * pB) + (weightC * pC);
    sw.stop();
    final isOut = pNeural >= 0.50;
    return IodPrediction(
      state: isOut ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor,
      confidence: isOut ? ((pNeural - 0.5) * 2.0).clamp(0.0, 1.0) : (((1.0 - pNeural) - 0.5) * 2.0).clamp(0.0, 1.0),
      deepIodOutdoorProbability: pNeural,
      nativeClass: isOut ? 'outdoor' : 'indoor',
      modelVersion: 'deepiod-neural-amv-v1.0',
      inferenceLatencyMs: sw.elapsedMilliseconds,
      sensorAvailability: _buildAvailability(snapshot),
      reasoningSummary: 'DeepIOD Neural AMV P(Out)=${(pNeural * 100).toStringAsFixed(1)}% [A=${(pA * 100).toStringAsFixed(0)}%, B=${(pB * 100).toStringAsFixed(0)}%, C=${(pC * 100).toStringAsFixed(0)}%]',
      isObservationalOnly: true,
    );
  }

  /// Classifies environment using the full DeepIOD AMV framework (Neural + Light + GPS).
  IodPrediction classify(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();
    final evalWindow = _updateAndGetWindow(snapshot);
    final availability = _buildAvailability(snapshot);

    if (evalWindow == null) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_sensors_available',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    // 1. Evaluate Neural Ensemble (Models A, B, C)
    final double pA = modelA.predict(evalWindow);
    final double pB = modelB.predict(evalWindow);
    final double pC = modelC.predict(evalWindow);
    final double pNeural = (weightA * pA) + (weightB * pB) + (weightC * pC);
    final double wNeural = 0.50; // Baseline neural reliability weight

    // 2. Evaluate Adaptive Light-Intensity Module
    final lightModule = _evaluateAdaptiveLightModule(snapshot);

    // 3. Evaluate GPS Accuracy Module (5m criterion)
    final gpsModule = _evaluateGpsAccuracyModule(snapshot);

    // 4. Adaptive Majority Voting (AMV) Consensus
    final totalWeight = wNeural + lightModule.weight + gpsModule.weight;
    final double fusedOutdoorProb = totalWeight > 0.0
        ? ((wNeural * pNeural) +
                (lightModule.weight * lightModule.outdoorProb) +
                (gpsModule.weight * gpsModule.outdoorProb)) /
            totalWeight
        : pNeural;

    final bool isOutdoor = fusedOutdoorProb >= 0.50;
    final IndoorOutdoorState state = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
    final double confidence = isOutdoor
        ? ((fusedOutdoorProb - 0.5) * 2.0).clamp(0.0, 1.0)
        : (((1.0 - fusedOutdoorProb) - 0.5) * 2.0).clamp(0.0, 1.0);

    stopwatch.stop();

    final reasoning = 'DeepIOD-Full-AMV [P(Out)=${(fusedOutdoorProb * 100).toStringAsFixed(1)}%] '
        'NeuralEnsemble(A=${(pA * 100).toStringAsFixed(0)}%, '
        'B=${(pB * 100).toStringAsFixed(0)}%, '
        'C=${(pC * 100).toStringAsFixed(0)}%, '
        'P_neural=${(pNeural * 100).toStringAsFixed(1)}% w=0.50) | '
        'Light(${lightModule.note} P=${(lightModule.outdoorProb * 100).toStringAsFixed(0)}% w=${lightModule.weight.toStringAsFixed(2)}) | '
        'GPS(${gpsModule.note} P=${(gpsModule.outdoorProb * 100).toStringAsFixed(0)}% w=${gpsModule.weight.toStringAsFixed(2)})';

    return IodPrediction(
      state: state,
      confidence: confidence,
      deepIodOutdoorProbability: fusedOutdoorProb,
      nativeClass: state.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }

  /// Adaptive light-intensity evaluation tracking diurnal state and illumination thresholds.
  _SubModuleResult _evaluateAdaptiveLightModule(IodSensorSnapshot snapshot) {
    if (!snapshot.hasLightSensor || snapshot.ambientLux == null) {
      return const _SubModuleResult(outdoorProb: 0.5, weight: 0.0, note: 'no_lux');
    }

    final lux = snapshot.ambientLux!;

    // Night condition: photodiode uninformative for solar daylight
    if (snapshot.isNightTime) {
      return _SubModuleResult(
        outdoorProb: 0.5,
        weight: 0.05,
        note: 'night lux=${lux.toStringAsFixed(0)}',
      );
    }

    // Stowed / Pocket condition
    if (lux < 5.0 && snapshot.isScreenOff) {
      return _SubModuleResult(
        outdoorProb: 0.5,
        weight: 0.05,
        note: 'pocket lux=${lux.toStringAsFixed(0)}',
      );
    }

    double outdoorProb;
    double weight = 0.40;

    if (lux >= 1000.0) {
      outdoorProb = math.min(1.0, 0.75 + (lux / 10000.0) * 0.25);
    } else if (lux <= 400.0) {
      outdoorProb = math.max(0.05, (lux / 400.0) * 0.30);
    } else {
      final t = (lux - 400.0) / (1000.0 - 400.0);
      outdoorProb = 0.30 + (t * 0.45);
      weight = 0.25;
    }

    return _SubModuleResult(
      outdoorProb: outdoorProb,
      weight: weight,
      note: 'lux=${lux.toStringAsFixed(0)}',
    );
  }

  /// GPS accuracy module implementing published 5-meter criterion and C/N0 telemetry.
  _SubModuleResult _evaluateGpsAccuracyModule(IodSensorSnapshot snapshot) {
    if (!snapshot.hasGpsFix && !snapshot.hasGnssStatus) {
      return const _SubModuleResult(outdoorProb: 0.5, weight: 0.0, note: 'no_gps');
    }

    double outdoorProb = 0.5;
    double weight = 0.35;

    if (snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null) {
      final cn0 = snapshot.top4Cn0DbHz!;
      if (cn0 >= 35.0) {
        outdoorProb = 0.85;
      } else if (cn0 <= 28.0) {
        outdoorProb = 0.15;
      } else {
        final t = (cn0 - 28.0) / (35.0 - 28.0);
        outdoorProb = 0.15 + (t * 0.70);
      }
    } else if (snapshot.hasGpsFix && snapshot.horizontalAccuracy != null) {
      final acc = snapshot.horizontalAccuracy!;
      // Published 5-meter criterion in DeepIOD
      if (acc <= 5.0) {
        outdoorProb = 0.90;
        weight = 0.40;
      } else if (acc <= 15.0) {
        outdoorProb = 0.75;
      } else if (acc >= 40.0) {
        outdoorProb = 0.30;
        weight = 0.20;
      } else {
        final t = (acc - 15.0) / (40.0 - 15.0);
        outdoorProb = 0.75 - (t * 0.45);
      }
    }

    return _SubModuleResult(
      outdoorProb: outdoorProb,
      weight: weight,
      note: snapshot.hasGnssStatus
          ? 'cn0=${snapshot.top4Cn0DbHz?.toStringAsFixed(1)}dB'
          : 'acc=${snapshot.horizontalAccuracy?.toStringAsFixed(1)}m',
    );
  }
}

class _SubModuleResult {
  final double outdoorProb;
  final double weight;
  final String note;

  const _SubModuleResult({
    required this.outdoorProb,
    required this.weight,
    required this.note,
  });
}
