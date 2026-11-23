import 'dart:convert';
import 'package:fitness_exercise_application/features/workout/domain/services/research_running_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double? estimate(String activity, double? height, int? cadence) =>
      ResearchRunningStepLength.estimateMeters(
        activityType: activity,
        heightCm: height,
        cadenceSpm: cadence,
      );

  test('RBDS coefficients, Hz conversion and individual step units', () {
    final l = estimate('Running', 175, 180)!;
    expect(
      l,
      closeTo(
        1.75 * (0.3210564550962659 * 3 + 0.7252540911327735) -
            1.680950042382748,
        1e-12,
      ),
    );
    expect(estimate('Running', 175, 190)!, greaterThan(l));
    final contribution = const WorkoutTrackingEngine()
        .computeIndoorStepContribution(
          stepDelta: 10,
          strideLengthMeters: l,
          now: DateTime.utc(2026, 11, 18),
          lastStepTime: null,
        );
    expect(contribution.addedDistanceMeters, closeTo(l * 10, 1e-12));
  });

  test('guard against unsupported data and activity modes', () {
    for (final (activity, height, cadence) in [
      ('Running', null, 180),
      ('Running', double.nan, 180),
      ('Running', 162.6, 180),
      ('Running', 187.3, 180),
      ('Running', 175.0, null),
      ('Running', 175.0, 142),
      ('Running', 175.0, 224),
      ('Walking', 175.0, 180),
      ('Cycling', 175.0, 180),
    ]) {
      expect(estimate(activity, height, cadence), isNull);
    }
    expect(estimate('Running', 162.7, 143), isNotNull);
    expect(estimate('Running', 187.2, 223), isNotNull);
  });

  test(
    'indoor running keeps live adaptive distance and correct model audit',
    () {
      final result = const WorkoutSessionFinalizer().finalize(
        state: WorkoutSessionState(
          status: RecordingState.stopping,
          activityType: 'Running',
          trackingMode: 'indoor',
          recordingSource: 'step_fallback',
          distanceMeters: 250,
          stepCount: 200,
          xuDetectedSteps: 200,
          adaptiveStepCount: 190,
          durationSeconds: 90,
          movingTimeSeconds: 85,
        ),
        userId: 'test',
        finishedAt: DateTime.utc(2026, 11, 18),
        caloriesBurned: 0,
        fallbackStrideLengthMeters: 1.0,
        trackingEngine: const WorkoutTrackingEngine(),
        rawGpsPositions: const [],
        filteredRouteSegments: const [],
      );
      final audit = jsonDecode(result.session.routeMatchMetricsJson);
      expect(result.session.distanceKm, closeTo(.25, 1e-9));
      expect(audit['step_length_model'], 'renaudin2012_rbds_fit');
      expect(audit['adaptive_step_count'], 190);
      expect(audit['xu_detected_step_count'], 200);
      expect(audit['oxford_detected_step_count'], 0);
      expect(
        audit['distance_selection_policy'],
        'live_accumulated_adaptive_run_steps',
      );
    },
  );
}
