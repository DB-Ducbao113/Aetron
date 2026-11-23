import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GpsSmoothingService', () {
    final service = GpsSmoothingService();

    test('freezes marker on low-movement stationary updates', () {
      final update = service.smoothAcceptedPoint(
        activityType: 'walking',
        acceptedPoint: const LatLng(10.000001, 106.0),
        previousAcceptedPoint: const LatLng(10.0, 106.0),
        previousSmoothedPoint: const LatLng(10.0, 106.0),
        lastSmoothedRoutePoint: const LatLng(10.0, 106.0),
        accuracyMeters: 12,
        speedMs: 0.1,
        timeDeltaSec: 2,
        gpsGapDurationSec: 0,
      );

      expect(update.isStationary, isTrue);
      expect(update.smoothedPoint, const LatLng(10.0, 106.0));
      expect(update.shouldAppendRoutePoint, isFalse);
      expect(update.confidence, GpsConfidence.medium);
    });

    test(
      'appends route for real running movement and keeps confidence high',
      () {
        final update = service.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: const LatLng(10.00005, 106.0),
          previousAcceptedPoint: const LatLng(10.0, 106.0),
          previousSmoothedPoint: const LatLng(10.0, 106.0),
          lastSmoothedRoutePoint: const LatLng(10.0, 106.0),
          accuracyMeters: 6,
          speedMs: 3.1,
          timeDeltaSec: 2,
          gpsGapDurationSec: 0,
        );

        expect(update.isStationary, isFalse);
        expect(update.shouldAppendRoutePoint, isTrue);
        expect(update.confidence, GpsConfidence.high);
        expect(update.smoothedPoint.latitude, greaterThan(10.0));
      },
    );
  });
}
