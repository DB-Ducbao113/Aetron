import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('StrideLength', () {
    test(
      'running missing-cadence fallback is based on RBDS frequency, not gender',
      () {
        final male = computeStrideLength(
          activityType: 'Running',
          heightCm: 175,
          gender: 'male',
        );
        final female = computeStrideLength(
          activityType: 'Running',
          heightCm: 175,
          gender: 'female',
        );

        expect(male, closeTo(1.2000277854850385, .000001));
        expect(female, male);
      },
    );

    test('walking fallback uses SLEDataset2 mean without height', () {
      final male = computeStrideLength(activityType: 'Walking', gender: 'male');
      final female = computeStrideLength(
        activityType: 'Walking',
        gender: 'female',
      );

      expect(male, closeTo(0.7540663897, 0.0001));
      expect(female, male);
    });
  });

  group('EnvironmentClassifier', () {
    Position makePosition({
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      double accuracy = 10,
      double speed = 0,
    }) {
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: speed,
        speedAccuracy: 0,
      );
    }

    test(
      'classifier emits indoor hint and fallback suggestion on clearly weak GPS walking signal',
      () async {
        final classifier = EnvironmentClassifier(activityType: 'walking');
        addTearDown(classifier.dispose);

        final now = DateTime.now();
        final eventFuture = classifier.stateStream
            .firstWhere(
              (event) => event.environment != TrackingEnvironment.detecting,
            )
            .timeout(const Duration(seconds: 2));

        classifier.addPosition(
          makePosition(
            latitude: 10.0,
            longitude: 106.0,
            timestamp: now,
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addPosition(
          makePosition(
            latitude: 10.000001,
            longitude: 106.000001,
            timestamp: now.add(const Duration(seconds: 1)),
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addStepDelta(5);
        classifier.addPosition(
          makePosition(
            latitude: 10.000002,
            longitude: 106.000002,
            timestamp: now.add(const Duration(seconds: 2)),
            accuracy: 55,
            speed: 0.05,
          ),
        );
        classifier.addStepDelta(4);
        classifier.addPosition(
          makePosition(
            latitude: 10.000003,
            longitude: 106.000003,
            timestamp: now.add(const Duration(seconds: 3)),
            accuracy: 55,
            speed: 0.05,
          ),
        );

        final event = await eventFuture;
        expect(event.environment, TrackingEnvironment.indoor);
        expect(event.fallbackSuggested, isTrue);
        expect(event.confidence, greaterThan(0));
      },
    );
  });

  group('WorkoutTrackingEngine live route breaks', () {
    Position makePosition({
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      double accuracy = 10,
      double speed = 0,
    }) {
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: speed,
        speedAccuracy: 0,
      );
    }

    test('breaks display route and skips distance for weak walking jump', () {
      const engine = WorkoutTrackingEngine();
      final startedAt = DateTime(2026, 5, 8, 8);
      const start = LatLng(10.00000, 106.00000);
      const recoveryJump = LatLng(10.00028, 106.00000);

      final decision = engine.evaluateGpsUpdate(
        position: makePosition(
          latitude: recoveryJump.latitude,
          longitude: recoveryJump.longitude,
          timestamp: startedAt.add(const Duration(seconds: 3)),
          accuracy: 42,
        ),
        activityType: 'walking',
        routePoints: const [start],
        currentLatLng: start,
        distanceAnchorPoint: start,
        lastAcceptedPositionTime: startedAt,
        shouldResetAnchorOnResume: false,
      );

      expect(decision.type, TrackingGpsDecisionType.acceptRoute);
      expect(decision.previewPoint, recoveryJump);
      expect(decision.shouldBreakRouteForDisplay, isTrue);
      expect(decision.shouldAddDistance, isFalse);
      expect(decision.segmentMeters, 0);
    });

    test('continues drawing normally after a recovery segment is seeded', () {
      const engine = WorkoutTrackingEngine();
      final startedAt = DateTime(2026, 5, 8, 8);
      const start = LatLng(10.00000, 106.00000);
      const recoveryJump = LatLng(10.00028, 106.00000);
      const stableNext = LatLng(10.00032, 106.00000);

      final decision = engine.evaluateGpsUpdate(
        position: makePosition(
          latitude: stableNext.latitude,
          longitude: stableNext.longitude,
          timestamp: startedAt.add(const Duration(seconds: 5)),
          accuracy: 8,
          speed: 1.2,
        ),
        activityType: 'walking',
        routePoints: const [start, recoveryJump],
        currentLatLng: recoveryJump,
        distanceAnchorPoint: recoveryJump,
        lastAcceptedPositionTime: startedAt.add(const Duration(seconds: 3)),
        shouldResetAnchorOnResume: false,
      );

      expect(decision.type, TrackingGpsDecisionType.acceptRoute);
      expect(decision.shouldBreakRouteForDisplay, isFalse);
      expect(decision.shouldAddDistance, isTrue);
      expect(decision.segmentMeters, greaterThan(0));
    });
  });
}
