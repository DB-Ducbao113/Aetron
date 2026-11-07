import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';

/// Provenance classification of ground-truth labels.
enum LabelProvenance {
  /// Verified ground truth explicitly certified by survey description (e.g., S1, S4 100% Outdoor).
  verifiedGroundTruth,

  /// Exploratory macro scenario derived from narrative without second-by-second doorway timestamps (e.g., S2, S3, S5).
  /// Strictly EXPLORATORY: Not certified Indoor ground truth.
  exploratoryUnverifiedMacro,

  /// Backward-compatible alias for exploratoryUnverifiedMacro.
  inferredScenarioMacro,

  /// Unlabeled or completely uncertain ground truth.
  unlabeled,
}

/// A discrete test sample from a benchmark dataset with known ground truth.
class IodBenchmarkSample {
  final String sessionId;
  final int sequenceIndex;
  final DateTime timestamp;
  final IodSensorSnapshot snapshot;
  final IndoorOutdoorState groundTruth;
  final String environmentType;
  final LabelProvenance labelProvenance;

  const IodBenchmarkSample({
    required this.sessionId,
    required this.sequenceIndex,
    required this.timestamp,
    required this.snapshot,
    required this.groundTruth,
    required this.environmentType,
    this.labelProvenance = LabelProvenance.verifiedGroundTruth,
  });

  bool get isVerifiedGroundTruth =>
      labelProvenance == LabelProvenance.verifiedGroundTruth;
}

/// The result of running an Aetron IOD classifier on a benchmark sample.
class IodBenchmarkResult {
  final IodBenchmarkSample sample;
  final IodPrediction prediction;

  const IodBenchmarkResult({
    required this.sample,
    required this.prediction,
  });

  bool get isCorrect => sample.groundTruth == prediction.state;
  bool get isEvaluated => prediction.state != IndoorOutdoorState.unknown;

  Map<String, dynamic> toMap() {
    return {
      'session_id': sample.sessionId,
      'timestamp': sample.timestamp.toUtc().toIso8601String(),
      'ground_truth': sample.groundTruth.code,
      'predicted_state': prediction.state.code,
      'confidence': prediction.confidence,
      'deepiod_outdoor_score': prediction.deepIodOutdoorProbability,
      'yoo_transition_prob': prediction.transitionProbability,
      'latency_ms': prediction.inferenceLatencyMs,
      'has_gnss': sample.snapshot.hasGnssStatus,
      'satellite_count': sample.snapshot.satelliteCount,
      'mean_cn0': sample.snapshot.meanCn0DbHz,
      'top4_cn0': sample.snapshot.top4Cn0DbHz,
      'horizontal_accuracy': sample.snapshot.horizontalAccuracy,
      'speed': sample.snapshot.speed,
      'mag_var': sample.snapshot.magneticVariance,
      'is_correct': isCorrect,
    };
  }
}

/// Comprehensive statistical metrics for IOD classifier evaluation.
class IodEvaluationMetrics {
  final String datasetName;
  final String modelName;
  final int totalSamples;
  final int evaluatedSamples;
  final int unknownPredictionCount;
  final Map<IndoorOutdoorState, Map<IndoorOutdoorState, int>> confusionMatrix;

  IodEvaluationMetrics({
    required this.datasetName,
    required this.modelName,
    required this.totalSamples,
    required this.evaluatedSamples,
    required this.unknownPredictionCount,
    required this.confusionMatrix,
  });

