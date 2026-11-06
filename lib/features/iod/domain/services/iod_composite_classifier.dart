import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'deepiod_baseline_classifier.dart';
import 'deepiod_framework_classifier.dart';
import 'deepiod_neural_classifier.dart';
import 'seamless_transition_detector.dart';

/// Supported operation modes for the Aetron Indoor-Outdoor Detection subsystem.
enum IodClassifierMode {
  /// Composite Production Default: Dedicated Model C-Mobile (4 unprivileged sensors)
  /// with Yoo (2025) probabilistic transition boundary telemetry reported as an auxiliary signal.
  compositeDefault,

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

  final IodClassifierMode mode;
  final DeepIodFrameworkClassifier _frameworkClassifier;
  final DeepIodNeuralClassifier _mobileClassifier;
  final DeepIodNeuralClassifier _completeClassifier;
  final DeepIodBaselineClassifier _heuristicBaseline;
  final SeamlessTransitionDetector _yooTransition;

  String get activeModelVersion {
    switch (mode) {
      case IodClassifierMode.compositeDefault:
        return modelVersion;
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
  })  : _frameworkClassifier = frameworkClassifier ?? DeepIodFrameworkClassifier(),
        _mobileClassifier = mobileClassifier ?? DeepIodNeuralClassifier.mobile(),
        _completeClassifier = completeClassifier ?? DeepIodNeuralClassifier.complete(),
        _heuristicBaseline = heuristicBaseline ?? DeepIodBaselineClassifier(),
        _yooTransition = yooTransition ?? SeamlessTransitionDetector();

  factory IodCompositeClassifier.fullDeepIod({SeamlessTransitionDetector? yooTransition}) =>
      IodCompositeClassifier(
        mode: IodClassifierMode.deepiodFull,
        yooTransition: yooTransition,
      );

  factory IodCompositeClassifier.mobileOnly() =>
      IodCompositeClassifier(mode: IodClassifierMode.deepiodMobile);

  factory IodCompositeClassifier.research8Channel() =>
      IodCompositeClassifier(mode: IodClassifierMode.deepiodModelCResearch);

  factory IodCompositeClassifier.yooOnly({SeamlessTransitionDetector? yooTransition}) =>
      IodCompositeClassifier(
        mode: IodClassifierMode.yooTransition,
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
  }

  /// Evaluates models according to the selected [mode].
  IodPrediction predict(IodSensorSnapshot snapshot) {
    switch (mode) {
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

        final availability = Map<String, bool>.from(neuralPred.sensorAvailability)
          ..addAll(yooPred.sensorAvailability);

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
