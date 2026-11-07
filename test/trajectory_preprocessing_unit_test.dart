import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Trajectory Preprocessing Unit Tests (Li et al., 2025 & Zheng, 2015)', () {
    const distanceCalc = Distance();
    final t0 = DateTime(2026, 4, 15, 8, 0, 0);

    test('1. KinematicLimits mode-specific parameters are differentiated and grounded', () {
      final walk = KinematicLimits.walking();
      final run = KinematicLimits.running();
      final cycle = KinematicLimits.cycling();

      // Walking limits
      expect(walk.maxSpeedMs, equals(3.5)); // ~12.6 km/h
      expect(walk.maxAccelerationMs2, equals(2.5));
      expect(walk.minSegmentMeters, equals(0.8));
      expect(walk.stayPointMaxDistanceMeters, equals(8.0));

      // Running limits
      expect(run.maxSpeedMs, equals(8.0)); // ~28.8 km/h
      expect(run.maxAccelerationMs2, equals(4.5));
      expect(run.minSegmentMeters, equals(1.2));
      expect(run.stayPointMaxDistanceMeters, equals(10.0));

      // Cycling limits
      expect(cycle.maxSpeedMs, equals(22.0)); // ~79.2 km/h
      expect(cycle.maxAccelerationMs2, equals(6.0));
      expect(cycle.minSegmentMeters, equals(2.5));
      expect(cycle.stayPointMaxDistanceMeters, equals(12.0));

      // Activity string factory mapping
      expect(KinematicLimits.forActivity('walking').maxSpeedMs, equals(3.5));
      expect(KinematicLimits.forActivity('Running').maxSpeedMs, equals(8.0));
      expect(KinematicLimits.forActivity('cycling').maxSpeedMs, equals(22.0));
    });

    test('2. Raw GPS samples remain strictly immutable during preprocessing', () {
      final preprocessor = TrajectoryPreprocessor.forActivity('running');
      final rawSamples = [
        TrajectoryRawSample(
          index: 0,
          timestamp: t0,
          point: const LatLng(10.7791, 106.6973),
          accuracyMeters: 4.0,
          sensorSpeedMs: 3.0,
        ),
        TrajectoryRawSample(
          index: 1,
          timestamp: t0.add(const Duration(seconds: 1)),
          point: const LatLng(10.7792, 106.6974),
          accuracyMeters: 4.0,
          sensorSpeedMs: 3.2,
        ),
      ];

      final origLat = rawSamples[0].latitude;
      final origLng = rawSamples[0].longitude;

      final result = preprocessor.processBatch(rawSamples);

      // Verify original objects are untouched
      expect(rawSamples[0].latitude, equals(origLat));
      expect(rawSamples[0].longitude, equals(origLng));
      expect(result.rawSamples.length, equals(2));
      expect(result.rawSamples[0].point, equals(rawSamples[0].point));
    });

    test('3. Outlier Detection: flags speed spikes without deleting raw samples', () {
      final streaming = TrajectoryPreprocessor.forActivity('walking').createStreamingSession();

      // Sample 0: Normal walk start
      final p0 = streaming.processSample(TrajectoryRawSample(
        index: 0,
        timestamp: t0,
        point: const LatLng(10.77910, 106.69730),
        accuracyMeters: 4.0,
      ));
      expect(p0.isClean, isTrue);
      expect(p0.isAccepted, isTrue);

      // Sample 1: Normal walk step (1.4m in 1s -> 1.4 m/s <= 3.5 m/s)
      final p1 = streaming.processSample(TrajectoryRawSample(
        index: 1,
        timestamp: t0.add(const Duration(seconds: 1)),
        point: const LatLng(10.77911, 106.69731),
        accuracyMeters: 4.0,
      ));
      expect(p1.isClean, isTrue);
      expect(p1.isAccepted, isTrue);

      // Sample 2: Impossible teleport spike (100m in 1s -> 100 m/s >> 3.5 m/s)
      final p2 = streaming.processSample(TrajectoryRawSample(
        index: 2,
        timestamp: t0.add(const Duration(seconds: 2)),
        point: const LatLng(10.78000, 106.69830), // ~140m away
        accuracyMeters: 4.0,
      ));
      expect(p2.qualityFlags.contains(TrajectoryQualityFlag.speedSpike), isTrue);
      expect(p2.isOutlier, isTrue);
      expect(p2.isAccepted, isFalse);
      // Raw data is preserved inside processed point!
      expect(p2.rawSample.latitude, equals(10.78000));

      // Sample 3: Legitimate point following p1 (continues walking from p1)
      final p3 = streaming.processSample(TrajectoryRawSample(
        index: 3,
        timestamp: t0.add(const Duration(seconds: 3)),
        point: const LatLng(10.77912, 106.69732),
        accuracyMeters: 4.0,
      ));
      // Evaluated against p1 (since p2 was rejected as outlier)
      expect(p3.isClean, isTrue);
      expect(p3.isAccepted, isTrue);
    });

    test('4. Outlier Detection: flags acute heading detour spike (ping-pong reflection)', () {
      final streaming = TrajectoryPreprocessor.forActivity('running').createStreamingSession();

      // Heading East (~90 deg)
      streaming.processSample(TrajectoryRawSample(
        index: 0,
        timestamp: t0,
        point: const LatLng(10.77910, 106.69700),
        accuracyMeters: 3.0,
      ));

      streaming.processSample(TrajectoryRawSample(
        index: 1,
        timestamp: t0.add(const Duration(seconds: 1)),
        point: const LatLng(10.77910, 106.69705), // ~5.5m East
        accuracyMeters: 3.0,
      ));

      // Ping-pong spike: jumps North-West 25m in 1s then turns sharply back
      final p2 = streaming.processSample(TrajectoryRawSample(
        index: 2,
        timestamp: t0.add(const Duration(seconds: 2)),
        point: const LatLng(10.77930, 106.69680), // Acute reversal jump
        accuracyMeters: 3.0,
      ));

      // Detected as speed spike or heading spike
      expect(p2.isOutlier, isTrue);
      expect(p2.isAccepted, isFalse);
    });

    test('5. Signal Gap & Outage Handling: strictly avoids interpolating long outages', () {
      final streaming = TrajectoryPreprocessor.forActivity('cycling').createStreamingSession();

      // Fix 1: Normal cycling point cruising at 7 m/s
      final p0 = streaming.processSample(TrajectoryRawSample(
        index: 0,
        timestamp: t0,
        point: const LatLng(10.77910, 106.69700),
        accuracyMeters: 4.0,
        sensorSpeedMs: 7.0,
      ));
      expect(p0.isAccepted, isTrue);

      // Fix 2: 1 second later (displacement ~7.0m)
      final p1 = streaming.processSample(TrajectoryRawSample(
        index: 1,
        timestamp: t0.add(const Duration(seconds: 1)),
        point: const LatLng(10.77915, 106.69705),
        accuracyMeters: 4.0,
        sensorSpeedMs: 7.0,
      ));
      expect(p1.isAccepted, isTrue);
      final initialDist = streaming.accumulatedCleanDistanceMeters;
      expect(initialDist, greaterThan(0));

      // 45-second GPS blackout tunnel (dt = 45s > dt_gap = 5s)
      final p2 = streaming.processSample(TrajectoryRawSample(
        index: 2,
        timestamp: t0.add(const Duration(seconds: 46)),
        point: const LatLng(10.78200, 106.70000), // Exit tunnel 450m away
        accuracyMeters: 5.0,
        sensorSpeedMs: 8.0,
      ));

      // p2 is marked as signalGap and isGapRecovery
      expect(p2.qualityFlags.contains(TrajectoryQualityFlag.signalGap), isTrue);
      expect(p2.isGapRecovery, isTrue);
      expect(p2.isAccepted, isTrue); // accepted as a new anchor!

      // Accumulated distance MUST NOT add the 450m unobserved tunnel jump!
      expect(streaming.accumulatedCleanDistanceMeters, equals(initialDist));

      // Fix 3: 1 second after recovery
      final p3 = streaming.processSample(TrajectoryRawSample(
        index: 3,
        timestamp: t0.add(const Duration(seconds: 47)),
        point: const LatLng(10.78205, 106.70005),
        accuracyMeters: 5.0,
        sensorSpeedMs: 8.0,
      ));
      expect(p3.isAccepted, isTrue);
      expect(p3.isGapRecovery, isFalse);
      // Now normal distance continues
      expect(streaming.accumulatedCleanDistanceMeters, greaterThan(initialDist));
    });

    test('6. Zheng et al. (2009) Stay Point Detection: segments stationary dwell & eliminates phantom drift', () {
      final batch = BatchTrajectoryPreprocessor(limits: KinematicLimits.walking());
      final samples = <TrajectoryRawSample>[];

      // Leg 1: Move segment (20 seconds walking East)
      for (var s = 0; s < 20; s++) {
        samples.add(TrajectoryRawSample(
          index: s,
          timestamp: t0.add(Duration(seconds: s)),
          point: LatLng(10.77910, 106.69700 + (s * 0.000012)), // ~1.3 m/s
          accuracyMeters: 3.0,
        ));
      }

      // Leg 2: Stationary Dwell (40 seconds stop at red light: slight GPS jitter <= 4m around centroid)
      const dwellCenter = LatLng(10.77910, 106.69724);
      for (var s = 20; s < 60; s++) {
        final jitterLat = (s % 3 - 1) * 0.000015; // +/- 1.6m
        final jitterLng = ((s * 2) % 3 - 1) * 0.000015;
        samples.add(TrajectoryRawSample(
          index: s,
          timestamp: t0.add(Duration(seconds: s)),
          point: LatLng(dwellCenter.latitude + jitterLat, dwellCenter.longitude + jitterLng),
          accuracyMeters: 4.0,
        ));
      }

      // Leg 3: Move segment (20 seconds walking North)
      for (var s = 60; s < 80; s++) {
        samples.add(TrajectoryRawSample(
          index: s,
          timestamp: t0.add(Duration(seconds: s)),
          point: LatLng(dwellCenter.latitude + ((s - 60) * 0.000012), dwellCenter.longitude),
          accuracyMeters: 3.0,
        ));
      }

      final result = batch.process(samples);

      // Assertions
      expect(result.totalRawCount, equals(80));
      expect(result.stayPointsCount, equals(1), reason: 'Must detect exactly 1 stay point');
      expect(result.totalStayDurationSeconds, greaterThanOrEqualTo(39.0));

      // Segments must have Move -> Stay -> Move
      expect(result.segments.length, equals(3));
      expect(result.segments[0].type, equals(TrajectorySegmentType.move));
      expect(result.segments[1].type, equals(TrajectorySegmentType.stay));
      expect(result.segments[2].type, equals(TrajectorySegmentType.move));

      // Stay point centroid should be very close to ground-truth dwellCenter
      final stayCentroid = result.segments[1].centroid!;
      final centroidDist = distanceCalc.distance(stayCentroid, dwellCenter);
      expect(centroidDist, lessThan(3.0), reason: 'Centroid must match dwell cluster center');

      // Phantom jitter accumulated during dwell must be eliminated
      expect(result.stationaryDriftEliminatedMeters, greaterThan(30.0));
      expect(result.cleanDistanceMeters, lessThan(result.rawTotalDistanceMeters));
    });

    test('7. Batch Sliding-Window Median Filter isolates gross coordinate deviations', () {
      final detector = TrajectoryOutlierDetector(limits: KinematicLimits.walking());
      final points = <ProcessedTrajectoryPoint>[];

      // 9 straight collinear points along a line
      for (var i = 0; i < 9; i++) {
        final lat = 10.77900 + (i * 0.00001);
        final raw = TrajectoryRawSample(
          index: i,
          timestamp: t0.add(Duration(seconds: i)),
          point: LatLng(lat, 106.69700),
          accuracyMeters: 3.0,
        );

        points.add(ProcessedTrajectoryPoint(
          rawSample: raw,
          qualityFlags: {TrajectoryQualityFlag.clean},
          segmentDistanceMeters: 1.1,
          timeDeltaSec: 1.0,
          impliedSpeedMs: 1.1,
          impliedAccelerationMs2: 0.0,
          isAccepted: true,
        ));
      }

      // Inject a spatial deviation at index 4 (middle) that moved 30m East while maintaining plausible timing
      final injectedRaw = TrajectoryRawSample(
        index: 4,
        timestamp: t0.add(const Duration(seconds: 4)),
        point: const LatLng(10.77904, 106.69730), // ~33m East
        accuracyMeters: 3.0,
      );
      points[4] = ProcessedTrajectoryPoint(
        rawSample: injectedRaw,
        qualityFlags: {TrajectoryQualityFlag.clean},
        segmentDistanceMeters: 1.1,
        timeDeltaSec: 1.0,
        impliedSpeedMs: 1.1,
        impliedAccelerationMs2: 0.0,
        isAccepted: true,
      );

      final filtered = detector.applyBatchMedianFilter(points);

      expect(filtered[4].qualityFlags.contains(TrajectoryQualityFlag.statisticalOutlier), isTrue);
      expect(filtered[4].isAccepted, isFalse);
      // Surrounding points remain clean
      expect(filtered[3].isAccepted, isTrue);
      expect(filtered[5].isAccepted, isTrue);
    });
  });
}