  factory IodEvaluationMetrics.compute({
    required String datasetName,
    required String modelName,
    required List<IodBenchmarkResult> results,
  }) {
    final matrix = <IndoorOutdoorState, Map<IndoorOutdoorState, int>>{
      IndoorOutdoorState.indoor: {
        IndoorOutdoorState.indoor: 0,
        IndoorOutdoorState.outdoor: 0,
        IndoorOutdoorState.transition: 0,
        IndoorOutdoorState.unknown: 0,
      },
      IndoorOutdoorState.outdoor: {
        IndoorOutdoorState.indoor: 0,
        IndoorOutdoorState.outdoor: 0,
        IndoorOutdoorState.transition: 0,
        IndoorOutdoorState.unknown: 0,
      },
      IndoorOutdoorState.transition: {
        IndoorOutdoorState.indoor: 0,
        IndoorOutdoorState.outdoor: 0,
        IndoorOutdoorState.transition: 0,
        IndoorOutdoorState.unknown: 0,
      },
    };

    int evaluated = 0;
    int unknownCount = 0;

    for (final res in results) {
      final gt = res.sample.groundTruth;
      if (!matrix.containsKey(gt)) continue;

      final pred = res.prediction.state;
      matrix[gt]![pred] = (matrix[gt]![pred] ?? 0) + 1;

      if (pred == IndoorOutdoorState.unknown) {
        unknownCount++;
      } else {
        evaluated++;
      }
    }

    return IodEvaluationMetrics(
      datasetName: datasetName,
      modelName: modelName,
      totalSamples: results.length,
      evaluatedSamples: evaluated,
      unknownPredictionCount: unknownCount,
      confusionMatrix: matrix,
    );
  }

  double get coverage =>
      totalSamples > 0 ? evaluatedSamples / totalSamples : 0.0;

  int get correctCount {
    int sum = 0;
    for (final state in [
      IndoorOutdoorState.indoor,
      IndoorOutdoorState.outdoor,
      IndoorOutdoorState.transition,
    ]) {
      sum += confusionMatrix[state]?[state] ?? 0;
    }
    return sum;
  }

  /// Overall Accuracy on all evaluated samples.
  double get accuracy =>
      evaluatedSamples > 0 ? correctCount / evaluatedSamples : 0.0;

  /// Precision for a given state: TP / (TP + FP).
  double precision(IndoorOutdoorState state) {
    final tp = confusionMatrix[state]?[state] ?? 0;
    int totalPredicted = 0;
    for (final s in confusionMatrix.keys) {
      totalPredicted += confusionMatrix[s]?[state] ?? 0;
    }
    return totalPredicted > 0 ? tp / totalPredicted : 0.0;
  }

  /// Recall for a given state: TP / (TP + FN).
  double recall(IndoorOutdoorState state) {
    final tp = confusionMatrix[state]?[state] ?? 0;
    int totalActual = 0;
    confusionMatrix[state]?.forEach((_, count) {
      totalActual += count;
    });
    return totalActual > 0 ? tp / totalActual : 0.0;
  }

  /// F1-Score for a given state.
  double f1Score(IndoorOutdoorState state) {
    final p = precision(state);
    final r = recall(state);
    return (p + r) > 0 ? 2 * (p * r) / (p + r) : 0.0;
  }

  /// Macro-averaged F1 score across the active classes in ground truth.
  double get macroF1 {
    final activeClasses = confusionMatrix.keys.where((s) {
      final total = confusionMatrix[s]?.values.fold<int>(0, (a, b) => a + b) ?? 0;
      return total > 0;
    }).toList();

    if (activeClasses.isEmpty) return 0.0;
    final sum = activeClasses.fold<double>(0.0, (acc, s) => acc + f1Score(s));
    return sum / activeClasses.length;
  }

