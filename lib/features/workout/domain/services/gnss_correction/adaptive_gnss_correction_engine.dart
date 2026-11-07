import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:latlong2/latlong.dart';

/// Phase 2 (P02) — Adaptive GNSS Correction Engine.
///
/// Implements research-grounded error correction techniques derived from:
/// - Sukhenko et al. (Applied Sciences 2025; DOI: 10.3390/app152212304)
/// - Groves (2013, Artech House, "Principles of GNSS, Inertial, and Multisensor Integrated Navigation Systems")
/// - Bar-Shalom, Li & Kirubarajan (2001, Wiley, "Estimation with Applications to Tracking and Navigation")
/// - Rong Li & Jilkov (2003, IEEE TAES, "Survey of Maneuvering Target Tracking")
class AdaptiveGnssCorrectionEngine implements IGnssCorrectionEngine {
  static const double _earthRadiusMeters = 6378137.0;
  static const double _degToRad = math.pi / 180.0;

  /// Chi-square 2-DOF 95% threshold: gamma_1 = 5.991
  final double gammaNominal;

  /// Chi-square 2-DOF 99.9% critical gate threshold: gamma_2 = 13.816
  final double gammaCritical;

  double? _prevAcceptedHeadingDeg;
  int _consecutiveOutlierCount = 0;

  AdaptiveGnssCorrectionEngine({
    this.gammaNominal = 5.991,
    this.gammaCritical = 13.816,
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
    final spatialDistSq = (yNorth * yNorth) + (yEast * yEast);

    // 2. Innovation Covariance S = P_pred + R_meas (2D isotropic scalar formulation)
    final rMeas = math.max(2.25, reportedAccuracyMeters * reportedAccuracyMeters);
    final pPred = math.max(1.0, predictedPosVariance);
    final sTotal = pPred + rMeas;

    // 3. Normalized Innovation Squared (Mahalanobis Distance Squared d_M^2)
    final dMSq = spatialDistSq / sTotal;

    // Mode-specific kinematic thresholds
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

    // 4. Low-speed heading deadband stabilization
    final bool isHeadingDeadbandActive = reportedSpeedMs < deadbandSpeedMs;
    double? effectiveHeading = reportedHeadingDeg;
    if (isHeadingDeadbandActive) {
      // When speed is negligible, GNSS Doppler bearing is invalid noise
      effectiveHeading = null;
    }

    // 5. Turn-Rate Centripetal Process Noise Scaling
    double headingMultiplier = 1.0;
    bool isTurnAdapted = false;

    if (!isHeadingDeadbandActive && reportedHeadingDeg != null) {
      final baselineHeading = predictedHeadingDeg ?? _prevAcceptedHeadingDeg ?? reportedHeadingDeg;
      var headingDiff = (reportedHeadingDeg - baselineHeading).abs();
      if (headingDiff > 180.0) headingDiff = 360.0 - headingDiff;

      final turnRate = headingDiff / dt;
      if (turnRate > turnRateThresholdDegPerSec) {
        final ratio = turnRate / turnRateThresholdDegPerSec;
        headingMultiplier = math.min(
          maxTurnNoiseMultiplier,
          1.0 + 0.8 * (ratio * ratio),
        );
        isTurnAdapted = true;
      }
    }

    // 6. Innovation Testing & Measurement Covariance Inflation
    if (dMSq <= gammaNominal) {
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
    } else if (dMSq <= gammaCritical) {
      // Degraded observation: inflate measurement covariance R adaptively
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

      // If user took a genuine abrupt motion that sustained for > 3 consecutive points,
      // re-anchor rather than perpetually rejecting
      if (_consecutiveOutlierCount >= 3) {
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
