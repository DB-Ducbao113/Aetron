import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const engine = WorkoutTrackingEngine();
  final t0 = DateTime.utc(2026, 10, 1);
  const base = LatLng(10.0, 106.0);

  Position fix(
    int second, {
    double latitude = 10.0,
    double accuracy = 5.0,
    double speed = 0.0,
  }) {
    return Position(
      latitude: latitude,
      longitude: base.longitude,
      timestamp: t0.add(Duration(seconds: second)),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );
  }

  TrackingGpsDecision decide(
    Position current, {
    required LatLng anchor,
    required DateTime lastAccepted,
    required double rawGapSec,
  }) {
    return engine.evaluateGpsUpdate(
      position: current,
      activityType: 'cycling',
      routePoints: [anchor],
      currentLatLng: anchor,
      distanceAnchorPoint: anchor,
      lastAcceptedPositionTime: lastAccepted,
      rawGpsGapDurationSec: rawGapSec,
      shouldResetAnchorOnResume: false,
    );
  }

  test('60s stationary raw stream does not create a false route blackout', () {
    final route = GpsPipeline()..seedRoute(base);
    // The sensor sends a healthy fix every second; tiny GPS jitter is rejected.
    for (var sec = 1; sec <= 60; sec++) {
      final jitter = fix(
        sec,
        latitude: base.latitude + (sec.isEven ? 0.000002 : -0.000002),
      );
      final d = decide(
        jitter,
        anchor: base,
        lastAccepted: t0,
        rawGapSec: 0.0,
      );
      expect(d.type, TrackingGpsDecisionType.skip, reason: 'second $sec');
      expect(d.reason, GpsRejectReason.tinySegment);
    }

    final resumed = decide(
      fix(61, latitude: 10.00009, speed: 3.0), // ~10m of real motion
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 0.0,
    );
    expect(resumed.type, TrackingGpsDecisionType.acceptRoute);
    expect(resumed.shouldAddDistance, isTrue);
    expect(resumed.shouldBreakRouteForDisplay, isFalse);
    expect(resumed.gpsGapDurationSec, 0.0);
    expect(resumed.segmentMeters, greaterThan(8.0));
    route.appendAcceptedSegment(
      routeCandidate: resumed.livePoint,
      displayRoutePoint: resumed.livePoint,
      shouldBreakRouteForDisplay: resumed.shouldBreakRouteForDisplay,
      gpsGapDurationSec: resumed.gpsGapDurationSec,
      shouldAppendSmoothedPoint: true,
    );
    expect(route.routeSegments, hasLength(1));
    expect(route.gpsGapSegments, isEmpty);
  });

  test('15s without raw GPS never bridges distance across the outage', () {
    final recovered = decide(
      fix(15, latitude: 10.0009, speed: 3.0),
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 15.0,
    );
    expect(recovered.type, TrackingGpsDecisionType.acceptRoute);
    expect(recovered.shouldAddDistance, isFalse);
    expect(recovered.shouldBreakRouteForDisplay, isTrue);
    expect(recovered.gpsGapDurationSec, 15.0);
    expect(recovered.segmentMeters, 0.0);
  });

  test('first valid fix after blackout re-anchors even if displacement is tiny', () {
    final recovered = decide(
      fix(15, latitude: 10.000002, speed: 0.0), // < cycling 1.5m threshold
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 15.0,
    );
    expect(recovered.type, TrackingGpsDecisionType.acceptRoute);
    expect(recovered.shouldBreakRouteForDisplay, isTrue);
    expect(recovered.shouldAddDistance, isFalse);
  });

  test('a rejected first recovery fix cannot erase the pending real gap', () {
    final invalid = decide(
      fix(15, latitude: 10.0009, accuracy: 45.0, speed: 4.0),
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 15.0,
    );
    expect(invalid.type, TrackingGpsDecisionType.skip);
    expect(invalid.reason, GpsRejectReason.lowAccuracy);

    // Live recorder preserves rawGapSec until the next accepted fix.
    final valid = decide(
      fix(16, latitude: 10.00091, speed: 4.0),
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 15.0,
    );
    expect(valid.type, TrackingGpsDecisionType.acceptRoute);
    expect(valid.shouldBreakRouteForDisplay, isTrue);
    expect(valid.shouldAddDistance, isFalse);
  });

  test('a rejected teleport does not become an accepted distance jump', () {
    final bad = decide(
      fix(1, latitude: 10.002, speed: 85.0),
      anchor: base,
      lastAccepted: t0,
      rawGapSec: 0.0,
    );
    expect(bad.type, TrackingGpsDecisionType.skip);
    expect(bad.reason, GpsRejectReason.gpsSpeedHardSpike);
  });

  test('Fixed-Alpha and EKF use identical prevalidation and route boundaries', () {
    final fixed = GpsSmoothingService(algorithm: GpsFilterAlgorithm.fixedAlpha);
    final ekf = GpsSmoothingService(algorithm: GpsFilterAlgorithm.ekf4State);
    final variants = [
      (smoother: fixed, pipeline: GpsPipeline()..seedRoute(base)),
      (smoother: ekf, pipeline: GpsPipeline()..seedRoute(base)),
    ];
    final latestSmoothed = [base, base];

    for (var sec = 1; sec <= 6; sec++) {
      final position = fix(sec, latitude: base.latitude + sec * 0.00004, speed: 4);
      final current = LatLng(position.latitude, position.longitude);
      final d = decide(
        position,
        anchor: LatLng(base.latitude + (sec - 1) * 0.00004, base.longitude),
        lastAccepted: t0.add(Duration(seconds: sec - 1)),
        rawGapSec: 0.0,
      );
      expect(d.type, TrackingGpsDecisionType.acceptRoute);
      expect(d.shouldBreakRouteForDisplay, isFalse);

      for (var i = 0; i < variants.length; i++) {
        final variant = variants[i];
        final prevAccepted = variant.pipeline.routePoints.last;
        final smoothed = variant.smoother.smoothAcceptedPoint(
          activityType: 'cycling',
          acceptedPoint: current,
          previousAcceptedPoint: prevAccepted,
          previousSmoothedPoint: latestSmoothed[i],
          lastSmoothedRoutePoint: variant.pipeline.smoothedRoutePoints.last,
          accuracyMeters: position.accuracy,
          speedMs: position.speed,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        variant.pipeline.appendAcceptedSegment(
          routeCandidate: current,
          displayRoutePoint: smoothed.smoothedPoint,
          shouldBreakRouteForDisplay: false,
          gpsGapDurationSec: 0.0,
          shouldAppendSmoothedPoint: smoothed.shouldAppendRoutePoint,
        );
        latestSmoothed[i] = smoothed.smoothedPoint;
      }
    }

    expect(variants[0].pipeline.routePoints, variants[1].pipeline.routePoints);
    expect(variants[0].pipeline.routeSegments, variants[1].pipeline.routeSegments);
    expect(variants[0].pipeline.gpsGapSegments, isEmpty);
    expect(variants[1].pipeline.gpsGapSegments, isEmpty);
  });
}
