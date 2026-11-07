import 'dart:convert';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/batch_trajectory_preprocessor.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/kinematic_limits.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class WorkoutSessionFinalization {
  final String sessionId;
  final int caloriesBurned;
  final double avgSpeedKmh;
  final WorkoutGpsAnalysis gpsAnalysis;
  final WorkoutSession session;

  const WorkoutSessionFinalization({
    required this.sessionId,
    required this.caloriesBurned,
    required this.avgSpeedKmh,
    required this.gpsAnalysis,
    required this.session,
  });
}

class WorkoutSessionFinalizer {
  const WorkoutSessionFinalizer();

  WorkoutSessionFinalization finalize({
    required WorkoutSessionState state,
    required String userId,
    required DateTime finishedAt,
    required int caloriesBurned,
    required double fallbackStrideLengthMeters,
    required WorkoutTrackingEngine trackingEngine,
    required List<Position> rawGpsPositions,
    required List<List<LatLng>> filteredRouteSegments,
    String gpsAlgorithm = 'ekf_4state',
    UserProfile? userProfile,
    bool enableTrajectoryPreprocessing = kEnableTrajectoryPreprocessing,
  }) {
    final gpsAnalysis = trackingEngine.analyzeGpsWorkout(
      GpsWorkoutAnalysisInput(
        rawPositions: rawGpsPositions,
        activityType: state.activityType,
        totalDurationSec: state.durationSeconds,
        fallbackDistanceMeters: state.distanceMeters,
      ),
    );
    final durationSec = state.durationSeconds;
    final movingTimeSec = math.min(state.movingTimeSeconds, durationSec);

    TrajectoryPreprocessingResult? preprocessorResult;
    if (enableTrajectoryPreprocessing && rawGpsPositions.isNotEmpty) {
      try {
        final limits = KinematicLimits.forActivity(state.activityType);
        final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
        final rawSamples = rawGpsPositions.asMap().entries.map((entry) {
          final pos = entry.value;
          return TrajectoryRawSample(
            index: entry.key,
            timestamp: pos.timestamp,
            point: LatLng(pos.latitude, pos.longitude),
            altitudeMeters: pos.altitude,
            sensorSpeedMs: pos.speed,
            accuracyMeters: pos.accuracy,
            sensorHeadingDeg: pos.heading,
            deviceSource: 'finalizer_batch',
          );
        }).toList(growable: false);
        preprocessorResult = batchPreprocessor.process(rawSamples);
      } catch (e) {
        // Fallback safely if batch preprocessing fails on unusual inputs
      }
    }

    final legacyDistanceKm = gpsAnalysis.validDistanceKm > 0
        ? gpsAnalysis.validDistanceKm
        : (gpsAnalysis.totalDistanceKm > 0
              ? gpsAnalysis.totalDistanceKm
              : WorkoutMetricsCalculator.distanceMetersToKm(
                  state.distanceMeters,
                ));

    double filteredRouteDistanceM = 0.0;
    for (final segment in filteredRouteSegments) {
      for (var i = 1; i < segment.length; i++) {
        filteredRouteDistanceM += Geolocator.distanceBetween(
          segment[i - 1].latitude,
          segment[i - 1].longitude,
          segment[i].latitude,
          segment[i].longitude,
        );
      }
    }

    final double distanceKm;
    final String distanceSelectionPolicy;
    if (enableTrajectoryPreprocessing) {
      if (filteredRouteDistanceM > 0) {
        distanceKm = filteredRouteDistanceM / 1000.0;
        distanceSelectionPolicy = 'aekf_filtered_then_preprocessed_clean';
      } else if (preprocessorResult != null &&
          preprocessorResult.cleanDistanceMeters > 0) {
        distanceKm = preprocessorResult.cleanDistanceMeters / 1000.0;
        distanceSelectionPolicy = 'preprocessed_clean_then_raw_valid_then_live';
      } else {
        distanceKm = legacyDistanceKm;
        distanceSelectionPolicy = 'raw_valid_then_raw_total_then_live';
      }
    } else {
      distanceKm = legacyDistanceKm;
      distanceSelectionPolicy = 'raw_valid_then_raw_total_then_live';
    }

    final avgSpeedKmh = WorkoutMetricsCalculator.computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: durationSec,
    );

    var resolvedCalories = caloriesBurned;
    if (userProfile != null) {
      final recalculated = WorkoutMetricsCalculator.computeCaloriesKcal(
        profile: userProfile,
        activityType: state.activityType,
        distanceMeters: distanceKm * 1000.0,
        durationSec: durationSec,
        movingDurationSec: movingTimeSec,
      );
      if (distanceKm <= 0 &&
          userProfile.calculateCalories(
                activityType: state.activityType,
                distanceKm: 1.0,
              ) >
              0) {
        resolvedCalories = 0;
      } else {
        resolvedCalories = math.max(caloriesBurned, recalculated);
      }
    }

