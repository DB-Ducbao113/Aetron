import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'stop_detector_interface.dart';

/// 2-Mode Interacting Multiple Model (IMM) Stop/Move Detector:
/// Blom, H. A. P., & Bar-Shalom, Y. (1988).
/// "The interacting multiple model algorithm for systems with Markovian
/// switching coefficients." IEEE TAC 33(8), 780–783. DOI: 10.1109/9.1299.
///
/// Modes:
/// - Mode 0 (Stationary): position random-walk with near-zero velocity & small `qStationary`.
/// - Mode 1 (Moving): 4-state constant-velocity model with process acceleration `qMoving`.
///
/// Decision rule (MAP): `isStopped = muStationary >= 0.5`.
/// Hyperparameters (`pStayStationary`, `pStayMoving`, `qStationary`, `qMoving`)
/// are not fixed in [BB88] and must be chosen on a validation split.
class ImmStopDetector implements StopDetector {
  static const double _metersPerDegLat = 111320.0;

  final double pStayStationary;
  final double pStayMoving;
  final double qStationaryStd;
  final double qMovingAccelStd;
  final double maxGapSec;

  LatLng? _origin;
  DateTime? _lastTime;

  // Mode probabilities: [stationary, moving], sum = 1.0
  double _mu0 = 0.5;
  double _mu1 = 0.5;

  // Mode 0 state [e, n, ve, vn] and diagonal/full 4x4 covariance
  final List<double> _x0 = List<double>.filled(4, 0.0);
  final List<double> _p0 = List<double>.filled(16, 0.0);

  // Mode 1 state [e, n, ve, vn] and 4x4 covariance
  final List<double> _x1 = List<double>.filled(4, 0.0);
  final List<double> _p1 = List<double>.filled(16, 0.0);

  bool _wasStopped = false;
  DateTime? _onsetTime;

  ImmStopDetector({
    this.pStayStationary = 0.96,
    this.pStayMoving = 0.96,
    this.qStationaryStd = 0.05,
    this.qMovingAccelStd = 1.2,
    this.maxGapSec = 300.0,
  });

  double get stationaryProbability => _mu0;
  double get movingProbability => _mu1;

  @override
  void reset() {
    _origin = null;
    _lastTime = null;
    _mu0 = 0.5;
    _mu1 = 0.5;
    for (int i = 0; i < 4; i++) {
      _x0[i] = 0.0;
      _x1[i] = 0.0;
    }
    for (int i = 0; i < 16; i++) {
      _p0[i] = 0.0;
      _p1[i] = 0.0;
    }
    _wasStopped = false;
    _onsetTime = null;
  }

  (double, double) _toEnu(LatLng pt) {
    final o = _origin!;
    final cosLat = math.cos(o.latitude * math.pi / 180.0);
    return (
      (pt.longitude - o.longitude) * _metersPerDegLat * cosLat,
      (pt.latitude - o.latitude) * _metersPerDegLat,
    );
  }

  void _init(LatLng point, DateTime timestamp, double acc) {
    _origin = point;
    _lastTime = timestamp;
    _mu0 = 0.5;
    _mu1 = 0.5;
    final r0 = math.max(acc * acc, 4.0);
    for (int i = 0; i < 4; i++) {
      _x0[i] = 0.0;
      _x1[i] = 0.0;
    }
    for (int i = 0; i < 16; i++) {
      _p0[i] = 0.0;
      _p1[i] = 0.0;
    }
    _p0[0] = r0;
    _p0[5] = r0;
    _p0[10] = 0.04;
    _p0[15] = 0.04;

    _p1[0] = r0;
    _p1[5] = r0;
    _p1[10] = 4.0;
    _p1[15] = 4.0;
    _wasStopped = false;
    _onsetTime = null;
  }

