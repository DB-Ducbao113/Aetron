import 'dart:convert';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_walking_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Renaudin Eq. 8 returns metres per single step, not full gait cycle',
    () {
      final length = ResearchWalkingStepLength.estimateMeters(
        activityType: 'Walking',
        heightCm: 175,
        cadenceSpm: 120,
      );
      expect(length, closeTo(0.77803458, 0.00001));
    },
  );

  test('walking estimate adapts to cadence and height', () {
    double estimate(double height, int cadence) =>
        ResearchWalkingStepLength.estimateMeters(
          activityType: 'walking',
          heightCm: height,
          cadenceSpm: cadence,
        )!;
    expect(estimate(175, 140), greaterThan(estimate(175, 100)));
    expect(estimate(180, 120), greaterThan(estimate(165, 120)));
  });

  test(
    'missing, non-finite, out-of-cohort or other activity inputs fall back',
    () {
      for (final (activity, height, cadence) in [
        ('Walking', null, 120),
        ('Walking', double.nan, 120),
        ('Walking', 159.0, 120),
        ('Walking', 189.0, 120),
        ('Walking', 175.0, null),
        ('Walking', 175.0, 0),
        ('Walking', 175.0, 93),
        ('Walking', 175.0, 145),
        ('Running', 175.0, 120),
        ('Cycling', 175.0, 120),
      ]) {
        expect(
          ResearchWalkingStepLength.estimateMeters(
            activityType: activity,
            heightCm: height,
            cadenceSpm: cadence,
          ),
          isNull,
        );
      }
    },
  );

  test('step contribution sums individual steps without doubling distance', () {
    final length = ResearchWalkingStepLength.estimateMeters(
      activityType: 'Walking',
      heightCm: 175,
      cadenceSpm: 120,
    )!;
    final c = const WorkoutTrackingEngine().computeIndoorStepContribution(
      stepDelta: 6,
      strideLengthMeters: length,
      now: DateTime.utc(2026, 1, 1, 0, 0, 3),
      lastStepTime: DateTime.utc(2026, 1, 1),
    );
    expect(c.addedDistanceMeters, closeTo(length * 6, 1e-9));
    expect(c.instantSpeedKmh, closeTo(length * 2 * 3.6, 1e-9));
  });
  test(
    'indoor session preserves accumulated adaptive distance and audit count',
    () {
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        activityType: 'Walking',
        trackingMode: 'indoor',
        recordingSource: 'step_fallback',
        distanceMeters: 157,
        stepCount: 200,
        adaptiveStepCount: 180,
        durationSeconds: 120,
        movingTimeSeconds: 110,
      );
      final result = const WorkoutSessionFinalizer().finalize(
        state: state,
        userId: 'test',
        finishedAt: DateTime.utc(2026, 11, 18),
        caloriesBurned: 0,
        fallbackStrideLengthMeters: .75,
        trackingEngine: const WorkoutTrackingEngine(),
        rawGpsPositions: const [],
        filteredRouteSegments: const [],
      );
      expect(result.session.distanceKm, closeTo(.157, 1e-9));
      final audit = jsonDecode(result.session.routeMatchMetricsJson);
      expect(audit['adaptive_step_count'], 180);
      expect(
        audit['distance_selection_policy'],
        'live_accumulated_adaptive_walk_steps',
      );
    },
  );
}
