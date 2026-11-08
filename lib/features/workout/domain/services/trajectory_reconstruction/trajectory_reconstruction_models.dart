import 'package:latlong2/latlong.dart';

/// Classification of sampling gaps encountered during trajectory reconstruction.
///
/// Literature Grounding:
/// - Czerwiński, Wydra, Rachwał, Jachuła & Zubrzycki (2026).
///   "A Multi-Stage Framework for GPS Trajectory Reconstruction Using Consumer-Grade Wearable Devices."
///   Applied Sciences (MDPI), 16(18), 8972. DOI: 10.3390/app16188972.
/// - Fritsch & Carlson (1980). "Monotone Piecewise Cubic Interpolation."
///   SIAM Journal on Numerical Analysis, 17(2), 238–246.
enum ReconstructionGapType {
  /// Nominal high-frequency sampling (dt <= 2.0s). Original point retained without interpolation.
  nominalDense,

  /// Recoverable moderate outage / sparse sampling (2.0s < dt <= 15.0s).
  /// Reconstructed via Monotone Piecewise Cubic Hermite Interpolation (PCHIP)
  /// matching boundary velocities from prior EKF state.
  sparseRecoverable,

  /// Severe signal blackout or unknown detour (dt > 15.0s).
  /// Reconstructing across prolonged blackouts without ground truth creates fictitious motion.
  /// Marked as an indeterminate discontinuity; gap distance is isolated.
  indeterminateOutage,

  /// Stationary dwell point (athlete stopped at traffic light or resting).
  /// Clustered to stay-point centroid; zero artificial travel distance accumulated.
  stationaryDwell,
}

/// A trajectory point resulting from the P03 reconstruction stage.
class ReconstructedPoint {
  final LatLng point;
  final DateTime timestamp;
  final double impliedSpeedMs;
  final double? impliedHeadingDeg;
  final double elevationMeters;

  /// True if this point was synthesized by P03 interpolation; false if original observed EKF point.
  final bool isInterpolated;

  /// Nature of the gap that preceded or generated this point.
  final ReconstructionGapType gapType;

  const ReconstructedPoint({
    required this.point,
    required this.timestamp,
    required this.impliedSpeedMs,
    this.impliedHeadingDeg,
    this.elevationMeters = 0.0,
    required this.isInterpolated,
    required this.gapType,
  });

  double get latitude => point.latitude;
  double get longitude => point.longitude;

  @override
  String toString() =>
      'ReconstructedPoint(t=$timestamp, lat=${latitude.toStringAsFixed(6)}, '
      'lng=${longitude.toStringAsFixed(6)}, v=${impliedSpeedMs.toStringAsFixed(2)}m/s, '
      'interpolated=$isInterpolated, gap=$gapType)';
}

/// Comprehensive metrics and telemetry produced by the P03 Trajectory Reconstruction Engine.
class TrajectoryReconstructionResult {
  /// The complete ordered sequence of reconstructed trajectory points.
  final List<ReconstructedPoint> points;

  /// Total count of original input points provided to the engine.
  final int originalPointCount;

  /// Total count of points in the reconstructed output stream.
  final int reconstructedPointCount;

  /// Total count of intermediate points synthesized via monotonic kinematic interpolation.
  final int interpolatedPointCount;

  /// Count of indeterminate prolonged blackouts detected (dt > 15s).
  final int indeterminateGapCount;

  /// Total cumulative path distance along observed and reconstructed segments (meters).
  final double totalReconstructedDistanceMeters;

  /// Distance covered during indeterminate blackouts (straight-line chord, isolated) (meters).
  final double indeterminateChordDistanceMeters;

  /// Ratio of synthesized points to total output points.
  double get interpolationRatio =>
      reconstructedPointCount > 0 ? interpolatedPointCount / reconstructedPointCount : 0.0;

  const TrajectoryReconstructionResult({
    required this.points,
    required this.originalPointCount,
    required this.reconstructedPointCount,
    required this.interpolatedPointCount,
    required this.indeterminateGapCount,
    required this.totalReconstructedDistanceMeters,
    required this.indeterminateChordDistanceMeters,
  });
}
