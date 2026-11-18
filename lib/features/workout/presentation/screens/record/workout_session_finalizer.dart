import 'dart:convert';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/batch_trajectory_preprocessor.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/kinematic_limits.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/kinematic_trajectory_reconstruction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/trajectory_reconstruction_models.dart';
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
    bool enableTrajectoryReconstruction = kEnableTrajectoryReconstruction,
    ReconstructionMethod? reconstructionMethod,
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

    final canReconstruct =
        enableTrajectoryReconstruction &&
        rawGpsPositions.length >= 2 &&
        state.trackingMode == 'outdoor' &&
        state.adaptiveStepCount == 0 &&
        state.stepDistanceMeters == 0 &&
        !state.isIndoorSyntheticRoute &&
        filteredRouteSegments.length <= 1;
    TrajectoryPreprocessingResult? preprocessorResult;
    if ((enableTrajectoryPreprocessing || canReconstruct) &&
        rawGpsPositions.isNotEmpty) {
      try {
        final limits = KinematicLimits.forActivity(state.activityType);
        final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
        final rawSamples = rawGpsPositions
            .asMap()
            .entries
            .map((entry) {
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
            })
            .toList(growable: false);
        preprocessorResult = batchPreprocessor.process(rawSamples);
      } catch (e) {
        // Fallback safely if batch preprocessing fails on unusual inputs
      }
    }

    TrajectoryReconstructionResult? reconstructionResult;
    if (canReconstruct &&
        preprocessorResult != null &&
        preprocessorResult.processedPoints.isNotEmpty) {
      try {
        const reconstructionEngine = KinematicTrajectoryReconstructionEngine();
        final candidate = reconstructionEngine.reconstructTrajectory(
          points: preprocessorResult.processedPoints,
          activityType: state.activityType,
          method:
              reconstructionMethod ??
              (kTrajectoryReconstructionMethod == 'monotonePchip'
                  ? ReconstructionMethod.monotonePchip
                  : ReconstructionMethod.linearChord),
        );
        // On dense routes prefer the existing validated display geometry.
        if (candidate.interpolatedPointCount > 0 ||
            candidate.indeterminateGapCount > 0) {
          reconstructionResult = candidate;
        }
      } catch (e) {
        // Fallback safely if reconstruction fails
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
    if (state.stepDistanceMeters > 0) {
      // The provider records step-only distance separately and breaks its
      // genuine GNSS route when recovering. Do not re-add the gap or the
      // display-only P03 route, and never discard step-only contributions.
      final gpsMeters =
          enableTrajectoryPreprocessing && filteredRouteDistanceM > 0
          ? filteredRouteDistanceM
          : state.gpsDistanceMeters;
      distanceKm = (gpsMeters + state.stepDistanceMeters) / 1000.0;
      distanceSelectionPolicy = gpsMeters > 0
          ? 'segmented_gps_plus_step_distance'
          : 'live_step_distance_only';
    } else if (state.adaptiveStepCount > 0 && state.trackingMode == 'indoor') {
      // Indoor estimated distance is accumulated from step contributions.
      // Mixed sessions ending outdoors retain the existing GPS validation policy.
      distanceKm = WorkoutMetricsCalculator.distanceMetersToKm(
        state.distanceMeters,
      );
      distanceSelectionPolicy = state.activityType.toLowerCase() == 'running'
          ? 'live_accumulated_adaptive_run_steps'
          : 'live_accumulated_adaptive_walk_steps';
    } else if (enableTrajectoryPreprocessing &&
        state.trackingMode == 'outdoor' &&
        rawGpsPositions.length >= 2) {
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
      resolvedCalories =
          UserProfile.compendiumDistanceMet(activityType: state.activityType) !=
              null
          ? recalculated
          : math.max(caloriesBurned, recalculated);
    }

    // Missing step measurements are not inferred from GPS distance.
    final finalSteps = state.activityType.toLowerCase() == 'cycling'
        ? 0
        : math.max(0, state.stepCount);

    // The DB column is `uuid`, so the fallback must also be a valid UUID.
    // (A raw epoch string here would make the Supabase insert fail with
    // "invalid input syntax for type uuid", losing the workout silently.)
    final sessionId = _isUuid(state.sessionId)
        ? state.sessionId!
        : const Uuid().v4();

    final routeMetrics = <String, dynamic>{
      if (state.status == RecordingState.stopping ||
          state.status == RecordingState.finished)
        'scientific_result_version': 1,
      'gps_algorithm': gpsAlgorithm,
      'dbscan_enabled': false,
      'filter_branch': 'experiment/ekf4-field-recording',
      'source_revision': kGitRevision,
      'source_fingerprint': kSourceFingerprint,
      'distance_selection_policy': distanceSelectionPolicy,
      if (state.adaptiveStepCount > 0) ...{
        'step_length_model': state.activityType.toLowerCase() == 'running'
            ? 'renaudin2012_rbds_fit'
            : 'renaudin2012_sledataset2_fit',
        'adaptive_step_count': state.adaptiveStepCount,
      },
      'step_distance_m': state.stepDistanceMeters,
      'gps_live_distance_m': state.gpsDistanceMeters,
      'oxford_detected_step_count': state.researchDetectedSteps,
      'xu_detected_step_count': state.xuDetectedSteps,
      if (state.stepDistanceMeters > 0)
        'step_length_fallback':
            'renaudin_cohort_mean_frequency_or_population_step',
      'step_count_policy': state.activityType.toLowerCase() == 'cycling'
          ? 'not_applicable'
          : 'sensor_count_only',
      // Match the remote upsert conflict key, so duplicate observations
      // cannot leave deterministic finalization waiting for nonexistent rows.
      'raw_gps_observation_count': rawGpsPositions.length,
      'raw_gps_fix_count': rawGpsPositions
          .map(
            (position) => (
              position.timestamp.microsecondsSinceEpoch,
              position.latitude,
              position.longitude,
            ),
          )
          .toSet()
          .length,
      'live_distance_km': state.distanceMeters / 1000.0,
      'saved_distance_km': distanceKm,
      'saved_minus_live_distance_km':
          distanceKm - state.distanceMeters / 1000.0,
      'filtered_route_distance_km': filteredRouteDistanceM / 1000.0,
      'filtered_minus_saved_distance_km':
          filteredRouteDistanceM / 1000.0 - distanceKm,
      'raw_valid_distance_km': gpsAnalysis.validDistanceKm,
      'preprocessing_enabled': preprocessorResult != null,
      'preprocessing_distance_policy_enabled': enableTrajectoryPreprocessing,
      if (preprocessorResult != null) ...{
        'preprocessing_clean_distance_km':
            preprocessorResult.cleanDistanceMeters / 1000.0,
        'preprocessing_raw_total_distance_km':
            preprocessorResult.rawTotalDistanceMeters / 1000.0,
        'preprocessing_drift_eliminated_m':
            preprocessorResult.stationaryDriftEliminatedMeters,
        'preprocessing_stay_points_count': preprocessorResult.stayPointsCount,
        'preprocessing_stay_duration_sec':
            preprocessorResult.totalStayDurationSeconds,
        'preprocessing_accepted_count': preprocessorResult.acceptedCleanCount,
        'preprocessing_rejected_count':
            preprocessorResult.totalRawCount -
            preprocessorResult.acceptedCleanCount,
        'preprocessing_speed_spikes': preprocessorResult.speedSpikeCount,
        'preprocessing_accel_spikes': preprocessorResult.accelerationSpikeCount,
        'preprocessing_heading_spikes': preprocessorResult.headingSpikeCount,
        'preprocessing_signal_gaps': preprocessorResult.signalGapCount,
        'preprocessing_latency_us_per_sample':
            preprocessorResult.latencyPerSampleUs,
        'legacy_vs_clean_delta_km':
            legacyDistanceKm -
            (preprocessorResult.cleanDistanceMeters / 1000.0),
        'aekf_vs_clean_delta_km':
            (filteredRouteDistanceM - preprocessorResult.cleanDistanceMeters) /
            1000.0,
      },
      'reconstruction_enabled': reconstructionResult != null,
      if (reconstructionResult != null) ...{
        'reconstruction_method': reconstructionResult.method.name,
        'reconstruction_interpolated_points':
            reconstructionResult.interpolatedPointCount,
        'reconstruction_indeterminate_outages':
            reconstructionResult.indeterminateGapCount,
        'reconstruction_distance_km':
            reconstructionResult.totalReconstructedDistanceMeters / 1000.0,
        'reconstruction_interpolation_ratio':
            reconstructionResult.interpolationRatio,
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
      matchedRouteJson: reconstructionResult != null
          ? _encodeReconstructedSegments(reconstructionResult.points)
          : '[]',
      routeMatchStatus: reconstructionResult != null
          ? (reconstructionResult.method == ReconstructionMethod.monotonePchip
                ? 'reconstructed_pchip'
                : 'reconstructed_linear')
          : 'pending',
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

String _encodeReconstructedSegments(List<ReconstructedPoint> points) {
  if (points.isEmpty) return '[]';
  final segments = <List<Map<String, dynamic>>>[];
  var currentSegment = <Map<String, dynamic>>[];

  for (final p in points) {
    if (p.gapType == ReconstructionGapType.indeterminateOutage &&
        currentSegment.isNotEmpty) {
      segments.add(currentSegment);
      currentSegment = <Map<String, dynamic>>[];
    }
    currentSegment.add({
      'lat': p.point.latitude,
      'lng': p.point.longitude,
      'interpolated': p.isInterpolated,
      'gap_type': p.gapType.name,
    });
  }
  if (currentSegment.isNotEmpty) {
    segments.add(currentSegment);
  }
  return jsonEncode(segments);
}
