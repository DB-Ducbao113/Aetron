import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

import '../trajectory_preprocessing/kinematic_limits.dart';
import '../trajectory_preprocessing/trajectory_sample.dart';
import 'trajectory_reconstruction_interface.dart';
import 'trajectory_reconstruction_models.dart';

/// Production-ready Autonomous Kinematic Trajectory Reconstruction Engine.
///
/// Literature Grounding:
/// - Dariusz Czerwiński, Michał Wydra, Albert Rachwał, Weronika Jachuła, Jarosław Zubrzycki (2026).
///   "A Multi-Stage Framework for GPS Trajectory Reconstruction Using Consumer-Grade Wearable Devices."
///   Applied Sciences (MDPI), 16(18), 8972. DOI: 10.3390/app16188972.
/// - F. N. Fritsch and R. E. Carlson (1980).
///   "Monotone Piecewise Cubic Interpolation."
///   SIAM Journal on Numerical Analysis, 17(2), pp. 238–246. DOI: 10.1137/0717021.
class KinematicTrajectoryReconstructionEngine implements ITrajectoryReconstructionEngine {
  static const double _earthRadiusMeters = 6378137.0;
  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  /// Maximum time gap (seconds) across which monotonic spline interpolation is physically meaningful.
  /// Beyond 15 seconds without observations, human trajectories can branch or detour unpredictably;
  /// fabricating intermediate coordinates across such gaps would create phantom routes.
  final double maxRecoverableGapSec;

  /// Minimum gap duration (seconds) before intermediate interpolation triggers.
  final double minInterpolationGapSec;

  const KinematicTrajectoryReconstructionEngine({
    this.maxRecoverableGapSec = 15.0,
    this.minInterpolationGapSec = 2.0,
  });

  @override
  TrajectoryReconstructionResult reconstructTrajectory({
    required List<ProcessedTrajectoryPoint> points,
    required String activityType,
    double samplingStepSec = 1.0,
    ReconstructionMethod method = ReconstructionMethod.monotonePchip,
  }) {
    // Exclude points rejected by prior kinematic preprocessing
    final validPoints = points.any((p) => !p.isAccepted)
        ? points.where((p) => p.isAccepted).toList(growable: false)
        : points;

    if (validPoints.isEmpty) {
      return TrajectoryReconstructionResult(
        points: const [],
        originalPointCount: 0,
        reconstructedPointCount: 0,
        interpolatedPointCount: 0,
        indeterminateGapCount: 0,
        totalReconstructedDistanceMeters: 0.0,
        indeterminateChordDistanceMeters: 0.0,
        method: method,
      );
    }

    final limits = KinematicLimits.forActivity(activityType);
    final reconstructedList = <ReconstructedPoint>[];
    const distanceCalculator = Distance();

    var totalReconstructedDist = 0.0;
    var totalIndeterminateChordDist = 0.0;
    var interpolatedCount = 0;
    var indeterminateGapCount = 0;

    // 1. Initial point
    final p0 = validPoints.first;
    reconstructedList.add(ReconstructedPoint(
      point: p0.point,
      timestamp: p0.timestamp,
      impliedSpeedMs: p0.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs),
      impliedHeadingDeg: p0.forwardBearingDeg,
      elevationMeters: p0.rawSample.altitudeMeters ?? 0.0,
      isInterpolated: false,
      gapType: ReconstructionGapType.nominalDense,
    ));