  /// Runs a single mode-matched Kalman predict+update and returns Gaussian log-likelihood.
  double _modeStep({
    required List<double> x,
    required List<double> p,
    required double dt,
    required bool isStationaryMode,
    required double ze,
    required double zn,
    required double rVar,
  }) {
    // Predict
    if (isStationaryMode) {
      // Zero-velocity stationary dynamics: position stays constant, velocity decays to 0
      x[2] = 0.0;
      x[3] = 0.0;
      final qPos = qStationaryStd * qStationaryStd * dt;
      p[0] += qPos;
      p[5] += qPos;
      p[2] = 0.0;
      p[8] = 0.0;
      p[7] = 0.0;
      p[13] = 0.0;
      p[10] = 0.01;
      p[15] = 0.01;
    } else {
      x[0] += x[2] * dt;
      x[1] += x[3] * dt;
      final pPrev = List<double>.from(p);
      final fp = List<double>.filled(16, 0.0);
      for (int j = 0; j < 4; j++) {
        fp[0 * 4 + j] = pPrev[0 * 4 + j] + dt * pPrev[2 * 4 + j];
        fp[1 * 4 + j] = pPrev[1 * 4 + j] + dt * pPrev[3 * 4 + j];
        fp[2 * 4 + j] = pPrev[2 * 4 + j];
        fp[3 * 4 + j] = pPrev[3 * 4 + j];
      }
      for (int i = 0; i < 4; i++) {
        p[i * 4 + 0] = fp[i * 4 + 0] + dt * fp[i * 4 + 2];
        p[i * 4 + 1] = fp[i * 4 + 1] + dt * fp[i * 4 + 3];
        p[i * 4 + 2] = fp[i * 4 + 2];
        p[i * 4 + 3] = fp[i * 4 + 3];
      }
      final qa = qMovingAccelStd * qMovingAccelStd;
      final dt2 = dt * dt;
      final dt3 = dt2 * dt;
      final dt4 = dt3 * dt;
      p[0] += 0.25 * dt4 * qa;
      p[2] += 0.5 * dt3 * qa;
      p[8] += 0.5 * dt3 * qa;
      p[10] += dt2 * qa;
      p[5] += 0.25 * dt4 * qa;
      p[7] += 0.5 * dt3 * qa;
      p[13] += 0.5 * dt3 * qa;
      p[15] += dt2 * qa;
    }

    // Innovation
    final ve = ze - x[0];
    final vn = zn - x[1];
    final s00 = p[0] + rVar;
    final s01 = p[1];
    final s11 = p[5] + rVar;
    final det = math.max(s00 * s11 - s01 * s01, 1e-9);
    final inv00 = s11 / det;
    final inv01 = -s01 / det;
    final inv11 = s00 / det;
    final d2 = ve * (inv00 * ve + inv01 * vn) + vn * (inv01 * ve + inv11 * vn);

    // Gaussian log-likelihood: -0.5 * (2*ln(2*pi) + ln(det(S)) + d2)
    final logLik = -0.5 * (2.0 * math.log(2.0 * math.pi) + math.log(det) + d2);

    // Kalman update
    final k = List<double>.filled(8, 0.0);
    for (int i = 0; i < 4; i++) {
      final pi0 = p[i * 4 + 0];
      final pi1 = p[i * 4 + 1];
      k[i * 2 + 0] = pi0 * inv00 + pi1 * inv01;
      k[i * 2 + 1] = pi0 * inv01 + pi1 * inv11;
    }
    for (int i = 0; i < 4; i++) {
      x[i] += k[i * 2 + 0] * ve + k[i * 2 + 1] * vn;
    }
    if (isStationaryMode) {
      x[2] = 0.0;
      x[3] = 0.0;
    }

    // Joseph-form covariance update
    final ikh = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      ikh[i * 4 + i] = 1.0;
      ikh[i * 4 + 0] -= k[i * 2 + 0];
      ikh[i * 4 + 1] -= k[i * 2 + 1];
    }
    final tmp = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double s = 0.0;
        for (int c = 0; c < 4; c++) {
          s += ikh[i * 4 + c] * p[c * 4 + j];
        }
        tmp[i * 4 + j] = s;
      }
    }
    for (int i = 0; i < 4; i++) {
      for (int j = i; j < 4; j++) {
        double s = 0.0;
        for (int c = 0; c < 4; c++) {
          s += tmp[i * 4 + c] * ikh[j * 4 + c];
        }
        s += k[i * 2 + 0] * rVar * k[j * 2 + 0] + k[i * 2 + 1] * rVar * k[j * 2 + 1];
        p[i * 4 + j] = s;
        p[j * 4 + i] = s;
      }
    }

    return logLik;
  }

  @override
  StopDetectionUpdate update({
    required LatLng point,
    required DateTime timestamp,
    required double accuracyMeters,
    double? speedMs,
  }) {
    final acc = accuracyMeters.isFinite && accuracyMeters > 0 ? accuracyMeters : 5.0;
    if (_origin == null || _lastTime == null) {
      _init(point, timestamp, acc);
      return const StopDetectionUpdate(
        isStopped: false,
        stopProbability: 0.5,
        transitionedToStop: false,
        transitionedToMove: false,
      );
    }

    final dt = timestamp.difference(_lastTime!).inMilliseconds / 1000.0;
    if (dt <= 0.0) {
      return StopDetectionUpdate(
        isStopped: _wasStopped,
        stopProbability: _mu0,
        transitionedToStop: false,
        transitionedToMove: false,
        stopOnsetTime: _onsetTime,
      );
    }
    if (dt > maxGapSec) {
      _init(point, timestamp, acc);
      return const StopDetectionUpdate(
        isStopped: false,
        stopProbability: 0.5,
        transitionedToStop: false,
        transitionedToMove: false,
      );
    }

    // Step 1: IMM Interaction / Mixing (Blom & Bar-Shalom 1988)
    final p00 = pStayStationary;
    final p01 = 1.0 - pStayStationary;
    final p10 = 1.0 - pStayMoving;
    final p11 = pStayMoving;

    final c0 = (p00 * _mu0 + p10 * _mu1).clamp(1e-9, 1.0);
    final c1 = (p01 * _mu0 + p11 * _mu1).clamp(1e-9, 1.0);

    final mu00 = (p00 * _mu0) / c0;
    final mu10 = (p10 * _mu1) / c0;
    final mu01 = (p01 * _mu0) / c1;
    final mu11 = (p11 * _mu1) / c1;

    final mixX0 = List<double>.generate(4, (i) => mu00 * _x0[i] + mu10 * _x1[i]);
    final mixX1 = List<double>.generate(4, (i) => mu01 * _x0[i] + mu11 * _x1[i]);

    List<double> mixCov(double w0, double w1, List<double> mx) {
      final res = List<double>.filled(16, 0.0);
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          final d0i = _x0[i] - mx[i];
          final d0j = _x0[j] - mx[j];
          final d1i = _x1[i] - mx[i];
          final d1j = _x1[j] - mx[j];
          res[i * 4 + j] =
              w0 * (_p0[i * 4 + j] + d0i * d0j) + w1 * (_p1[i * 4 + j] + d1i * d1j);
        }
      }
      return res;
    }

    final mixP0 = mixCov(mu00, mu10, mixX0);
    final mixP1 = mixCov(mu01, mu11, mixX1);

    // Step 2: Mode-matched Kalman filtering
    final (ze, zn) = _toEnu(point);
    final rVar = math.max(acc * acc, 4.0);

    final ll0 = _modeStep(
      x: mixX0,
      p: mixP0,
      dt: dt,
      isStationaryMode: true,
      ze: ze,
      zn: zn,
      rVar: rVar,
    );
    final ll1 = _modeStep(
      x: mixX1,
      p: mixP1,
      dt: dt,
      isStationaryMode: false,
      ze: ze,
      zn: zn,
      rVar: rVar,
    );

    // Copy updated mode states back
    for (int i = 0; i < 4; i++) {
      _x0[i] = mixX0[i];
      _x1[i] = mixX1[i];
    }
    for (int i = 0; i < 16; i++) {
      _p0[i] = mixP0[i];
      _p1[i] = mixP1[i];
    }

    // Step 3: Mode probability update (log-sum-exp stabilized)
    final logPost0 = ll0 + math.log(c0);
    final logPost1 = ll1 + math.log(c1);
    final mLog = math.max(logPost0, logPost1);
    final e0 = math.exp(logPost0 - mLog);
    final e1 = math.exp(logPost1 - mLog);
    _mu0 = (e0 / (e0 + e1)).clamp(1e-6, 1.0 - 1e-6);
    _mu1 = 1.0 - _mu0;

    _lastTime = timestamp;

    // Step 4: MAP mode decision (no ad-hoc threshold)
    final stoppedNow = _mu0 >= 0.5;
    final toStop = stoppedNow && !_wasStopped;
    final toMove = !stoppedNow && _wasStopped;
    if (toStop) _onsetTime = timestamp;
    if (toMove) _onsetTime = null;
    _wasStopped = stoppedNow;

    return StopDetectionUpdate(
      isStopped: stoppedNow,
      stopProbability: _mu0,
      transitionedToStop: toStop,
      transitionedToMove: toMove,
      stopOnsetTime: _onsetTime,
    );
  }
}
