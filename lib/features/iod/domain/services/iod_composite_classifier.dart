import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_baseline_classifier.dart';
import 'deepiod_neural_classifier.dart';
import 'seamless_transition_detector.dart';

/// Unified composite classifier coordinating DeepIOD (Sensors 2024) and Yoo (Electronics 2025).
///
/// Integrates:
/// 1. DeepIOD Neural Classifier: Model C (PMC11360063 Table 1) 2D Depth-Wise Separable CNN
///    trained on Cambridge CIOD benchmark with exact feed-forward numerical weights.
/// 2. DeepIOD Literature Baseline: Multi-source heuristic baseline preserved for comparison.
/// 3. Yoo Seamless Transition Detector: Continuous entrance/exit boundary identification.
///
/// Resolves the overall application-level environment state:
/// - [IndoorOutdoorState.indoor]
/// - [IndoorOutdoorState.outdoor]
/// - [IndoorOutdoorState.transition]
/// - [IndoorOutdoorState.unknown]
class IodCompositeClassifier {
  static const String modelVersion = 'aetron-iod-ensemble-v1.0';

  final DeepIodNeuralClassifier _neuralClassifier = DeepIodNeuralClassifier();
  final DeepIodBaselineClassifier _heuristicBaseline = DeepIodBaselineClassifier();
  final SeamlessTransitionDetector _yooTransition = SeamlessTransitionDetector();

  void reset() {
    _neuralClassifier.reset();
    _yooTransition.reset();
  }

  /// Evaluates models and computes the integrated prediction.
  IodPrediction predict(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    // 1. Run primary DeepIOD trained neural network (Table 1 Model C DWS-Conv2D)
    final neuralPred = _neuralClassifier.classify(snapshot);

    // 2. Run heuristic baseline for literature comparison
    final heuristicPred = _heuristicBaseline.classify(snapshot);

    // 3. Run secondary Yoo transition boundary detector
    final yooPred = _yooTransition.evaluate(snapshot);

    stopwatch.stop();
    final latency = stopwatch.elapsedMilliseconds;

    // Primary application-level classification path:
    // Follows the validated primary DeepIOD neural classifier (Model C).
    // Yoo's transition detector is preserved as a separately reported experimental signal
    // without unconditionally hijacking the primary Indoor/Outdoor classification.
    final IndoorOutdoorState resolvedState = neuralPred.state;
    final double resolvedConfidence = neuralPred.confidence;
    final double yooTransitionProb = yooPred.transitionProbability ?? 0.0;

    // Merge sensor availability
    final availability = Map<String, bool>.from(neuralPred.sensorAvailability)
      ..addAll(yooPred.sensorAvailability);

    final combinedReasoning =
        'Ensemble: [State=${resolvedState.code.toUpperCase()}] '
        'NeuralModelC=${neuralPred.state.code}(${(neuralPred.confidence * 100).toStringAsFixed(0)}%, '
        'P(Out)=${((neuralPred.deepIodOutdoorProbability ?? 0.0) * 100).toStringAsFixed(1)}%) | '
        'YooExperimentalTrans=${(yooTransitionProb * 100).toStringAsFixed(0)}% | '
        'Baseline=${heuristicPred.state.code}';

    return IodPrediction(
      state: resolvedState,
      confidence: resolvedConfidence,
      deepIodOutdoorProbability: neuralPred.deepIodOutdoorProbability,
      transitionProbability: yooTransitionProb,
      nativeClass: 'neural:${neuralPred.nativeClass}+yoo:${yooPred.nativeClass}',
      modelVersion: modelVersion,
      inferenceLatencyMs: latency,
      sensorAvailability: availability,
      reasoningSummary: combinedReasoning,
      isObservationalOnly: true,
    );
  }
}

