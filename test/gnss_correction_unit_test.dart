import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('AdaptiveGnssCorrectionEngine (Phase 2 - P02) Unit Tests', () {
    late AdaptiveGnssCorrectionEngine engine;

    setUp(() {
      engine = AdaptiveGnssCorrectionEngine();
    });

    test('Initial fix is accepted nominally without prior prediction', () {
      final result = engine.correctMeasurement(
        measurementPoint: const LatLng(10.776889, 106.700806),
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 90.0,
        predictedPosition: null,
        predictedHeadingDeg: null,
        predictedPosVariance: 16.0,
        activityType: 'cycling',
      );

      expect(result.isAccepted, isTrue);
      expect(result.quality, equals(GnssCorrectionQuality.nominal));
      expect(result.effectiveAccuracyMeters, equals(4.0));
      expect(result.mahalanobisDistanceSq, equals(0.0));
      expect(result.headingProcessNoiseMultiplier, equals(1.0));
    });

    test('Nominal measurement within 95% chi-square gate preserves accuracy', () {
      const pred = LatLng(10.776889, 106.700806);
      // Small 1.5m displacement (innovation)
      const meas = LatLng(10.776902, 106.700806);

      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 5.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0, // S = 9 + 25 = 34 m^2
        activityType: 'running',
      );

      expect(result.isAccepted, isTrue);
      expect(result.quality, equals(GnssCorrectionQuality.nominal));
      expect(result.effectiveAccuracyMeters, equals(5.0));
      expect(result.mahalanobisDistanceSq, lessThan(5.991));
    });

    test('Moderate innovation error adaptively inflates measurement covariance', () {
      const pred = LatLng(10.776889, 106.700806);
      // ~15m displacement: spatialDistSq ≈ 225m^2. With S ≈ 30m^2, d_M^2 ≈ 7.5 (between 5.991 and 13.816)
      const meas = LatLng(10.777024, 106.700806);

      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 14.0,
        activityType: 'running',
      );

      expect(result.isAccepted, isTrue);
      expect(result.quality, equals(GnssCorrectionQuality.inflatedVariance));
      expect(result.mahalanobisDistanceSq, greaterThan(5.991));
      expect(result.mahalanobisDistanceSq, lessThanOrEqualTo(13.816));
      expect(result.effectiveAccuracyMeters, greaterThan(4.0));
    });

    test('Severe multipath jump exceeding critical gate is rejected', () {
      const pred = LatLng(10.776889, 106.700806);
      // ~35m sudden lateral jump: spatialDistSq ≈ 1225m^2. S ≈ 25m^2 -> d_M^2 ≈ 49 >> 13.816
      const meas = LatLng(10.777204, 106.700806);

      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 16.0,
        activityType: 'cycling',
      );

      expect(result.isAccepted, isFalse);
      expect(result.quality, equals(GnssCorrectionQuality.multipathRejected));
      expect(result.mahalanobisDistanceSq, greaterThan(13.816));
    });

    test('Turn-rate adaptation inflates heading process noise during sharp 90-degree turn', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776899, 106.700816);

      // Previous heading was North (0°), current heading is East (90°) -> turnRate = 90°/s
      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 6.0,
        reportedHeadingDeg: 90.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );

      expect(result.isAccepted, isTrue);
      expect(result.quality, equals(GnssCorrectionQuality.turnAdapted));
      expect(result.headingProcessNoiseMultiplier, greaterThan(1.5));
    });

    test('Low-speed heading deadband clamps heading when moving under mode threshold', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776891, 106.700806);

      // Walking at 0.4 m/s (below 0.8 m/s deadband threshold)
      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 0.4,
        reportedHeadingDeg: 270.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'walking',
      );

      expect(result.isAccepted, isTrue);
      expect(result.quality, equals(GnssCorrectionQuality.headingDeadbandApplied));
      expect(result.effectiveHeadingDeg, isNull);
    });
  });
}
