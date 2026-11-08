import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/matrix_math_4x4.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:latlong2/latlong.dart';

/// Output estimation from an EKF update cycle
class EkfEstimate {
  final LatLng position;
  final double speedMs;
  final double headingDeg;
  final double positionVariance;
  final GnssCorrectionQuality? correctionQuality;
  final double? mahalanobisDistanceSq;
  final bool isMeasurementApplied;

  const EkfEstimate({
    required this.position,
    required this.speedMs,
    required this.headingDeg,
    required this.positionVariance,
    this.correctionQuality,
    this.mahalanobisDistanceSq,
    this.isMeasurementApplied = true,
  });
}

/// 4-State Extended Kalman Filter for real-time mobile GPS tracking.
///
/// State vector:
/// x = [ px,   (local East in meters)
///       py,   (local North in meters)
///       v,    (speed along track in m/s)
///       θ ]   (heading in radians, clockwise from North)
class ExtendedKalmanFilter {
  EquirectangularProjection? _projection;

  // State vector x: [px, py, v, theta]
  final Float64List _x = Float64List(4);

  // Error covariance matrix P (4x4)
  Matrix4x4 _p = Matrix4x4.identity();

  // Process noise standard deviations
  final double processPosStd; // meters/sec
  final double processSpeedStd; // m/s^2
  final double processHeadingStd; // rad/s

  // Phase 2 (P02) GNSS correction coupling
  final IGnssCorrectionEngine? gnssCorrectionEngine;
  final bool enableGnssCorrection;
  final bool enableShadowMode;
  final String activityType;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  ExtendedKalmanFilter({
    this.processPosStd = 0.5,
    this.processSpeedStd = 1.2,
    this.processHeadingStd = 0.35,
    this.gnssCorrectionEngine,
    this.enableGnssCorrection = kEnableGnssCorrection,
    this.enableShadowMode = kEnableGnssCorrectionShadowMode,
    this.activityType = 'running',
  });

  /// Re-seeds or initializes the filter with an initial anchor point.
  void init({
    required LatLng initialPoint,
    double initialAccuracyMeters = 5.0,
    double initialSpeedMs = 0.0,
    double? initialHeadingDeg,
  }) {
    _projection = EquirectangularProjection(initialPoint);
    _x[0] = 0.0; // px
    _x[1] = 0.0; // py
    _x[2] = math.max(0.0, initialSpeedMs); // v

    final headingDeg = initialHeadingDeg ?? 0.0;
    _x[3] = EquirectangularProjection.normalizeAngleRad(
      headingDeg * EquirectangularProjection.degToRad,
    );

    final posVar = math.max(2.25, initialAccuracyMeters * initialAccuracyMeters);
    _p = Matrix4x4.diagonal(
      posVar,
      posVar,
      4.0, // initial speed variance (2 m/s std)
      1.0, // initial heading variance (~57 deg std)
    );
    gnssCorrectionEngine?.reset();
    _initialized = true;
  }

  /// Resets filter state (e.g. after long GPS blackout > 5s)
  void reset() {
    _initialized = false;
    _projection = null;
    _x.fillRange(0, 4, 0.0);
    _p = Matrix4x4.identity();
    gnssCorrectionEngine?.reset();
  }

  /// Performs Predict-only cycle when GPS measurement is unavailable, rejected, or invalid.
  EkfEstimate predictOnly({required double timeDeltaSec}) {
    if (!_initialized || _projection == null) {
      throw StateError('Cannot predict without initialization');
    }
    final dt = (timeDeltaSec.isFinite && timeDeltaSec > 0.0)
        ? timeDeltaSec.clamp(0.05, 5.0)
        : 1.0;

    _predict(dt);

    if (_x[2] < 0.0) _x[2] = 0.0;
    _x[3] = EquirectangularProjection.normalizeAngleRad(_x[3]);

    final estimatedLatLng = _projection!.unproject(_x[0], _x[1]);
    final estimatedHeadingDeg = EquirectangularProjection.normalizeAngleDeg(
      _x[3] * EquirectangularProjection.radToDeg,
    );
    final posVariance = (_p.get(0, 0) + _p.get(1, 1)) / 2.0;

    return EkfEstimate(
      position: estimatedLatLng,
      speedMs: _x[2],
      headingDeg: estimatedHeadingDeg,
      positionVariance: posVariance,
      correctionQuality: GnssCorrectionQuality.nominal,
      mahalanobisDistanceSq: null,
      isMeasurementApplied: false,
    );
  }

