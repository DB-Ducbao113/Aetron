import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'trajectory_sample.dart';

/// Trajectory outlier detection engine reproducing published literature:
///
/// 1. Zheng (2015). "Trajectory Data Mining: An Overview." ACM TIST, 6(3), 29.
///    DOI: 10.1145/2743025 (Section 3.1: Noise Filtering by Mean/Median & Heuristic Thresholds).
/// 2. Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///    Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694 (Section 3.1: Data Cleaning & Outlier Detection).
///
/// Under the academic requirement, algorithms are faithful to the cited primary literature,
/// and neither delete nor overwrite raw GPS data. Anomalies are labeled via quality flags.
class TrajectoryOutlierDetector {
  final KinematicLimits limits;
  static const Distance _distance = Distance();

  const TrajectoryOutlierDetector({required this.limits});

  /// Evaluates a single candidate point against its predecessor(s) in streaming mode.
  ///
  /// Returns the set of quality flags and computed kinematic quantities.
  ProcessedTrajectoryPoint evaluateStreamingPoint({
    required TrajectoryRawSample candidate,
    required ProcessedTrajectoryPoint? previousAcceptedPoint,
    required ProcessedTrajectoryPoint? twoPointsAgoAccepted,
    required double? rawTimeSincePreviousSampleSec,
  }) {
    final flags = <TrajectoryQualityFlag>{};

    // 1. Accuracy Check
    if (candidate.accuracyMeters > limits.maxAccuracyMeters) {
      flags.add(TrajectoryQualityFlag.lowAccuracy);
    }

    // First point of trajectory
    if (previousAcceptedPoint == null) {
      if (flags.isEmpty) {
        flags.add(TrajectoryQualityFlag.clean);
      }
      return ProcessedTrajectoryPoint(
        rawSample: candidate,
        qualityFlags: flags,
        segmentDistanceMeters: 0.0,
        timeDeltaSec: 0.0,
        impliedSpeedMs: candidate.sensorSpeedMs ?? 0.0,
        impliedAccelerationMs2: 0.0,
        forwardBearingDeg: candidate.sensorHeadingDeg,
        isAccepted: !flags.contains(TrajectoryQualityFlag.lowAccuracy),
        isGapRecovery: false,
      );
    }

    // 2. Temporal Gap Check (Blackout / Outage)
    final dtSec = candidate.timestamp
            .difference(previousAcceptedPoint.timestamp)
            .inMilliseconds /
        1000.0;

    final rawGapSec = rawTimeSincePreviousSampleSec ?? dtSec;
    final isOutageGap = rawGapSec > limits.outageGapThresholdSeconds ||
        dtSec > limits.outageGapThresholdSeconds;

    if (isOutageGap) {
      flags.add(TrajectoryQualityFlag.signalGap);
    }

    // 3. Segment displacement
    final segmentDistanceMeters = _distance.distance(
      previousAcceptedPoint.point,
      candidate.point,
    );

    // Forward bearing
    final forwardBearingDeg = segmentDistanceMeters > 0.1
        ? _distance.bearing(previousAcceptedPoint.point, candidate.point)
        : previousAcceptedPoint.forwardBearingDeg;

    // 4. Implied Speed Check (only within continuous tracking, not across outages)
    var impliedSpeedMs = candidate.sensorSpeedMs ?? 0.0;
    if (!isOutageGap && dtSec > 0.05) {
      impliedSpeedMs = segmentDistanceMeters / dtSec;
      if (impliedSpeedMs > limits.maxSpeedMs) {
        flags.add(TrajectoryQualityFlag.speedSpike);
      }
    }

    // 5. Implied Acceleration Check (only within continuous tracking, not across outages)
    var impliedAccMs2 = 0.0;
    final canCheckAcceleration = !isOutageGap &&
        (!previousAcceptedPoint.isGapRecovery || previousAcceptedPoint.impliedSpeedMs > 0) &&
        dtSec > 0.1;

    if (canCheckAcceleration) {
      final prevSpeed = previousAcceptedPoint.impliedSpeedMs;
      impliedAccMs2 = (impliedSpeedMs - prevSpeed).abs() / dtSec;
      if (impliedAccMs2 > limits.maxAccelerationMs2) {
        flags.add(TrajectoryQualityFlag.accelerationSpike);
      }
    }

    // 6. Acute Heading Reversal Spike (Ping-Pong multipath reflection)
    // If we have 2 prior points, check whether candidate forms a sharp acute rebound:
    // candidate jumps out and then sharply turns back with high speed.
    if (twoPointsAgoAccepted != null && !isOutageGap && dtSec <= 4.0) {
      final prevBearing = twoPointsAgoAccepted.forwardBearingDeg;
      if (prevBearing != null && forwardBearingDeg != null) {
        final bearingChange = _bearingDifference(prevBearing, forwardBearingDeg);
        if (bearingChange >= limits.acuteHeadingReversalThresholdDeg &&
            segmentDistanceMeters > 10.0 &&
            impliedSpeedMs > limits.maxSpeedMs * 0.75) {
          flags.add(TrajectoryQualityFlag.headingSpike);
        }
      }
    }

    // Determine acceptance:
    // A point is accepted for path inclusion if it is not an outlier spike and not low accuracy.
    // If it's a signal gap, it is accepted as a recovery anchor (starting a new segment),
    // but marked with isGapRecovery = true so downstream path accumulators do not interpolate.
    final hasKinematicSpike =
        flags.contains(TrajectoryQualityFlag.speedSpike) ||
        flags.contains(TrajectoryQualityFlag.accelerationSpike) ||
        flags.contains(TrajectoryQualityFlag.headingSpike);

    final isAccuracyFailure = flags.contains(TrajectoryQualityFlag.lowAccuracy);

    final isAccepted = !hasKinematicSpike && !isAccuracyFailure;

    if (flags.isEmpty) {
      flags.add(TrajectoryQualityFlag.clean);
    }

    return ProcessedTrajectoryPoint(
      rawSample: candidate,
      qualityFlags: flags,
      segmentDistanceMeters: segmentDistanceMeters,
      timeDeltaSec: dtSec,
      impliedSpeedMs: impliedSpeedMs,
      impliedAccelerationMs2: impliedAccMs2,
      forwardBearingDeg: forwardBearingDeg,
      isAccepted: isAccepted,
      isGapRecovery: isOutageGap && isAccepted,
    );
  }

