import 'dart:convert';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('research defaults activate P01 and P02 in the live pipeline', () {
    expect(kEnableTrajectoryPreprocessing, true);
    expect(kEnableTrajectoryPreprocessingShadowMode, false);
    expect(kEnableGnssCorrection, true);
    expect(kEnableGnssCorrectionShadowMode, false);
    expect(kEnableGpsQualityGate, false);
    expect(kEnableTrajectoryReconstruction, true);
    expect(kTrajectoryReconstructionMethod, 'monotonePchip');
  });
  test(
    'P02 active does not freeze real 1 Hz walking and resets on route break',
    () {
      final s = GpsSmoothingService();
      expect(s.algorithmName, 'aekf_4state');
      const first = LatLng(10, 106);
      const next = LatLng(10.000012, 106);
      final initial = s.smoothAcceptedPoint(
        activityType: 'walking',
        acceptedPoint: first,
        previousAcceptedPoint: null,
        previousSmoothedPoint: null,
        lastSmoothedRoutePoint: null,
        accuracyMeters: 3,
        speedMs: 1.3,
        timeDeltaSec: 1,
        gpsGapDurationSec: 0,
        sensorHeadingDeg: 0,
      );
      final moving = s.smoothAcceptedPoint(
        activityType: 'walking',
        acceptedPoint: next,
        previousAcceptedPoint: first,
        previousSmoothedPoint: initial.smoothedPoint,
        lastSmoothedRoutePoint: first,
        accuracyMeters: 3,
        speedMs: 1.3,
        timeDeltaSec: 1,
        gpsGapDurationSec: 0,
        sensorHeadingDeg: 0,
      );
      expect(moving.isStationary, false);
      expect(moving.smoothedPoint.latitude, greaterThan(first.latitude));
      const recovered = LatLng(10.001, 106.001);
      final reset = s.smoothAcceptedPoint(
        activityType: 'walking',
        acceptedPoint: recovered,
        previousAcceptedPoint: next,
        previousSmoothedPoint: moving.smoothedPoint,
        lastSmoothedRoutePoint: first,
        accuracyMeters: 3,
        speedMs: 1.3,
        timeDeltaSec: 2,
        gpsGapDurationSec: 0,
        resetAnchor: true,
      );
      expect(reset.smoothedPoint, recovered);
      expect(reset.shouldAppendRoutePoint, true);
    },
  );
  test(
    'P01 retains bearing history and cannot accept a rejected recovery fix',
    () {
      final pre = TrajectoryPreprocessor.forActivity(
        'walking',
      ).createStreamingSession(enableQualityGate: false);
      final t = DateTime.utc(2026, 11, 18);
      TrajectoryRawSample sample(int i, double lat, double accuracy) =>
          TrajectoryRawSample(
            index: i,
            timestamp: t.add(Duration(seconds: i)),
            point: LatLng(lat, 106),
            accuracyMeters: accuracy,
            sensorSpeedMs: 1.3,
            sensorHeadingDeg: 0,
          );
      pre.processSample(sample(0, 10, 3));
      final second = pre.processSample(sample(1, 10.000012, 3));
      expect(second.forwardBearingDeg, isNotNull);
      final bad = pre.processSample(sample(20, 10.001, 80));
      expect(bad.isAccepted, false);
      final legacy = TrackingGpsDecision(
        type: TrackingGpsDecisionType.acceptRoute,
        livePoint: bad.point,
        previewPoint: bad.point,
        outcome: GpsPointOutcome.signalGap,
      );
      final merged = const WorkoutTrackingEngine()
          .resolveTrajectoryPreprocessingDecision(
            legacyDecision: legacy,
            processedSample: bad,
            livePoint: bad.point,
            pendingGapDurationSec: 19,
          );
      expect(merged.type, TrackingGpsDecisionType.skip);
      expect(merged.reason, GpsRejectReason.lowAccuracy);
    },
  );
  test('P02 service shadow leaves all live outputs identical', () {
    final off = GpsSmoothingService(
      algorithm: GpsFilterAlgorithm.ekf4State,
      enableGnssCorrection: false,
      enableShadowMode: false,
    );
    final shadow = GpsSmoothingService(
      algorithm: GpsFilterAlgorithm.ekf4State,
      enableGnssCorrection: false,
      enableShadowMode: true,
    );
    LatLng? previous, smoothed, displayed;
    for (final p in const [
      LatLng(10, 106),
      LatLng(10.00003, 106),
      LatLng(10.00005, 106),
      LatLng(10.0003, 106.0001),
      LatLng(10.00006, 106),
      LatLng(10.00006, 106),
      LatLng(10.00009, 106),
    ]) {
      GpsSmoothingUpdate update(GpsSmoothingService service) =>
          service.smoothAcceptedPoint(
            activityType: 'running',
            acceptedPoint: p,
            previousAcceptedPoint: previous,
            previousSmoothedPoint: smoothed,
            lastSmoothedRoutePoint: displayed,
            accuracyMeters: 3,
            speedMs: 3,
            timeDeltaSec: 1,
            gpsGapDurationSec: 0,
          );
      final a = update(off), b = update(shadow);
      expect(b.smoothedPoint, a.smoothedPoint);
      expect(b.shouldAppendRoutePoint, a.shouldAppendRoutePoint);
      expect(b.isStationary, a.isStationary);
      expect(b.confidence, a.confidence);
      previous = p;
      smoothed = a.smoothedPoint;
      if (a.shouldAppendRoutePoint) displayed = smoothed;
    }
  });
  test(
    'offline P03 default is linear and does not change official distance, energy or speed',
    () {
      final t = DateTime.utc(2026, 11, 18);
      final raw = [
        for (final (i, lon) in [(0, 106.0), (5, 106.000137)])
          Position(
            latitude: 10,
            longitude: lon,
            timestamp: t.add(Duration(seconds: i)),
            accuracy: 4,
            altitude: 0,
            altitudeAccuracy: 1,
            heading: 90,
            headingAccuracy: 1,
            speed: 3,
            speedAccuracy: .5,
          ),
      ];
      final state = WorkoutSessionState(
        status: RecordingState.stopping,
        activityType: 'Running',
        trackingMode: 'outdoor',
        recordingSource: 'gps',
        durationSeconds: 5,
        movingTimeSeconds: 5,
        distanceMeters: 15,
        stepCount: 12,
      );
      final segments = [
        [const LatLng(10, 106), const LatLng(10, 106.000137)],
      ];
      WorkoutSessionFinalization finish({
        bool? enabled,
        List<List<LatLng>>? route,
      }) => const WorkoutSessionFinalizer().finalize(
        state: state,
        userId: 'test',
        finishedAt: t.add(const Duration(seconds: 5)),
        caloriesBurned: 1,
        fallbackStrideLengthMeters: 1,
        trackingEngine: const WorkoutTrackingEngine(),
        rawGpsPositions: raw,
        filteredRouteSegments: route ?? segments,
        enableTrajectoryPreprocessing: false,
        enableTrajectoryReconstruction:
            enabled ?? kEnableTrajectoryReconstruction,
      );
      final baseline = finish(enabled: false), reconstructed = finish();
      final audit = jsonDecode(reconstructed.session.routeMatchMetricsJson);
      expect(audit['reconstruction_method'], 'monotonePchip');
      expect(audit['preprocessing_enabled'], true);
      expect(audit['preprocessing_distance_policy_enabled'], false);
      expect(audit['reconstruction_interpolated_points'], greaterThan(0));
      expect(reconstructed.session.routeMatchStatus, 'reconstructed_pchip');
      expect(reconstructed.session.distanceKm, baseline.session.distanceKm);
      expect(reconstructed.session.avgSpeedKmh, baseline.session.avgSpeedKmh);
      expect(reconstructed.session.caloriesKcal, baseline.session.caloriesKcal);
      expect(
        reconstructed.session.filteredRouteJson,
        baseline.session.filteredRouteJson,
      );
      final split = finish(
        route: [
          [const LatLng(10, 106)],
          [const LatLng(10, 106.000137)],
        ],
      );
      expect(split.session.matchedRouteJson, '[]');
    },
  );
}
