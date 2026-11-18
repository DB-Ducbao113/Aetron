// Run with dart run tooling/step_benchmark/run_oxford_author_validation.dart
// [path-to-pinned-dataset]. No fitting or detector parameter changes.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/services/sensor/oxford_step_detector.dart';

void main(List<String> args) {
  final base = Directory(
    args.isEmpty ? '../../oxford_wpd_validation_20261118' : args.single,
  );
  final manifest =
      jsonDecode(File('${base.path}/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  const commit = '922cc0d8511a7189f7a667d173c21e9472729603';
  if (manifest['commit'] != commit) {
    throw StateError('Unexpected dataset version');
  }
  final files =
      Directory('${base.path}/validation')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.csv'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.length != 12) throw StateError('Expected all 12 validation traces');
  final results = <Map<String, dynamic>>[];
  for (final file in files) {
    final detector = OxfordStepDetector();
    int? startNs, lastNs;
    int? firstGt, firstAuthor, firstHardware;
    var gt = 0,
        author = 0,
        hardware = 0,
        count = 0,
        rows = 0,
        nonIncreasing = 0;
    final gtTimes = <int>[], available = <int>[];
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final p = line.split(',');
      if (p.length != 7) throw FormatException('Expected 7 columns');
      final ns = int.parse(p[0]);
      startNs ??= ns;
      final us = (ns - startNs) ~/ 1000;
      final gtRaw = int.parse(p[5]), authorRaw = int.parse(p[4]);
      final hardwareRaw = int.parse(p[6]);
      firstGt ??= gtRaw;
      firstAuthor ??= authorRaw;
      firstHardware ??= hardwareRaw;
      final newGt = gtRaw - firstGt;
      if (newGt < gt ||
          authorRaw - firstAuthor < author ||
          hardwareRaw - firstHardware < hardware) {
        throw FormatException('Unexpected counter reset');
      }
      for (var j = gt; j < newGt; j++) {
        gtTimes.add(us);
      }
      gt = newGt;
      author = authorRaw - firstAuthor;
      hardware = hardwareRaw - firstHardware;
      if (lastNs != null && ns <= lastNs) nonIncreasing++;
      lastNs = ns;
      final events = detector.addSample(
        us,
        double.parse(p[1]),
        double.parse(p[2]),
        double.parse(p[3]),
      );
      count += events.length;
      available.addAll(List.filled(events.length, us));
      rows++;
    }
    final durationUs = (lastNs! - startNs!) ~/ 1000;
    var g0 = 0, g1 = 0, p0 = 0, p1 = 0, windows = 0;
    var absSpm = 0.0;
    for (var t = 6000000; t <= durationUs; t += 1000000) {
      while (g1 < gtTimes.length && gtTimes[g1] <= t) {
        g1++;
      }
      while (g0 < g1 && gtTimes[g0] <= t - 6000000) {
        g0++;
      }
      while (p1 < available.length && available[p1] <= t) {
        p1++;
      }
      while (p0 < p1 && available[p0] <= t - 6000000) {
        p0++;
      }
      absSpm += ((p1 - p0) - (g1 - g0)).abs() * 10;
      windows++;
    }
    final name = file.uri.pathSegments.last;
    results.add({
      'file': name,
      'user': name.split('_')[0],
      'position': name.split('_')[1],
      'rows': rows,
      'duration_seconds': durationUs / 1000000,
      'nonincreasing_timestamps': nonIncreasing,
      'ground_truth': gt,
      'dart_detector': count,
      'recorded_author_algorithm': author,
      // Zero throughout all user1 traces: unavailable rather than 0% accuracy.
      'recorded_hardware': hardware == 0 ? null : hardware,
      'dart_absolute_count_error': (count - gt).abs(),
      'dart_relative_count_error': (count - gt).abs() / gt,
      'author_relative_count_error': (author - gt).abs() / gt,
      'cadence_window_count': windows,
      'cadence_absolute_error_sum_spm': absSpm,
      'cadence_mae_spm': absSpm / windows,
    });
  }
  Map<String, dynamic> metrics(List<Map<String, dynamic>> subset, String key) {
    final valid = subset.where((x) => x[key] != null).toList();
    final errors = valid
        .map(
          (x) =>
              ((x[key] as int) - (x['ground_truth'] as int)).abs() /
              (x['ground_truth'] as int),
        )
        .toList();
    final n = valid.length;
    final mape = errors.reduce((a, b) => a + b) / n;
    final gtTotal = valid.fold<int>(0, (s, x) => s + x['ground_truth'] as int);
    final predTotal = valid.fold<int>(0, (s, x) => s + x[key] as int);
    final abs = valid.fold<int>(
      0,
      (s, x) => s + ((x[key] as int) - (x['ground_truth'] as int)).abs(),
    );
    return {
      'sessions': n,
      'ground_truth_steps': gtTotal,
      'reported_steps': predTotal,
      'count_mape': mape,
      'count_wape': abs / gtTotal,
      'mean_accuracy_1_minus_mape': 1 - mape,
      'accuracy_sample_sd': math.sqrt(
        errors.fold<double>(0, (s, x) => s + math.pow(x - mape, 2)) / (n - 1),
      ),
    };
  }

  final cadenceSum = results.fold<double>(
    0,
    (s, x) => s + (x['cadence_absolute_error_sum_spm'] as num),
  );
  final windows = results.fold<int>(
    0,
    (s, x) => s + x['cadence_window_count'] as int,
  );
  final summary = {
    'dataset_commit': commit,
    'sessions': results.length,
    'rows': results.fold<int>(0, (s, x) => s + x['rows'] as int),
    'duration_seconds': results.fold<double>(
      0,
      (s, x) => s + (x['duration_seconds'] as num),
    ),
    'dart': metrics(results, 'dart_detector'),
    'recorded_author': metrics(results, 'recorded_author_algorithm'),
    'recorded_hardware_available': metrics(results, 'recorded_hardware'),
    'dart_on_hardware_available_subset': metrics(
      results.where((x) => x['recorded_hardware'] != null).toList(),
      'dart_detector',
    ),
    'recorded_author_on_hardware_available_subset': metrics(
      results.where((x) => x['recorded_hardware'] != null).toList(),
      'recorded_author_algorithm',
    ),
    'causal_6s_cadence_mae_spm_vs_reference_counter_updates':
        cadenceSum / windows,
    'cadence_windows': windows,
  };
  final report = {'summary': summary, 'traces': results};
  File(
    'tooling/step_benchmark/results/oxford_author_validation.json',
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