  /// Performs Predict-Update cycle for a new accepted GPS measurement.
  ///
  /// - [measurementPoint]: raw accepted GPS LatLng
  /// - [accuracyMeters]: GPS reported horizontal accuracy (1-sigma)
  /// - [timeDeltaSec]: elapsed seconds since last update
  /// - [speedMs]: device measured GPS speed (optional)
  /// - [headingDeg]: device measured GPS heading in degrees (optional)
  /// - [activityType]: athletic sport modality for kinematic thresholds (optional)
  EkfEstimate update({
    required LatLng measurementPoint,
    required double accuracyMeters,
    required double timeDeltaSec,
    double? speedMs,
    double? headingDeg,
    String? activityType,
  }) {
    // Robust input validation and sanitization
    if (!measurementPoint.latitude.isFinite ||
        !measurementPoint.longitude.isFinite ||
        !accuracyMeters.isFinite ||
        accuracyMeters <= 0.0) {
      if (!_initialized) {
        return EkfEstimate(
          position: measurementPoint,
          speedMs: 0.0,
          headingDeg: 0.0,
          positionVariance: 50.0,
          correctionQuality: GnssCorrectionQuality.multipathRejected,
          isMeasurementApplied: false,
        );
      }
      return predictOnly(timeDeltaSec: timeDeltaSec);
    }

    if (!_initialized || _projection == null) {
      init(
        initialPoint: measurementPoint,
        initialAccuracyMeters: accuracyMeters,
        initialSpeedMs: speedMs ?? 0.0,
        initialHeadingDeg: headingDeg,
      );
      return EkfEstimate(
        position: measurementPoint,
        speedMs: _x[2],
        headingDeg: EquirectangularProjection.normalizeAngleDeg(
          _x[3] * EquirectangularProjection.radToDeg,
        ),
        positionVariance: accuracyMeters * accuracyMeters,
        correctionQuality: GnssCorrectionQuality.nominal,
        mahalanobisDistanceSq: 0.0,
        isMeasurementApplied: true,
      );
    }

    final dt = (timeDeltaSec.isFinite && timeDeltaSec > 0.0)
        ? timeDeltaSec.clamp(0.05, 5.0)
        : 1.0;

    // 1. PREDICT STEP: x_k|k-1 = f(x_k-1, dt)
    _predict(dt);

    var effectiveAccuracy = accuracyMeters;
    var effectiveHeading = headingDeg;
    var shouldApplyMeasurement = true;
    GnssCorrectionQuality? correctionQuality;
    double? mahalanobisDistanceSq;

    // P02 Innovation Testing & Adaptive Correction against filter prior state (x_k|k-1, P_k|k-1)
    if ((enableGnssCorrection || enableShadowMode) && gnssCorrectionEngine != null) {
      final predLatLng = _projection!.unproject(_x[0], _x[1]);
      final predHeadingDeg = EquirectangularProjection.normalizeAngleDeg(
        _x[3] * EquirectangularProjection.radToDeg,
      );
      final p00 = _p.get(0, 0); // East variance
      final p11 = _p.get(1, 1); // North variance
      final p01 = _p.get(0, 1); // EN covariance

      final corr = gnssCorrectionEngine!.correctMeasurement(
        measurementPoint: measurementPoint,
        reportedAccuracyMeters: accuracyMeters,
        timeDeltaSec: dt,
        reportedSpeedMs: speedMs ?? _x[2],
        reportedHeadingDeg: headingDeg,
        predictedPosition: predLatLng,
        predictedHeadingDeg: predHeadingDeg,
        predictedPosVariance: (p00 + p11) * 0.5,
        predictedPosVarianceEast: p00,
        predictedPosVarianceNorth: p11,
        predictedPosCovarianceEN: p01,
        activityType: activityType ?? this.activityType,
      );

      correctionQuality = corr.quality;
      mahalanobisDistanceSq = corr.mahalanobisDistanceSq;

      if (enableGnssCorrection) {
        if (!corr.isAccepted) {
          // Critical multipath jump rejected (d_M^2 > 13.816)
          shouldApplyMeasurement = false;
        } else {
          effectiveAccuracy = corr.effectiveAccuracyMeters;
          effectiveHeading = corr.effectiveHeadingDeg;
          if (corr.headingProcessNoiseMultiplier > 1.0) {
            // Add extra maneuver heading process noise delta Q_theta linearly [Li & Jilkov 2003; Groves 2013]
            // rather than geometrically multiplying posterior covariance P33 across consecutive epochs.
            final extraHeadingQ = (processHeadingStd * processHeadingStd * dt) *
                (corr.headingProcessNoiseMultiplier - 1.0);
            _p.set(3, 3, _p.get(3, 3) + extraHeadingQ);
          }
        }
      }
    }

    // 2. UPDATE STEP: calculate Kalman gain K and update with GPS measurement (if accepted)
    if (shouldApplyMeasurement) {
      _updateMeasurement(
        measurementPoint: measurementPoint,
        accuracyMeters: effectiveAccuracy,
        speedMs: speedMs,
        headingDeg: effectiveHeading,
        dt: dt,
      );
    }

    // Ensure speed non-negative
    if (_x[2] < 0.0) _x[2] = 0.0;
    _x[3] = EquirectangularProjection.normalizeAngleRad(_x[3]);

    final estimatedLatLng = _projection!.unproject(_x[0], _x[1]);
    final estimatedHeadingDeg = EquirectangularProjection.normalizeAngleDeg(
      _x[3] * EquirectangularProjection.radToDeg,
    );
    final posVariance = (_p.get(0, 0) + _p.get(1, 1)) / 2.0;

    return EkfEstimate(
      position: estimatedLatLng,
      speedMs: _x[2],
      headingDeg: estimatedHeadingDeg,
      positionVariance: posVariance,
      correctionQuality: correctionQuality,
      mahalanobisDistanceSq: mahalanobisDistanceSq,
      isMeasurementApplied: shouldApplyMeasurement,
    );
  }

