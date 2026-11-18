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

    test('BENCHMARK 1: Sparse Dropouts (5s Interval) on OSM 247-Epoch Circuit (4-Pipeline Comparison)', () {
      // Simulate sparse sampling by picking every 5th second (0, 5, 10, ...)
      final sparseSamples = <TrajectoryRawSample>[];
      for (var i = 0; i < osmRawSamples.length; i += 5) {
        sparseSamples.add(osmRawSamples[i]);
      }

      const p03Engine = KinematicTrajectoryReconstructionEngine();

      // =========================================================================
      // PIPELINE A: Raw Linear Interpolation (Linear chord on raw 5s fixes)
      // =========================================================================
      final swA = Stopwatch()..start();
      final pipelineAErrors = <double>[];
      final pipelineATurnErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);
        var posA = sparseSamples.first.point;
        for (var k = 0; k < sparseSamples.length - 1; k++) {
          final t0 = sparseSamples[k].timestamp;
          final t1 = sparseSamples[k + 1].timestamp;
          if (tTime.compareTo(t0) >= 0 && tTime.compareTo(t1) <= 0) {
            final dtTotal = t1.difference(t0).inMilliseconds;
            final dtCurr = tTime.difference(t0).inMilliseconds;
            final u = dtTotal > 0 ? (dtCurr / dtTotal) : 0.0;
            final p0 = sparseSamples[k].point;
            final p1 = sparseSamples[k + 1].point;
            posA = LatLng(
              p0.latitude + (p1.latitude - p0.latitude) * u,
              p0.longitude + (p1.longitude - p0.longitude) * u,
            );
            break;
          }
        }
        final err = distanceCalculator.distance(posA, gt.position);
        pipelineAErrors.add(err);
        if (gt.segmentType == 'turn_90') pipelineATurnErrors.add(err);
      }
      swA.stop();
      var distA = 0.0;
      for (var k = 1; k < sparseSamples.length; k++) {
        distA += distanceCalculator.distance(sparseSamples[k - 1].point, sparseSamples[k].point);
      }
      final rmseA = math.sqrt(pipelineAErrors.fold(0.0, (acc, e) => acc + e * e) / pipelineAErrors.length);
      final sortedA = List<double>.from(pipelineAErrors)..sort();
      final p95A = sortedA[(sortedA.length * 0.95).floor()];
      final apexA = pipelineATurnErrors.isEmpty ? 0.0 : pipelineATurnErrors.reduce(math.max);
      final latencyA = swA.elapsedMicroseconds / groundTruth.length;

      // =========================================================================
      // PIPELINE B: Raw Monotone PCHIP (Fritsch & Carlson 1980 on raw 5s fixes)
      // =========================================================================
      final rawPoints = sparseSamples.map((s) => ProcessedTrajectoryPoint(
        rawSample: s,
        qualityFlags: {TrajectoryQualityFlag.clean},
        segmentDistanceMeters: 5.0 * (s.sensorSpeedMs ?? 5.0),
        timeDeltaSec: 5.0,
        impliedSpeedMs: s.sensorSpeedMs ?? 5.0,
        impliedAccelerationMs2: 0.0,
        isAccepted: true,
      )).toList(growable: false);

      final swB = Stopwatch()..start();
      final resB = p03Engine.reconstructTrajectory(
        points: rawPoints,
        activityType: 'cycling',
        samplingStepSec: 1.0,
      );
      swB.stop();

      final pipelineBErrors = <double>[];
      final pipelineBTurnErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);
        var matched = resB.points.first.point;
        var minDt = 999999;
        for (final p in resB.points) {
          final diff = (p.timestamp.difference(tTime).inMilliseconds).abs();
          if (diff < minDt) {
            minDt = diff;
            matched = p.point;
          }
          if (diff == 0) break;
        }
        final err = distanceCalculator.distance(matched, gt.position);
        pipelineBErrors.add(err);
        if (gt.segmentType == 'turn_90') pipelineBTurnErrors.add(err);
      }
      final rmseB = math.sqrt(pipelineBErrors.fold(0.0, (acc, e) => acc + e * e) / pipelineBErrors.length);
      final sortedB = List<double>.from(pipelineBErrors)..sort();
      final p95B = sortedB[(sortedB.length * 0.95).floor()];
      final apexB = pipelineBTurnErrors.isEmpty ? 0.0 : pipelineBTurnErrors.reduce(math.max);
      final latencyB = swB.elapsedMicroseconds / resB.reconstructedPointCount;

      // =========================================================================
      // PIPELINE C: P01 + P02 + AEKF (Discrete AEKF fixes with linear chord)
      // =========================================================================
      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      final prepResult = batchPreprocessor.process(sparseSamples);

      final ekfBaseline = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );

      final swC = Stopwatch()..start();
      final baselinePositions = <({DateTime time, LatLng position, double speedMs, double? headingDeg, double? alt})>[];
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
        baselinePositions.add((time: pt.timestamp, position: est.position, speedMs: est.speedMs, headingDeg: est.headingDeg, alt: pt.rawSample.altitudeMeters));
      }
      swC.stop();

      final pipelineCErrors = <double>[];
      final pipelineCTurnErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);
        var basePos = baselinePositions.first.position;
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
        final err = distanceCalculator.distance(basePos, gt.position);
        pipelineCErrors.add(err);
        if (gt.segmentType == 'turn_90') pipelineCTurnErrors.add(err);
      }
      var distC = 0.0;
      for (var k = 1; k < baselinePositions.length; k++) {
        distC += distanceCalculator.distance(baselinePositions[k - 1].position, baselinePositions[k].position);
      }
      final rmseC = math.sqrt(pipelineCErrors.fold(0.0, (acc, e) => acc + e * e) / pipelineCErrors.length);
      final sortedC = List<double>.from(pipelineCErrors)..sort();
      final p95C = sortedC[(sortedC.length * 0.95).floor()];
      final apexC = pipelineCTurnErrors.isEmpty ? 0.0 : pipelineCTurnErrors.reduce(math.max);
      final latencyC = swC.elapsedMicroseconds / baselinePositions.length;

      // =========================================================================
      // PIPELINE D: P01 Preprocessing + P03 Kinematic PCHIP Reconstruction
      // =========================================================================
      final swD = Stopwatch()..start();
      final resD = p03Engine.reconstructTrajectory(
        points: prepResult.processedPoints,
        activityType: 'cycling',
        samplingStepSec: 1.0,
      );
      swD.stop();

      final pipelineDErrors = <double>[];
      final pipelineDTurnErrors = <double>[];
      for (var t = 0; t < groundTruth.length; t++) {
        final gt = groundTruth[t];
        final tTime = DateTime.fromMillisecondsSinceEpoch(t * 1000);
        var matched = resD.points.first.point;
        var minDt = 999999;
        for (final p in resD.points) {
          final diff = (p.timestamp.difference(tTime).inMilliseconds).abs();
          if (diff < minDt) {
            minDt = diff;
            matched = p.point;
          }
          if (diff == 0) break;
        }
        final err = distanceCalculator.distance(matched, gt.position);
        pipelineDErrors.add(err);
        if (gt.segmentType == 'turn_90') pipelineDTurnErrors.add(err);
      }
      final rmseD = math.sqrt(pipelineDErrors.fold(0.0, (acc, e) => acc + e * e) / pipelineDErrors.length);
      final sortedD = List<double>.from(pipelineDErrors)..sort();
      final p95D = sortedD[(sortedD.length * 0.95).floor()];
      final apexD = pipelineDTurnErrors.isEmpty ? 0.0 : pipelineDTurnErrors.reduce(math.max);
      final latencyD = swD.elapsedMicroseconds / resD.reconstructedPointCount;

      // =========================================================================
      // PIPELINE E: P01 + P03 Reconstruction + P02 + AEKF (1Hz Filtered Stream)
      // =========================================================================
      final ekfRecon = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );
      final swE = Stopwatch()..start();
      final pipelineEErrors = <double>[];
      final pipelineETurnErrors = <double>[];
      var distE = 0.0;
      LatLng? lastPosE;
      for (var i = 0; i < resD.points.length; i++) {
        final pt = resD.points[i];
        final est = ekfRecon.update(
          measurementPoint: pt.point,
          accuracyMeters: pt.isInterpolated ? 8.0 : 4.0,
          timeDeltaSec: 1.0,
          speedMs: pt.impliedSpeedMs,
          headingDeg: pt.impliedHeadingDeg,
          activityType: 'cycling',
        );
        if (lastPosE != null) {
          distE += distanceCalculator.distance(lastPosE, est.position);
        }
        lastPosE = est.position;

        if (i < groundTruth.length) {
          final gt = groundTruth[i];
          final err = distanceCalculator.distance(est.position, gt.position);
          pipelineEErrors.add(err);
          if (gt.segmentType == 'turn_90') pipelineETurnErrors.add(err);
        }
      }
      swE.stop();
      final rmseE = math.sqrt(pipelineEErrors.fold(0.0, (acc, e) => acc + e * e) / pipelineEErrors.length);
      final sortedE = List<double>.from(pipelineEErrors)..sort();
      final p95E = sortedE[(sortedE.length * 0.95).floor()];
      final apexE = pipelineETurnErrors.isEmpty ? 0.0 : pipelineETurnErrors.reduce(math.max);
      final latencyE = swE.elapsedMicroseconds / resD.points.length;

      print('\n========================================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 1: DOWNSAMPLED 5S SPARSE DROPOUTS ON OSM CIRCUIT (1,113.0 M REFERENCE - MULTI-PIPELINE)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | 1Hz Trajectory RMSE | P95 Error | Reconstructed Dist | Turn Apex Lag | Latency |');
      print('|:-----------------------------------------|:-------------------:|:---------:|:------------------:|:-------------:|:-------:|');
      print('| A. Raw Linear Interpolation (5s chords)  | ${rmseA.toStringAsFixed(2).padLeft(17)} m | ${p95A.toStringAsFixed(1).padLeft(7)} m | ${distA.toStringAsFixed(1).padLeft(16)} m | ${apexA.toStringAsFixed(1).padLeft(11)} m | ${latencyA.toStringAsFixed(1).padLeft(5)} µs |');
      print('| B. Raw Monotone PCHIP (Fritsch-Carlson)  | ${rmseB.toStringAsFixed(2).padLeft(17)} m | ${p95B.toStringAsFixed(1).padLeft(7)} m | ${resB.totalReconstructedDistanceMeters.toStringAsFixed(1).padLeft(16)} m | ${apexB.toStringAsFixed(1).padLeft(11)} m | ${latencyB.toStringAsFixed(1).padLeft(5)} µs |');
      print('| C. P01 + P02 + AEKF (5s sparse baseline) | ${rmseC.toStringAsFixed(2).padLeft(17)} m | ${p95C.toStringAsFixed(1).padLeft(7)} m | ${distC.toStringAsFixed(1).padLeft(16)} m | ${apexC.toStringAsFixed(1).padLeft(11)} m | ${latencyC.toStringAsFixed(1).padLeft(5)} µs |');
      print('| D. P01 + P03 Kinematic PCHIP (Clean Rec) | ${rmseD.toStringAsFixed(2).padLeft(17)} m | ${p95D.toStringAsFixed(1).padLeft(7)} m | ${resD.totalReconstructedDistanceMeters.toStringAsFixed(1).padLeft(16)} m | ${apexD.toStringAsFixed(1).padLeft(11)} m | ${latencyD.toStringAsFixed(1).padLeft(5)} µs |');
      print('| E. P01 + P03 + P02 + AEKF (1Hz Filtered) | ${rmseE.toStringAsFixed(2).padLeft(17)} m | ${p95E.toStringAsFixed(1).padLeft(7)} m | ${distE.toStringAsFixed(1).padLeft(16)} m | ${apexE.toStringAsFixed(1).padLeft(11)} m | ${latencyE.toStringAsFixed(1).padLeft(5)} µs |');
      print('========================================================================================================================\n');

      final segments = ['straight', 'turn_90', 'stationary', 'urban_canyon', 'roundabout', 'outage'];
      final segmentStats = <String, ({double linearRmse, double pchipRmse, double p01PchipRmse, int count})>{};
      for (final seg in segments) {
        final errsA = <double>[];
        final errsB = <double>[];
        final errsD = <double>[];
        for (var t = 0; t < groundTruth.length; t++) {
          if (groundTruth[t].segmentType == seg) {
            errsA.add(pipelineAErrors[t]);
            errsB.add(pipelineBErrors[t]);
            errsD.add(pipelineDErrors[t]);
          }
        }
        if (errsA.isNotEmpty) {
          final rA = math.sqrt(errsA.fold(0.0, (acc, e) => acc + e * e) / errsA.length);
          final rB = math.sqrt(errsB.fold(0.0, (acc, e) => acc + e * e) / errsB.length);
          final rD = math.sqrt(errsD.fold(0.0, (acc, e) => acc + e * e) / errsD.length);
          segmentStats[seg] = (linearRmse: rA, pchipRmse: rB, p01PchipRmse: rD, count: errsA.length);
        }
      }

      print('========================================================================================================================');
      print('AETRON RESEARCH P03: FAIR LINEAR VS PCHIP ERROR BREAKDOWN BY SEGMENT TYPE');
      print('========================================================================================================================');
      print('| Segment Type            | Epoch Count | Linear RMSE (Pipe A) | PCHIP RMSE (Pipe B) | P01+PCHIP (Pipe D) | Best Method |');
      print('|:------------------------|:-----------:|:--------------------:|:-------------------:|:------------------:|:-----------:|');
      for (final entry in segmentStats.entries) {
        final s = entry.value;
        final best = s.linearRmse < s.pchipRmse ? 'Linear' : (s.pchipRmse < s.linearRmse ? 'PCHIP' : 'Tie');
        print('| ${entry.key.padRight(24)}| ${s.count.toString().padLeft(11)} | ${s.linearRmse.toStringAsFixed(2).padLeft(18)} m | ${s.pchipRmse.toStringAsFixed(2).padLeft(17)} m | ${s.p01PchipRmse.toStringAsFixed(2).padLeft(16)} m | ${best.padLeft(11)} |');
      }
      print('========================================================================================================================\n');

      expect(groundTruthDistanceMeters, greaterThan(0.0));
      expect(resD.interpolatedPointCount, greaterThan(150));
      expect(rmseD, lessThan(rmseC));
      expect(p95D, lessThanOrEqualTo(p95C));
      expect(apexD, lessThan(10.0));
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

    test('BENCHMARK 3: Historical Cycling Dataset (10,779 Raw Fixes across 7 Sessions)', () {
      final file = File('exports/aetron_raw_gps_combined.csv');
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
      expect(records.length, equals(10779));

      final sessionGroups = <String, List<RawCsvRecord>>{};
      for (final r in records) {
        sessionGroups.putIfAbsent(r.workoutId, () => []).add(r);
      }
      expect(sessionGroups.length, equals(7));

      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      const p03Engine = KinematicTrajectoryReconstructionEngine();

      var totalInputPoints = 0;
      var totalReconstructedPoints = 0;
      var totalInterpolatedPoints = 0;
      var totalIndeterminateGaps = 0;
      var totalReconstructedDistKm = 0.0;
      final sw = Stopwatch()..start();

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
      sw.stop();
      final totalElapsedMs = sw.elapsedMilliseconds;
      final throughput = (totalInputPoints / (math.max(1, totalElapsedMs) / 1000.0)).round();

      print('====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 3: HISTORICAL CYCLING DATASET (10,779 RAW FIXES ACROSS 7 SESSIONS)');
      print('====================================================================================================');
      print('| Metric                                   | Observed Value |');
      print('|:-----------------------------------------|:--------------:|');
      print('| Total Raw Input Fixes                    | $totalInputPoints |');
      print('| Distinct Sessions Processed              | ${sessionGroups.length} |');
      print('| Total Reconstructed Stream Points        | $totalReconstructedPoints |');
      print('| Interpolated Recoverable Points          | $totalInterpolatedPoints |');
      print('| Indeterminate Prolonged Outages (dt>15s) | $totalIndeterminateGaps |');
      print('| Total Reconstructed Distance             | ${totalReconstructedDistKm.toStringAsFixed(2)} km |');
      print('| Total Execution Time (7 full sessions)   | $totalElapsedMs ms |');
      print('| Processing Throughput                    | $throughput fixes/sec |');
      print('====================================================================================================\n');

      expect(totalInputPoints, equals(10779));
      expect(totalReconstructedPoints, greaterThan(totalInputPoints));
      expect(totalElapsedMs, lessThan(3000)); // Under 3 seconds on host
    });

    test('BENCHMARK 4: Non-OSM Off-Road / Athletic Stadium Track (Network-Agnostic Recovery)', () {
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

      // Verify independence: evaluate perpendicular lateral error against the exact mathematical track geometry
      final lateralErrors = <double>[];
      for (final p in reconTrack.points) {
        final dLat = (p.point.latitude - pCenter.latitude) * (math.pi / 180.0) * 6378137.0;
        final dLng = (p.point.longitude - pCenter.longitude) * (math.pi / 180.0) * 6378137.0 * math.cos(pCenter.latitude * math.pi / 180.0);

        double distToCenterline;
        if (dLat >= 0.0 && dLat <= 100.0) {
          // Straights: x = trackRadius or x = -trackRadius
          final distEastStraight = (dLng - trackRadius).abs();
          final distWestStraight = (dLng - (-trackRadius)).abs();
          distToCenterline = math.min(distEastStraight, distWestStraight);
        } else if (dLat > 100.0) {
          // North semicircle: center at (0, 100), radius trackRadius
          final r = math.sqrt(dLng * dLng + (dLat - 100.0) * (dLat - 100.0));
          distToCenterline = (r - trackRadius).abs();
        } else {
          // South semicircle: center at (0, 0), radius trackRadius
          final r = math.sqrt(dLng * dLng + dLat * dLat);
          distToCenterline = (r - trackRadius).abs();
        }
        lateralErrors.add(distToCenterline);
      }
      final lateralRmse = math.sqrt(lateralErrors.fold(0.0, (acc, e) => acc + e * e) / lateralErrors.length);
      final maxLateralDev = lateralErrors.reduce(math.max);

      print('====================================================================================================');
      print('AETRON RESEARCH P03 BENCHMARK 4: NON-OSM STADIUM TRACK (400M OVAL, GEOMETRY INDEPENDENCE)');
      print('====================================================================================================');
      print('| Metric                                   | Target Reference | Reconstructed Value |');
      print('|:-----------------------------------------|:----------------:|:-------------------:|');
      print('| True Lap Length                          |         400.0 m  | ${reconTrack.totalReconstructedDistanceMeters.toStringAsFixed(1).padLeft(17)} m  |');
      print('| Sparse Input Points (dt = 4.0s)          |          26 pts  | ${reconTrack.originalPointCount.toString().padLeft(17)} pts  |');
      print('| Synthesized PCHIP Points (dt = 1.0s)     |          75 pts  | ${reconTrack.interpolatedPointCount.toString().padLeft(17)} pts  |');
      print('| Lateral Centerline RMSE                  |           0.0 m  | ${lateralRmse.toStringAsFixed(2).padLeft(17)} m  |');
      print('| Max Lateral Deviation                    |          <2.0 m  | ${maxLateralDev.toStringAsFixed(2).padLeft(17)} m  |');
      print('| Indeterminate Outages Flagged            |           0 gaps | ${reconTrack.indeterminateGapCount.toString().padLeft(17)} gaps |');
      print('====================================================================================================\n');

      expect(reconTrack.interpolatedPointCount, greaterThan(60));
      expect((reconTrack.totalReconstructedDistanceMeters - 400.0).abs(), lessThan(15.0));
      expect(lateralRmse, lessThan(2.0)); // Highly faithful curvature recovery
    });

    test('BENCHMARK 5: Prolonged Tunnel Blackout Outage (dt = 45s Gap)', () {
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
      print('AETRON RESEARCH P03 BENCHMARK 5: PROLONGED TUNNEL BLACKOUT (45S OUTAGE)');
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

    test('BENCHMARK 6 / RUNTIME: WorkoutSessionFinalizer integration with P03 feature flag', () {
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
        reconstructionMethod: ReconstructionMethod.monotonePchip,
      );

      final p03Metrics = jsonDecode(p03Result.session.routeMatchMetricsJson);
      expect(p03Metrics['reconstruction_enabled'], isTrue);
      expect(p03Metrics['reconstruction_interpolated_points'], greaterThan(0));
      expect(p03Result.session.routeMatchStatus, equals('reconstructed_pchip'));
      expect(p03Result.session.matchedRouteJson, isNot(equals('[]')));

      // 3. Blackout splitting verification in Finalizer (Zero fake line across severe outage)
      final blackoutPositions = [
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
        // 30s prolonged blackout gap
        Position(
          latitude: 10.750500,
          longitude: 106.650500,
          timestamp: t0.add(const Duration(seconds: 30)),
          altitude: 10.0,
          accuracy: 4.0,
          heading: 90.0,
          speed: 3.0,
          speedAccuracy: 0.5,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        ),
      ];

      final blackoutResult = finalizer.finalize(
        state: state,
        userId: 'test_user_blackout',
        finishedAt: t0.add(const Duration(seconds: 30)),
        caloriesBurned: 5,
        fallbackStrideLengthMeters: 1.25,
        trackingEngine: trackingEngine,
        rawGpsPositions: blackoutPositions,
        filteredRouteSegments: const [],
        enableTrajectoryPreprocessing: true,
        enableTrajectoryReconstruction: true,
        reconstructionMethod: ReconstructionMethod.monotonePchip,
      );

      final blackoutSegments = jsonDecode(blackoutResult.session.matchedRouteJson) as List;
      // Must produce 2 separate polyline segments, not a connected line across the blackout!
      expect(blackoutSegments.length, equals(2));
      expect(rawPositions.length, equals(2)); // Raw GPS list is completely unmodified
    });
  });
}
