import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/oxford_step_detector.dart';
import 'package:fitness_exercise_application/core/services/sensor/xu_running_step_detector.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/step_motion_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IMU Stationary Hand-Sway & Tremor Rejection', () {
    test(
      'OxfordStepDetector rejects 60s of hand-held breathing, postural sway, and screen glances',
      () {
        final detector = OxfordStepDetector();
        final rng = math.Random(7);
        var detectedSteps = 0;

        for (var i = 0; i < 6000; i++) {
          final t = i / 100.0;
          var sway =
              0.15 * math.sin(2 * math.pi * 0.30 * t) +
              0.25 * math.sin(2 * math.pi * 1.90 * t) +
              (rng.nextDouble() - 0.5) * 0.12;
          if (4.0 < (t % 10.0) && (t % 10.0) < 4.6) {
            sway += 0.55 * math.sin(2 * math.pi * 1.5 * (t % 10.0));
          }
          detectedSteps += detector
              .addSample(i * 10000, 0.4, 2.0, 9.58 + sway)
              .length;
        }

        expect(detectedSteps, 0);
      },
    );

    test(
      'XuRunningStepDetector rejects 60s of hand-held breathing, postural sway, and screen glances',
      () {
        final detector = XuRunningStepDetector();
        final rng = math.Random(7);
        var detectedSteps = 0;

        for (var i = 0; i < 3000; i++) {
          final t = i / 50.0;
          var sway =
              0.15 * math.sin(2 * math.pi * 0.30 * t) +
              0.25 * math.sin(2 * math.pi * 1.90 * t) +
              (rng.nextDouble() - 0.5) * 0.12;
          if (4.0 < (t % 10.0) && (t % 10.0) < 4.6) {
            sway += 0.70 * math.sin(2 * math.pi * 1.5 * (t % 10.0));
          }
          detectedSteps += detector
              .addSample(i * 20000, 0.4, 2.0, 9.58 + sway)
              .length;
        }

        expect(detectedSteps, 0);
      },
    );

    test(
      'Skog (2010) MV-GLRT rejects sharp isolated 2.2 m/s² screen taps while stationary',
      () {
        final oxford = OxfordStepDetector();
        final xu = XuRunningStepDetector();
        var oxSteps = 0;
        var xuSteps = 0;

        for (var i = 0; i < 3000; i++) {
          final t = i / 100.0;
          var az = 9.81 + 0.12 * math.sin(2 * math.pi * 1.4 * t);
          // Sharp 50ms single-tap impulse every 5 seconds (peak-to-peak > 2.2 m/s²)
          if ((i % 500) >= 200 && (i % 500) < 205) {
            az += 2.2;
          }
          oxSteps += oxford.addSample(i * 10000, 0.0, 0.0, az).length;
          if (i.isEven) {
            xuSteps += xu.addSample(i * 10000, 0.0, 0.0, az).length;
          }
        }

        expect(oxSteps, 0);
        expect(xuSteps, 0);
      },
    );
  });

  group('StepMotionGate Bout & Stationary GNSS Blocking', () {
    test(
      'sporadic 1-4 isolated impulses while standing still stay at 0 and never leak later',
      () {
        final gate = StepMotionGate();
        final t0 = DateTime.utc(2026, 11, 25, 8, 0, 0);
        var acceptedTotal = 0;

        // 3 isolated impulses separated by 5s of standing still -> 0 accepted
        for (var k = 0; k < 4; k++) {
          final res = gate.evaluate(
            rawDelta: 2,
            now: t0.add(Duration(seconds: k * 5)),
            isOutdoorGpsStationaryLocked: false,
          );
          acceptedTotal += res.acceptedDelta;
        }
        expect(acceptedTotal, 0);
        expect(gate.isBoutActive, isFalse);

        // Athlete later starts genuine rhythmic walking (10 steps at 0.55s intervals).
        // Rejected stationary impulses must NEVER retroactively catch up.
        final walkStart = t0.add(const Duration(seconds: 30));
        for (var i = 0; i < 10; i++) {
          final res = gate.evaluate(
            rawDelta: 1,
            now: walkStart.add(Duration(milliseconds: i * 550)),
            isOutdoorGpsStationaryLocked: false,
          );
          acceptedTotal += res.acceptedDelta;
        }
        expect(acceptedTotal, 10);
        expect(gate.isBoutActive, isTrue);
      },
    );

    test(
      'outdoor high-accuracy stationary GNSS blocks continuous in-place shaking for 60s',
      () {
        final gate = StepMotionGate();
        final t0 = DateTime.utc(2026, 11, 25, 8, 0, 0);
        var acceptedTotal = 0;

        // 60 seconds of continuous 2 Hz phone shaking while GNSS proves 0m displacement
        for (var i = 0; i < 120; i++) {
          final res = gate.evaluate(
            rawDelta: 1,
            now: t0.add(Duration(milliseconds: i * 500)),
            isOutdoorGpsStationaryLocked: true,
          );
          acceptedTotal += res.acceptedDelta;
        }

        expect(acceptedTotal, 0);
        expect(gate.isBoutActive, isFalse);

        // Athlete then begins real outdoor movement (GNSS stationary lock clears)
        final moveStart = t0.add(const Duration(seconds: 70));
        for (var i = 0; i < 8; i++) {
          final res = gate.evaluate(
            rawDelta: 1,
            now: moveStart.add(Duration(milliseconds: i * 500)),
            isOutdoorGpsStationaryLocked: false,
          );
          acceptedTotal += res.acceptedDelta;
        }

        expect(acceptedTotal, 8);
      },
    );

    test(
      'startup steps buffered during initial GNSS grace window flush once movement is confirmed',
      () {
        final gate = StepMotionGate();
        final t0 = DateTime.utc(2026, 11, 25, 8, 0, 0);
        var acceptedTotal = 0;

        // First 4 steps (~2.0s) before GNSS crosses 2.5m displacement threshold
        for (var i = 0; i < 4; i++) {
          final res = gate.evaluate(
            rawDelta: 1,
            now: t0.add(Duration(milliseconds: i * 550)),
            isOutdoorGpsStationaryLocked: true,
          );
          acceptedTotal += res.acceptedDelta;
        }
        expect(acceptedTotal, 0);

        // Step 5 at 2.2s after GNSS observes real outdoor displacement
        final fifth = gate.evaluate(
          rawDelta: 1,
          now: t0.add(const Duration(milliseconds: 2200)),
          isOutdoorGpsStationaryLocked: false,
        );
        acceptedTotal += fifth.acceptedDelta;

        expect(acceptedTotal, 5);
        expect(gate.isBoutActive, isTrue);
      },
    );
  });
}
