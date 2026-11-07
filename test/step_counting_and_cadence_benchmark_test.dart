import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/core/services/cadence_calculator_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aetron Step Counting & Cadence Public Dataset Benchmark (PedEval)', () {
    late Directory dataDir;
    late File demoFile;

    setUpAll(() {
      final baseDir = Directory.current.path;
      final pedevalDir = '$baseDir/tooling/step_benchmark/pedeval';
      dataDir = Directory('$pedevalDir/Data');
      demoFile = File('$pedevalDir/demographics.csv');
    });

    test('1. Verify PedEval Dataset integrity (30 subjects, 90 sessions)', () {
      expect(demoFile.existsSync(), isTrue, reason: 'demographics.csv must exist');
      expect(dataDir.existsSync(), isTrue, reason: 'PedEval Data directory must exist');

      final pDirs = dataDir.listSync().whereType<Directory>().toList();
      expect(pDirs.length, equals(30), reason: 'Must contain 30 subject directories');

      var totalStepsFound = 0;
      var sessionCount = 0;
      for (final pDir in pDirs) {
        for (final proto in ['Regular', 'SemiRegular', 'Irregular']) {
          final stepsFile = File('${pDir.path}/$proto/steps.txt');
          if (stepsFile.existsSync()) {
            sessionCount++;
            final lines = stepsFile.readAsLinesSync();
            for (final line in lines) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.length >= 2 &&
                  (parts[1].toLowerCase() == 'left' || parts[1].toLowerCase() == 'right')) {
                totalStepsFound++;
              }
            }
          }
        }
      }

      expect(sessionCount, equals(90), reason: 'Must have 90 protocol sessions');
      expect(totalStepsFound, equals(56668), reason: 'Exact reference count from gold standard video');
    });

    test('2. Conservation of Step Totals across all 90 sessions (0 drift)', () async {
      final pDirs = dataDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      var totalRef = 0;
      var totalMeasured = 0;
      final startDate = DateTime(2026, 11, 5, 8, 0, 0);

      for (final pDir in pDirs) {
        for (final proto in ['Regular', 'SemiRegular', 'Irregular']) {
          final stepsFile = File('${pDir.path}/$proto/steps.txt');
          if (!stepsFile.existsSync()) continue;

          final lines = stepsFile.readAsLinesSync();
          final stepTimestamps = <double>[];
          for (final line in lines) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2 &&
                (parts[1].toLowerCase() == 'left' || parts[1].toLowerCase() == 'right')) {
              final frame = int.tryParse(parts[0]);
              if (frame != null) stepTimestamps.add(frame / 15.0);
            }
          }
          if (stepTimestamps.isEmpty) continue;

          final sessionRefSteps = stepTimestamps.length;
          totalRef += sessionRefSteps;

          final mockAdapter = MockStepSensorAdapter(initialRawSteps: 0);
          final stepService = StepTrackingService(adapter: mockAdapter);
          await stepService.startTracking();

          // Baseline
          mockAdapter.emitSample(rawSteps: 0, timestamp: startDate);
          await Future<void>.delayed(Duration.zero);

          // Fast forward steps in 2-second batches
          final durationSec = stepTimestamps.last + 1.0;
          var stepIdx = 0;
          for (var t = 1; t <= durationSec.ceil(); t += 2) {
            final simTimeSec = t.toDouble();
            while (stepIdx < stepTimestamps.length && stepTimestamps[stepIdx] <= simTimeSec) {
              stepIdx++;
            }
            mockAdapter.emitSample(
              rawSteps: stepIdx,
              timestamp: startDate.add(Duration(seconds: t)),
            );
            await Future<void>.delayed(Duration.zero);
          }

          final measured = stepService.currentActiveSteps;
          totalMeasured += measured;
          expect(measured, equals(sessionRefSteps),
              reason: 'Session ${pDir.path}/$proto must have 0 step drift');

          stepService.dispose();
        }
      }

      expect(totalMeasured, equals(totalRef));
      expect(totalMeasured, equals(56668));
    });

    test('3. Cadence MAE & RMSE evaluation against video ground truth (6s window)', () async {
      // Evaluate on P001 Regular session (935 steps over 567s)
      final stepsFile = File('${dataDir.path}/P001/Regular/steps.txt');
      expect(stepsFile.existsSync(), isTrue);

      final lines = stepsFile.readAsLinesSync();
      final stepTimestamps = <double>[];
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 &&
            (parts[1].toLowerCase() == 'left' || parts[1].toLowerCase() == 'right')) {
          final frame = int.tryParse(parts[0]);
          if (frame != null) stepTimestamps.add(frame / 15.0);
        }
      }

      final mockAdapter = MockStepSensorAdapter(initialRawSteps: 0);
      final cadenceCalc = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 6),
        inactivityTimeout: const Duration(seconds: 4),
      );
      final stepService = StepTrackingService(
        adapter: mockAdapter,
        cadenceCalculator: cadenceCalc,
      );

      final startDate = DateTime(2026, 11, 5, 8, 0, 0);
      await stepService.startTracking();
      mockAdapter.emitSample(rawSteps: 0, timestamp: startDate);
      await Future<void>.delayed(Duration.zero);

      final maxSec = stepTimestamps.last.ceil();
      var stepIdx = 0;
      var totalAbsDiff = 0.0;
      var count = 0;

      for (var s = 1; s <= maxSec; s++) {
        final simTimeSec = s.toDouble();
        while (stepIdx < stepTimestamps.length && stepTimestamps[stepIdx] <= simTimeSec) {
          stepIdx++;
        }
        mockAdapter.emitSample(
          rawSteps: stepIdx,
          timestamp: startDate.add(Duration(seconds: s)),
        );
        await Future<void>.delayed(Duration.zero);

        if (s > 6) {
          // Ground truth 6s window count
          final windowStart = math.max(0.0, simTimeSec - 6.0);
          var gtCount = 0;
          for (final ts in stepTimestamps) {
            if (ts > simTimeSec) break;
            if (ts >= windowStart) gtCount++;
          }
          final gtSpm = (gtCount * 60.0) / 6.0;
          final aetronSpm = stepService.currentCadenceSpm.toDouble();

          totalAbsDiff += (aetronSpm - gtSpm).abs();
          count++;
        }
      }

      final mae = count > 0 ? totalAbsDiff / count : 0.0;
      expect(mae, lessThan(2.0), reason: 'Aetron 6s cadence MAE must be within 2.0 spm of ground truth');
      expect(stepService.currentActiveSteps, equals(935));

      stepService.dispose();
    });

    test('4. Synthetic Fault Injection Matrix (Baseline, Pause, Reboot, Spike, Decay)', () async {
      final startDate = DateTime(2026, 11, 5, 8, 0, 0);

      // Fault 1: Baseline Isolation
      {
        final adapter = MockStepSensorAdapter(initialRawSteps: 0);
        final service = StepTrackingService(adapter: adapter);
        await service.startTracking();
        adapter.emitSample(rawSteps: 55432, timestamp: startDate);
        await Future<void>.delayed(Duration.zero);
        adapter.emitSample(rawSteps: 55532, timestamp: startDate.add(const Duration(seconds: 40)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(100));
        service.dispose();
      }

      // Fault 2: Pause / Resume Offset
      {
        final adapter = MockStepSensorAdapter(initialRawSteps: 0);
        final service = StepTrackingService(adapter: adapter);
        await service.startTracking();
        adapter.emitSample(rawSteps: 100, timestamp: startDate);
        await Future<void>.delayed(Duration.zero);
        adapter.emitSample(rawSteps: 120, timestamp: startDate.add(const Duration(seconds: 15)));
        await Future<void>.delayed(Duration.zero);

        service.pauseTracking(startDate.add(const Duration(seconds: 15)));
        await Future<void>.delayed(Duration.zero);

        // 35 steps while paused
        adapter.emitSample(rawSteps: 155, timestamp: startDate.add(const Duration(seconds: 35)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(20));
        expect(service.currentCadenceSpm, equals(0));

        service.resumeTracking(startDate.add(const Duration(seconds: 35)));
        await Future<void>.delayed(Duration.zero);

        adapter.emitSample(rawSteps: 175, timestamp: startDate.add(const Duration(seconds: 50)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(40)); // 20 + 20
        service.dispose();
      }

      // Fault 3: Counter Reset / Reboot
      {
        final adapter = MockStepSensorAdapter(initialRawSteps: 0);
        final service = StepTrackingService(adapter: adapter);
        await service.startTracking();
        adapter.emitSample(rawSteps: 500, timestamp: startDate);
        await Future<void>.delayed(Duration.zero);
        adapter.emitSample(rawSteps: 580, timestamp: startDate.add(const Duration(seconds: 40)));
        await Future<void>.delayed(Duration.zero);

        // Reboot: counter resets to 4
        adapter.emitSample(rawSteps: 4, timestamp: startDate.add(const Duration(seconds: 45)));
        await Future<void>.delayed(Duration.zero);
        adapter.emitSample(rawSteps: 24, timestamp: startDate.add(const Duration(seconds: 60)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(100)); // 80 + 20
        service.dispose();
      }

      // Fault 4: Spike Rejection
      {
        final adapter = MockStepSensorAdapter(initialRawSteps: 0);
        final service = StepTrackingService(adapter: adapter);
        await service.startTracking();
        adapter.emitSample(rawSteps: 1000, timestamp: startDate);
        await Future<void>.delayed(Duration.zero);
        adapter.emitSample(rawSteps: 1010, timestamp: startDate.add(const Duration(seconds: 5)));
        await Future<void>.delayed(Duration.zero);

        // Spike > 4.5 steps/sec
        adapter.emitSample(rawSteps: 1150, timestamp: startDate.add(const Duration(milliseconds: 5500)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(10));

        // Valid follow up
        adapter.emitSample(rawSteps: 1020, timestamp: startDate.add(const Duration(seconds: 10)));
        await Future<void>.delayed(Duration.zero);
        expect(service.currentActiveSteps, equals(20));
        service.dispose();
      }

      // Fault 5: Cadence Inactivity Decay
      {
        final calc = CadenceCalculatorService(
          windowDuration: const Duration(seconds: 6),
          inactivityTimeout: const Duration(seconds: 4),
        );
        calc.computeInstantCadence(activeSteps: 0, timestamp: startDate);
        final activeCad = calc.computeInstantCadence(
          activeSteps: 12,
          timestamp: startDate.add(const Duration(seconds: 6)),
        );
        final decayedCad = calc.computeInstantCadence(
          activeSteps: 12,
          timestamp: startDate.add(const Duration(seconds: 11)),
        );
        expect(activeCad, greaterThan(60));
        expect(decayedCad, equals(0));
      }
    });
  });
}
