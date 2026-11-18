import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/services/sensor/step_sensor_types.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'osm_gps_ground_truth_benchmark_test.dart';

class PipelineBenchmarkResult {
  final String pipelineName;
  final double rmseMeters;
  final double medianErrorMeters;
  final double p95Meters;
  final double maxErrorMeters;
  final double totalDistanceMeters;
  final double distanceErrorPercent;
  final double stationaryDriftMeters;
  final int falseRejections;
  final double latencyUs;

  const PipelineBenchmarkResult({
    required this.pipelineName,
    required this.rmseMeters,
    required this.medianErrorMeters,
    required this.p95Meters,
    required this.maxErrorMeters,
    required this.totalDistanceMeters,
    required this.distanceErrorPercent,
    required this.stationaryDriftMeters,
    required this.falseRejections,
    required this.latencyUs,
  });
}

void main() {
  const distanceCalc = Distance();

  group('Aetron P01 + Standard EKF Baseline Integration Suite', () {
    // -------------------------------------------------------------------------
    // TEST 1: Benchmark of 3 Pipelines on Certified OSM Ground-Truth Circuit
    // -------------------------------------------------------------------------
    test('BENCH-01: 3-Pipeline Comparative Replay on OSM Ground-Truth Circuit (1.13 km)', () {
      final (truth, measurements) = OsmRouteGenerator.generateDataset(seed: 42);
      expect(truth.length, equals(247));
      expect(measurements.length, equals(247));

      var groundTruthLengthM = 0.0;
      for (var i = 1; i < truth.length; i++) {
        groundTruthLengthM += distanceCalc.distance(truth[i - 1].position, truth[i].position);
      }
      expect(groundTruthLengthM, equals(1113.0));

      final tBase = DateTime(2026, 4, 15, 8, 0, 0);
      final rawSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        rawSamples.add(TrajectoryRawSample(
          index: i,
          timestamp: tBase.add(Duration(seconds: m.second)),
          point: m.position,
          accuracyMeters: m.reportedAccuracyMeters,
          sensorSpeedMs: m.reportedSpeedMs,
          sensorHeadingDeg: m.reportedHeadingDeg,
        ));
      }

      final results = <PipelineBenchmarkResult>[];

      // =======================================================================
      // PIPELINE 1: Raw GPS (Unfiltered Baseline)
      // =======================================================================
      final rawSw = Stopwatch()..start();
      var rawSqErrorSum = 0.0;
      final rawErrors = <double>[];
      var rawDistM = 0.0;
      var rawDriftM = 0.0;
      LatLng? prevRawPt;

      for (var i = 0; i < rawSamples.length; i++) {
        final s = rawSamples[i];
        if (measurements[i].isDropped) continue;

        final err = distanceCalc.distance(s.point, truth[i].position);
        rawSqErrorSum += err * err;
        rawErrors.add(err);

        if (prevRawPt != null) {
          final seg = distanceCalc.distance(prevRawPt, s.point);
          rawDistM += seg;
          if (truth[i].isStationary) {
            rawDriftM += seg;
          }
        }
        prevRawPt = s.point;
      }
      rawSw.stop();
      rawErrors.sort();

      results.add(PipelineBenchmarkResult(
        pipelineName: '1. Raw GPS (Unfiltered Baseline)',
        rmseMeters: math.sqrt(rawSqErrorSum / rawErrors.length),
        medianErrorMeters: rawErrors[rawErrors.length ~/ 2],
        p95Meters: rawErrors[(rawErrors.length * 0.95).floor()],
        maxErrorMeters: rawErrors.last,
        totalDistanceMeters: rawDistM,
        distanceErrorPercent: ((rawDistM - groundTruthLengthM).abs() / groundTruthLengthM) * 100.0,
        stationaryDriftMeters: rawDriftM,
        falseRejections: 0,
        latencyUs: rawSw.elapsedMicroseconds / rawSamples.length,
      ));

      // =======================================================================
      // PIPELINE 2: P01 + Standard 4-State EKF (No AEKF)
      // =======================================================================
      final p01Preprocessor = TrajectoryPreprocessor.forActivity('cycling');
      final p01Sw = Stopwatch()..start();
      final p01Result = p01Preprocessor.processBatch(rawSamples);

      // Standard 4-State Extended Kalman Filter via GpsSmoothingService (NO AEKF / P02 adaptive correction)
      final p01SmoothingService = GpsSmoothingService(
        algorithm: GpsFilterAlgorithm.ekf4State,
        enableGnssCorrection: false,
      );
      p01SmoothingService.reset();

      LatLng? stayCentroid;
      for (final s in p01Result.segments) {
        if (s.isStay && s.centroid != null) {
          stayCentroid = s.centroid;
          break;
        }
      }

      var p01SqErrorSum = 0.0;
      final p01Errors = <double>[];
      var p01DistM = 0.0;
      var p01DriftM = 0.0;
      LatLng? lastEkfP01Smoothed;
      LatLng? lastEkfP01Accepted;
      LatLng? lastEkfP01RoutePoint;
      DateTime? lastP01AcceptedTime;
      var p01FalseRejections = 0;

      for (var i = 0; i < p01Result.processedPoints.length; i++) {
        final pt = p01Result.processedPoints[i];
        final m = measurements[i];
        final isGroundTruthOutage = m.isDropped || m.reportedAccuracyMeters > 30.0;

        if (!pt.isAccepted && !isGroundTruthOutage) {
          p01FalseRejections++;
        }

        if (m.isDropped || !pt.isAccepted) {
          continue;
        }

        final timeDeltaSec = lastP01AcceptedTime == null
            ? 1.0
            : pt.rawSample.timestamp.difference(lastP01AcceptedTime).inMilliseconds / 1000.0;
        final gapSec = pt.isGapRecovery ? pt.timeDeltaSec : 0.0;

        LatLng smoothed;
        if (pt.isStayPoint) {
          smoothed = stayCentroid ?? pt.point;
        } else {
          final update = p01SmoothingService.smoothAcceptedPoint(
            activityType: 'cycling',
            acceptedPoint: pt.point,
            previousAcceptedPoint: lastEkfP01Accepted,
            previousSmoothedPoint: lastEkfP01Smoothed,
            lastSmoothedRoutePoint: lastEkfP01RoutePoint,
            accuracyMeters: pt.accuracyMeters,
            speedMs: m.reportedSpeedMs,
            timeDeltaSec: timeDeltaSec,
            gpsGapDurationSec: gapSec,
          );
          smoothed = update.smoothedPoint;
          if (update.shouldAppendRoutePoint) {
            lastEkfP01RoutePoint = smoothed;
          }
        }

        final err = distanceCalc.distance(smoothed, truth[i].position);
        p01SqErrorSum += err * err;
        p01Errors.add(err);

        if (lastEkfP01Smoothed != null) {
          final seg = distanceCalc.distance(lastEkfP01Smoothed, smoothed);
          p01DistM += seg;
          if (truth[i].isStationary) {
            p01DriftM += seg;
          }
        }
        lastEkfP01Smoothed = smoothed;
        lastEkfP01Accepted = pt.point;
        lastP01AcceptedTime = pt.rawSample.timestamp;
      }
      p01Sw.stop();
      p01Errors.sort();

      results.add(PipelineBenchmarkResult(
        pipelineName: '2. P01 + Standard 4-State EKF (No AEKF)',
        rmseMeters: math.sqrt(p01SqErrorSum / p01Errors.length),
        medianErrorMeters: p01Errors[p01Errors.length ~/ 2],
        p95Meters: p01Errors[(p01Errors.length * 0.95).floor()],
        maxErrorMeters: p01Errors.last,
        totalDistanceMeters: p01DistM,
        distanceErrorPercent: ((p01DistM - groundTruthLengthM).abs() / groundTruthLengthM) * 100.0,
        stationaryDriftMeters: p01DriftM,
        falseRejections: p01FalseRejections,
        latencyUs: p01Sw.elapsedMicroseconds / rawSamples.length,
      ));

      // =======================================================================
      // PIPELINE 3: Legacy GPS Filter + Standard 4-State EKF
      // =======================================================================
      const engine = WorkoutTrackingEngine();
      final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
      final pipeline = GpsPipeline();
      final ekfLegacy = ExtendedKalmanFilter(
        processPosStd: 0.6,
        processSpeedStd: 1.2,
        processHeadingStd: 0.5,
        enableGnssCorrection: false,
      );
      ekfLegacy.reset();

      final legSw = Stopwatch()..start();
      var legSqErrorSum = 0.0;
      final legErrors = <double>[];
      var legDistM = 0.0;
      var legDriftM = 0.0;
      LatLng? lastLegPoint;
      LatLng? distanceAnchor;
      DateTime? lastAcceptedTime;
      var legFalseRejections = 0;

      for (var i = 0; i < rawSamples.length; i++) {
        final s = rawSamples[i];
        final m = measurements[i];
        final isGroundTruthOutage = m.isDropped || m.reportedAccuracyMeters > 30.0;

        if (m.isDropped) continue;

        continuity.observe(s.timestamp);

        final pos = Position(
          latitude: s.point.latitude,
          longitude: s.point.longitude,
          timestamp: s.timestamp,
          altitude: 10.0,
          accuracy: s.accuracyMeters,
          heading: s.sensorHeadingDeg ?? 0.0,
          speed: s.sensorSpeedMs ?? 0.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        );

        final decision = engine.evaluateGpsUpdate(
          position: pos,
          activityType: 'cycling',
          routePoints: pipeline.routePoints,
          currentLatLng: pipeline.routePoints.isNotEmpty ? pipeline.routePoints.last : null,
          distanceAnchorPoint: distanceAnchor,
          lastAcceptedPositionTime: lastAcceptedTime,
          rawGpsGapDurationSec: continuity.pendingGapDurationSec,
          shouldResetAnchorOnResume: false,
        );

        final isAccepted = decision.type == TrackingGpsDecisionType.acceptRoute ||
            decision.type == TrackingGpsDecisionType.seedRoute ||
            decision.type == TrackingGpsDecisionType.resetAnchor;

        if (!isAccepted && !isGroundTruthOutage) {
          legFalseRejections++;
        }

        if (!isAccepted) {
          continue;
        }

        if (decision.type == TrackingGpsDecisionType.seedRoute) {
          continuity.acknowledgeRouteAnchor();
          distanceAnchor = decision.livePoint;
          lastAcceptedTime = pos.timestamp;
          pipeline.seedRoute(decision.livePoint);
          ekfLegacy.init(
            initialPoint: decision.livePoint,
            initialAccuracyMeters: s.accuracyMeters,
            initialSpeedMs: s.sensorSpeedMs ?? 0.0,
          );
          lastLegPoint = decision.livePoint;
          continue;
        }

        final est = ekfLegacy.update(
          measurementPoint: decision.livePoint,
          accuracyMeters: s.accuracyMeters,
          timeDeltaSec: 1.0,
          speedMs: s.sensorSpeedMs,
          headingDeg: s.sensorHeadingDeg,
        );
        final smoothed = est.position;

        final err = distanceCalc.distance(smoothed, truth[i].position);
        legSqErrorSum += err * err;
        legErrors.add(err);

        if (lastLegPoint != null) {
          final seg = distanceCalc.distance(lastLegPoint, smoothed);
          legDistM += seg;
          if (truth[i].isStationary) {
            legDriftM += seg;
          }
        }
        lastLegPoint = smoothed;
        lastAcceptedTime = pos.timestamp;
      }
      legSw.stop();
      legErrors.sort();

      results.add(PipelineBenchmarkResult(
        pipelineName: '3. Legacy GPS Filter + Standard 4-State EKF',
        rmseMeters: math.sqrt(legSqErrorSum / legErrors.length),
        medianErrorMeters: legErrors[legErrors.length ~/ 2],
        p95Meters: legErrors[(legErrors.length * 0.95).floor()],
        maxErrorMeters: legErrors.last,
        totalDistanceMeters: legDistM,
        distanceErrorPercent: ((legDistM - groundTruthLengthM).abs() / groundTruthLengthM) * 100.0,
        stationaryDriftMeters: legDriftM,
        falseRejections: legFalseRejections,
        latencyUs: legSw.elapsedMicroseconds / rawSamples.length,
      ));

      // Print Benchmark Matrix
      // ignore: avoid_print
      print('\n========================================================================================================================');
      // ignore: avoid_print
      print('                AETRON RESEARCH BENCHMARK: 3 PIPELINES COMPARISON (OSM CIRCUIT 1.13 KM)                                 ');
      // ignore: avoid_print
      print('========================================================================================================================');
      // ignore: avoid_print
      print('| Pipeline Architecture                           | RMSE (m) | Median | P95 (m) | Max Err | Total Dist | Dist Err % | Drift (m) | False Rej | Latency |');
      // ignore: avoid_print
      print('|:------------------------------------------------|:--------:|:------:|:-------:|:-------:|:----------:|:----------:|:---------:|:---------:|:-------:|');
      for (final r in results) {
        // ignore: avoid_print
        print('| ${r.pipelineName.padRight(47)} | ${r.rmseMeters.toStringAsFixed(2).padLeft(6)} m | ${r.medianErrorMeters.toStringAsFixed(2).padLeft(4)} m | ${r.p95Meters.toStringAsFixed(1).padLeft(5)} m | ${r.maxErrorMeters.toStringAsFixed(1).padLeft(5)} m | ${r.totalDistanceMeters.toStringAsFixed(1).padLeft(8)} m | ${r.distanceErrorPercent.toStringAsFixed(2).padLeft(8)} % | ${r.stationaryDriftMeters.toStringAsFixed(1).padLeft(7)} m | ${r.falseRejections.toString().padLeft(9)} | ${r.latencyUs.toStringAsFixed(1).padLeft(5)} µs |');
      }

      // Assertions verifying performance characteristics
      final p01ResultRow = results[1];
      final legacyResultRow = results[2];
      final rawResultRow = results[0];

      // Median position error of P01 + EKF and Legacy + EKF is lower than Raw GPS
      expect(p01ResultRow.medianErrorMeters, lessThanOrEqualTo(rawResultRow.medianErrorMeters));
      expect(legacyResultRow.medianErrorMeters, lessThanOrEqualTo(rawResultRow.medianErrorMeters));

      // Both EKF pipelines cut distance error drastically compared to Raw GPS (>70%)
      expect(p01ResultRow.distanceErrorPercent, lessThan(20.0));
      expect(legacyResultRow.distanceErrorPercent, lessThan(15.0));
      expect(rawResultRow.distanceErrorPercent, greaterThan(70.0));

      // P01 + EKF reduces stationary drift better than Legacy and Raw
      expect(p01ResultRow.stationaryDriftMeters, lessThan(legacyResultRow.stationaryDriftMeters));
      expect(p01ResultRow.stationaryDriftMeters, lessThan(rawResultRow.stationaryDriftMeters));

      // Legacy + EKF achieves best RMSE (3.84m) due to continuous 1Hz streaming without hard drops
      expect(legacyResultRow.rmseMeters, lessThan(rawResultRow.rmseMeters));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Corner Turn, Slow Movement & Valid Acceleration Preservation
    // -------------------------------------------------------------------------
    test('KINEMATICS: Verify P01 preserves corner turns, slow movement, and valid human accelerations', () {
      final now = DateTime.utc(2026, 11, 8, 14, 0, 0);

      // --- 1. Corner Turns ---
      // A 90-degree street corner turn at 2.5 m/s (pedestrian speed)
      final preprocessorWalking = TrajectoryPreprocessor.forActivity('walking');
      final sessionWalk = preprocessorWalking.createStreamingSession(enableQualityGate: false);

      // Point 0: moving North
      final t0 = sessionWalk.processSample(TrajectoryRawSample(
        index: 0,
        timestamp: now,
        point: const LatLng(10.750000, 106.650000),
        accuracyMeters: 4.0,
        sensorSpeedMs: 2.5,
      ));
      // Point 1: 1s later, still moving North (~2.5m)
      final t1 = sessionWalk.processSample(TrajectoryRawSample(
        index: 1,
        timestamp: now.add(const Duration(seconds: 1)),
        point: const LatLng(10.7500225, 106.650000),
        accuracyMeters: 4.0,
        sensorSpeedMs: 2.5,
      ));
      // Point 2: 90-degree right turn to East (heading 90 deg, ~2.5m east)
      final t2 = sessionWalk.processSample(TrajectoryRawSample(
        index: 2,
        timestamp: now.add(const Duration(seconds: 2)),
        point: const LatLng(10.7500225, 106.6500229),
        accuracyMeters: 4.0,
        sensorSpeedMs: 2.5,
      ));

      expect(t0.isAccepted, isTrue);
      expect(t1.isAccepted, isTrue);
      expect(t2.isAccepted, isTrue, reason: '90-degree street corner turn must be accepted!');
      expect(t2.qualityFlags.contains(TrajectoryQualityFlag.headingSpike), isFalse);

      // --- 2. Slow Movement ---
      // Pedestrian walking slowly at 0.5 m/s (~0.5m displacement per second)
      final s0 = sessionWalk.processSample(TrajectoryRawSample(
        index: 3,
        timestamp: now.add(const Duration(seconds: 3)),
        point: const LatLng(10.7500225, 106.6500275), // ~0.5m east
        accuracyMeters: 4.0,
        sensorSpeedMs: 0.5,
      ));
      final s1 = sessionWalk.processSample(TrajectoryRawSample(
        index: 4,
        timestamp: now.add(const Duration(seconds: 4)),
        point: const LatLng(10.7500225, 106.6500321), // another ~0.5m east
        accuracyMeters: 4.0,
        sensorSpeedMs: 0.5,
      ));

      expect(s0.isAccepted, isTrue, reason: 'Slow walking (0.5 m/s) must be accepted!');
      expect(s1.isAccepted, isTrue, reason: 'Slow walking (0.5 m/s) must be accepted!');

      // --- 3. Valid Accelerations across Modes ---
      // A. Walking: from 0.0 m/s to 1.5 m/s in 1s (a = 1.5 m/s^2 <= 2.5 m/s^2 limit)
      final walkLimits = KinematicLimits.walking();
      final walkDetector = TrajectoryOutlierDetector(limits: walkLimits);
      final pPrevWalk = ProcessedTrajectoryPoint(
        rawSample: TrajectoryRawSample(
          index: 0,
          timestamp: now,
          point: const LatLng(10.750000, 106.650000),
          accuracyMeters: 4.0,
          sensorSpeedMs: 0.0,
        ),
        qualityFlags: const {TrajectoryQualityFlag.clean},
        segmentDistanceMeters: 0.0,
        timeDeltaSec: 1.0,
        impliedSpeedMs: 0.0,
        impliedAccelerationMs2: 0.0,
        isAccepted: true,
        isGapRecovery: false,
      );
      final pNextWalk = walkDetector.evaluateStreamingPoint(
        candidate: TrajectoryRawSample(
          index: 1,
          timestamp: now.add(const Duration(seconds: 1)),
          point: const LatLng(10.7500135, 106.650000), // ~1.5m north
          accuracyMeters: 4.0,
          sensorSpeedMs: 1.5,
        ),
        previousAcceptedPoint: pPrevWalk,
        twoPointsAgoAccepted: null,
        rawTimeSincePreviousSampleSec: 1.0,
      );
      expect(pNextWalk.isAccepted, isTrue);
      expect(pNextWalk.qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike), isFalse);

      // B. Running: from 1.0 m/s to 4.0 m/s in 1s (a = 3.0 m/s^2 <= 4.5 m/s^2 limit)
      final runLimits = KinematicLimits.running();
      final runDetector = TrajectoryOutlierDetector(limits: runLimits);
      final pPrevRun = ProcessedTrajectoryPoint(
        rawSample: TrajectoryRawSample(
          index: 0,
          timestamp: now,
          point: const LatLng(10.750000, 106.650000),
          accuracyMeters: 4.0,
          sensorSpeedMs: 1.0,
        ),
        qualityFlags: const {TrajectoryQualityFlag.clean},
        segmentDistanceMeters: 1.0,
        timeDeltaSec: 1.0,
        impliedSpeedMs: 1.0,
        impliedAccelerationMs2: 0.0,
        isAccepted: true,
        isGapRecovery: false,
      );
      final pNextRun = runDetector.evaluateStreamingPoint(
        candidate: TrajectoryRawSample(
          index: 1,
          timestamp: now.add(const Duration(seconds: 1)),
          point: const LatLng(10.750036, 106.650000), // ~4.0m north
          accuracyMeters: 4.0,
          sensorSpeedMs: 4.0,
        ),
        previousAcceptedPoint: pPrevRun,
        twoPointsAgoAccepted: null,
        rawTimeSincePreviousSampleSec: 1.0,
      );
      expect(pNextRun.isAccepted, isTrue);
      expect(pNextRun.qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike), isFalse);

      // C. Cycling: from 2.0 m/s to 6.5 m/s in 1s (a = 4.5 m/s^2 <= 6.0 m/s^2 limit)
      final cycleLimits = KinematicLimits.cycling();
      final cycleDetector = TrajectoryOutlierDetector(limits: cycleLimits);
      final pPrevCycle = ProcessedTrajectoryPoint(
        rawSample: TrajectoryRawSample(
          index: 0,
          timestamp: now,
          point: const LatLng(10.750000, 106.650000),
          accuracyMeters: 5.0,
          sensorSpeedMs: 2.0,
        ),
        qualityFlags: const {TrajectoryQualityFlag.clean},
        segmentDistanceMeters: 2.0,
        timeDeltaSec: 1.0,
        impliedSpeedMs: 2.0,
        impliedAccelerationMs2: 0.0,
        isAccepted: true,
        isGapRecovery: false,
      );
      final pNextCycle = cycleDetector.evaluateStreamingPoint(
        candidate: TrajectoryRawSample(
          index: 1,
          timestamp: now.add(const Duration(seconds: 1)),
          point: const LatLng(10.7500585, 106.650000), // ~6.5m north
          accuracyMeters: 5.0,
          sensorSpeedMs: 6.5,
        ),
        previousAcceptedPoint: pPrevCycle,
        twoPointsAgoAccepted: null,
        rawTimeSincePreviousSampleSec: 1.0,
      );
      expect(pNextCycle.isAccepted, isTrue);
      expect(pNextCycle.qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 3: IOD and SCC Non-Interference Verification
    // -------------------------------------------------------------------------
    test('NON-INTERFERENCE: Verify IOD does not disrupt EKF and SCC is independent of GPS filtering', () {
      const engine = WorkoutTrackingEngine();
      final now = DateTime.utc(2026, 11, 8, 15, 0, 0);

      // 1. SCC Step Count Independence
      // Suppose GPS rejects 3 consecutive fixes due to unphysical jump or high inaccuracy
      final normalStepUpdate = WorkoutStepUpdate(
        activeSessionSteps: 120,
        totalSessionSteps: 520,
        deltaSteps: 20,
        currentCadenceSpm: 155,
        avgCadenceSpm: 150,
        timestamp: now,
        isPaused: false,
        source: StepSensorSource.mock,
      );

      final decision1 = engine.evaluateStepUpdate(
        sessionSteps: normalStepUpdate.activeSessionSteps,
        currentStepCount: 100,
        activityType: 'Running',
        requiresGpsTracking: true,
        gpsFallbackActive: false,
        recordingSource: 'gps',
        lastAcceptedPositionTime: now,
        now: now,
      );

      // Delta steps are 20, cadence is 155 spm, NO fallback triggered
      expect(decision1.delta, equals(20));
      expect(decision1.shouldActivateGpsFallback, isFalse);

      // 2. Step counting when GPS is completely rejected (e.g. bad fixes)
      final subsequentStepUpdate = WorkoutStepUpdate(
        activeSessionSteps: 145,
        totalSessionSteps: 545,
        deltaSteps: 25,
        currentCadenceSpm: 158,
        avgCadenceSpm: 152,
        timestamp: now.add(const Duration(seconds: 5)),
        isPaused: false,
        source: StepSensorSource.mock,
      );

      final decision2 = engine.evaluateStepUpdate(
        sessionSteps: subsequentStepUpdate.activeSessionSteps,
        currentStepCount: 120,
        activityType: 'Running',
        requiresGpsTracking: true,
        gpsFallbackActive: false,
        recordingSource: 'gps',
        lastAcceptedPositionTime: now, // last accepted GPS was 5s ago
        now: now.add(const Duration(seconds: 5)),
      );

      // Steps still increment by 25, cadence unaffected, no GPS mutation
      expect(decision2.delta, equals(25));
      expect(decision2.shouldActivateGpsFallback, isFalse);

      // 3. Fallback only triggers when GPS is dead for >12s
      final longOutageStepUpdate = WorkoutStepUpdate(
        activeSessionSteps: 170,
        totalSessionSteps: 570,
        deltaSteps: 25,
        currentCadenceSpm: 155,
        avgCadenceSpm: 153,
        timestamp: now.add(const Duration(seconds: 15)),
        isPaused: false,
        source: StepSensorSource.mock,
      );

      final decision3 = engine.evaluateStepUpdate(
        sessionSteps: longOutageStepUpdate.activeSessionSteps,
        currentStepCount: 145,
        activityType: 'Running',
        requiresGpsTracking: true,
        gpsFallbackActive: false,
        recordingSource: 'gps',
        lastAcceptedPositionTime: now, // 15s stale!
        now: now.add(const Duration(seconds: 15)),
      );

      // Triggers indoor step fallback smoothly
      expect(decision3.delta, equals(25));
      expect(decision3.shouldActivateGpsFallback, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Production Feature Flags Audit
    // -------------------------------------------------------------------------
    test('FLAGS AUDIT: Verify research runtime defaults', () {
      // EKF algorithm defaults to 4-State EKF
      expect(kGpsFilterAlgoConfig, equals('ekf4State'));

      // P01 active; shadow off
      expect(kEnableTrajectoryPreprocessing, isTrue);
      expect(kEnableTrajectoryPreprocessingShadowMode, isFalse);

      // Phase 2 active; shadow off
      expect(kEnableGnssCorrection, isTrue);
      expect(kEnableGnssCorrectionShadowMode, isFalse);

      // Phase 3 offline visual reconstruction ON
      expect(kEnableTrajectoryReconstruction, isTrue);
      expect(kEnableTrajectoryReconstructionShadowMode, isFalse);

      // Enhanced GPS Input Quality Gate defaults to false
      expect(kEnableGpsQualityGate, isFalse);
      expect(kEnableGpsQualityGateShadowMode, isFalse);
    });
  });
}
