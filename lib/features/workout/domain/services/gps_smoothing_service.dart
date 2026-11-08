import 'dart:math' as math;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:latlong2/latlong.dart';

const Distance _gpsDistance = Distance();

class GpsSmoothingUpdate {
  final LatLng smoothedPoint;
  final bool shouldAppendRoutePoint;
  final bool isStationary;
  final GpsConfidence confidence;

  const GpsSmoothingUpdate({
    required this.smoothedPoint,
    required this.shouldAppendRoutePoint,
    required this.isStationary,
    required this.confidence,
  });
}

/// Filter algorithm selection for GPS trajectory smoothing.
enum GpsFilterAlgorithm {
  /// Standard 4-State Extended Kalman Filter (State: [px, py, v, theta]).
  ekf4State,

  /// Original Fixed Alpha with turn-boost filter (Historical baseline).
  fixedAlpha,
}

class GpsSmoothingService {
  final GpsFilterAlgorithm algorithm;
  final ExtendedKalmanFilter _ekf;
  final IGnssCorrectionEngine? _gnssCorrectionEngine;
  final bool enableGnssCorrection;
  final bool enableShadowMode;

  /// Duration after which a GPS absence is treated as a major blackout gap.
  static const double kGpsGapThresholdSec = 5.0;

  GpsSmoothingService({
    ExtendedKalmanFilter? ekf,
    GpsFilterAlgorithm? algorithm,
    IGnssCorrectionEngine? gnssCorrectionEngine,
    bool? enableGnssCorrection,
    bool? enableShadowMode,
  }) : algorithm =
           algorithm ??
           (kGpsFilterAlgoConfig.toLowerCase() == 'fixedalpha'
               ? GpsFilterAlgorithm.fixedAlpha
               : GpsFilterAlgorithm.ekf4State),
       enableGnssCorrection = enableGnssCorrection ?? kEnableGnssCorrection,
       enableShadowMode = enableShadowMode ?? kEnableGnssCorrectionShadowMode,
       _gnssCorrectionEngine = gnssCorrectionEngine ??
           ((enableGnssCorrection ?? kEnableGnssCorrection) || (enableShadowMode ?? kEnableGnssCorrectionShadowMode)
               ? AdaptiveGnssCorrectionEngine()
               : null),
       _ekf =
           ekf ??
           ExtendedKalmanFilter(
             processPosStd: 0.6,
             processSpeedStd: 1.2,
             processHeadingStd: 0.5,
             gnssCorrectionEngine: gnssCorrectionEngine ??
                 ((enableGnssCorrection ?? kEnableGnssCorrection) || (enableShadowMode ?? kEnableGnssCorrectionShadowMode)
                     ? AdaptiveGnssCorrectionEngine()
                     : null),
             enableGnssCorrection: enableGnssCorrection ?? kEnableGnssCorrection,
             enableShadowMode: enableShadowMode ?? kEnableGnssCorrectionShadowMode,
           );

  /// Human-readable identifier of the active smoothing algorithm.
  String get algorithmName =>
      algorithm == GpsFilterAlgorithm.ekf4State ? 'ekf_4state' : 'fixed_alpha';

  /// Resets filter state (e.g. at workout start, mode flip, or after long GPS blackout)
  void reset() {
    _ekf.reset();
    _gnssCorrectionEngine?.reset();
  }

