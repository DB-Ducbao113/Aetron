// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ciod_dataset_adapter.dart';
import 'iod_benchmark_models.dart';

void main() {
  test('Cambridge CIOD Full-Session Held-Out Benchmark (Sessions 72..84, Uncapped)', () async {
    print('======================================================================');
    print('  CAMBRIDGE CIOD — UNCAPPED FULL-SESSION HELD-OUT GENERALIZATION AUDIT');
    print('  (ALL SAMPLES ACROSS SESSIONS 72..84, ZERO ARTIFICIAL SESSION CAPPING)');
    print('======================================================================\n');

    final swTotal = Stopwatch()..start();

    final ciodFile = File('tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv');
    if (!ciodFile.existsSync() || ciodFile.lengthSync() == 0) {
      stderr.writeln('FATAL ERROR: Cambridge CIOD dataset file missing or empty at: ${ciodFile.path}');
      fail('Cambridge CIOD dataset file missing or empty');
    }

    final outDir = Directory('tooling/data/benchmark_results');
    outDir.createSync(recursive: true);

    final heldOutSessionIds = Set<int>.from(List.generate(13, (i) => 72 + i));
    print('Loading ALL held-out test sessions (Sessions 72..84, maxSamplesPerSession = 0)...');
    final swLoad = Stopwatch()..start();
    final ciodFullSamples = await CiodDatasetAdapter.parseCsvFile(
      file: ciodFile,
      targetSessionIndices: heldOutSessionIds,
      maxSamplesPerSession: 0,
    );
    print('Loaded ${ciodFullSamples.length} samples in ${swLoad.elapsedMilliseconds} ms.');

    final loadedSessionIds = ciodFullSamples.map((s) => s.sessionId).toSet();
    if (loadedSessionIds.length != 13) {
      stderr.writeln('FATAL ERROR: Expected 13 held-out test sessions, got ${loadedSessionIds.length}');
      fail('Expected 13 held-out test sessions, got ${loadedSessionIds.length}');
    }
    for (int sIdx = 72; sIdx <= 84; sIdx++) {
      if (!loadedSessionIds.contains('CIOD_session_${sIdx + 1}') &&
          !loadedSessionIds.contains('CIOD_session_$sIdx') &&
          !loadedSessionIds.contains('session_$sIdx')) {
        stderr.writeln('FATAL ERROR: Missing required held-out test session: $sIdx');
        fail('Missing required held-out test session: $sIdx');
      }
    }

    final indoorCount = ciodFullSamples.where((s) => s.groundTruth == IndoorOutdoorState.indoor).length;
    final outdoorCount = ciodFullSamples.where((s) => s.groundTruth == IndoorOutdoorState.outdoor).length;
    print('Class Distribution across Full Held-Out Sessions:');
    print('  - Total Samples:   ${ciodFullSamples.length}');
    print('  - Indoor Samples:  $indoorCount (${(indoorCount / ciodFullSamples.length * 100).toStringAsFixed(2)}%)');
    print('  - Outdoor Samples: $outdoorCount (${(outdoorCount / ciodFullSamples.length * 100).toStringAsFixed(2)}%)\n');

    // Baseline A: Always-Indoor Majority Baseline (Full Held-Out)
    final ciodAlwaysIndoorResults = <IodBenchmarkResult>[];
    for (final s in ciodFullSamples) {
      ciodAlwaysIndoorResults.add(IodBenchmarkResult(
        sample: s,
        prediction: IodPrediction(
          state: IndoorOutdoorState.indoor,
          confidence: 1.0,
          nativeClass: 'indoor',
          modelVersion: 'majority-always-indoor',
          inferenceLatencyMs: 0,
          sensorAvailability: const {},
          reasoningSummary: 'Always-Indoor baseline (full held-out test)',
          isObservationalOnly: true,
        ),
      ));
    }
    final ciodAlwaysIndoorMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (Sessions 72..84)',
      modelName: 'Always-Indoor Majority Baseline',
      results: ciodAlwaysIndoorResults,
    );
    print(ciodAlwaysIndoorMetrics.toMarkdownTable());

    // Model 1: Deployed Model C-Mobile (4-Sensor Dedicated Mobile Network)
    print('Evaluating Deployed Model C-Mobile on Full Held-Out Set...');
    final swMobile = Stopwatch()..start();
    final ciodMobileResults = <IodBenchmarkResult>[];
    final deepIodMobileClassifier = DeepIodNeuralClassifier.mobile();
    String? lastSessIdMobile;
    for (final s in ciodFullSamples) {
      if (s.sessionId != lastSessIdMobile) {
        deepIodMobileClassifier.reset();
        lastSessIdMobile = s.sessionId;
      }
      final pred = deepIodMobileClassifier.classify(s.snapshot);
      ciodMobileResults.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    print('Evaluated Model C-Mobile in ${swMobile.elapsedMilliseconds} ms.');
    final ciodMobileMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (Sessions 72..84, 201,731 samples)',
      modelName: 'DeepIOD Model C-Mobile (4-Sensor Dedicated — Deployed)',
      results: ciodMobileResults,
    );
    print(ciodMobileMetrics.toMarkdownTable());

    // Model 2: Aetron IOD Composite Classifier (Application Deployed Default)
    print('Evaluating Aetron Composite Classifier on Full Held-Out Set...');
    final swComp = Stopwatch()..start();
    final ciodCompositeResults = <IodBenchmarkResult>[];
    final compositeClassifier = IodCompositeClassifier();
    String? lastSessIdComp;
    for (final s in ciodFullSamples) {
      if (s.sessionId != lastSessIdComp) {
        compositeClassifier.reset();
        lastSessIdComp = s.sessionId;
      }
      final pred = compositeClassifier.predict(s.snapshot);
      ciodCompositeResults.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    print('Evaluated Aetron Composite Classifier in ${swComp.elapsedMilliseconds} ms.');
    final ciodCompositeMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (Sessions 72..84, 201,731 samples)',
      modelName: 'Aetron IOD Composite Classifier (Deployed Default)',
      results: ciodCompositeResults,
    );
    print(ciodCompositeMetrics.toMarkdownTable());

    // Model 3: DeepIOD Model C (8-Sensor Complete Network)
    print('Evaluating DeepIOD Model C (8-Sensor Complete) on Full Held-Out Set...');
    final swC = Stopwatch()..start();
    final ciodModelCResults = <IodBenchmarkResult>[];
    final deepIodCClassifier = DeepIodNeuralClassifier.complete();
    String? lastSessIdC;
    for (final s in ciodFullSamples) {
      if (s.sessionId != lastSessIdC) {
        deepIodCClassifier.reset();
        lastSessIdC = s.sessionId;
      }
      final pred = deepIodCClassifier.classify(s.snapshot);
      ciodModelCResults.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    print('Evaluated Model C (8-Sensor) in ${swC.elapsedMilliseconds} ms.');
    final ciodModelCMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (Sessions 72..84, 201,731 samples)',
      modelName: 'DeepIOD Model C (8-Sensor Complete Network)',
      results: ciodModelCResults,
    );
    print(ciodModelCMetrics.toMarkdownTable());

    // Export predictions to CSV
    print('Exporting full held-out prediction CSVs...');
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_mobile_predictions.csv',
      ciodMobileResults,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_composite_predictions.csv',
      ciodCompositeResults,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_model_c_predictions.csv',
      ciodModelCResults,
    );

    print('\nAll full held-out evaluations completed in ${(swTotal.elapsedMilliseconds / 1000).toStringAsFixed(1)} seconds.');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
