import 'package:latlong2/latlong.dart';

/// Quality flag indicating how the GNSS measurement was corrected or scaled.
enum GnssCorrectionQuality {
  /// Measurement is within standard statistical confidence (d_M^2 <= gamma_1).
  nominal,

  /// Measurement exhibited moderate innovation error; variance R was adaptively inflated.
  inflatedVariance,

  /// Measurement exceeded the critical chi-square gate (d_M^2 > gamma_2); flagged as multipath.
  multipathRejected,

  /// Measurement occurred at low speed; heading was clamped to track deadband.
  headingDeadbandApplied,

  /// Measurement occurred during a sharp turn; turn rate adaptation was triggered.
  turnAdapted,
}

/// Result of evaluating a GNSS measurement through the P02 GNSS Correction Layer.
class GnssCorrectionResult {
  /// The input or corrected geographic position.
  final LatLng position;

  /// Effective 1-sigma horizontal accuracy in meters after adaptive scaling.
  final double effectiveAccuracyMeters;

  /// Effective speed in m/s.
  final double effectiveSpeedMs;

  /// Effective heading in degrees, or null if deadbanded / invalid.
  final double? effectiveHeadingDeg;

  /// Normalized Innovation Squared (Mahalanobis distance squared d_M^2).
  final double mahalanobisDistanceSq;

  /// Quality classification for this correction cycle.
  final GnssCorrectionQuality quality;

  /// Whether the measurement is accepted for state update.
  final bool isAccepted;

  /// Dynamic heading process noise multiplier for turn lag elimination.
  final double headingProcessNoiseMultiplier;

  const GnssCorrectionResult({
    required this.position,
    required this.effectiveAccuracyMeters,
    required this.effectiveSpeedMs,
    required this.effectiveHeadingDeg,
    required this.mahalanobisDistanceSq,
    required this.quality,
    required this.isAccepted,
    this.headingProcessNoiseMultiplier = 1.0,
  });
}