  void _predict(double dt) {
    final px = _x[0];
    final py = _x[1];
    final v = _x[2];
    final theta = _x[3];

    final sinTheta = math.sin(theta);
    final cosTheta = math.cos(theta);

    // Non-linear state transition f(x, dt)
    _x[0] = px + v * sinTheta * dt;
    _x[1] = py + v * cosTheta * dt;
    // v and theta are modeled as constant velocity / heading with process noise

    // Jacobian F = df / dx
    final f = Matrix4x4.identity();
    f.set(0, 2, sinTheta * dt);
    f.set(0, 3, v * cosTheta * dt);
    f.set(1, 2, cosTheta * dt);
    f.set(1, 3, -v * sinTheta * dt);

    // Process noise covariance Q
    final qPos = processPosStd * processPosStd * dt;
    final qSpeed = processSpeedStd * processSpeedStd * dt;
    final qHeading = processHeadingStd * processHeadingStd * dt;
    final q = Matrix4x4.diagonal(qPos, qPos, qSpeed, qHeading);

    // P = F * P * F^T + Q
    final fTranspose = f.transpose();
    _p = (f * _p * fTranspose) + q;
    _p.symmetrizeAndClamp();
  }

  void _updateMeasurement({
    required LatLng measurementPoint,
    required double accuracyMeters,
    double? speedMs,
    double? headingDeg,
    required double dt,
  }) {
    final (zx, zy) = _projection!.project(measurementPoint);
    final rPos = math.max(2.25, accuracyMeters * accuracyMeters);

    final hasValidSpeed = speedMs != null && speedMs >= 0.0;
    final hasValidHeading =
        headingDeg != null &&
        headingDeg >= 0.0 &&
        (speedMs == null || speedMs > 0.6);

    if (hasValidSpeed && hasValidHeading) {
      // Full 4x4 measurement update: z = [zx, zy, speed, headingRad]
      final zHeadingRad = EquirectangularProjection.normalizeAngleRad(
        headingDeg * EquirectangularProjection.degToRad,
      );

      final rSpeed = 1.0; // (1.0 m/s)^2
      final rHeading = math.max(0.1, (accuracyMeters / (math.max(1.0, speedMs) * dt)).clamp(0.1, 1.5));
      final r = Matrix4x4.diagonal(rPos, rPos, rSpeed, rHeading);

      // S = P + R (since H = I)
      final s = _p + r;
      Matrix4x4 sInv;
      try {
        sInv = s.invert();
      } catch (_) {
        // Fallback to position-only update if 4x4 near singular
        _updatePositionOnly(zx, zy, rPos);
        return;
      }

      // K = P * S^-1
      final k = _p * sInv;

      // Innovation y = z - x
      var headingInnov = zHeadingRad - _x[3];
      headingInnov = EquirectangularProjection.normalizeAngleRad(headingInnov);

      final y = Float64List(4);
      y[0] = zx - _x[0];
      y[1] = zy - _x[1];
      y[2] = speedMs - _x[2];
      y[3] = headingInnov;

      final ky = k.multiplyVector(y);
      _x[0] += ky[0];
      _x[1] += ky[1];
      _x[2] += ky[2];
      _x[3] += ky[3];

      // Covariance update: P = (I - K) * P
      final iMinusK = Matrix4x4.identity() - k;
      _p = iMinusK * _p;
      _p.symmetrizeAndClamp();
    } else {
      // Position-only 2x2 update: H = [1 0 0 0; 0 1 0 0]
      _updatePositionOnly(zx, zy, rPos);
    }
  }

