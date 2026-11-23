// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'osm_gps_ground_truth_benchmark_test.dart';

const Distance _distanceCalc = Distance();

enum BenchmarkPipelineType {
  legacyEkf,
  p01Ekf,
  legacyAekf,
  p01Aekf,
}

class FourPipelineResult {
  final BenchmarkPipelineType type;
  final String pipelineName;
  final String activityType;
  final double rmseMeters;
  final double medianErrorMeters;
  final double p95Meters;
  final double maxErrorMeters;
  final double totalDistanceMeters;
  final double distanceErrorPercent;
  final double stationaryDriftMeters;
  final int falseRejections;
  final double falseRejectionRatePct;
  final double meanNis;
  final double pctNisNominal; // <= 5.991
  final double pctNisCritical; // > 13.816
  final double latencyUs;

  const FourPipelineResult({
    required this.type,
    required this.pipelineName,
    required this.activityType,
    required this.rmseMeters,
    required this.medianErrorMeters,
    required this.p95Meters,
    required this.maxErrorMeters,
    required this.totalDistanceMeters,
    required this.distanceErrorPercent,
    required this.stationaryDriftMeters,
    required this.falseRejections,
    required this.falseRejectionRatePct,
    required this.meanNis,
    required this.pctNisNominal,
    required this.pctNisCritical,
    required this.latencyUs,
  });
}

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

/// Helper that generates OSM Circuit trajectory tailored specifically for an athletic modality
class ModalityDataset {
  final List<GroundTruthPoint> truth;
  final List<SimulatedGpsMeasurement> measurements;
  final List<TrajectoryRawSample> rawSamples;
  final double groundTruthDistanceMeters;

  const ModalityDataset({
    required this.truth,
    required this.measurements,
    required this.rawSamples,
    required this.groundTruthDistanceMeters,
  });
}

