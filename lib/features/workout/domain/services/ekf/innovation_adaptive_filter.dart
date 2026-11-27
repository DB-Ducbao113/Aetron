import 'dart:collection';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../trajectory_preprocessing/robust_igg3_weight.dart';

/// Result of a single update step of [InnovationAdaptiveKalmanFilter].
class IaeFilterOutput {
  final LatLng position;
  final double velocityEastMs;
  final double velocityNorthMs;
  final double speedMs;
  final double posVarEast;
  final double posVarNorth;
  final double igg3Weight;
  final bool rejected;
  final double nis;
  final double estimatedREast;
  final double estimatedRNorth;

  const IaeFilterOutput({
    required this.position,
    required this.velocityEastMs,
    required this.velocityNorthMs,
    required this.speedMs,
    required this.posVarEast,
    required this.posVarNorth,
    required this.igg3Weight,
    required this.rejected,
    required this.nis,
    required this.estimatedREast,
    required this.estimatedRNorth,
  });
}

/// 4-State Constant-Velocity Kalman Filter with:
/// - Innovation-Based Adaptive Estimation (IAE):
///   Mohamed, A. H., & Schwarz, K. P. (1999). "Adaptive Kalman filtering for INS/GPS."
///   Journal of Geodesy, 73, 193–203. DOI: 10.1007/s001900050236.
///   Estimates `C_hat_v = (1/m) sum(v_i v_i^T)` and `R_hat = C_hat_v - H P^- H^T`.
/// - Optional IGG-III robust observation weighting:
///   Yang, Y., He, H., & Xu, G. (2001). Journal of Geodesy, 75, 109–116.
///   DOI: 10.1007/s001900000157.
///
/// Adaptation disclosures:
/// 1. [MS99] targets INS/GPS; here we apply IAE to a 4-state GNSS-only CV model.
/// 2. Positive-definiteness of `R_hat` is safeguarded by clamping diagonal entries
///    to `[rFloor, rCap]` (numerical adaptation).
/// 3. Joseph-form covariance update preserves symmetry and PSD guarantees.
class InnovationAdaptiveKalmanFilter {
  static const double _metersPerDegLat = 111320.0;

  final int windowSize;
  final bool enableIae;
  final bool enableIgg3;
  final double processAccelStd;
  final double igg3K0;
  final double igg3K1;
  final double maxGapSec;
  final double rMinVar;
  final double rMaxVar;

  LatLng? _origin;
  DateTime? _lastTime;

  // State vector x = [e, n, ve, vn]
  final List<double> _x = List<double>.filled(4, 0.0);
  // 4x4 covariance matrix P (row-major)
  final List<double> _p = List<double>.filled(16, 0.0);

  // Sliding window of 2D innovations (ve, vn) for IAE
  final ListQueue<(double, double)> _innovations = ListQueue<(double, double)>();
  double _lastREast = 9.0;
  double _lastRNorth = 9.0;

  InnovationAdaptiveKalmanFilter({
    this.windowSize = 10,
    this.enableIae = true,
    this.enableIgg3 = true,
    this.processAccelStd = 1.0,
    this.igg3K0 = RobustIgg3Weight.defaultK0,
    this.igg3K1 = RobustIgg3Weight.defaultK1,
    this.maxGapSec = 5.0,
    this.rMinVar = 1.0,
    this.rMaxVar = 2500.0,
  });

  bool get isInitialized => _origin != null && _lastTime != null;

  /// Exposes a copy of the 4x4 covariance matrix P for symmetry/PSD tests.
  List<double> get covarianceCopy => List<double>.from(_p);

  void reset() {
    _origin = null;
    _lastTime = null;
    for (int i = 0; i < 4; i++) {
      _x[i] = 0.0;
    }
    for (int i = 0; i < 16; i++) {
      _p[i] = 0.0;
    }
    _innovations.clear();
  }

  (double, double) _toEnu(LatLng pt) {
    final o = _origin!;
    final cosLat = math.cos(o.latitude * math.pi / 180.0);
    final e = (pt.longitude - o.longitude) * _metersPerDegLat * cosLat;
    final n = (pt.latitude - o.latitude) * _metersPerDegLat;
    return (e, n);
  }

  LatLng _toLatLng(double e, double n) {
    final o = _origin!;
    final cosLat = math.cos(o.latitude * math.pi / 180.0).clamp(1e-6, 1.0);
    final lat = o.latitude + (n / _metersPerDegLat);
    final lng = o.longitude + (e / (_metersPerDegLat * cosLat));
    return LatLng(lat, lng);
  }