  /// Batch Median Outlier Filter (Li et al. 2025 Sec 3.1 & Zheng 2015).
  ///
  /// Applies a symmetric sliding window of odd size W (e.g. 5) across trajectory points.
  /// Computes spatial median for each window and annotates statistical outliers
  /// where deviation exceeds 3 * MAD (Median Absolute Deviation) or mode limit.
  List<ProcessedTrajectoryPoint> applyBatchMedianFilter(
    List<ProcessedTrajectoryPoint> points,
  ) {
    if (points.length < limits.medianWindowSize) {
      return points;
    }

    final k = limits.medianWindowSize ~/ 2;
    final result = <ProcessedTrajectoryPoint>[];

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      if (!pt.isAccepted || pt.isGapRecovery) {
        result.add(pt);
        continue;
      }

      final start = math.max(0, i - k);
      final end = math.min(points.length - 1, i + k);
      final window = points.sublist(start, end + 1).where((p) => p.isAccepted).toList();

      if (window.length < 3) {
        result.add(pt);
        continue;
      }

      final lats = window.map((p) => p.latitude).toList()..sort();
      final lngs = window.map((p) => p.longitude).toList()..sort();

      final medianLat = lats[lats.length ~/ 2];
      final medianLng = lngs[lngs.length ~/ 2];
      final medianPoint = LatLng(medianLat, medianLng);

      final distToMedian = _distance.distance(pt.point, medianPoint);

      // Compute MAD of distances to median in the window
      final dists = window
          .map((p) => _distance.distance(p.point, medianPoint))
          .toList()
        ..sort();
      final madDist = dists[dists.length ~/ 2];
      final threshold = math.max(12.0, math.max(3.0 * madDist, pt.accuracyMeters * 2.0));

      if (distToMedian > threshold) {
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
          isAccepted: false, // rejected by statistical median window
          isGapRecovery: pt.isGapRecovery,
        ));
      } else {
        result.add(pt);
      }
    }

    return result;
  }

  /// Calculates angular difference between two bearings in degrees [0, 180].
  static double _bearingDifference(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }
}
