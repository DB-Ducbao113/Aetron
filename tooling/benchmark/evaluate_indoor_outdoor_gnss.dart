// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';

import 'iod_benchmark_models.dart';
import 'mimir_dataset_adapter.dart';

void main() async {
  print('=' * 80);
  print('  EVALUATION OF GNSS-ASSISTED FUSION ON INDOOR & OUTDOOR OBSERVATIONS');
  print('  Dataset: Nantes Zenodo Smartphone GNSS Dataset (Google Pixel 7)');
  print('  Scenarios: S2 (Building), S3 (Train Station), S5 (Shopping Mall), S1, S4');
  print('=' * 80);

  final zenodoDir = Directory('tooling/data/zenodo_nantes/dataset');
  if (!zenodoDir.existsSync()) {
    print('FATAL ERROR: Zenodo directory not found: ${zenodoDir.path}');
    exit(1);
  }

  // Load scenarios containing BOTH indoor and outdoor walking
  final testSequences = [
    // Mixed Indoor/Outdoor Scenarios
    ('S2', 'A1', 'S2/A1/GP7/log_mimir_20240313154931.txt', 'UGE Building (Outdoor -> Indoor -> Outdoor)'),
    ('S2', 'A2', 'S2/A2/GP7/log_mimir_20240313155815.txt', 'UGE Building (Outdoor -> Indoor -> Outdoor)'),
    ('S3', 'A1', 'S3/A1/GP7/log_mimir_20240314102818.txt', 'Nantes Train Station (Outdoor -> Mezzanine Indoor)'),
    ('S3', 'A2', 'S3/A2/GP7/log_mimir_20240314104725.txt', 'Nantes Train Station (Outdoor -> Mezzanine Indoor)'),
    ('S5', 'A1', 'S5/A1/GP7/log_mimir_20240315101511.txt', 'Atlantis Shopping Mall (Outdoor -> Mall Loops -> Exit)'),
    ('S5', 'A2', 'S5/A2/GP7/log_mimir_20240315102957.txt', 'Atlantis Shopping Mall (Outdoor -> Mall Loops -> Exit)'),
    // Pure Outdoor Reference Scenarios
    ('S1', 'A1', 'S1/A1/GP7/log_mimir_20240313111400.txt', 'Open-sky Road Walk'),
    ('S4', 'A1', 'S4/A1/GP7/log_mimir_20240314144624.txt', 'Dense Urban Canyon Walk'),
  ];

  final allSamples = <IodBenchmarkSample>[];

  for (final (scen, acq, relPath, desc) in testSequences) {
    final f = File('${zenodoDir.path}/$relPath');
    if (!f.existsSync()) {
      print('Warning: File not found: ${f.path}');
      continue;
    }
    final samples = await MimirDatasetAdapter.parseLogFile(
      file: f,
      sessionId: '${scen}_${acq}_GP7',
      scenarioId: scen,
    );
    print('Loaded $scen-$acq ($desc): ${samples.length} epochs.');
    allSamples.addAll(samples);
  }

  print('\nTotal Epochs Loaded across all scenarios: ${allSamples.length}');

  // Filter out transition boundary epochs so we evaluate strictly on unambiguous indoor and outdoor
  final cleanSamples = allSamples.where((s) =>
      s.groundTruth == IndoorOutdoorState.indoor ||
      s.groundTruth == IndoorOutdoorState.outdoor).toList();

  final indoorCount = cleanSamples.where((s) => s.groundTruth == IndoorOutdoorState.indoor).length;
  final outdoorCount = cleanSamples.where((s) => s.groundTruth == IndoorOutdoorState.outdoor).length;
  print('Evaluated Epochs (excluding transitions): ${cleanSamples.length} (Indoor: $indoorCount, Outdoor: $outdoorCount)');

  // Models to evaluate:
  final baselineMobile = DeepIodNeuralClassifier.mobile(classificationThreshold: 0.50);
  final calibratedMobile = DeepIodNeuralClassifier.mobile(classificationThreshold: 0.25);
  final compositeDefault = IodCompositeClassifier();
  final gnssAssistedExp = IodCompositeClassifier.gnssAssistedExperimental();
  final yooTransition = SeamlessTransitionDetector();

  final evaluators = [
    (
      'Model C-Mobile Baseline (theta=0.50)',
      () => baselineMobile.reset(),
      (s) => baselineMobile.classify(s.snapshot),
    ),
    (
      'Model C-Mobile Calibrated (theta=0.25)',
      () => calibratedMobile.reset(),
      (s) => calibratedMobile.classify(s.snapshot),
    ),
    (
      'Aetron Composite Default (Production)',
      () => compositeDefault.reset(),
      (s) => compositeDefault.predict(s.snapshot),
    ),
    (
      'Candidate: Composite GNSS-Assisted Exp',
      () => gnssAssistedExp.reset(),
      (s) => gnssAssistedExp.predict(s.snapshot),
    ),
    (
      'Yoo (2025) Transition Detector Standalone',
      () => yooTransition.reset(),
      (s) => yooTransition.evaluate(s.snapshot),
    ),
  ];

  print('\n' + '=' * 105);
  print('PERFORMANCE & FALSE OUTDOOR CLASSIFICATION AUDIT (MIMIR / PIXEL 7 WITH GENUINE GNSS)');
  print('=' * 105);
  print('| Model / Mode | Total | In GT | In TN | False Out (FP) | False Out Rate | Out GT | Out TP | Miss Out (FN) | Out Rec | In Rec | Acc | Macro-F1 |');
  print('| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |');

  for (final (name, resetFn, predictFn) in evaluators) {
    String? currentSess;
    int inGt = 0;
    int inTn = 0;
    int falseOutFp = 0;

    int outGt = 0;
    int outTp = 0;
    int missOutFn = 0;

    for (final s in cleanSamples) {
      if (s.sessionId != currentSess) {
        resetFn();
        currentSess = s.sessionId;
      }

      final pred = predictFn(s);
      final isOutPred = (pred.state == IndoorOutdoorState.outdoor);
      final isInPred = (pred.state == IndoorOutdoorState.indoor);

      if (s.groundTruth == IndoorOutdoorState.indoor) {
        inGt++;
        if (isInPred) {
          inTn++;
        } else if (isOutPred) {
          falseOutFp++;
        }
      } else if (s.groundTruth == IndoorOutdoorState.outdoor) {
        outGt++;
        if (isOutPred) {
          outTp++;
        } else if (isInPred) {
          missOutFn++;
        }
      }
    }

    final falseOutRate = inGt > 0 ? (falseOutFp / inGt * 100.0) : 0.0;
    final outRec = outGt > 0 ? (outTp / outGt * 100.0) : 0.0;
    final inRec = inGt > 0 ? (inTn / inGt * 100.0) : 0.0;
    final total = inGt + outGt;
    final acc = total > 0 ? ((inTn + outTp) / total * 100.0) : 0.0;

    final outPrec = (outTp + falseOutFp) > 0 ? (outTp / (outTp + falseOutFp) * 100.0) : 0.0;
    final inPrec = (inTn + missOutFn) > 0 ? (inTn / (inTn + missOutFn) * 100.0) : 0.0;

    final f1Out = (outPrec + outRec) > 0 ? (2 * outPrec * outRec / (outPrec + outRec)) : 0.0;
    final f1In = (inPrec + inRec) > 0 ? (2 * inPrec * inRec / (inPrec + inRec)) : 0.0;
    final macroF1 = (f1Out + f1In) / 2.0;

    print(
      '| **$name** | $total | $inGt | $inTn | **$falseOutFp** | **${falseOutRate.toStringAsFixed(1)}%** | $outGt | $outTp | $missOutFn | ${outRec.toStringAsFixed(1)}% | ${inRec.toStringAsFixed(1)}% | ${acc.toStringAsFixed(1)}% | ${macroF1.toStringAsFixed(1)}% |',
    );
  }

  // Export results to CSV for independent python verification
  final outCsv = File('tooling/data/benchmark_results/zenodo_mixed_indoor_outdoor_gnss_predictions.csv');
  outCsv.parent.createSync(recursive: true);
  final sink = outCsv.openWrite();
  sink.writeln('session_id,timestamp,ground_truth,predicted_state,class_probability,model_version,is_correct,has_gnss,top4_cn0,is_false_outdoor_inside');

  String? currS;
  gnssAssistedExp.reset();
  for (final s in cleanSamples) {
    if (s.sessionId != currS) {
      gnssAssistedExp.reset();
      currS = s.sessionId;
    }
    final pred = gnssAssistedExp.predict(s.snapshot);
    final isCorr = (pred.state == s.groundTruth) ? 1 : 0;
    final isFalseOut = (s.groundTruth == IndoorOutdoorState.indoor && pred.state == IndoorOutdoorState.outdoor) ? 1 : 0;
    sink.writeln(
      '${s.sessionId},${s.snapshot.timestamp.toIso8601String()},${s.groundTruth.code},${pred.state.code},${pred.confidence.toStringAsFixed(4)},${pred.modelVersion},$isCorr,${s.snapshot.hasGnssStatus ? 1 : 0},${s.snapshot.top4Cn0DbHz?.toStringAsFixed(1) ?? ""},$isFalseOut',
    );
  }
  await sink.close();
  print('\nExported candidate predictions to: ${outCsv.path}');
}
