import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'trajectory_sample.dart';

/// Decision outcomes for the Robust M-Estimator GNSS Quality Gate.
enum GpsQualityStatus {
  /// Normal GPS fix, trusted within nominal kinematic limits.
  accept,

  /// Moderate uncertainty (e.g. acceleration white noise derivative spike, moderate multipath).
  /// Measurement is retained for trajectory continuity, but covariance is inflated for AEKF.
  downweight,

  /// Gross physical impossibility (extreme velocity spike or unphysical multi-sigma jump).
  reject,

  /// Signal blackout or temporal discontinuity (> 5.0s). Anchor reset, no interpolation.
  segmentBreak,
}

/// Output decision for each GPS fix evaluated by the Quality Gate.
class GpsQualityGateDecision {
  final TrajectoryRawSample rawSample;
  final GpsQualityStatus status;
  final double covarianceScale;
  final Set<TrajectoryQualityFlag> qualityFlags;
  final double impliedSpeedMs;
  final double impliedAccelerationMs2;
  final double innovationMeters;
  final double segmentDistanceMeters;
  final double timeDeltaSec;
  final bool isGapRecovery;

  const GpsQualityGateDecision({
    required this.rawSample,
    required this.status,
    required this.covarianceScale,
    required this.qualityFlags,
    required this.impliedSpeedMs,
    required this.impliedAccelerationMs2,
    required this.innovationMeters,
    required this.segmentDistanceMeters,
    required this.timeDeltaSec,
    required this.isGapRecovery,
  });

  bool get isAcceptedForPath =>
      status == GpsQualityStatus.accept ||
      status == GpsQualityStatus.downweight ||
      (status == GpsQualityStatus.segmentBreak && isGapRecovery);

  bool get isDownweighted => status == GpsQualityStatus.downweight;
  bool get isRejected => status == GpsQualityStatus.reject;
}

/// Candidate Algorithm 2: Mobile-GVIO Robust M-Estimator GNSS Quality Gate.
///
/// Grounded in:
/// 1. Jiangbo Song et al. (2024–2026). "Mobile-GVIO: A Mobile Devices-Based
///    GNSS-Visual-Inertial Adaptive Fusion Method for Complex Urban Environments."
///    IEEE Internet of Things Journal.
/// 2. Peter J. Huber (1981). "Robust Statistics." John Wiley & Sons.
/// 3. Paul D. Groves (2013). "Principles of GNSS, Inertial, and Multisensor
///    Integrated Navigation Systems." Artech House, 2nd Edition.
///
/// Under 1 Hz consumer GPS sampling, white noise produces apparent acceleration
/// spikes (5-8 m/s^2) that trigger false rejections in rigid threshold filters.
/// This quality gate applies continuous/piecewise M-estimator downweighting
/// rather than hard-dropping valid mobile positions.
class MobileGvioQualityGate {
  final KinematicLimits limits;
  static const Distance _distance = Distance();

  /// Nominal innovation threshold multiplier in units of sigma (Huber k1).
  final double nominalSigmaMultiplier;

  /// Critical outlier rejection threshold multiplier in units of sigma (Huber k2).
  final double criticalSigmaMultiplier;

  const MobileGvioQualityGate({
    required this.limits,
    this.nominalSigmaMultiplier = 2.0,
    this.criticalSigmaMultiplier = 5.0,
  });

  factory MobileGvioQualityGate.forActivity(String activityType) {
    return MobileGvioQualityGate(
      limits: KinematicLimits.forActivity(activityType),
    );
  }

