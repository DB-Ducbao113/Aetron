// Run from worktree root with dart run tooling/step_benchmark/run_oxford_raw_imu_benchmark.dart
import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/core/services/sensor/oxford_step_detector.dart';

void main() {
  final root = Directory('tooling/step_benchmark/pedeval/Data');
  final results = <Map<String, Object>>[];
  final subjects = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final subject in subjects) {
    final id = subject.path.split('/').last;
    for (final protocol in ['Regular', 'SemiRegular', 'Irregular']) {
      final dir = Directory('${subject.path}/$protocol');
      final raw = dir.listSync().whereType<File>().singleWhere(
        (f) => f.path.endsWith('.txt') && !f.path.endsWith('steps.txt'),
      );
      final labels =
          File('${dir.path}/steps.txt')
              .readAsLinesSync()
              .map((s) => s.trim().split(RegExp(r'\s+')))
              .where((p) => p.length >= 2 && ['left', 'right'].contains(p[1]))
              .map((p) => (int.parse(p[0]) * 1000000 / 15).round())
              .toList()
            ..sort();
      final detectors = List.generate(3, (_) => OxfordStepDetector());
      final detected = List.generate(3, (_) => <int>[]);
      final announced = List.generate(3, (_) => <int>[]);
      var index = 0;
      for (final line in raw.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final values = line
            .trim()
            .split(RegExp(r'\s+'))
            .map(double.parse)
            .toList();
        if (values.length != 9) {
          throw FormatException('Expected three XYZ triplets');
        }
        final us = (index++ * 1000000 / 15).round();
        for (var position = 0; position < 3; position++) {
          final i = 3 * position;
          // PedEval values are in g. Do not replace raw data with the labels.
          final events = detectors[position].addSample(
            us,
            values[i] * 9.80665,
            values[i + 1] * 9.80665,
            values[i + 2] * 9.80665,
          );
          detected[position].addAll(events);
          announced[position].addAll(List.filled(events.length, us));
        }
      }
      final durationUs = (index * 1000000 / 15).round();
      for (var position = 0; position < 3; position++) {
        final predictions = detected[position];
        // Match each event at most once, with an explicitly chosen ±300 ms
        // tolerance; the device peak is not necessarily a heel strike.
        var p = 0, g = 0, tp = 0;
        while (p < predictions.length && g < labels.length) {
          final difference = predictions[p] - labels[g];
          if (difference.abs() <= 300000) {
            tp++;
            p++;
            g++;
          } else if (difference < 0) {
            p++;
          } else {
            g++;
          }
        }
        final fp = predictions.length - tp;
        final fn = labels.length - tp;
        var gtStart = 0, gtEnd = 0, predStart = 0, predEnd = 0;
        var errorSum = 0.0, windows = 0;
        final available = announced[position];
        // Causal six-second cadence at one-second reporting boundaries.
        for (var t = 6000000; t < durationUs; t += 1000000) {
          while (gtEnd < labels.length && labels[gtEnd] <= t) {
            gtEnd++;
          }
          while (gtStart < gtEnd && labels[gtStart] <= t - 6000000) {
            gtStart++;
          }
          while (predEnd < available.length && available[predEnd] <= t) {
            predEnd++;
          }
          while (predStart < predEnd && available[predStart] <= t - 6000000) {
            predStart++;
          }
          errorSum += ((gtEnd - gtStart) - (predEnd - predStart)).abs() * 10;
          windows++;
        }
        results.add({
          'subject': id,
          'protocol': protocol,
          'triplet': position + 1,
          'samples': index,
          'reference_steps': labels.length,
          'detected_steps': predictions.length,
          'tp': tp,
          'fp': fp,
          'fn': fn,
          'cadence_windows': windows,
          'cadence_abs_error_sum_spm': errorSum,
          'absolute_count_error': (predictions.length - labels.length).abs(),
        });
      }
    }
  }
  final summary = <Map<String, Object>>[];
  for (var triplet = 1; triplet <= 3; triplet++) {
    for (final protocol in ['Regular', 'SemiRegular', 'Irregular', 'All']) {
      final group = results
          .where(
            (r) =>
                r['triplet'] == triplet &&
                (protocol == 'All' || r['protocol'] == protocol),
          )
          .toList();
      double sum(String key) => group.fold(0.0, (a, r) => a + (r[key] as num));
      final gt = sum('reference_steps'), pred = sum('detected_steps');
      final tp = sum('tp'), fp = sum('fp'), fn = sum('fn');
      summary.add({
        'triplet': triplet,
        'protocol': protocol,
        'sessions': group.length,
        'ground_truth_steps': gt,
        'detected_steps': pred,
        'count_wape': sum('absolute_count_error') / gt,
        'event_precision': tp / (tp + fp),
        'event_recall': tp / (tp + fn),
        'event_f1': 2 * tp / (2 * tp + fp + fn),
        'cadence_window_mae_spm':
            sum('cadence_abs_error_sum_spm') / sum('cadence_windows'),
      });
    }
  }
  final report = {
    'method': 'Oxford WPD streaming adaptation',
    'input_hz': 15,
    'event_tolerance_us': 300000,
    'cadence_window_s': 6,
    'summary': summary,
    'sessions': results,
  };
  final output = File(
    'tooling/step_benchmark/results/oxford_raw_imu_benchmark.json',
  );
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
}
