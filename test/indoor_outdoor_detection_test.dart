import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_record_entry.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_baseline_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/seamless_transition_detector.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';

void main() {
  group('1. DeepIOD Multi-Source Baseline Classifier Tests (Sensors 2024)', () {
    late DeepIodBaselineClassifier classifier;

    setUp(() {
      classifier = DeepIodBaselineClassifier();
    });

    test('Clear Outdoor Condition: Strong Daylight + High C/N0 + Low Mag Variance', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 14, 0), // 2 PM daylight
        hasGnssStatus: true,
        satelliteCount: 12,
        usedInFixCount: 8,
        meanCn0DbHz: 31.5,
        top4Cn0DbHz: 34.0,
        maxCn0DbHz: 38.0,
        hasGpsFix: true,
        horizontalAccuracy: 4.5,
        speed: 1.4,
        hasLightSensor: true,
        ambientLux: 15400.0, // Bright sunlight
        hasImuData: true,
        magneticMagnitudeMean: 46.2,
        magneticVariance: 2.1, // Clean geomagnetic field
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.confidence, greaterThanOrEqualTo(0.75));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.70));
      expect(pred.isObservationalOnly, isTrue);
    });

    test('Urban Canyon Condition: Degraded GPS (acc=35m) does NOT force false Indoor', () {
      // In high-rise street canyon: GPS multipath, but sunlight is daylight and mag is uniform
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 11, 30),
        hasGnssStatus: true,
        satelliteCount: 6,
        usedInFixCount: 4,
        meanCn0DbHz: 21.0,
        top4Cn0DbHz: 24.5,
        hasGpsFix: true,
        horizontalAccuracy: 38.0, // High GPS uncertainty
        speed: 1.2,
        hasLightSensor: true,
        ambientLux: 8500.0, // Abundant outdoor daylight
        hasImuData: true,
        magneticMagnitudeMean: 45.0,
        magneticVariance: 3.8, // Uniform outdoor field
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      // Multi-modal AMV correctly overcomes weak GPS and recognizes Outdoor!
      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.deepIodOutdoorProbability, greaterThan(0.55));
    });

    test('Confirmed Indoor Condition: Artificial Light + High Mag Variance + Blocked GNSS', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 15, 0),
        hasGnssStatus: true,
        satelliteCount: 2,
        usedInFixCount: 0,
        meanCn0DbHz: 14.0,
        top4Cn0DbHz: 16.0,
        hasGpsFix: false,
        horizontalAccuracy: 75.0,
        hasLightSensor: true,
        ambientLux: 180.0, // Typical office / gym interior
        hasImuData: true,
        magneticMagnitudeMean: 58.0,
        magneticVariance: 26.4, // High structural steel perturbation
        isNightTime: false,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.indoor));
      expect(pred.confidence, greaterThanOrEqualTo(0.65));
      expect(pred.deepIodOutdoorProbability, lessThan(0.35));
    });

    test('Night-time Outdoor: Guards against 0 lux triggering false indoor', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 22, 30), // 10:30 PM Night
        hasGnssStatus: true,
        satelliteCount: 10,
        usedInFixCount: 7,
        meanCn0DbHz: 30.0,
        top4Cn0DbHz: 33.0,
        hasGpsFix: true,
        horizontalAccuracy: 5.0,
        speed: 2.5,
        hasLightSensor: true,
        ambientLux: 0.8, // Dark night
        hasImuData: true,
        magneticMagnitudeMean: 47.0,
        magneticVariance: 2.5,
        isNightTime: true,
      );

      final pred = classifier.classify(snapshot);

      // Night guard downweights light sensor weight to 0.05, allowing GPS + IMU to prevail!
      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.reasoningSummary, contains('night_mode'));
    });

    test('Pocket Stowed Mode: Screen off + 0 lux is downweighted gracefully', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 10, 0),
        hasGnssStatus: true,
        satelliteCount: 11,
        usedInFixCount: 8,
        meanCn0DbHz: 29.5,
        top4Cn0DbHz: 32.0,
        hasGpsFix: true,
        horizontalAccuracy: 6.0,
        hasLightSensor: true,
        ambientLux: 1.0, // Phone in pocket
        hasImuData: true,
        magneticVariance: 3.0,
        isScreenOff: true,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.reasoningSummary, contains('pocket_stowed'));
    });

    test('Missing Sensors: Hardware without Light or GNSS status degrades gracefully', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime(2026, 5, 20, 12, 0),
        hasGnssStatus: false, // No native GNSS chip telemetry
        hasLightSensor: false, // No light sensor on tablet
        hasGpsFix: true,
        horizontalAccuracy: 8.0,
        hasImuData: true,
        magneticVariance: 3.5,
      );

      final pred = classifier.classify(snapshot);

      expect(pred.state, isNot(equals(IndoorOutdoorState.unknown)));
      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.sensorAvailability['light'], isFalse);
      expect(pred.sensorAvailability['gnss_status'], isFalse);
    });

    test('Total Sensor Absence: Returns clean Unknown state without throwing', () {
      final emptySnapshot = IodSensorSnapshot.empty();
      final pred = classifier.classify(emptySnapshot);

      expect(pred.state, equals(IndoorOutdoorState.unknown));
      expect(pred.confidence, equals(0.0));
      expect(pred.reasoningSummary, contains('no_reliable_sensors_available'));
    });
  });

  group('2. Seamless Transition Detector Tests (Yoo, Electronics 2025)', () {
    late SeamlessTransitionDetector detector;

    setUp(() {
      detector = SeamlessTransitionDetector();
    });

    test('Outdoor Clear Line-of-Sight State', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime.now(),
        hasGnssStatus: true,
        top4Cn0DbHz: 32.0,
        usedInFixCount: 7,
        hasGpsFix: true,
        horizontalAccuracy: 6.0,
      );

      final pred = detector.evaluate(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.transitionProbability, lessThan(0.25));
    });

    test('Indoor Deep Obstruction State', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime.now(),
        hasGnssStatus: true,
        top4Cn0DbHz: 15.0,
        usedInFixCount: 1,
        hasGpsFix: false,
      );

      final pred = detector.evaluate(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.indoor));
      expect(pred.transitionProbability, lessThan(0.25));
    });

    test('Intermediate Transition Zone: Boundary Signal Gradient + Walking Motion', () {
      // Step 1: Baseline outdoor reading
      detector.evaluate(
        IodSensorSnapshot(
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          hasGnssStatus: true,
          top4Cn0DbHz: 31.0,
          usedInFixCount: 6,
          hasGpsFix: true,
        ),
      );

      // Step 2: Abrupt transition at building entrance (C/N0 drops to 24 dB-Hz, user is walking)
      final transitionSnapshot = IodSensorSnapshot(
        timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
        hasGnssStatus: true,
        top4Cn0DbHz: 23.5, // Intermediate region
        usedInFixCount: 4,
        hasGpsFix: true,
        horizontalAccuracy: 18.0,
        stepDelta: 2, // Active walking motion across doorway
        speed: 1.1,
      );

      final pred = detector.evaluate(transitionSnapshot);

      expect(pred.state, equals(IndoorOutdoorState.transition));
      expect(pred.transitionProbability, greaterThanOrEqualTo(0.50));
      expect(pred.confidence, greaterThanOrEqualTo(0.50));
    });
  });

  group('3. Composite Ensemble Classifier Tests', () {
    late IodCompositeClassifier ensemble;

    setUp(() {
      ensemble = IodCompositeClassifier();
    });

    test('Inference Latency is fast (< 10 ms as specified in DeepIOD)', () {
      final snapshot = IodSensorSnapshot(
        timestamp: DateTime.now(),
        hasGnssStatus: true,
        top4Cn0DbHz: 32.0,
        usedInFixCount: 8,
        hasGpsFix: true,
        horizontalAccuracy: 5.0,
        hasLightSensor: true,
        ambientLux: 12000.0,
        hasImuData: true,
        magneticVariance: 2.5,
      );

      final pred = ensemble.predict(snapshot);

      expect(pred.state, equals(IndoorOutdoorState.outdoor));
      expect(pred.inferenceLatencyMs, lessThanOrEqualTo(10));
      expect(pred.modelVersion, equals('aetron-iod-ensemble-v1.0'));
      expect(pred.isObservationalOnly, isTrue);
    });
  });

  group('4. Storage, Serialization & Ground-Truth CSV Export Tests', () {
    test('IodRecordEntry CSV headers match data columns strictly', () {
      final headers = IodRecordEntry.csvHeaders();
      expect(headers, contains('session_id'));
      expect(headers, contains('predicted_state'));
      expect(headers, contains('confidence'));
      expect(headers, contains('mean_cn0'));
      expect(headers, contains('ambient_lux'));
      expect(headers, contains('ground_truth_env'));

      final snapshot = IodSensorSnapshot(
        timestamp: DateTime.utc(2026, 5, 20, 10, 0),
        hasGnssStatus: true,
        satelliteCount: 9,
        usedInFixCount: 6,
        meanCn0DbHz: 28.4,
        top4Cn0DbHz: 31.2,
        maxCn0DbHz: 35.0,
        hasGpsFix: true,
        latitude: 10.7769,
        longitude: 106.7009,
        horizontalAccuracy: 6.2,
        speed: 1.35,
        hasLightSensor: true,
        ambientLux: 1450.0,
        hasImuData: true,
        accelMagnitudeMean: 9.81,
        accelVariance: 0.12,
        magneticMagnitudeMean: 45.3,
        magneticVariance: 3.1,
        stepDelta: 2,
      );

      const prediction = IodPrediction(
        state: IndoorOutdoorState.outdoor,
        confidence: 0.88,
        deepIodOutdoorProbability: 0.88,
        transitionProbability: 0.08,
        nativeClass: 'outdoor',
        modelVersion: 'deepiod-baseline-v1.0',
        inferenceLatencyMs: 2,
        sensorAvailability: {'gps': true, 'light': true, 'imu': true},
        reasoningSummary: 'Test sample reasoning',
      );

      final entry = IodRecordEntry(
        sessionId: 'test-session-001',
        epochIndex: 0,
        timestamp: DateTime.utc(2026, 5, 20, 10, 0),
        snapshot: snapshot,
        prediction: prediction,
        groundTruth: GroundTruthEnvironment.outdoor,
        groundTruthNote: 'Walking on sunny street',
      );

      final csvRow = entry.toCsvRow();
      expect(csvRow.length, equals(headers.length));
      expect(csvRow[0], equals('test-session-001'));
      expect(csvRow[3], equals('outdoor'));
      expect(csvRow[4], equals('0.8800'));
      expect(csvRow[27], equals('2')); // step_delta
      expect(csvRow[28], equals('outdoor')); // ground_truth_env
      expect(csvRow[29], equals('Walking on sunny street'));

      // Round-trip JSON test
      final json = entry.toJson();
      final restored = IodRecordEntry.fromJson(json);
      expect(restored.sessionId, equals(entry.sessionId));
      expect(restored.prediction.state, equals(entry.prediction.state));
      expect(restored.groundTruth, equals(entry.groundTruth));
    });
  });
}
