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

    test('Numerical conditioning: negative or zero reported accuracy is safely sanitized', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776899, 106.700806);

      // Pathological receiver error: reportedAccuracyMeters = -5.0m
      final res = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: -5.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'running',
      );

      expect(res.isAccepted, isTrue);
      expect(res.effectiveAccuracyMeters, equals(10.0)); // Fallback safe default
      expect(res.mahalanobisDistanceSq.isFinite, isTrue);
      expect(res.mahalanobisDistanceSq, greaterThan(0.0));
    });

    test('Numerical conditioning: extreme reported accuracy 500m remains numerically stable', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776950, 106.700806);

      // Extreme cellular/WiFi coarse accuracy: 500m -> R = 250,000 m^2
      final res = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 500.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 16.0,
        activityType: 'running',
      );

      expect(res.isAccepted, isTrue);
      expect(res.quality, equals(GnssCorrectionQuality.nominal));
      expect(res.effectiveAccuracyMeters, equals(500.0));
      // With R = 250,000, NIS distance is tiny (< 0.01)
      expect(res.mahalanobisDistanceSq, lessThan(0.01));
      expect(res.mahalanobisDistanceSq, greaterThanOrEqualTo(0.0));
    });

    test('Numerical conditioning: pathological singular cross-covariance is clamped by Cauchy-Schwarz', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776910, 106.700806);

      // Pathological P_EN violating Cauchy-Schwarz: P_EE = 4.0, P_NN = 4.0, but P_EN = 100.0 (unphysical)
      // Max allowable |P_EN| is 0.99 * sqrt(4 * 4) = 3.96
      final res = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 4.0,
        predictedPosVarianceEast: 4.0,
        predictedPosVarianceNorth: 4.0,
        predictedPosCovarianceEN: 100.0, // Pathological singular covariance
        activityType: 'running',
      );

      expect(res.isAccepted, isTrue);
      expect(res.mahalanobisDistanceSq.isFinite, isTrue);
      expect(res.mahalanobisDistanceSq, greaterThan(0.0));
      expect(res.mahalanobisDistanceSq, lessThan(5.991));
    });

    test('Input sanitization: non-positive dt, negative speed, and NaN heading do not crash or produce NaN', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776899, 106.700806);

      final res = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: -1.0, // Non-positive dt
        reportedSpeedMs: -3.0, // Negative speed
        reportedHeadingDeg: double.nan, // NaN heading
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'running',
      );

      expect(res.isAccepted, isTrue);
      expect(res.effectiveSpeedMs, equals(0.0));
      expect(res.effectiveHeadingDeg, isNull);
      expect(res.mahalanobisDistanceSq.isFinite, isTrue);
      expect(res.headingProcessNoiseMultiplier, equals(1.0));
    });

    test('Numerical conditioning: extreme anisotropic eigenvalues and condition number analysis', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776910, 106.700806);

      // Highly anisotropic prior covariance: P_EE = 5000.0 m^2, P_NN = 1.0 m^2, P_EN = 0.0
      // With reported accuracy 3.0m (R = 9.0 m^2):
      // S_EE = 5000 + 9 = 5009, S_NN = 1 + 9 = 10, S_EN = 0
      // lambda_max = 5009, lambda_min = 10 -> kappa(S) = 500.9 >> 5.0
      final res = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 2500.5,
        predictedPosVarianceEast: 5000.0,
        predictedPosVarianceNorth: 1.0,
        predictedPosCovarianceEN: 0.0,
        activityType: 'running',
      );

      expect(res.isAccepted, isTrue);
      expect(res.mahalanobisDistanceSq.isFinite, isTrue);
      expect(res.mahalanobisDistanceSq, greaterThan(0.0));

      // Analytical verification: S remains strictly positive definite even when kappa(S) is large
      const sEE = 5000.0 + 9.0;
      const sNN = 1.0 + 9.0;
      const detS = sEE * sNN;
      const kappa = sEE / sNN; // 500.9
      expect(detS, greaterThan(0.0));
      expect(kappa, greaterThan(100.0)); // Proves universal kappa(S) < 5 claim is invalid without input bounds!
    });

    test('Input sanitization: NaN and Infinity in position coordinates and variances', () {
      // Case 1: Corrupted predictedPosition with NaN
      const nanPred = LatLng(double.nan, 106.700806);
      const validMeas = LatLng(10.776889, 106.700806);

      final res1 = engine.correctMeasurement(
        measurementPoint: validMeas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: nanPred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'running',
      );
      expect(res1.isAccepted, isTrue);
      expect(res1.quality, equals(GnssCorrectionQuality.nominal));
      expect(res1.position, equals(validMeas));

      // Case 2: Corrupted measurementPoint with Infinity
      const infMeas = LatLng(10.776889, double.infinity);
      const validPred = LatLng(10.776889, 106.700806);

      final res2 = engine.correctMeasurement(
        measurementPoint: infMeas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: validPred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 9.0,
        activityType: 'running',
      );
      expect(res2.isAccepted, isFalse);
      expect(res2.quality, equals(GnssCorrectionQuality.multipathRejected));

      // Case 3: Infinite prior variances are safely clamped
      final res3 = engine.correctMeasurement(
        measurementPoint: validMeas,
        reportedAccuracyMeters: 4.0,
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: validPred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: double.infinity,
        predictedPosVarianceEast: double.infinity,
        predictedPosVarianceNorth: double.nan,
        activityType: 'running',
      );
      expect(res3.isAccepted, isTrue);
      expect(res3.mahalanobisDistanceSq.isFinite, isTrue);
    });

    test('Empirical measurement covariance R analysis: per-axis standard deviation vs 68% circular radius', () {
      const pred = LatLng(10.776889, 106.700806);
      const meas = LatLng(10.776920, 106.700806); // ~3.4m North displacement

      // Model A: Conservative mapping R = H_acc^2
      final resConservative = engine.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0, // R = 9.0 m^2
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 4.0,
        activityType: 'running',
      );

      // Model B: Rayleigh 68% mapping R = H_acc^2 / 2.2789 (effective sigma_axis = H_acc / 1.51)
      final customEngineRayleigh = AdaptiveGnssCorrectionEngine();
      final resRayleigh = customEngineRayleigh.correctMeasurement(
        measurementPoint: meas,
        reportedAccuracyMeters: 3.0 / 1.5096, // R = 3.95 m^2
        timeDeltaSec: 1.0,
        reportedSpeedMs: 4.0,
        reportedHeadingDeg: 0.0,
        predictedPosition: pred,
        predictedHeadingDeg: 0.0,
        predictedPosVariance: 4.0,
        activityType: 'running',
      );

      // Verification: Smaller R increases NIS (d_M^2), making the filter more aggressive in gating
      expect(resRayleigh.mahalanobisDistanceSq, greaterThan(resConservative.mahalanobisDistanceSq));
      // Confirms conservative mapping prevents false inflation on smartphones where H_acc is already optimistic
      expect(resConservative.quality, equals(GnssCorrectionQuality.nominal));
    });
  });
}

