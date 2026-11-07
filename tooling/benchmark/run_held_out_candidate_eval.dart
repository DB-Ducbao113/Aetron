// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ciod_dataset_adapter.dart';
import 'iod_benchmark_models.dart';
import 'mimir_dataset_adapter.dart';

void main() {
  test('Evaluate Candidate Models and Ablations on Held-Out Test Sets (Cambridge CIOD & Nantes Zenodo)', () async {
    print('======================================================================');
    print('  AETRON IOD CANDIDATE EVALUATION & ABLATION ON UNTOUCHED HELD-OUT SETS');
    print('======================================================================\n');

    final outDir = Directory('tooling/data/benchmark_results');
    outDir.createSync(recursive: true);

    final ciodFile = File('tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv');
    if (!ciodFile.existsSync()) {
      fail('Cambridge CIOD CSV not found at: ${ciodFile.path}');
    }

    final heldOutSessionIds = Set<int>.from(List.generate(13, (i) => 72 + i));

    // -------------------------------------------------------------------------
    // 1. UNIFORM 10,400 HELD-OUT SAMPLES (800-SAMPLE/SESSION CAP)
    // -------------------------------------------------------------------------
    print('>>> Loading 10,400 Held-Out Samples (Sessions 72..84, 800/session)...');
    final ciod10kSamples = await CiodDatasetAdapter.parseCsvFile(
      file: ciodFile,
      targetSessionIndices: heldOutSessionIds,
      maxSamplesPerSession: 800,
    );
    expect(ciod10kSamples.length, equals(10400));

    // 1A. Candidate 1: Calibrated Model C-Mobile (theta = 0.25) on 10,400 Samples
    final mobileCalibrated = DeepIodNeuralClassifier.mobile(classificationThreshold: 0.25);
    final results10kCalibrated = <IodBenchmarkResult>[];
    String? lastSess10k;
    for (final s in ciod10kSamples) {
      if (s.sessionId != lastSess10k) {
        mobileCalibrated.reset();
        lastSess10k = s.sessionId;
      }
      final pred = mobileCalibrated.classify(s.snapshot);
      results10kCalibrated.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    final metrics10kCalibrated = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Held-Out (10,400 samples)',
      modelName: 'Candidate: Calibrated Model C-Mobile (θ = 0.25)',
      results: results10kCalibrated,
    );
    print(metrics10kCalibrated.toMarkdownTable());

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_held_out_mobile_calibrated_predictions.csv',
      results10kCalibrated,
    );

    // -------------------------------------------------------------------------
    // 2. UNCAPPED FULL-SESSION HELD-OUT (201,731 SAMPLES)
    // -------------------------------------------------------------------------
    print('\n>>> Loading ALL 201,731 Held-Out Samples (Sessions 72..84, Uncapped)...');
    final ciod201kSamples = await CiodDatasetAdapter.parseCsvFile(
      file: ciodFile,
      targetSessionIndices: heldOutSessionIds,
      maxSamplesPerSession: 0,
    );
    expect(ciod201kSamples.length, equals(201731));

    // 2A. Candidate 1: Calibrated Model C-Mobile (theta = 0.25) on Full 201,731 Samples
    mobileCalibrated.reset();
    final results201kCalibrated = <IodBenchmarkResult>[];
    String? lastSess201k;
    for (final s in ciod201kSamples) {
      if (s.sessionId != lastSess201k) {
        mobileCalibrated.reset();
        lastSess201k = s.sessionId;
      }
      final pred = mobileCalibrated.classify(s.snapshot);
      results201kCalibrated.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    final metrics201kCalibrated = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (201,731 samples)',
      modelName: 'Candidate: Calibrated Model C-Mobile (θ = 0.25)',
      results: results201kCalibrated,
    );
    print(metrics201kCalibrated.toMarkdownTable());

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_mobile_calibrated_predictions.csv',
      results201kCalibrated,
    );

    // 2B. Candidate 2: Temporal Hysteresis [High=0.40, Low=0.20] on Full 201,731 Samples
    final mobileHysteresisRaw = DeepIodNeuralClassifier.mobile();
    final results201kHysteresis = <IodBenchmarkResult>[];
    String? lastSessHyst;
    IndoorOutdoorState hystState = IndoorOutdoorState.indoor;
    for (final s in ciod201kSamples) {
      if (s.sessionId != lastSessHyst) {
        mobileHysteresisRaw.reset();
        hystState = IndoorOutdoorState.indoor;
        lastSessHyst = s.sessionId;
      }
      final pred = mobileHysteresisRaw.classify(s.snapshot);
      final pOut = pred.deepIodOutdoorProbability ?? 0.50;
      if (hystState == IndoorOutdoorState.indoor && pOut >= 0.40) {
        hystState = IndoorOutdoorState.outdoor;
      } else if (hystState == IndoorOutdoorState.outdoor && pOut <= 0.20) {
        hystState = IndoorOutdoorState.indoor;
      }
      final hystPred = IodPrediction(
        state: hystState,
        confidence: hystState == IndoorOutdoorState.outdoor ? pOut : (1.0 - pOut),
        deepIodOutdoorProbability: pOut,
        nativeClass: hystState.code,
        modelVersion: 'candidate-c-mobile-hysteresis-v1.0',
        inferenceLatencyMs: pred.inferenceLatencyMs,
        sensorAvailability: pred.sensorAvailability,
        reasoningSummary: 'Temporal Hysteresis [High=0.40, Low=0.20]',
        isObservationalOnly: true,
      );
      results201kHysteresis.add(IodBenchmarkResult(sample: s, prediction: hystPred));
    }
    final metrics201kHysteresis = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (201,731 samples)',
      modelName: 'Candidate: Temporal Hysteresis Model C-Mobile [High=0.40, Low=0.20]',
      results: results201kHysteresis,
    );
    print(metrics201kHysteresis.toMarkdownTable());

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_mobile_hysteresis_predictions.csv',
      results201kHysteresis,
    );

    // 2C. Candidate 3: Composite GNSS-Assisted Experimental Mode
    final gnssAssistedClassifier = IodCompositeClassifier.gnssAssistedExperimental();
    final results201kGnssAssisted = <IodBenchmarkResult>[];
    String? lastSessGnss;
    for (final s in ciod201kSamples) {
      if (s.sessionId != lastSessGnss) {
        gnssAssistedClassifier.reset();
        lastSessGnss = s.sessionId;
      }
      final pred = gnssAssistedClassifier.predict(s.snapshot);
      results201kGnssAssisted.add(IodBenchmarkResult(sample: s, prediction: pred));
    }
    final metrics201kGnssAssisted = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD Full Held-Out (201,731 samples — GNSS Strictly Unavailable)',
      modelName: 'IodCompositeClassifier (GNSS-Assisted Experimental Mode)',
      results: results201kGnssAssisted,
    );
    print(metrics201kGnssAssisted.toMarkdownTable());

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_gnss_assisted_exp_predictions.csv',
      results201kGnssAssisted,
    );

    // -------------------------------------------------------------------------
    // 3. ABLATION STUDY A: LIGHT SENSOR ABLATION (SIMULATED POCKET/DARKNESS)
    // -------------------------------------------------------------------------
    print('\n======================================================================');
    print('  ABLATION STUDY A: LIGHT SENSOR ABLATION (SIMULATED POCKET/STOWED DARKNESS)');
    print('  (All samples have ambientLux set to 0.0 with hasLightSensor = false)');
    print('======================================================================');

    final results201kNoLightBaseline = <IodBenchmarkResult>[];
    final results201kNoLightCalibrated = <IodBenchmarkResult>[];
    final mobileDefault = DeepIodNeuralClassifier.mobile(classificationThreshold: 0.50);
    mobileCalibrated.reset();
    lastSess201k = null;

    for (final s in ciod201kSamples) {
      if (s.sessionId != lastSess201k) {
        mobileDefault.reset();
        mobileCalibrated.reset();
        lastSess201k = s.sessionId;
      }
      // Ablate light sensor completely (pocket stowed condition)
      final ablatedSnapshot = IodSensorSnapshot(
        timestamp: s.snapshot.timestamp,
        hasGnssStatus: s.snapshot.hasGnssStatus,
        satelliteCount: s.snapshot.satelliteCount,
        usedInFixCount: s.snapshot.usedInFixCount,
        meanCn0DbHz: s.snapshot.meanCn0DbHz,
        maxCn0DbHz: s.snapshot.maxCn0DbHz,
        top4Cn0DbHz: s.snapshot.top4Cn0DbHz,
        hasGpsFix: s.snapshot.hasGpsFix,
        latitude: s.snapshot.latitude,
        longitude: s.snapshot.longitude,
        horizontalAccuracy: s.snapshot.horizontalAccuracy,
        speed: s.snapshot.speed,
        altitude: s.snapshot.altitude,
        heading: s.snapshot.heading,
        hasLightSensor: false, // Ablated
        ambientLux: 0.0, // Ablated
        hasImuData: s.snapshot.hasImuData,
        accelMagnitudeMean: s.snapshot.accelMagnitudeMean,
        accelVariance: s.snapshot.accelVariance,
        magneticMagnitudeMean: s.snapshot.magneticMagnitudeMean,
        magneticVariance: s.snapshot.magneticVariance,
        stepDelta: s.snapshot.stepDelta,
        isNightTime: s.snapshot.isNightTime,
        isScreenOff: true, // Pocket condition
        hasTelephonyLte: s.snapshot.hasTelephonyLte,
        lteRsrpDbm: s.snapshot.lteRsrpDbm,
        lteRsrqDb: s.snapshot.lteRsrqDb,
        hasProximitySensor: true,
        proximityCm: 0.0, // Covered in pocket
      );

      final pDef = mobileDefault.classify(ablatedSnapshot);
      final pCal = mobileCalibrated.classify(ablatedSnapshot);

      results201kNoLightBaseline.add(IodBenchmarkResult(sample: s, prediction: pDef));
      results201kNoLightCalibrated.add(IodBenchmarkResult(sample: s, prediction: pCal));
    }

    final metricsNoLightDef = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD (201K Samples — Light Ablated / Stowed)',
      modelName: 'Model C-Mobile Baseline (θ = 0.50, Light Ablated)',
      results: results201kNoLightBaseline,
    );
    print(metricsNoLightDef.toMarkdownTable());

    final metricsNoLightCal = IodEvaluationMetrics.compute(
      datasetName: 'Cambridge CIOD (201K Samples — Light Ablated / Stowed)',
      modelName: 'Model C-Mobile Calibrated (θ = 0.25, Light Ablated)',
      results: results201kNoLightCalibrated,
    );
    print(metricsNoLightCal.toMarkdownTable());

    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_light_ablated_baseline_predictions.csv',
      results201kNoLightBaseline,
    );
    await IodEvaluationMetrics.exportToCsv(
      '${outDir.path}/ciod_full_held_out_light_ablated_calibrated_predictions.csv',
      results201kNoLightCalibrated,
    );

    // -------------------------------------------------------------------------
    // 4. ABLATION STUDY B: GNSS ABLATION ON ZENODO NANTES DATASET (PIXEL 7)
    // -------------------------------------------------------------------------
    print('\n======================================================================');
    print('  ABLATION STUDY B: GNSS AVAILABLE VS UNAVAILABLE (NANTES ZENODO DATASET)');
    print('  (Certified Ground Truth: S1 Open-sky & S4 Urban Canyon Outdoor, 3,180 Epochs)');
    print('======================================================================');

    final zenodoDir = Directory('tooling/data/zenodo_nantes/dataset');
    if (zenodoDir.existsSync()) {
      final zenodoSequences = [
        ('S1', 'A1', 'S1/A1/GP7/log_mimir_20240313111400.txt'),
        ('S1', 'A2', 'S1/A2/GP7/log_mimir_20240313112757.txt'),
        ('S4', 'A1', 'S4/A1/GP7/log_mimir_20240314144624.txt'),
        ('S4', 'A2', 'S4/A2/GP7/log_mimir_20240314151021.txt'),
      ];

      final outdoorSamples = <IodBenchmarkSample>[];
      for (final (scenario, acq, relPath) in zenodoSequences) {
        final f = File('${zenodoDir.path}/$relPath');
        if (!f.existsSync()) continue;
        final seqSamples = await MimirDatasetAdapter.parseLogFile(
          file: f,
          sessionId: '${scenario}_${acq}_GP7',
          scenarioId: scenario,
        );
        outdoorSamples.addAll(seqSamples.where((s) => s.labelProvenance == LabelProvenance.verifiedGroundTruth));
      }

      print('Loaded ${outdoorSamples.length} verified outdoor epochs from Nantes Zenodo (Pixel 7).');

      // Test Mode 1: With Genuine GNSS (GNSS Available via Pixel 7)
      final zenodoGnssAssistedResults = <IodBenchmarkResult>[];
      final zenodoClassifier = IodCompositeClassifier.gnssAssistedExperimental();
      String? lastZenodoSess;
      for (final s in outdoorSamples) {
        if (s.sessionId != lastZenodoSess) {
          zenodoClassifier.reset();
          lastZenodoSess = s.sessionId;
        }
        final pred = zenodoClassifier.predict(s.snapshot);
        zenodoGnssAssistedResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final metricsZenodoGnss = IodEvaluationMetrics.compute(
        datasetName: 'Zenodo Nantes (3,180 Verified Outdoor Epochs)',
        modelName: 'Candidate: Composite GNSS-Assisted Experimental (GNSS Available)',
        results: zenodoGnssAssistedResults,
      );
      print(metricsZenodoGnss.toMarkdownTable());

      // Test Mode 2: GNSS Ablated (Simulated GNSS Outage / Missing GNSS)
      final zenodoGnssAblatedResults = <IodBenchmarkResult>[];
      lastZenodoSess = null;
      for (final s in outdoorSamples) {
        if (s.sessionId != lastZenodoSess) {
          zenodoClassifier.reset();
          lastZenodoSess = s.sessionId;
        }
        // Mask out GNSS
        final noGnssSnap = IodSensorSnapshot(
          timestamp: s.snapshot.timestamp,
          hasGnssStatus: false, // Masked
          top4Cn0DbHz: null, // Masked
          satelliteCount: null,
          usedInFixCount: null,
          hasGpsFix: false,
          latitude: null,
          longitude: null,
          horizontalAccuracy: null,
          speed: null,
          altitude: null,
          heading: null,
          hasLightSensor: s.snapshot.hasLightSensor,
          ambientLux: s.snapshot.ambientLux,
          hasImuData: s.snapshot.hasImuData,
          accelMagnitudeMean: s.snapshot.accelMagnitudeMean,
          magneticMagnitudeMean: s.snapshot.magneticMagnitudeMean,
          magneticVariance: s.snapshot.magneticVariance,
          isNightTime: s.snapshot.isNightTime,
          isScreenOff: s.snapshot.isScreenOff,
          hasTelephonyLte: s.snapshot.hasTelephonyLte,
          lteRsrpDbm: s.snapshot.lteRsrpDbm,
          lteRsrqDb: s.snapshot.lteRsrqDb,
        );
        final pred = zenodoClassifier.predict(noGnssSnap);
        zenodoGnssAblatedResults.add(IodBenchmarkResult(sample: s, prediction: pred));
      }
      final metricsZenodoAblated = IodEvaluationMetrics.compute(
        datasetName: 'Zenodo Nantes (3,180 Verified Outdoor Epochs)',
        modelName: 'Candidate: Composite GNSS-Assisted (GNSS Ablated / Outage)',
        results: zenodoGnssAblatedResults,
      );
      print(metricsZenodoAblated.toMarkdownTable());

      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/zenodo_gnss_assisted_exp_predictions.csv',
        zenodoGnssAssistedResults,
      );
      await IodEvaluationMetrics.exportToCsv(
        '${outDir.path}/zenodo_gnss_ablated_predictions.csv',
        zenodoGnssAblatedResults,
      );
    }

    print('\n======================================================================');
    print('        ALL HELD-OUT CANDIDATE EVALUATIONS & ABLATIONS COMPLETE        ');
    print('======================================================================');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
