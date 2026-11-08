import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:latlong2/latlong.dart';

/// Phase 2 (P02) — Adaptive GNSS Correction Engine.
///
/// Implements research-grounded error correction techniques derived from:
/// - Sukhenko et al. (Applied Sciences 2025; DOI: 10.3390/app152212304)
/// - Groves (2013, Artech House, "Principles of GNSS, Inertial, and Multisensor Integrated Navigation Systems", Sec. 11.4)
/// - Bar-Shalom, Li & Kirubarajan (2001, Wiley, "Estimation with Applications to Tracking and Navigation", Sec. 2.3 & 3.2)
/// - Rong Li & Jilkov (2003, IEEE TAES, "Survey of Maneuvering Target Tracking. Part I: Dynamic Models")
class AdaptiveGnssCorrectionEngine implements IGnssCorrectionEngine {
  static const double _earthRadiusMeters = 6378137.0;
  static const double _degToRad = math.pi / 180.0;

  /// Chi-square 2-DOF 95% threshold: gamma_1 = 5.991 [Published: Bar-Shalom 2001; Groves 2013]
  final double gammaNominal;

  /// Chi-square 2-DOF 99.9% critical gate threshold: gamma_2 = 13.816 [Published: Bar-Shalom 2001; Sukhenko 2025]
  final double gammaCritical;

  /// Ablation feature flags (default true for production P02)
  final bool enableInnovationGating;
  final bool enableAdaptiveCovarianceInflation;
  final bool enableTurnRateNoiseScaling;
  final bool enableHeadingDeadband;
  final bool enableConsecutiveReanchor;

  /// Number of consecutive critical outliers required before triggering a recovery re-anchor.
  final int consecutiveOutlierThreshold;

  double? _prevAcceptedHeadingDeg;
  int _consecutiveOutlierCount = 0;

  AdaptiveGnssCorrectionEngine({
    this.gammaNominal = 5.991,
    this.gammaCritical = 13.816,
    this.enableInnovationGating = true,
    this.enableAdaptiveCovarianceInflation = true,
    this.enableTurnRateNoiseScaling = true,
    this.enableHeadingDeadband = true,
    this.enableConsecutiveReanchor = true,
    this.consecutiveOutlierThreshold = 4,
  });

  @override
  void reset() {
    _prevAcceptedHeadingDeg = null;
    _consecutiveOutlierCount = 0;
  }