  /// Formats metrics as a Markdown summary table.
  String toMarkdownTable() {
    final buf = StringBuffer();
    buf.writeln('### Benchmark Evaluation: $datasetName ($modelName)\n');
    buf.writeln('| Metric | Value |');
    buf.writeln('| :--- | :--- |');
    buf.writeln('| **Total Samples** | $totalSamples |');
    buf.writeln('| **Evaluated Samples** | $evaluatedSamples |');
    buf.writeln('| **Unknown / Abstained** | $unknownPredictionCount (${(totalSamples > 0 ? (unknownPredictionCount / totalSamples * 100) : 0).toStringAsFixed(1)}%) |');
    buf.writeln('| **Coverage** | ${(coverage * 100).toStringAsFixed(2)}% |');
    buf.writeln('| **Accuracy** | **${(accuracy * 100).toStringAsFixed(2)}%** |');
    buf.writeln('| **Macro-F1** | **${(macroF1 * 100).toStringAsFixed(2)}%** |\n');

    buf.writeln('#### Per-Class Performance\n');
    buf.writeln('| Class | Support | Precision | Recall | F1-Score |');
    buf.writeln('| :--- | :--- | :--- | :--- | :--- |');
    for (final s in confusionMatrix.keys) {
      final support = confusionMatrix[s]?.values.fold<int>(0, (a, b) => a + b) ?? 0;
      if (support == 0) continue;
      final p = precision(s) * 100;
      final r = recall(s) * 100;
      final f1 = f1Score(s) * 100;
      buf.writeln('| **${s.code.toUpperCase()}** | $support | ${p.toStringAsFixed(1)}% | ${r.toStringAsFixed(1)}% | **${f1.toStringAsFixed(1)}%** |');
    }
    buf.writeln();

    buf.writeln('#### Confusion Matrix (Actual rows vs Predicted columns)\n');
    buf.writeln('| Ground Truth \\ Pred | Indoor | Outdoor | Transition | Unknown |');
    buf.writeln('| :--- | :--- | :--- | :--- | :--- |');
    for (final s in confusionMatrix.keys) {
      final row = confusionMatrix[s]!;
      buf.writeln('| **${s.code.toUpperCase()}** | ${row[IndoorOutdoorState.indoor]} | ${row[IndoorOutdoorState.outdoor]} | ${row[IndoorOutdoorState.transition]} | ${row[IndoorOutdoorState.unknown]} |');
    }

    return buf.toString();
  }

  /// Exports detailed per-sample predictions to a CSV file.
  static Future<void> exportToCsv(String filePath, List<IodBenchmarkResult> results) async {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    final sink = file.openWrite();

    sink.writeln(
      'session_id,timestamp,ground_truth,predicted_state,class_probability,model_version,is_correct,confidence,'
      'deepiod_outdoor_score,yoo_transition_prob,latency_ms,has_gnss,'
      'satellite_count,mean_cn0,top4_cn0,horizontal_accuracy,speed,mag_var',
    );

    for (final res in results) {
      final s = res.sample;
      final snap = s.snapshot;
      final pred = res.prediction;

      double classProb;
      if (pred.deepIodOutdoorProbability != null) {
        if (pred.state == IndoorOutdoorState.outdoor) {
          classProb = pred.deepIodOutdoorProbability!;
        } else if (pred.state == IndoorOutdoorState.indoor) {
          classProb = 1.0 - pred.deepIodOutdoorProbability!;
        } else if (pred.state == IndoorOutdoorState.transition) {
          classProb = pred.transitionProbability ?? pred.confidence;
        } else {
          classProb = pred.confidence;
        }
      } else {
        classProb = pred.confidence;
      }

      sink.writeln([
        s.sessionId,
        s.timestamp.toUtc().toIso8601String(),
        s.groundTruth.code,
        pred.state.code,
        classProb.toStringAsFixed(4),
        pred.modelVersion,
        res.isCorrect ? 1 : 0,
        pred.confidence.toStringAsFixed(3),
        pred.deepIodOutdoorProbability?.toStringAsFixed(3) ?? '',
        pred.transitionProbability?.toStringAsFixed(3) ?? '',
        pred.inferenceLatencyMs,
        snap.hasGnssStatus ? 1 : 0,
        snap.satelliteCount ?? '',
        snap.meanCn0DbHz?.toStringAsFixed(1) ?? '',
        snap.top4Cn0DbHz?.toStringAsFixed(1) ?? '',
        snap.horizontalAccuracy?.toStringAsFixed(1) ?? '',
        snap.speed?.toStringAsFixed(2) ?? '',
        snap.magneticVariance?.toStringAsFixed(2) ?? '',
      ].join(','));
    }

    await sink.flush();
    await sink.close();
  }
}
