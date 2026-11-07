import 'dart:convert';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'osm_gps_ground_truth_benchmark_test.dart';

void main() {
  group('Trajectory Preprocessing Runtime Integration Tests', () {
    test('Finalizer enriches routeMetrics with research preprocessing telemetry', () {
      const finalizer = WorkoutSessionFinalizer();
      const trackingEngine = WorkoutTrackingEngine();

      final now = DateTime.utc(2026, 11, 7, 10, 0, 0);
      final rawPositions = <Position>[
        Position(
          latitude: 10.750000,
          longitude: 106.650000,
          timestamp: now,
          altitude: 5.0,
          accuracy: 5.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
        Position(
          latitude: 10.750100,
          longitude: 106.650000,
          timestamp: now.add(const Duration(seconds: 5)),
          altitude: 5.0,
          accuracy: 5.0,
          heading: 0.0,
          speed: 2.2,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
        // Stationary cluster (3 samples at same point)
        Position(
          latitude: 10.750100,
          longitude: 106.650000,
          timestamp: now.add(const Duration(seconds: 40)),
          altitude: 5.0,
          accuracy: 5.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
      ];

      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: '00000000-0000-0000-0000-000000000001',
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 40,
        distanceMeters: 11.1,
        stepCount: 50,
      );

      final finalization = finalizer.finalize(
        state: state,
        userId: 'test-user-id',
        finishedAt: now.add(const Duration(seconds: 40)),
        caloriesBurned: 15,
        fallbackStrideLengthMeters: 0.75,
        trackingEngine: trackingEngine,
        rawGpsPositions: rawPositions,
        filteredRouteSegments: [
          [
            const LatLng(10.750000, 106.650000),
            const LatLng(10.750100, 106.650000),
          ]
        ],
        enableTrajectoryPreprocessing: true,
      );

      final metrics = jsonDecode(finalization.session.routeMatchMetricsJson) as Map<String, dynamic>;

      expect(metrics['preprocessing_enabled'], isTrue);
      expect(metrics['distance_selection_policy'], equals('preprocessed_clean_then_raw_valid_then_live'));
      expect(metrics.containsKey('preprocessing_clean_distance_km'), isTrue);
      expect(metrics.containsKey('preprocessing_drift_eliminated_m'), isTrue);
      expect(metrics.containsKey('preprocessing_stay_points_count'), isTrue);
      expect(metrics.containsKey('preprocessing_accepted_count'), isTrue);
      expect(metrics.containsKey('preprocessing_rejected_count'), isTrue);
      expect(metrics.containsKey('legacy_vs_clean_delta_km'), isTrue);
      expect(metrics['preprocessing_accepted_count'], greaterThanOrEqualTo(2));
    });

    test('Finalizer defaults safely to legacy policy when preprocessing flag is disabled', () {
      const finalizer = WorkoutSessionFinalizer();
      const trackingEngine = WorkoutTrackingEngine();

      final now = DateTime.utc(2026, 11, 7, 10, 0, 0);
      final rawPositions = <Position>[
        Position(
          latitude: 10.750000,
          longitude: 106.650000,
          timestamp: now,
          altitude: 5.0,
          accuracy: 5.0,
          heading: 0.0,
          speed: 2.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
      ];

      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: '00000000-0000-0000-0000-000000000002',
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 10,
        distanceMeters: 20.0,
      );

      final finalization = finalizer.finalize(
        state: state,
        userId: 'test-user-id',
        finishedAt: now.add(const Duration(seconds: 10)),
        caloriesBurned: 5,
        fallbackStrideLengthMeters: 0.75,
        trackingEngine: trackingEngine,
        rawGpsPositions: rawPositions,
        filteredRouteSegments: const [],
      );

      final metrics = jsonDecode(finalization.session.routeMatchMetricsJson) as Map<String, dynamic>;
      expect(metrics['preprocessing_enabled'], isFalse);
      expect(metrics['distance_selection_policy'], equals('raw_valid_then_raw_total_then_live'));
    });

    test('Streaming preprocessor integration correctly filters acceleration spikes in live pipeline', () {
      final preprocessor = TrajectoryPreprocessor.forActivity('running').createStreamingSession();
      final now = DateTime.utc(2026, 11, 7, 10, 0, 0);

      // p0: clean start
      final p0 = preprocessor.processSample(
        TrajectoryRawSample(
          index: 0,
          timestamp: now,
          point: const LatLng(10.750000, 106.650000),
          accuracyMeters: 5.0,
          sensorSpeedMs: 3.0,
        ),
      );
      expect(p0.isAccepted, isTrue);

      // p1: normal running movement (3 m/s)
      final p1 = preprocessor.processSample(
        TrajectoryRawSample(
          index: 1,
          timestamp: now.add(const Duration(seconds: 1)),
          point: const LatLng(10.750027, 106.650000), // ~3.0m north
          accuracyMeters: 5.0,
          sensorSpeedMs: 3.0,
        ),
      );
      expect(p1.isAccepted, isTrue);
      expect(p1.impliedSpeedMs, closeTo(3.0, 0.2));

      // p2: sudden acute acceleration spike (speed jumps from 3.0 m/s to 15 m/s in 1s = 12 m/s^2 > 4.5 m/s^2)
      final p2 = preprocessor.processSample(
        TrajectoryRawSample(
          index: 2,
          timestamp: now.add(const Duration(seconds: 2)),
          point: const LatLng(10.750162, 106.650000), // ~15m jump in 1s
          accuracyMeters: 5.0,
          sensorSpeedMs: 15.0,
        ),
      );
      expect(p2.isAccepted, isFalse);
      expect(p2.qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike), isTrue);
      expect(p2.impliedAccelerationMs2, greaterThan(4.5));
    });

    test('Streaming preprocessor handles GNSS blackout and recovery without distance bridging', () {
      final preprocessor = TrajectoryPreprocessor.forActivity('running').createStreamingSession();
      final now = DateTime.utc(2026, 11, 7, 10, 0, 0);

      // p0: initial point
      preprocessor.processSample(
        TrajectoryRawSample(
          index: 0,
          timestamp: now,
          point: const LatLng(10.750000, 106.650000),
          accuracyMeters: 5.0,
          sensorSpeedMs: 3.0,
        ),
      );

      // p1: normal movement
      preprocessor.processSample(
        TrajectoryRawSample(
          index: 1,
          timestamp: now.add(const Duration(seconds: 2)),
          point: const LatLng(10.750054, 106.650000), // ~6m
          accuracyMeters: 5.0,
          sensorSpeedMs: 3.0,
        ),
      );

      final initialCleanDist = preprocessor.accumulatedCleanDistanceMeters;
      expect(initialCleanDist, closeTo(6.0, 0.2));

      // p2: arrives after 30s tunnel blackout (dt = 30s > 20s gap threshold)
      final recoveryFix = preprocessor.processSample(
        TrajectoryRawSample(
          index: 2,
          timestamp: now.add(const Duration(seconds: 32)),
          point: const LatLng(10.750800, 106.650000), // 83 meters away
          accuracyMeters: 6.0,
          sensorSpeedMs: 3.0,
        ),
      );

      expect(recoveryFix.qualityFlags.contains(TrajectoryQualityFlag.signalGap), isTrue);
      expect(recoveryFix.isGapRecovery, isTrue);
      expect(recoveryFix.isAccepted, isTrue);

      // CRITICAL INVARIANT: clean distance MUST NOT accumulate the 83m tunnel jump
      expect(preprocessor.accumulatedCleanDistanceMeters, closeTo(initialCleanDist, 0.001));
    });

    test('Feature flags are declared and defaulted correctly', () {
      expect(kEnableTrajectoryPreprocessing, isFalse);
      expect(kEnableTrajectoryPreprocessingShadowMode, isFalse);
    });

    test('Audit of 39 multipath points: distinguishes confirmed spatial distortion from kinematically suspected spikes', () {
      final (truth, measurements) = OsmRouteGenerator.generateDataset(seed: 42);
      const distanceCalc = Distance();
      final preprocessor = TrajectoryPreprocessor.forActivity('cycling');

      final rawSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        rawSamples.add(TrajectoryRawSample(
          index: i,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m.second * 1000, isUtc: true),
          point: m.position,
          accuracyMeters: m.reportedAccuracyMeters,
          sensorSpeedMs: m.reportedSpeedMs,
          sensorHeadingDeg: m.reportedHeadingDeg,
          deviceSource: 'osm_simulated',
        ));
      }

      final result = preprocessor.processBatch(rawSamples);

      var severeSpatialOutliers = 0; // true error >= 10m
      var moderateSpatialOutliers = 0; // 5m <= true error < 10m
      var lowSpatialErrorSpikes = 0; // true error < 5m, but kinematic spike (acceleration/speed)

      for (var i = 0; i < result.processedPoints.length; i++) {
        final pt = result.processedPoints[i];
        final isCanopyOutage = measurements[i].isDropped || measurements[i].reportedAccuracyMeters > 30.0;
        final isDetected = pt.qualityFlags.contains(TrajectoryQualityFlag.signalGap) ||
            pt.qualityFlags.contains(TrajectoryQualityFlag.lowAccuracy) ||
            pt.isOutlier;

        // Examine the 39 points that were not part of the 6 canopy outage epochs
        if (isDetected && !isCanopyOutage) {
          final trueErr = distanceCalc.distance(rawSamples[i].point, truth[i].position);
          if (trueErr >= 10.0) {
            severeSpatialOutliers++;
          } else if (trueErr >= 5.0) {
            moderateSpatialOutliers++;
          } else {
            lowSpatialErrorSpikes++;
          }
        }
      }

      final totalMultipathSuspected = severeSpatialOutliers + moderateSpatialOutliers + lowSpatialErrorSpikes;
      // ignore: avoid_print
      print('OSM 39 Multipath Audit Breakdown: severe(>=10m)=$severeSpatialOutliers, moderate(5-10m)=$moderateSpatialOutliers, lowSpatial(<5m, kinematic spike)=$lowSpatialErrorSpikes');
      expect(totalMultipathSuspected, equals(39));
      expect(severeSpatialOutliers + moderateSpatialOutliers, greaterThan(0));

      // Scientific finding: the 39 points consist of:
      // - Real spatial deviations (points shifted by multipath > 5m or > 10m from true road)
      // - Pure kinematic spikes (points with small spatial error but sharp inter-epoch jump due to noise derivative)
      // They are NOT homogeneous and must NOT be circularly claimed as 100% ground-truth outliers.
    });

    test('Audit of short sessions (4-10 fixes): analyzes cold-start, stationary jitter, and AEKF convergence', () {
      // Authentic session 18c54f6e (4 fixes): ultra-short startup before immediate cancellation
      final preprocessor = TrajectoryPreprocessor.forActivity('cycling');

      final shortSamples4 = [
        TrajectoryRawSample(
          index: 0,
          timestamp: DateTime.parse('2026-11-05T03:35:15.107Z'),
          point: const LatLng(10.7380611802551, 106.625276692795),
          accuracyMeters: 18.59,
          sensorSpeedMs: 0.0,
        ),
        TrajectoryRawSample(
          index: 1,
          timestamp: DateTime.parse('2026-11-05T03:35:16.943Z'),
          point: const LatLng(10.7380611802551, 106.625276692795),
          accuracyMeters: 18.59,
          sensorSpeedMs: 0.0,
        ),
        TrajectoryRawSample(
          index: 2,
          timestamp: DateTime.parse('2026-11-05T03:35:21.404Z'),
          point: const LatLng(10.7381135989687, 106.625283520382),
          accuracyMeters: 56.01, // Low accuracy spike rejected (> 30m)
          sensorSpeedMs: 0.0,
        ),
        TrajectoryRawSample(
          index: 3,
          timestamp: DateTime.parse('2026-11-05T03:35:22.404Z'),
          point: const LatLng(10.7380612528045, 106.625222256134),
          accuracyMeters: 27.73,
          sensorSpeedMs: 1.48,
          deviceSource: 'geolocator_position_stream_recovery',
        ),
      ];

      final res4 = preprocessor.processBatch(shortSamples4);

      // Point 2 is rejected for low accuracy (56m).
      // Point 3 arrives >5s after last accepted point (16.943s -> 22.404s = 5.46s), triggering signalGap recovery.
      // Therefore, clean locomotion distance is 0.0m (no false distance bridged).
      expect(res4.cleanDistanceMeters, closeTo(0.0, 0.01));
      expect(res4.lowAccuracyCount, equals(1));
      expect(res4.acceptedCleanCount, equals(3));
    });
  });
}