  void _init(LatLng point, DateTime timestamp, double accuracyMeters) {
    _origin = point;
    _lastTime = timestamp;
    _x[0] = 0.0;
    _x[1] = 0.0;
    _x[2] = 0.0;
    _x[3] = 0.0;
    final r0 = math.max(accuracyMeters * accuracyMeters, rMinVar);
    for (int i = 0; i < 16; i++) {
      _p[i] = 0.0;
    }
    _p[0] = r0;
    _p[5] = r0;
    _p[10] = 4.0;
    _p[15] = 4.0;
    _innovations.clear();
    _lastREast = r0;
    _lastRNorth = r0;
  }

  IaeFilterOutput update({
    required LatLng point,
    required DateTime timestamp,
    required double accuracyMeters,
  }) {
    final acc = accuracyMeters.isFinite && accuracyMeters > 0
        ? accuracyMeters
        : 5.0;

    if (!isInitialized) {
      _init(point, timestamp, acc);
      return IaeFilterOutput(
        position: point,
        velocityEastMs: 0.0,
        velocityNorthMs: 0.0,
        speedMs: 0.0,
        posVarEast: _p[0],
        posVarNorth: _p[5],
        igg3Weight: 1.0,
        rejected: false,
        nis: 0.0,
        estimatedREast: _lastREast,
        estimatedRNorth: _lastRNorth,
      );
    }

    final dt = timestamp.difference(_lastTime!).inMilliseconds / 1000.0;
    if (dt <= 0.0) {
      return IaeFilterOutput(
        position: _toLatLng(_x[0], _x[1]),
        velocityEastMs: _x[2],
        velocityNorthMs: _x[3],
        speedMs: math.sqrt(_x[2] * _x[2] + _x[3] * _x[3]),
        posVarEast: _p[0],
        posVarNorth: _p[5],
        igg3Weight: 1.0,
        rejected: false,
        nis: 0.0,
        estimatedREast: _lastREast,
        estimatedRNorth: _lastRNorth,
      );
    }

    if (dt > maxGapSec) {
      _init(point, timestamp, acc);
      return IaeFilterOutput(
        position: point,
        velocityEastMs: 0.0,
        velocityNorthMs: 0.0,
        speedMs: 0.0,
        posVarEast: _p[0],
        posVarNorth: _p[5],
        igg3Weight: 1.0,
        rejected: false,
        nis: 0.0,
        estimatedREast: _lastREast,
        estimatedRNorth: _lastRNorth,
      );
    }

    // 1. Predict x^- = F x, P^- = F P F^T + Q
    _x[0] += _x[2] * dt;
    _x[1] += _x[3] * dt;

    final pPrev = List<double>.from(_p);
    // Compute FP then (FP)F^T
    final fp = List<double>.filled(16, 0.0);
    for (int j = 0; j < 4; j++) {
      fp[0 * 4 + j] = pPrev[0 * 4 + j] + dt * pPrev[2 * 4 + j];
      fp[1 * 4 + j] = pPrev[1 * 4 + j] + dt * pPrev[3 * 4 + j];
      fp[2 * 4 + j] = pPrev[2 * 4 + j];
      fp[3 * 4 + j] = pPrev[3 * 4 + j];
    }
    for (int i = 0; i < 4; i++) {
      _p[i * 4 + 0] = fp[i * 4 + 0] + dt * fp[i * 4 + 2];
      _p[i * 4 + 1] = fp[i * 4 + 1] + dt * fp[i * 4 + 3];
      _p[i * 4 + 2] = fp[i * 4 + 2];
      _p[i * 4 + 3] = fp[i * 4 + 3];
    }

    // Continuous white-noise acceleration process covariance Q
    final qa = processAccelStd * processAccelStd;
    final dt2 = dt * dt;
    final dt3 = dt2 * dt;
    final dt4 = dt3 * dt;
    final qPos = 0.25 * dt4 * qa;
    final qCross = 0.5 * dt3 * qa;
    final qVel = dt2 * qa;
    _p[0] += qPos;
    _p[2] += qCross;
    _p[8] += qCross;
    _p[10] += qVel;
    _p[5] += qPos;
    _p[7] += qCross;
    _p[13] += qCross;
    _p[15] += qVel;

    // 2. Innovation v = z - H x^-
    final (ze, zn) = _toEnu(point);
    final ve = ze - _x[0];
    final vn = zn - _x[1];

    // Nominal measurement noise R_nom from reported accuracy
    final rNom = (acc * acc).clamp(rMinVar, rMaxVar);
    double rE = rNom;
    double rN = rNom;

    // 3. IAE (Mohamed & Schwarz 1999): estimate R_hat from PRIOR accepted innovations
    //    so a gross outlier at step k cannot self-mask by inflating C_hat_v before IGG-III.
    if (enableIae && _innovations.length >= windowSize) {
      double cEE = 0.0;
      double cNN = 0.0;
      for (final (ie, in_) in _innovations) {
        cEE += ie * ie;
        cNN += in_ * in_;
      }
      cEE /= _innovations.length;
      cNN /= _innovations.length;
      // Diagonal positive-definite projection (adaptation)
      rE = (cEE - _p[0]).clamp(rMinVar, rMaxVar);
      rN = (cNN - _p[5]).clamp(rMinVar, rMaxVar);
    }

    // 4. Innovation covariance S = H P^- H^T + R
    final s00Pre = _p[0] + rE;
    final s01Pre = _p[1];
    final s11Pre = _p[5] + rN;

    final vTilde = RobustIgg3Weight.normalizedResidual2d(
      ve: ve,
      vn: vn,
      s00: s00Pre,
      s01: s01Pre,
      s11: s11Pre,
    );
    final nis = 2.0 * vTilde * vTilde;

    double wIgg3 = 1.0;
    if (enableIgg3) {
      wIgg3 = RobustIgg3Weight.weight(vTilde, k0: igg3K0, k1: igg3K1);
      if (wIgg3 <= 1e-6) {
        // Gross outlier rejected; do NOT contaminate IAE innovation buffer
        _lastTime = timestamp;
        _lastREast = rE;
        _lastRNorth = rN;
        return IaeFilterOutput(
          position: _toLatLng(_x[0], _x[1]),
          velocityEastMs: _x[2],
          velocityNorthMs: _x[3],
          speedMs: math.sqrt(_x[2] * _x[2] + _x[3] * _x[3]),
          posVarEast: _p[0],
          posVarNorth: _p[5],
          igg3Weight: 0.0,
          rejected: true,
          nis: nis,
          estimatedREast: rE,
          estimatedRNorth: rN,
        );
      }
      rE = (rE / wIgg3).clamp(rMinVar, rMaxVar * 100.0);
      rN = (rN / wIgg3).clamp(rMinVar, rMaxVar * 100.0);
    }

    // Record accepted innovation for subsequent IAE cycles
    if (enableIae) {
      _innovations.addLast((ve, vn));
      while (_innovations.length > windowSize) {
        _innovations.removeFirst();
      }
    }

    // 5. Kalman Gain K = P^- H^T S^-1 (4x2)
    final s00 = _p[0] + rE;
    final s01 = _p[1];
    final s11 = _p[5] + rN;
    final det = s00 * s11 - s01 * s01;
    final invS00 = s11 / det;
    final invS01 = -s01 / det;
    final invS11 = s00 / det;

    final k = List<double>.filled(8, 0.0); // 4x2 row-major
    for (int i = 0; i < 4; i++) {
      final pi0 = _p[i * 4 + 0];
      final pi1 = _p[i * 4 + 1];
      k[i * 2 + 0] = pi0 * invS00 + pi1 * invS01;
      k[i * 2 + 1] = pi0 * invS01 + pi1 * invS11;
    }

    // State update: x = x^- + K v
    for (int i = 0; i < 4; i++) {
      _x[i] += k[i * 2 + 0] * ve + k[i * 2 + 1] * vn;
    }

    // Joseph-form covariance update: P = (I - K H) P^- (I - K H)^T + K R K^T
    final ikh = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      ikh[i * 4 + i] = 1.0;
      ikh[i * 4 + 0] -= k[i * 2 + 0];
      ikh[i * 4 + 1] -= k[i * 2 + 1];
    }

