import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_sample.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/kinematic_trajectory_reconstruction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/trajectory_reconstruction_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('KinematicTrajectoryReconstructionEngine (P03) Unit Tests', () {
    late KinematicTrajectoryReconstructionEngine engine;

    setUp(() {
      engine = const KinematicTrajectoryReconstructionEngine();
    });

    ProcessedTrajectoryPoint makePoint({
      required int index,
      required DateTime timestamp,
      required LatLng point,
      double speedMs = 5.0,
      double? headingDeg,
      bool isStay = false,
      bool isGapRecovery = false,
    }) {
      final raw = TrajectoryRawSample(
        index: index,
        timestamp: timestamp,
        point: point,
        accuracyMeters: 4.0,
        sensorSpeedMs: speedMs,
        sensorHeadingDeg: headingDeg,
      );
      final flags = <TrajectoryQualityFlag>{TrajectoryQualityFlag.clean};
      if (isStay) flags.add(TrajectoryQualityFlag.stayPoint);
      if (isGapRecovery) flags.add(TrajectoryQualityFlag.signalGap);

      return ProcessedTrajectoryPoint(
        rawSample: raw,
        qualityFlags: flags,
        segmentDistanceMeters: speedMs * 1.0,
        timeDeltaSec: 1.0,
        impliedSpeedMs: speedMs,
        impliedAccelerationMs2: 0.0,
        forwardBearingDeg: headingDeg,
        isAccepted: true,
        isGapRecovery: isGapRecovery,
      );
    }

    test('Nominal 1Hz dense stream is preserved without unnecessary interpolation', () {
      final t0 = DateTime(2026, 11, 8, 10, 0, 0);
      final points = [
        makePoint(index: 0, timestamp: t0, point: const LatLng(10.776889, 106.700806), speedMs: 5.0),
        makePoint(index: 1, timestamp: t0.add(const Duration(seconds: 1)), point: const LatLng(10.776934, 106.700806), speedMs: 5.0),
        makePoint(index: 2, timestamp: t0.add(const Duration(seconds: 2)), point: const LatLng(10.776979, 106.700806), speedMs: 5.0),
      ];

      final res = engine.reconstructTrajectory(points: points, activityType: 'cycling');

      expect(res.originalPointCount, equals(3));
      expect(res.reconstructedPointCount, equals(3));
      expect(res.interpolatedPointCount, equals(0));
      expect(res.indeterminateGapCount, equals(0));
      expect(res.points.every((p) => p.gapType == ReconstructionGapType.nominalDense), isTrue);
    });

    test('Sparse recoverable gap (dt = 5.0s) synthesizes smooth intermediate points via PCHIP', () {
      final t0 = DateTime(2026, 11, 8, 10, 0, 0);
      // Gap of 5.0s moving North at 5.0 m/s (~25m distance)
      final points = [
        makePoint(
          index: 0,
          timestamp: t0,
          point: const LatLng(10.776889, 106.700806),
          speedMs: 5.0,
          headingDeg: 0.0,
        ),
        makePoint(
          index: 1,
          timestamp: t0.add(const Duration(seconds: 5)),
          point: const LatLng(10.777114, 106.700806), // ~25m North
          speedMs: 5.0,
          headingDeg: 0.0,
        ),
      ];

      final res = engine.reconstructTrajectory(points: points, activityType: 'cycling');

      expect(res.originalPointCount, equals(2));
      // With dt = 5.0s and step = 1.0s, creates 4 intermediate points (at t=1, 2, 3, 4) + 2 endpoints = 6 points
      expect(res.interpolatedPointCount, equals(4));
      expect(res.reconstructedPointCount, equals(6));
      expect(res.indeterminateGapCount, equals(0));

      // Intermediate points must have monotonic increasing latitude and constant longitude
      for (var i = 1; i < res.points.length; i++) {
        expect(res.points[i].latitude, greaterThan(res.points[i - 1].latitude));
        expect((res.points[i].longitude - 106.700806).abs(), lessThan(1e-6));
      }
    });

    test('Sparse recoverable gap (dt = 5.0s) synthesizes straight intermediate points via Linear Chord', () {
      final t0 = DateTime(2026, 11, 8, 10, 0, 0);
      final points = [
        makePoint(
          index: 0,
          timestamp: t0,
          point: const LatLng(10.776889, 106.700806),
          speedMs: 5.0,
          headingDeg: 0.0,
        ),
        makePoint(
          index: 1,
          timestamp: t0.add(const Duration(seconds: 5)),
          point: const LatLng(10.777114, 106.700806),
          speedMs: 5.0,
          headingDeg: 0.0,
        ),
      ];

      final res = engine.reconstructTrajectory(
        points: points,
        activityType: 'cycling',
        method: ReconstructionMethod.linearChord,
      );

      expect(res.method, equals(ReconstructionMethod.linearChord));
      expect(res.originalPointCount, equals(2));
      expect(res.interpolatedPointCount, equals(4));
      expect(res.reconstructedPointCount, equals(6));

      for (var i = 1; i < res.points.length; i++) {
        expect(res.points[i].latitude, greaterThan(res.points[i - 1].latitude));
        expect((res.points[i].longitude - 106.700806).abs(), lessThan(1e-6));
      }
    });

    test('Severe outage (dt = 30.0s) is isolated as indeterminate without fabricating unobserved path', () {
      final t0 = DateTime(2026, 11, 8, 10, 0, 0);
      final points = [
        makePoint(
          index: 0,
          timestamp: t0,
          point: const LatLng(10.776889, 106.700806),
          speedMs: 5.0,
        ),
        makePoint(
          index: 1,
          timestamp: t0.add(const Duration(seconds: 30)),
          point: const LatLng(10.778500, 106.703000), // Far away after prolonged blackout
          speedMs: 5.0,
          isGapRecovery: true,
        ),
      ];

      final res = engine.reconstructTrajectory(points: points, activityType: 'cycling');

      expect(res.originalPointCount, equals(2));
      expect(res.reconstructedPointCount, equals(2));
      expect(res.interpolatedPointCount, equals(0)); // Zero fictitious points fabricated!
      expect(res.indeterminateGapCount, equals(1));
      expect(res.indeterminateChordDistanceMeters, greaterThan(150.0));
      expect(res.points.last.gapType, equals(ReconstructionGapType.indeterminateOutage));
    });

    test('Stationary dwell points are clustered to centroid with zero accumulated motion', () {
      final t0 = DateTime(2026, 11, 8, 10, 0, 0);
      const stayLoc = LatLng(10.776889, 106.700806);
      final points = [
        makePoint(index: 0, timestamp: t0, point: stayLoc, speedMs: 0.0, isStay: true),
        makePoint(index: 1, timestamp: t0.add(const Duration(seconds: 10)), point: stayLoc, speedMs: 0.0, isStay: true),
      ];

      final res = engine.reconstructTrajectory(points: points, activityType: 'running');

      expect(res.interpolatedPointCount, equals(0));
      expect(res.totalReconstructedDistanceMeters, equals(0.0));
      expect(res.points.last.gapType, equals(ReconstructionGapType.stationaryDwell));
    });
  });
}
