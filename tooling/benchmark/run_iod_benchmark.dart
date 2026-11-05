// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_baseline_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ciod_dataset_adapter.dart';
import 'iod_benchmark_models.dart';
import 'mimir_dataset_adapter.dart';

void main() {
  test('IOD Benchmark Suite on Published Datasets (Zenodo & Cambridge CIOD)', () async {
    print('================================================================');
    print('       AETRON INDOOR-OUTDOOR DETECTION BENCHMARK HARNESS       ');
    print('================================================================\n');

    final outDir = Directory('tooling/data/benchmark_results');
    outDir.createSync(recursive: true);

    // ================================================================
    // PART 1: ZENODO ANDROID GNSS/IMU BENCHMARK (NANTES DATASET)
    // ================================================================
    print('>>> PART 1: ZENODO ANDROID GNSS/IMU (Grenier et al., 2024)...');
    final zenodoDir = Directory('tooling/data/zenodo_nantes/dataset');
    if (!zenodoDir.existsSync()) {
      fail('Zenodo dataset directory not found at: ${zenodoDir.path}');
    }

    final sequences = [
      // S1: Open-Sky Outdoor (100% verified outdoor ground truth)
      ('S1', 'A1', 'S1/A1/GP7/log_mimir_20240313111400.txt'),
      ('S1', 'A2', 'S1/A2/GP7/log_mimir_20240313112757.txt'),
      // S4: Urban Canyon Outdoor (100% verified outdoor ground truth)
      ('S4', 'A1', 'S4/A1/GP7/log_mimir_20240314144624.txt'),
      ('S4', 'A2', 'S4/A2/GP7/log_mimir_20240314151021.txt'),
      // S2: Indoor in UGE Building (mixed macro scenario, doorway transitions unverified)
      ('S2', 'A1', 'S2/A1/GP7/log_mimir_20240313154931.txt'),
      ('S2', 'A2', 'S2/A2/GP7/log_mimir_20240313155815.txt'),
      // S3: Light Indoor in Train Station (glass walls/roof, doorway transitions unverified)
      ('S3', 'A1', 'S3/A1/GP7/log_mimir_20240314102818.txt'),
      ('S3', 'A2', 'S3/A2/GP7/log_mimir_20240314104725.txt'),
      // S5: Shopping Center Indoor (dense stores & atrium, doorway transitions unverified)
      ('S5', 'A1', 'S5/A1/GP7/log_mimir_20240315101511.txt'),
      ('S5', 'A2', 'S5/A2/GP7/log_mimir_20240315102957.txt'),
    ];

    final allZenodoSamples = <IodBenchmarkSample>[];
    final Map<String, List<IodBenchmarkSample>> samplesByScenario = {
      'S1': [],
      'S4': [],
      'S2': [],
      'S3': [],
      'S5': [],
    };

    for (final (scenario, acq, relPath) in sequences) {
      final file = File('${zenodoDir.path}/$relPath');
      if (!file.existsSync()) {
        print('Sequence file missing: $relPath (skipping)');
        continue;
      }

      final sessionId = '${scenario}_${acq}_GP7';
      final seqSamples = await MimirDatasetAdapter.parseLogFile(
        file: file,
        sessionId: sessionId,
        scenarioId: scenario,
      );

      allZenodoSamples.addAll(seqSamples);
      samplesByScenario[scenario]?.addAll(seqSamples);
      print('Loaded $sessionId: ${seqSamples.length} epochs (Scenario $scenario)');
    }

    print('\nTotal Zenodo samples: ${allZenodoSamples.length} across ${sequences.length} sessions.');

    // Majority Baseline: Always Outdoor
    final alwaysOutdoorResults = <IodBenchmarkResult>[];
    for (final sample in allZenodoSamples) {
      alwaysOutdoorResults.add(IodBenchmarkResult(
        sample: sample,
        prediction: IodPrediction(
          state: IndoorOutdoorState.outdoor,
          confidence: 1.0,
          nativeClass: 'outdoor',
          modelVersion: 'majority-always-outdoor',
          inferenceLatencyMs: 0,
          sensorAvailability: const {},
          reasoningSummary: 'Majority class baseline (always outdoor)',
          isObservationalOnly: true,
        ),
      ));
    }
    final alwaysOutdoorMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (All 6,482 Epochs)',
      modelName: 'Always-Outdoor Majority Baseline',
      results: alwaysOutdoorResults,
    );

    // Yoo 2025 Adaptation
    final yooDetector = SeamlessTransitionDetector();
    final yooResults = <IodBenchmarkResult>[];
    String? lastSession;
    for (final sample in allZenodoSamples) {
      if (sample.sessionId != lastSession) {
        yooDetector.reset();
        lastSession = sample.sessionId;
      }
      final pred = yooDetector.evaluate(sample.snapshot);
      yooResults.add(IodBenchmarkResult(sample: sample, prediction: pred));
    }
    final yooMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (All 6,482 Epochs)',
      modelName: 'SeamlessTransitionDetector (Yoo 2025 C/N0 Adaptation)',
      results: yooResults,
    );

    // DeepIOD Baseline (Aetron 3-State Ternary with [0.42, 0.58] transition band)
    final deepIodClassifier = DeepIodBaselineClassifier();
    final deepIodTernaryResults = <IodBenchmarkResult>[];
    for (final sample in allZenodoSamples) {
      final pred = deepIodClassifier.classify(sample.snapshot);
      deepIodTernaryResults.add(IodBenchmarkResult(sample: sample, prediction: pred));
    }
    final deepIodTernaryMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (All 6,482 Epochs)',
      modelName: 'DeepIOD Baseline (Aetron 3-State Ternary Heuristic)',
      results: deepIodTernaryResults,
    );

    // DeepIOD Baseline (Native Published Binary Decision Rule: P >= 0.5)
    final deepIodBinaryResults = <IodBenchmarkResult>[];
    for (final sample in allZenodoSamples) {
      final pred = deepIodClassifier.classify(sample.snapshot);
      final pOutdoor = pred.deepIodOutdoorProbability ?? 0.5;
      final isOutdoor = pOutdoor >= 0.50;
      final binaryState = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
      final binaryConf = isOutdoor
          ? ((pOutdoor - 0.5) * 2.0).clamp(0.0, 1.0)
          : (((1.0 - pOutdoor) - 0.5) * 2.0).clamp(0.0, 1.0);

      deepIodBinaryResults.add(IodBenchmarkResult(
        sample: sample,
        prediction: IodPrediction(
          state: binaryState,
          confidence: binaryConf,
          deepIodOutdoorProbability: pOutdoor,
          nativeClass: binaryState.code,
          modelVersion: 'deepiod-published-binary',
          inferenceLatencyMs: pred.inferenceLatencyMs,
          sensorAvailability: pred.sensorAvailability,
          reasoningSummary: pred.reasoningSummary,
          isObservationalOnly: true,
        ),
      ));
    }
    final deepIodBinaryMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (All 6,482 Epochs)',
      modelName: 'DeepIOD Baseline (Native Published Binary Rule P>=0.5)',
      results: deepIodBinaryResults,
    );

    // IodCompositeClassifier (Aetron Ensemble v1.0)
    final compositeClassifier = IodCompositeClassifier();
    final compositeResults = <IodBenchmarkResult>[];
    lastSession = null;
    for (final sample in allZenodoSamples) {
      if (sample.sessionId != lastSession) {
        compositeClassifier.reset();
        lastSession = sample.sessionId;
      }
      final pred = compositeClassifier.predict(sample.snapshot);
      compositeResults.add(IodBenchmarkResult(sample: sample, prediction: pred));
    }
    final compositeMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (All 6,482 Epochs)',
      modelName: 'IodCompositeClassifier (Aetron Ensemble v1.0)',
      results: compositeResults,
    );

    // Print Part 1 Summary Tables
    print('\n======================================================================');
    print('          PART 1: ZENODO NANTES OVERALL BENCHMARK (ALL 6,482 EPOCHS)');
    print('======================================================================');
    print(alwaysOutdoorMetrics.toMarkdownTable());
    print(yooMetrics.toMarkdownTable());
    print(deepIodTernaryMetrics.toMarkdownTable());
    print(deepIodBinaryMetrics.toMarkdownTable());
    print(compositeMetrics.toMarkdownTable());

    // ================================================================
    // PART 2: VERIFIED GROUND-TRUTH SUBSET EVALUATION
    // (Excluding the 304 unverified synthetic doorway transition epochs)
    // ================================================================
    print('\n======================================================================');
    print('  PART 2: VERIFIED GROUND-TRUTH EVALUATION (6,178 VERIFIED EPOCHS)');
    print('  (Filtering out 304 unverified doorway transition labels)');
    print('======================================================================');

    final verifiedBinaryIndices = <int>[];
    for (int i = 0; i < allZenodoSamples.length; i++) {
      if (allZenodoSamples[i].groundTruth != IndoorOutdoorState.transition) {
        verifiedBinaryIndices.add(i);
      }
    }

    final verifiedAlwaysOut = verifiedBinaryIndices.map((i) => alwaysOutdoorResults[i]).toList();
    final verifiedYoo = verifiedBinaryIndices.map((i) => yooResults[i]).toList();
    final verifiedDeepIodTernary = verifiedBinaryIndices.map((i) => deepIodTernaryResults[i]).toList();
    final verifiedDeepIodBinary = verifiedBinaryIndices.map((i) => deepIodBinaryResults[i]).toList();
    final verifiedComposite = verifiedBinaryIndices.map((i) => compositeResults[i]).toList();

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 6,178 Epochs)',
      modelName: 'Always-Outdoor Majority Baseline',
      results: verifiedAlwaysOut,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 6,178 Epochs)',
      modelName: 'SeamlessTransitionDetector (Yoo 2025)',
      results: verifiedYoo,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 6,178 Epochs)',
      modelName: 'DeepIOD Baseline (Aetron 3-State Ternary)',
      results: verifiedDeepIodTernary,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 6,178 Epochs)',
      modelName: 'DeepIOD Baseline (Native Published Binary Rule P>=0.5)',
      results: verifiedDeepIodBinary,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 6,178 Epochs)',
      modelName: 'IodCompositeClassifier (Aetron Ensemble v1.0)',
      results: verifiedComposite,
    ).toMarkdownTable());

    // ================================================================
    // PART 3: SCENARIO-BY-SCENARIO BREAKDOWN & FALSE TRANSITIONS
    // ================================================================
    print('\n======================================================================');
    print('       PART 3: SCENARIO-BY-SCENARIO ACCURACY & FALSE TRANSITIONS');
    print('======================================================================');

    for (final scenario in ['S1', 'S4', 'S2', 'S3', 'S5']) {
      final samples = samplesByScenario[scenario]!;
      if (samples.isEmpty) continue;

      int alwaysOutCorrect = 0;
      int yooCorrect = 0;
      int yooPredTrans = 0;
      int deepIodTernaryCorrect = 0;
      int deepIodTernaryPredTrans = 0;
      int deepIodBinaryCorrect = 0;
      int compositeCorrect = 0;
      int compositePredTrans = 0;

      final yooLocal = SeamlessTransitionDetector();
      final ensLocal = IodCompositeClassifier();

      for (final s in samples) {
        // Majority
        if (s.groundTruth == IndoorOutdoorState.outdoor) alwaysOutCorrect++;

        // Yoo
        final yp = yooLocal.evaluate(s.snapshot);
        if (yp.state == s.groundTruth) yooCorrect++;
        if (yp.state == IndoorOutdoorState.transition) yooPredTrans++;

        // DeepIOD Ternary
        final dpTernary = deepIodClassifier.classify(s.snapshot);
        if (dpTernary.state == s.groundTruth) deepIodTernaryCorrect++;
        if (dpTernary.state == IndoorOutdoorState.transition) deepIodTernaryPredTrans++;

        // DeepIOD Binary
        final pOut = dpTernary.deepIodOutdoorProbability ?? 0.5;
        final bState = pOut >= 0.50 ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
        if (bState == s.groundTruth) deepIodBinaryCorrect++;

        // Composite
        final cp = ensLocal.predict(s.snapshot);
        if (cp.state == s.groundTruth) compositeCorrect++;
        if (cp.state == IndoorOutdoorState.transition) compositePredTrans++;
      }

      final n = samples.length;
      print('Scenario $scenario ($n epochs):');
      print('  - Always-Outdoor:        ${(alwaysOutCorrect / n * 100).toStringAsFixed(2)}%');
      print('  - Yoo 2025 Adaptation:   ${(yooCorrect / n * 100).toStringAsFixed(2)}% (Predicted Transition: $yooPredTrans epochs)');
      print('  - DeepIOD 3-State:       ${(deepIodTernaryCorrect / n * 100).toStringAsFixed(2)}% (Predicted Transition: $deepIodTernaryPredTrans epochs)');
      print('  - DeepIOD Native Binary: ${(deepIodBinaryCorrect / n * 100).toStringAsFixed(2)}%');
      print('  - Aetron Ensemble v1.0:  ${(compositeCorrect / n * 100).toStringAsFixed(2)}% (Predicted Transition: $compositePredTrans epochs)');
    }

    // Export CSVs
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/zenodo_yoo_predictions.csv',
      yooResults,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/zenodo_deepiod_ternary_predictions.csv',
      deepIodTernaryResults,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/zenodo_deepiod_binary_predictions.csv',
      deepIodBinaryResults,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/zenodo_ensemble_predictions.csv',
      compositeResults,
    );

    // ================================================================
    // PART 4: UNIVERSITY OF CAMBRIDGE CIOD BENCHMARK
    // (Bakirtzis et al., DOI: 10.17863/CAM.82668; 1.47M rows, 85 sessions)
    // ================================================================
    print('\n======================================================================');
    print('  PART 4: UNIVERSITY OF CAMBRIDGE CIOD BENCHMARK (MULTI-SESSION REPLAY)');
    print('======================================================================');

    final ciodFile = File('tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv');
    if (ciodFile.existsSync()) {
      print('Loading Cambridge CIOD sessions (first 30 independent sessions)...');
      final ciodSamples = await CiodDatasetAdapter.parseCsvFile(
        file: ciodFile,
        maxSessions: 30,
        maxSamplesPerSession: 400,
      );
      print('Loaded ${ciodSamples.length} samples across Cambridge CIOD sessions.');

      // 1. Majority Baseline on Cambridge CIOD
      final ciodMajorityResults = <IodBenchmarkResult>[];
      for (final s in ciodSamples) {
        ciodMajorityResults.add(IodBenchmarkResult(
          sample: s,
          prediction: IodPrediction(
            state: IndoorOutdoorState.outdoor,
            confidence: 1.0,
            nativeClass: 'outdoor',
            modelVersion: 'majority-outdoor',
            inferenceLatencyMs: 0,
            sensorAvailability: const {},
            reasoningSummary: 'Always outdoor baseline',
            isObservationalOnly: true,
          ),
        ));
      }
      final ciodMajorityMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'Always-Outdoor Baseline',
        results: ciodMajorityResults,
      );
      print(ciodMajorityMetrics.toMarkdownTable());

      // 2. DeepIOD Native Binary on Cambridge CIOD
      final ciodDeepIodBinaryResults = <IodBenchmarkResult>[];
      for (final s in ciodSamples) {
        final pred = deepIodClassifier.classify(s.snapshot);
        final pOut = pred.deepIodOutdoorProbability ?? 0.5;
        final isOutdoor = pOut >= 0.50;
        final bState = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
        final bConf = isOutdoor
            ? ((pOut - 0.5) * 2.0).clamp(0.0, 1.0)
            : (((1.0 - pOut) - 0.5) * 2.0).clamp(0.0, 1.0);

        ciodDeepIodBinaryResults.add(IodBenchmarkResult(
          sample: s,
          prediction: IodPrediction(
            state: bState,
            confidence: bConf,
            deepIodOutdoorProbability: pOut,
            nativeClass: bState.code,
            modelVersion: 'deepiod-binary-ciod',
            inferenceLatencyMs: pred.inferenceLatencyMs,
            sensorAvailability: pred.sensorAvailability,
            reasoningSummary: pred.reasoningSummary,
            isObservationalOnly: true,
          ),
        ));
      }
      final ciodDeepIodBinaryMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'DeepIOD Baseline (Native Binary Rule P>=0.5)',
        results: ciodDeepIodBinaryResults,
      );
      print(ciodDeepIodBinaryMetrics.toMarkdownTable());

      // 3. DeepIOD Neural Classifier (Model C DWS-Conv2D Trained Network - Complete 8 Sensors)
      final ciodNeuralResults = <IodBenchmarkResult>[];
      final deepIodNeuralClassifier = DeepIodNeuralClassifier();
      for (final s in ciodSamples) {
        final pred = deepIodNeuralClassifier.classify(s.snapshot);
        ciodNeuralResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodNeuralMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'DeepIOD Neural Model C (8-Sensor Complete Network)',
        results: ciodNeuralResults,
      );
      print(ciodNeuralMetrics.toMarkdownTable());

      // 4. Dedicated Model C-Mobile (4-Sensor Genuine Mobile Network: Light, Mag, Acc, Daytime)
      final ciodMobileResults = <IodBenchmarkResult>[];
      final deepIodMobileClassifier = DeepIodNeuralClassifier.mobile();
      for (final s in ciodSamples) {
        final pred = deepIodMobileClassifier.classify(s.snapshot);
        ciodMobileResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodMobileMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'DeepIOD Model C-Mobile (4-Sensor Dedicated Mobile Network)',
        results: ciodMobileResults,
      );
      print(ciodMobileMetrics.toMarkdownTable());

      // 5. Application-Level IodCompositeClassifier (Ensemble with Yoo experimental transition signal)
      final ciodCompositeResults = <IodBenchmarkResult>[];
      final compositeClassifier = IodCompositeClassifier();
      for (final s in ciodSamples) {
        final pred = compositeClassifier.predict(s.snapshot);
        ciodCompositeResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodCompositeMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'Aetron IOD Composite Classifier (Application Output)',
        results: ciodCompositeResults,
      );
      print(ciodCompositeMetrics.toMarkdownTable());

      // 6. Yoo SeamlessTransitionDetector on Cambridge CIOD (Preserves missing GNSS as missing)
      final ciodYooResults = <IodBenchmarkResult>[];
      final ciodYoo = SeamlessTransitionDetector();
      for (final s in ciodSamples) {
        final pred = ciodYoo.evaluate(s.snapshot);
        ciodYooResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodYooMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD (Real Smartphone Sensors)',
        modelName: 'SeamlessTransitionDetector (Yoo 2025)',
        results: ciodYooResults,
      );
      print(ciodYooMetrics.toMarkdownTable());

      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_deepiod_model_c_predictions.csv',
        ciodNeuralResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_deepiod_mobile_predictions.csv',
        ciodMobileResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_composite_predictions.csv',
        ciodCompositeResults,
      );
      print('Cambridge CIOD prediction CSVs exported to ${outDir.path}');
    } else {
      print('Cambridge CIOD CSV not found at: ${ciodFile.path}');
    }

    print('\n================================================================');
    print('               ALL BENCHMARKS COMPLETED SUCCESSFULLY            ');
    print('================================================================');
  });
}