  @override
  GnssCorrectionResult correctMeasurement({
    required LatLng measurementPoint,
    required double reportedAccuracyMeters,
    required double timeDeltaSec,
    required double reportedSpeedMs,
    required double? reportedHeadingDeg,
    required LatLng? predictedPosition,
    required double? predictedHeadingDeg,
    required double predictedPosVariance,
    double? predictedPosVarianceEast,
    double? predictedPosVarianceNorth,
    double? predictedPosCovarianceEN,
    required String activityType,
  }) {
    final dt = timeDeltaSec.clamp(0.05, 5.0);

    // Initial fix: no prediction available, accept nominally
    if (predictedPosition == null) {
      if (reportedHeadingDeg != null) {
        _prevAcceptedHeadingDeg = reportedHeadingDeg;
      }
      return GnssCorrectionResult(
        position: measurementPoint,
        effectiveAccuracyMeters: math.max(1.5, reportedAccuracyMeters),
        effectiveSpeedMs: math.max(0.0, reportedSpeedMs),
        effectiveHeadingDeg: reportedHeadingDeg,
        mahalanobisDistanceSq: 0.0,
        quality: GnssCorrectionQuality.nominal,
        isAccepted: true,
        headingProcessNoiseMultiplier: 1.0,
      );
    }

    // 1. Calculate Local ENU Spatial Innovation Vector y = z - x_pred
    final dLatRad = (measurementPoint.latitude - predictedPosition.latitude) * _degToRad;
    final dLngRad = (measurementPoint.longitude - predictedPosition.longitude) * _degToRad;
    final meanLatRad = (measurementPoint.latitude + predictedPosition.latitude) * 0.5 * _degToRad;

    final yNorth = dLatRad * _earthRadiusMeters;
    final yEast = dLngRad * math.cos(meanLatRad) * _earthRadiusMeters;

    // 2. Full 2x2 Innovation Covariance Matrix: S = H P^- H^T + R [Published: Bar-Shalom 2001, Eq. 1.4-12]
    // Reported horizontal accuracy (iOS CLLocation.horizontalAccuracy / Android Location.getAccuracy())
    // is a 68% confidence circle (1-sigma radius). R = diag(sigma_pos^2, sigma_pos^2).
    final rMeas = math.max(2.25, reportedAccuracyMeters * reportedAccuracyMeters);
    final pEast = math.max(0.5, predictedPosVarianceEast ?? predictedPosVariance);
    final pNorth = math.max(0.5, predictedPosVarianceNorth ?? predictedPosVariance);
    final pCov = predictedPosCovarianceEN ?? 0.0;

    final s00 = pEast + rMeas; // S_EE
    final s11 = pNorth + rMeas; // S_NN
    final s01 = pCov; // S_EN = S_NE

    // Determinant: det(S) = S_EE * S_NN - S_EN^2
    // Since P^- is positive semi-definite (P_EE * P_NN - P_EN^2 >= 0) and rMeas >= 2.25 > 0,
    // det(S) >= rMeas^2 >= 5.0625 > 0, strictly positive definite and stably invertible.
    final detS = (s00 * s11) - (s01 * s01);
    final safeDet = detS > 1e-4 ? detS : (rMeas * rMeas);

    // 3. Normalized Innovation Squared (NIS / Mahalanobis Distance Squared d_M^2)
    // [Published: Bar-Shalom 2001, Eq. 2.3.1; Groves 2013, Eq. 11.42]
    // Closed-form exact 2D quadratic form: y^T S^-1 y = (yE^2 * S_NN - 2 * yE * yN * S_EN + yN^2 * S_EE) / det(S)
    final dMSq = ((yEast * yEast * s11) - (2.0 * yEast * yNorth * s01) + (yNorth * yNorth * s00)) / safeDet;

    // Mode-specific kinematic thresholds [Aetron-Adapted]
    final mode = activityType.toLowerCase();
    final double deadbandSpeedMs;
    final double turnRateThresholdDegPerSec;
    final double maxTurnNoiseMultiplier;

    if (mode.contains('walk')) {
      deadbandSpeedMs = 0.8;
      turnRateThresholdDegPerSec = 20.0;
      maxTurnNoiseMultiplier = 3.0;
    } else if (mode.contains('run')) {
      deadbandSpeedMs = 1.2;
      turnRateThresholdDegPerSec = 15.0;
      maxTurnNoiseMultiplier = 4.0;
    } else {
      // cycling / wheel sports
      deadbandSpeedMs = 1.8;
      turnRateThresholdDegPerSec = 10.0;
      maxTurnNoiseMultiplier = 5.0;
    }

    // 4. Low-speed heading deadband stabilization [Aetron-Adapted]
    final bool isHeadingDeadbandActive =
        enableHeadingDeadband && (reportedSpeedMs < deadbandSpeedMs);
    double? effectiveHeading = reportedHeadingDeg;
    if (isHeadingDeadbandActive) {
      // When speed is negligible, GNSS Doppler bearing is invalid white noise
      effectiveHeading = null;
    }

    // 5. Turn-Rate Centripetal Process Noise Scaling [Reproduced: Rong Li & Jilkov 2003]
    // Heading wrap-around across 359° -> 1° handled via circular shortest difference.
    double headingMultiplier = 1.0;
    bool isTurnAdapted = false;

    if (enableTurnRateNoiseScaling && !isHeadingDeadbandActive && reportedHeadingDeg != null) {
      final baselineHeading = predictedHeadingDeg ?? _prevAcceptedHeadingDeg ?? reportedHeadingDeg;
      var headingDiff = (reportedHeadingDeg - baselineHeading).abs();
      if (headingDiff > 180.0) headingDiff = 360.0 - headingDiff;

      final turnRate = headingDiff / dt;
      if (turnRate > turnRateThresholdDegPerSec) {
        final ratio = turnRate / turnRateThresholdDegPerSec;
        // [Aetron-Adapted] Damping factor 0.8 prevents arm-swing oscillation from over-inflating noise.
        headingMultiplier = math.min(
          maxTurnNoiseMultiplier,
          1.0 + 0.8 * (ratio * ratio),
        );
        isTurnAdapted = true;
      }
    }

    // 6. Innovation Testing & Measurement Covariance Inflation
    final isGatedOutlier = enableInnovationGating && (dMSq > gammaCritical);
    final isInflated = enableAdaptiveCovarianceInflation && (dMSq > gammaNominal && dMSq <= gammaCritical);

    if (!isGatedOutlier && !isInflated) {
      // Nominal observation: within 95% confidence ellipsoid
      _consecutiveOutlierCount = 0;
      if (effectiveHeading != null) {
        _prevAcceptedHeadingDeg = effectiveHeading;
      }
      return GnssCorrectionResult(
        position: measurementPoint,
        effectiveAccuracyMeters: reportedAccuracyMeters,
        effectiveSpeedMs: reportedSpeedMs,
        effectiveHeadingDeg: effectiveHeading,
        mahalanobisDistanceSq: dMSq,
        quality: isTurnAdapted
            ? GnssCorrectionQuality.turnAdapted
            : (isHeadingDeadbandActive
                ? GnssCorrectionQuality.headingDeadbandApplied
                : GnssCorrectionQuality.nominal),
        isAccepted: true,
        headingProcessNoiseMultiplier: headingMultiplier,
      );
    } else if (isInflated) {
      // Degraded observation: inflate measurement covariance R adaptively [Reproduced: Groves 2013, Sec 11.4]
      _consecutiveOutlierCount = 0;
      final inflationFactor = math.sqrt(dMSq / gammaNominal);
      final effectiveAcc = reportedAccuracyMeters * inflationFactor;

      if (effectiveHeading != null) {
        _prevAcceptedHeadingDeg = effectiveHeading;
      }
      return GnssCorrectionResult(
        position: measurementPoint,
        effectiveAccuracyMeters: effectiveAcc,
        effectiveSpeedMs: reportedSpeedMs,
        effectiveHeadingDeg: effectiveHeading,
        mahalanobisDistanceSq: dMSq,
        quality: GnssCorrectionQuality.inflatedVariance,
        isAccepted: true,
        headingProcessNoiseMultiplier: headingMultiplier,
      );
    } else {
      // Critical outlier (d_M^2 > gammaCritical): severe multipath jump
      _consecutiveOutlierCount++;

      // If user took a genuine abrupt motion that sustained for >= consecutiveOutlierThreshold consecutive points,
      // re-anchor rather than perpetually rejecting
      if (enableConsecutiveReanchor && _consecutiveOutlierCount >= consecutiveOutlierThreshold) {
        _consecutiveOutlierCount = 0;
        if (effectiveHeading != null) {
          _prevAcceptedHeadingDeg = effectiveHeading;
        }
        return GnssCorrectionResult(
          position: measurementPoint,
          effectiveAccuracyMeters: reportedAccuracyMeters * 2.0,
          effectiveSpeedMs: reportedSpeedMs,
          effectiveHeadingDeg: effectiveHeading,
          mahalanobisDistanceSq: dMSq,
          quality: GnssCorrectionQuality.inflatedVariance,
          isAccepted: true,
          headingProcessNoiseMultiplier: headingMultiplier,
        );
      }

      // Reject outlier update to protect state from multipath distortion
      return GnssCorrectionResult(
        position: measurementPoint,
        effectiveAccuracyMeters: reportedAccuracyMeters,
        effectiveSpeedMs: reportedSpeedMs,
        effectiveHeadingDeg: null,
        mahalanobisDistanceSq: dMSq,
        quality: GnssCorrectionQuality.multipathRejected,
        isAccepted: false,
        headingProcessNoiseMultiplier: 1.0,
      );
    }
  }
}