ModalityDataset generateModalityDataset({
  required String activityType,
  int seed = 42,
}) {
  final rng = DeterministicRandom(seed);
  final truth = <GroundTruthPoint>[];
  final measurements = <SimulatedGpsMeasurement>[];
  var second = 0;

  final double targetSpeed;
  final double noiseSigma;
  final double reportedAcc;

  if (activityType == 'walking') {
    targetSpeed = 1.25; // 4.5 km/h
    noiseSigma = 2.0;
    reportedAcc = 3.5;
  } else if (activityType == 'running') {
    targetSpeed = 3.33; // 12.0 km/h (5:00 min/km)
    noiseSigma = 2.5;
    reportedAcc = 4.0;
  } else {
    // cycling
    targetSpeed = 6.0; // 21.6 km/h
    noiseSigma = 3.0;
    reportedAcc = 5.0;
  }

  void addPoint({
    required LatLng point,
    required double speed,
    required double heading,
    required String segmentType,
    required bool isStationary,
    required double nominalNoiseStd,
    required double reportedAccuracy,
    bool isOutage = false,
    double lateralMultipathDrift = 0.0,
  }) {
    truth.add(GroundTruthPoint(
      second: second,
      position: point,
      speedMs: speed,
      headingDeg: heading,
      segmentType: segmentType,
      isStationary: isStationary,
    ));

    if (isOutage) {
      measurements.add(SimulatedGpsMeasurement(
        second: second,
        position: point,
        reportedAccuracyMeters: 45.0,
        reportedSpeedMs: 0.0,
        reportedHeadingDeg: null,
        isDropped: true,
      ));
    } else {
      final alongError = rng.nextGaussian() * nominalNoiseStd;
      final crossError = rng.nextGaussian() * nominalNoiseStd + lateralMultipathDrift;

      final bearingRad = heading * math.pi / 180.0;
      final perpRad = bearingRad + math.pi / 2.0;

      final dNorth = alongError * math.cos(bearingRad) + crossError * math.cos(perpRad);
      final dEast = alongError * math.sin(bearingRad) + crossError * math.sin(perpRad);

      final noisyPoint = _distanceCalc.offset(
        _distanceCalc.offset(point, dNorth, 0.0),
        dEast,
        90.0,
      );

      final speedNoise = rng.nextGaussian() * 0.2;
      final measSpeed = math.max(0.0, speed + speedNoise);

      final double? measHeading = isStationary
          ? null
          : ((heading + rng.nextGaussian() * 4.0) + 360.0) % 360.0;

      measurements.add(SimulatedGpsMeasurement(
        second: second,
        position: noisyPoint,
        reportedAccuracyMeters: reportedAccuracy,
        reportedSpeedMs: measSpeed,
        reportedHeadingDeg: measHeading,
      ));
    }
    second++;
  }

  // 1,113.0 m circuit traversal
  // 1. Straight cruising: 359.1m
  final straightSec = math.max(20, (359.1 / targetSpeed).round());
  for (var i = 0; i <= straightSec; i++) {
    final s = (i / straightSec) * 359.1;
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(s),
      speed: targetSpeed,
      heading: OsmRouteGenerator.headingAtDistance(s),
      segmentType: 'straight',
      isStationary: false,
      nominalNoiseStd: noiseSigma,
      reportedAccuracy: reportedAcc,
    );
  }

  // 2. 90-degree corner: 40m
  final turnSec = math.max(6, (40.0 / targetSpeed).round());
  for (var i = 1; i <= turnSec; i++) {
    final s = 359.1 + (i / turnSec) * 40.0;
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(s),
      speed: targetSpeed * 0.8,
      heading: OsmRouteGenerator.headingAtDistance(s),
      segmentType: 'turn_90',
      isStationary: false,
      nominalNoiseStd: noiseSigma,
      reportedAccuracy: reportedAcc,
    );
  }

  // 3. Stationary dwell at crosswalk (45s, v=0)
  for (var i = 0; i < 45; i++) {
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(399.1),
      speed: 0.0,
      heading: OsmRouteGenerator.headingAtDistance(399.1),
      segmentType: 'stationary',
      isStationary: true,
      nominalNoiseStd: noiseSigma * 0.8,
      reportedAccuracy: reportedAcc,
    );
  }

  // 4. Urban canyon: 228.0m (with multipath lateral drift 6.0m)
  final canyonSec = math.max(20, (228.0 / targetSpeed).round());
  for (var i = 1; i <= canyonSec; i++) {
    final s = 399.1 + (i / canyonSec) * 228.0;
    final drift = (i >= 5 && i <= 25) ? 6.0 : 0.0;
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(s),
      speed: targetSpeed,
      heading: OsmRouteGenerator.headingAtDistance(s),
      segmentType: 'urban_canyon',
      isStationary: false,
      nominalNoiseStd: noiseSigma * 1.5,
      reportedAccuracy: reportedAcc * 1.2,
      lateralMultipathDrift: drift,
    );
  }

  // 5. Cathedral roundabout curve: 230.0m
  final curveSec = math.max(15, (230.0 / targetSpeed).round());
  for (var i = 1; i <= curveSec; i++) {
    final s = 627.1 + (i / curveSec) * 230.0;
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(s),
      speed: targetSpeed,
      heading: OsmRouteGenerator.headingAtDistance(s),
      segmentType: 'roundabout',
      isStationary: false,
      nominalNoiseStd: noiseSigma,
      reportedAccuracy: reportedAcc,
    );
  }

  // 6. Tree canopy brief outage: 6s
  for (var i = 0; i < 6; i++) {
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(857.1),
      speed: targetSpeed,
      heading: OsmRouteGenerator.headingAtDistance(857.1),
      segmentType: 'outage',
      isStationary: false,
      nominalNoiseStd: 35.0,
      reportedAccuracy: 45.0,
      isOutage: true,
    );
  }

  // 7. Final leg back to origin: 255.9m
  final finalSec = math.max(15, (255.9 / targetSpeed).round());
  for (var i = 1; i <= finalSec; i++) {
    final s = 857.1 + (i / finalSec) * 255.9;
    addPoint(
      point: OsmRouteGenerator.pointAtDistance(s),
      speed: targetSpeed,
      heading: OsmRouteGenerator.headingAtDistance(s),
      segmentType: 'straight',
      isStationary: false,
      nominalNoiseStd: noiseSigma,
      reportedAccuracy: reportedAcc,
    );
  }

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

  return ModalityDataset(
    truth: truth,
    measurements: measurements,
    rawSamples: rawSamples,
    groundTruthDistanceMeters: 1113.0,
  );
}