    // 2. Iterate adjacent pairs
    for (var i = 0; i < validPoints.length - 1; i++) {
      final curr = validPoints[i];
      final next = validPoints[i + 1];

      // If either point is a stay point, maintain centroid without artificial motion
      if (curr.isStayPoint || next.isStayPoint) {
        reconstructedList.add(ReconstructedPoint(
          point: next.point,
          timestamp: next.timestamp,
          impliedSpeedMs: 0.0,
          impliedHeadingDeg: null,
          elevationMeters: next.rawSample.altitudeMeters ?? 0.0,
          isInterpolated: false,
          gapType: ReconstructionGapType.stationaryDwell,
        ));
        continue;
      }

      final dtSec = next.timestamp.difference(curr.timestamp).inMilliseconds / 1000.0;
      final stepDist = distanceCalculator.distance(curr.point, next.point);

      if (dtSec <= minInterpolationGapSec) {
        // Nominal high-frequency stream: append directly
        totalReconstructedDist += stepDist;
        reconstructedList.add(ReconstructedPoint(
          point: next.point,
          timestamp: next.timestamp,
          impliedSpeedMs: next.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs),
          impliedHeadingDeg: next.forwardBearingDeg,
          elevationMeters: next.rawSample.altitudeMeters ?? 0.0,
          isInterpolated: false,
          gapType: ReconstructionGapType.nominalDense,
        ));
      } else if (dtSec > minInterpolationGapSec && dtSec <= maxRecoverableGapSec) {
        // Recoverable sparse gap: apply selected method (Monotone PCHIP or Linear chord)
        final intermediatePoints = method == ReconstructionMethod.monotonePchip
            ? _interpolatePchip(
                pStart: curr,
                pEnd: next,
                dtSec: dtSec,
                stepSec: samplingStepSec,
                limits: limits,
              )
            : _interpolateLinear(
                pStart: curr,
                pEnd: next,
                dtSec: dtSec,
                stepSec: samplingStepSec,
                limits: limits,
              );

        var prevInterpPoint = curr.point;
        for (final interp in intermediatePoints) {
          final d = distanceCalculator.distance(prevInterpPoint, interp.point);
          totalReconstructedDist += d;
          prevInterpPoint = interp.point;
          reconstructedList.add(interp);
          interpolatedCount++;
        }

        // Append actual endpoint
        final lastSegmentDist = distanceCalculator.distance(prevInterpPoint, next.point);
        totalReconstructedDist += lastSegmentDist;
        reconstructedList.add(ReconstructedPoint(
          point: next.point,
          timestamp: next.timestamp,
          impliedSpeedMs: next.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs),
          impliedHeadingDeg: next.forwardBearingDeg,
          elevationMeters: next.rawSample.altitudeMeters ?? 0.0,
          isInterpolated: false,
          gapType: ReconstructionGapType.sparseRecoverable,
        ));
      } else {
        // Indeterminate severe blackout (dt > 15s)
        indeterminateGapCount++;
        totalIndeterminateChordDist += stepDist;

        // Isolate discontinuity: do NOT synthesize fictitious coordinates across unknown territory
        reconstructedList.add(ReconstructedPoint(
          point: next.point,
          timestamp: next.timestamp,
          impliedSpeedMs: next.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs),
          impliedHeadingDeg: next.forwardBearingDeg,
          elevationMeters: next.rawSample.altitudeMeters ?? 0.0,
          isInterpolated: false,
          gapType: ReconstructionGapType.indeterminateOutage,
        ));
      }
    }

    return TrajectoryReconstructionResult(
      points: reconstructedList,
      originalPointCount: points.length,
      reconstructedPointCount: reconstructedList.length,
      interpolatedPointCount: interpolatedCount,
      indeterminateGapCount: indeterminateGapCount,
      totalReconstructedDistanceMeters: totalReconstructedDist,
      indeterminateChordDistanceMeters: totalIndeterminateChordDist,
      method: method,
    );
  }

  /// Generates intermediate points using Linear Chord Interpolation.
  List<ReconstructedPoint> _interpolateLinear({
    required ProcessedTrajectoryPoint pStart,
    required ProcessedTrajectoryPoint pEnd,
    required double dtSec,
    required double stepSec,
    required KinematicLimits limits,
  }) {
    final intermediate = <ReconstructedPoint>[];
    final steps = (dtSec / stepSec).floor();
    if (steps <= 1) return intermediate;

    final alt0 = pStart.rawSample.altitudeMeters ?? 0.0;
    final alt1 = pEnd.rawSample.altitudeMeters ?? 0.0;

    for (var s = 1; s < steps; s++) {
      final tau = (s * stepSec) / dtSec;
      final lat = pStart.latitude + (pEnd.latitude - pStart.latitude) * tau;
      final lng = pStart.longitude + (pEnd.longitude - pStart.longitude) * tau;
      final alt = alt0 + (alt1 - alt0) * tau;
      final t = pStart.timestamp.add(Duration(milliseconds: (s * stepSec * 1000).round()));

      intermediate.add(ReconstructedPoint(
        point: LatLng(lat, lng),
        timestamp: t,
        impliedSpeedMs: pStart.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs),
        impliedHeadingDeg: pStart.forwardBearingDeg,
        elevationMeters: alt,
        isInterpolated: true,
        gapType: ReconstructionGapType.sparseRecoverable,
      ));
    }
    return intermediate;
  }

  /// Generates intermediate points using Monotone Piecewise Cubic Hermite Interpolation (PCHIP).
  ///
  /// Guarantees C1 continuity and strictly enforces the Fritsch-Carlson monotonicity
  /// criteria on local projected coordinates (x, y), preventing unphysical overshoot or loop artifacts.
  List<ReconstructedPoint> _interpolatePchip({
    required ProcessedTrajectoryPoint pStart,
    required ProcessedTrajectoryPoint pEnd,
    required double dtSec,
    required double stepSec,
    required KinematicLimits limits,
  }) {
    final meanLatRad = (pStart.latitude + pEnd.latitude) * 0.5 * _degToRad;
    final cosMeanLat = math.cos(meanLatRad);

    // Project endpoint coordinates relative to pStart in meters
    final dxTotal = (pEnd.longitude - pStart.longitude) * _degToRad * cosMeanLat * _earthRadiusMeters;
    final dyTotal = (pEnd.latitude - pStart.latitude) * _degToRad * _earthRadiusMeters;

    // Secant slope velocities (average velocity across gap)
    final secantVx = dxTotal / dtSec;
    final secantVy = dyTotal / dtSec;

    // Endpoint boundary velocities
    final v0 = pStart.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs);
    final v1 = pEnd.impliedSpeedMs.clamp(0.0, limits.maxSpeedMs);

    final theta0Rad = (pStart.forwardBearingDeg != null)
        ? pStart.forwardBearingDeg! * _degToRad
        : math.atan2(dxTotal, dyTotal);
    final theta1Rad = (pEnd.forwardBearingDeg != null)
        ? pEnd.forwardBearingDeg! * _degToRad
        : math.atan2(dxTotal, dyTotal);

    var vx0 = v0 * math.sin(theta0Rad);
    var vy0 = v0 * math.cos(theta0Rad);
    var vx1 = v1 * math.sin(theta1Rad);
    var vy1 = v1 * math.cos(theta1Rad);

    // Fritsch-Carlson Monotonicity Limiter for Coordinate X
    if (dxTotal.abs() < 1e-4) {
      vx0 = 0.0;
      vx1 = 0.0;
    } else {
      final alphaX = vx0 / secantVx;
      final betaX = vx1 / secantVx;
      if (alphaX < 0) vx0 = 0.0;
      if (betaX < 0) vx1 = 0.0;
      final hypX = (alphaX * alphaX) + (betaX * betaX);
      if (hypX > 9.0) {
        final tau = 3.0 / math.sqrt(hypX);
        vx0 = tau * alphaX * secantVx;
        vx1 = tau * betaX * secantVx;
      }
    }

    // Fritsch-Carlson Monotonicity Limiter for Coordinate Y
    if (dyTotal.abs() < 1e-4) {
      vy0 = 0.0;
      vy1 = 0.0;
    } else {
      final alphaY = vy0 / secantVy;
      final betaY = vy1 / secantVy;
      if (alphaY < 0) vy0 = 0.0;
      if (betaY < 0) vy1 = 0.0;
      final hypY = (alphaY * alphaY) + (betaY * betaY);
      if (hypY > 9.0) {
        final tau = 3.0 / math.sqrt(hypY);
        vy0 = tau * alphaY * secantVy;
        vy1 = tau * betaY * secantVy;
      }
    }

    final alt0 = pStart.rawSample.altitudeMeters ?? 0.0;
    final alt1 = pEnd.rawSample.altitudeMeters ?? 0.0;

    final results = <ReconstructedPoint>[];
    final stepsCount = (dtSec / stepSec).floor();

    for (var k = 1; k < stepsCount; k++) {
      final t = k * stepSec;
      final u = t / dtSec; // Normalized parameter [0, 1]

      // Standard Hermite basis functions (with pStart as local coordinate origin: x0 = 0, y0 = 0)
      final u2 = u * u;
      final u3 = u2 * u;
      final h10 = u3 - (2.0 * u2) + u;
      final h01 = (-2.0 * u3) + (3.0 * u2);
      final h11 = u3 - u2;

      // Position evaluation
      final xInterp = (h10 * dtSec * vx0) + (h01 * dxTotal) + (h11 * dtSec * vx1);
      final yInterp = (h10 * dtSec * vy0) + (h01 * dyTotal) + (h11 * dtSec * vy1);

      // Derivative evaluation for instantaneous speed and heading
      final dh10 = (3.0 * u2) - (4.0 * u) + 1.0;
      final dh01 = ((-6.0 * u2) + (6.0 * u)) / dtSec;
      final dh11 = (3.0 * u2) - (2.0 * u);

      final vxInterp = (dh10 * vx0) + (dh01 * dxTotal) + (dh11 * vx1);
      final vyInterp = (dh10 * vy0) + (dh01 * dyTotal) + (dh11 * vy1);

      final interpSpeed = math.sqrt(vxInterp * vxInterp + vyInterp * vyInterp).clamp(0.0, limits.maxSpeedMs);
      var interpHeadingDeg = math.atan2(vxInterp, vyInterp) * _radToDeg;
      if (interpHeadingDeg < 0) interpHeadingDeg += 360.0;

      // Unproject back to geodetic WGS-84
      final latInterp = pStart.latitude + (yInterp / _earthRadiusMeters) * _radToDeg;
      final lngInterp = pStart.longitude + (xInterp / (_earthRadiusMeters * cosMeanLat)) * _radToDeg;
      final altInterp = alt0 + (alt1 - alt0) * u;
      final timeInterp = pStart.timestamp.add(Duration(milliseconds: (t * 1000).round()));

      results.add(ReconstructedPoint(
        point: LatLng(latInterp, lngInterp),
        timestamp: timeInterp,
        impliedSpeedMs: interpSpeed,
        impliedHeadingDeg: interpHeadingDeg,
        elevationMeters: altInterp,
        isInterpolated: true,
        gapType: ReconstructionGapType.sparseRecoverable,
      ));
    }

    return results;
  }
}
