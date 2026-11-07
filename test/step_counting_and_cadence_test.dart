import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/core/services/cadence_calculator_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('INTERLIVE Step Counting Validation Suite', () {
    late MockStepSensorAdapter mockAdapter;
    late CadenceCalculatorService cadenceCalculator;
    late StepTrackingService stepService;

    setUp(() {
      mockAdapter = MockStepSensorAdapter(initialRawSteps: 5000);
      cadenceCalculator = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 6),
        inactivityTimeout: const Duration(seconds: 3),
      );
      stepService = StepTrackingService(
        adapter: mockAdapter,
        cadenceCalculator: cadenceCalculator,
      );
    });

    tearDown(() {
      stepService.dispose();
    });

    test('1. Baseline capture on workout start isolates workout steps from all-day total', () async {
      await stepService.startTracking();

      // Initial hardware reading: 5000 (all-day steps before workout)
      final startTime = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 5000, timestamp: startTime);
      await pumpEventQueue();

      expect(stepService.currentActiveSteps, equals(0));
      expect(stepService.isTracking, isTrue);
      expect(stepService.isPaused, isFalse);
    });

    test('2. Walking Protocol — 100 reference steps at ~105 spm', () async {
      await stepService.startTracking();
      final startTime = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 5000, timestamp: startTime);
      await pumpEventQueue();

      const referenceSteps = 100;
      // 100 steps over 57 seconds = ~105 spm
      const testDurationSec = 57;
      final stepIntervalMs = (testDurationSec * 1000) ~/ referenceSteps;

      var currentTime = startTime;
      for (var i = 1; i <= referenceSteps; i++) {
        currentTime = currentTime.add(Duration(milliseconds: stepIntervalMs));
        mockAdapter.emitSample(rawSteps: 5000 + i, timestamp: currentTime);
      }
      await pumpEventQueue();

      final measuredSteps = stepService.currentActiveSteps;
      final absError = (measuredSteps - referenceSteps).abs();
      final percentError = (absError / referenceSteps) * 100.0;

      expect(measuredSteps, equals(referenceSteps));
      expect(absError, equals(0));
      expect(percentError, equals(0.0));
      // Cadence should reflect ~105 spm
      expect(stepService.currentCadenceSpm, inInclusiveRange(95, 115));
      expect(stepService.currentAvgCadenceSpm, inInclusiveRange(95, 115));
    });

    test('3. Running Protocol — 200 reference steps at ~170 spm', () async {
      await stepService.startTracking();
      final startTime = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 12000, timestamp: startTime);
      await pumpEventQueue();

      const referenceSteps = 200;
      // 200 steps at 170 spm = ~70.5 seconds (step every ~353 ms)
      const stepIntervalMs = 353;

      var currentTime = startTime;
      for (var i = 1; i <= referenceSteps; i++) {
        currentTime = currentTime.add(const Duration(milliseconds: stepIntervalMs));
        mockAdapter.emitSample(rawSteps: 12000 + i, timestamp: currentTime);
      }
      await pumpEventQueue();

      final measuredSteps = stepService.currentActiveSteps;
      final absError = (measuredSteps - referenceSteps).abs();
      final percentError = (absError / referenceSteps) * 100.0;

      expect(measuredSteps, equals(referenceSteps));
      expect(absError, equals(0));
      expect(percentError, lessThan(1.0));
      expect(stepService.currentCadenceSpm, inInclusiveRange(165, 175));
      expect(stepService.currentAvgCadenceSpm, inInclusiveRange(165, 175));
    });

    test('4. Standing Still Protocol — zero steps accumulated and cadence drops to 0', () async {
      await stepService.startTracking();
      final startTime = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 3000, timestamp: startTime);
      await pumpEventQueue();

      // Take 10 steps to establish motion
      var currentTime = startTime;
      for (var i = 1; i <= 10; i++) {
        currentTime = currentTime.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 3000 + i, timestamp: currentTime);
      }
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(10));
      expect(stepService.currentCadenceSpm, greaterThan(0));

      // Stand still for 10 seconds (no steps, timestamp advances)
      currentTime = currentTime.add(const Duration(seconds: 10));
      mockAdapter.emitSample(rawSteps: 3010, timestamp: currentTime);
      await pumpEventQueue();

      expect(stepService.currentActiveSteps, equals(10));
      // Inactivity timeout triggers zero cadence
      expect(stepService.currentCadenceSpm, equals(0));
    });

    test('5. Placement Scenarios — Trouser pocket, Handheld, Bag carrying simulation', () async {
      await stepService.startTracking();
      final startTime = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 4000, timestamp: startTime);
      await pumpEventQueue();

      // Scenario A: Trouser Pocket (regular periodic steps, high signal quality)
      var time = startTime;
      for (var i = 1; i <= 50; i++) {
        time = time.add(const Duration(milliseconds: 550));
        mockAdapter.emitSample(rawSteps: 4000 + i, timestamp: time);
      }
      await pumpEventQueue();
      final pocketSteps = stepService.currentActiveSteps;
      expect(pocketSteps, equals(50));

      // Scenario B: Handheld (slight arm-swing irregularity)
      for (var i = 1; i <= 50; i++) {
        final jitter = (i % 3 == 0) ? 600 : 520;
        time = time.add(Duration(milliseconds: jitter));
        mockAdapter.emitSample(rawSteps: 4050 + i, timestamp: time);
      }
      await pumpEventQueue();
      final handheldSteps = stepService.currentActiveSteps;
      expect(handheldSteps, equals(100));

      // Scenario C: Bag placement (sensor hardware batching / delayed deliveries)
      time = time.add(const Duration(seconds: 8));
      mockAdapter.emitSample(rawSteps: 4115, timestamp: time); // 15 steps in burst
      time = time.add(const Duration(seconds: 8));
      mockAdapter.emitSample(rawSteps: 4130, timestamp: time); // 15 steps in burst
      await pumpEventQueue();

      final totalWithBag = stepService.currentActiveSteps;
      expect(totalWithBag, equals(130));
    });

    test('6. Pause and Resume Accounting — Steps during pause are strictly segregated', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 1000, timestamp: t0);
      await pumpEventQueue();

      // Active phase 1: walk 60 steps
      var t = t0;
      for (var i = 1; i <= 60; i++) {
        t = t.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 1000 + i, timestamp: t);
      }
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(60));

      // Pause workout
      stepService.pauseTracking(t);
      expect(stepService.isPaused, isTrue);
      expect(stepService.currentCadenceSpm, equals(0));

      // Walk 40 steps while paused (e.g. coffee shop or waiting at traffic light)
      for (var i = 1; i <= 40; i++) {
        t = t.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 1060 + i, timestamp: t);
      }
      await pumpEventQueue();
      // Active workout steps must NOT have increased!
      expect(stepService.currentActiveSteps, equals(60));

      // Resume workout
      stepService.resumeTracking(t);
      expect(stepService.isPaused, isFalse);

      // Active phase 2: walk 50 more steps
      for (var i = 1; i <= 50; i++) {
        t = t.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 1100 + i, timestamp: t);
      }
      await pumpEventQueue();

      // Expected active steps: 60 + 50 = 110. Paused 40 steps must not be counted!
      expect(stepService.currentActiveSteps, equals(110));
    });

    test('7. Device Reboot & Hardware Counter Reset Recovery', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 80000, timestamp: t0);
      await pumpEventQueue();

      // Walk 50 steps before reboot
      var t = t0;
      for (var i = 1; i <= 50; i++) {
        t = t.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 80000 + i, timestamp: t);
      }
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(50));

      // Device reboots: counter resets to 0 or small number (e.g. 5)
      t = t.add(const Duration(seconds: 45));
      mockAdapter.simulateReboot(rebootInitialSteps: 5, timestamp: t);
      await pumpEventQueue();

      // Active steps must remain 50 (no negative regression or wipeout)
      expect(stepService.currentActiveSteps, equals(50));

      // Walk 25 more steps after reboot
      for (var i = 1; i <= 25; i++) {
        t = t.add(const Duration(milliseconds: 500));
        mockAdapter.emitSample(rawSteps: 5 + i, timestamp: t);
      }
      await pumpEventQueue();

      expect(stepService.currentActiveSteps, equals(75));
    });

    test('8. Spike Filtering — Drops unrealistic step deltas (> 4.5 steps/sec)', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 2000, timestamp: t0);
      await pumpEventQueue();

      // 5 normal steps in 2.5s (2 steps/s)
      final t1 = t0.add(const Duration(milliseconds: 2500));
      mockAdapter.emitSample(rawSteps: 2005, timestamp: t1);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(5));

      // Sensor glitch / violent shake: jumps 100 steps in 100 milliseconds (1000 steps/s > 4.5)
      final tGlitch = t1.add(const Duration(milliseconds: 100));
      mockAdapter.emitSample(rawSteps: 2105, timestamp: tGlitch);
      await pumpEventQueue();

      // Spike must be discarded!
      expect(stepService.currentActiveSteps, equals(5));

      // Subsequent valid sample
      final tValid = tGlitch.add(const Duration(seconds: 2));
      mockAdapter.emitSample(rawSteps: 2009, timestamp: tValid);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(9));
    });

    test('9. Native Cadence Passthrough and Unit Verification (Apple CoreMotion steps/s to SPM)', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(
        rawSteps: 1000,
        timestamp: t0,
        nativeCadenceStepsPerSec: 2.75, // 2.75 steps/s * 60 = 165 spm
      );
      await pumpEventQueue();

      final t1 = t0.add(const Duration(seconds: 1));
      mockAdapter.emitSample(
        rawSteps: 1003,
        timestamp: t1,
        nativeCadenceStepsPerSec: 2.8333, // 2.8333 steps/s * 60 = ~170 spm
      );
      await pumpEventQueue();

      expect(stepService.currentCadenceSpm, equals(170));
    });

    test('10. Permissions and Sensor Unavailable Handlers', () async {
      final deniedAdapter = MockStepSensorAdapter(hasPermission: false);
      final deniedService = StepTrackingService(adapter: deniedAdapter);

      expect(
        () => deniedService.startTracking(),
        throwsA(isA<Exception>()),
      );

      final unavailAdapter = MockStepSensorAdapter(isAvailable: false);
      final status = await unavailAdapter.checkStatus();
      expect(status.isAvailable, isFalse);
    });

    test('11. Multi-Session MAE and MAPE Statistical Benchmark (INTERLIVE)', () async {
      final sessionConfigs = [
        {'name': 'S1_Walk_Slow', 'refSteps': 80, 'durationSec': 60, 'expectedCadence': 80},
        {'name': 'S2_Walk_Brisk', 'refSteps': 115, 'durationSec': 60, 'expectedCadence': 115},
        {'name': 'S3_Jog', 'refSteps': 150, 'durationSec': 60, 'expectedCadence': 150},
        {'name': 'S4_Run_Cadence', 'refSteps': 175, 'durationSec': 60, 'expectedCadence': 175},
        {'name': 'S5_Interval', 'refSteps': 140, 'durationSec': 60, 'expectedCadence': 140},
      ];

      var totalAbsError = 0.0;
      var totalAbsPercentError = 0.0;

      for (final config in sessionConfigs) {
        final adapter = MockStepSensorAdapter(initialRawSteps: 10000);
        final service = StepTrackingService(adapter: adapter);
        await service.startTracking();

        final refSteps = config['refSteps'] as int;
        final durationSec = config['durationSec'] as int;
        final stepIntervalMs = (durationSec * 1000) ~/ refSteps;

        var t = DateTime(2026, 11, 5, 9, 0, 0);
        adapter.emitSample(rawSteps: 10000, timestamp: t);
        await pumpEventQueue();

        for (var i = 1; i <= refSteps; i++) {
          t = t.add(Duration(milliseconds: stepIntervalMs));
          adapter.emitSample(rawSteps: 10000 + i, timestamp: t);
        }
        await pumpEventQueue();

        final measured = service.currentActiveSteps;
        final error = (measured - refSteps).abs().toDouble();
        final percentError = (error / refSteps) * 100.0;

        totalAbsError += error;
        totalAbsPercentError += percentError;

        service.dispose();
      }

      final meanAbsoluteError = totalAbsError / sessionConfigs.length;
      final meanAbsolutePercentageError = totalAbsPercentError / sessionConfigs.length;

      // INTERLIVE validation threshold: MAE <= 1.0 step, MAPE < 3%
      expect(meanAbsoluteError, lessThanOrEqualTo(1.0));
      expect(meanAbsolutePercentageError, lessThan(3.0));
    });
  });
}
