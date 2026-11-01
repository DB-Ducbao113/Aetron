import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_environment_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_lifecycle.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_sensor_bootstrapper.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_starter.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('WorkoutTrackingEngine', () {
    const engine = WorkoutTrackingEngine();

    Position buildPosition({
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      double accuracy = 5,
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

    test('seeds first route point when first fix is accurate enough', () {
      final decision = engine.evaluateGpsUpdate(
        position: buildPosition(
          latitude: 10.0,
          longitude: 106.0,
          timestamp: DateTime.utc(2026, 4, 14, 10),
          accuracy: 4,
        ),
        activityType: 'running',
        routePoints: const [],
        currentLatLng: null,
        distanceAnchorPoint: null,
        lastAcceptedPositionTime: null,
        shouldResetAnchorOnResume: false,
      );

      expect(decision.type, TrackingGpsDecisionType.seedRoute);
      expect(decision.previewPoint, decision.livePoint);
    });

    test('skips tiny GPS segment for walking', () {
      final t0 = DateTime.utc(2026, 4, 14, 10);
      final decision = engine.evaluateGpsUpdate(
        position: buildPosition(
          latitude: 10.000001,
          longitude: 106.0,
          timestamp: t0.add(const Duration(seconds: 2)),
          accuracy: 4,
        ),
        activityType: 'walking',
        routePoints: const [LatLng(10.0, 106.0)],
        currentLatLng: const LatLng(10.0, 106.0),
        distanceAnchorPoint: const LatLng(10.0, 106.0),
        lastAcceptedPositionTime: t0,
        shouldResetAnchorOnResume: false,
      );

      expect(decision.type, TrackingGpsDecisionType.skip);
      expect(decision.skipReason, contains('segment='));
    });

    test('accepts reasonable GPS segment and computes candidate speed', () {
      final t0 = DateTime.utc(2026, 4, 14, 10);
      final decision = engine.evaluateGpsUpdate(
        position: buildPosition(
          latitude: 10.0001,
          longitude: 106.0,
          timestamp: t0.add(const Duration(seconds: 5)),
          accuracy: 4,
        ),
        activityType: 'running',
        routePoints: const [LatLng(10.0, 106.0)],
        currentLatLng: const LatLng(10.0, 106.0),
        distanceAnchorPoint: const LatLng(10.0, 106.0),
        lastAcceptedPositionTime: t0,
        shouldResetAnchorOnResume: false,
      );

      expect(decision.type, TrackingGpsDecisionType.acceptRoute);
      expect(decision.segmentMeters, greaterThan(0.3));
      expect(decision.candidateSpeedKmh, greaterThan(0));
    });

    test(
      'accepts GPS recovery route without adding distance after a stale gap (> 20s)',
      () {
        final t0 = DateTime.utc(2026, 4, 14, 10);
        final decision = engine.evaluateGpsUpdate(
          position: buildPosition(
            latitude: 10.0002,
            longitude: 106.0,
            timestamp: t0.add(const Duration(seconds: 25)),
            accuracy: 4,
          ),
          activityType: 'running',
          routePoints: const [LatLng(10.0, 106.0)],
          currentLatLng: const LatLng(10.0, 106.0),
          distanceAnchorPoint: const LatLng(10.0, 106.0),
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );

        expect(decision.type, TrackingGpsDecisionType.acceptRoute);
        expect(decision.shouldAddDistance, isFalse);
        expect(decision.segmentMeters, 0);
        expect(decision.gpsGapDurationSec, greaterThan(20));
      },
    );

    test(
      'continues route when accepted fixes lag but raw GPS arrived throughout',
      () {
        final t0 = DateTime.utc(2026, 4, 14, 10);
        final decision = engine.evaluateGpsUpdate(
          position: buildPosition(
            latitude: 10.0002, // ~22.2m displacement
            longitude: 106.0,
            timestamp: t0.add(
              const Duration(seconds: 8),
            ), // implied speed 2.78m/s (10km/h)
            accuracy: 6,
            speed: 2.8,
          ),
          activityType: 'running',
          routePoints: const [LatLng(10.0, 106.0)],
          currentLatLng: const LatLng(10.0, 106.0),
          distanceAnchorPoint: const LatLng(10.0, 106.0),
          lastAcceptedPositionTime: t0,
          // Intermediate raw fixes arrived each second but were not accepted.
          rawGpsGapDurationSec: 1.0,
          shouldResetAnchorOnResume: false,
        );

        expect(decision.type, TrackingGpsDecisionType.acceptRoute);
        expect(decision.shouldAddDistance, isTrue);
        expect(decision.segmentMeters, greaterThan(20.0));
        expect(decision.shouldBreakRouteForDisplay, isFalse);
      },
    );

    test(
      'does not freeze GPS route just because walking speed looks like running',
      () {
        final t0 = DateTime.utc(2026, 4, 14, 10);
        final decision = engine.evaluateGpsUpdate(
          position: buildPosition(
            latitude: 10.00018,
            longitude: 106.0,
            timestamp: t0.add(const Duration(seconds: 5)),
            accuracy: 4,
          ),
          activityType: 'walking',
          routePoints: const [LatLng(10.0, 106.0)],
          currentLatLng: const LatLng(10.0, 106.0),
          distanceAnchorPoint: const LatLng(10.0, 106.0),
          lastAcceptedPositionTime: t0,
          shouldResetAnchorOnResume: false,
        );

        expect(decision.type, TrackingGpsDecisionType.acceptRoute);
        expect(decision.candidateSpeedKmh, greaterThan(10));
      },
    );

    test('flags walking result as invalid when average speed is too high', () {
      final assessment = engine.assessActivityConsistency(
        activityType: 'walking',
        avgSpeedKmh: 12.5,
        distanceKm: 2.0,
        durationSec: 600,
      );

      expect(assessment.shouldInvalidateResult, isTrue);
      expect(assessment.reason, 'avg_speed_too_high_for_walking');
    });

    test(
      'marks a cycling workout unverified when GPS gaps consume most of it',
      () {
        final startedAt = DateTime.utc(2026, 10, 12, 20, 30);
        final analysis = engine.analyzeGpsWorkout(
          GpsWorkoutAnalysisInput(
            activityType: 'cycling',
            totalDurationSec: 21 * 60 + 14,
            fallbackDistanceMeters: 4110,
            rawPositions: [
              buildPosition(
                latitude: 10.0,
                longitude: 106.0,
                timestamp: startedAt,
                speed: 3.8,
              ),
              buildPosition(
                latitude: 10.00015,
                longitude: 106.0,
                timestamp: startedAt.add(const Duration(seconds: 5)),
                speed: 3.8,
              ),
              buildPosition(
                latitude: 10.00030,
                longitude: 106.0,
                timestamp: startedAt.add(
                  const Duration(minutes: 21, seconds: 14),
                ),
                speed: 3.8,
              ),
            ],
          ),
        );

        expect(analysis.gpsGapCount, 1);
        expect(analysis.gpsGapDurationSec, greaterThan(1200));
        expect(analysis.validityFlag, WorkoutValidityFlag.unverified);
      },
    );

    test('does not switch cycling to step fallback after a GPS gap', () {
      final startedAt = DateTime.utc(2026, 10, 12, 20, 30);

      final decision = engine.evaluateStepUpdate(
        sessionSteps: 12,
        currentStepCount: 0,
        activityType: 'cycling',
        requiresGpsTracking: true,
        gpsFallbackActive: false,
        recordingSource: 'gps',
        lastAcceptedPositionTime: startedAt,
        now: startedAt.add(const Duration(seconds: 13)),
      );

      expect(decision.shouldActivateGpsFallback, isFalse);
    });
  });

  group('WorkoutSessionStarter', () {
    const starter = WorkoutSessionStarter();

    test('creates outdoor start plan for GPS activities', () {
      final plan = starter.createPlan(
        sessionId: 'session-1',
        activityType: 'Running',
        requiresGps: true,
        strideLengthMeters: 0.92,
        startedAt: DateTime.utc(2026, 4, 14, 10),
        outdoorMode: 'outdoor',
        indoorMode: 'indoor',
        recordingSource: 'gps',
      );

      expect(plan.trackingMode, 'outdoor');
      expect(plan.environmentHint, 'detecting');
      expect(plan.modeDecisionLocked, isTrue);
    });

    test('applies indoor bootstrap state', () {
      final baseState = WorkoutSessionState(
        status: RecordingState.initializing,
        activityType: 'Workout',
        trackingMode: 'auto',
      );

      final bootstrapped = starter.applyIndoorBootstrap(baseState);

      expect(bootstrapped.trackingMode, 'indoor');
      expect(bootstrapped.recordingSource, 'step_fallback');
      expect(bootstrapped.gpsFallbackActive, isTrue);
    });
  });

  group('WorkoutSessionFinalizer', () {
    const finalizer = WorkoutSessionFinalizer();
    const trackingEngine = WorkoutTrackingEngine();

    test('finalizes canonical distance, speed and timestamps', () {
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: '11111111-1111-4111-8111-111111111111',
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 1800,
        distanceMeters: 5000,
        stepCount: 6200,
        strideLengthMeters: 0.9,
        startedAt: DateTime.utc(2026, 4, 14, 9, 30),
      );

      final result = finalizer.finalize(
        state: state,
        userId: 'user-1',
        finishedAt: DateTime.utc(2026, 4, 14, 10, 0),
        caloriesBurned: 420,
        fallbackStrideLengthMeters: 0.8,
        trackingEngine: trackingEngine,
        rawGpsPositions: const [],
        filteredRouteSegments: const [
          [LatLng(10.0, 106.0), LatLng(10.001, 106.001)],
        ],
      );

      expect(result.session.id, '11111111-1111-4111-8111-111111111111');
      expect(result.session.distanceKm, closeTo(5.0, 0.0001));
      expect(result.avgSpeedKmh, closeTo(10.0, 0.0001));
      expect(result.session.steps, 6200);
      expect(result.session.startedAt, DateTime.utc(2026, 4, 14, 9, 30));
      expect(result.session.endedAt, DateTime.utc(2026, 4, 14, 10, 0));
      expect(result.session.routeMatchStatus, 'pending');
      expect(result.session.routeDistanceSource, 'filtered');
      expect(result.session.matchedRouteJson, '[]');
      expect(result.session.filteredRouteJson, isNot('[]'));

      final audit =
          jsonDecode(result.session.routeMatchMetricsJson)
              as Map<String, dynamic>;
      expect(
        audit['distance_selection_policy'],
        'raw_valid_then_raw_total_then_live',
      );
      expect(audit['raw_gps_fix_count'], 0);
      expect(audit['live_distance_km'], 5.0);
      expect(audit['saved_distance_km'], 5.0);
      expect(audit['saved_minus_live_distance_km'], 0.0);
      // Displayed route geometry may differ from saved workout distance.
      expect(audit['filtered_route_distance_km'], lessThan(5.0));
      expect(audit['filtered_minus_saved_distance_km'], lessThan(0.0));
    });

    test('estimates steps from stride when sensor steps are unavailable', () {
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        activityType: 'Walking',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 600,
        distanceMeters: 800,
        stepCount: 0,
        strideLengthMeters: 0.0,
      );

      final result = finalizer.finalize(
        state: state,
        userId: 'user-1',
        finishedAt: DateTime.utc(2026, 4, 14, 10, 10),
        caloriesBurned: 60,
        fallbackStrideLengthMeters: 0.8,
        trackingEngine: trackingEngine,
        rawGpsPositions: const [],
        filteredRouteSegments: const [
          [LatLng(10.0, 106.0), LatLng(10.0005, 106.0005)],
        ],
      );

      expect(result.session.steps, 1000);
      expect(result.session.id, isNotEmpty);
      expect(result.session.routeMatchStatus, 'pending');
      expect(result.session.routeDistanceSource, 'filtered');
    });

    test('replaces a non-UUID session id with a valid UUID', () {
      // Regression: workout_sessions.id is a Postgres uuid column. Finalizing
      // with a raw epoch string made the Supabase upsert fail with
      // "invalid input syntax for type uuid", silently losing the workout.
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: 'session-1',
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 300,
        distanceMeters: 1000,
      );

      final result = finalizer.finalize(
        state: state,
        userId: 'user-1',
        finishedAt: DateTime.utc(2026, 4, 14, 10, 0),
        caloriesBurned: 50,
        fallbackStrideLengthMeters: 0.8,
        trackingEngine: trackingEngine,
        rawGpsPositions: const [],
        filteredRouteSegments: const [],
      );

      expect(
        result.session.id,
        matches(
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
            r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ),
        ),
      );
      expect(result.sessionId, result.session.id);
    });

    test('serializes filtered route segments into filteredRouteJson', () {
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: 'session-route',
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 900,
        distanceMeters: 2400,
        startedAt: DateTime.utc(2026, 4, 14, 9, 45),
      );

      final result = finalizer.finalize(
        state: state,
        userId: 'user-1',
        finishedAt: DateTime.utc(2026, 4, 14, 10, 0),
        caloriesBurned: 210,
        fallbackStrideLengthMeters: 0.8,
        trackingEngine: trackingEngine,
        rawGpsPositions: const [],
        filteredRouteSegments: const [
          [LatLng(10.0, 106.0), LatLng(10.001, 106.001)],
          [LatLng(10.002, 106.002)],
        ],
      );

      final decoded = jsonDecode(result.session.filteredRouteJson) as List;

      expect(decoded, hasLength(2));
      expect((decoded[0] as List), hasLength(2));
      expect((decoded[1] as List), hasLength(1));
      expect(result.session.routeDistanceSource, 'filtered');
      expect(result.session.matchedRouteJson, '[]');
    });
  });

  group('WorkoutSessionLifecycle', () {
    const lifecycle = WorkoutSessionLifecycle();

    test('creates initializing state with recording metadata', () {
      final startedAt = DateTime.utc(2026, 4, 14, 10);
      final state = lifecycle.createInitializingState(
        sessionId: 'session-1',
        activityType: 'Running',
        trackingMode: 'outdoor',
        environmentHint: 'detecting',
        recordingSource: 'gps',
        modeDecisionLocked: true,
        strideLengthMeters: 0.92,
        startedAt: startedAt,
      );

      expect(state.status, RecordingState.initializing);
      expect(state.sessionId, 'session-1');
      expect(state.startedAt, startedAt);
      expect(state.recordingSource, 'gps');
    });

    test('pause, resume and finish update status-critical fields', () {
      final base = WorkoutSessionState(
        status: RecordingState.active,
        activityType: 'Running',
        trackingMode: 'outdoor',
        speedKmh: 8.5,
        pausedAutoStopRemainingSeconds: 10,
      );

      final paused = lifecycle.pause(
        current: base,
        pauseAutoStopRemainingSeconds: 120,
      );
      final resumed = lifecycle.resume(paused);
      final finished = lifecycle.finish(
        current: resumed,
        caloriesBurned: 320,
        avgSpeedKmh: 10.2,
        sessionId: 'session-9',
        gpsAnalysis: const WorkoutGpsAnalysis(),
      );

      expect(paused.status, RecordingState.paused);
      expect(paused.speedKmh, 0);
      expect(paused.pausedAutoStopRemainingSeconds, 120);
      expect(resumed.status, RecordingState.active);
      expect(resumed.pausedAutoStopRemainingSeconds, 0);
      expect(finished.status, RecordingState.finished);
      expect(finished.caloriesBurned, 320);
      expect(finished.avgSpeedKmh, closeTo(10.2, 0.0001));
      expect(finished.sessionId, 'session-9');
    });

    test('marks a GPS gap as weak signal without auto-pausing cycling', () {
      final cycling = WorkoutSessionState(
        status: RecordingState.active,
        activityType: 'Cycling',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        speedKmh: 14,
        isAutoPaused: true,
      );

      final updated = lifecycle.markGpsSignalWeak(current: cycling);

      expect(updated.status, RecordingState.active);
      expect(updated.isGpsSignalWeak, isTrue);
      expect(updated.isAutoPaused, isFalse);
      expect(updated.speedKmh, 14);
    });
  });

  group('WorkoutSensorBootstrapper', () {
    const bootstrapper = WorkoutSensorBootstrapper();

    test(
      'applies last known GPS position to both initial and current point',
      () {
        final base = WorkoutSessionState(
          status: RecordingState.initializing,
          activityType: 'Running',
          trackingMode: 'outdoor',
        );

        final updated = bootstrapper.applyLastKnownPosition(
          current: base,
          latitude: 10.123,
          longitude: 106.456,
        );

        expect(updated.initialPosition, const LatLng(10.123, 106.456));
        expect(updated.currentLatLng, const LatLng(10.123, 106.456));
      },
    );

    test('converts GPS startup failure into indoor fallback state', () {
      final base = WorkoutSessionState(
        status: RecordingState.initializing,
        activityType: 'Running',
        trackingMode: 'outdoor',
      );

      final updated = bootstrapper.applyGpsStartupFailure(
        base,
        'location_disabled',
        supportsStepFallback: true,
      );

      expect(updated.trackingMode, 'indoor');
      expect(updated.recordingSource, 'step_fallback');
      expect(updated.gpsFallbackActive, isTrue);
      expect(updated.errorMessage, 'location_disabled');
    });

    test('keeps cycling GPS-based when GPS cannot start', () {
      final base = WorkoutSessionState(
        status: RecordingState.initializing,
        activityType: 'Cycling',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
      );

      final updated = bootstrapper.applyGpsStartupFailure(
        base,
        'location_disabled',
        supportsStepFallback: false,
      );

      expect(updated.trackingMode, 'outdoor');
      expect(updated.recordingSource, 'gps');
      expect(updated.gpsFallbackActive, isFalse);
      expect(updated.isGpsSignalWeak, isTrue);
    });
  });

  group('WorkoutEnvironmentController', () {
    Position buildPosition({
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      double accuracy = 8,
      double speed = 1.2,
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

    test('emits classifier events after start and position feed', () async {
      final controller = WorkoutEnvironmentController();
      final events = <dynamic>[];

      await controller.start(activityType: 'walking', onEvent: events.add);

      final t0 = DateTime.utc(2026, 4, 14, 10);
      controller.addPosition(
        buildPosition(latitude: 10.0, longitude: 106.0, timestamp: t0),
      );
      controller.addPosition(
        buildPosition(
          latitude: 10.00001,
          longitude: 106.0,
          timestamp: t0.add(const Duration(seconds: 1)),
        ),
      );
      controller.addPosition(
        buildPosition(
          latitude: 10.00002,
          longitude: 106.0,
          timestamp: t0.add(const Duration(seconds: 2)),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.stop();

      expect(events, isNotEmpty);
    });
  });
}
