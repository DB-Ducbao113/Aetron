import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/gnss_correction_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/kinematic_limits.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/streaming_trajectory_preprocessor.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Phase 2 (P02) GNSS Correction Runtime Integration Tests', () {
    const startPoint = LatLng(10.776889, 106.700806);

    test('Feature Flag OFF: default GpsSmoothingService runs baseline EKF without modification', () {
      final defaultService = GpsSmoothingService(
        enableGnssCorrection: false,
        enableShadowMode: false,
      );

      // Normal movement
      final update1 = defaultService.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: startPoint,
        previousAcceptedPoint: null,
        previousSmoothedPoint: null,
        lastSmoothedRoutePoint: null,
        accuracyMeters: 4.0,
        speedMs: 3.5,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );
      expect(update1.smoothedPoint, equals(startPoint));

      // Deceptive multipath spike (30m jump with optimistic reported accuracy 3.0m)
      const spikePoint = LatLng(10.777159, 106.700806);
      final update2 = defaultService.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: spikePoint,
        previousAcceptedPoint: startPoint,
        previousSmoothedPoint: update1.smoothedPoint,
        lastSmoothedRoutePoint: update1.smoothedPoint,
        accuracyMeters: 3.0,
        speedMs: 3.5,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );

      // Baseline EKF without P02 moves towards the spike
      expect(update2.smoothedPoint.latitude, greaterThan(startPoint.latitude));
    });

    test('Feature Flag ON: GpsSmoothingService rejects severe multipath spike via Chi-square gating', () {
      final p02Engine = AdaptiveGnssCorrectionEngine();
      final p02Service = GpsSmoothingService(
        enableGnssCorrection: true,
        enableShadowMode: false,
        gnssCorrectionEngine: p02Engine,
      );

      // Step 1: Initialize at startPoint
      final u1 = p02Service.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: startPoint,
        previousAcceptedPoint: null,
        previousSmoothedPoint: null,
        lastSmoothedRoutePoint: null,
        accuracyMeters: 3.0,
        speedMs: 4.0,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );
      expect(u1.smoothedPoint, equals(startPoint));

      // Step 2: Athlete moves nominally North by 4m (at 4 m/s)
      const step2Point = LatLng(10.776925, 106.700806);
      final u2 = p02Service.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: step2Point,
        previousAcceptedPoint: startPoint,
        previousSmoothedPoint: u1.smoothedPoint,
        lastSmoothedRoutePoint: u1.smoothedPoint,
        accuracyMeters: 3.0,
        speedMs: 4.0,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );
      expect(u2.smoothedPoint.latitude, greaterThan(startPoint.latitude));

      // Step 3: Severe deceptive multipath spike (40m lateral jump)
      const spikePoint = LatLng(10.777285, 106.700806);
      final u3 = p02Service.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: spikePoint,
        previousAcceptedPoint: step2Point,
        previousSmoothedPoint: u2.smoothedPoint,
        lastSmoothedRoutePoint: u1.smoothedPoint,
        accuracyMeters: 3.0,
        speedMs: 4.0,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );

      // P02 rejects the 40m spike measurement; EKF state remains at predicted forward position
      // Lateral distance from step2Point is roughly expected movement (~4m), NOT 40m
      const distance = Distance();
      final distFromPred = distance.distance(u2.smoothedPoint, u3.smoothedPoint);
      expect(distFromPred, lessThan(8.0));
      expect(distFromPred, greaterThan(1.0));
    });

    test('Shadow Mode computes correction diagnostic quality without altering smoothed coordinates', () {
      final ekfStandard = ExtendedKalmanFilter(enableGnssCorrection: false, enableShadowMode: false);
      final ekfShadow = ExtendedKalmanFilter(
        enableGnssCorrection: false,
        enableShadowMode: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
      );

      // Run same sequence of fixes through both
      const p1 = LatLng(10.776889, 106.700806);
      const p2 = LatLng(10.776925, 106.700806);
      const p3 = LatLng(10.777100, 106.700806); // Moderate deviation

      final estStd1 = ekfStandard.update(measurementPoint: p1, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);
      final estShd1 = ekfShadow.update(measurementPoint: p1, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);
      expect(estShd1.position.latitude, equals(estStd1.position.latitude));

      final estStd2 = ekfStandard.update(measurementPoint: p2, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);
      final estShd2 = ekfShadow.update(measurementPoint: p2, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);
      expect(estShd2.position.latitude, equals(estStd2.position.latitude));

      final estStd3 = ekfStandard.update(measurementPoint: p3, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);
      final estShd3 = ekfShadow.update(measurementPoint: p3, accuracyMeters: 4.0, timeDeltaSec: 1.0, speedMs: 4.0);

      // Shadow mode output MUST match standard output exactly to ensure non-invasive safety
      expect(estShd3.position.latitude, equals(estStd3.position.latitude));
      expect(estShd3.position.longitude, equals(estStd3.position.longitude));
      // But shadow mode records the diagnostic quality flag
      expect(estShd3.correctionQuality, isNotNull);
    });

    test('Blackout gap (>5s) resets both EKF state and GNSS correction engine', () {
      final engine = AdaptiveGnssCorrectionEngine();
      final service = GpsSmoothingService(
        enableGnssCorrection: true,
        gnssCorrectionEngine: engine,
      );

      // Fix 1
      service.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: startPoint,
        previousAcceptedPoint: null,
        previousSmoothedPoint: null,
        lastSmoothedRoutePoint: null,
        accuracyMeters: 4.0,
        speedMs: 4.0,
        timeDeltaSec: 1.0,
        gpsGapDurationSec: 0.0,
      );

      // Blackout gap of 8.0s
      const resumePoint = LatLng(10.780000, 106.705000); // New location after tunnel
      final resumeUpdate = service.smoothAcceptedPoint(
        activityType: 'running',
        acceptedPoint: resumePoint,
        previousAcceptedPoint: startPoint,
        previousSmoothedPoint: startPoint,
        lastSmoothedRoutePoint: startPoint,
        accuracyMeters: 5.0,
        speedMs: 4.0,
        timeDeltaSec: 8.0,
        gpsGapDurationSec: 8.0,
      );

      // Blackout recovery re-seeds on new resume point without rejecting it as a jump
      expect(resumeUpdate.smoothedPoint, equals(resumePoint));
      expect(resumeUpdate.shouldAppendRoutePoint, isTrue);
    });

    test('2x2 Permutation Matrix (P01 ON/OFF x P02 ON/OFF) operates with complete state isolation', () {
      // Test points: 3 nominal points moving North at 5 m/s, followed by a 25m East deceptive multipath spike
      const baseLat = 10.776889;
      const baseLng = 106.700806;
      final rawFixes = <TrajectoryRawSample>[
        TrajectoryRawSample(
          index: 0,
          timestamp: DateTime(2026, 10, 24, 10, 0, 0),
          point: const LatLng(baseLat, baseLng),
          accuracyMeters: 3.5,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ),
        TrajectoryRawSample(
          index: 1,
          timestamp: DateTime(2026, 10, 24, 10, 0, 1),
          point: const LatLng(baseLat + 0.000045, baseLng),
          accuracyMeters: 3.5,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ),
        TrajectoryRawSample(
          index: 2,
          timestamp: DateTime(2026, 10, 24, 10, 0, 2),
          point: const LatLng(baseLat + 0.000090, baseLng),
          accuracyMeters: 3.5,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ),
        // Fix 3: 25m lateral multipath spike with deceptive reported accuracy 3.0m
        TrajectoryRawSample(
          index: 3,
          timestamp: DateTime(2026, 10, 24, 10, 0, 3),
          point: const LatLng(baseLat + 0.000135, baseLng + 0.000228),
          accuracyMeters: 3.0,
          sensorSpeedMs: 5.0,
          sensorHeadingDeg: 0.0,
        ),
      ];

      // Permutation 1: P01 OFF, P02 OFF (Legacy Raw -> Baseline EKF)
      final ekfP1 = ExtendedKalmanFilter(
        enableGnssCorrection: false,
        enableShadowMode: false,
        activityType: 'cycling',
      );
      LatLng? p1Smoothed;
      for (final fix in rawFixes) {
        final est = ekfP1.update(
          measurementPoint: fix.point,
          accuracyMeters: fix.accuracyMeters,
          timeDeltaSec: 1.0,
          speedMs: fix.sensorSpeedMs,
          headingDeg: fix.sensorHeadingDeg,
          activityType: 'cycling',
        );
        p1Smoothed = est.position;
      }
      // Baseline EKF absorbs the multipath spike laterally
      expect(p1Smoothed!.longitude, greaterThan(baseLng + 0.00005));

      // Permutation 2: P01 ON, P02 OFF (Streaming Preprocessed -> Baseline EKF)
      final preprocessorP2 = StreamingTrajectoryPreprocessor(
        limits: KinematicLimits.forActivity('cycling'),
      );
      final ekfP2 = ExtendedKalmanFilter(
        enableGnssCorrection: false,
        enableShadowMode: false,
        activityType: 'cycling',
      );
      LatLng? p2Smoothed;
      for (final fix in rawFixes) {
        final prepResult = preprocessorP2.processSample(fix);
        if (!prepResult.isOutlier) {
          final est = ekfP2.update(
            measurementPoint: prepResult.point,
            accuracyMeters: prepResult.accuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: fix.sensorSpeedMs,
            headingDeg: fix.sensorHeadingDeg,
            activityType: 'cycling',
          );
          p2Smoothed = est.position;
        }
      }
      expect(p2Smoothed, isNotNull);

      // Permutation 3: P01 OFF, P02 ON (Raw Fixes -> EKF with P02 Adaptive Correction)
      final ekfP3 = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );
      var p3Rejected = false;
      LatLng? p3Smoothed;
      for (final fix in rawFixes) {
        final est = ekfP3.update(
          measurementPoint: fix.point,
          accuracyMeters: fix.accuracyMeters,
          timeDeltaSec: 1.0,
          speedMs: fix.sensorSpeedMs,
          headingDeg: fix.sensorHeadingDeg,
          activityType: 'cycling',
        );
        p3Smoothed = est.position;
        if (est.correctionQuality == GnssCorrectionQuality.multipathRejected) {
          p3Rejected = true;
        }
      }
      // P02 successfully rejects the deceptive multipath pulse at fix 3 even without P01!
      expect(p3Rejected, isTrue);
      // Smoothed longitude is preserved along meridian (~0.0 lateral distortion)
      expect((p3Smoothed!.longitude - baseLng).abs(), lessThan(0.00003));

      // Permutation 4: P01 ON, P02 ON (Preprocessed -> EKF with P02 Adaptive Correction)
      final preprocessorP4 = StreamingTrajectoryPreprocessor(
        limits: KinematicLimits.forActivity('cycling'),
      );
      final ekfP4 = ExtendedKalmanFilter(
        enableGnssCorrection: true,
        gnssCorrectionEngine: AdaptiveGnssCorrectionEngine(),
        activityType: 'cycling',
      );
      var p4Rejected = false;
      LatLng? p4Smoothed;
      for (final fix in rawFixes) {
        final prepResult = preprocessorP4.processSample(fix);
        if (!prepResult.isOutlier) {
          final est = ekfP4.update(
            measurementPoint: prepResult.point,
            accuracyMeters: prepResult.accuracyMeters,
            timeDeltaSec: 1.0,
            speedMs: fix.sensorSpeedMs,
            headingDeg: fix.sensorHeadingDeg,
            activityType: 'cycling',
          );
          p4Smoothed = est.position;
          if (est.correctionQuality == GnssCorrectionQuality.multipathRejected) {
            p4Rejected = true;
          }
        }
      }
      expect(p4Smoothed, isNotNull);
      // P01 preprocessor filtered the spike before EKF, so P02 inside EKF received only clean candidate fixes
      expect(p4Rejected, isFalse);
      // Full stack preserves accuracy and demonstrates complete modularity
      expect((p4Smoothed!.longitude - baseLng).abs(), lessThan(0.00005));
    });
  });
}
