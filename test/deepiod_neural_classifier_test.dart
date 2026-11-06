import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/transition_handover_event.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_framework_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_a.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_b.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_c.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepIOD Neural Classifier Tests (Sensors 2024 Reproduction)', () {
    late DeepIodNeuralClassifier classifier;

    setUp(() {
      classifier = DeepIodNeuralClassifier();
    });

    test('Clear Outdoor Condition: Strong Daylight + High C/N0 -> Predicts Outdoor', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: true,
        ambientLux: 12000.0, // Bright sunlight
        hasGnssStatus: true,
        top4Cn0DbHz: 39.5,
        satelliteCount: 14,
        hasImuData: true,
        magneticMagnitudeMean: 45.0,
        accelMagnitudeMean: 0.85, // Linear acceleration without gravity (m/s^2)
        magneticVariance: 2.1,
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.confidence, greaterThanOrEqualTo(0.50));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.60));
      expect(pred.isObservationalOnly, isTrue);
      expect(pred.modelVersion, equals('deepiod-neural-c-mobile-v1.0'));
    });

    test('Confirmed Indoor Condition: Artificial Illumination + Shielded GNSS -> Predicts Indoor', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: true,
        ambientLux: 150.0, // Dim office illumination
        hasGnssStatus: true,
        top4Cn0DbHz: 18.0, // Deeply attenuated GNSS
        satelliteCount: 2,
        hasImuData: true,
        magneticMagnitudeMean: 58.0,
        accelMagnitudeMean: 0.25, // Quiescent linear acceleration at rest
        magneticVariance: 25.0, // Structural steel distortion
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.indoor));
      expect(pred.confidence, greaterThanOrEqualTo(0.50));
      expect(pred.deepIodOutdoorProbability, lessThan(0.35));
      expect(pred.isObservationalOnly, isTrue);
    });

    test('Urban Canyon Condition: Degraded GNSS with Outdoor Daylight does not force false Indoor', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 12, 0),
        hasLightSensor: true,
        ambientLux: 8500.0, // Clear outdoor overcast/daylight
        hasGnssStatus: true,
        top4Cn0DbHz: 28.5, // Attenuated multipath in street canyon
        satelliteCount: 6,
        hasImuData: true,
        magneticMagnitudeMean: 44.5,
        accelMagnitudeMean: 0.85,
        magneticVariance: 3.5,
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.50));
    });

    test('Missing Sensors: Hardware lacking photodiode handles missing features with genuine LTE', () {
      final completeClassifier = DeepIodNeuralClassifier.complete();
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: false,
        ambientLux: null,
        hasTelephonyLte: true,
        lteRsrpDbm: -72.0,
        lteRsrqDb: -6.5,
        hasGnssStatus: true,
        top4Cn0DbHz: 40.0,
        satelliteCount: 12,
        hasImuData: true,
        magneticMagnitudeMean: 45.0,
        accelMagnitudeMean: 0.85,
        magneticVariance: 2.0,
        isNightTime: false,
      );

      final pred = completeClassifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.sensorAvailability['light'], isFalse);
      expect(pred.sensorAvailability['rsrp'], isTrue);
      expect(pred.sensorAvailability['gnss_status'], isTrue);
    });

    test('Total Sensor Absence: Returns unknown state without throwing exception', () {
      final snapshot = IodSensorSnapshot.empty(timestamp: DateTime.now());

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.unknown));
      expect(pred.confidence, equals(0.0));
    });

    test('Inference Latency: Runs in less than 5 milliseconds', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: true,
        ambientLux: 1000.0,
        hasGnssStatus: true,
        top4Cn0DbHz: 35.0,
        hasImuData: true,
        magneticVariance: 5.0,
      );

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        classifier.classify(snapshot);
      }
      sw.stop();

      final avgLatencyMs = sw.elapsedMilliseconds / 100.0;
      expect(avgLatencyMs, lessThan(2.0));
    });

    test('Model C-Mobile (4-Sensor Variant): Operates independently with genuine mobile sensors', () {
      final mobileClassifier = DeepIodNeuralClassifier.mobile();
      expect(mobileClassifier.variant, equals(DeepIodVariant.mobile4Channel));
      expect(mobileClassifier.modelVersion, equals('deepiod-neural-c-mobile-v1.0'));

      final outdoorSnap = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: true,
        ambientLux: 15000.0,
        hasImuData: true,
        magneticMagnitudeMean: 46.0,
        accelMagnitudeMean: 0.85, // Linear acceleration without gravity (m/s^2)
        isNightTime: false,
      );

      final pred = mobileClassifier.classify(outdoorSnap);
      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.60));
      expect(pred.sensorAvailability['telephony_lte'], isFalse);
      expect(pred.isObservationalOnly, isTrue);
    });

    test('Parity Verification (Model C 8-Sensor): Strict failure if fixtures missing; exact PyTorch agreement', () {
      final parityFile = File('tooling/data/deepiod_weights/parity_test_vectors.json');
      final weightsFile = File('tooling/data/deepiod_weights/deepiod_model_c_weights.json');

      expect(
        parityFile.existsSync(),
        isTrue,
        reason: 'Required fixture parity_test_vectors.json must exist (graceful skipping banned).',
      );
      expect(
        weightsFile.existsSync(),
        isTrue,
        reason: 'Required fixture deepiod_model_c_weights.json must exist (graceful skipping banned).',
      );

      final testVectors = (jsonDecode(parityFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
      final model = DeepIodModelC.fromJson(weightsJson);

      double maxAbsError = 0.0;
      double sumAbsError = 0.0;
      int agreements = 0;

      for (final item in testVectors) {
        final window = (item['window'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();

        final dartProb = model.predict(window);
        final absError = (dartProb - expectedPyTorch).abs();
        if (absError > maxAbsError) {
          maxAbsError = absError;
        }
        sumAbsError += absError;

        if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) {
          agreements++;
        }
      }

      final meanAbsError = sumAbsError / testVectors.length;
      final agreementPct = (agreements / testVectors.length) * 100.0;

      expect(maxAbsError, lessThan(1e-4));
      expect(meanAbsError, lessThan(1e-6));
      expect(agreementPct, equals(100.0));
    });

    test('Parity Verification (Model C-Mobile 4-Sensor): Strict failure if fixtures missing; exact PyTorch agreement', () {
      final parityFile = File('tooling/data/deepiod_weights/parity_test_vectors_mobile.json');
      final weightsFile = File('tooling/data/deepiod_weights/deepiod_model_c_mobile_weights.json');

      expect(
        parityFile.existsSync(),
        isTrue,
        reason: 'Required fixture parity_test_vectors_mobile.json must exist (graceful skipping banned).',
      );
      expect(
        weightsFile.existsSync(),
        isTrue,
        reason: 'Required fixture deepiod_model_c_mobile_weights.json must exist (graceful skipping banned).',
      );

      final testVectors = (jsonDecode(parityFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
      final model = DeepIodModelC.fromJson(weightsJson);

      double maxAbsError = 0.0;
      double sumAbsError = 0.0;
      int agreements = 0;

      for (final item in testVectors) {
        final window = (item['window'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();

        final dartProb = model.predict(window);
        final absError = (dartProb - expectedPyTorch).abs();
        if (absError > maxAbsError) {
          maxAbsError = absError;
        }
        sumAbsError += absError;

        if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) {
          agreements++;
        }
      }

      final meanAbsError = sumAbsError / testVectors.length;
      final agreementPct = (agreements / testVectors.length) * 100.0;

      expect(maxAbsError, lessThan(1e-4));
      expect(meanAbsError, lessThan(1e-6));
      expect(agreementPct, equals(100.0));
    });

    test('Parity Verification (Model A 8-Sensor CNN-LSTM): Strict failure if fixtures missing; exact PyTorch agreement', () {
      final parityFile = File('tooling/data/deepiod_weights/parity_test_vectors_model_a.json');
      final weightsFile = File('tooling/data/deepiod_weights/deepiod_model_a_weights.json');

      expect(parityFile.existsSync(), isTrue);
      expect(weightsFile.existsSync(), isTrue);

      final testVectors = (jsonDecode(parityFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
      final model = DeepIodModelA.fromJson(weightsJson);

      double maxAbsError = 0.0;
      double sumAbsError = 0.0;
      int agreements = 0;

      for (final item in testVectors) {
        final window = (item['window'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();

        final dartProb = model.predict(window);
        final absError = (dartProb - expectedPyTorch).abs();
        if (absError > maxAbsError) maxAbsError = absError;
        sumAbsError += absError;

        if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
      }

      final meanAbsError = sumAbsError / testVectors.length;
      final agreementPct = (agreements / testVectors.length) * 100.0;

      expect(maxAbsError, lessThan(1e-4));
      expect(meanAbsError, lessThan(1e-6));
      expect(agreementPct, equals(100.0));
    });

    test('Parity Verification (Model B 8-Sensor CNN-MHA): Strict failure if fixtures missing; exact PyTorch agreement', () {
      final parityFile = File('tooling/data/deepiod_weights/parity_test_vectors_model_b.json');
      final weightsFile = File('tooling/data/deepiod_weights/deepiod_model_b_weights.json');

      expect(parityFile.existsSync(), isTrue);
      expect(weightsFile.existsSync(), isTrue);

      final testVectors = (jsonDecode(parityFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
      final model = DeepIodModelB.fromJson(weightsJson);

      double maxAbsError = 0.0;
      double sumAbsError = 0.0;
      int agreements = 0;

      for (final item in testVectors) {
        final window = (item['window'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();

        final dartProb = model.predict(window);
        final absError = (dartProb - expectedPyTorch).abs();
        if (absError > maxAbsError) maxAbsError = absError;
        sumAbsError += absError;

        if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
      }

      final meanAbsError = sumAbsError / testVectors.length;
      final agreementPct = (agreements / testVectors.length) * 100.0;

      expect(maxAbsError, lessThan(1e-4));
      expect(meanAbsError, lessThan(1e-6));
      expect(agreementPct, equals(100.0));
    });

    test('Parity Verification (AMV Neural Consensus): Strict PyTorch agreement across 500 samples', () {
      final parityFile = File('tooling/data/deepiod_weights/parity_test_vectors_amv.json');
      final metaFile = File('tooling/data/deepiod_weights/deepiod_metadata.json');

      expect(parityFile.existsSync(), isTrue);
      expect(metaFile.existsSync(), isTrue);

      final metaJson = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final amvWeights = metaJson['amv_weights'] as Map<String, dynamic>;
      final wa = (amvWeights['model_a'] as num).toDouble();
      final wb = (amvWeights['model_b'] as num).toDouble();
      final wc = (amvWeights['model_c'] as num).toDouble();

      final modelA = DeepIodModelA.fromJson(jsonDecode(File('tooling/data/deepiod_weights/deepiod_model_a_weights.json').readAsStringSync()));
      final modelB = DeepIodModelB.fromJson(jsonDecode(File('tooling/data/deepiod_weights/deepiod_model_b_weights.json').readAsStringSync()));
      final modelC = DeepIodModelC.fromJson(jsonDecode(File('tooling/data/deepiod_weights/deepiod_model_c_weights.json').readAsStringSync()));

      final testVectors = (jsonDecode(parityFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();

      double maxAbsError = 0.0;
      double sumAbsError = 0.0;
      int agreements = 0;

      for (final item in testVectors) {
        final window = (item['window'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        final expectedPyTorch = (item['prob_pytorch_amv'] as num).toDouble();

        final pa = modelA.predict(window);
        final pb = modelB.predict(window);
        final pc = modelC.predict(window);
        final dartAmv = (wa * pa) + (wb * pb) + (wc * pc);

        final absError = (dartAmv - expectedPyTorch).abs();
        if (absError > maxAbsError) maxAbsError = absError;
        sumAbsError += absError;

        if ((dartAmv >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
      }

      final meanAbsError = sumAbsError / testVectors.length;
      final agreementPct = (agreements / testVectors.length) * 100.0;

      expect(maxAbsError, lessThan(1e-4));
      expect(meanAbsError, lessThan(1e-6));
      expect(agreementPct, equals(100.0));
    });

    test('DeepIOD Full Framework Classifier (AMV Ensemble of A, B, C + Light + GPS) predicts accurately', () {
      final framework = DeepIodFrameworkClassifier();

      final outdoorSnapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0),
        hasLightSensor: true,
        ambientLux: 15000.0,
        hasGnssStatus: true,
        top4Cn0DbHz: 41.0,
        hasGpsFix: true,
        horizontalAccuracy: 4.0, // <= 5m DeepIOD criterion
        hasImuData: true,
        magneticMagnitudeMean: 46.0,
        accelMagnitudeMean: 0.85,
        magneticVariance: 2.0,
        isNightTime: false,
      );

      final pred = framework.classify(outdoorSnapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.70));
      expect(pred.modelVersion, equals('deepiod-full-framework-v1.0'));
      expect(pred.isObservationalOnly, isTrue);
      expect(pred.reasoningSummary, contains('DeepIOD-Full-AMV'));
    });

    test('SeamlessTransitionDetector evaluates GNSS, Doorway Proximity, and Handover Events', () {
      final entrance = const BuildingTransitionPoint(
        id: 'door_main',
        name: 'Main Building Entrance',
        latitude: 10.7769,
        longitude: 106.7009,
        radiusMeters: 5.0,
      );

      final detector = SeamlessTransitionDetector(transitionPoints: [entrance]);

      // 1. Initial position outdoor away from door
      final s1 = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0, 0),
        hasGpsFix: true,
        latitude: 10.7775,
        longitude: 106.7015, // ~90 meters away
        hasGnssStatus: true,
        top4Cn0DbHz: 42.0,
        usedInFixCount: 9,
      );
      final p1 = detector.evaluate(s1);
      expect(p1.state, equals(IndoorOutdoorState.outdoor));

      // 2. Approaching doorway: intermediate C/N0 (35 dB-Hz) and at door coordinates (0 meters)
      final s2 = IodSensorSnapshot(
        timestamp: DateTime(2026, 6, 1, 14, 0, 1),
        hasGpsFix: true,
        latitude: 10.7769,
        longitude: 106.7009, // exactly at entrance point
        hasGnssStatus: true,
        top4Cn0DbHz: 35.0,
        usedInFixCount: 4,
        stepDelta: 2,
        speed: 1.2,
      );
      final p2 = detector.evaluate(s2);
      expect(p2.state, equals(IndoorOutdoorState.transition));
      expect(p2.transitionProbability, greaterThan(0.50));

      // Handover event should be recorded
      expect(detector.handoverEvents.isNotEmpty, isTrue);
      final event = detector.handoverEvents.last;
      expect(event.fromState, equals(IndoorOutdoorState.outdoor));
      expect(event.toState, equals(IndoorOutdoorState.transition));
    });
  });
}