    var finalSteps = state.stepCount;
    if (finalSteps <= 0 && state.recordingSource != 'step_fallback') {
      final strideToUse = state.strideLengthMeters > 0
          ? state.strideLengthMeters
          : fallbackStrideLengthMeters;
      finalSteps = math.max(0, (state.distanceMeters / strideToUse).round());
    }

    // The DB column is `uuid`, so the fallback must also be a valid UUID.
    // (A raw epoch string here would make the Supabase insert fail with
    // "invalid input syntax for type uuid", losing the workout silently.)
    final sessionId = _isUuid(state.sessionId)
        ? state.sessionId!
        : const Uuid().v4();

    final routeMetrics = <String, dynamic>{
      'gps_algorithm': gpsAlgorithm,
      'dbscan_enabled': false,
      'filter_branch': 'experiment/ekf4-field-recording',
      'source_revision': kGitRevision,
      'source_fingerprint': kSourceFingerprint,
      'distance_selection_policy': distanceSelectionPolicy,
      'raw_gps_fix_count': rawGpsPositions.length,
      'live_distance_km': state.distanceMeters / 1000.0,
      'saved_distance_km': distanceKm,
      'saved_minus_live_distance_km':
          distanceKm - state.distanceMeters / 1000.0,
      'filtered_route_distance_km': filteredRouteDistanceM / 1000.0,
      'filtered_minus_saved_distance_km':
          filteredRouteDistanceM / 1000.0 - distanceKm,
      'raw_valid_distance_km': gpsAnalysis.validDistanceKm,
      'preprocessing_enabled': preprocessorResult != null,
      if (preprocessorResult != null) ...{
        'preprocessing_clean_distance_km':
            preprocessorResult.cleanDistanceMeters / 1000.0,
        'preprocessing_raw_total_distance_km':
            preprocessorResult.rawTotalDistanceMeters / 1000.0,
        'preprocessing_drift_eliminated_m':
            preprocessorResult.stationaryDriftEliminatedMeters,
        'preprocessing_stay_points_count':
            preprocessorResult.stayPointsCount,
        'preprocessing_stay_duration_sec':
            preprocessorResult.totalStayDurationSeconds,
        'preprocessing_accepted_count':
            preprocessorResult.acceptedCleanCount,
        'preprocessing_rejected_count':
            preprocessorResult.totalRawCount - preprocessorResult.acceptedCleanCount,
        'preprocessing_speed_spikes':
            preprocessorResult.speedSpikeCount,
        'preprocessing_accel_spikes':
            preprocessorResult.accelerationSpikeCount,
        'preprocessing_heading_spikes':
            preprocessorResult.headingSpikeCount,
        'preprocessing_signal_gaps':
            preprocessorResult.signalGapCount,
        'preprocessing_latency_us_per_sample':
            preprocessorResult.latencyPerSampleUs,
        'legacy_vs_clean_delta_km':
            legacyDistanceKm - (preprocessorResult.cleanDistanceMeters / 1000.0),
        'aekf_vs_clean_delta_km':
            (filteredRouteDistanceM - preprocessorResult.cleanDistanceMeters) / 1000.0,
      },
    };
    final session = WorkoutSession(
      id: sessionId,
      userId: userId,
      activityType: state.activityType,
      startedAt:
          state.startedAt?.toUtc() ??
          finishedAt.toUtc().subtract(Duration(seconds: durationSec)),
      endedAt: finishedAt.toUtc(),
      durationSec: durationSec,
      movingTimeSec: movingTimeSec,
      distanceKm: distanceKm,
      steps: finalSteps,
      avgSpeedKmh: avgSpeedKmh,
      caloriesKcal: resolvedCalories.toDouble(),
      mode: state.trackingMode,
      createdAt: finishedAt.toUtc(),
      lapSplits: state.lapSplits,
      gpsAnalysis: gpsAnalysis,
      filteredRouteJson: _encodeRouteSegments(filteredRouteSegments),
      matchedRouteJson: '[]',
      routeMatchStatus: 'pending',
      routeDistanceSource: 'filtered',
      routeMatchMetricsJson: jsonEncode(routeMetrics),
    );

    return WorkoutSessionFinalization(
      sessionId: sessionId,
      caloriesBurned: resolvedCalories,
      avgSpeedKmh: avgSpeedKmh,
      gpsAnalysis: gpsAnalysis,
      session: session,
    );
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

String _encodeRouteSegments(List<List<LatLng>> segments) {
  final jsonSegments = segments
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) => segment
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(growable: false),
      )
      .toList(growable: false);
  return jsonEncode(jsonSegments);
}
