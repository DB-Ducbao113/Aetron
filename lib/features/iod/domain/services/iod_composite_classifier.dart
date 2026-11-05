import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_baseline_classifier.dart';
import 'seamless_transition_detector.dart';

/// Unified composite classifier coordinating DeepIOD (2024) and Yoo (2025).
///
/// Ensures both published models run concurrently, preserving their native
/// outputs while resolving the overall application-level environment state:
/// - [IndoorOutdoorState.indoor]
/// - [IndoorOutdoorState.outdoor]
/// - [IndoorOutdoorState.transition]
/// - [IndoorOutdoorState.unknown]
class IodCompositeClassifier {
  static const String modelVersion = 'aetron-iod-ensemble-v1.0';

  final DeepIodBaselineClassifier _deepIod = DeepIodBaselineClassifier();
  final SeamlessTransitionDetector _yooTransition = SeamlessTransitionDetector();

  void reset() {
    _yooTransition.reset();
  }

  /// Evaluates both models and computes the integrated prediction.
  IodPrediction predict(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    // 1. Run primary DeepIOD multi-source baseline
    final deepIodPred = _deepIod.classify(snapshot);

    // 2. Run secondary Yoo transition boundary detector
    final yooPred = _yooTransition.evaluate(snapshot);

    stopwatch.stop();
    final latency = stopwatch.elapsedMilliseconds;

    // Fused resolution logic:
    // If Yoo transition detector recognizes an entrance/exit boundary with high confidence,
    // transition state takes precedence.
    IndoorOutdoorState resolvedState;
    double resolvedConfidence;

    final yooTransitionProb = yooPred.transitionProbability ?? 0.0;
    if (yooTransitionProb >= 0.50) {
      resolvedState = IndoorOutdoorState.transition;
      resolvedConfidence = yooTransitionProb;
    } else {
      // Defer to DeepIOD AMV fused prediction
      resolvedState = deepIodPred.state;
      resolvedConfidence = deepIodPred.confidence;
    }

    // Merge sensor availability
    final availability = Map<String, bool>.from(deepIodPred.sensorAvailability)
      ..addAll(yooPred.sensorAvailability);

    final combinedReasoning =
        'Ensemble: [State=${resolvedState.code.toUpperCase()}] '
        'DeepIOD=${deepIodPred.state.code}(${(deepIodPred.confidence * 100).toStringAsFixed(0)}%) | '
        'YooTrans=${(yooTransitionProb * 100).toStringAsFixed(0)}% | '
        '${deepIodPred.reasoningSummary}';

    return IodPrediction(
      state: resolvedState,
      confidence: resolvedConfidence,
      deepIodOutdoorProbability: deepIodPred.deepIodOutdoorProbability,
      transitionProbability: yooTransitionProb,
      nativeClass: 'deepiod:${deepIodPred.nativeClass}+yoo:${yooPred.nativeClass}',
      modelVersion: modelVersion,
      inferenceLatencyMs: latency,
      sensorAvailability: availability,
      reasoningSummary: combinedReasoning,
      isObservationalOnly: true,
    );
  }
}
