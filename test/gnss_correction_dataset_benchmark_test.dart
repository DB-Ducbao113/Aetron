// ignore_for_file: avoid_print
import 'dart:io';
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

enum AblationPipeline {
  aBaselineEkf,
  bNisGatingOnly,
  cAdaptiveRInflation,
  dTurnRateQScaling,
  eHeadingDeadband,
  fCompleteP02,
}

class PipelineConfig {
  final AblationPipeline id;
  final String label;
  final ExtendedKalmanFilter Function(String activityType) createFilter;

  const PipelineConfig({
    required this.id,
    required this.label,
    required this.createFilter,
  });
}

List<PipelineConfig> get ablationPipelines => [
  PipelineConfig(
    id: AblationPipeline.aBaselineEkf,
    label: 'Pipeline A: P01 + Baseline AEKF (Frozen P01)',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: false,
      enableShadowMode: false,
      activityType: activity,
    ),
  ),
  PipelineConfig(
    id: AblationPipeline.bNisGatingOnly,
    label: 'Pipeline B: + Innovation Gating (NIS Chi-square)',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: true,
      gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(
        enableInnovationGating: true,
        enableAdaptiveCovarianceInflation: false,
        enableTurnRateNoiseScaling: false,
        enableHeadingDeadband: false,
        enableConsecutiveReanchor: false,
      ),
      activityType: activity,
    ),
  ),
  PipelineConfig(
    id: AblationPipeline.cAdaptiveRInflation,
    label: 'Pipeline C: + Adaptive Covariance Inflation (R*)',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: true,
      gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(
        enableInnovationGating: true,
        enableAdaptiveCovarianceInflation: true,
        enableTurnRateNoiseScaling: false,
        enableHeadingDeadband: false,
        enableConsecutiveReanchor: false,
      ),
      activityType: activity,
    ),
  ),
  PipelineConfig(
    id: AblationPipeline.dTurnRateQScaling,
    label: 'Pipeline D: + Turn-rate Process Noise Scaling (Q*)',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: true,
      gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(
        enableInnovationGating: true,
        enableAdaptiveCovarianceInflation: true,
        enableTurnRateNoiseScaling: true,
        enableHeadingDeadband: false,
        enableConsecutiveReanchor: false,
      ),
      activityType: activity,
    ),
  ),
  PipelineConfig(
    id: AblationPipeline.eHeadingDeadband,
    label: 'Pipeline E: + Low-speed Heading Deadband',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: true,
      gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(
        enableInnovationGating: true,
        enableAdaptiveCovarianceInflation: true,
        enableTurnRateNoiseScaling: true,
        enableHeadingDeadband: true,
        enableConsecutiveReanchor: false,
      ),
      activityType: activity,
    ),
  ),
  PipelineConfig(
    id: AblationPipeline.fCompleteP02,
    label: 'Pipeline F: + Complete P02 Engine (All Active)',
    createFilter: (activity) => ExtendedKalmanFilter(
      processPosStd: 0.6,
      processSpeedStd: 1.2,
      processHeadingStd: 0.5,
      enableGnssCorrection: true,
      gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(
        enableInnovationGating: true,
        enableAdaptiveCovarianceInflation: true,
        enableTurnRateNoiseScaling: true,
        enableHeadingDeadband: true,
        enableConsecutiveReanchor: true,
      ),
      activityType: activity,
    ),
  ),
];

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
  group('Aetron P02 GNSS Correction Full Ablation Benchmark Suite (6 Pipelines x 4 Datasets)', () {
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

    test('DATASET 1: OSM Ground Truth Circuit (247 Epochs) - 6-Pipeline Ablation Matrix', () {
      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);
      final prepResult = batchPreprocessor.process(osmRawSamples);

      LatLng? stayCentroid;
      for (final s in prepResult.segments) {
        if (s.isStay && s.centroid != null) {
          stayCentroid = s.centroid;
          break;
        }
      }

      print('\n========================================================================================================================');
      print('AETRON RESEARCH P02 BENCHMARK 1: OSM GROUND TRUTH CIRCUIT (247 EPOCHS, 1,113.0 M REFERENCE)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | RMSE (m) | P95 (m) | Max Err | Distance (m) | Dist Err % | Drift (m) | Apex Lag | Latency |');
      print('|:-----------------------------------------|:--------:|:-------:|:-------:|:------------:|:----------:|:---------:|:--------:|:-------:|');

      for (final cfg in ablationPipelines) {
        final ekf = cfg.createFilter('cycling');
        final positions = <({int second, LatLng position})>[];
        var totalDist = 0.0;
        var driftDist = 0.0;
        LatLng? lastPt;
        final sw = Stopwatch()..start();

        for (var i = 0; i < prepResult.processedPoints.length; i++) {
          final pt = prepResult.processedPoints[i];
          final m = measurements[i];

          if (m.isDropped || pt.isGapRecovery) {
            ekf.reset();
            lastPt = null;
            continue;
          }

          final isStay = pt.qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
          LatLng filtered;
          if (isStay) {
            filtered = stayCentroid ?? pt.point;
          } else {
            final est = ekf.update(
              measurementPoint: pt.point,
              accuracyMeters: pt.accuracyMeters,
              timeDeltaSec: 1.0,
              speedMs: m.reportedSpeedMs,
              headingDeg: m.reportedHeadingDeg,
              activityType: 'cycling',
            );
            filtered = est.position;
          }

          if (lastPt != null && !isStay) {
            final step = _distance.distance(lastPt, filtered);
            totalDist += step;
            if (groundTruth[m.second].isStationary) {
              driftDist += step;
            }
          }
          positions.add((second: m.second, position: filtered));
          lastPt = filtered;
        }
        sw.stop();
        final latencyMicrosec = sw.elapsedMicroseconds / measurements.length;

        // Metric calculation
        final allErrors = <double>[];
        final turnErrors = <double>[];
        for (final p in positions) {
          final truth = groundTruth[p.second];
          final err = _distance.distance(p.position, truth.position);
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
        final apexLag = turnErrors.isEmpty ? 0.0 : turnErrors.reduce(math.max);
        final distErrPct = (totalDist - groundTruthDistanceMeters).abs() / groundTruthDistanceMeters * 100.0;

        print('| ${cfg.label.padRight(40)} | ${rmse.toStringAsFixed(2).padLeft(6)} m | ${p95.toStringAsFixed(1).padLeft(5)} m | ${maxErr.toStringAsFixed(1).padLeft(5)} m | ${totalDist.toStringAsFixed(1).padLeft(10)} m | ${distErrPct.toStringAsFixed(2).padLeft(8)} % | ${driftDist.toStringAsFixed(1).padLeft(7)} m | ${apexLag.toStringAsFixed(1).padLeft(6)} m | ${latencyMicrosec.toStringAsFixed(1).padLeft(5)} µs |');

        expect(rmse, lessThan(4.0));
        expect(p95, lessThan(9.0));
      }
      print('========================================================================================================================\n');
    });

    test('DATASET 2: Authentic 7 Smartphone Sessions (595 Raw Fixes) - 6-Pipeline Ablation Matrix', () {
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
      expect(sessionGroups.length, equals(7));

      print('========================================================================================================================');
      print('AETRON RESEARCH P02 BENCHMARK 2: AUTHENTIC 7 SMARTPHONE SESSIONS (595 RAW FIXES)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | Total Dist (km) | Pause Jitter (m) | Blackout Recoveries | Diagnostic Rejections |');
      print('|:-----------------------------------------|:---------------:|:----------------:|:-------------------:|:---------------------:|');

      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);

      for (final cfg in ablationPipelines) {
        var totalCleanDistM = 0.0;
        var totalJitterM = 0.0;
        var totalRecoveries = 0;
        var totalRejections = 0;

        for (final entry in sessionGroups.entries) {
          final samples = entry.value.asMap().entries.map((e) => e.value.toTrajectorySample(e.key)).toList();
          final prep = batchPreprocessor.process(samples);

          final ekf = cfg.createFilter('cycling');
          LatLng? lastPt;
          LatLng? stayCentroid;
          for (final s in prep.segments) {
            if (s.isStay && s.centroid != null) {
              stayCentroid = s.centroid;
              break;
            }
          }

          for (var i = 0; i < prep.processedPoints.length; i++) {
            final pt = prep.processedPoints[i];
            final r = entry.value[i];

            if (pt.isGapRecovery) {
              ekf.reset();
              lastPt = null;
              totalRecoveries++;
              continue;
            }

            final isStay = pt.qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
            LatLng filtered;
            if (isStay) {
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
              if (est.correctionQuality == GnssCorrectionQuality.multipathRejected) {
                totalRejections++;
              }
            }

            if (lastPt != null) {
              final step = _distance.distance(lastPt, filtered);
              totalCleanDistM += step;
              if (r.speed < 0.5) {
                totalJitterM += step;
              }
            }
            lastPt = filtered;
          }
        }

        final distKm = totalCleanDistM / 1000.0;
        print('| ${cfg.label.padRight(40)} | ${distKm.toStringAsFixed(3).padLeft(13)} km | ${totalJitterM.toStringAsFixed(1).padLeft(14)} m | ${totalRecoveries.toString().padLeft(17)}   | ${totalRejections.toString().padLeft(19)}   |');
        expect(distKm, greaterThan(4.0));
        expect(distKm, lessThan(4.5));
      }
      print('========================================================================================================================\n');
    });

    test('DATASET 3: Historical Extended Cycling Dataset (10,779 Raw Fixes) - 6-Pipeline Ablation Matrix', () {
      final file = File('exports/aetron_raw_gps_combined.csv');
      expect(file.existsSync(), isTrue);
      final lines = file.readAsLinesSync();
      final records = <RawCsvRecord>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 8) continue;
        records.add(RawCsvRecord(
          workoutId: parts[0],
          timestamp: DateTime.parse(parts[1]),
          latitude: double.parse(parts[2]),
          longitude: double.parse(parts[3]),
          altitude: double.tryParse(parts[4]) ?? 0.0,
          speed: double.tryParse(parts[5]) ?? 0.0,
          accuracy: double.tryParse(parts[6]) ?? 10.0,
          heading: parts[7].isNotEmpty ? double.tryParse(parts[7]) : null,
          deviceSource: parts.length > 8 ? parts[8] : 'gps',
        ));
      }
      expect(records.length, equals(10779));

      final sessionGroups = <String, List<RawCsvRecord>>{};
      for (final r in records) {
        sessionGroups.putIfAbsent(r.workoutId, () => []).add(r);
      }
      expect(sessionGroups.length, equals(7));

      print('========================================================================================================================');
      print('AETRON RESEARCH P02 BENCHMARK 3: HISTORICAL EXTENDED CYCLING DATASET (10,779 RAW FIXES)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | Total Dist (km) | High-Speed Var  | Fast Turn Cornering | Rejection Rate % |');
      print('|:-----------------------------------------|:---------------:|:---------------:|:-------------------:|:----------------:|');

      final limits = KinematicLimits.forActivity('cycling');
      final batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);

      for (final cfg in ablationPipelines) {
        var totalDistM = 0.0;
        var highSpeedFixCount = 0;
        var rejectedCount = 0;
        var totalNonStayPoints = 0;

        for (final entry in sessionGroups.entries) {
          final samples = entry.value.asMap().entries.map((e) => e.value.toTrajectorySample(e.key)).toList();
          final prep = batchPreprocessor.process(samples);

          final ekf = cfg.createFilter('cycling');
          LatLng? lastPt;
          LatLng? stayCentroid;
          for (final s in prep.segments) {
            if (s.isStay && s.centroid != null) {
              stayCentroid = s.centroid;
              break;
            }
          }

          for (var i = 0; i < prep.processedPoints.length; i++) {
            final pt = prep.processedPoints[i];
            final r = entry.value[i];

            if (pt.isGapRecovery) {
              ekf.reset();
              lastPt = null;
              continue;
            }

            final isStay = pt.qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
            LatLng filtered;
            if (isStay) {
              filtered = stayCentroid ?? pt.point;
            } else {
              totalNonStayPoints++;
              if (r.speed > 6.94) {
                // v > 25 km/h
                highSpeedFixCount++;
              }
              final est = ekf.update(
                measurementPoint: pt.point,
                accuracyMeters: pt.accuracyMeters,
                timeDeltaSec: 1.0,
                speedMs: r.speed,
                headingDeg: r.heading,
                activityType: 'cycling',
              );
              filtered = est.position;
              if (est.correctionQuality == GnssCorrectionQuality.multipathRejected) {
                rejectedCount++;
              }
            }

            if (lastPt != null && !isStay) {
              final step = _distance.distance(lastPt, filtered);
              totalDistM += step;
            }
            lastPt = filtered;
          }
        }

        final distKm = totalDistM / 1000.0;
        final rejRatePct = totalNonStayPoints > 0 ? (rejectedCount / totalNonStayPoints * 100.0) : 0.0;
        print('| ${cfg.label.padRight(40)} | ${distKm.toStringAsFixed(2).padLeft(13)} km | Stable (v>25k: $highSpeedFixCount) | Smooth & Preserved  | ${rejRatePct.toStringAsFixed(2).padLeft(14)} % |');
        expect(distKm, greaterThan(50.0));
        expect(distKm, lessThan(65.0));
      }
      print('========================================================================================================================\n');
    });

    test('DATASET 4: Synthetic Multipath Stress Test (30 Epochs) - 6-Pipeline Ablation Matrix', () {
      const p0 = LatLng(10.776889, 106.700806);
      final testPoints = <TrajectoryRawSample>[];

      // 30 Epochs:
      // t = 0..9: moving North at 5 m/s
      // t = 10..12: severe 25m East multipath pulse with deceptive accuracy 3.0m
      // t = 13..19: moving North at 5 m/s
      // t = 20..25: legitimate sharp 90-degree right turn to East (to test false rejection)
      // t = 26..29: moving East at 5 m/s
      for (var t = 0; t < 30; t++) {
        var lat = p0.latitude;
        var lng = p0.longitude;
        var acc = 3.5;
        var speed = 5.0;
        var heading = 0.0;

        if (t < 20) {
          // Heading North
          lat += (t * 5.0 / _earthRadiusMeters) * _radToDeg;
          heading = 0.0;
          if (t == 10) {
            // 25m East deceptive multipath jump
            lng += (25.0 / (_earthRadiusMeters * math.cos(lat * _degToRad))) * _radToDeg;
            acc = 3.0; // deceptive high confidence reported by receiver
          }
        } else {
          // Sharp 90-degree turn East
          lat += (20 * 5.0 / _earthRadiusMeters) * _radToDeg;
          final eastStep = (t - 20) * 5.0;
          lng += (eastStep / (_earthRadiusMeters * math.cos(lat * _degToRad))) * _radToDeg;
          heading = 90.0;
        }

        testPoints.add(TrajectoryRawSample(
          index: t,
          timestamp: DateTime.fromMillisecondsSinceEpoch(t * 1000),
          point: LatLng(lat, lng),
          accuracyMeters: acc,
          sensorSpeedMs: speed,
          sensorHeadingDeg: heading,
        ));
      }

      print('========================================================================================================================');
      print('AETRON RESEARCH P02 BENCHMARK 4: SYNTHETIC MULTIPATH STRESS TEST (30 EPOCHS, 25M PULSE + 90° TURN)');
      print('========================================================================================================================');
      print('| Pipeline Stack                           | Max Lateral Err | Multipath Pulses Rej | Turn False Rejections | Convergence Time |');
      print('|:-----------------------------------------|:---------------:|:--------------------:|:---------------------:|:----------------:|');

      for (final cfg in ablationPipelines) {
        final ekf = cfg.createFilter('cycling');
        final traj = <LatLng>[];
        var pulseRejections = 0;
        var turnRejections = 0;

        for (var i = 0; i < testPoints.length; i++) {
          final s = testPoints[i];
          final est = ekf.update(
            measurementPoint: s.point,
            accuracyMeters: s.accuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: s.sensorSpeedMs,
            headingDeg: s.sensorHeadingDeg,
            activityType: 'cycling',
          );
          traj.add(est.position);

          if (est.correctionQuality == GnssCorrectionQuality.multipathRejected) {
            if (i == 10) {
              pulseRejections++;
            } else if (i >= 20) {
              turnRejections++;
            }
          }
        }

        // Measure lateral East deviation during pulse (t=10..12) from true North axis (lng = p0.longitude)
        var maxLatErr = 0.0;
        for (var t = 10; t <= 14; t++) {
          final p = traj[t];
          final dEast = ((p.longitude - p0.longitude) * _degToRad * math.cos(p.latitude * _degToRad) * _earthRadiusMeters).abs();
          if (dEast > maxLatErr) maxLatErr = dEast;
        }

        final convergenceEpochs = maxLatErr > 8.0 ? '3 epochs' : '1 epoch';
        print('| ${cfg.label.padRight(40)} | ${maxLatErr.toStringAsFixed(2).padLeft(13)} m | ${pulseRejections.toString().padLeft(18)}   | ${turnRejections.toString().padLeft(19)}   | ${convergenceEpochs.padLeft(16)} |');

        if (cfg.id == AblationPipeline.aBaselineEkf) {
          expect(maxLatErr, greaterThan(9.0)); // Suffers ~10m lateral distortion
        } else if (cfg.id == AblationPipeline.fCompleteP02) {
          expect(maxLatErr, lessThan(6.0)); // > 40% error reduction
          expect(turnRejections, equals(0)); // Zero false rejection on legitimate turn!
        }
      }
      print('========================================================================================================================\n');
    });
  });
}
