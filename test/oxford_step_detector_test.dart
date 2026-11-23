import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/oxford_step_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stationary input does not generate steps', () {
    final detector = OxfordStepDetector();
    for (var i = 0; i < 1000; i++) {
      expect(detector.addSample(i * 10000, 0, 0, 9.81), isEmpty);
    }
  });

  test('stationary input with sensor noise and hand tremor does not generate steps', () {
    final detector = OxfordStepDetector();
    final rng = math.Random(42);
    final peaks = <int>[];
    // 60 seconds at 100 Hz with realistic MEMS accelerometer noise + hand tremor (sigma = 0.05 m/s²)
    for (var i = 0; i < 6000; i++) {
      final u1 = rng.nextDouble().clamp(1e-7, 1.0);
      final u2 = rng.nextDouble();
      final noise = 0.05 * math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
      final events = detector.addSample(i * 10000, 0, 0, 9.80665 + noise);
      peaks.addAll(events);
    }
    expect(peaks, isEmpty);
  });

  test('periodic acceleration yields events in timestamp order', () {
    final detector = OxfordStepDetector();
    final peaks = <int>[];
    for (var i = 0; i < 2000; i++) {
      final t = i / 100;
      final events = detector.addSample(
        i * 10000,
        0,
        0,
        9.81 + 3 * math.sin(2 * math.pi * 2 * t),
      );
      expect(events.every((event) => event <= i * 10000), isTrue);
      peaks.addAll(events);
    }
    expect(peaks.length, inInclusiveRange(34, 40));
    expect(peaks, orderedEquals(peaks.toSet().toList()..sort()));
  });

  test(
    'reset and missing samples do not carry pending motion into next segment',
    () {
      final detector = OxfordStepDetector();
      for (var i = 0; i < 200; i++) {
        detector.addSample(i * 10000, 0, 0, 9.81 + 3 * math.sin(i * .13));
      }
      detector.reset();
      for (var i = 0; i < 200; i++) {
        expect(detector.addSample(5000000 + i * 10000, 0, 0, 9.81), isEmpty);
      }
      expect(detector.addSample(9000000, 0, 0, 9.81), isEmpty);
      expect(detector.addSample(8999999, 0, 0, 20), isEmpty);
    },
  );
}
