import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../ekf/innovation_adaptive_filter.dart';
import '../stop_detection/imm_stop_detector.dart';
import 'state_estimator.dart';

/// SDD-08: Unified Recursive Bayesian State Estimator integrating:
/// - 4-state CV Kalman + IGG-III [Y01] + IAE [MS99] (`InnovationAdaptiveKalmanFilter`)
/// - 2-mode IMM Stationary/Moving [BB88] (`ImmStopDetector`)
/// - Optional PDR speed dead-reckoning update during GNSS outages
/// - Optional observational Indoor/Outdoor GNSS gating
///
/// Architectural disclosure:
/// Individual mathematical components follow their respective papers; the
/// unified integration and gating rules are Aetron's system architecture,
/// evaluated via ablation (H1–H4) rather than claimed as a single-paper reproduction.
class UnifiedBayesianEstimator implements StateEstimator {
  static const double _metersPerDegLat = 111320.0;

  final bool enableIgg3;
  final bool enableIae;
  final bool enableImm;
  final bool enablePdrFusion;
  final bool enableIodGating;
  final double indoorAccuracyInflation;

  late final InnovationAdaptiveKalmanFilter _gnssFilter;
  late final ImmStopDetector _imm;

  StateEstimate? _lastEstimate;
  IodContextHint? _lastIod;
  double _lastHeadingRad = 0.0;
  DateTime? _lastPdrTime;

  UnifiedBayesianEstimator({
    this.enableIgg3 = true,
    this.enableIae = true,
    this.enableImm = true,
    this.enablePdrFusion = true,
    this.enableIodGating = false,
    int iaeWindowSize = 10,
    this.indoorAccuracyInflation = 5.0,
  }) {
    _gnssFilter = InnovationAdaptiveKalmanFilter(
      windowSize: iaeWindowSize,
      enableIae: enableIae,
      enableIgg3: enableIgg3,
    );
    _imm = ImmStopDetector();
  }

  @override
  StateEstimate? get estimate => _lastEstimate;

  @override
  ModeProbabilities get modes => enableImm
      ? ModeProbabilities(
          stationary: _imm.stationaryProbability,
          moving: _imm.movingProbability,
        )
      : const ModeProbabilities(stationary: 0.0, moving: 1.0);

  @override
  void reset() {
    _gnssFilter.reset();
    _imm.reset();
    _lastEstimate = null;
    _lastIod = null;
    _lastHeadingRad = 0.0;
    _lastPdrTime = null;
  }

  @override
  void predict(DateTime t) {
    final prev = _lastEstimate;
    if (prev == null) return;
    final dt = t.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (dt <= 0.0 || dt > 10.0) return;

    final cosLat = math.cos(prev.position.latitude * math.pi / 180.0).clamp(1e-6, 1.0);
    final newLat = prev.position.latitude + (prev.velocityNorthMs * dt) / _metersPerDegLat;
    final newLng = prev.position.longitude +
        (prev.velocityEastMs * dt) / (_metersPerDegLat * cosLat);

    _lastEstimate = StateEstimate(
      position: LatLng(newLat, newLng),
      velocityEastMs: prev.velocityEastMs,
      velocityNorthMs: prev.velocityNorthMs,
      speedMs: prev.speedMs,
      nis: prev.nis,
      igg3Weight: prev.igg3Weight,
      gnssRejected: false,
      timestamp: t,
    );
  }

  @override
  void updateEnvironment(IodContextHint hint) {
    _lastIod = hint;
  }

  @override
  void updateGnss(GnssObs obs) {
    double effectiveAcc = obs.accuracyMeters;
    if (enableIodGating && _lastIod != null && _lastIod!.isIndoor) {
      effectiveAcc *= indoorAccuracyInflation;
    }

    final out = _gnssFilter.update(
      point: obs.point,
      timestamp: obs.timestamp,
      accuracyMeters: effectiveAcc,
    );

    if (enableImm) {
      _imm.update(
        point: out.position,
        timestamp: obs.timestamp,
        accuracyMeters: effectiveAcc,
        speedMs: obs.speedMs,
      );
    }

    if (out.speedMs > 0.4) {
      _lastHeadingRad = math.atan2(out.velocityEastMs, out.velocityNorthMs);
    }

    _lastEstimate = StateEstimate(
      position: out.position,
      velocityEastMs: out.velocityEastMs,
      velocityNorthMs: out.velocityNorthMs,
      speedMs: out.speedMs,
      nis: out.nis,
      igg3Weight: out.igg3Weight,
      gnssRejected: out.rejected,
      timestamp: obs.timestamp,
    );
  }

  @override
  void updatePdr(PdrObs obs) {
    if (!enablePdrFusion) return;
    final prev = _lastEstimate;
    if (prev == null) return;

    final refTime = _lastPdrTime != null && _lastPdrTime!.isAfter(prev.timestamp)
        ? _lastPdrTime!
        : prev.timestamp;
    final dt = obs.timestamp.difference(refTime).inMilliseconds / 1000.0;
    _lastPdrTime = obs.timestamp;
    if (dt <= 0.0 || dt > 5.0) return;

    final heading = obs.headingRad ?? _lastHeadingRad;
    final vPdr = obs.speedMs;
    final ve = vPdr * math.sin(heading);
    final vn = vPdr * math.cos(heading);

    // Dead-reckon position forward using PDR speed along heading
    final cosLat = math.cos(prev.position.latitude * math.pi / 180.0).clamp(1e-6, 1.0);
    final newLat = prev.position.latitude + (vn * dt) / _metersPerDegLat;
    final newLng = prev.position.longitude + (ve * dt) / (_metersPerDegLat * cosLat);

    _lastEstimate = StateEstimate(
      position: LatLng(newLat, newLng),
      velocityEastMs: ve,
      velocityNorthMs: vn,
      speedMs: vPdr,
      nis: prev.nis,
      igg3Weight: prev.igg3Weight,
      gnssRejected: false,
      timestamp: obs.timestamp,
    );
  }
}