  void _updatePositionOnly(double zx, double zy, double rPos) {
    // S = H P H^T + R (2x2)
    // H selects top-left 2x2 of P
    final s00 = _p.get(0, 0) + rPos;
    final s01 = _p.get(0, 1);
    final s10 = _p.get(1, 0);
    final s11 = _p.get(1, 1) + rPos;

    final s = Matrix2x2(s00, s01, s10, s11);
    Matrix2x2 sInv;
    try {
      sInv = s.invert();
    } catch (_) {
      // If singular, add diagonal regularizer
      sInv = Matrix2x2(s00 + 1e-4, s01, s10, s11 + 1e-4).invert();
    }

    // P * H^T is 4x2 matrix consisting of first two columns of P:
    // Row r: [ P(r, 0), P(r, 1) ]
    // K = (P * H^T) * S^-1 -> 4x2 matrix
    final k00 = _p.get(0, 0) * sInv.m00 + _p.get(0, 1) * sInv.m10;
    final k01 = _p.get(0, 0) * sInv.m01 + _p.get(0, 1) * sInv.m11;

    final k10 = _p.get(1, 0) * sInv.m00 + _p.get(1, 1) * sInv.m10;
    final k11 = _p.get(1, 0) * sInv.m01 + _p.get(1, 1) * sInv.m11;

    final k20 = _p.get(2, 0) * sInv.m00 + _p.get(2, 1) * sInv.m10;
    final k21 = _p.get(2, 0) * sInv.m01 + _p.get(2, 1) * sInv.m11;

    final k30 = _p.get(3, 0) * sInv.m00 + _p.get(3, 1) * sInv.m10;
    final k31 = _p.get(3, 0) * sInv.m01 + _p.get(3, 1) * sInv.m11;

    // Innovation y = [zx - px, zy - py]
    final y0 = zx - _x[0];
    final y1 = zy - _x[1];

    _x[0] += k00 * y0 + k01 * y1;
    _x[1] += k10 * y0 + k11 * y1;
    _x[2] += k20 * y0 + k21 * y1;
    _x[3] += k30 * y0 + k31 * y1;

    // P = (I - K H) * P
    // K H is 4x4 matrix with columns 0 and 1 equal to K, and columns 2 and 3 equal to 0.
    final kh = Matrix4x4.fromList([
      k00, k01, 0.0, 0.0,
      k10, k11, 0.0, 0.0,
      k20, k21, 0.0, 0.0,
      k30, k31, 0.0, 0.0,
    ]);
    final iMinusKh = Matrix4x4.identity() - kh;
    _p = iMinusKh * _p;
    _p.symmetrizeAndClamp();
  }
}
