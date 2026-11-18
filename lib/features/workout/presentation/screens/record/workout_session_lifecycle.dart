import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';

class WorkoutSessionLifecycle {
  const WorkoutSessionLifecycle();

  WorkoutSessionState createInitializingState({
    required String sessionId,
    required String activityType,
    required String trackingMode,
    required String environmentHint,
    required String recordingSource,
    required bool modeDecisionLocked,
    required double strideLengthMeters,
    required DateTime startedAt,
  }) {
    return WorkoutSessionState(
      status: RecordingState.initializing,
      sessionId: sessionId,
      activityType: activityType,
      trackingMode: trackingMode,
      environmentHint: environmentHint,
      recordingSource: recordingSource,
      gpsFallbackActive: false,
      modeDecisionLocked: modeDecisionLocked,
      strideLengthMeters: strideLengthMeters,
      startedAt: startedAt,
      pausedAutoStopRemainingSeconds: 0,
    );
  }

  WorkoutSessionState activate({
    required WorkoutSessionState current,
    required String recordingSource,
  }) {
    return current.copyWith(
      status: RecordingState.active,
      durationSeconds: 0,
      movingTimeSeconds: 0,
      distanceMeters: 0,
      gpsDistanceMeters: 0,
      stepDistanceMeters: 0,
      researchDetectedSteps: 0,
      xuDetectedSteps: 0,
      adaptiveStepCount: 0,
      speedKmh: 0,
      stepCount: 0,
      caloriesBurned: 0,
      lapSplits: const [],
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: 0,
      recordingSource: recordingSource,
    );
  }

  WorkoutSessionState pause({
    required WorkoutSessionState current,
    required int pauseAutoStopRemainingSeconds,
  }) {
    return current.copyWith(
      status: RecordingState.paused,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: pauseAutoStopRemainingSeconds,
    );
  }

  WorkoutSessionState resume(WorkoutSessionState current) {
    return current.copyWith(
      status: RecordingState.active,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: 0,
    );
  }

  /// A missing or rejected GPS fix means signal quality is unknown, not that
  /// the athlete stopped moving. Keep the workout active and preserve the last
  /// confirmed speed until a later GPS update can revise it.
  WorkoutSessionState markGpsSignalWeak({
    required WorkoutSessionState current,
  }) {
    return current.copyWith(isGpsSignalWeak: true, isAutoPaused: false);
  }

  WorkoutSessionState stopping(WorkoutSessionState current) {
    return current.copyWith(
      status: RecordingState.stopping,
      speedKmh: 0,
      isAutoPaused: false,
      pausedAutoStopRemainingSeconds: 0,
    );
  }

  WorkoutSessionState finish({
    required WorkoutSessionState current,
    required int caloriesBurned,
    required double avgSpeedKmh,
    required String sessionId,
    required WorkoutGpsAnalysis gpsAnalysis,
  }) {
    return current.copyWith(
      status: RecordingState.finished,
      caloriesBurned: caloriesBurned,
      avgSpeedKmh: avgSpeedKmh,
      sessionId: sessionId,
      gpsAnalysis: gpsAnalysis,
      pausedAutoStopRemainingSeconds: 0,
    );
  }
}
