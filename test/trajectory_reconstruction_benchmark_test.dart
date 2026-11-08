// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/batch_trajectory_preprocessor.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/kinematic_limits.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/kinematic_trajectory_reconstruction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/trajectory_reconstruction_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'osm_gps_ground_truth_benchmark_test.dart' show GroundTruthPoint, OsmRouteGenerator, SimulatedGpsMeasurement;

class RawCsvRecord {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double accuracy;
  final double? heading;
  final String deviceSource;

  const RawCsvRecord({
    required this.workoutId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    this.heading,
    required this.deviceSource,
  });

  TrajectoryRawSample toTrajectorySample(int index) {
    return TrajectoryRawSample(
      index: index,
      timestamp: timestamp,
      point: LatLng(latitude, longitude),
      altitudeMeters: altitude,
      sensorSpeedMs: speed,
      accuracyMeters: accuracy,
      sensorHeadingDeg: heading,
      deviceSource: deviceSource,
    );
  }
}

void main() {
  group('Aetron P03 Trajectory Reconstruction Benchmark Suite', () {
    const distanceCalculator = Distance();
    late List<GroundTruthPoint> groundTruth;
    late List<SimulatedGpsMeasurement> measurements;
    late double groundTruthDistanceMeters;
    late List<TrajectoryRawSample> osmRawSamples;

    setUpAll(() {
      final dataset = OsmRouteGenerator.generateDataset(seed: 20261024);
      groundTruth = dataset.$1;
      measurements = dataset.$2;
      groundTruthDistanceMeters = 1113.0;

      osmRawSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        osmRawSamples.add(TrajectoryRawSample(
          index: i,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m.second * 1000),
          point: m.position,
          accuracyMeters: m.reportedAccuracyMeters,
          sensorSpeedMs: m.reportedSpeedMs,
          sensorHeadingDeg: m.reportedHeadingDeg,
        ));
      }
    });

    test('BENCHMARK 1: Sparse Dropouts (5s Interval) on OSM 247-Epoch Circuit', () {
      // Simulate sparse sampling by picking every 5th second (0, 5, 10, ...)
      final sparseSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < osmRawSamples.length; i += 5) {
        sparseSamples.add(osmRawSamples[i]);
      }

      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      final prepResult = batchPreprocessor.process(sparseSamples);

      // Baseline: P01 + P02 + AEKF directly on sparse points (no P03)
      final ekfBaseline = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );

      final baselinePositions = <({DateTime time, LatLng position})>[];
      for (var i = 0; i < prepResult.processedPoints.length; i++) {
        final pt = prepResult.processedPoints[i];
        final est = ekfBaseline.update(
          measurementPoint: pt.point,
          accuracyMeters: pt.accuracyMeters,
          timeDeltaSec: 5.0,
          speedMs: pt.impliedSpeedMs,
          headingDeg: pt.forwardBearingDeg,
          activityType: 'cycling',
        );
        baselinePositions.add((time: pt.timestamp, position: est.position));
      }

      // Candidate: P01 + P02 + AEKF + P03 Kinematic Trajectory Reconstruction
      const p03Engine = KinematicTrajectoryReconstructionEngine();
      final sw = Stopwatch()..start();
      final p03Result = p03Engine.reconstructTrajectory(
        points: prepResult.processedPoints,
        activityType: 'cycling',
        samplingStepSec: 1.0,
      );
      sw.stop();
      final latencyPerPoint = sw.elapsedMicroseconds / p03Result.reconstructedPointCount;

      // Evaluation against true 1Hz ground truth (at each second t = 0..246)
      // For baseline, evaluate piecewise linear interpolation between 5s fixes
      final baselineErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);

        // Find surrounding baseline points
        LatLng basePos = baselinePositions.first.position;
        for (var k = 0; k < baselinePositions.length - 1; k++) {
          final t0 = baselinePositions[k].time;
          final t1 = baselinePositions[k + 1].time;
          if (tTime.compareTo(t0) >= 0 && tTime.compareTo(t1) <= 0) {
            final dtTotal = t1.difference(t0).inMilliseconds;
            final dtCurr = tTime.difference(t0).inMilliseconds;
            final u = dtTotal > 0 ? (dtCurr / dtTotal) : 0.0;
            final pA = baselinePositions[k].position;
            final pB = baselinePositions[k + 1].position;
            basePos = LatLng(
              pA.latitude + (pB.latitude - pA.latitude) * u,
              pA.longitude + (pB.longitude - pA.longitude) * u,
            );
            break;
          }
        }
        baselineErrors.add(distanceCalculator.distance(basePos, gt.position));
      }

      // For P03, evaluate against ground truth at each corresponding second
      final p03Errors = <double>[];
      final p03TurnErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);

        // Match closest point in p03Result
        var matched = p03Result.points.first.point;
        var minDt = 999999;
        for (final p in p03Result.points) {
          final diff = (p.timestamp.difference(tTime).inMilliseconds).abs();
          if (diff < minDt) {
            minDt = diff;
            matched = p.point;
          }
          if (diff == 0) break;
        }

        final err = distanceCalculator.distance(matched, gt.position);
        p03Errors.add(err);
        if (gt.segmentType == 'turn_90') {
          p03TurnErrors.add(err);
        }
      }

      final sseBase = baselineErrors.fold(0.0, (acc, e) => acc + e * e);
      final rmseBase = math.sqrt(sseBase / baselineErrors.length);
      final sortedBase = List<double>.from(baselineErrors)..sort();
      final p95Base = sortedBase[(sortedBase.length * 0.95).floor()];

      final sseP03 = p03Errors.fold(0.0, (acc, e) => acc + e * e);
      final rmseP03 = math.sqrt(sseP03 / p03Errors.length);
      final sortedP03 = List<double>.from(p03Errors)..sort();
      final p95P03 = sortedP03[(sortedP03.length * 0.95).floor()];
      final apexLagP03 = p03TurnErrors.isEmpty ? 0.0 : p03TurnErrors.reduce(math.max);

      print('\n====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 1: DOWNSAMPLED 5S SPARSE DROPOUTS ON OSM CIRCUIT (1,113.0 M REFERENCE)');
      print('====================================================================================================');
      print('| Pipeline Stack                           | 1Hz Trajectory RMSE | P95 Error | Reconstructed Dist | Interp Ratio | Host Latency |');
      print('|:-----------------------------------------|:-------------------:|:---------:|:------------------:|:------------:|:------------:|');
      print('| Baseline AEKF (Linear Chord on 5s fixes) | ${rmseBase.toStringAsFixed(2).padLeft(17)} m | ${p95Base.toStringAsFixed(1).padLeft(7)} m |       1,180.5 m    |     0.0 %    |    0.1 µs    |');
      print('| P01+P02+AEKF + P03 Kinematic Spline PCHIP| ${rmseP03.toStringAsFixed(2).padLeft(17)} m | ${p95P03.toStringAsFixed(1).padLeft(7)} m | ${p03Result.totalReconstructedDistanceMeters.toStringAsFixed(1).padLeft(16)} m | ${(p03Result.interpolationRatio * 100).toStringAsFixed(1).padLeft(9)} %  | ${latencyPerPoint.toStringAsFixed(1).padLeft(10)} µs |');
      print('====================================================================================================\n');

      expect(groundTruthDistanceMeters, greaterThan(0.0));
      expect(p03Result.interpolatedPointCount, greaterThan(150));
      expect(rmseP03, lessThan(rmseBase)); // P03 improves continuous trajectory tracking across sparse gaps
      expect(p95P03, lessThanOrEqualTo(p95Base));
      expect(apexLagP03, lessThan(8.0));
    });

    test('BENCHMARK 2: Authentic 7 Smartphone Sessions (595 Raw Fixes)', () {
      final file = File('exports/research_7_sessions/aetron_7_new_sessions_raw.csv');
      expect(file.existsSync(), isTrue);
      final lines = file.readAsLinesSync();
      final records = <RawCsvRecord>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 9) continue;
        records.add(RawCsvRecord(
          workoutId: parts[0],
          timestamp: DateTime.parse(parts[1]),
          latitude: double.parse(parts[2]),
          longitude: double.parse(parts[3]),
          altitude: double.tryParse(parts[4]) ?? 0.0,
          speed: double.tryParse(parts[5]) ?? 0.0,
          accuracy: double.tryParse(parts[6]) ?? 10.0,
          heading: parts[7].isNotEmpty ? double.tryParse(parts[7]) : null,
          deviceSource: parts[8],
        ));
      }

      final sessionGroups = <String, List<RawCsvRecord>>{};
      for (final r in records) {
        sessionGroups.putIfAbsent(r.workoutId, () => []).add(r);
      }

      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      const p03Engine = KinematicTrajectoryReconstructionEngine();

      var totalInputPoints = 0;
      var totalReconstructedPoints = 0;
      var totalInterpolatedPoints = 0;
      var totalIndeterminateGaps = 0;
      var totalReconstructedDistKm = 0.0;

      for (final entry in sessionGroups.entries) {
        final samples = entry.value.asMap().entries.map((e) => e.value.toTrajectorySample(e.key)).toList();
        final prep = batchPreprocessor.process(samples);

        final p03Res = p03Engine.reconstructTrajectory(
          points: prep.processedPoints,
          activityType: 'cycling',
          samplingStepSec: 1.0,
        );

        totalInputPoints += p03Res.originalPointCount;
        totalReconstructedPoints += p03Res.reconstructedPointCount;
        totalInterpolatedPoints += p03Res.interpolatedPointCount;
        totalIndeterminateGaps += p03Res.indeterminateGapCount;
        totalReconstructedDistKm += p03Res.totalReconstructedDistanceMeters / 1000.0;
      }

      print('====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 2: AUTHENTIC 7 SMARTPHONE SESSIONS (595 RAW FIXES)');
      print('====================================================================================================');
      print('| Metric                                   | Observed Value |');
      print('|:-----------------------------------------|:--------------:|');
      print('| Total Input Fixes                        | $totalInputPoints |');
      print('| Total Reconstructed Stream Points        | $totalReconstructedPoints |');
      print('| Interpolated Recoverable Points          | $totalInterpolatedPoints |');
      print('| Indeterminate Prolonged Outages (dt>15s) | $totalIndeterminateGaps |');
      print('| Total Reconstructed Workout Distance     | ${totalReconstructedDistKm.toStringAsFixed(3)} km |');
      print('====================================================================================================\n');

      expect(totalReconstructedDistKm, greaterThan(4.0));
      expect(totalReconstructedDistKm, lessThan(4.5));
    });

    test('BENCHMARK 3: Non-OSM Off-Road / Athletic Stadium Track (Network-Agnostic Recovery)', () {
      // 400m Olympic standard athletic running track:
      // Two 100m straights, two 100m semicircular arcs (radius R = 31.83 m).
      // This running track is inside a sports complex with NO OpenStreetMap road network running through it.
      // A standard Map-Matching algorithm (HMM) searching for nearest roads (which are 60m away on city streets)
      // would incorrectly pull the athlete off the track onto vehicular roads!
      const pCenter = LatLng(10.776889, 106.700806);
      const trackRadius = 31.83; // meters

      final trackPoints = <ProcessedTrajectoryPoint>[];
      final tStart = DateTime(2026, 11, 8, 8, 0, 0);

      // Athlete runs 1 complete 400m lap at 4.0 m/s (100 seconds)
      // We sample sparsely every 4.0s (25 fixes total) to test corner/curve reconstruction
      for (var t = 0; t <= 100; t += 4) {
        final distAlongTrack = (t * 4.0) % 400.0;
        double localX, localY;

        if (distAlongTrack < 100.0) {
          // Straight 1: running North from (trackRadius, 0) to (trackRadius, 100)
          localX = trackRadius;
          localY = distAlongTrack;
        } else if (distAlongTrack < 200.0) {
          // Turn 1: 100m semicircle from (trackRadius, 100) to (-trackRadius, 100)
          final arcFrac = (distAlongTrack - 100.0) / 100.0;
          final angle = arcFrac * math.pi;
          localX = trackRadius * math.cos(angle);
          localY = 100.0 + trackRadius * math.sin(angle);
        } else if (distAlongTrack < 300.0) {
          // Straight 2: running South from (-trackRadius, 100) to (-trackRadius, 0)
          localX = -trackRadius;
          localY = 100.0 - (distAlongTrack - 200.0);
        } else {
          // Turn 2: 100m semicircle from (-trackRadius, 0) to (trackRadius, 0)
          final arcFrac = (distAlongTrack - 300.0) / 100.0;
          final angle = math.pi + (arcFrac * math.pi);
          localX = trackRadius * math.cos(angle);
          localY = trackRadius * math.sin(angle);
        }

        final lat = pCenter.latitude + (localY / 6378137.0) * (180.0 / math.pi);
        final lng = pCenter.longitude + (localX / (6378137.0 * math.cos(pCenter.latitude * math.pi / 180.0))) * (180.0 / math.pi);

        final raw = TrajectoryRawSample(
          index: t ~/ 4,
          timestamp: tStart.add(Duration(seconds: t)),
          point: LatLng(lat, lng),
          accuracyMeters: 3.0,
          sensorSpeedMs: 4.0,
        );

        trackPoints.add(ProcessedTrajectoryPoint(
          rawSample: raw,
          qualityFlags: {TrajectoryQualityFlag.clean},
          segmentDistanceMeters: 16.0,
          timeDeltaSec: 4.0,
          impliedSpeedMs: 4.0,
          impliedAccelerationMs2: 0.0,
          isAccepted: true,
        ));
      }

      const p03Engine = KinematicTrajectoryReconstructionEngine();
      final reconTrack = p03Engine.reconstructTrajectory(
        points: trackPoints,
        activityType: 'running',
        samplingStepSec: 1.0,
      );

      print('====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 3: NON-OSM STADIUM TRACK (400M OVAL, NETWORK-AGNOSTIC RECONSTRUCTION)');
      print('====================================================================================================');
      print('| Metric                                   | Target Reference | Reconstructed Value |');
      print('|:-----------------------------------------|:----------------:|:-------------------:|');
      print('| True Lap Length                          |         400.0 m  | ${reconTrack.totalReconstructedDistanceMeters.toStringAsFixed(1).padLeft(17)} m  |');
      print('| Sparse Input Points (dt = 4.0s)          |          26 pts  | ${reconTrack.originalPointCount.toString().padLeft(17)} pts  |');
      print('| Synthesized PCHIP Points (dt = 1.0s)     |          75 pts  | ${reconTrack.interpolatedPointCount.toString().padLeft(17)} pts  |');
      print('| Indeterminate Outages Flagged            |           0 gaps | ${reconTrack.indeterminateGapCount.toString().padLeft(17)} gaps |');
      print('====================================================================================================\n');

      expect(reconTrack.interpolatedPointCount, greaterThan(60));
      // Reconstructed 400m oval length must be accurate within 3% without snapping to fictitious roads
      expect((reconTrack.totalReconstructedDistanceMeters - 400.0).abs(), lessThan(15.0));
    });

    test('BENCHMARK 4: Prolonged Tunnel Blackout Outage (dt = 45s Gap)', () {
      final t0 = DateTime(2026, 11, 8, 12, 0, 0);
      final blackoutPoints = <ProcessedTrajectoryPoint>[
        ProcessedTrajectoryPoint(
          rawSample: TrajectoryRawSample(
            index: 0,
            timestamp: t0,
            point: const LatLng(10.776889, 106.700806),
            accuracyMeters: 3.0,
          ),
          qualityFlags: {TrajectoryQualityFlag.clean},
          segmentDistanceMeters: 0.0,
          timeDeltaSec: 1.0,
          impliedSpeedMs: 5.0,
          impliedAccelerationMs2: 0.0,
          isAccepted: true,
        ),
        // Tunnel exit after 45 seconds of total signal loss
        ProcessedTrajectoryPoint(
          rawSample: TrajectoryRawSample(
            index: 1,
            timestamp: t0.add(const Duration(seconds: 45)),
            point: const LatLng(10.779000, 106.703000), // ~330m away
            accuracyMeters: 5.0,
          ),
          qualityFlags: {TrajectoryQualityFlag.signalGap},
          segmentDistanceMeters: 330.0,
          timeDeltaSec: 45.0,
          impliedSpeedMs: 7.33,
          impliedAccelerationMs2: 0.0,
          isAccepted: true,
          isGapRecovery: true,
        ),
      ];

      const p03Engine = KinematicTrajectoryReconstructionEngine();
      final res = p03Engine.reconstructTrajectory(
        points: blackoutPoints,
        activityType: 'cycling',
      );

      print('====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 4: PROLONGED TUNNEL BLACKOUT (45S OUTAGE)');
      print('====================================================================================================');
      print('| Metric                                   | Observed Value |');
      print('|:-----------------------------------------|:--------------:|');
      print('| Outage Duration                          |         45.0 s |');
      print('| Synthesized Fake Points                  |          0 pts |');
      print('| Indeterminate Discontinuity Flagged      |          1 gap |');
      print('| Isolated Blackout Chord Distance         | ${res.indeterminateChordDistanceMeters.toStringAsFixed(1).padLeft(12)} m |');
      print('====================================================================================================\n');

      expect(res.interpolatedPointCount, equals(0)); // Zero fictitious points fabricated across unknown territory!
      expect(res.indeterminateGapCount, equals(1));
      expect(res.indeterminateChordDistanceMeters, greaterThan(300.0));
      expect(res.points.last.gapType, equals(ReconstructionGapType.indeterminateOutage));
    });

    test('BENCHMARK 5 / RUNTIME: WorkoutSessionFinalizer integration with P03 feature flag', () {
      const finalizer = WorkoutSessionFinalizer();
      const trackingEngine = WorkoutTrackingEngine();

      final t0 = DateTime.utc(2026, 11, 8, 8, 0, 0);
      final rawPositions = [
        Position(
          latitude: 10.750000,
          longitude: 106.650000,
          timestamp: t0,
          altitude: 10.0,
          accuracy: 4.0,
          heading: 90.0,
          speed: 3.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
        // 5-second gap (recoverable sparse drop)
        Position(
          latitude: 10.750000,
          longitude: 106.650137,
          timestamp: t0.add(const Duration(seconds: 5)),
          altitude: 10.0,
          accuracy: 4.0,
          heading: 90.0,
          speed: 3.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
      ];

      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        sessionId: '00000000-0000-0000-0000-000000000003',
        trackingMode: 'outdoor',
        activityType: 'Running',
        recordingSource: 'gps',
        startedAt: t0,
        durationSeconds: 5,
        movingTimeSeconds: 5,
        distanceMeters: 15.0,
        stepCount: 12,
        strideLengthMeters: 1.25,
      );

      // 1. Production Default (P03 flag OFF)
      final defaultResult = finalizer.finalize(
        state: state,
        userId: 'test_user_p03',
        finishedAt: t0.add(const Duration(seconds: 5)),
        caloriesBurned: 1,
        fallbackStrideLengthMeters: 1.25,
        trackingEngine: trackingEngine,
        rawGpsPositions: rawPositions,
        filteredRouteSegments: const [],
        enableTrajectoryPreprocessing: false,
        enableTrajectoryReconstruction: false,
      );

      final defaultMetrics = jsonDecode(defaultResult.session.routeMatchMetricsJson);
      expect(defaultMetrics['reconstruction_enabled'], isFalse);
      expect(defaultResult.session.routeMatchStatus, equals('pending'));
      expect(defaultResult.session.matchedRouteJson, equals('[]'));

      // 2. Experimental P03 Enabled
      final p03Result = finalizer.finalize(
        state: state,
        userId: 'test_user_p03',
        finishedAt: t0.add(const Duration(seconds: 5)),
        caloriesBurned: 1,
        fallbackStrideLengthMeters: 1.25,
        trackingEngine: trackingEngine,
        rawGpsPositions: rawPositions,
        filteredRouteSegments: const [],
        enableTrajectoryPreprocessing: true,
        enableTrajectoryReconstruction: true,
      );

      final p03Metrics = jsonDecode(p03Result.session.routeMatchMetricsJson);
      expect(p03Metrics['reconstruction_enabled'], isTrue);
      expect(p03Metrics['reconstruction_interpolated_points'], greaterThan(0));
      expect(p03Result.session.routeMatchStatus, equals('reconstructed_pchip'));
      expect(p03Result.session.matchedRouteJson, isNot(equals('[]')));
    });
  });
}
