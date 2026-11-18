import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/xu_running_step_detector.dart';
import 'package:flutter_test/flutter_test.dart';

double runningSignal(int us) =>
    9.81 + 4 * math.sin(2 * math.pi * 2.5 * us / 1000000);

void main() {
  test('constant acceleration yields no steps', () {
    final detector = XuRunningStepDetector();
    for (var i = 0; i < 1000; i++) {
      expect(detector.addSample(i * 20000, 0, 0, 9.81), isEmpty);
    }
  });

  test('causal running peaks stay ordered across one-second boundaries', () {
    for (final rate in [50, 100]) {
      final detector = XuRunningStepDetector();
      final peaks = <int>[];
      for (var i = 0; i < rate * 20; i++) {
        final us = i * 1000000 ~/ rate;
        final events = detector.addSample(us, 0, 0, runningSignal(us));
        for (final peak in events) {
          expect(peak, lessThanOrEqualTo(us));
          expect(us - peak, lessThanOrEqualTo(1800000));
        }
        peaks.addAll(events);
      }
      expect(peaks.length, inInclusiveRange(45, 50));
      expect(peaks, orderedEquals(peaks.toSet().toList()..sort()));
      for (var i = 1; i < peaks.length; i++) {
        expect(peaks[i] - peaks[i - 1], greaterThan(286000));
      }
    }
  });

  test('reset, invalid inputs and outages discard pending peaks', () {
    for (final mode in ['reset', 'invalid', 'gap']) {
      final detector = XuRunningStepDetector();
      for (var i = 0; i < 100; i++) {
        final us = i * 20000;
        detector.addSample(us, 0, 0, runningSignal(us));
      }
      if (mode == 'reset') detector.reset();
      if (mode == 'invalid') {
        expect(detector.addSample(2000000, double.nan, 0, 0), isEmpty);
      }
      for (var i = 0; i < 300; i++) {
        expect(detector.addSample(5000000 + i * 20000, 0, 0, 9.81), isEmpty);
      }
      expect(detector.addSample(5000000, 0, 0, 100), isEmpty);
    }
  });

  test(
    'spectral interference suppresses high-frequency peaks after warmup',
    () {
      final detector = XuRunningStepDetector();
      for (var i = 0; i < 600; i++) {
        final t = i * 20000;
        final events = detector.addSample(
          t,
          0,
          0,
          9.81 + 4 * math.sin(2 * math.pi * 4 * t / 1000000),
        );
        if (i > 400) expect(events, isEmpty);
      }
    },
  );
}
