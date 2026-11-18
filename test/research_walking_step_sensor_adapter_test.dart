import 'dart:async';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/sensor/research_walking_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/sensor/step_sensor_types.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'raw IMU source owns counts, then OS fallback rebases without duplication',
    () async {
      final os = MockStepSensorAdapter(initialRawSteps: 1000);
      final raw = StreamController<AccelerometerEvent>();
      final adapter = ResearchWalkingStepSensorAdapter(
        fallback: os,
        rawStream: () => raw.stream,
      );
      final samples = <StepSensorSample>[];
      final sub = adapter.sampleStream.listen(samples.add);
      final start = adapter.startStream();
      await flush();
      final epoch = DateTime.now();
      for (var i = 0; i < 1000; i++) {
        raw.add(
          AccelerometerEvent(
            0,
            0,
            9.81 + 3 * math.sin(2 * math.pi * 2 * i / 100),
            epoch.add(Duration(milliseconds: i * 10)),
          ),
        );
      }
      await start;
      await flush();
      expect(os.isStreaming, isFalse);
      expect(
        samples.every((s) => s.source == StepSensorSource.oxfordWpd),
        isTrue,
      );
      final before = samples.last.rawSteps;
      expect(before, greaterThan(10));

      raw.addError(StateError('accelerometer disconnected'));
      await flush();
      expect(os.isStreaming, isTrue);
      final next = epoch.add(const Duration(seconds: 11));
      os.emitSample(rawSteps: 50000, timestamp: next);
      await flush();
      expect(samples.last.rawSteps, before);
      expect(samples.last.source, StepSensorSource.mock);
      os.emitSample(
        rawSteps: 50003,
        timestamp: next.add(const Duration(seconds: 2)),
      );
      await flush();
      expect(samples.last.rawSteps, before + 3);
      os.emitSample(
        rawSteps: 50001,
        timestamp: next.add(const Duration(seconds: 1)),
      );
      await flush();
      expect(samples.last.rawSteps, before + 3);

      await adapter.stopStream();
      expect(os.isStreaming, isFalse);
      await sub.cancel();
      await raw.close();
      adapter.dispose();
      os.dispose();
    },
  );

  test(
    'Running selects Xu, excludes paused motion and rebases OS fallback',
    () async {
      final os = MockStepSensorAdapter(initialRawSteps: 1000);
      final raw = StreamController<AccelerometerEvent>();
      final adapter = ResearchWalkingStepSensorAdapter(
        fallback: os,
        running: true,
        rawStream: () => raw.stream,
      );
      final service = StepTrackingService(
        adapter: os,
        runningResearchAdapter: adapter,
      );
      final updates = <WorkoutStepUpdate>[];
      final sub = service.updateStream.listen(updates.add);
      final started = service.startTracking(
        activityType: 'Running',
        useResearchImu: true,
      );
      await flush();
      final epoch = DateTime.now();
      void feed(int start, int end, {bool resting = false}) {
        for (var i = start; i < end; i++) {
          raw.add(
            AccelerometerEvent(
              0,
              0,
              resting ? 9.81 : 9.81 + 4 * math.sin(2 * math.pi * 2.5 * i / 50),
              epoch.add(Duration(milliseconds: i * 20)),
            ),
          );
        }
      }

      feed(0, 500);
      await started;
      await flush();
      final initial = service.currentActiveSteps;
      expect(initial, inInclusiveRange(20, 25));
      expect(updates.last.source, StepSensorSource.xuRunning);
      expect(os.isStreaming, false);
      service.pauseTracking(epoch.add(const Duration(seconds: 10)));
      feed(500, 1000);
      await flush();
      expect(service.currentActiveSteps, initial);
      expect(service.currentCadenceSpm, 0);
      service.resumeTracking(epoch.add(const Duration(seconds: 20)));
      feed(1000, 1500);
      await flush();
      expect(service.currentActiveSteps - initial, inInclusiveRange(20, 25));
      feed(1500, 2000, resting: true);
      await flush();
      expect(service.currentCadenceSpm, 0);
      final beforeFallback = service.currentActiveSteps;
      raw.addError(StateError('raw lost'));
      await flush();
      expect(os.isStreaming, true);
      final fallbackStart = epoch.add(const Duration(seconds: 41));
      os.emitSample(rawSteps: 50000, timestamp: fallbackStart);
      await flush();
      expect(service.currentActiveSteps, beforeFallback);
      os.emitSample(
        rawSteps: 50003,
        timestamp: fallbackStart.add(const Duration(seconds: 2)),
      );
      await flush();
      expect(service.currentActiveSteps, beforeFallback + 3);
      expect(updates.last.source, StepSensorSource.mock);
      service.stopTracking();
      await flush();
      await sub.cancel();
      await raw.close();
      service.dispose();
    },
  );

  test('raw unavailable at startup falls back to OS', () async {
    final os = MockStepSensorAdapter();
    final adapter = ResearchWalkingStepSensorAdapter(
      fallback: os,
      rawStream: () =>
          Stream<AccelerometerEvent>.error(StateError('no sensor')),
    );
    final samples = <StepSensorSample>[];
    final sub = adapter.sampleStream.listen(samples.add);
    await adapter.startStream();
    expect(os.isStreaming, isTrue);
    os.emitSample(rawSteps: 2400);
    await flush();
    expect(samples.last.rawSteps, 0);
    os.emitSample(rawSteps: 2401);
    await flush();
    expect(samples.last.rawSteps, 1);
    await adapter.stopStream();
    await sub.cancel();
    adapter.dispose();
    os.dispose();
  });

  test('cycling retains original OS counters with research flag', () async {
    for (final mode in ['cycling']) {
      final os = MockStepSensorAdapter();
      final service = StepTrackingService(adapter: os);
      await service.startTracking(activityType: mode, useResearchImu: true);
      final start = DateTime.now();
      os.emitSample(rawSteps: 2000, timestamp: start);
      os.emitSample(
        rawSteps: 2004,
        timestamp: start.add(const Duration(seconds: 2)),
      );
      await flush();
      expect(service.currentActiveSteps, 4);
      service.stopTracking();
      service.dispose();
    }
  });

  test(
    'walking service excludes paused raw motion and emits zero cadence at rest',
    () async {
      final os = MockStepSensorAdapter();
      final raw = StreamController<AccelerometerEvent>();
      final adapter = ResearchWalkingStepSensorAdapter(
        fallback: os,
        rawStream: () => raw.stream,
      );
      final service = StepTrackingService(
        adapter: os,
        researchAdapter: adapter,
      );
      final updates = <WorkoutStepUpdate>[];
      final sub = service.updateStream.listen(updates.add);
      final started = service.startTracking(
        activityType: 'walking',
        useResearchImu: true,
      );
      await flush();
      final epoch = DateTime.now();
      void feed(int from, int end, {bool stationary = false}) {
        for (var i = from; i < end; i++) {
          raw.add(
            AccelerometerEvent(
              0,
              0,
              stationary
                  ? 9.81
                  : 9.81 + 3 * math.sin(2 * math.pi * 2 * i / 100),
              epoch.add(Duration(milliseconds: i * 10)),
            ),
          );
        }
      }

      feed(0, 1000);
      await started;
      await flush();
      final initial = service.currentActiveSteps;
      expect(initial, greaterThan(10));
      expect(updates.last.source, StepSensorSource.oxfordWpd);
      service.pauseTracking(epoch.add(const Duration(seconds: 10)));
      feed(1000, 2000);
      await flush();
      expect(service.currentActiveSteps, initial);
      expect(service.currentCadenceSpm, 0);
      service.resumeTracking(epoch.add(const Duration(seconds: 20)));
      feed(2000, 3000);
      await flush();
      expect(service.currentActiveSteps, greaterThan(initial));
      feed(3000, 3800, stationary: true);
      await flush();
      expect(updates.last.currentCadenceSpm, 0);
      expect(updates.last.deltaSteps, 0);
      service.stopTracking();
      await flush();
      await sub.cancel();
      await raw.close();
      service.dispose();
    },
  );
}
