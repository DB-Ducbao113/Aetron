// Replay the unchanged Aetron Oxford WPD candidate on Xu et al. 2022,
// DOI 10.3390/rs14122926, Group 3 (constrained running).
// Reference counts come from metadata rows 12-16, verified against Table 5.
// No fitting, signal-based activity selection, warm-up trimming, or end flush.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/oxford_step_detector.dart';

void main(List<String> args) {
  final base = Directory(
    args.isEmpty ? '../../xu_step_counting_20261118' : args.single,
  );
  const commit = '3da2d6e683f56e39eb74cda79eaa8ee93e033d6c';
  final git = Process.runSync('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: base.path);
  if (git.exitCode != 0 || git.stdout.toString().trim() != commit) {
    throw StateError('Unexpected dataset revision');
  }
  const references = {11: 240, 12: 343, 13: 230, 14: 183, 15: 284};
  const paperStepcount = {11: 94.2, 12: 95.3, 13: 84.3, 14: 88.5, 15: 87.3};
  const paperXu = {11: 98.3, 12: 99.1, 13: 99.1, 14: 98.9, 15: 99.3};
  final rows = <Map<String, dynamic>>[];
  for (final ref in references.entries) {
    final file = base.listSync().whereType<File>().singleWhere(
      (f) =>
          f.uri.pathSegments.last.startsWith('${ref.key}_') &&
          f.path.endsWith('.txt'),
    );
    final detector = OxfordStepDetector();
    var samples = 0, detected = 0, nonIncreasing = 0;
    int? firstUs, lastUs;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final values = line
          .trim()
          .split(RegExp(r'\s+'))
          .map(double.parse)
          .toList();
      if (values.length != 4 || values.any((v) => !v.isFinite)) {
        throw FormatException('Invalid sample in subject ${ref.key}');
      }
      final us = (values[0] * 1000000).round();
      firstUs ??= us;
      if (lastUs != null && us <= lastUs) nonIncreasing++;
      lastUs = us;
      detected += detector
          .addSample(us - firstUs, values[1], values[2], values[3])
          .length;
      samples++;
    }
    final seconds = (lastUs! - firstUs!) / 1000000;
    final absError = (detected - ref.value).abs();
    rows.add({
      'subject_id': ref.key,
      'samples': samples,
      'duration_seconds': seconds,
      'nonincreasing_timestamps': nonIncreasing,
      'reference_steps': ref.value,
      'detector_steps': detected,
      'absolute_count_error': absError,
      'count_accuracy_pct': 100 * (1 - absError / ref.value),
      'reference_session_count_per_min': 60 * ref.value / seconds,
      'detector_session_count_per_min': 60 * detected / seconds,
      'paper_stepcount_accuracy_pct': paperStepcount[ref.key],
      'paper_xu_accuracy_pct': paperXu[ref.key],
      'sha256': Process.runSync('shasum', [
        '-a',
        '256',
        file.path,
      ]).stdout.toString().split(RegExp(r'\s+')).first,
    });
  }
  double mean(String field) =>
      rows.fold<double>(0, (s, r) => s + (r[field] as num)) / rows.length;
  int total(String field) => rows.fold<int>(0, (s, r) => s + (r[field] as int));
  final acc = mean('count_accuracy_pct');
  final result = {
    'source_doi': '10.3390/rs14122926',
    'dataset_commit': commit,
    'scope':
        'Constrained running Group 3 only. Unchanged Oxford WPD candidate, not active Running OS path. Paper rates are author-reported, not executed. No event truth.',
    'detector_sha256': Process.runSync('shasum', [
      '-a',
      '256',
      'lib/core/services/sensor/oxford_step_detector.dart',
    ]).stdout.toString().split(RegExp(r'\s+')).first,
    'sessions': rows.length,
    'total_samples': total('samples'),
    'reference_steps': total('reference_steps'),
    'detector_steps': total('detector_steps'),
    'macro_count_accuracy_pct': acc,
    'macro_count_accuracy_sample_sd_pp': math.sqrt(
      rows.fold<double>(
            0,
            (s, r) => s + math.pow((r['count_accuracy_pct'] as num) - acc, 2),
          ) /
          (rows.length - 1),
    ),
    'wape_pct': 100 * total('absolute_count_error') / total('reference_steps'),
    'session_count_per_min_mae':
        rows.fold<double>(
          0,
          (s, r) =>
              s +
              ((r['reference_session_count_per_min'] as num) -
                      (r['detector_session_count_per_min'] as num))
                  .abs(),
        ) /
        rows.length,
    'paper_stepcount_mean_accuracy_pct': mean('paper_stepcount_accuracy_pct'),
    'paper_xu_mean_accuracy_pct': mean('paper_xu_accuracy_pct'),
    'traces': rows,
  };
  final json = const JsonEncoder.withIndent('  ').convert(result);
  File(
    'tooling/step_benchmark/results/xu_running_validation.json',
  ).writeAsStringSync('$json\n');
  stdout.writeln(json);
}