void main() {
  group('Aetron P02 — Research-Driven AEKF Four-Pipeline Benchmark Suite', () {
    // -------------------------------------------------------------------------
    // HELPER: Replay a pipeline across an athletic modality dataset
    // -------------------------------------------------------------------------
    FourPipelineResult executePipeline({
      required BenchmarkPipelineType type,
      required String activityType,
      required ModalityDataset dataset,
    }) {
      final measurements = dataset.measurements;
      final truth = dataset.truth;
      final rawSamples = dataset.rawSamples;
      final groundTruthLengthM = dataset.groundTruthDistanceMeters;

      final bool isP01 = (type == BenchmarkPipelineType.p01Ekf || type == BenchmarkPipelineType.p01Aekf);
      final bool isAekf = (type == BenchmarkPipelineType.legacyAekf || type == BenchmarkPipelineType.p01Aekf);

      final String pipelineLabel = switch (type) {
        BenchmarkPipelineType.legacyEkf => 'Pipeline A: Legacy + EKF (Standard Core)',
        BenchmarkPipelineType.p01Ekf => 'Pipeline B: P01 + EKF (Standard Core)',
        BenchmarkPipelineType.legacyAekf => 'Pipeline C: Legacy + AEKF (Adaptive Core)',
        BenchmarkPipelineType.p01Aekf => 'Pipeline D: P01 + AEKF (Adaptive Core)',
      };

      final sw = Stopwatch()..start();
      var sqErrorSum = 0.0;
      final errors = <double>[];
      var totalDistM = 0.0;
      var driftM = 0.0;
      var falseRejections = 0;
      final nisValues = <double>[];

      if (isP01) {
        // P01 Trajectory Preprocessor Stack
        final p01Preprocessor = TrajectoryPreprocessor.forActivity(activityType);
        final p01Result = p01Preprocessor.processBatch(rawSamples);

        final ekf = ExtendedKalmanFilter(
          processPosStd: 0.6,
          processSpeedStd: 1.2,
          processHeadingStd: 0.5,
          enableGnssCorrection: isAekf,
          gnssCorrectionEngine: isAekf ? AdaptiveGnssCorrectionEngine() : null,
          activityType: activityType,
        );
        ekf.reset();

        LatLng? stayCentroid;
        for (final s in p01Result.segments) {
          if (s.isStay && s.centroid != null) {
            stayCentroid = s.centroid;
            break;
          }
        }

        LatLng? lastSmoothed;
        DateTime? lastAcceptedTime;

        for (var i = 0; i < p01Result.processedPoints.length; i++) {
          final pt = p01Result.processedPoints[i];
          final m = measurements[i];
          final isGroundTruthOutage = m.isDropped || m.reportedAccuracyMeters > 30.0;

          if (!pt.isAccepted && !isGroundTruthOutage) {
            falseRejections++;
          }

          if (m.isDropped || !pt.isAccepted) {
            continue;
          }

          final timeDeltaSec = lastAcceptedTime == null
              ? 1.0
              : pt.rawSample.timestamp.difference(lastAcceptedTime).inMilliseconds / 1000.0;

          if (pt.isGapRecovery) {
            ekf.reset();
            lastSmoothed = null;
          }

          LatLng smoothed;
          if (pt.isStayPoint) {
            smoothed = stayCentroid ?? pt.point;
          } else {
            final est = ekf.update(
              measurementPoint: pt.point,
              accuracyMeters: pt.accuracyMeters,
              timeDeltaSec: timeDeltaSec,
              speedMs: m.reportedSpeedMs,
              headingDeg: m.reportedHeadingDeg,
              activityType: activityType,
            );
            smoothed = est.position;
            if (est.mahalanobisDistanceSq != null) {
              nisValues.add(est.mahalanobisDistanceSq!);
            }
          }

          final err = _distanceCalc.distance(smoothed, truth[i].position);
          sqErrorSum += err * err;
          errors.add(err);

          if (lastSmoothed != null) {
            final seg = _distanceCalc.distance(lastSmoothed, smoothed);
            totalDistM += seg;
            if (truth[i].isStationary) {
              driftM += seg;
            }
          }
          lastSmoothed = smoothed;
          lastAcceptedTime = pt.rawSample.timestamp;
        }
      } else {
        // Legacy WorkoutTrackingEngine Stack
        const engine = WorkoutTrackingEngine();
        final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
        final pipeline = GpsPipeline();
        final ekf = ExtendedKalmanFilter(
          processPosStd: 0.6,
          processSpeedStd: 1.2,
          processHeadingStd: 0.5,
          enableGnssCorrection: isAekf,
          gnssCorrectionEngine: isAekf ? AdaptiveGnssCorrectionEngine() : null,
          activityType: activityType,
        );
        ekf.reset();

        LatLng? lastSmoothedPoint;
        LatLng? distanceAnchor;
        DateTime? lastAcceptedTime;

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
            activityType: activityType,
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
            falseRejections++;
          }

          if (!isAccepted) continue;

          if (decision.type == TrackingGpsDecisionType.seedRoute) {
            continuity.acknowledgeRouteAnchor();
            distanceAnchor = decision.livePoint;
            lastAcceptedTime = pos.timestamp;
            pipeline.seedRoute(decision.livePoint);
            ekf.init(
              initialPoint: decision.livePoint,
              initialAccuracyMeters: s.accuracyMeters,
              initialSpeedMs: s.sensorSpeedMs ?? 0.0,
              initialHeadingDeg: s.sensorHeadingDeg,
            );
            lastSmoothedPoint = decision.livePoint;
            continue;
          }

          final est = ekf.update(
            measurementPoint: decision.livePoint,
            accuracyMeters: s.accuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: s.sensorSpeedMs,
            headingDeg: s.sensorHeadingDeg,
            activityType: activityType,
          );
          final smoothed = est.position;
          if (est.mahalanobisDistanceSq != null) {
            nisValues.add(est.mahalanobisDistanceSq!);
          }

          final err = _distanceCalc.distance(smoothed, truth[i].position);
          sqErrorSum += err * err;
          errors.add(err);

          if (lastSmoothedPoint != null) {
            final seg = _distanceCalc.distance(lastSmoothedPoint, smoothed);
            totalDistM += seg;
            if (truth[i].isStationary) {
              driftM += seg;
            }
          }
          lastSmoothedPoint = smoothed;
          lastAcceptedTime = s.timestamp;
        }
      }

      sw.stop();
      errors.sort();

      final rmse = math.sqrt(sqErrorSum / math.max(1, errors.length));
      final median = errors.isEmpty ? 0.0 : errors[errors.length ~/ 2];
      final p95 = errors.isEmpty ? 0.0 : errors[(errors.length * 0.95).floor()];
      final maxErr = errors.isEmpty ? 0.0 : errors.last;
      final distErrPct = ((totalDistM - groundTruthLengthM).abs() / groundTruthLengthM) * 100.0;
      final latency = sw.elapsedMicroseconds / math.max(1, rawSamples.length);

      final meanNis = nisValues.isEmpty ? 0.0 : (nisValues.reduce((a, b) => a + b) / nisValues.length);
      final nominalNisCount = nisValues.where((v) => v <= 5.991).length;
      final criticalNisCount = nisValues.where((v) => v > 13.816).length;
      final pctNominal = nisValues.isEmpty ? 0.0 : (nominalNisCount / nisValues.length) * 100.0;
      final pctCritical = nisValues.isEmpty ? 0.0 : (criticalNisCount / nisValues.length) * 100.0;
      final totalValidMotionEpochs = truth.where((t) => !t.isStationary && t.segmentType != 'outage').length;
      final falseRejPct = (falseRejections / math.max(1, totalValidMotionEpochs)) * 100.0;

      return FourPipelineResult(
        type: type,
        pipelineName: pipelineLabel,
        activityType: activityType,
        rmseMeters: rmse,
        medianErrorMeters: median,
        p95Meters: p95,
        maxErrorMeters: maxErr,
        totalDistanceMeters: totalDistM,
        distanceErrorPercent: distErrPct,
        stationaryDriftMeters: driftM,
        falseRejections: falseRejections,
        falseRejectionRatePct: falseRejPct,
        meanNis: meanNis,
        pctNisNominal: pctNominal,
        pctNisCritical: pctCritical,
        latencyUs: latency,
      );
    }

    void printPipelineTable(String title, List<FourPipelineResult> results) {
      print('\n========================================================================================================================');
      print(title);
      print('========================================================================================================================');
      print('| Pipeline Architecture                           | RMSE (m) | Median | P95 (m) | Max Err | Total Dist | Dist Err % | Drift (m) | False Rej | Mean NIS | Latency |');
      print('|:------------------------------------------------|:--------:|:------:|:-------:|:-------:|:----------:|:----------:|:---------:|:---------:|:--------:|:-------:|');
      for (final r in results) {
        final nisStr = r.meanNis > 0.0 ? r.meanNis.toStringAsFixed(2) : 'N/A';
        print('| ${r.pipelineName.padRight(47)} | ${r.rmseMeters.toStringAsFixed(2).padLeft(6)} m | ${r.medianErrorMeters.toStringAsFixed(2).padLeft(4)} m | ${r.p95Meters.toStringAsFixed(1).padLeft(5)} m | ${r.maxErrorMeters.toStringAsFixed(1).padLeft(5)} m | ${r.totalDistanceMeters.toStringAsFixed(1).padLeft(8)} m | ${r.distanceErrorPercent.toStringAsFixed(2).padLeft(8)} % | ${r.stationaryDriftMeters.toStringAsFixed(1).padLeft(7)} m | ${r.falseRejections.toString().padLeft(9)} | ${nisStr.padLeft(8)} | ${r.latencyUs.toStringAsFixed(1).padLeft(5)} µs |');
      }
      print('========================================================================================================================');
    }

    // -------------------------------------------------------------------------
    // TEST 1: WALKING MODALITY FOUR-PIPELINE BENCHMARK
    // -------------------------------------------------------------------------
    test('BENCH-WALK: 4-Pipeline Comparative Replay on OSM Ground-Truth Walking (1.13 km)', () {
      final dataset = generateModalityDataset(activityType: 'walking', seed: 101);
      final results = <FourPipelineResult>[];

      for (final type in BenchmarkPipelineType.values) {
        results.add(executePipeline(type: type, activityType: 'walking', dataset: dataset));
      }

      printPipelineTable('AETRON RESEARCH BENCHMARK: 4 PIPELINES ON WALKING MODALITY (1,113.0 M REFERENCE)', results);

      // Verify all pipelines completed reasonably
      for (final r in results) {
        expect(r.rmseMeters, lessThan(10.0));
        expect(r.totalDistanceMeters, greaterThan(900.0));
      }

      // Legacy + AEKF (Pipeline C) preserves continuous innovation stream
      final legacyAekf = results.firstWhere((r) => r.type == BenchmarkPipelineType.legacyAekf);
      expect(legacyAekf.rmseMeters, lessThan(4.5));
    });

    // -------------------------------------------------------------------------
    // TEST 2: RUNNING MODALITY FOUR-PIPELINE BENCHMARK
    // -------------------------------------------------------------------------
    test('BENCH-RUN: 4-Pipeline Comparative Replay on OSM Ground-Truth Running (1.13 km)', () {
      final dataset = generateModalityDataset(activityType: 'running', seed: 202);
      final results = <FourPipelineResult>[];

      for (final type in BenchmarkPipelineType.values) {
        results.add(executePipeline(type: type, activityType: 'running', dataset: dataset));
      }

      printPipelineTable('AETRON RESEARCH BENCHMARK: 4 PIPELINES ON RUNNING MODALITY (1,113.0 M REFERENCE)', results);

      for (final r in results) {
        expect(r.rmseMeters, lessThan(10.0));
        expect(r.totalDistanceMeters, greaterThan(900.0));
      }

      final legacyAekf = results.firstWhere((r) => r.type == BenchmarkPipelineType.legacyAekf);
      expect(legacyAekf.rmseMeters, lessThan(4.5));
    });

    // -------------------------------------------------------------------------
    // TEST 3: CYCLING MODALITY FOUR-PIPELINE BENCHMARK
    // -------------------------------------------------------------------------
    test('BENCH-CYCLE: 4-Pipeline Comparative Replay on OSM Ground-Truth Cycling (1.13 km)', () {
      final dataset = generateModalityDataset(activityType: 'cycling', seed: 303);
      final results = <FourPipelineResult>[];

      for (final type in BenchmarkPipelineType.values) {
        results.add(executePipeline(type: type, activityType: 'cycling', dataset: dataset));
      }

      printPipelineTable('AETRON RESEARCH BENCHMARK: 4 PIPELINES ON CYCLING MODALITY (1,113.0 M REFERENCE)', results);

      for (final r in results) {
        expect(r.rmseMeters, lessThan(10.0));
        expect(r.totalDistanceMeters, greaterThan(900.0));
      }

      final legacyAekf = results.firstWhere((r) => r.type == BenchmarkPipelineType.legacyAekf);
      expect(legacyAekf.rmseMeters, lessThan(4.5));
    });

    // -------------------------------------------------------------------------
    // TEST 4: AUTHENTIC FIELD DATASET (7 SESSIONS, 595 RAW FIXES IN HCMC)
    // -------------------------------------------------------------------------
    test('BENCH-FIELD: 4-Pipeline Evaluation on Authentic Smartphone Dataset (595 Raw Fixes)', () {
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
      expect(records.length, equals(595));

      final sessionGroups = <String, List<RawCsvRecord>>{};
      for (final r in records) {
        sessionGroups.putIfAbsent(r.workoutId, () => []).add(r);
      }

      print('\n========================================================================================================================');
      print('AETRON RESEARCH BENCHMARK: 4 PIPELINES ON AUTHENTIC SMARTPHONE DATASET (595 FIXES, NO RTK GROUND TRUTH)');
      print('========================================================================================================================');
      print('| Pipeline Architecture                           | Clean Dist (km) | Pause Jitter (m) | Rejections | Mean NIS | Latency |');
      print('|:------------------------------------------------|:---------------:|:----------------:|:----------:|:--------:|:-------:|');

      for (final type in BenchmarkPipelineType.values) {
        final bool isP01 = (type == BenchmarkPipelineType.p01Ekf || type == BenchmarkPipelineType.p01Aekf);
        final bool isAekf = (type == BenchmarkPipelineType.legacyAekf || type == BenchmarkPipelineType.p01Aekf);

        final label = switch (type) {
          BenchmarkPipelineType.legacyEkf => 'Pipeline A: Legacy + EKF (Standard Core)',
          BenchmarkPipelineType.p01Ekf => 'Pipeline B: P01 + EKF (Standard Core)',
          BenchmarkPipelineType.legacyAekf => 'Pipeline C: Legacy + AEKF (Adaptive Core)',
          BenchmarkPipelineType.p01Aekf => 'Pipeline D: P01 + AEKF (Adaptive Core)',
        };

        var totalDistM = 0.0;
        var totalJitterM = 0.0;
        var totalRejections = 0;
        final nisList = <double>[];
        final sw = Stopwatch()..start();

        for (final entry in sessionGroups.entries) {
          final recs = entry.value;
          final samples = recs.asMap().entries.map((e) => e.value.toTrajectorySample(e.key)).toList();

          final ekf = ExtendedKalmanFilter(
            processPosStd: 0.6,
            processSpeedStd: 1.2,
            processHeadingStd: 0.5,
            enableGnssCorrection: isAekf,
            gnssCorrectionEngine: isAekf ? AdaptiveGnssCorrectionEngine() : null,
            activityType: 'cycling',
          );
          ekf.reset();

          if (isP01) {
            final preprocessor = TrajectoryPreprocessor.forActivity('cycling');
            final prepRes = preprocessor.processBatch(samples);

            LatLng? stayCentroid;
            for (final s in prepRes.segments) {
              if (s.isStay && s.centroid != null) {
                stayCentroid = s.centroid;
                break;
              }
            }

            LatLng? lastPt;
            for (var i = 0; i < prepRes.processedPoints.length; i++) {
              final pt = prepRes.processedPoints[i];
              final r = recs[i];

              if (!pt.isAccepted) {
                totalRejections++;
                continue;
              }
              if (pt.isGapRecovery) {
                ekf.reset();
                lastPt = null;
                continue;
              }

              LatLng filtered;
              if (pt.isStayPoint) {
                filtered = stayCentroid ?? pt.point;
              } else {
                final est = ekf.update(
                  measurementPoint: pt.point,
                  accuracyMeters: pt.accuracyMeters,
                  timeDeltaSec: 1.0,
                  speedMs: r.speed,
                  headingDeg: r.heading,
                  activityType: 'cycling',
                );
                filtered = est.position;
                if (est.mahalanobisDistanceSq != null) {
                  nisList.add(est.mahalanobisDistanceSq!);
                }
                if (!est.isMeasurementApplied) {
                  totalRejections++;
                }
              }

              if (lastPt != null) {
                final step = _distanceCalc.distance(lastPt, filtered);
                totalDistM += step;
                if (r.speed < 0.5) {
                  totalJitterM += step;
                }
              }
              lastPt = filtered;
            }
          } else {
            const engine = WorkoutTrackingEngine();
            final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
            final pipeline = GpsPipeline();
            LatLng? lastPt;
            LatLng? distanceAnchor;
            DateTime? lastAcceptedTime;

            for (var i = 0; i < samples.length; i++) {
              final s = samples[i];
              final r = recs[i];
              continuity.observe(s.timestamp);

              final pos = Position(
                latitude: s.point.latitude,
                longitude: s.point.longitude,
                timestamp: s.timestamp,
                altitude: s.altitudeMeters ?? 10.0,
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

              if (!isAccepted) {
                totalRejections++;
                continue;
              }

              if (decision.type == TrackingGpsDecisionType.seedRoute) {
                continuity.acknowledgeRouteAnchor();
                distanceAnchor = decision.livePoint;
                lastAcceptedTime = pos.timestamp;
                pipeline.seedRoute(decision.livePoint);
                ekf.init(
                  initialPoint: decision.livePoint,
                  initialAccuracyMeters: s.accuracyMeters,
                  initialSpeedMs: s.sensorSpeedMs ?? 0.0,
                  initialHeadingDeg: s.sensorHeadingDeg,
                );
                lastPt = decision.livePoint;
                continue;
              }

              final est = ekf.update(
                measurementPoint: decision.livePoint,
                accuracyMeters: s.accuracyMeters,
                timeDeltaSec: 1.0,
                speedMs: s.sensorSpeedMs,
                headingDeg: s.sensorHeadingDeg,
                activityType: 'cycling',
              );
              final filtered = est.position;
              if (est.mahalanobisDistanceSq != null) {
                nisList.add(est.mahalanobisDistanceSq!);
              }
              if (!est.isMeasurementApplied) {
                totalRejections++;
              }

              if (lastPt != null) {
                final step = _distanceCalc.distance(lastPt, filtered);
                totalDistM += step;
                if (r.speed < 0.5) {
                  totalJitterM += step;
                }
              }
              lastPt = filtered;
              lastAcceptedTime = s.timestamp;
            }
          }
        }

        sw.stop();
        final meanNis = nisList.isEmpty ? 0.0 : (nisList.reduce((a, b) => a + b) / nisList.length);
        final nisStr = meanNis > 0.0 ? meanNis.toStringAsFixed(2) : 'N/A';
        final latency = sw.elapsedMicroseconds / records.length;

        print('| ${label.padRight(47)} | ${(totalDistM / 1000.0).toStringAsFixed(3).padLeft(12)} km | ${totalJitterM.toStringAsFixed(1).padLeft(14)} m | ${totalRejections.toString().padLeft(10)} | ${nisStr.padLeft(8)} | ${latency.toStringAsFixed(1).padLeft(5)} µs |');
        expect(totalDistM, greaterThan(3500.0));
      }
      print('========================================================================================================================\n');
    }, tags: 'external-data');

    // -------------------------------------------------------------------------
    // TEST 5: STATIC GEODETIC MONUMENT BENCHMARK (0.0 M GROUND TRUTH)
    // -------------------------------------------------------------------------
    test('BENCH-STATIC: 4-Pipeline Evaluation on Static Geodetic Monument (600s x 3 Conditions)', () {
      const geodeticTruth = LatLng(48.6011925, 19.1416842);
      const epochs = 600;
      final rng = math.Random(20261108);

      print('\n========================================================================================================================');
      print('AETRON RESEARCH BENCHMARK: 4 PIPELINES ON STATIC GEODETIC MONUMENT (0.0 M TRUE GROUND TRUTH)');
      print('========================================================================================================================');
      print('| Condition        | Legacy + EKF Wander | P01 + EKF Wander | Legacy + AEKF Wander | P01 + AEKF Wander | Ground Truth |');
      print('|:-----------------|:-------------------:|:----------------:|:--------------------:|:-----------------:|:------------:|');

      for (final condition in ['Open Sky', 'Tree Canopy', 'Indoor Multipath']) {
        final double sigma;
        final double reportedAcc;
        final double spikeProb;

        switch (condition) {
          case 'Open Sky':
            sigma = 1.12;
            reportedAcc = 2.8;
            spikeProb = 0.01;
            break;
          case 'Tree Canopy':
            sigma = 3.85;
            reportedAcc = 6.5;
            spikeProb = 0.08;
            break;
          case 'Indoor Multipath':
          default:
            sigma = 12.40;
            reportedAcc = 18.0;
            spikeProb = 0.25;
            break;
        }

        final samples = <TrajectoryRawSample>[];
        final t0 = DateTime(2026, 3, 4, 10, 0, 0);

        for (var i = 0; i < epochs; i++) {
          final isSpike = rng.nextDouble() < spikeProb;
          final s = isSpike ? sigma * 3.5 : sigma;

          final u1 = math.max(1e-10, rng.nextDouble());
          final u2 = rng.nextDouble();
          final g1 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
          final g2 = math.sqrt(-2.0 * math.log(u1)) * math.sin(2.0 * math.pi * u2);

          const mPerDegLat = 111132.92;
          final mPerDegLon = 111412.84 * math.cos(geodeticTruth.latitude * math.pi / 180.0);

          final jLat = geodeticTruth.latitude + (g1 * s) / mPerDegLat;
          final jLon = geodeticTruth.longitude + (g2 * s) / mPerDegLon;

          samples.add(TrajectoryRawSample(
            index: i,
            timestamp: t0.add(Duration(seconds: i)),
            point: LatLng(jLat, jLon),
            accuracyMeters: isSpike ? reportedAcc * 2.2 : reportedAcc,
            sensorSpeedMs: 0.0,
            sensorHeadingDeg: 0.0,
          ));
        }

        double evaluateWander(BenchmarkPipelineType type) {
          final isP01 = (type == BenchmarkPipelineType.p01Ekf || type == BenchmarkPipelineType.p01Aekf);
          final isAekf = (type == BenchmarkPipelineType.legacyAekf || type == BenchmarkPipelineType.p01Aekf);

          var wanderDistM = 0.0;
          final ekf = ExtendedKalmanFilter(
            processPosStd: 0.6,
            processSpeedStd: 1.2,
            processHeadingStd: 0.5,
            enableGnssCorrection: isAekf,
            gnssCorrectionEngine: isAekf ? AdaptiveGnssCorrectionEngine() : null,
            activityType: 'walking',
          );
          ekf.reset();

          if (isP01) {
            final preprocessor = TrajectoryPreprocessor.forActivity('walking');
            final res = preprocessor.processBatch(samples);
            LatLng? stayCentroid;
            for (final s in res.segments) {
              if (s.isStay && s.centroid != null) {
                stayCentroid = s.centroid;
                break;
              }
            }

            LatLng? lastPt;
            for (var i = 0; i < res.processedPoints.length; i++) {
              final pt = res.processedPoints[i];
              if (!pt.isAccepted) continue;
              LatLng filtered;
              if (pt.isStayPoint) {
                filtered = stayCentroid ?? pt.point;
              } else {
                final est = ekf.update(
                  measurementPoint: pt.point,
                  accuracyMeters: pt.accuracyMeters,
                  timeDeltaSec: 1.0,
                  speedMs: 0.0,
                  activityType: 'walking',
                );
                filtered = est.position;
              }
              if (lastPt != null && !pt.isStayPoint) {
                wanderDistM += _distanceCalc.distance(lastPt, filtered);
              }
              lastPt = filtered;
            }
          } else {
            const engine = WorkoutTrackingEngine();
            final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
            final pipeline = GpsPipeline();
            LatLng? lastPt;
            LatLng? distanceAnchor;
            DateTime? lastAcceptedTime;

            for (var i = 0; i < samples.length; i++) {
              final s = samples[i];
              continuity.observe(s.timestamp);

              final pos = Position(
                latitude: s.point.latitude,
                longitude: s.point.longitude,
                timestamp: s.timestamp,
                altitude: 10.0,
                accuracy: s.accuracyMeters,
                heading: 0.0,
                speed: 0.0,
                speedAccuracy: 0.5,
                altitudeAccuracy: 1.0,
                headingAccuracy: 1.0,
              );

              final decision = engine.evaluateGpsUpdate(
                position: pos,
                activityType: 'walking',
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

              if (!isAccepted) continue;

              if (decision.type == TrackingGpsDecisionType.seedRoute) {
                continuity.acknowledgeRouteAnchor();
                distanceAnchor = decision.livePoint;
                lastAcceptedTime = pos.timestamp;
                pipeline.seedRoute(decision.livePoint);
                ekf.init(
                  initialPoint: decision.livePoint,
                  initialAccuracyMeters: s.accuracyMeters,
                  initialSpeedMs: 0.0,
                );
                lastPt = decision.livePoint;
                continue;
              }

              final est = ekf.update(
                measurementPoint: decision.livePoint,
                accuracyMeters: s.accuracyMeters,
                timeDeltaSec: 1.0,
                speedMs: 0.0,
                activityType: 'walking',
              );
              final filtered = est.position;
              if (lastPt != null) {
                wanderDistM += _distanceCalc.distance(lastPt, filtered);
              }
              lastPt = filtered;
              lastAcceptedTime = s.timestamp;
            }
          }
          return wanderDistM;
        }

        final wanderLegacyEkf = evaluateWander(BenchmarkPipelineType.legacyEkf);
        final wanderP01Ekf = evaluateWander(BenchmarkPipelineType.p01Ekf);
        final wanderLegacyAekf = evaluateWander(BenchmarkPipelineType.legacyAekf);
        final wanderP01Aekf = evaluateWander(BenchmarkPipelineType.p01Aekf);

        print('| ${condition.padRight(16)} | ${'${wanderLegacyEkf.toStringAsFixed(1)} m'.padLeft(19)} | ${'${wanderP01Ekf.toStringAsFixed(1)} m'.padLeft(16)} | ${'${wanderLegacyAekf.toStringAsFixed(1)} m'.padLeft(20)} | ${'${wanderP01Aekf.toStringAsFixed(1)} m'.padLeft(17)} |         0.0 m |');
      }
      print('========================================================================================================================\n');
    });

    // -------------------------------------------------------------------------
    // TEST 6: NON-INTERFERENCE & REDUNDANT REJECTION AUDIT
    // -------------------------------------------------------------------------
    test('AUDIT: Verify P01 and AEKF do not redundantly hard-reject or over-downweight', () {
      final preprocessor = TrajectoryPreprocessor.forActivity('cycling');

      final aekf = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );
      aekf.init(initialPoint: const LatLng(10.7769, 106.7009));

      // Case 1: Valid sharp turn (turn rate 25 deg/s)
      // P01 should accept (heading difference below reversal limit)
      // AEKF should adapt Q_theta (turn-rate noise scaling) without hard-rejecting!
      final t0 = DateTime.utc(2026, 11, 8, 10, 0, 0);
      final turnSamples = [
        TrajectoryRawSample(
          index: 0,
          timestamp: t0,
          point: const LatLng(10.7769, 106.7009),
          accuracyMeters: 4.0,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ),
        TrajectoryRawSample(
          index: 1,
          timestamp: t0.add(const Duration(seconds: 1)),
          point: const LatLng(10.776945, 106.7009),
          accuracyMeters: 4.0,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 25.0,
        ),
      ];

      final p01TurnRes = preprocessor.processBatch(turnSamples);
      expect(p01TurnRes.processedPoints[1].isAccepted, isTrue, reason: 'P01 must not reject valid turn');

      final aekfTurnEst = aekf.update(
        measurementPoint: turnSamples[1].point,
        accuracyMeters: turnSamples[1].accuracyMeters,
        timeDeltaSec: 1.0,
        speedMs: turnSamples[1].sensorSpeedMs,
        headingDeg: turnSamples[1].sensorHeadingDeg,
        activityType: 'cycling',
      );
      expect(aekfTurnEst.isMeasurementApplied, isTrue, reason: 'AEKF must accept valid turn with Q adaptation');
      expect(aekfTurnEst.correctionQuality, equals(GnssCorrectionQuality.turnAdapted));

      // Case 2: Production flags compile-time check
      expect(kEnableGnssCorrection, isTrue, reason: 'FLOWFIT_ENABLE_GNSS_CORRECTION must default to true');
      expect(kEnableGnssCorrectionShadowMode, isFalse, reason: 'FLOWFIT_GNSS_CORRECTION_SHADOW must default to false');
      expect(kEnableTrajectoryPreprocessing, isTrue, reason: 'FLOWFIT_ENABLE_TRAJECTORY_PREPROCESSING must default to true');
    });
  });
}