  /// Evaluates a single streaming fix against kinematic prior and historical context.
  GpsQualityGateDecision evaluatePoint({
    required TrajectoryRawSample candidate,
    required TrajectoryRawSample? previousSample,
    required LatLng? kinematicPredictedPoint,
    required double? previousSpeedMs,
  }) {
    final flags = <TrajectoryQualityFlag>{};

    // 1. Accuracy Check
    if (candidate.accuracyMeters > limits.maxAccuracyMeters) {
      flags.add(TrajectoryQualityFlag.lowAccuracy);
    }

    // First fix of session
    if (previousSample == null) {
      final isClean = flags.isEmpty;
      if (isClean) flags.add(TrajectoryQualityFlag.clean);
      return GpsQualityGateDecision(
        rawSample: candidate,
        status: isClean ? GpsQualityStatus.accept : GpsQualityStatus.downweight,
        covarianceScale: isClean ? 1.0 : 4.0,
        qualityFlags: flags,
        impliedSpeedMs: candidate.sensorSpeedMs ?? 0.0,
        impliedAccelerationMs2: 0.0,
        innovationMeters: 0.0,
        segmentDistanceMeters: 0.0,
        timeDeltaSec: 0.0,
        isGapRecovery: false,
      );
    }

    // 2. Temporal Gap (Blackout) Detection
    final dtSec = candidate.timestamp
            .difference(previousSample.timestamp)
            .inMilliseconds /
        1000.0;
    final isOutageGap = dtSec > limits.outageGapThresholdSeconds;

    if (isOutageGap) {
      flags.add(TrajectoryQualityFlag.signalGap);
      return GpsQualityGateDecision(
        rawSample: candidate,
        status: GpsQualityStatus.segmentBreak,
        covarianceScale: 1.0,
        qualityFlags: flags,
        impliedSpeedMs: 0.0,
        impliedAccelerationMs2: 0.0,
        innovationMeters: 0.0,
        segmentDistanceMeters: 0.0,
        timeDeltaSec: dtSec,
        isGapRecovery: true,
      );
    }

    // 3. Segment displacement & implied speed
    final segmentDistM = _distance.distance(previousSample.point, candidate.point);
    final impliedSpeedMs = dtSec > 0.05 ? segmentDistM / dtSec : (candidate.sensorSpeedMs ?? 0.0);

    // 4. Implied acceleration
    var impliedAccMs2 = 0.0;
    if (previousSpeedMs != null && dtSec > 0.1) {
      impliedAccMs2 = (impliedSpeedMs - previousSpeedMs).abs() / dtSec;
    }

    // 5. Kinematic Innovation calculation
    final predictedPt = kinematicPredictedPoint ?? previousSample.point;
    final innovationMeters = _distance.distance(predictedPt, candidate.point);

    // Nominal observation standard deviation (minimum 2.5m for consumer smartphone)
    final sigmaPos = math.max(2.5, candidate.accuracyMeters);
    final normalizedInnovation = innovationMeters / sigmaPos;

    // 6. Multi-Tier Decision:
    // A. Clear gross physical outlier (Reject)
    final isGrossSpeedViolation = impliedSpeedMs > limits.maxSpeedMs * 1.5;
    final isCriticalInnovationJump = normalizedInnovation > criticalSigmaMultiplier;
    final isSevereInaccurateSpike = candidate.accuracyMeters > limits.maxAccuracyMeters * 2.0;

    if (isGrossSpeedViolation || isCriticalInnovationJump || isSevereInaccurateSpike) {
      if (isGrossSpeedViolation) flags.add(TrajectoryQualityFlag.speedSpike);
      if (isCriticalInnovationJump) flags.add(TrajectoryQualityFlag.statisticalOutlier);
      if (isSevereInaccurateSpike) flags.add(TrajectoryQualityFlag.lowAccuracy);

      return GpsQualityGateDecision(
        rawSample: candidate,
        status: GpsQualityStatus.reject,
        covarianceScale: double.infinity,
        qualityFlags: flags,
        impliedSpeedMs: impliedSpeedMs,
        impliedAccelerationMs2: impliedAccMs2,
        innovationMeters: innovationMeters,
        segmentDistanceMeters: segmentDistM,
        timeDeltaSec: dtSec,
        isGapRecovery: false,
      );
    }

    // B. Moderate uncertainty: Acceleration noise spike or moderate innovation (Downweight)
    final isAccelerationSpike = impliedAccMs2 > limits.maxAccelerationMs2;
    final isModerateInnovation = normalizedInnovation > nominalSigmaMultiplier;
    final isModerateLowAccuracy = flags.contains(TrajectoryQualityFlag.lowAccuracy);

    if (isAccelerationSpike || isModerateInnovation || isModerateLowAccuracy) {
      if (isAccelerationSpike) flags.add(TrajectoryQualityFlag.accelerationSpike);
      if (isModerateInnovation) flags.add(TrajectoryQualityFlag.statisticalOutlier);

      // Cauchy robust loss weight: w = 1 / (1 + (r - r_nominal)^2)
      final excess = math.max(0.0, normalizedInnovation - nominalSigmaMultiplier);
      final cauchyWeight = 1.0 / (1.0 + (excess * excess));

      // Acceleration penalty factor
      final accRatio = limits.maxAccelerationMs2 > 0
          ? math.min(3.0, impliedAccMs2 / limits.maxAccelerationMs2)
          : 1.0;

      // Inflated covariance scale: S_R = (1 / w) * (accRatio)
      final covarianceScale = (1.0 / cauchyWeight) * math.max(1.0, accRatio);
      final clampedScale = covarianceScale.clamp(1.5, 9.0);

      return GpsQualityGateDecision(
        rawSample: candidate,
        status: GpsQualityStatus.downweight,
        covarianceScale: clampedScale,
        qualityFlags: flags,
        impliedSpeedMs: impliedSpeedMs,
        impliedAccelerationMs2: impliedAccMs2,
        innovationMeters: innovationMeters,
        segmentDistanceMeters: segmentDistM,
        timeDeltaSec: dtSec,
        isGapRecovery: false,
      );
    }

    // C. Nominal acceptable fix (Accept)
    flags.add(TrajectoryQualityFlag.clean);
    return GpsQualityGateDecision(
      rawSample: candidate,
      status: GpsQualityStatus.accept,
      covarianceScale: 1.0,
      qualityFlags: flags,
      impliedSpeedMs: impliedSpeedMs,
      impliedAccelerationMs2: impliedAccMs2,
      innovationMeters: innovationMeters,
      segmentDistanceMeters: segmentDistM,
      timeDeltaSec: dtSec,
      isGapRecovery: false,
    );
  }

  /// Processes a complete trajectory sequence using the Mobile-GVIO Quality Gate.
  List<GpsQualityGateDecision> processBatch(List<TrajectoryRawSample> samples) {
    if (samples.isEmpty) return const [];

    final decisions = <GpsQualityGateDecision>[];
    TrajectoryRawSample? prevAcceptedSample;
    double? prevSpeed;
    LatLng? predicted;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final decision = evaluatePoint(
        candidate: sample,
        previousSample: prevAcceptedSample,
        kinematicPredictedPoint: predicted,
        previousSpeedMs: prevSpeed,
      );

      decisions.add(decision);

      if (decision.isAcceptedForPath) {
        prevAcceptedSample = sample;
        prevSpeed = decision.impliedSpeedMs;
        // Simple kinematic linear extrapolation for next predicted point
        if (decisions.length >= 2 && decision.timeDeltaSec > 0.05) {
          final dLat = sample.latitude - (samples[i - 1].latitude);
          final dLon = sample.longitude - (samples[i - 1].longitude);
          predicted = LatLng(sample.latitude + dLat, sample.longitude + dLon);
        } else {
          predicted = sample.point;
        }
      }
    }

    return decisions;
  }
}
