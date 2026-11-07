import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:latlong2/latlong.dart';

/// Abstract contract for Phase 2 (P02) — GNSS Correction Techniques.
///
/// Responsible for:
/// 1. Statistical innovation testing (Normalized Innovation Squared / Mahalanobis gating).
/// 2. Adaptive measurement noise covariance inflation for multipath resilience.
/// 3. Centripetal turn-rate process noise scaling to eliminate corner apex lag.
/// 4. Low-speed heading deadband stabilization.
abstract class IGnssCorrectionEngine {
  /// Evaluates and corrects a clean GNSS fix prior to or during EKF state update.
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
  });

  /// Resets internal temporal and heading states.
  void reset();
}