    final tmp = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double sum = 0.0;
        for (int c = 0; c < 4; c++) {
          sum += ikh[i * 4 + c] * _p[c * 4 + j];
        }
        tmp[i * 4 + j] = sum;
      }
    }

    final pNew = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double sum = 0.0;
        for (int c = 0; c < 4; c++) {
          sum += tmp[i * 4 + c] * ikh[j * 4 + c];
        }
        // + K R K^T (diagonal R)
        sum += k[i * 2 + 0] * rE * k[j * 2 + 0] + k[i * 2 + 1] * rN * k[j * 2 + 1];
        pNew[i * 4 + j] = sum;
      }
    }

    // Enforce exact symmetry
    for (int i = 0; i < 4; i++) {
      for (int j = i; j < 4; j++) {
        final avg = 0.5 * (pNew[i * 4 + j] + pNew[j * 4 + i]);
        _p[i * 4 + j] = avg;
        _p[j * 4 + i] = avg;
      }
    }

    _lastTime = timestamp;
    _lastREast = rE;
    _lastRNorth = rN;

    return IaeFilterOutput(
      position: _toLatLng(_x[0], _x[1]),
      velocityEastMs: _x[2],
      velocityNorthMs: _x[3],
      speedMs: math.sqrt(_x[2] * _x[2] + _x[3] * _x[3]),
      posVarEast: _p[0],
      posVarNorth: _p[5],
      igg3Weight: wIgg3,
      rejected: false,
      nis: nis,
      estimatedREast: rE,
      estimatedRNorth: rN,
    );
  }
}
