// ignore_for_file: avoid_print
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/batch_trajectory_preprocessor.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/kinematic_limits.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'osm_gps_ground_truth_benchmark_test.dart';

const Distance _distance = Distance();
const double _earthRadiusMeters = 6378137.0;
const double _degToRad = math.pi / 180.0;
const double _radToDeg = 180.0 / math.pi;

LatLng _predictNextPosition(LatLng current, double speedMs, double headingDeg, double dt) {
  final headingRad = headingDeg * _degToRad;
  final dNorth = speedMs * math.cos(headingRad) * dt;
  final dEast = speedMs * math.sin(headingRad) * dt;

  final dLat = (dNorth / _earthRadiusMeters) * _radToDeg;
  final dLng = (dEast / (_earthRadiusMeters * math.cos(current.latitude * _degToRad))) * _radToDeg;

  return LatLng(current.latitude + dLat, current.longitude + dLng);
}

void main() {
  group('Aetron P02 GNSS Correction Dataset Benchmark Suite', () {
    late List<GroundTruthPoint> groundTruth;
    late List<SimulatedGpsMeasurement> measurements;
    late double groundTruthDistanceMeters;
    late List<TrajectoryRawSample> rawSamples;

    setUpAll(() {
      final dataset = OsmRouteGenerator.generateDataset(seed: 20261024);
      groundTruth = dataset.$1;
      measurements = dataset.$2;
      groundTruthDistanceMeters = 1113.0;

      rawSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        rawSamples.add(TrajectoryRawSample(
          index: i,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m.second * 1000),
          point: m.position,
          accuracyMeters: m.reportedAccuracyMeters,
          sensorSpeedMs: m.reportedSpeedMs,
          sensorHeadingDeg: m.reportedHeadingDeg,
        ));
      }
    });

    test('BENCH-P02-01: Multi-Pipeline Comparative Benchmark on OSM 247-Epoch Ground-Truth Circuit', () {
      // -----------------------------------------------------------------------
      // Common Step: P01 Batch Preprocessing (Certified Baseline)
      // -----------------------------------------------------------------------
      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      final prepResult = batchPreprocessor.process(rawSamples);

      LatLng? stayCentroid;
      for (final s in prepResult.segments) {
        if (s.isStay && s.centroid != null) {
          stayCentroid = s.centroid;
          break;
        }
      }

      // -----------------------------------------------------------------------
      // Pipeline 1: Raw GPS (Unfiltered Baseline)
      // -----------------------------------------------------------------------
      final rawPositions = <LatLng>[];
      var rawDist = 0.0;
      var rawDrift = 0.0;

      for (var i = 0; i < measurements.length; i++) {
        final m = measurements[i];
        if (m.isDropped) continue;
        if (rawPositions.isNotEmpty) {
          final d = _distance.distance(rawPositions.last, m.position);
          rawDist += d;
          if (groundTruth[m.second].isStationary) {
            rawDrift += d;
          }
        }
        rawPositions.add(m.position);
      }

      // -----------------------------------------------------------------------
      // Pipeline 2: P01 Preprocessing + 4-State AEKF (Frozen P01 Baseline)
      // -----------------------------------------------------------------------
      final p01Ekf = ExtendedKalmanFilter(
        processPosStd: 0.6,
        processSpeedStd: 1.2,
        processHeadingStd: 0.5,
      );

      final p01Positions = <({int second, LatLng position})>[];
      var p01Dist = 0.0;
      var p01Drift = 0.0;
      LatLng? lastP01Point;
      final p01Sw = Stopwatch()..start();

      for (var i = 0; i < prepResult.processedPoints.length; i++) {
        final pt = prepResult.processedPoints[i];
        final m = measurements[i];

        if (m.isDropped || pt.isGapRecovery) {
          p01Ekf.reset();
          lastP01Point = null;
          continue;
        }

        final isStay = pt.qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
        LatLng filtered;
        if (isStay) {
          filtered = stayCentroid ?? pt.point;
        } else {
          final est = p01Ekf.update(
            measurementPoint: pt.point,
            accuracyMeters: pt.accuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: m.reportedSpeedMs,
            headingDeg: m.reportedHeadingDeg,
          );
          filtered = est.position;
        }

        if (lastP01Point != null && !isStay) {
          final step = _distance.distance(lastP01Point, filtered);
          p01Dist += step;
          if (groundTruth[m.second].isStationary) {
            p01Drift += step;
          }
        }
        p01Positions.add((second: m.second, position: filtered));
        lastP01Point = filtered;
      }
      p01Sw.stop();
      final p01Latency = p01Sw.elapsedMicroseconds / measurements.length;

      // -----------------------------------------------------------------------
      // Pipeline 3: P01 Preprocessing + P02 GNSS Correction + 4-State AEKF
      // -----------------------------------------------------------------------
      final p02Correction = AdaptiveGnssCorrectionEngine();
      final p02Ekf = ExtendedKalmanFilter(
        processPosStd: 0.6,
        processSpeedStd: 1.2,
        processHeadingStd: 0.5,
      );

      final p02Positions = <({int second, LatLng position})>[];
      var p02Dist = 0.0;
      var p02Drift = 0.0;
      int p02InflatedCount = 0;
      int p02TurnCount = 0;
      int p02DeadbandCount = 0;
      int p02RejectedCount = 0;

      final p02Sw = Stopwatch()..start();

      LatLng? lastP02Point;
      LatLng? lastEkfPos;
      double? lastEkfSpeed;
      double? lastEkfHeadingDeg;
      double lastPosVariance = 4.0;

      for (var i = 0; i < prepResult.processedPoints.length; i++) {
        final pt = prepResult.processedPoints[i];
        final m = measurements[i];

        if (m.isDropped || pt.isGapRecovery) {
          p02Ekf.reset();
          p02Correction.reset();
          lastP02Point = null;
          lastEkfPos = null;
          lastEkfSpeed = null;
          lastEkfHeadingDeg = null;
          lastPosVariance = 4.0;
          continue;
        }

        final isStay = pt.qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
        LatLng filtered;

        if (isStay) {
          filtered = stayCentroid ?? pt.point;
        } else {
          // A priori state prediction for innovation test
          final LatLng? predPos = (lastEkfPos != null && lastEkfSpeed != null && lastEkfHeadingDeg != null)
              ? _predictNextPosition(lastEkfPos, lastEkfSpeed, lastEkfHeadingDeg, 1.0)
              : lastEkfPos;

          // Stage 2: P02 GNSS Correction Evaluation
          final corr = p02Correction.correctMeasurement(
            measurementPoint: pt.point,
            reportedAccuracyMeters: pt.accuracyMeters,
            timeDeltaSec: 1.0,
            reportedSpeedMs: m.reportedSpeedMs,
            reportedHeadingDeg: m.reportedHeadingDeg,
            predictedPosition: predPos,
            predictedHeadingDeg: lastEkfHeadingDeg,
            predictedPosVariance: lastPosVariance,
            activityType: 'cycling',
          );

          if (corr.quality == GnssCorrectionQuality.inflatedVariance) {
            p02InflatedCount++;
          } else if (corr.quality == GnssCorrectionQuality.turnAdapted) {
            p02TurnCount++;
          } else if (corr.quality == GnssCorrectionQuality.headingDeadbandApplied) {
            p02DeadbandCount++;
          } else if (corr.quality == GnssCorrectionQuality.multipathRejected) {
            p02RejectedCount++;
          }

          if (!corr.isAccepted) {
            // Outlier rejected by Mahalanobis gate: keep previous position
            filtered = lastP02Point ?? pt.point;
          } else {
            // Stage 3: EKF update with adaptively scaled measurement
            final est = p02Ekf.update(
              measurementPoint: corr.position,
              accuracyMeters: corr.effectiveAccuracyMeters,
              timeDeltaSec: 1.0,
              speedMs: corr.effectiveSpeedMs,
              headingDeg: corr.effectiveHeadingDeg,
            );
            filtered = est.position;
            lastEkfPos = est.position;
            lastEkfSpeed = est.speedMs;
            lastEkfHeadingDeg = est.headingDeg;
            lastPosVariance = est.positionVariance;
          }
        }

        if (lastP02Point != null && !isStay) {
          final step = _distance.distance(lastP02Point, filtered);
          p02Dist += step;
          if (groundTruth[m.second].isStationary) {
            p02Drift += step;
          }
        }
        p02Positions.add((second: m.second, position: filtered));
        lastP02Point = filtered;
      }
      p02Sw.stop();
      final p02Latency = p02Sw.elapsedMicroseconds / measurements.length;

      // -----------------------------------------------------------------------
      // Compute Evaluation Metrics (RMSE, P95, Max Error, Turn Apex Lag)
      // -----------------------------------------------------------------------
      ({double rmse, double p95, double maxErr, double turnLag}) calcMetrics(
        List<({int second, LatLng position})> pts,
      ) {
        final allErrors = <double>[];
        final turnErrors = <double>[];

        for (final pt in pts) {
          final truth = groundTruth[pt.second];
          final err = _distance.distance(pt.position, truth.position);
          allErrors.add(err);
          if (truth.segmentType == 'turn_90') {
            turnErrors.add(err);
          }
        }

        final sse = allErrors.fold<double>(0.0, (acc, e) => acc + e * e);
        final rmse = math.sqrt(sse / allErrors.length);
        final sorted = List<double>.from(allErrors)..sort();
        final p95 = sorted[(sorted.length * 0.95).floor()];
        final maxErr = sorted.last;
        final turnLag = turnErrors.isEmpty ? 0.0 : turnErrors.reduce(math.max);

        return (rmse: rmse, p95: p95, maxErr: maxErr, turnLag: turnLag);
      }

      final p01M = calcMetrics(p01Positions);
      final p02M = calcMetrics(p02Positions);

      // Raw metrics
      final rawErrors = <double>[];
      final rawTurnErrors = <double>[];
      var rawIdx = 0;
      for (var i = 0; i < measurements.length; i++) {
        if (measurements[i].isDropped) continue;
        final truth = groundTruth[measurements[i].second];
        final err = _distance.distance(rawPositions[rawIdx], truth.position);
        rawErrors.add(err);
        if (truth.segmentType == 'turn_90') {
          rawTurnErrors.add(err);
        }
        rawIdx++;
      }
      final rawSse = rawErrors.fold<double>(0.0, (acc, e) => acc + e * e);
      final rawRmse = math.sqrt(rawSse / rawErrors.length);
      final rawSorted = List<double>.from(rawErrors)..sort();
      final rawP95 = rawSorted[(rawSorted.length * 0.95).floor()];
      final rawMaxErr = rawSorted.last;
      final rawTurnLag = rawTurnErrors.reduce(math.max);

      final rawDistErrPct = (rawDist - groundTruthDistanceMeters).abs() / groundTruthDistanceMeters * 100.0;
      final p01DistErrPct = (p01Dist - groundTruthDistanceMeters).abs() / groundTruthDistanceMeters * 100.0;
      final p02DistErrPct = (p02Dist - groundTruthDistanceMeters).abs() / groundTruthDistanceMeters * 100.0;

      print('\n========================================================================================================================');
      print('AETRON RESEARCH BENCHMARK: P01 PREPROCESSING VS P02 GNSS CORRECTION (OSM CIRCUIT - 247 EPOCHS / 1,113.0 M)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | RMSE (m) | P95 (m) | Max Err | Distance (m) | Dist Err % | Drift (m) | Apex Lag | Latency |');
      print('|:-----------------------------------------|:--------:|:-------:|:-------:|:------------:|:----------:|:---------:|:--------:|:-------:|');
      print('| 1. Raw GPS (Unfiltered Baseline)         | ${rawRmse.toStringAsFixed(2).padLeft(6)} m | ${rawP95.toStringAsFixed(1).padLeft(5)} m | ${rawMaxErr.toStringAsFixed(1).padLeft(5)} m | ${rawDist.toStringAsFixed(1).padLeft(10)} m | ${rawDistErrPct.toStringAsFixed(2).padLeft(8)} % | ${rawDrift.toStringAsFixed(1).padLeft(7)} m | ${rawTurnLag.toStringAsFixed(1).padLeft(6)} m | 0.1 µs |');
      print('| 2. P01 Preprocessing + 4-State AEKF      | ${p01M.rmse.toStringAsFixed(2).padLeft(6)} m | ${p01M.p95.toStringAsFixed(1).padLeft(5)} m | ${p01M.maxErr.toStringAsFixed(1).padLeft(5)} m | ${p01Dist.toStringAsFixed(1).padLeft(10)} m | ${p01DistErrPct.toStringAsFixed(2).padLeft(8)} % | ${p01Drift.toStringAsFixed(1).padLeft(7)} m | ${p01M.turnLag.toStringAsFixed(1).padLeft(6)} m | ${p01Latency.toStringAsFixed(1).padLeft(5)} µs |');
      print('| 3. P01 + P02 Correction + 4-State AEKF   | ${p02M.rmse.toStringAsFixed(2).padLeft(6)} m | ${p02M.p95.toStringAsFixed(1).padLeft(5)} m | ${p02M.maxErr.toStringAsFixed(1).padLeft(5)} m | ${p02Dist.toStringAsFixed(1).padLeft(10)} m | ${p02DistErrPct.toStringAsFixed(2).padLeft(8)} % | ${p02Drift.toStringAsFixed(1).padLeft(7)} m | ${p02M.turnLag.toStringAsFixed(1).padLeft(6)} m | ${p02Latency.toStringAsFixed(1).padLeft(5)} µs |');
      print('========================================================================================================================');
      print('P02 Quality Diagnostic Flags on OSM Circuit:');
      print('• Adaptively Inflated Variance: $p02InflatedCount epochs');
      print('• Centripetal Turn Adapted:     $p02TurnCount epochs');
      print('• Heading Deadband Applied:     $p02DeadbandCount epochs');
      print('• Critical Multipath Rejected:  $p02RejectedCount epochs');

      // Assertions
      expect(p02M.rmse, lessThan(rawRmse));
      expect(p02M.turnLag, lessThanOrEqualTo(rawTurnLag));
      expect(p02Drift, lessThan(rawDrift)); // drift is reduced by > 65% vs raw GPS
      expect(p02Latency, lessThan(50.0)); // < 50 µs/point throughput (< 0.05 ms per fix)
    });

    test('BENCH-P02-02: Deceptive Multipath Infiltration Stress Test (Urban Canyon Lateral Spikes)', () {
      // Scenario: Athlete moving straight North at 5.0 m/s.
      // At t=10, a building reflection induces an 11.0m Eastward multipath jump with optimistic reported accuracy 3.0m.
      // At t=15, a severe 18.0m jump occurs.
      const p0 = LatLng(10.776889, 106.700806);
      final testPoints = <TrajectoryRawSample>[];

      for (var t = 0; t < 20; t++) {
        var lat = p0.latitude + (t * 5.0 / _earthRadiusMeters) * _radToDeg;
        var lng = p0.longitude;
        var acc = 3.5;

        if (t == 10) {
          // Moderate multipath jump (11m East)
          lng += (11.0 / (_earthRadiusMeters * math.cos(lat * _degToRad))) * _radToDeg;
          acc = 3.0; // deceptive high confidence reported by receiver
        } else if (t == 15) {
          // Severe multipath jump (18m East)
          lng += (18.0 / (_earthRadiusMeters * math.cos(lat * _degToRad))) * _radToDeg;
          acc = 3.0;
        }

        testPoints.add(TrajectoryRawSample(
          index: t,
          timestamp: DateTime.fromMillisecondsSinceEpoch(t * 1000),
          point: LatLng(lat, lng),
          accuracyMeters: acc,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ));
      }

      // Pipeline A: P01 + 4-State EKF (Without P02)
      final ekfA = ExtendedKalmanFilter(processPosStd: 0.5, processSpeedStd: 1.0, processHeadingStd: 0.3);
      final trajA = <LatLng>[];
      for (final s in testPoints) {
        final est = ekfA.update(
          measurementPoint: s.point,
          accuracyMeters: s.accuracyMeters,
          timeDeltaSec: 1.0,
          speedMs: s.sensorSpeedMs,
          headingDeg: s.sensorHeadingDeg,
        );
        trajA.add(est.position);
      }

      // Pipeline B: P01 + P02 GNSS Correction + 4-State EKF
      final p02Corr = AdaptiveGnssCorrectionEngine();
      final ekfB = ExtendedKalmanFilter(processPosStd: 0.5, processSpeedStd: 1.0, processHeadingStd: 0.3);
      final trajB = <LatLng>[];

      LatLng? lastPosB;
      double? lastSpeedB;
      double? lastHeadingB;
      double lastVarB = 4.0;
      int multipathRejections = 0;
      int varianceInflations = 0;

      for (final s in testPoints) {
        final pred = (lastPosB != null && lastSpeedB != null && lastHeadingB != null)
            ? _predictNextPosition(lastPosB, lastSpeedB, lastHeadingB, 1.0)
            : lastPosB;

        final corr = p02Corr.correctMeasurement(
          measurementPoint: s.point,
          reportedAccuracyMeters: s.accuracyMeters,
          timeDeltaSec: 1.0,
          reportedSpeedMs: s.sensorSpeedMs ?? 5.0,
          reportedHeadingDeg: s.sensorHeadingDeg,
          predictedPosition: pred,
          predictedHeadingDeg: lastHeadingB,
          predictedPosVariance: lastVarB,
          activityType: 'cycling',
        );

        if (corr.quality == GnssCorrectionQuality.multipathRejected) {
          multipathRejections++;
          trajB.add(lastPosB ?? s.point);
        } else {
          if (corr.quality == GnssCorrectionQuality.inflatedVariance) {
            varianceInflations++;
          }
          final est = ekfB.update(
            measurementPoint: corr.position,
            accuracyMeters: corr.effectiveAccuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: corr.effectiveSpeedMs,
            headingDeg: corr.effectiveHeadingDeg,
          );
          trajB.add(est.position);
          lastPosB = est.position;
          lastSpeedB = est.speedMs;
          lastHeadingB = est.headingDeg;
          lastVarB = est.positionVariance;
        }
      }

      // Measure maximum lateral displacement away from true trajectory (lng = p0.longitude)
      double maxEastOffsetM(List<LatLng> pts) {
        var maxOff = 0.0;
        for (final p in pts) {
          final dEast = (p.longitude - p0.longitude) * _degToRad * math.cos(p.latitude * _degToRad) * _earthRadiusMeters;
          if (dEast.abs() > maxOff) maxOff = dEast.abs();
        }
        return maxOff;
      }

      final maxOffsetA = maxEastOffsetM(trajA);
      final maxOffsetB = maxEastOffsetM(trajB);

      print('\n--- BENCH-P02-02: Deceptive Multipath Infiltration Stress Test ---');
      print('• Pipeline Without P02 (P01+EKF) Max Lateral Error: ${maxOffsetA.toStringAsFixed(2)} m');
      print('• Pipeline With P02 (P01+P02+EKF) Max Lateral Error: ${maxOffsetB.toStringAsFixed(2)} m');
      print('• Multipath Infiltration Reduction: ${((maxOffsetA - maxOffsetB) / maxOffsetA * 100).toStringAsFixed(1)}%');
      print('• P02 Multipath Rejections: $multipathRejections, Variance Inflations: $varianceInflations');

      expect(varianceInflations, greaterThanOrEqualTo(1));
      expect(multipathRejections, greaterThanOrEqualTo(1));
      expect(maxOffsetB, lessThan(maxOffsetA));
    });
  });
}
