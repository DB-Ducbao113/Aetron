import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/core/services/cadence_calculator_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aetron Sensor Event Robustness & Batching Suite', () {
    late MockStepSensorAdapter mockAdapter;
    late CadenceCalculatorService cadenceCalculator;
    late StepTrackingService stepService;

    setUp(() {
      mockAdapter = MockStepSensorAdapter(initialRawSteps: 1000);
      cadenceCalculator = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 6),
        inactivityTimeout: const Duration(seconds: 4),
      );
      stepService = StepTrackingService(
        adapter: mockAdapter,
        cadenceCalculator: cadenceCalculator,
      );
    });

    tearDown(() {
      stepService.dispose();
    });

    test('1. Out-of-order packets are rejected without corrupting baseline or step count', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);

      // Baseline
      mockAdapter.emitSample(rawSteps: 1000, timestamp: t0);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(0));

      // Normal progression: +5 steps at t = 3s
      final t1 = t0.add(const Duration(seconds: 3));
      mockAdapter.emitSample(rawSteps: 1005, timestamp: t1);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(5));

      // Out-of-order packet arriving late: timestamp is t = 2s, rawSteps = 1003
      final tOld = t0.add(const Duration(seconds: 2));
      mockAdapter.emitSample(rawSteps: 1003, timestamp: tOld);
      await pumpEventQueue();

      // Must be rejected! Active steps remains 5, baseline is NOT corrupted
      expect(stepService.currentActiveSteps, equals(5));

      // Next valid progression: +4 steps at t = 6s
      final t2 = t0.add(const Duration(seconds: 6));
      mockAdapter.emitSample(rawSteps: 1009, timestamp: t2);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(9));
    });

    test('2. Duplicate packets are cleanly ignored without redundant increments', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);

      mockAdapter.emitSample(rawSteps: 2000, timestamp: t0);
      await pumpEventQueue();

      final t1 = t0.add(const Duration(seconds: 2));
      mockAdapter.emitSample(rawSteps: 2004, timestamp: t1);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(4));

      // Exact duplicate of previous sample
      mockAdapter.emitSample(rawSteps: 2004, timestamp: t1);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(4));
    });

    test('3. Hardware micro-burst batching (<= 5 steps within < 100ms) is accepted without false spike rejection', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);

      mockAdapter.emitSample(rawSteps: 5000, timestamp: t0);
      await pumpEventQueue();

      // Batch 1: at t = 2.0s (+4 steps)
      final t1 = t0.add(const Duration(seconds: 2));
      mockAdapter.emitSample(rawSteps: 5004, timestamp: t1);
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(4));

      // Batch 2 arrived 50ms later in a micro-burst (+2 steps in 50ms = 40 st/s)
      // Normal Android HAL stride burst granularity!
      final tBurst = t1.add(const Duration(milliseconds: 50));
      mockAdapter.emitSample(rawSteps: 5006, timestamp: tBurst);
      await pumpEventQueue();

      // Must be ACCEPTED! Not falsely dropped by spike guard!
      expect(stepService.currentActiveSteps, equals(6));
    });

    test('4. Realistic Android batching intervals (2s, 5s, 10s, 30s) are fully preserved', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);

      mockAdapter.emitSample(rawSteps: 10000, timestamp: t0);
      await pumpEventQueue();

      // Batch 2s: 6 steps (180 spm = 3 st/s)
      mockAdapter.emitSample(rawSteps: 10006, timestamp: t0.add(const Duration(seconds: 2)));
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(6));

      // Batch 5s: 15 steps (3 st/s)
      mockAdapter.emitSample(rawSteps: 10021, timestamp: t0.add(const Duration(seconds: 7)));
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(21));

      // Batch 10s: 30 steps (3 st/s)
      mockAdapter.emitSample(rawSteps: 10051, timestamp: t0.add(const Duration(seconds: 17)));
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(51));

      // Batch 30s (Doze mode wakeup): 90 steps (3 st/s)
      mockAdapter.emitSample(rawSteps: 10141, timestamp: t0.add(const Duration(seconds: 47)));
      await pumpEventQueue();
      expect(stepService.currentActiveSteps, equals(141));
    });

    test('5. Dropped intermediate cumulative packets do not cause step loss', () async {
      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);

      mockAdapter.emitSample(rawSteps: 500, timestamp: t0);
      await pumpEventQueue();

      // Packets 501..514 were dropped by OS/IPC; sample 515 arrives at t = 5s
      mockAdapter.emitSample(rawSteps: 515, timestamp: t0.add(const Duration(seconds: 5)));
      await pumpEventQueue();

      // Cumulative counter automatically catches up without missing any steps
      expect(stepService.currentActiveSteps, equals(15));
    });

    test('6. Distinguish stationary cadence (0 spm) from sensor unavailable state', () async {
      expect(stepService.isCadenceAvailable, isFalse, reason: 'Before tracking/baseline, cadence is unavailable');

      await stepService.startTracking();
      final t0 = DateTime(2026, 11, 5, 8, 0, 0);
      mockAdapter.emitSample(rawSteps: 100, timestamp: t0);
      await pumpEventQueue();

      // Active stepping
      for (var s = 1; s <= 6; s++) {
        mockAdapter.emitSample(
          rawSteps: 100 + s * 2,
          timestamp: t0.add(Duration(seconds: s)),
        );
      }
      await pumpEventQueue();

      expect(stepService.currentActiveSteps, equals(12));
      expect(stepService.currentCadenceSpm, greaterThan(60));
      expect(stepService.isCadenceAvailable, isTrue);

      // Stop moving: time advances by 5 seconds with no new steps
      // Inactivity timeout triggers cadence = 0 spm (user standing still)
      mockAdapter.emitSample(
        rawSteps: 112,
        timestamp: t0.add(const Duration(seconds: 11)),
      );
      await pumpEventQueue();

      expect(stepService.currentCadenceSpm, equals(0), reason: 'Stationary user has cadence 0');
      expect(stepService.isCadenceAvailable, isTrue, reason: 'Sensor is healthy and actively reporting, user is just standing still');
    });
  });
}
