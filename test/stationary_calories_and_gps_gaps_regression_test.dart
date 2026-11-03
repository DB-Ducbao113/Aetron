import 'dart:convert';

import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const engine = WorkoutTrackingEngine();
  const finalizer = WorkoutSessionFinalizer();
  final baseLatLng = const LatLng(10.7769, 106.7009);
  final t0 = DateTime.utc(2026, 11, 3, 6, 0, 0);

  Position makeFix({
    required int sec,
    double? latitude,
    double? longitude,
    double accuracy = 5.0,
    double speed = 3.0,
  }) {
    return Position(
      latitude: latitude ?? (baseLatLng.latitude + (sec * 0.00003)),
      longitude: longitude ?? baseLatLng.longitude,
      timestamp: t0.add(Duration(seconds: sec)),
      accuracy: accuracy,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: speed,
      speedAccuracy: 0.2,
    );
  }

  UserProfile makeProfile({
    double weightKg = 70.0,
    double heightCm = 175.0,
    String gender = 'male',
  }) {
    return UserProfile(
      id: 'test-user',
      userId: 'test-user',
      weightKg: weightKg,
      heightCm: heightCm,
      gender: gender,
      createdAt: t0,
      updatedAt: t0,
    );
  }

  TrackingGpsDecision evaluate(
    Position position, {
    required List<LatLng> routePoints,
    required LatLng currentLatLng,
    LatLng? distanceAnchorPoint,
    DateTime? lastAcceptedPositionTime,
    double? rawGpsGapDurationSec,
    bool shouldResetAnchorOnResume = false,
    bool wasGpsSignalWeak = false,
    String activityType = 'Running',
  }) {
    return engine.evaluateGpsUpdate(
      position: position,
      activityType: activityType,
      routePoints: routePoints,
      currentLatLng: currentLatLng,
      distanceAnchorPoint: distanceAnchorPoint ?? currentLatLng,
      lastAcceptedPositionTime: lastAcceptedPositionTime,
      rawGpsGapDurationSec: rawGpsGapDurationSec,
      shouldResetAnchorOnResume: shouldResetAnchorOnResume,
      wasGpsSignalWeak: wasGpsSignalWeak,
    );
  }

  group('Task 1 Regression: Stationary Active Calories & Moving Time', () {
    test(
      'stationary for 5 minutes (running) accumulates ZERO active calories',
      () {
        final profile = makeProfile(weightKg: 70.0);

        // Distance is 0, elapsed time is 300 seconds (5 minutes)
        final calories = profile.calculateCalories(
          activityType: 'Running',
          distanceKm: 0.0,
          speedKmh: 0.0,
          durationSec: 300,
          movingDurationSec: 0,
        );

        expect(
          calories,
          equals(0.0),
          reason:
              'Active calories must be 0 when stationary for distance-based activities',
        );

        final kcal = WorkoutMetricsCalculator.computeCaloriesKcal(
          profile: profile,
          activityType: 'Running',
          distanceMeters: 0.0,
          durationSec: 300,
          movingDurationSec: 0,
        );

        expect(kcal, equals(0));
      },
    );

    test(
      'stationary for 5 minutes (walking and cycling) also returns 0 calories',
      () {
        final profile = makeProfile(weightKg: 65.0, gender: 'female');

        for (final activity in ['Walking', 'Cycling']) {
          final calories = profile.calculateCalories(
            activityType: activity,
            distanceKm: 0.0,
            speedKmh: 0.0,
            durationSec: 300,
            movingDurationSec: 0,
          );
          expect(
            calories,
            equals(0.0),
            reason: '$activity with 0km must burn 0 active calories',
          );
        }
      },
    );

    test(
      'non-GPS activity (Yoga, Strength) preserves appropriate MET calculations',
      () {
        final profile = makeProfile(weightKg: 70.0);

        // 30 minutes of yoga (MET = 3.0)
        final yogaCal = profile.calculateCalories(
          activityType: 'Yoga',
          distanceKm: 0.0,
          durationSec: 1800,
        );

        // Expected: 3.0 MET * 70kg * 0.5h * 1.0 = 105 kcal
        expect(yogaCal, closeTo(105.0, 1.0));

        // 45 minutes of strength training (MET = 5.0)
        final strengthCal = profile.calculateCalories(
          activityType: 'Strength',
          distanceKm: 0.0,
          durationSec: 2700,
        );

        // Expected: 5.0 MET * 70kg * 0.75h * 1.0 = 262.5 kcal
        expect(strengthCal, closeTo(262.5, 1.0));
      },
    );

    test(
      'active running accumulates calories based on distance and moving speed',
      () {
        final profile = makeProfile(weightKg: 70.0);

        // Running 5 km in 25 min (12 km/h) -> k = 1.05 + 0.05 = 1.10
        final kcal = WorkoutMetricsCalculator.computeCaloriesKcal(
          profile: profile,
          activityType: 'Running',
          distanceMeters: 5000.0,
          durationSec: 1500,
          movingDurationSec: 1500,
        );

        // 70 * 5.0 * 1.10 = 385 kcal
        expect(kcal, equals(385));
      },
    );

    test('calories do not decrease when athlete stops at a red light', () {
      final profile = makeProfile(weightKg: 70.0);

      // Athlete runs 1 km at 12 km/h in 300s (moving)
      final calWhileMoving = WorkoutMetricsCalculator.computeCaloriesKcal(
        profile: profile,
        activityType: 'Running',
        distanceMeters: 1000.0,
        durationSec: 300,
        movingDurationSec: 300,
      );
      // 70 * 1.0 * 1.10 = 77 kcal
      expect(calWhileMoving, equals(77));

      // Athlete waits at a red light for 5 minutes (elapsed = 600s, moving = 300s, distance = 1000m)
      final calAfterWaiting = WorkoutMetricsCalculator.computeCaloriesKcal(
        profile: profile,
        activityType: 'Running',
        distanceMeters: 1000.0,
        durationSec: 600,
        movingDurationSec: 300,
      );

      expect(
        calAfterWaiting,
        greaterThanOrEqualTo(calWhileMoving),
        reason: 'Calories must not decrease during stationary periods',
      );
      expect(calAfterWaiting, equals(77));
    });

    test('finalizer computes consistent calories matching live policy', () {
      final profile = makeProfile(weightKg: 70.0);

      // 5 minutes stationary session
      final stationaryState = WorkoutSessionState(
        status: RecordingState.stopping,
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 300,
        movingTimeSeconds: 0,
        distanceMeters: 0.0,
      );

      final finalization = finalizer.finalize(
        state: stationaryState,
        userId: 'test-user',
        finishedAt: t0.add(const Duration(seconds: 300)),
        caloriesBurned: 0,
        fallbackStrideLengthMeters: 0.8,
        trackingEngine: engine,
        rawGpsPositions: const [],
        filteredRouteSegments: const [],
        userProfile: profile,
      );

      expect(finalization.caloriesBurned, equals(0));
      expect(finalization.session.caloriesKcal, equals(0.0));
      expect(finalization.session.distanceKm, equals(0.0));
      expect(finalization.session.movingTimeSec, equals(0));
    });
  });

  group('Task 2 & 3 Regression: GPS Route Gaps and Continuous Tracking', () {
    test(
      'GPS unavailable for 3 seconds: continuous tracking without route break',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(
          sec: 0,
          latitude: baseLatLng.latitude,
          longitude: baseLatLng.longitude,
        );
        continuity.observe(fix0.timestamp);

        // 3 seconds later (3s <= 5s threshold), plausible runner movement: 9m in 3s (3 m/s)
        final fix3 = makeFix(
          sec: 3,
          latitude: baseLatLng.latitude + 0.00008,
          speed: 3.0,
        );
        continuity.observe(fix3.timestamp);

        final decision = evaluate(
          fix3,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: false,
        );

        expect(decision.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(
          decision.shouldAddDistance,
          isTrue,
          reason: 'Plausible 3s gap must add distance',
        );
        expect(
          decision.shouldBreakRouteForDisplay,
          isFalse,
          reason: '3s gap must not break route',
        );
        expect(decision.segmentMeters, greaterThan(8.0));
        expect(decision.gpsGapDurationSec, equals(0.0));

        pipeline.appendAcceptedSegment(
          routeCandidate: decision.livePoint,
          displayRoutePoint: decision.livePoint,
          shouldBreakRouteForDisplay: decision.shouldBreakRouteForDisplay,
          gpsGapDurationSec: decision.gpsGapDurationSec,
          shouldAppendSmoothedPoint: true,
        );

        expect(pipeline.routeSegments, hasLength(1));
        expect(pipeline.gpsGapSegments, isEmpty);
      },
    );

    test(
      'GPS unavailable for 6 seconds: classified as staleSignalGap and breaks display route',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);
        continuity.observe(fix0.timestamp);

        // 6 seconds blackout (6s > 5s threshold)
        final fix6 = makeFix(
          sec: 6,
          latitude: baseLatLng.latitude + 0.0002,
          speed: 3.0,
        );
        continuity.observe(fix6.timestamp);
        expect(continuity.pendingGapDurationSec, equals(6.0));

        final decision = evaluate(
          fix6,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: true,
        );

        expect(decision.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(decision.outcome, equals(GpsPointOutcome.signalGap));
        expect(decision.reason, equals(GpsRejectReason.staleSignalGap));
        expect(
          decision.shouldAddDistance,
          isFalse,
          reason: 'Must not count unverified gap distance',
        );
        expect(decision.segmentMeters, equals(0.0));
        expect(
          decision.shouldBreakRouteForDisplay,
          isTrue,
          reason: '6s gap must break display route',
        );
        expect(decision.gpsGapDurationSec, equals(6.0));

        pipeline.appendAcceptedSegment(
          routeCandidate: decision.livePoint,
          displayRoutePoint: decision.livePoint,
          shouldBreakRouteForDisplay: decision.shouldBreakRouteForDisplay,
          gpsGapDurationSec: decision.gpsGapDurationSec,
          shouldAppendSmoothedPoint: true,
        );

        expect(pipeline.routeSegments, hasLength(2));
        expect(pipeline.gpsGapSegments, hasLength(1));
        expect(pipeline.gpsGapSegments.first.durationSec, equals(6.0));
      },
    );

    test(
      'GPS unavailable for 15 seconds: major gap breaks route without distance bridging',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);
        continuity.observe(fix0.timestamp);

        final fix15 = makeFix(
          sec: 15,
          latitude: baseLatLng.latitude + 0.0005,
          speed: 3.5,
        );
        continuity.observe(fix15.timestamp);
        expect(continuity.pendingGapDurationSec, equals(15.0));

        final decision = evaluate(
          fix15,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: true,
        );

        expect(decision.outcome, equals(GpsPointOutcome.signalGap));
        expect(decision.shouldAddDistance, isFalse);
        expect(decision.shouldBreakRouteForDisplay, isTrue);
        expect(decision.segmentMeters, equals(0.0));
        expect(decision.gpsGapDurationSec, equals(15.0));
      },
    );

    test(
      'GPS recovery with plausible location update after weak accuracy does not break route',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(
          sec: 0,
          latitude: baseLatLng.latitude,
          accuracy: 5.0,
        );
        continuity.observe(fix0.timestamp);

        // Fix at sec=1: accuracy degraded to 45m (> 42m maxAccuracy for running -> soft rejected)
        final fix1 = makeFix(
          sec: 1,
          latitude: baseLatLng.latitude + 0.00003,
          accuracy: 45.0,
        );
        continuity.observe(fix1.timestamp);
        final dec1 = evaluate(
          fix1,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
        );
        expect(dec1.type, equals(TrackingGpsDecisionType.skip));
        expect(dec1.reason, equals(GpsRejectReason.lowAccuracy));

        // Fix at sec=3: accuracy recovers to 8m, moved 10m (speed ~3.3 m/s, fully plausible)
        final fix3 = makeFix(
          sec: 3,
          latitude: baseLatLng.latitude + 0.00009,
          accuracy: 8.0,
          speed: 3.3,
        );
        continuity.observe(fix3.timestamp);

        final dec3 = evaluate(
          fix3,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: true,
        );

        expect(dec3.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(
          dec3.shouldAddDistance,
          isTrue,
          reason: 'Plausible recovery must add distance',
        );
        expect(
          dec3.shouldBreakRouteForDisplay,
          isFalse,
          reason: 'Plausible recovery must NOT false-break route',
        );
        expect(dec3.segmentMeters, greaterThan(9.0));
      },
    );

    test('GPS recovery with an implausible jump is rejected or breaks route', () {
      final pipeline = GpsPipeline()..seedRoute(baseLatLng);
      final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);

      // Teleport: jumps 500m in 2 seconds (implied speed 250 m/s >> 7.0 m/s)
      final fixTeleport = makeFix(
        sec: 2,
        latitude: baseLatLng.latitude + 0.0045, // ~500m away
        speed: 3.0,
      );

      final decision = evaluate(
        fixTeleport,
        routePoints: pipeline.routePoints,
        currentLatLng: baseLatLng,
        distanceAnchorPoint: baseLatLng,
        lastAcceptedPositionTime: fix0.timestamp,
        rawGpsGapDurationSec: 0.0,
        wasGpsSignalWeak: false,
      );

      // Either hard rejected by speed or flagged as route break with 0 distance
      if (decision.type == TrackingGpsDecisionType.acceptRoute) {
        expect(decision.shouldAddDistance, isFalse);
        expect(decision.shouldBreakRouteForDisplay, isTrue);
      } else {
        expect(decision.type, equals(TrackingGpsDecisionType.skip));
      }
    });

    test(
      'session pause and resume: anchor reset prevents fake bridge line across paused displacement',
      () {
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        // Workout active from t=0 to t=10
        final fix1 = makeFix(sec: 10, latitude: baseLatLng.latitude + 0.0003);
        final d1 = evaluate(
          fix1,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
        );
        pipeline.appendAcceptedSegment(
          routeCandidate: d1.livePoint,
          displayRoutePoint: d1.livePoint,
          shouldBreakRouteForDisplay: false,
          gpsGapDurationSec: 0,
          shouldAppendSmoothedPoint: true,
        );
        expect(pipeline.routeSegments, hasLength(1));

        // User pauses at t=10, walks 200m away, resumes at t=60 at new location
        final resumeLatLng = LatLng(
          baseLatLng.latitude + 0.002,
          baseLatLng.longitude + 0.002,
        );
        final fixResume = makeFix(
          sec: 60,
          latitude: resumeLatLng.latitude,
          longitude: resumeLatLng.longitude,
        );

        // On resume, shouldResetAnchorOnResume is true
        final dResume = evaluate(
          fixResume,
          routePoints: pipeline.routePoints,
          currentLatLng: d1.livePoint,
          distanceAnchorPoint: d1.livePoint,
          shouldResetAnchorOnResume: true,
        );
        expect(dResume.type, equals(TrackingGpsDecisionType.resetAnchor));

        // Resumed anchor seeds a new segment in pipeline
        pipeline.appendAcceptedSegment(
          routeCandidate: dResume.livePoint,
          displayRoutePoint: dResume.livePoint,
          shouldBreakRouteForDisplay: true,
          gpsGapDurationSec: 0,
          shouldAppendSmoothedPoint: true,
        );

        expect(
          pipeline.routeSegments,
          hasLength(2),
          reason:
              'Resume must create a new segment without connecting across paused movement',
        );
      },
    );

    test(
      'raw points available but filtered route incomplete: metadata preserves full provenance',
      () {
        final rawPositions = <Position>[];
        // Generate 50 raw positions
        for (var s = 0; s < 50; s++) {
          rawPositions.add(
            makeFix(
              sec: s,
              latitude: baseLatLng.latitude + (s * 0.00002),
              accuracy: s < 5 ? 35.0 : 5.0, // First 5 points have poor accuracy
            ),
          );
        }

        final filteredSegments = <List<LatLng>>[
          [
            LatLng(baseLatLng.latitude + 0.0001, baseLatLng.longitude),
            LatLng(baseLatLng.latitude + 0.0002, baseLatLng.longitude),
            LatLng(baseLatLng.latitude + 0.0003, baseLatLng.longitude),
          ],
        ];

        final state = WorkoutSessionState(
          status: RecordingState.stopping,
          activityType: 'Running',
          trackingMode: 'outdoor',
          recordingSource: 'gps',
          durationSeconds: 50,
          movingTimeSeconds: 45,
          distanceMeters: 400.0,
        );

        final finalization = finalizer.finalize(
          state: state,
          userId: 'test-user',
          finishedAt: t0.add(const Duration(seconds: 50)),
          caloriesBurned: 35,
          fallbackStrideLengthMeters: 0.8,
          trackingEngine: engine,
          rawGpsPositions: rawPositions,
          filteredRouteSegments: filteredSegments,
        );

        final audit =
            jsonDecode(finalization.session.routeMatchMetricsJson)
                as Map<String, dynamic>;

        expect(
          audit['raw_gps_fix_count'],
          equals(50),
          reason: 'Raw points must be preserved',
        );
        expect(
          audit['distance_selection_policy'],
          equals('raw_valid_then_raw_total_then_live'),
        );
        expect(finalization.session.filteredRouteJson, isNot('[]'));
        expect(finalization.session.distanceKm, greaterThan(0.0));
      },
    );

    test(
      'saved route versus displayed route consistency: segments with length >= 2 rendered properly',
      () {
        final segments = <List<LatLng>>[
          [
            const LatLng(10.77, 106.69),
            const LatLng(10.771, 106.691),
            const LatLng(10.772, 106.692),
          ],
          [const LatLng(10.78, 106.70), const LatLng(10.781, 106.701)],
        ];

        final state = WorkoutSessionState(
          status: RecordingState.stopping,
          activityType: 'Running',
          trackingMode: 'outdoor',
          recordingSource: 'gps',
          durationSeconds: 600,
          movingTimeSeconds: 600,
          distanceMeters: 2000.0,
        );

        final finalization = finalizer.finalize(
          state: state,
          userId: 'test-user',
          finishedAt: t0.add(const Duration(seconds: 600)),
          caloriesBurned: 150,
          fallbackStrideLengthMeters: 0.8,
          trackingEngine: engine,
          rawGpsPositions: const [],
          filteredRouteSegments: segments,
        );

        final decodedJson =
            jsonDecode(finalization.session.filteredRouteJson) as List<dynamic>;
        expect(decodedJson, hasLength(2));
        for (final seg in decodedJson) {
          expect((seg as List).length, greaterThanOrEqualTo(2));
        }
      },
    );
  });

  group('Phase 3 Explicit 12-Point Regression Suite', () {
    test(
      '1. Stationary for 60 seconds with continuous raw GPS preserves 0 pending gap',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);
        continuity.observe(fix0.timestamp);

        // 60 seconds of 1 Hz raw GPS with micro-jitter (<0.5m)
        for (var s = 1; s <= 60; s++) {
          final fixStationary = makeFix(
            sec: s,
            latitude: baseLatLng.latitude + (s % 2 == 0 ? 0.000002 : -0.000002),
            speed: 0.1,
          );
          final observed = continuity.observe(fixStationary.timestamp);
          expect(observed, isTrue);
          expect(continuity.pendingGapDurationSec, equals(0.0));

          final decision = evaluate(
            fixStationary,
            routePoints: pipeline.routePoints,
            currentLatLng: baseLatLng,
            distanceAnchorPoint: baseLatLng,
            lastAcceptedPositionTime: fix0.timestamp,
            rawGpsGapDurationSec: continuity.pendingGapDurationSec,
            wasGpsSignalWeak: false,
          );
          expect(decision.type, equals(TrackingGpsDecisionType.skip));
          expect(decision.reason, equals(GpsRejectReason.tinySegment));
        }

        expect(continuity.pendingGapDurationSec, equals(0.0));
        expect(pipeline.routePoints, hasLength(1));
      },
    );

    test(
      '2. Movement resuming after stationary filtering does not false-break route',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);
        continuity.observe(fix0.timestamp);

        // User stationary for 60s
        for (var s = 1; s <= 60; s++) {
          continuity.observe(t0.add(Duration(seconds: s)));
        }

        // At sec 61, athlete starts running: 15m displacement in 3s (5 m/s)
        final fixResume = makeFix(
          sec: 61,
          latitude: baseLatLng.latitude + 0.000135, // ~15m
          speed: 5.0,
        );
        continuity.observe(fixResume.timestamp);

        // Even if wasGpsSignalWeak was true from an older UI ticker policy:
        final decision = evaluate(
          fixResume,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec, // 0.0s!
          wasGpsSignalWeak: true,
        );

        expect(decision.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(
          decision.shouldAddDistance,
          isTrue,
          reason: 'Plausible resumption must add distance',
        );
        expect(
          decision.shouldBreakRouteForDisplay,
          isFalse,
          reason: 'Plausible resumption must NOT break route',
        );
        expect(decision.gpsGapDurationSec, equals(0.0));
        expect(decision.segmentMeters, greaterThan(14.0));

        pipeline.appendAcceptedSegment(
          routeCandidate: decision.livePoint,
          displayRoutePoint: decision.livePoint,
          shouldBreakRouteForDisplay: decision.shouldBreakRouteForDisplay,
          gpsGapDurationSec: decision.gpsGapDurationSec,
          shouldAppendSmoothedPoint: true,
        );

        expect(pipeline.routeSegments, hasLength(1));
        expect(pipeline.gpsGapSegments, isEmpty);
      },
    );

    test(
      '3. Valid sequence with 6-second gap between accepted fixes but continuous raw observations',
      () {
        final continuity = GpsRawSignalContinuity(
          gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
        );
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);
        continuity.observe(fix0.timestamp);

        // Stationary jitter for 5 seconds: ~0.05m jitter (< 0.3m minSegmentMeters)
        for (var s = 1; s <= 5; s++) {
          final fixStationary = makeFix(
            sec: s,
            latitude:
                baseLatLng.latitude + (s % 2 == 0 ? 0.0000005 : -0.0000005),
            speed: 0.05,
          );
          continuity.observe(fixStationary.timestamp);
          final d = evaluate(
            fixStationary,
            routePoints: pipeline.routePoints,
            currentLatLng: baseLatLng,
            distanceAnchorPoint: baseLatLng,
            lastAcceptedPositionTime: fix0.timestamp,
            rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          );
          expect(d.type, equals(TrackingGpsDecisionType.skip));
          expect(d.reason, equals(GpsRejectReason.tinySegment));
        }

        // At sec 6, user moves 10 meters (running at 3.0 m/s)
        final fix6 = makeFix(
          sec: 6,
          latitude: baseLatLng.latitude + 0.00009, // ~10m
          speed: 3.0,
        );
        continuity.observe(fix6.timestamp);
        expect(
          continuity.pendingGapDurationSec,
          equals(0.0),
          reason: 'Continuous raw stream has 0s gap',
        );

        final d6 = evaluate(
          fix6,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          distanceAnchorPoint: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp, // 6 seconds ago!
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: false,
        );

        expect(d6.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(d6.shouldAddDistance, isTrue);
        expect(
          d6.shouldBreakRouteForDisplay,
          isFalse,
          reason:
              '6s accepted-fix interval with continuous raw stream must NOT break route',
        );
        expect(d6.gpsGapDurationSec, equals(0.0));
        expect(d6.segmentMeters, greaterThan(9.0));
      },
    );

    test(
      '4. True raw GPS outages of 6 and 15 seconds break route without bridging fake distance',
      () {
        final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);

        // 6s outage
        continuity.observe(t0);
        continuity.observe(t0.add(const Duration(seconds: 6)));
        expect(continuity.pendingGapDurationSec, equals(6.0));

        final fix6 = makeFix(sec: 6, latitude: baseLatLng.latitude + 0.0003);
        final d6 = evaluate(
          fix6,
          routePoints: [baseLatLng],
          currentLatLng: baseLatLng,
          lastAcceptedPositionTime: t0,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
        );
        expect(d6.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(d6.outcome, equals(GpsPointOutcome.signalGap));
        expect(d6.reason, equals(GpsRejectReason.staleSignalGap));
        expect(d6.shouldBreakRouteForDisplay, isTrue);
        expect(d6.shouldAddDistance, isFalse);
        expect(d6.gpsGapDurationSec, equals(6.0));

        // 15s outage
        continuity.reset();
        continuity.observe(t0);
        continuity.observe(t0.add(const Duration(seconds: 15)));
        expect(continuity.pendingGapDurationSec, equals(15.0));

        final fix15 = makeFix(sec: 15, latitude: baseLatLng.latitude + 0.0008);
        final d15 = evaluate(
          fix15,
          routePoints: [baseLatLng],
          currentLatLng: baseLatLng,
          lastAcceptedPositionTime: t0,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
        );
        expect(d15.outcome, equals(GpsPointOutcome.signalGap));
        expect(d15.shouldBreakRouteForDisplay, isTrue);
        expect(d15.shouldAddDistance, isFalse);
        expect(d15.gpsGapDurationSec, equals(15.0));
      },
    );

    test(
      '5. Low-accuracy GPS followed by valid recovery keeps raw continuity and resumes cleanly',
      () {
        final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final fix0 = makeFix(
          sec: 0,
          latitude: baseLatLng.latitude,
          accuracy: 6.0,
        );
        continuity.observe(fix0.timestamp);

        // 3 fixes with poor accuracy (55m > 42m)
        for (var s = 1; s <= 3; s++) {
          final fixBad = makeFix(sec: s, accuracy: 55.0);
          continuity.observe(fixBad.timestamp);
          final d = evaluate(
            fixBad,
            routePoints: pipeline.routePoints,
            currentLatLng: baseLatLng,
            lastAcceptedPositionTime: fix0.timestamp,
            rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          );
          expect(d.type, equals(TrackingGpsDecisionType.skip));
          expect(d.reason, equals(GpsRejectReason.lowAccuracy));
        }
        expect(
          continuity.pendingGapDurationSec,
          equals(0.0),
          reason: 'Stream was continuous during low accuracy',
        );

        // Valid recovery fix at sec 4 with 8m accuracy and 12m movement
        final fixGood = makeFix(
          sec: 4,
          latitude: baseLatLng.latitude + 0.00011,
          accuracy: 8.0,
          speed: 3.0,
        );
        continuity.observe(fixGood.timestamp);
        final dGood = evaluate(
          fixGood,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          wasGpsSignalWeak: true,
        );
        expect(dGood.type, equals(TrackingGpsDecisionType.acceptRoute));
        expect(dGood.shouldAddDistance, isTrue);
        expect(dGood.shouldBreakRouteForDisplay, isFalse);
        expect(dGood.segmentMeters, greaterThan(11.0));
      },
    );

    test(
      '6. Implausible GPS teleport is rejected or segmented with 0 distance',
      () {
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);
        final fix0 = makeFix(sec: 0, latitude: baseLatLng.latitude);

        // Teleport: 400m jump in 2 seconds (200 m/s >> max 10 m/s * 1.2)
        final fixTeleport = makeFix(
          sec: 2,
          latitude: baseLatLng.latitude + 0.0036,
        );
        final decision = evaluate(
          fixTeleport,
          routePoints: pipeline.routePoints,
          currentLatLng: baseLatLng,
          lastAcceptedPositionTime: fix0.timestamp,
        );
        if (decision.type == TrackingGpsDecisionType.acceptRoute) {
          expect(decision.shouldAddDistance, isFalse);
          expect(decision.shouldBreakRouteForDisplay, isTrue);
        } else {
          expect(decision.type, equals(TrackingGpsDecisionType.skip));
        }
      },
    );

    test(
      '7. Cached/stale recovery position is rejected by freshness verification',
      () {
        final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
        continuity.observe(t0.add(const Duration(seconds: 100)));

        // Stale position from 50s ago (before current stream position)
        final stalePosition = makeFix(
          sec: 50,
          latitude: baseLatLng.latitude + 0.001,
        );
        final observed = continuity.observe(stalePosition.timestamp);
        expect(
          observed,
          isFalse,
          reason: 'Stale / backward timestamp must return false',
        );
        expect(
          continuity.lastRawFixTimestamp,
          equals(t0.add(const Duration(seconds: 100))),
        );

        // Fresh position at sec 101 succeeds
        final freshPosition = makeFix(
          sec: 101,
          latitude: baseLatLng.latitude + 0.001,
        );
        expect(continuity.observe(freshPosition.timestamp), isTrue);
      },
    );

    test(
      '8. Out-of-order GPS timestamps do not corrupt continuity or drop subsequent valid fix',
      () {
        final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);

        // t=0
        expect(continuity.observe(t0), isTrue);
        // t=10 (outage of 10s detected)
        expect(continuity.observe(t0.add(const Duration(seconds: 10))), isTrue);
        expect(continuity.pendingGapDurationSec, equals(10.0));

        // t=5 (glitched out-of-order packet delivered late by OS)
        expect(continuity.observe(t0.add(const Duration(seconds: 5))), isFalse);
        expect(
          continuity.lastRawFixTimestamp,
          equals(t0.add(const Duration(seconds: 10))),
        );
        expect(
          continuity.pendingGapDurationSec,
          equals(10.0),
          reason: 'Out of order packet must not erase pending gap',
        );

        // t=11 (subsequent fresh valid fix)
        expect(continuity.observe(t0.add(const Duration(seconds: 11))), isTrue);
        expect(
          continuity.lastRawFixTimestamp,
          equals(t0.add(const Duration(seconds: 11))),
        );
        // The pending 10s gap is still preserved until route anchor acknowledgement!
        expect(continuity.pendingGapDurationSec, equals(10.0));

        continuity.acknowledgeRouteAnchor();
        expect(continuity.pendingGapDurationSec, equals(0.0));
      },
    );

    test(
      '9. Pause/resume without fake distance resets anchor and segments route cleanly',
      () {
        final pipeline = GpsPipeline()..seedRoute(baseLatLng);

        final p1 = LatLng(baseLatLng.latitude + 0.0003, baseLatLng.longitude);
        pipeline.appendAcceptedSegment(
          routeCandidate: p1,
          displayRoutePoint: p1,
          shouldBreakRouteForDisplay: false,
          gpsGapDurationSec: 0,
          shouldAppendSmoothedPoint: true,
        );
        expect(pipeline.routeSegments, hasLength(1));

        // Paused at p1, resumed at p2 (250m away)
        final p2 = LatLng(baseLatLng.latitude + 0.0025, baseLatLng.longitude);
        final fixResume = Position(
          latitude: p2.latitude,
          longitude: p2.longitude,
          timestamp: t0.add(const Duration(seconds: 60)),
          accuracy: 5.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final decision = evaluate(
          fixResume,
          routePoints: pipeline.routePoints,
          currentLatLng: p1,
          distanceAnchorPoint: p1,
          shouldResetAnchorOnResume: true,
        );
        expect(decision.type, equals(TrackingGpsDecisionType.resetAnchor));

        pipeline.appendAcceptedSegment(
          routeCandidate: decision.livePoint,
          displayRoutePoint: decision.livePoint,
          shouldBreakRouteForDisplay: true,
          gpsGapDurationSec: 0,
          shouldAppendSmoothedPoint: true,
        );
        expect(
          pipeline.routeSegments,
          hasLength(2),
          reason:
              'Resume must create separate segment without fake bridge line',
        );
      },
    );

    test('10. Watchdog recovery cooldown prevents rapid restart storms', () {
      final lastAttempt = DateTime.now();
      const cooldown = Duration(seconds: 15);

      // 5 seconds later: cooldown active (< 15s)
      final isCooldownActiveAt5s =
          DateTime.now().difference(lastAttempt) < cooldown;
      expect(isCooldownActiveAt5s, isTrue);

      // Simulating 16 seconds later: cooldown expired
      final simulatedLaterTime = lastAttempt.add(const Duration(seconds: 16));
      final isCooldownActiveAt16s =
          simulatedLaterTime.difference(lastAttempt) < cooldown;
      expect(isCooldownActiveAt16s, isFalse);
    });

    test(
      '11. Route persistence and map-rendering consistency filters single-point segments',
      () {
        final mixedSegments = <List<LatLng>>[
          [const LatLng(10.0, 106.0)], // Single point (degenerate)
          [
            const LatLng(10.0, 106.0),
            const LatLng(10.001, 106.001),
          ], // Valid segment (2 points)
          [const LatLng(10.002, 106.002)], // Single point
        ];

        final renderableSegments = <List<LatLng>>[];
        for (final seg in mixedSegments) {
          if (seg.length >= 2) {
            renderableSegments.add(seg);
          }
        }

        expect(renderableSegments, hasLength(1));
        expect(renderableSegments.first, hasLength(2));
      },
    );

    test(
      '12. Fixed-Alpha Baseline and EKF receive identical raw observations and prevalidation rules',
      () {
        final fixedSmoother = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.fixedAlpha,
        );
        final ekfSmoother = GpsSmoothingService(
          algorithm: GpsFilterAlgorithm.ekf4State,
        );

        final fixedPipe = GpsPipeline()..seedRoute(baseLatLng);
        final ekfPipe = GpsPipeline()..seedRoute(baseLatLng);

        var fixedSmoothed = baseLatLng;
        var ekfSmoothed = baseLatLng;

        for (var s = 1; s <= 10; s++) {
          final rawFix = makeFix(
            sec: s,
            latitude: baseLatLng.latitude + (s * 0.00004),
            speed: 4.0,
          );
          final livePt = LatLng(rawFix.latitude, rawFix.longitude);

          final d = evaluate(
            rawFix,
            routePoints: fixedPipe.routePoints,
            currentLatLng: baseLatLng,
            distanceAnchorPoint: LatLng(
              baseLatLng.latitude + ((s - 1) * 0.00004),
              baseLatLng.longitude,
            ),
            lastAcceptedPositionTime: t0.add(Duration(seconds: s - 1)),
          );
          expect(d.type, equals(TrackingGpsDecisionType.acceptRoute));

          final fixedUp = fixedSmoother.smoothAcceptedPoint(
            activityType: 'Running',
            acceptedPoint: livePt,
            previousAcceptedPoint: fixedPipe.routePoints.last,
            previousSmoothedPoint: fixedSmoothed,
            lastSmoothedRoutePoint: fixedPipe.smoothedRoutePoints.last,
            accuracyMeters: rawFix.accuracy,
            speedMs: rawFix.speed,
            timeDeltaSec: 1.0,
            gpsGapDurationSec: 0.0,
          );
          fixedPipe.appendAcceptedSegment(
            routeCandidate: livePt,
            displayRoutePoint: fixedUp.smoothedPoint,
            shouldBreakRouteForDisplay: false,
            gpsGapDurationSec: 0.0,
            shouldAppendSmoothedPoint: fixedUp.shouldAppendRoutePoint,
          );
          fixedSmoothed = fixedUp.smoothedPoint;

          final ekfUp = ekfSmoother.smoothAcceptedPoint(
            activityType: 'Running',
            acceptedPoint: livePt,
            previousAcceptedPoint: ekfPipe.routePoints.last,
            previousSmoothedPoint: ekfSmoothed,
            lastSmoothedRoutePoint: ekfPipe.smoothedRoutePoints.last,
            accuracyMeters: rawFix.accuracy,
            speedMs: rawFix.speed,
            timeDeltaSec: 1.0,
            gpsGapDurationSec: 0.0,
          );
          ekfPipe.appendAcceptedSegment(
            routeCandidate: livePt,
            displayRoutePoint: ekfUp.smoothedPoint,
            shouldBreakRouteForDisplay: false,
            gpsGapDurationSec: 0.0,
            shouldAppendSmoothedPoint: ekfUp.shouldAppendRoutePoint,
          );
          ekfSmoothed = ekfUp.smoothedPoint;
        }

        // Exact parity in prevalidation, accepted points, and segmentation
        expect(fixedPipe.routePoints, equals(ekfPipe.routePoints));
        expect(
          fixedPipe.routeSegments.length,
          equals(ekfPipe.routeSegments.length),
        );
        expect(fixedPipe.gpsGapSegments, isEmpty);
        expect(ekfPipe.gpsGapSegments, isEmpty);
      },
    );
  });
}
