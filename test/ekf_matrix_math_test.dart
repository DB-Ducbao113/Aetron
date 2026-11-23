import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/matrix_math_4x4.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Matrix4x4', () {
    test('identity matrix properties', () {
      final i = Matrix4x4.identity();
      expect(i.get(0, 0), 1.0);
      expect(i.get(1, 1), 1.0);
      expect(i.get(2, 2), 1.0);
      expect(i.get(3, 3), 1.0);
      expect(i.get(0, 1), 0.0);

      final v = Float64List.fromList([2.0, 3.0, 5.0, 7.0]);
      final res = i.multiplyVector(v);
      expect(res, equals(v));
    });

    test('matrix multiplication & transpose', () {
      final m = Matrix4x4.diagonal(2.0, 3.0, 4.0, 5.0);
      final mt = m.transpose();
      expect(mt.get(0, 0), 2.0);
      expect(mt.get(1, 1), 3.0);

      final prod = m * Matrix4x4.diagonal(0.5, 1.0 / 3.0, 0.25, 0.2);
      expect(prod.get(0, 0), closeTo(1.0, 1e-12));
      expect(prod.get(1, 1), closeTo(1.0, 1e-12));
      expect(prod.get(2, 2), closeTo(1.0, 1e-12));
      expect(prod.get(3, 3), closeTo(1.0, 1e-12));
    });

    test('matrix inversion for general invertible matrix', () {
      final a = Matrix4x4.fromList([
        4.0, 1.0, 0.0, 0.0,
        1.0, 3.0, 1.0, 0.0,
        0.0, 1.0, 2.0, 1.0,
        0.0, 0.0, 1.0, 5.0,
      ]);

      final aInv = a.invert();
      final prod = a * aInv;

      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final expected = (r == c) ? 1.0 : 0.0;
          expect(prod.get(r, c), closeTo(expected, 1e-9));
        }
      }
    });

    test('throws StateError on singular matrix inversion', () {
      final singular = Matrix4x4.fromList([
        1.0, 2.0, 3.0, 4.0,
        2.0, 4.0, 6.0, 8.0, // linearly dependent row
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
      ]);

      expect(() => singular.invert(), throwsStateError);
    });

    test('symmetrizeAndClamp enforces symmetry, minimum variance, and Cauchy-Schwarz bounds', () {
      final m = Matrix4x4.fromList([
        -1.0, 50.0, 0.0, 0.0,
        10.0, 4.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 9.0,
      ]);

      m.symmetrizeAndClamp(1e-3);

      // Diagonal clamped >= minVariance
      expect(m.get(0, 0), closeTo(1e-3, 1e-9));
      expect(m.get(1, 1), closeTo(4.0, 1e-9));
      expect(m.get(2, 2), closeTo(1e-3, 1e-9));
      expect(m.get(3, 3), closeTo(9.0, 1e-9));

      // Symmetrized off-diagonals
      expect(m.get(0, 1), equals(m.get(1, 0)));

      // Cauchy-Schwarz bound: |P_01| <= 0.999 * sqrt(P_00 * P_11)
      final maxCov01 = 0.999 * math.sqrt(m.get(0, 0) * m.get(1, 1));
      expect(m.get(0, 1).abs(), lessThanOrEqualTo(maxCov01 + 1e-12));
    });
  });

  group('Matrix2x2', () {
    test('determinant and inversion', () {
      const m = Matrix2x2(4.0, 7.0, 2.0, 6.0);
      expect(m.determinant, 10.0);

      final mInv = m.invert();
      expect(mInv.m00, closeTo(0.6, 1e-12));
      expect(mInv.m01, closeTo(-0.7, 1e-12));
      expect(mInv.m10, closeTo(-0.2, 1e-12));
      expect(mInv.m11, closeTo(0.4, 1e-12));
    });

    test('throws on singular 2x2', () {
      const singular = Matrix2x2(1.0, 2.0, 2.0, 4.0);
      expect(() => singular.invert(), throwsStateError);
    });
  });

  group('EquirectangularProjection', () {
    test('round-trip projection within sub-millimeter error', () {
      const origin = LatLng(10.7769, 106.7009); // Ho Chi Minh City
      final proj = EquirectangularProjection(origin);

      final testPoint = LatLng(10.7780, 106.7020);
      final (xEast, yNorth) = proj.project(testPoint);

      expect(xEast, greaterThan(0.0));
      expect(yNorth, greaterThan(0.0));

      final restored = proj.unproject(xEast, yNorth);
      expect(restored.latitude, closeTo(testPoint.latitude, 1e-9));
      expect(restored.longitude, closeTo(testPoint.longitude, 1e-9));
    });

    test('angle normalization in radians and degrees', () {
      expect(
        EquirectangularProjection.normalizeAngleRad(3 * math.pi),
        closeTo(math.pi, 1e-9),
      );
      expect(
        EquirectangularProjection.normalizeAngleRad(-3 * math.pi),
        closeTo(math.pi, 1e-9),
      );
      expect(EquirectangularProjection.normalizeAngleDeg(370.0), 10.0);
      expect(EquirectangularProjection.normalizeAngleDeg(-10.0), 350.0);
    });
  });

  group('ExtendedKalmanFilter AEKF Core Functionality', () {
    const origin = LatLng(10.7769, 106.7009);

    test('predictOnly propagates state without measurement update', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(
        initialPoint: origin,
        initialSpeedMs: 5.0,
        initialHeadingDeg: 90.0, // Eastward
      );

      final priorVariance = ekf.update(
        measurementPoint: origin,
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        speedMs: 5.0,
        headingDeg: 90.0,
      ).positionVariance;

      // Predict only for 1 second
      final predEst = ekf.predictOnly(timeDeltaSec: 1.0);

      expect(predEst.isMeasurementApplied, isFalse);
      // Position moved East
      expect(predEst.position.longitude, greaterThan(origin.longitude));
      // Covariance grew during prediction
      expect(predEst.positionVariance, greaterThan(priorVariance));
    });

    test('invalid GPS measurement safely falls back to predictOnly without state corruption', () {
      final ekf = ExtendedKalmanFilter();
      ekf.init(initialPoint: origin, initialSpeedMs: 3.0, initialHeadingDeg: 0.0);

      // Attempt to update with NaN coordinate
      final estNaN = ekf.update(
        measurementPoint: const LatLng(double.nan, 106.7009),
        accuracyMeters: 5.0,
        timeDeltaSec: 1.0,
      );

      expect(estNaN.isMeasurementApplied, isFalse);
      expect(estNaN.position.latitude.isFinite, isTrue);
      expect(estNaN.position.longitude.isFinite, isTrue);

      // Attempt to update with negative accuracy
      final estNegAcc = ekf.update(
        measurementPoint: const LatLng(10.7770, 106.7009),
        accuracyMeters: -10.0,
        timeDeltaSec: 1.0,
      );

      expect(estNegAcc.isMeasurementApplied, isFalse);
      expect(estNegAcc.position.latitude.isFinite, isTrue);
    });

    test('single GPS outlier does NOT reset EKF state or clear filter initialization', () {
      final ekf = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
      );
      ekf.init(initialPoint: origin, initialSpeedMs: 2.0, initialHeadingDeg: 0.0);

      expect(ekf.isInitialized, isTrue);

      // Nominal point
      final est1 = ekf.update(
        measurementPoint: const LatLng(10.77691, 106.7009),
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 2.0,
        headingDeg: 0.0,
      );
      expect(est1.isMeasurementApplied, isTrue);

      // Inject a massive 200m multipath jump (single outlier)
      final estOutlier = ekf.update(
        measurementPoint: const LatLng(10.77900, 106.7009),
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 2.0,
        headingDeg: 0.0,
      );

      // Must be rejected by Chi-square gating
      expect(estOutlier.isMeasurementApplied, isFalse);
      expect(estOutlier.correctionQuality, equals(GnssCorrectionQuality.multipathRejected));

      // Filter MUST REMAIN INITIALIZED (not reset!)
      expect(ekf.isInitialized, isTrue);

      // Subsequent nominal point must be accepted smoothly without cold restart
      final est2 = ekf.update(
        measurementPoint: const LatLng(10.77693, 106.7009),
        accuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        speedMs: 2.0,
        headingDeg: 0.0,
      );
      expect(est2.isMeasurementApplied, isTrue);
    });
  });
}
