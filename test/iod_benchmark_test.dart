import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_baseline_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tooling/benchmark/ciod_dataset_adapter.dart';
import '../tooling/benchmark/iod_benchmark_models.dart';
import '../tooling/benchmark/mimir_dataset_adapter.dart';

void main() {
  group('IOD Benchmark Models & Metrics', () {
    test('computes precision, recall, F1, accuracy, and confusion matrix accurately', () {
      final now = DateTime.utc(2026, 11, 5, 12, 0, 0);

      // Construct synthetic benchmark results:
      // Outdoor: 3 samples -> 2 predicted outdoor (TP), 1 predicted transition (FN)
      // Indoor: 2 samples -> 2 predicted indoor (TP)
      // Transition: 1 sample -> 1 predicted transition (TP)
      final results = <IodBenchmarkResult>[
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's1',
            sequenceIndex: 0,
            timestamp: now,
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.outdoor,
            environmentType: 'open_sky',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.outdoor,
            confidence: 0.9,
            nativeClass: 'outdoor',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's1',
            sequenceIndex: 1,
            timestamp: now.add(const Duration(seconds: 1)),
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.outdoor,
            environmentType: 'open_sky',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.outdoor,
            confidence: 0.85,
            nativeClass: 'outdoor',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's1',
            sequenceIndex: 2,
            timestamp: now.add(const Duration(seconds: 2)),
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.outdoor,
            environmentType: 'open_sky',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.transition,
            confidence: 0.70,
            nativeClass: 'transition',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's2',
            sequenceIndex: 0,
            timestamp: now.add(const Duration(seconds: 10)),
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.indoor,
            environmentType: 'room',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.indoor,
            confidence: 0.95,
            nativeClass: 'indoor',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's2',
            sequenceIndex: 1,
            timestamp: now.add(const Duration(seconds: 11)),
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.indoor,
            environmentType: 'room',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.indoor,
            confidence: 0.88,
            nativeClass: 'indoor',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
        IodBenchmarkResult(
          sample: IodBenchmarkSample(
            sessionId: 's3',
            sequenceIndex: 0,
            timestamp: now.add(const Duration(seconds: 20)),
            snapshot: IodSensorSnapshot.empty(timestamp: now),
            groundTruth: IndoorOutdoorState.transition,
            environmentType: 'doorway',
          ),
          prediction: IodPrediction(
            state: IndoorOutdoorState.transition,
            confidence: 0.65,
            nativeClass: 'transition',
            modelVersion: 'test-v1',
            inferenceLatencyMs: 1,
            sensorAvailability: const {},
            reasoningSummary: 'test reasoning',
            isObservationalOnly: true,
          ),
        ),
      ];

      final metrics = IodEvaluationMetrics.compute(
        datasetName: 'Synthetic Test',
        modelName: 'Test Model',
        results: results,
      );

      expect(metrics.totalSamples, equals(6));
      expect(metrics.evaluatedSamples, equals(6));
      expect(metrics.unknownPredictionCount, equals(0));
      expect(metrics.coverage, equals(1.0));

      // Correct: 2 outdoor + 2 indoor + 1 transition = 5 out of 6
      expect(metrics.correctCount, equals(5));
      expect(metrics.accuracy, closeTo(5 / 6, 0.001));

      // Precision:
      // Outdoor: 2 TP, 0 FP -> Precision = 1.0
      expect(metrics.precision(IndoorOutdoorState.outdoor), equals(1.0));
      // Indoor: 2 TP, 0 FP -> Precision = 1.0
      expect(metrics.precision(IndoorOutdoorState.indoor), equals(1.0));
      // Transition: 1 TP, 1 FP (from outdoor) -> Precision = 1 / 2 = 0.5
      expect(metrics.precision(IndoorOutdoorState.transition), equals(0.5));

      // Recall:
      // Outdoor: 2 TP / 3 actual -> Recall = 2/3
      expect(metrics.recall(IndoorOutdoorState.outdoor), closeTo(2 / 3, 0.001));
      // Indoor: 2 TP / 2 actual -> Recall = 1.0
      expect(metrics.recall(IndoorOutdoorState.indoor), equals(1.0));
      // Transition: 1 TP / 1 actual -> Recall = 1.0
      expect(metrics.recall(IndoorOutdoorState.transition), equals(1.0));

      // F1:
      // Outdoor: 2 * (1.0 * 2/3) / (1.0 + 2/3) = 4/3 / 5/3 = 0.8
      expect(metrics.f1Score(IndoorOutdoorState.outdoor), closeTo(0.8, 0.001));
      // Indoor: 1.0
      expect(metrics.f1Score(IndoorOutdoorState.indoor), equals(1.0));
      // Transition: 2 * (0.5 * 1.0) / (0.5 + 1.0) = 1.0 / 1.5 = 2/3
      expect(metrics.f1Score(IndoorOutdoorState.transition), closeTo(2 / 3, 0.001));

      // Macro-F1: (0.8 + 1.0 + 0.6667) / 3 = 2.4667 / 3 = 0.8222
      expect(metrics.macroF1, closeTo((0.8 + 1.0 + (2 / 3)) / 3, 0.001));

      // Confusion matrix values
      expect(metrics.confusionMatrix[IndoorOutdoorState.outdoor]?[IndoorOutdoorState.outdoor], equals(2));
      expect(metrics.confusionMatrix[IndoorOutdoorState.outdoor]?[IndoorOutdoorState.transition], equals(1));
      expect(metrics.confusionMatrix[IndoorOutdoorState.indoor]?[IndoorOutdoorState.indoor], equals(2));
      expect(metrics.confusionMatrix[IndoorOutdoorState.transition]?[IndoorOutdoorState.transition], equals(1));

      final markdown = metrics.toMarkdownTable();
      expect(markdown, contains('### Benchmark Evaluation: Synthetic Test'));
      expect(markdown, contains('Accuracy'));
      expect(markdown, contains('Macro-F1'));
    });
  });

  group('Cambridge CIOD Dataset Adapter', () {
    test('parses multi-session CSV and respects sequence boundaries without leakage', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_ciod_${DateTime.now().millisecondsSinceEpoch}.csv');
      tempFile.writeAsStringSync(
        'Lux,AccX,AccY,AccZ,MagX,MagY,MagZ,GyrX,GyrY,GyrZ,New_seq,Label\n'
        '1500.0,0.1,0.2,9.8,20.0,20.0,-40.0,0.01,0.01,0.01,1,0\n'
        '1600.0,0.2,0.1,9.8,20.1,20.2,-39.8,0.02,0.01,0.01,0,0\n'
        '50.0,0.1,0.1,9.8,40.0,-10.0,50.0,0.00,0.00,0.00,1,1\n'
        '45.0,0.1,0.1,9.8,41.0,-10.2,50.5,0.00,0.00,0.00,0,1\n',
      );

      final samples = await CiodDatasetAdapter.parseCsvFile(file: tempFile);
      tempFile.deleteSync();

      expect(samples.length, equals(4));

      // First sequence (outdoor)
      expect(samples[0].sessionId, equals('CIOD_session_1'));
      expect(samples[0].groundTruth, equals(IndoorOutdoorState.outdoor));
      expect(samples[0].snapshot.ambientLux, equals(1500.0));
      expect(samples[0].snapshot.hasLightSensor, isTrue);
      expect(samples[0].snapshot.hasGnssStatus, isFalse); // Never fabricated

      expect(samples[1].sessionId, equals('CIOD_session_1'));
      expect(samples[1].groundTruth, equals(IndoorOutdoorState.outdoor));

      // Second sequence (indoor)
      expect(samples[2].sessionId, equals('CIOD_session_2'));
      expect(samples[2].groundTruth, equals(IndoorOutdoorState.indoor));
      expect(samples[2].snapshot.ambientLux, equals(50.0));

      expect(samples[3].sessionId, equals('CIOD_session_2'));
      expect(samples[3].groundTruth, equals(IndoorOutdoorState.indoor));

      // Replay through Aetron DeepIOD baseline classifier
      final classifier = DeepIodBaselineClassifier();
      final predOutdoor = classifier.classify(samples[0].snapshot);
      expect(predOutdoor.state, equals(IndoorOutdoorState.outdoor));

      final predIndoor = classifier.classify(samples[2].snapshot);
      expect(predIndoor.state, equals(IndoorOutdoorState.indoor));
    });
  });

  group('Mimir / Android GNSS Dataset Adapter', () {
    test('aggregates GNSS raw measurements into 1-second epochs', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_mimir_${DateTime.now().millisecondsSinceEpoch}.txt');
      tempFile.writeAsStringSync(
        '# Header\n'
        'Raw,1710324840100,0,0,0,0,0,0,0,0,0,1,0,0,0,0,42.5\n'
        'Raw,1710324840200,0,0,0,0,0,0,0,0,0,2,0,0,0,0,38.0\n'
        'Raw,1710324840300,0,0,0,0,0,0,0,0,0,3,0,0,0,0,36.5\n'
        'Raw,1710324840400,0,0,0,0,0,0,0,0,0,4,0,0,0,0,34.0\n'
        'Raw,1710324840500,0,0,0,0,0,0,0,0,0,5,0,0,0,0,28.0\n'
        'Fix,gps,47.156,-1.640,100.0,1.2,4.5,90.0,1710324840500\n'
        'ACC_UNCAL,1710324840100,0,0.0,0.0,9.81\n'
        'MAG_UNCAL,1710324840100,0,10.0,20.0,30.0\n',
      );

      final samples = await MimirDatasetAdapter.parseLogFile(
        file: tempFile,
        sessionId: 'test_session',
        scenarioId: 'S1',
      );
      tempFile.deleteSync();

      expect(samples.length, equals(1));
      final s = samples.first;
      expect(s.groundTruth, equals(IndoorOutdoorState.outdoor));
      expect(s.snapshot.hasGnssStatus, isTrue);
      expect(s.snapshot.satelliteCount, equals(5));
      expect(s.snapshot.maxCn0DbHz, equals(42.5));

      // Top 4 CN0: 42.5, 38.0, 36.5, 34.0 -> average = 151.0 / 4 = 37.75
      expect(s.snapshot.top4Cn0DbHz, closeTo(37.75, 0.01));

      // Mean CN0: (42.5 + 38.0 + 36.5 + 34.0 + 28.0) / 5 = 179.0 / 5 = 35.8
      expect(s.snapshot.meanCn0DbHz, closeTo(35.8, 0.01));

      // Has GPS fix
      expect(s.snapshot.hasGpsFix, isTrue);
      expect(s.snapshot.horizontalAccuracy, equals(4.5));
      expect(s.snapshot.speed, equals(1.2));

      // Has IMU
      expect(s.snapshot.hasImuData, isTrue);
      expect(s.snapshot.accelMagnitudeMean, closeTo(9.81, 0.01));

      // Light is not fabricated
      expect(s.snapshot.hasLightSensor, isFalse);
      expect(s.snapshot.ambientLux, isNull);

      // Replay through SeamlessTransitionDetector (Yoo 2025)
      final yoo = SeamlessTransitionDetector();
      final yooPred = yoo.evaluate(s.snapshot);
      // Top4 is 37.75 dB-Hz, between 30 and 40 -> Yoo evaluates boundary / transition zone
      expect(yooPred.state, anyOf([IndoorOutdoorState.transition, IndoorOutdoorState.outdoor]));

      // Replay through Ensemble
      final ensemble = IodCompositeClassifier();
      final ensPred = ensemble.predict(s.snapshot);
      expect(ensPred.state, anyOf([IndoorOutdoorState.transition, IndoorOutdoorState.outdoor]));
    });
  });
}
