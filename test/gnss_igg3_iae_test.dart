import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/innovation_adaptive_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/robust_igg3_weight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SDD-02 RobustIgg3Weight (Yang, He, Xu 2001)', () {
    test('Exact boundary values, continuity, and monotonicity', () {
      expect(RobustIgg3Weight.weight(0.0), 1.0);
      expect(RobustIgg3Weight.weight(1.5), 1.0);
      expect(RobustIgg3Weight.weight(-1.5), 1.0);
      expect(RobustIgg3Weight.weight(3.0), 0.0);
      expect(RobustIgg3Weight.weight(3.5), 0.0);
      expect(RobustIgg3Weight.weight(double.nan), 0.0);

      // Strictly decreasing on (k0, k1)
      double prev = 1.0;
      for (double v = 1.6; v < 3.0; v += 0.1) {
        final w = RobustIgg3Weight.weight(v);
        expect(w, lessThan(prev));
        expect(w, greaterThan(0.0));
        prev = w;
      }

      expect(RobustIgg3Weight.covarianceScale(1.0), 1.0);
      expect(RobustIgg3Weight.covarianceScale(3.1), double.infinity);
    });
  });

  group('SDD-03 InnovationAdaptiveKalmanFilter (Mohamed & Schwarz 1999)', () {
    test('Maintains symmetric PSD covariance and rejects synthetic 50m outlier', () {
      final filter = InnovationAdaptiveKalmanFilter(
        windowSize: 10,
        enableIae: true,
        enableIgg3: true,
      );
      final t0 = DateTime.utc(2026, 11, 27, 10, 0, 0);
      const baseLat = 48.2082;
      const baseLng = 16.3738;
      // 1.5 m/s northward walk
      final dLatPerSec = 1.5 / 111320.0;

      for (int i = 0; i < 20; i++) {
        final out = filter.update(
          point: LatLng(baseLat + i * dLatPerSec, baseLng),
          timestamp: t0.add(Duration(seconds: i)),
          accuracyMeters: 3.0,
        );
        expect(out.rejected, isFalse);
        final p = filter.covarianceCopy;
        for (int r = 0; r < 4; r++) {
          expect(p[r * 4 + r], greaterThan(0.0));
          for (int c = 0; c < 4; c++) {
            expect((p[r * 4 + c] - p[c * 4 + r]).abs(), lessThan(1e-12));
          }
        }
      }

      // Inject 50m gross outlier jump -> IGG-III must reject
      final outlier = filter.update(
        point: LatLng(baseLat + 20 * dLatPerSec + 50.0 / 111320.0, baseLng),
        timestamp: t0.add(const Duration(seconds: 20)),
        accuracyMeters: 3.0,
      );
      expect(outlier.rejected, isTrue);
      expect(outlier.igg3Weight, 0.0);
    });

    test('IAE adapts R_hat upward when actual measurement noise exceeds reported accuracy', () {
      final filter = InnovationAdaptiveKalmanFilter(
        windowSize: 15,
        enableIae: true,
        enableIgg3: false,
      );
      final rng = math.Random(42);
      final t0 = DateTime.utc(2026, 11, 27, 10, 0, 0);
      const baseLat = 48.2082;
      const baseLng = 16.3738;

      double lastRN = 0.0;
      for (int i = 0; i < 60; i++) {
        // Box-Muller Gaussian with true sigma = 8m while device claims accuracy = 2m
        final u1 = math.max(rng.nextDouble(), 1e-9);
        final u2 = rng.nextDouble();
        final noiseM = 8.0 * math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
        final out = filter.update(
          point: LatLng(baseLat + noiseM / 111320.0, baseLng),
          timestamp: t0.add(Duration(seconds: i)),
          accuracyMeters: 2.0,
        );
        lastRN = out.estimatedRNorth;
      }
      // Nominal R was 2^2 = 4 m^2; true R is 8^2 = 64 m^2 -> IAE should inflate well above 4 m^2
      expect(lastRN, greaterThan(15.0));
    });
  });
}
