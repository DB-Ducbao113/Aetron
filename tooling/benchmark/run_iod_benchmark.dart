// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/radio_map.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/transition_handover_event.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_baseline_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_framework_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ciod_dataset_adapter.dart';
import 'iod_benchmark_models.dart';
import 'mimir_dataset_adapter.dart';

void main() {
  test(
    'IOD Benchmark Suite on Published Datasets (Zenodo & Cambridge CIOD)',
    () async {
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
    // (Filtering strictly by LabelProvenance.verifiedGroundTruth: S1 & S4 Outdoor Only)
    // ================================================================
    print('\n======================================================================');
    print('  PART 2: VERIFIED GROUND-TRUTH EVALUATION (3,180 VERIFIED OUTDOOR EPOCHS)');
    print('  (Filtering strictly by LabelProvenance.verifiedGroundTruth: S1 & S4)');
    print('======================================================================');

    final verifiedIndices = <int>[];
    for (int i = 0; i < allZenodoSamples.length; i++) {
      if (allZenodoSamples[i].labelProvenance == LabelProvenance.verifiedGroundTruth) {
        verifiedIndices.add(i);
      }
    }

    final verifiedAlwaysOut = verifiedIndices.map((i) => alwaysOutdoorResults[i]).toList();
    final verifiedYoo = verifiedIndices.map((i) => yooResults[i]).toList();
    final verifiedDeepIodTernary = verifiedIndices.map((i) => deepIodTernaryResults[i]).toList();
    final verifiedDeepIodBinary = verifiedIndices.map((i) => deepIodBinaryResults[i]).toList();
    final verifiedComposite = verifiedIndices.map((i) => compositeResults[i]).toList();

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 3,180 Epochs — S1 & S4)',
      modelName: 'Always-Outdoor Majority Baseline',
      results: verifiedAlwaysOut,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 3,180 Epochs — S1 & S4)',
      modelName: 'SeamlessTransitionDetector (Yoo 2025)',
      results: verifiedYoo,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 3,180 Epochs — S1 & S4)',
      modelName: 'DeepIOD Baseline (Aetron 3-State Ternary)',
      results: verifiedDeepIodTernary,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 3,180 Epochs — S1 & S4)',
      modelName: 'DeepIOD Baseline (Native Published Binary Rule P>=0.5)',
      results: verifiedDeepIodBinary,
    ).toMarkdownTable());

    print(IodEvaluationMetrics.compute(
      datasetName: 'Zenodo Nantes (Verified Ground Truth: 3,180 Epochs — S1 & S4)',
      modelName: 'IodCompositeClassifier (Aetron Ensemble v1.0)',
      results: verifiedComposite,
    ).toMarkdownTable());

    // ================================================================
    // PART 3: EXPLORATORY SCENARIO EVALUATION (INFERRED MACRO SCENARIOS S2, S3, S5)
    // (Notice: S2, S3, and S5 scenario labels are macro-inferred and lack
    // micro-timestamped doorway ground truth. These are exploratory diagnostics.)
    // ================================================================
    print('\n======================================================================');
    print('  PART 3: EXPLORATORY EVALUATION OF INFERRED MACRO SCENARIOS (S2, S3, S5)');
    print('  (DISCLOSURE: Macro-scenario annotations without certified doorway ground truth)');
    print('======================================================================');

    void evaluateScenarioGroup(String title, List<String> groupScenarios) {
      print('\n--- $title ---');
      for (final scenario in groupScenarios) {
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
    }

    evaluateScenarioGroup('VERIFIED GROUND-TRUTH SCENARIOS (Certified 100% Outdoor)', ['S1', 'S4']);
    evaluateScenarioGroup('EXPLORATORY INFERRED SCENARIOS (Macro Inferred — Doorway Boundaries Unverified)', ['S2', 'S3', 'S5']);

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
    print('  PART 4A: UNIVERSITY OF CAMBRIDGE CIOD — HELD-OUT INDEPENDENT TEST SET');
    print('  (SESSIONS 72..84, 13 UNSEEN SESSIONS, 10,400 EPOCHS)');
    print('======================================================================');

    final ciodFile = File('tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv');
    if (ciodFile.existsSync()) {
      // 1. Load strictly held-out sessions (72..84)
      final heldOutSessionIds = Set<int>.from(List.generate(13, (i) => 72 + i));
      print('Loading Cambridge CIOD held-out test sessions (Sessions 72..84)...');
      final ciodHeldOutSamples = await CiodDatasetAdapter.parseCsvFile(
        file: ciodFile,
        targetSessionIndices: heldOutSessionIds,
        maxSamplesPerSession: 800,
      );
      print('Loaded ${ciodHeldOutSamples.length} samples across 13 held-out Cambridge CIOD sessions.');

      // Baseline A: Always-Indoor Majority Baseline (Held-Out)
      final ciodAlwaysIndoorResults = <IodBenchmarkResult>[];
      for (final s in ciodHeldOutSamples) {
        ciodAlwaysIndoorResults.add(IodBenchmarkResult(
          sample: s,
          prediction: IodPrediction(
            state: IndoorOutdoorState.indoor,
            confidence: 1.0,
            nativeClass: 'indoor',
            modelVersion: 'majority-always-indoor',
            inferenceLatencyMs: 0,
            sensorAvailability: const {},
            reasoningSummary: 'Always-Indoor baseline (held-out test)',
            isObservationalOnly: true,
          ),
        ));
      }
      final ciodAlwaysIndoorMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'Always-Indoor Majority Baseline',
        results: ciodAlwaysIndoorResults,
      );
      print(ciodAlwaysIndoorMetrics.toMarkdownTable());

      // Baseline B: Always-Outdoor Baseline (Held-Out)
      final ciodAlwaysOutdoorResults = <IodBenchmarkResult>[];
      for (final s in ciodHeldOutSamples) {
        ciodAlwaysOutdoorResults.add(IodBenchmarkResult(
          sample: s,
          prediction: IodPrediction(
            state: IndoorOutdoorState.outdoor,
            confidence: 1.0,
            nativeClass: 'outdoor',
            modelVersion: 'majority-always-outdoor',
            inferenceLatencyMs: 0,
            sensorAvailability: const {},
            reasoningSummary: 'Always-Outdoor baseline (held-out test)',
            isObservationalOnly: true,
          ),
        ));
      }
      final ciodAlwaysOutdoorMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'Always-Outdoor Baseline',
        results: ciodAlwaysOutdoorResults,
      );
      print(ciodAlwaysOutdoorMetrics.toMarkdownTable());

      // Baseline C: DeepIOD Literature Heuristic Baseline (Held-Out)
      final ciodHeuristicResults = <IodBenchmarkResult>[];
      final ciodHeuristicClassifier = DeepIodBaselineClassifier();
      for (final s in ciodHeldOutSamples) {
        final pred = ciodHeuristicClassifier.classify(s.snapshot);
        final pOut = pred.deepIodOutdoorProbability ?? 0.5;
        final isOutdoor = pOut >= 0.50;
        final bState = isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
        final bConf = isOutdoor
            ? ((pOut - 0.5) * 2.0).clamp(0.0, 1.0)
            : (((1.0 - pOut) - 0.5) * 2.0).clamp(0.0, 1.0);

        ciodHeuristicResults.add(IodBenchmarkResult(
          sample: s,
          prediction: IodPrediction(
            state: bState,
            confidence: bConf,
            deepIodOutdoorProbability: pOut,
            nativeClass: bState.code,
            modelVersion: 'deepiod-baseline-heuristic',
            inferenceLatencyMs: pred.inferenceLatencyMs,
            sensorAvailability: pred.sensorAvailability,
            reasoningSummary: pred.reasoningSummary,
            isObservationalOnly: true,
          ),
        ));
      }
      final ciodHeuristicMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Literature Heuristic Baseline',
        results: ciodHeuristicResults,
      );
      print(ciodHeuristicMetrics.toMarkdownTable());

      // Model 1: DeepIOD Model A (1D-CNN + LSTM Sequence Decoder - Held-Out)
      final ciodModelAResults = <IodBenchmarkResult>[];
      final deepIodFramework = DeepIodFrameworkClassifier();
      String? lastSessIdA;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdA) {
          deepIodFramework.reset();
          lastSessIdA = s.sessionId;
        }
        final pred = deepIodFramework.classifyModelA(s.snapshot);
        ciodModelAResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodModelAMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Model A (1D-CNN + LSTM)',
        results: ciodModelAResults,
      );
      print(ciodModelAMetrics.toMarkdownTable());

      // Model 2: DeepIOD Model B (1D-CNN + Multi-Head Attention - Held-Out)
      final ciodModelBResults = <IodBenchmarkResult>[];
      deepIodFramework.reset();
      String? lastSessIdB;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdB) {
          deepIodFramework.reset();
          lastSessIdB = s.sessionId;
        }
        final pred = deepIodFramework.classifyModelB(s.snapshot);
        ciodModelBResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodModelBMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Model B (1D-CNN + MHA)',
        results: ciodModelBResults,
      );
      print(ciodModelBMetrics.toMarkdownTable());

      // Model 3: DeepIOD Neural Model C (8-Sensor Complete Network - Held-Out)
      final ciodNeuralCompleteResults = <IodBenchmarkResult>[];
      final deepIodCompleteClassifier = DeepIodNeuralClassifier.complete();
      String? lastSessId1;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessId1) {
          deepIodCompleteClassifier.reset();
          lastSessId1 = s.sessionId;
        }
        final pred = deepIodCompleteClassifier.classify(s.snapshot);
        ciodNeuralCompleteResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodNeuralCompleteMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Neural Model C (8-Sensor Complete Network)',
        results: ciodNeuralCompleteResults,
      );
      print(ciodNeuralCompleteMetrics.toMarkdownTable());

      // Model 4: DeepIOD Neural AMV Ensemble (Consensus of Models A, B, C)
      final ciodAmvResults = <IodBenchmarkResult>[];
      deepIodFramework.reset();
      String? lastSessIdAmv;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdAmv) {
          deepIodFramework.reset();
          lastSessIdAmv = s.sessionId;
        }
        final pred = deepIodFramework.classifyNeuralAmv(s.snapshot);
        ciodAmvResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodAmvMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Neural AMV (Published Eq. 9 Probability-Weighted Linear Voting)',
        results: ciodAmvResults,
      );
      print(ciodAmvMetrics.toMarkdownTable());

      // Model 4b: Discrete Hard Majority Voting (Binary Decision Consensus)
      final ciodHardAmvResults = <IodBenchmarkResult>[];
      final deepIodFrameworkHard = DeepIodFrameworkClassifier(
        amvMethod: DeepIodAmvMethod.hardMajorityVoting,
      );
      String? lastSessIdHard;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdHard) {
          deepIodFrameworkHard.reset();
          lastSessIdHard = s.sessionId;
        }
        final pred = deepIodFrameworkHard.classifyNeuralAmv(s.snapshot);
        ciodHardAmvResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodHardAmvMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Neural AMV (Discrete Hard Majority Voting)',
        results: ciodHardAmvResults,
      );
      print(ciodHardAmvMetrics.toMarkdownTable());

      // Model 4c: Aetron Experimental Bayesian Likelihood Fusion (Aetron Extension)
      final ciodAmvBayesResults = <IodBenchmarkResult>[];
      final deepIodFrameworkBayes = DeepIodFrameworkClassifier(
        amvMethod: DeepIodAmvMethod.aetronBayesianFusion,
      );
      String? lastSessIdAmvB;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdAmvB) {
          deepIodFrameworkBayes.reset();
          lastSessIdAmvB = s.sessionId;
        }
        final pred = deepIodFrameworkBayes.classifyNeuralAmv(s.snapshot);
        ciodAmvBayesResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodAmvBayesMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'Aetron Experimental Bayesian Fusion (Auxiliary Extension)',
        results: ciodAmvBayesResults,
      );
      print(ciodAmvBayesMetrics.toMarkdownTable());

      // Model 5: DeepIOD Full Framework (Published Eq. 9 AMV + Light Eq. 7 + GPS Eq. 8)
      final ciodFullFrameworkResults = <IodBenchmarkResult>[];
      deepIodFramework.reset();
      String? lastSessIdFull;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdFull) {
          deepIodFramework.reset();
          lastSessIdFull = s.sessionId;
        }
        final pred = deepIodFramework.classify(s.snapshot);
        ciodFullFrameworkResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodFullFrameworkMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Full Framework (Published Eq. 9 AMV + Light Eq. 7 + GPS Eq. 8)',
        results: ciodFullFrameworkResults,
      );
      print(ciodFullFrameworkMetrics.toMarkdownTable());

      // Model 5b: Aetron Full Framework (Aetron Bayesian Fusion + Light Eq. 7 + GPS Eq. 8)
      final ciodFullBayesResults = <IodBenchmarkResult>[];
      deepIodFrameworkBayes.reset();
      String? lastSessIdFullB;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessIdFullB) {
          deepIodFrameworkBayes.reset();
          lastSessIdFullB = s.sessionId;
        }
        final pred = deepIodFrameworkBayes.classify(s.snapshot);
        ciodFullBayesResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodFullBayesMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'Aetron Full Framework (Bayesian Fusion + Light + GPS)',
        results: ciodFullBayesResults,
      );
      print(ciodFullBayesMetrics.toMarkdownTable());

      // Model 6: Dedicated Model C-Mobile (4-Sensor Dedicated Mobile Network — Deployed Adapted Baseline)
      final ciodMobileResults = <IodBenchmarkResult>[];
      final deepIodMobileClassifier = DeepIodNeuralClassifier.mobile();
      String? lastSessId2;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessId2) {
          deepIodMobileClassifier.reset();
          lastSessId2 = s.sessionId;
        }
        final pred = deepIodMobileClassifier.classify(s.snapshot);
        ciodMobileResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodMobileMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'DeepIOD Model C-Mobile (4-Sensor Dedicated Mobile Network — Deployed)',
        results: ciodMobileResults,
      );
      print(ciodMobileMetrics.toMarkdownTable());

      // Model 7: Aetron IOD Composite Classifier (Application Output — Model C-Mobile Default)
      final ciodCompositeResults = <IodBenchmarkResult>[];
      final compositeClassifier = IodCompositeClassifier();
      String? lastSessId3;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessId3) {
          compositeClassifier.reset();
          lastSessId3 = s.sessionId;
        }
        final pred = compositeClassifier.predict(s.snapshot);
        ciodCompositeResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodCompositeMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'Aetron IOD Composite Classifier (Application Output)',
        results: ciodCompositeResults,
      );
      print(ciodCompositeMetrics.toMarkdownTable());

      // Baseline H: Yoo SeamlessTransitionDetector (Held-Out, cleanly abstains on missing GNSS)
      final ciodYooResults = <IodBenchmarkResult>[];
      final ciodYoo = SeamlessTransitionDetector();
      String? lastSessId4;
      for (final s in ciodHeldOutSamples) {
        if (s.sessionId != lastSessId4) {
          ciodYoo.reset();
          lastSessId4 = s.sessionId;
        }
        final pred = ciodYoo.evaluate(s.snapshot);
        ciodYooResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final ciodYooMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Held-Out (Sessions 72..84)',
        modelName: 'SeamlessTransitionDetector (Yoo 2025)',
        results: ciodYooResults,
      );
      print(ciodYooMetrics.toMarkdownTable());

      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_model_a_predictions.csv',
        ciodModelAResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_model_b_predictions.csv',
        ciodModelBResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_model_c_predictions.csv',
        ciodNeuralCompleteResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_amv_neural_predictions.csv',
        ciodAmvResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_amv_hard_predictions.csv',
        ciodHardAmvResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_amv_bayes_predictions.csv',
        ciodAmvBayesResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_full_framework_predictions.csv',
        ciodFullFrameworkResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_full_bayes_predictions.csv',
        ciodFullBayesResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_mobile_predictions.csv',
        ciodMobileResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_composite_predictions.csv',
        ciodCompositeResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_held_out_yoo_predictions.csv',
        ciodYooResults,
      );
      print('Cambridge CIOD held-out prediction CSVs exported to: ${outDir.path}\n');

      // ================================================================
      // PART 4B: TRAINING-SET DIAGNOSTIC REPLAY (SESSIONS 0..29)
      // (FOR OVERFITTING AUDIT & REPRODUCIBILITY VERIFICATION ONLY)
      // ================================================================
      print('======================================================================');
      print('  PART 4B: CAMBRIDGE CIOD — TRAINING-SET DIAGNOSTIC REPLAY (SESSIONS 0..29)');
      print('  (DIAGNOSTIC AUDIT ONLY — NOT INDEPENDENT VALIDATION)');
      print('======================================================================');

      final trainSessionIds = Set<int>.from(List.generate(30, (i) => i));
      final ciodTrainSamples = await CiodDatasetAdapter.parseCsvFile(
        file: ciodFile,
        targetSessionIndices: trainSessionIds,
        maxSamplesPerSession: 400,
      );
      print('Loaded ${ciodTrainSamples.length} diagnostic training samples across 30 sessions.');

      final trainNeuralResults = <IodBenchmarkResult>[];
      final trainClassifier = DeepIodNeuralClassifier.mobile();
      String? lastTrainSessId;
      for (final s in ciodTrainSamples) {
        if (s.sessionId != lastTrainSessId) {
          trainClassifier.reset();
          lastTrainSessId = s.sessionId;
        }
        final pred = trainClassifier.classify(s.snapshot);
        trainNeuralResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final trainMetrics = IodEvaluationMetrics.compute(
        datasetName: 'Cambridge CIOD Training-Set Replay (Sessions 0..29)',
        modelName: 'DeepIOD Model C-Mobile (Diagnostic Training Replay)',
        results: trainNeuralResults,
      );
      print(trainMetrics.toMarkdownTable());
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/ciod_train_diagnostic_predictions.csv',
        trainNeuralResults,
      );
    } else {
      print('Cambridge CIOD CSV not found at: ${ciodFile.path}');
    }

    // ================================================================
    // PART 5: SYNTHETIC INTEGRATION TEST — YOO TRANSITION STATE MACHINE & W-KNN LOGIC
    // (SYNTHETIC UNIT/INTEGRATION TEST ONLY — NOT SCIENTIFIC BENCHMARK CLAIM)
    // ================================================================
    print('======================================================================');
    print('  PART 5: SYNTHETIC INTEGRATION TEST — YOO TRANSITION STATE MACHINE & W-KNN');
    print('  (NOTICE: 30 handcrafted epochs + mock RadioMap verify algorithm logic');
    print('   and handover delay under ideal conditions. THIS IS A SYNTHETIC INTEGRATION');
    print('   TEST AND MUST NOT BE CITED AS A REAL-WORLD DATASET BENCHMARK RESULT.)');
    print('======================================================================');

    final transitionRadioMap = const RadioMap(
      id: 'hymn_facility_map',
      buildingName: 'Transition Facility Complex',
      points: [
        RadioFingerprintPoint(
          id: 'fp_plaza_outdoor',
          name: 'Outdoor Entrance Plaza',
          state: IndoorOutdoorState.outdoor,
          latitude: 10.7775,
          longitude: 106.7015,
          wifiRssiDbm: {'AP_OUTDOOR_1': -50.0, 'AP_OUTDOOR_2': -55.0, 'AP_INDOOR_1': -92.0},
        ),
        RadioFingerprintPoint(
          id: 'fp_doorway_foyer',
          name: 'Building Glass Entrance Foyer',
          state: IndoorOutdoorState.transition,
          latitude: 10.7769,
          longitude: 106.7009,
          wifiRssiDbm: {'AP_OUTDOOR_1': -70.0, 'AP_OUTDOOR_2': -75.0, 'AP_INDOOR_1': -68.0},
          bleRssiDbm: {'BEACON_FOYER': -62.0},
        ),
        RadioFingerprintPoint(
          id: 'fp_indoor_hall',
          name: 'Main Hallway 1st Floor',
          state: IndoorOutdoorState.indoor,
          latitude: 10.7765,
          longitude: 106.7005,
          wifiRssiDbm: {'AP_OUTDOOR_1': -98.0, 'AP_OUTDOOR_2': -100.0, 'AP_INDOOR_1': -45.0},
        ),
      ],
    );

    final transitionDoorway = const BuildingTransitionPoint(
      id: 'door_foyer',
      name: 'Glass Entrance Foyer Doorway',
      latitude: 10.7769,
      longitude: 106.7009,
      radiusMeters: 5.0,
    );

    final yooFullDetector = SeamlessTransitionDetector(
      transitionPoints: [transitionDoorway],
      radioMap: transitionRadioMap,
    );

    final tBase = DateTime(2026, 6, 1, 14, 0, 0);
    final transitionBenchmarkSamples = <IodBenchmarkSample>[];

    // Phase A: Epochs 0..9 -> Clear outdoor walking in plaza towards entrance
    for (int i = 0; i < 10; i++) {
      final t = tBase.add(Duration(seconds: i));
      transitionBenchmarkSamples.add(IodBenchmarkSample(
        timestamp: t,
        groundTruth: IndoorOutdoorState.outdoor,
        sessionId: 'trans_corridor_01',
        sequenceIndex: i,
        environmentType: 'plaza_outdoor',
        snapshot: IodSensorSnapshot(
          timestamp: t,
          hasGpsFix: true,
          latitude: 10.7775 - (i * 0.00004),
          longitude: 106.7015 - (i * 0.00004),
          horizontalAccuracy: 4.0,
          hasGnssStatus: true,
          top4Cn0DbHz: 42.0,
          usedInFixCount: 9,
          hasWifiScan: true,
          wifiFingerprint: {'AP_OUTDOOR_1': -51.0, 'AP_OUTDOOR_2': -56.0, 'AP_INDOOR_1': -91.0},
          stepDelta: 2,
          speed: 1.2,
        ),
      ));
    }

    // Phase B: Epochs 10..19 -> Crossing glass doorway foyer (Transition zone)
    final doorwayEntryTime = tBase.add(const Duration(seconds: 10));
    for (int i = 10; i < 20; i++) {
      final t = tBase.add(Duration(seconds: i));
      transitionBenchmarkSamples.add(IodBenchmarkSample(
        timestamp: t,
        groundTruth: IndoorOutdoorState.transition,
        sessionId: 'trans_corridor_01',
        sequenceIndex: i,
        environmentType: 'doorway_foyer_transition',
        snapshot: IodSensorSnapshot(
          timestamp: t,
          hasGpsFix: true,
          latitude: 10.7769,
          longitude: 106.7009,
          horizontalAccuracy: 12.0,
          hasGnssStatus: true,
          top4Cn0DbHz: 35.0, // intermediate C/N0 in transition
          usedInFixCount: 4,
          hasWifiScan: true,
          wifiFingerprint: {'AP_OUTDOOR_1': -71.0, 'AP_OUTDOOR_2': -74.0, 'AP_INDOOR_1': -67.0},
          hasBleScan: true,
          bleFingerprint: {'BEACON_FOYER': -61.0},
          stepDelta: 2,
          speed: 1.0,
        ),
      ));
    }

    // Phase C: Epochs 20..29 -> Deep indoor hallway (Indoor zone)
    for (int i = 20; i < 30; i++) {
      final t = tBase.add(Duration(seconds: i));
      transitionBenchmarkSamples.add(IodBenchmarkSample(
        timestamp: t,
        groundTruth: IndoorOutdoorState.indoor,
        sessionId: 'trans_corridor_01',
        sequenceIndex: i,
        environmentType: 'deep_indoor_hallway',
        snapshot: IodSensorSnapshot(
          timestamp: t,
          hasGpsFix: false,
          latitude: 10.7765,
          longitude: 106.7005,
          horizontalAccuracy: 45.0,
          hasGnssStatus: true,
          top4Cn0DbHz: 21.0, // blocked GNSS inside building
          usedInFixCount: 1,
          hasWifiScan: true,
          wifiFingerprint: {'AP_OUTDOOR_1': -99.0, 'AP_OUTDOOR_2': -100.0, 'AP_INDOOR_1': -44.0},
          stepDelta: 2,
          speed: 1.1,
        ),
      ));
    }

    final yooFullResults = <IodBenchmarkResult>[];
    DateTime? firstTransitionDetectedTime;

    for (final s in transitionBenchmarkSamples) {
      final pred = yooFullDetector.evaluate(s.snapshot);
      yooFullResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      if (pred.state == IndoorOutdoorState.transition && firstTransitionDetectedTime == null) {
        firstTransitionDetectedTime = s.timestamp;
      }
    }

    final yooFullMetrics = IodEvaluationMetrics.compute(
      datasetName: 'Synthetic Integration Scenario (30 Mock Epochs — Logic Verification)',
      modelName: 'SeamlessTransitionDetector (Synthetic W-KNN + Handover Verification)',
      results: yooFullResults,
    );
    print(yooFullMetrics.toMarkdownTable());

    final transitionDelaySec = firstTransitionDetectedTime != null
        ? firstTransitionDetectedTime.difference(doorwayEntryTime).inSeconds
        : -1;
    print('\n- Transition Detection Delay: ${transitionDelaySec}s');
    print('- Handover Events Logged:     ${yooFullDetector.handoverEvents.length}');
    for (final ev in yooFullDetector.handoverEvents) {
      print('  * ${ev.timestamp.toIso8601String()}: ${ev.fromState.code.toUpperCase()} -> ${ev.toState.code.toUpperCase()} (${ev.triggerReason})');
    }

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/yoo_transition_framework_predictions.csv',
      yooFullResults,
    );

    print('\n================================================================');
    print('               ALL BENCHMARKS COMPLETED SUCCESSFULLY            ');
    print('================================================================');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
