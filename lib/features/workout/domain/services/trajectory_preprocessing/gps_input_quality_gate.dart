import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'mobile_gvio_quality_gate.dart';
import 'trajectory_outlier_detector.dart';
import 'trajectory_sample.dart';

/// GPS Input Quality Gate for Aetron Workout Tracking.
///
/// Features:
/// 1. Emits 4 clean status levels:
///    - [GpsQualityStatus.accept]: Clean GPS within nominal kinematic limits.
///    - [GpsQualityStatus.downweight]: Retained fix with inflated measurement covariance (Huber/Cauchy scaling).
///    - [GpsQualityStatus.reject]: Unphysical outlier discarded from trajectory accumulation.
///    - [GpsQualityStatus.segmentBreak]: Hardware blackout (>5s), clean segment anchor without interpolation.
/// 2. Zero pseudo-measurements: never synthesizes fictional GPS positions.
/// 3. Preserves 100% raw GPS points in persistence layer.
/// 4. Production-safe fallback: when [kEnableGpsQualityGate] is false, falls back bit-for-bit to P01 OutlierDetector.
class GpsInputQualityGate {
  final KinematicLimits limits;
  final bool enableQualityGate;
  final bool enableShadowMode;
  final MobileGvioQualityGate _mGvioGate;
  final TrajectoryOutlierDetector _p01Detector;

  GpsInputQualityGate({
    required this.limits,
    bool? enableQualityGate,
    bool? enableShadowMode,
  })  : enableQualityGate = enableQualityGate ?? kEnableGpsQualityGate,
        enableShadowMode = enableShadowMode ?? kEnableGpsQualityGateShadowMode,
        _mGvioGate = MobileGvioQualityGate(limits: limits),
        _p01Detector = TrajectoryOutlierDetector(limits: limits);

  factory GpsInputQualityGate.forActivity(
    String activityType, {
    bool? enableQualityGate,
    bool? enableShadowMode,
  }) {
    final limits = KinematicLimits.forActivity(activityType);
    return GpsInputQualityGate(
      limits: limits,
      enableQualityGate: enableQualityGate,
      enableShadowMode: enableShadowMode,
    );
  }

  /// Evaluates an incoming streaming GPS sample.
  GpsQualityGateDecision evaluateSample({
    required TrajectoryRawSample candidate,
    required TrajectoryRawSample? previousRawSample,
    required ProcessedTrajectoryPoint? previousAcceptedPoint,
    required ProcessedTrajectoryPoint? twoPointsAgoAccepted,
    required LatLng? kinematicPredictedPoint,
    required double? previousSpeedMs,
    required double? rawTimeSincePreviousSampleSec,
  }) {
    // 1. Evaluate candidate using Candidate 2 (Mobile-GVIO Robust M-Estimator)
    final gateDecision = _mGvioGate.evaluatePoint(
      candidate: candidate,
      previousSample: previousRawSample,
      kinematicPredictedPoint: kinematicPredictedPoint,
      previousSpeedMs: previousSpeedMs,
    );

    // 2. Evaluate candidate using Current P01 Outlier Detector for baseline / shadow comparison
    final p01Processed = _p01Detector.evaluateStreamingPoint(
      candidate: candidate,
      previousAcceptedPoint: previousAcceptedPoint,
      twoPointsAgoAccepted: twoPointsAgoAccepted,
      rawTimeSincePreviousSampleSec: rawTimeSincePreviousSampleSec,
    );

    // 3. Shadow Mode logging
    if (enableShadowMode) {
      final p01Status = p01Processed.isAccepted
          ? (p01Processed.isGapRecovery
              ? GpsQualityStatus.segmentBreak
              : GpsQualityStatus.accept)
          : GpsQualityStatus.reject;

      if (p01Status != gateDecision.status) {
        if (kDebugMode) {
          debugPrint(
            '[GPS-GATE-SHADOW] Fix #${candidate.index}: '
            'P01=${p01Status.name} vs Gate=${gateDecision.status.name} '
            '(CovScale: ${gateDecision.covarianceScale.toStringAsFixed(2)}, '
            'AccSpike: ${gateDecision.impliedAccelerationMs2.toStringAsFixed(2)} m/s2)',
          );
        }
      }
    }

    // 4. Feature flag routing: if disabled, fallback bit-for-bit to P01 OutlierDetector
    if (!enableQualityGate) {
      if (!p01Processed.isAccepted) {
        return GpsQualityGateDecision(
          rawSample: candidate,
          status: GpsQualityStatus.reject,
          covarianceScale: double.infinity,
          qualityFlags: p01Processed.qualityFlags,
          impliedSpeedMs: p01Processed.impliedSpeedMs,
          impliedAccelerationMs2: p01Processed.impliedAccelerationMs2,
          innovationMeters: 0.0,
          segmentDistanceMeters: p01Processed.segmentDistanceMeters,
          timeDeltaSec: p01Processed.timeDeltaSec,
          isGapRecovery: false,
        );
      }

      if (p01Processed.isGapRecovery) {
        return GpsQualityGateDecision(
          rawSample: candidate,
          status: GpsQualityStatus.segmentBreak,
          covarianceScale: 1.0,
          qualityFlags: p01Processed.qualityFlags,
          impliedSpeedMs: p01Processed.impliedSpeedMs,
          impliedAccelerationMs2: p01Processed.impliedAccelerationMs2,
          innovationMeters: 0.0,
          segmentDistanceMeters: p01Processed.segmentDistanceMeters,
          timeDeltaSec: p01Processed.timeDeltaSec,
          isGapRecovery: true,
        );
      }

      return GpsQualityGateDecision(
        rawSample: candidate,
        status: GpsQualityStatus.accept,
        covarianceScale: 1.0,
        qualityFlags: p01Processed.qualityFlags,
        impliedSpeedMs: p01Processed.impliedSpeedMs,
        impliedAccelerationMs2: p01Processed.impliedAccelerationMs2,
        innovationMeters: 0.0,
        segmentDistanceMeters: p01Processed.segmentDistanceMeters,
        timeDeltaSec: p01Processed.timeDeltaSec,
        isGapRecovery: false,
      );
    }

    // 5. Enhanced Gate Active
    return gateDecision;
  }
}
