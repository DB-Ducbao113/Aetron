import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const engine = WorkoutTrackingEngine();

  Position buildPosition({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double accuracy = 8.0,
    double speed = 3.0,
    double heading = 0.0,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: heading,
      headingAccuracy: 1.0,
      speed: speed,
      speedAccuracy: 0.1,
    );
  }

  group('Aetron EKF 4-State Field Recording Readiness Audit', () {
    test(
      'Gate 1: Starting immediately after GPS becomes available & first sample initialization',
      () {
        final pipeline = GpsPipeline();
        final t0 = DateTime.utc(2026, 10, 28, 0, 29, 19);

        // Row 0 from real field recording fa1af1d3: accuracy = 21.27m
        final p0 = buildPosition(
          latitude: 10.738082,
          longitude: 106.625252,
          timestamp: t0,
          accuracy: 21.27,
          speed: 0.0,
        );

        final decision = engine.evaluateGpsUpdate(
          position: p0,
          activityType: 'cycling',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );

        // Main's cycling first-fix requirement is 20m. The historical
        // 21.27m row must wait for a better fix, not silently seed a route.
        expect(decision.type, TrackingGpsDecisionType.skip);
        expect(decision.reason, GpsRejectReason.waitingForBetterFirstFix);

        final betterFix = buildPosition(
          latitude: 10.738082,
          longitude: 106.625252,
          timestamp: t0.add(const Duration(seconds: 1)),
          accuracy: 12.0,
          speed: 0.0,
        );
        final seeded = engine.evaluateGpsUpdate(
          position: betterFix,
          activityType: 'cycling',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          rawGpsGapDurationSec: 0.0,
          shouldResetAnchorOnResume: false,
        );
        expect(seeded.type, TrackingGpsDecisionType.seedRoute);
        expect(seeded.outcome, GpsPointOutcome.accepted);
        expect(seeded.reason, GpsRejectReason.none);

        pipeline.seedRoute(seeded.livePoint);

        expect(pipeline.routePoints.length, 1);
        expect(pipeline.smoothedRoutePoints.length, 1);
        expect(pipeline.routeSegments.length, 1);
        expect(pipeline.smoothedRouteSegments.length, 1);
        expect(pipeline.routeSegments.first.length, 1);
        expect(pipeline.smoothedRouteSegments.first.length, 1);
        expect(pipeline.ekf.isInitialized, isTrue);
      },
    );

    test(
      'Gate 2: First and second accepted route points form displayable polyline without lag',
      () {
        final pipeline = GpsPipeline();
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        final t0 = DateTime.utc(2026, 10, 28, 0, 29, 19);

        // Fix #1 (Seed)
        final p0 = buildPosition(
          latitude: 10.738082,
          longitude: 106.625252,
          timestamp: t0,
          accuracy: 15.0,
          speed: 0.0,
        );
        final d0 = engine.evaluateGpsUpdate(
          position: p0,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        pipeline.seedRoute(d0.livePoint);

        // Fix #2: Moved ~3.3m north, arriving 1 second later
        final t1 = t0.add(const Duration(seconds: 1));
        final p1 = buildPosition(
          latitude: 10.738112,
          longitude: 106.625252,
          timestamp: t1,
          accuracy: 8.0,
          speed: 3.3,
        );
        final d1 = engine.evaluateGpsUpdate(
          position: p1,
          activityType: 'running',
          routePoints: pipeline.routePoints,
          currentLatLng: d0.livePoint,
          distanceAnchorPoint: d0.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );

        expect(d1.type, TrackingGpsDecisionType.acceptRoute);
        expect(d1.shouldAddDistance, isTrue);
        expect(d1.shouldBreakRouteForDisplay, isFalse);
        expect(d1.segmentMeters, greaterThan(2.5));

        final smoothingUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: d1.livePoint,
          previousAcceptedPoint: pipeline.routePoints.last,
          previousSmoothedPoint: pipeline.smoothedRoutePoints.last,
          lastSmoothedRoutePoint: pipeline.smoothedRoutePoints.last,
          accuracyMeters: p1.accuracy,
          speedMs: p1.speed,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );

        pipeline.appendAcceptedSegment(
          routeCandidate: d1.livePoint,
          displayRoutePoint: smoothingUpdate.smoothedPoint,
          shouldBreakRouteForDisplay: d1.shouldBreakRouteForDisplay,
          gpsGapDurationSec: d1.gpsGapDurationSec,
          shouldAppendSmoothedPoint: smoothingUpdate.shouldAppendRoutePoint,
        );

        // Crucial validation: On point #2, the polyline segment MUST have length 2
        // so that Flutter Map renders it on screen immediately.
        expect(pipeline.smoothedRouteSegments.first.length, 2);
        expect(d1.segmentMeters, greaterThan(2.5));
      },
    );

    test(
      'Gate 3: Continuous movement immediately after Start accumulates distance smoothly',
      () {
        final pipeline = GpsPipeline();
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        var t = DateTime.utc(2026, 10, 28, 0, 30, 0);
        var currentLat = 10.740000;
        final currentLng = 106.630000;
        var accumulatedDistanceM = 0.0;
        LatLng? anchor;

        // Seed
        final p0 = buildPosition(
          latitude: currentLat,
          longitude: currentLng,
          timestamp: t,
        );
        final d0 = engine.evaluateGpsUpdate(
          position: p0,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        pipeline.seedRoute(d0.livePoint);
        anchor = d0.livePoint;
        var lastTime = t;

        // Feed 10 consecutive 1Hz fixes moving ~3m north per fix (3 m/s)
        for (var i = 1; i <= 10; i++) {
          t = t.add(const Duration(seconds: 1));
          currentLat += 0.000027; // ~3.0 meters
          final p = buildPosition(
            latitude: currentLat,
            longitude: currentLng,
            timestamp: t,
            speed: 3.0,
          );

          final d = engine.evaluateGpsUpdate(
            position: p,
            activityType: 'running',
            routePoints: pipeline.routePoints,
            currentLatLng: anchor,
            distanceAnchorPoint: anchor,
            lastAcceptedPositionTime: lastTime,
            shouldResetAnchorOnResume: false,
          );

          expect(d.type, TrackingGpsDecisionType.acceptRoute);
          expect(d.shouldAddDistance, isTrue);
          expect(d.shouldBreakRouteForDisplay, isFalse);

          final update = smoothingService.smoothAcceptedPoint(
            activityType: 'running',
            acceptedPoint: d.livePoint,
            previousAcceptedPoint: pipeline.routePoints.last,
            previousSmoothedPoint: pipeline.smoothedRoutePoints.last,
            lastSmoothedRoutePoint: pipeline.smoothedRoutePoints.last,
            accuracyMeters: p.accuracy,
            speedMs: p.speed,
            timeDeltaSec: 1.0,
            gpsGapDurationSec: 0.0,
          );

          pipeline.appendAcceptedSegment(
            routeCandidate: d.livePoint,
            displayRoutePoint: update.smoothedPoint,
            shouldBreakRouteForDisplay: d.shouldBreakRouteForDisplay,
            gpsGapDurationSec: d.gpsGapDurationSec,
            shouldAppendSmoothedPoint: update.shouldAppendRoutePoint,
          );

          accumulatedDistanceM += d.segmentMeters;
          anchor = d.livePoint;
          lastTime = t;
        }

        expect(pipeline.smoothedRouteSegments.length, 1);
        expect(pipeline.smoothedRouteSegments.first.length, 11);
        expect(accumulatedDistanceM, closeTo(30.0, 3.0));
      },
    );

    test(
      'Gate 4: Stationary start followed by movement has zero phantom drift',
      () {
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        final base = const LatLng(10.740000, 106.630000);

        // 5 stationary points with sub-meter jitter and 0 speed
        for (var i = 1; i <= 5; i++) {
          final jitterPoint = LatLng(
            base.latitude + (i * 0.000002), // ~0.2m jitter
            base.longitude,
          );

          final update = smoothingService.smoothAcceptedPoint(
            activityType: 'running',
            acceptedPoint: jitterPoint,
            previousAcceptedPoint: base,
            previousSmoothedPoint: base,
            lastSmoothedRoutePoint: base,
            accuracyMeters: 8.0,
            speedMs: 0.0,
            timeDeltaSec: 1.0,
            gpsGapDurationSec: 0.0,
          );

          expect(update.isStationary, isTrue);
          expect(update.shouldAppendRoutePoint, isFalse);
          expect(update.smoothedPoint, base);
        }

        // Now start moving: moved 5m with speed 2.5 m/s
        final movingPoint = LatLng(base.latitude + 0.000045, base.longitude);
        final movingUpdate = smoothingService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: movingPoint,
          previousAcceptedPoint: base,
          previousSmoothedPoint: base,
          lastSmoothedRoutePoint: base,
          accuracyMeters: 8.0,
          speedMs: 2.5,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );

        expect(movingUpdate.isStationary, isFalse);
        expect(movingUpdate.shouldAppendRoutePoint, isTrue);
        expect(movingUpdate.smoothedPoint.latitude, greaterThan(base.latitude));
      },
    );

    test(
      'Gate 5: Baseline-parity 12s GPS gap breaks route without adding unverified distance',
      () {
        final pipeline = GpsPipeline();
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        final t0 = DateTime.utc(2026, 10, 28, 0, 30, 0);
        final p0 = buildPosition(
          latitude: 10.740000,
          longitude: 106.630000,
          timestamp: t0,
        );
        final d0 = engine.evaluateGpsUpdate(
          position: p0,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        pipeline.seedRoute(d0.livePoint);

        // Fix #2: Arrives after a 12-second delay (simulating phone in pocket / initial GPS settling)
        // User has covered ~36m at 3 m/s
        final t1 = t0.add(const Duration(seconds: 12));
        final p1 = buildPosition(
          latitude: 10.740324, // ~36m north
          longitude: 106.630000,
          timestamp: t1,
          speed: 3.0,
          accuracy: 10.0,
        );

        final d1 = engine.evaluateGpsUpdate(
          position: p1,
          activityType: 'running',
          routePoints: pipeline.routePoints,
          currentLatLng: d0.livePoint,
          distanceAnchorPoint: d0.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );

        // The historical main 5s gap policy treats a 12s gap as unverified.
        expect(d1.type, TrackingGpsDecisionType.acceptRoute);
        expect(d1.shouldAddDistance, isFalse);
        expect(d1.shouldBreakRouteForDisplay, isTrue);
        expect(d1.gpsGapDurationSec, 12.0);
        expect(d1.segmentMeters, 0.0);

        final update = smoothingService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: d1.livePoint,
          previousAcceptedPoint: pipeline.routePoints.last,
          previousSmoothedPoint: pipeline.smoothedRoutePoints.last,
          lastSmoothedRoutePoint: pipeline.smoothedRoutePoints.last,
          accuracyMeters: p1.accuracy,
          speedMs: p1.speed,
          timeDeltaSec: 12.0,
          gpsGapDurationSec: d1.gpsGapDurationSec,
        );

        pipeline.appendAcceptedSegment(
          routeCandidate: d1.livePoint,
          displayRoutePoint: update.smoothedPoint,
          shouldBreakRouteForDisplay: d1.shouldBreakRouteForDisplay,
          gpsGapDurationSec: d1.gpsGapDurationSec,
          shouldAppendSmoothedPoint: update.shouldAppendRoutePoint,
        );

        // The new segment is not bridged to the previously accepted fix.
        expect(pipeline.smoothedRouteSegments.length, 2);
        expect(pipeline.smoothedRouteSegments.last.length, 1);
        expect(pipeline.gpsGapSegments.length, 1);
      },
    );

    test(
      'Gate 6: Major GPS blackout (> 5s) triggers clean route break, zero distance jump, and safe EKF re-anchoring',
      () {
        final pipeline = GpsPipeline();
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        final t0 = DateTime.utc(2026, 10, 28, 0, 30, 0);
        final p0 = buildPosition(
          latitude: 10.740000,
          longitude: 106.630000,
          timestamp: t0,
        );
        final d0 = engine.evaluateGpsUpdate(
          position: p0,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        pipeline.seedRoute(d0.livePoint);

        // Major gap: 45 seconds later, 200m away
        final t1 = t0.add(const Duration(seconds: 45));
        final p1 = buildPosition(
          latitude: 10.741800,
          longitude: 106.630000,
          timestamp: t1,
          speed: 3.0,
          accuracy: 8.0,
        );

        final d1 = engine.evaluateGpsUpdate(
          position: p1,
          activityType: 'running',
          routePoints: pipeline.routePoints,
          currentLatLng: d0.livePoint,
          distanceAnchorPoint: d0.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );

        expect(d1.type, TrackingGpsDecisionType.acceptRoute);
        expect(d1.shouldBreakRouteForDisplay, isTrue);
        expect(d1.shouldAddDistance, isFalse);
        expect(d1.segmentMeters, 0.0);
        expect(d1.gpsGapDurationSec, 45.0);

        final update = smoothingService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: d1.livePoint,
          previousAcceptedPoint: pipeline.routePoints.last,
          previousSmoothedPoint: pipeline.smoothedRoutePoints.last,
          lastSmoothedRoutePoint: pipeline.smoothedRoutePoints.last,
          accuracyMeters: p1.accuracy,
          speedMs: p1.speed,
          timeDeltaSec: 45.0,
          gpsGapDurationSec: 45.0,
        );

        pipeline.appendAcceptedSegment(
          routeCandidate: d1.livePoint,
          displayRoutePoint: update.smoothedPoint,
          shouldBreakRouteForDisplay: d1.shouldBreakRouteForDisplay,
          gpsGapDurationSec: d1.gpsGapDurationSec,
          shouldAppendSmoothedPoint: update.shouldAppendRoutePoint,
        );

        // Creates a new segment separated by gap
        expect(pipeline.smoothedRouteSegments.length, 2);
        expect(pipeline.gpsGapSegments.length, 1);
        expect(pipeline.gpsGapSegments.first.durationSec, 45.0);
      },
    );

    test(
      'Gate 7: Workout stop and save records EKF route and algorithm metadata',
      () {
        const finalizer = WorkoutSessionFinalizer();
        var t = DateTime.utc(2026, 10, 28, 0, 30, 0);
        final rawPositions = <Position>[];
        final smoothedPoints = <LatLng>[];
        var lat = 10.740000;

        for (var i = 0; i < 11; i++) {
          final pos = buildPosition(
            latitude: lat,
            longitude: 106.630000,
            timestamp: t,
            speed: 3.0,
          );
          rawPositions.add(pos);
          smoothedPoints.add(LatLng(lat, 106.630000));
          lat +=
              0.000027; // ~3.0m per second -> pace ~333 s/km (within 150-720 s/km)
          t = t.add(const Duration(seconds: 1));
        }

        final state = WorkoutSessionState(
          status: RecordingState.active,
          sessionId: 'fa1af1d3-b209-4649-b928-47bf6e4502f9',
          activityType: 'running',
          trackingMode: 'outdoor',
          startedAt: DateTime.utc(2026, 10, 28, 0, 30, 0),
          durationSeconds: 10,
          distanceMeters: 30.0,
        );

        final result = finalizer.finalize(
          state: state,
          userId: 'test_athlete_123',
          finishedAt: t,
          caloriesBurned: 15,
          fallbackStrideLengthMeters: 0.8,
          trackingEngine: engine,
          rawGpsPositions: rawPositions,
          filteredRouteSegments: [smoothedPoints],
          gpsAlgorithm: 'ekf_4state',
        );

        expect(result.session.id, 'fa1af1d3-b209-4649-b928-47bf6e4502f9');
        expect(result.session.distanceKm, closeTo(0.03, 0.005));
        expect(result.session.filteredRouteJson, contains('106.63'));

        final metrics =
            jsonDecode(result.session.routeMatchMetricsJson)
                as Map<String, dynamic>;
        expect(metrics['gps_algorithm'], 'ekf_4state');
        expect(metrics['dbscan_enabled'], isFalse);
        expect(metrics['filter_branch'], 'experiment/ekf4-field-recording');
        expect(metrics['source_revision'], isNotEmpty);
        expect(metrics['source_fingerprint'], isNotEmpty);
        expect(metrics['filtered_route_distance_km'], closeTo(0.03, 0.005));
        expect(metrics['raw_valid_distance_km'], closeTo(0.03, 0.005));
        expect(metrics['distance_selection_policy'],
            'raw_valid_then_raw_total_then_live');
        expect(metrics['raw_gps_fix_count'], 11);
        expect(metrics['live_distance_km'], closeTo(0.03, 0.005));
        expect(metrics['saved_distance_km'], closeTo(result.session.distanceKm, 1e-9));
        expect(metrics['saved_minus_live_distance_km'], closeTo(0.0, 0.005));
      },
    );

    test(
      'Gate 8: Starting a second workout resets all state without carryover',
      () {
        final pipeline = GpsPipeline();
        final smoothingService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );

        // Workout #1 in Ho Chi Minh City
        final t0 = DateTime.utc(2026, 10, 28, 1, 0, 0);
        final pW1 = buildPosition(
          latitude: 10.740000,
          longitude: 106.630000,
          timestamp: t0,
        );
        pipeline.seedRoute(LatLng(pW1.latitude, pW1.longitude));
        smoothingService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: LatLng(pW1.latitude, pW1.longitude),
          previousAcceptedPoint: null,
          previousSmoothedPoint: null,
          lastSmoothedRoutePoint: null,
          accuracyMeters: 5.0,
          speedMs: 3.0,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );

        expect(pipeline.routePoints.isNotEmpty, isTrue);
        expect(pipeline.ekf.isInitialized, isTrue);

        // RESET between sessions (as in _resetRuntimeTrackingState)
        pipeline.reset();
        smoothingService.reset();

        expect(pipeline.routePoints, isEmpty);
        expect(pipeline.smoothedRoutePoints, isEmpty);
        expect(pipeline.routeSegments, isEmpty);
        expect(pipeline.smoothedRouteSegments, isEmpty);
        expect(pipeline.ekf.isInitialized, isFalse);

        // Workout #2 in Hanoi (21.0285, 105.8542)
        final pW2 = buildPosition(
          latitude: 21.028500,
          longitude: 105.854200,
          timestamp: t0.add(const Duration(hours: 2)),
        );
        pipeline.seedRoute(LatLng(pW2.latitude, pW2.longitude));

        expect(pipeline.routePoints.first.latitude, closeTo(21.0285, 0.0001));
        expect(
          pipeline.smoothedRoutePoints.first.longitude,
          closeTo(105.8542, 0.0001),
        );
        expect(pipeline.ekf.isInitialized, isTrue);
      },
    );

    test(
      'Gate 9: Dual-algorithm switchability between EKF 4-State candidate and Fixed Alpha baseline',
      () {
        final ekfService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );
        final alphaService = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.fixedAlpha,
        );

        expect(ekfService.algorithmName, 'ekf_4state');
        expect(alphaService.algorithmName, 'fixed_alpha');

        final p0 = const LatLng(10.740000, 106.630000);
        final p1 = const LatLng(10.740050, 106.630020);

        // Point #1 (Seed)
        final ekfSeed = ekfService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: p0,
          previousAcceptedPoint: null,
          previousSmoothedPoint: null,
          lastSmoothedRoutePoint: null,
          accuracyMeters: 8.0,
          speedMs: 2.5,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        final alphaSeed = alphaService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: p0,
          previousAcceptedPoint: null,
          previousSmoothedPoint: null,
          lastSmoothedRoutePoint: null,
          accuracyMeters: 8.0,
          speedMs: 2.5,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );

        expect(ekfSeed.smoothedPoint, p0);
        expect(alphaSeed.smoothedPoint, p0);

        // Point #2
        final ekfStep = ekfService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: p1,
          previousAcceptedPoint: p0,
          previousSmoothedPoint: p0,
          lastSmoothedRoutePoint: p0,
          accuracyMeters: 8.0,
          speedMs: 2.5,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );
        final alphaStep = alphaService.smoothAcceptedPoint(
          activityType: 'running',
          acceptedPoint: p1,
          previousAcceptedPoint: p0,
          previousSmoothedPoint: p0,
          lastSmoothedRoutePoint: p0,
          accuracyMeters: 8.0,
          speedMs: 2.5,
          timeDeltaSec: 1.0,
          gpsGapDurationSec: 0.0,
        );

        expect(ekfStep.smoothedPoint.latitude, greaterThan(p0.latitude));
        expect(alphaStep.smoothedPoint.latitude, greaterThan(p0.latitude));
        expect(ekfStep.shouldAppendRoutePoint, isTrue);
        expect(alphaStep.shouldAppendRoutePoint, isTrue);
      },
    );

    test(
      'Gate 10: Task 3 Regression Audit — Prove startup fix does not accept poor accuracy, bridge impossible gaps, or inflate distance',
      () {
        final t0 = DateTime.utc(2026, 10, 28, 0, 30, 0);

        // 1. Main policy for running: initial accuracy > 16m must be rejected
        final poorInitialFix = buildPosition(
          latitude: 10.740000,
          longitude: 106.630000,
          timestamp: t0,
          accuracy: 26.0,
        );
        final dInitial = engine.evaluateGpsUpdate(
          position: poorInitialFix,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        expect(dInitial.type, TrackingGpsDecisionType.skip);
        expect(dInitial.reason, GpsRejectReason.waitingForBetterFirstFix);

        // 2. Accept legitimate seed
        final legitimateSeed = buildPosition(
          latitude: 10.740000,
          longitude: 106.630000,
          timestamp: t0,
          accuracy: 15.0,
        );
        final dSeed = engine.evaluateGpsUpdate(
          position: legitimateSeed,
          activityType: 'running',
          routePoints: const [],
          currentLatLng: null,
          distanceAnchorPoint: null,
          lastAcceptedPositionTime: null,
          shouldResetAnchorOnResume: false,
        );
        expect(dSeed.type, TrackingGpsDecisionType.seedRoute);

        // 3a. Device speed spike (> 80.0 m/s, e.g. 85 m/s) MUST BE SKIPPED
        final deviceSpeedSpike = buildPosition(
          latitude: 10.740100,
          longitude: 106.630000,
          timestamp: t0.add(const Duration(seconds: 1)),
          speed: 85.0,
        );
        final dSpeedSpike = engine.evaluateGpsUpdate(
          position: deviceSpeedSpike,
          activityType: 'running',
          routePoints: [dSeed.livePoint],
          currentLatLng: dSeed.livePoint,
          distanceAnchorPoint: dSeed.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );
        expect(dSpeedSpike.type, TrackingGpsDecisionType.skip);
        expect(dSpeedSpike.reason, GpsRejectReason.gpsSpeedHardSpike);

        // 3b. Implied jump during delay (200m in 10s = 20 m/s > 7 m/s plausible) MUST ZERO DISTANCE and BREAK ROUTE
        final t1 = t0.add(const Duration(seconds: 10));
        final teleportSpike = buildPosition(
          latitude: 10.741800, // ~200m away
          longitude: 106.630000,
          timestamp: t1,
          speed: 4.0,
        );
        final dTeleport = engine.evaluateGpsUpdate(
          position: teleportSpike,
          activityType: 'running',
          routePoints: [dSeed.livePoint],
          currentLatLng: dSeed.livePoint,
          distanceAnchorPoint: dSeed.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );
        expect(dTeleport.shouldBreakRouteForDisplay, isTrue);
        expect(dTeleport.shouldAddDistance, isFalse);
        expect(dTeleport.segmentMeters, 0.0);

        // 4. Blackout gap > 5s (e.g. 25s) MUST ZERO DISTANCE and BREAK ROUTE
        final t2 = t0.add(const Duration(seconds: 25));
        final blackoutFix = buildPosition(
          latitude: 10.740500, // ~55m away
          longitude: 106.630000,
          timestamp: t2,
          speed: 2.2,
        );
        final dBlackout = engine.evaluateGpsUpdate(
          position: blackoutFix,
          activityType: 'running',
          routePoints: [dSeed.livePoint],
          currentLatLng: dSeed.livePoint,
          distanceAnchorPoint: dSeed.livePoint,
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );
        expect(dBlackout.type, TrackingGpsDecisionType.acceptRoute);
        expect(dBlackout.shouldBreakRouteForDisplay, isTrue);
        expect(dBlackout.shouldAddDistance, isFalse);
        expect(dBlackout.segmentMeters, 0.0);
        expect(dBlackout.reason, GpsRejectReason.staleSignalGap);
      },
    );
  });
}
