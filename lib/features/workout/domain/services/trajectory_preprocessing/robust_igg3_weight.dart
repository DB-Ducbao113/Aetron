import 'dart:math' as math;

/// IGG-III equivalent weight function from:
/// Yang, Y., He, H., & Xu, G. (2001). "Adaptively robust filtering for kinematic
/// geodetic positioning." Journal of Geodesy, 75, 109–116.
/// DOI: 10.1007/s001900000157.
///
/// Provenance note:
/// - Standard published IGG-III tuning constants are `k0 = 1.5` (range [1.0, 1.5])
///   and `k1 = 3.0` (range [2.5, 3.0]). Closed-access PDF is not archived locally;
///   equations follow the canonical IGG-III three-segment form.
class RobustIgg3Weight {
  /// Default lower bound where observations retain full weight (w = 1).
  static const double defaultK0 = 1.5;

  /// Default upper bound above which gross outliers are rejected (w = 0).
  static const double defaultK1 = 3.0;

  /// Computes the IGG-III weight w(|vTilde|) in [0.0, 1.0].
  ///
  /// - `|vTilde| <= k0` -> `1.0`
  /// - `k0 < |vTilde| <= k1` -> `(k0 / |vTilde|) * ((k1 - |vTilde|) / (k1 - k0))^2`
  /// - `|vTilde| > k1` -> `0.0` (gross outlier)
  static double weight(
    double vTilde, {
    double k0 = defaultK0,
    double k1 = defaultK1,
  }) {
    assert(k0 > 0 && k1 > k0, 'Require 0 < k0 < k1');
    if (!vTilde.isFinite) return 0.0;
    final v = vTilde.abs();
    if (v <= k0) return 1.0;
    if (v >= k1) return 0.0;
    final ratio = (k1 - v) / (k1 - k0);
    return (k0 / v) * ratio * ratio;
  }

  /// Returns the observation covariance inflation factor `1 / w`, or
  /// `double.infinity` when `w == 0` (reject).
  static double covarianceScale(
    double vTilde, {
    double k0 = defaultK0,
    double k1 = defaultK1,
    double minWeightFloor = 1e-6,
  }) {
    final w = weight(vTilde, k0: k0, k1: k1);
    if (w <= minWeightFloor) return double.infinity;
    return 1.0 / w;
  }

  /// Computes normalized scalar innovation magnitude `sqrt(v^T S^-1 v / dim)`
  /// for a 2D position innovation `(ve, vn)` and 2x2 innovation covariance `S`.
  static double normalizedResidual2d({
    required double ve,
    required double vn,
    required double s00,
    required double s01,
    required double s11,
  }) {
    final det = s00 * s11 - s01 * s01;
    if (!det.isFinite || det <= 1e-12) return double.infinity;
    final inv00 = s11 / det;
    final inv01 = -s01 / det;
    final inv11 = s00 / det;
    final mahalSq = ve * (inv00 * ve + inv01 * vn) + vn * (inv01 * ve + inv11 * vn);
    if (!mahalSq.isFinite || mahalSq < 0) return 0.0;
    return math.sqrt(mahalSq / 2.0);
  }
}
