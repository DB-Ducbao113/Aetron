import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'trajectory_sample.dart';

/// Historical Aetron three-stage preprocessing candidate, inspired by the
/// non-map-matching noise-reduction problem described by:
/// Kiki Adhinugraha, Wenny Rahayu, Takahiro Hara, and David Taniar (2021).
/// "Dealing with noise in crowdsourced GPS human trajectory logging data."
/// Concurrency and Computation: Practice and Experience (Wiley), 33(19), e6139.
/// DOI: 10.1002/cpe.6139.
///
/// The cited paper uses convex-hull based spike reduction and granularity
/// reduction. This speed/heading/median-MAD candidate does NOT reproduce
/// those stages. The class name is retained for historical benchmark API parity.
class AdhinugrahaTrajectoryFilter {
  final KinematicLimits limits;
  static const Distance _distance = Distance();

  const AdhinugrahaTrajectoryFilter({required this.limits});

  /// Factory for sport-specific kinematic parameters.
  factory AdhinugrahaTrajectoryFilter.forActivity(String activityType) {
    return AdhinugrahaTrajectoryFilter(
      limits: KinematicLimits.forActivity(activityType),
    );
  }

  /// Processes a complete trajectory sequence using the historical Aetron three-stage candidate.
  List<ProcessedTrajectoryPoint> process(List<TrajectoryRawSample> rawSamples) {
    if (rawSamples.isEmpty) return const [];

    // Stage 1: Point-level filtering (Speed & temporal gap verification)
    final stage1 = _evaluateStage1PointAnomalies(rawSamples);

    // Stage 2: Track-level acute detour spike filtering
    final stage2 = _evaluateStage2DetourAnomalies(stage1);

    // Stage 3: Density-Adaptive sliding-window median/MAD spatial smoothing
    final stage3 = _applyStage3AdaptiveMedianFilter(stage2);

    return stage3;
  }

  /// Stage 1: Point Anomaly Detection based on physical speed limits and outage gaps.
  List<ProcessedTrajectoryPoint> _evaluateStage1PointAnomalies(
    List<TrajectoryRawSample> samples,
  ) {
    final result = <ProcessedTrajectoryPoint>[];
    ProcessedTrajectoryPoint? lastAccepted;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final flags = <TrajectoryQualityFlag>{};

      if (sample.accuracyMeters > limits.maxAccuracyMeters) {
        flags.add(TrajectoryQualityFlag.lowAccuracy);
      }

      if (lastAccepted == null) {
        if (flags.isEmpty) flags.add(TrajectoryQualityFlag.clean);
        final pt = ProcessedTrajectoryPoint(
          rawSample: sample,
          qualityFlags: flags,
          segmentDistanceMeters: 0.0,
          timeDeltaSec: 0.0,
          impliedSpeedMs: sample.sensorSpeedMs ?? 0.0,
          impliedAccelerationMs2: 0.0,
          forwardBearingDeg: sample.sensorHeadingDeg,
          isAccepted: !flags.contains(TrajectoryQualityFlag.lowAccuracy),
          isGapRecovery: false,
        );
        result.add(pt);
        if (pt.isAccepted) lastAccepted = pt;
        continue;
      }

      final dtSec = sample.timestamp
              .difference(lastAccepted.timestamp)
              .inMilliseconds /
          1000.0;
      final isOutageGap = dtSec > limits.outageGapThresholdSeconds;

      if (isOutageGap) {
        flags.add(TrajectoryQualityFlag.signalGap);
      }

      final distM = _distance.distance(lastAccepted.point, sample.point);
      final bearingDeg = distM > 0.1
          ? _distance.bearing(lastAccepted.point, sample.point)
          : lastAccepted.forwardBearingDeg;

      var impliedSpeedMs = sample.sensorSpeedMs ?? 0.0;
      if (!isOutageGap && dtSec > 0.05) {
        impliedSpeedMs = distM / dtSec;
        if (impliedSpeedMs > limits.maxSpeedMs) {
          flags.add(TrajectoryQualityFlag.speedSpike);
        }
      }

      final isAccepted = !flags.contains(TrajectoryQualityFlag.lowAccuracy) &&
          !flags.contains(TrajectoryQualityFlag.speedSpike);

      if (flags.isEmpty) flags.add(TrajectoryQualityFlag.clean);

      final pt = ProcessedTrajectoryPoint(
        rawSample: sample,
        qualityFlags: flags,
        segmentDistanceMeters: distM,
        timeDeltaSec: dtSec,
        impliedSpeedMs: impliedSpeedMs,
        impliedAccelerationMs2: 0.0,
        forwardBearingDeg: bearingDeg,
        isAccepted: isAccepted,
        isGapRecovery: isOutageGap && isAccepted,
      );

      result.add(pt);
      if (isAccepted) {
        lastAccepted = pt;
      }
    }