  GpsSmoothingUpdate smoothAcceptedPoint({
    required String activityType,
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng? previousSmoothedPoint,
    required LatLng? lastSmoothedRoutePoint,
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    final confidence = _confidenceFor(
      accuracyMeters: accuracyMeters,
      speedMs: speedMs,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
    );
    final acceptedDelta = previousAcceptedPoint == null
        ? 0.0
        : _gpsDistance.distance(previousAcceptedPoint, acceptedPoint);
    final isStationary =
        previousAcceptedPoint != null &&
        gpsGapDurationSec <= 0 &&
        acceptedDelta <= _stationaryRadiusMeters(activityType) &&
        (speedMs <= 0.8 || timeDeltaSec >= 1.0);

    final smoothedPoint = _smoothPoint(
      acceptedPoint: acceptedPoint,
      previousAcceptedPoint: previousAcceptedPoint,
      previousSmoothedPoint: previousSmoothedPoint,
      confidence: confidence,
      activityType: activityType,
      isStationary: isStationary,
      acceptedDelta: acceptedDelta,
      accuracyMeters: accuracyMeters,
      speedMs: speedMs,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
    );

    final appendThreshold = _minAppendDistanceMeters(activityType);
    final routeDelta = lastSmoothedRoutePoint == null
        ? double.infinity
        : _gpsDistance.distance(lastSmoothedRoutePoint, smoothedPoint);
    final shouldAppendRoutePoint =
        gpsGapDurationSec > kGpsGapThresholdSec ||
        lastSmoothedRoutePoint == null ||
        (!isStationary &&
            routeDelta >= appendThreshold &&
            confidence != GpsConfidence.low);

    return GpsSmoothingUpdate(
      smoothedPoint: smoothedPoint,
      shouldAppendRoutePoint: shouldAppendRoutePoint,
      isStationary: isStationary,
      confidence: confidence,
    );
  }

  GpsConfidence _confidenceFor({
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    if (gpsGapDurationSec > kGpsGapThresholdSec || accuracyMeters > 30.0) {
      return GpsConfidence.low;
    }
    if (accuracyMeters > 15.0 || timeDeltaSec > 2.5 || speedMs <= 0.4) {
      return GpsConfidence.medium;
    }
    return GpsConfidence.high;
  }

  LatLng _smoothPoint({
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng? previousSmoothedPoint,
    required GpsConfidence confidence,
    required String activityType,
    required bool isStationary,
    required double acceptedDelta,
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required double gpsGapDurationSec,
  }) {
    if (previousSmoothedPoint == null ||
        gpsGapDurationSec > kGpsGapThresholdSec) {
      _ekf.reset();
      _ekf.init(
        initialPoint: acceptedPoint,
        initialAccuracyMeters: accuracyMeters,
        initialSpeedMs: speedMs,
      );
      return acceptedPoint;
    }

    if (isStationary && acceptedDelta < _stationaryFreezeMeters(activityType)) {
      return previousSmoothedPoint;
    }

    if (algorithm == GpsFilterAlgorithm.fixedAlpha) {
      return _smoothPointFixedAlpha(
        acceptedPoint: acceptedPoint,
        previousAcceptedPoint: previousAcceptedPoint,
        previousSmoothedPoint: previousSmoothedPoint,
        confidence: confidence,
        acceptedDelta: acceptedDelta,
      );
    }

    // Default: 4-State Extended Kalman Filter (EKF) Core
    return _smoothPointEkf(
      acceptedPoint: acceptedPoint,
      previousAcceptedPoint: previousAcceptedPoint,
      accuracyMeters: accuracyMeters,
      speedMs: speedMs,
      timeDeltaSec: timeDeltaSec,
      activityType: activityType,
    );
  }

  LatLng _smoothPointEkf({
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required double accuracyMeters,
    required double speedMs,
    required double timeDeltaSec,
    required String activityType,
  }) {
    final headingDeg = previousAcceptedPoint != null
        ? _bearing(previousAcceptedPoint, acceptedPoint)
        : null;

    final estimate = _ekf.update(
      measurementPoint: acceptedPoint,
      accuracyMeters: accuracyMeters,
      timeDeltaSec: timeDeltaSec,
      speedMs: speedMs >= 0.0 ? speedMs : null,
      headingDeg: headingDeg,
      activityType: activityType,
    );

    return estimate.position;
  }

  LatLng _smoothPointFixedAlpha({
    required LatLng acceptedPoint,
    required LatLng? previousAcceptedPoint,
    required LatLng previousSmoothedPoint,
    required GpsConfidence confidence,
    required double acceptedDelta,
  }) {
    var alpha = switch (confidence) {
      GpsConfidence.high => 0.72,
      GpsConfidence.medium => 0.52,
      GpsConfidence.low => 0.34,
    };

    if (previousAcceptedPoint != null) {
      final turnDelta = _bearingDelta(
        _bearing(previousAcceptedPoint, acceptedPoint),
        _bearing(previousSmoothedPoint, acceptedPoint),
      );
      if (turnDelta > 28.0 && acceptedDelta > 4.0) {
        alpha = math.max(alpha, 0.82);
      }
    }

    return LatLng(
      previousSmoothedPoint.latitude * (1 - alpha) +
          acceptedPoint.latitude * alpha,
      previousSmoothedPoint.longitude * (1 - alpha) +
          acceptedPoint.longitude * alpha,
    );
  }

  double _bearingDelta(double a, double b) {
    final delta = (a - b).abs();
    return delta > 180 ? 360 - delta : delta;
  }

  double _minAppendDistanceMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 2.0;
      case 'cycling':
        return 4.0;
      case 'running':
      default:
        return 2.5;
    }
  }

  double _stationaryRadiusMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 2.2;
      case 'cycling':
        return 3.5;
      case 'running':
      default:
        return 2.6;
    }
  }

  double _stationaryFreezeMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 1.6;
      case 'cycling':
        return 2.5;
      case 'running':
      default:
        return 2.0;
    }
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }
}
