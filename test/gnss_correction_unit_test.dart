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

    test('Full 2x2 innovation covariance properly handles anisotropic errors and cross-correlation', () {
      const pred = LatLng(10.776889, 106.700806);
      // Displacement of ~5m North, 0m East
      const meas = LatLng(10.776934, 106.700806);

      // Higher variance in East (25 m^2) than North (4 m^2), with positive cross-correlation (2 m^2)
      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 14.5,
        predictedPosVarianceEast: 25.0,
        predictedPosVarianceNorth: 4.0,
        predictedPosCovarianceEN: 2.0,
        activityType: 'running',
      );

      expect(result.isAccepted, isTrue);
      expect(result.mahalanobisDistanceSq, greaterThan(0.0));
      // det(S) = (25 + 9)*(4 + 9) - 4 = 34 * 13 - 4 = 438 > 0 strictly positive
      expect(result.mahalanobisDistanceSq, lessThan(5.991));
    });

    test('Heading wrap-around across 359° to 1° boundary does not trigger false turn-rate spike', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776899, 106.700806);

      // Previous heading was 359°, current heading is 1° -> true turn is 2° (NOT 358°)
      final result = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 1.0,
        predictedPosition: pred,
        predictedHeadingDeg: 359.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );

      expect(result.isAccepted, isTrue);
      // Turn rate of 2°/s is below cycling threshold 10°/s -> nominal, multiplier is 1.0
      expect(result.quality, equals(GnssCorrectionQuality.nominal));
      expect(result.headingProcessNoiseMultiplier, equals(1.0));
    });

    test('Consecutive critical outliers trigger re-anchoring recovery after consecutive threshold', () {
      final customEngine = AdaptiveGnssCorrectionEngine(consecutiveOutlierThreshold: 3);
      const pred = LatLng(10.776889, 106.700806);
      // Severe jump ~40m
      const meas = LatLng(10.777250, 106.700806);

      // Fix 1: rejected
      final r1 = customEngine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );
      expect(r1.isAccepted, isFalse);

      // Fix 2: rejected
      final r2 = customEngine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );
      expect(r2.isAccepted, isFalse);

      // Fix 3: recovery re-anchor (accepted with inflated variance)
      final r3 = customEngine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );
      expect(r3.isAccepted, isTrue);
      expect(r3.quality, equals(GnssCorrectionQuality.inflatedVariance));
    });

    test('Ablation flags allow selective deactivation of correction modules', () {
      final ungatedEngine = AdaptiveGnssCorrectionEngine(
        enableInnovationGating: false,
        enableAdaptiveCovarianceInflation: false,
      );

      const pred = LatLng(10.776889, 106.700806);
      const severeJump = LatLng(10.777250, 106.700806);

      final res = ungatedEngine.correctMeasurement(
        measurementPoint: severeJump,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 5.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'cycling',
      );

      // Without gating or inflation, fix is accepted nominally without rejection
      expect(res.isAccepted, isTrue);
      expect(res.quality, equals(GnssCorrectionQuality.nominal));
      expect(res.effectiveAccuracyMeters, equals(3.0));
    });
  });
}