    return result;
  }

  /// Stage 2: Track Anomaly Detection based on acute directional deflection.
  ///
  /// Evaluates consecutive triplets (p_{i-2}, p_{i-1}, p_i).
  /// If heading reversal > 135 deg and chord ratio > 2.0, p_{i-1} is marked as detour spike.
  List<ProcessedTrajectoryPoint> _evaluateStage2DetourAnomalies(
    List<ProcessedTrajectoryPoint> points,
  ) {
    if (points.length < 3) return points;

    final result = List<ProcessedTrajectoryPoint>.from(points);

    for (var i = 1; i < points.length - 1; i++) {
      final prev = result[i - 1];
      final curr = result[i];
      final next = result[i + 1];

      if (!prev.isAccepted || !curr.isAccepted || !next.isAccepted) continue;
      if (curr.isGapRecovery || next.isGapRecovery) continue;

      final b1 = _distance.bearing(prev.point, curr.point);
      final b2 = _distance.bearing(curr.point, next.point);
      final headingDeflection = _angularDiff(b1, b2);

      final d1 = _distance.distance(prev.point, curr.point);
      final d2 = _distance.distance(curr.point, next.point);
      final dChord = _distance.distance(prev.point, next.point);

      final pathSum = d1 + d2;
      final chordRatio = dChord > 0.5 ? pathSum / dChord : pathSum / 0.5;

      // Aetron candidate acute detour criteria: deflection >= 135 deg & path overshoot
      if (headingDeflection >= 135.0 && chordRatio > 2.0 && pathSum > 8.0) {
        final updatedFlags = Set<TrajectoryQualityFlag>.from(curr.qualityFlags)
          ..add(TrajectoryQualityFlag.headingSpike)
          ..remove(TrajectoryQualityFlag.clean);

        result[i] = ProcessedTrajectoryPoint(
          rawSample: curr.rawSample,
          qualityFlags: updatedFlags,
          segmentDistanceMeters: curr.segmentDistanceMeters,
          timeDeltaSec: curr.timeDeltaSec,
          impliedSpeedMs: curr.impliedSpeedMs,
          impliedAccelerationMs2: curr.impliedAccelerationMs2,
          forwardBearingDeg: curr.forwardBearingDeg,
          isAccepted: false, // Rejected by track-level detour rule
          isGapRecovery: curr.isGapRecovery,
        );
      }
    }

    return result;
  }

  /// Stage 3: Density-Adaptive Sliding-Window Median/MAD Filter.
  ///
  /// Adapts half-window k based on local sample density rho:
  /// k = clamp(1, 4, round(rho * 2.5)).
  /// Deviation threshold = max(10.0, 3 * MAD).
  List<ProcessedTrajectoryPoint> _applyStage3AdaptiveMedianFilter(
    List<ProcessedTrajectoryPoint> points,
  ) {
    if (points.length < 3) return points;

    final result = <ProcessedTrajectoryPoint>[];

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      if (!pt.isAccepted || pt.isGapRecovery) {
        result.add(pt);
        continue;
      }

      // Compute local sample density (samples per second in 30s window)
      final tCurrent = pt.timestamp;
      var localCount = 0;
      for (var j = math.max(0, i - 15);
          j <= math.min(points.length - 1, i + 15);
          j++) {
        if (points[j].timestamp.difference(tCurrent).inSeconds.abs() <= 15) {
          localCount++;
        }
      }
      final density = localCount / 30.0;
      final k = (density * 2.5).round().clamp(1, 4);

      final start = math.max(0, i - k);
      final end = math.min(points.length - 1, i + k);
      final window =
          points.sublist(start, end + 1).where((p) => p.isAccepted).toList();

      if (window.length < 3) {
        result.add(pt);
        continue;
      }

      final lats = window.map((p) => p.latitude).toList()..sort();
      final lngs = window.map((p) => p.longitude).toList()..sort();

      final medLat = lats[lats.length ~/ 2];
      final medLng = lngs[lngs.length ~/ 2];
      final medPt = LatLng(medLat, medLng);

      final distToMed = _distance.distance(pt.point, medPt);

      // Median Absolute Deviation of distances to median
      final dists = window
          .map((p) => _distance.distance(p.point, medPt))
          .toList()
        ..sort();
      final mad = dists[dists.length ~/ 2];
      final threshold = math.max(10.0, math.max(3.0 * mad, pt.accuracyMeters * 1.8));

      if (distToMed > threshold) {
        final updatedFlags = Set<TrajectoryQualityFlag>.from(pt.qualityFlags)
          ..add(TrajectoryQualityFlag.statisticalOutlier)
          ..remove(TrajectoryQualityFlag.clean);

        result.add(ProcessedTrajectoryPoint(
          rawSample: pt.rawSample,
          qualityFlags: updatedFlags,
          segmentDistanceMeters: pt.segmentDistanceMeters,
          timeDeltaSec: pt.timeDeltaSec,
          impliedSpeedMs: pt.impliedSpeedMs,
          impliedAccelerationMs2: pt.impliedAccelerationMs2,
          forwardBearingDeg: pt.forwardBearingDeg,
          isAccepted: false,
          isGapRecovery: pt.isGapRecovery,
        ));
      } else {
        result.add(pt);
      }
    }

    return result;
  }

  static double _angularDiff(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }
}

