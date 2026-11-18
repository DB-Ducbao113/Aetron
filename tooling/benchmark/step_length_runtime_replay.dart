// Descriptive replay of frozen production coefficients on the same cohort
// used for fitting. Not an independent validation. LOSO remains primary.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/services/research_walking_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_running_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_step_length_fallback.dart';

void main() {
  const root = 'tooling/benchmark/results/app_benchmark_20261118';
  final report = <String, dynamic>{
    'scope':
        'Frozen production Dart methods, rounded supplied cadence from the published-data feature replay, same training cohort; descriptive only, not held-out validation.',
  };
  for (final mode in ['walking', 'running']) {
    final lines = File('$root/$mode/sessions.csv').readAsLinesSync();
    final header = lines.first.split(',');
    var adaptive = 0;
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final columns = line.split(',');
      if (columns.length != header.length) throw FormatException(line);
      final row = Map<String, String>.fromIterables(header, columns);
      final height = double.parse(row['height_m']!) * 100;
      final cadence = (double.parse(row['frequency_hz']!) * 60).round();
      final reference = double.parse(row['reference_step_m']!);
      final estimate = mode == 'walking'
          ? ResearchWalkingStepLength.estimateMeters(
              activityType: mode,
              heightCm: height,
              cadenceSpm: cadence,
            )
          : ResearchRunningStepLength.estimateMeters(
              activityType: mode,
              heightCm: height,
              cadenceSpm: cadence,
            );
      if (estimate != null) adaptive++;
      final fallback = ResearchStepLengthFallback.estimateMeters(
        activityType: mode,
        heightCm: height,
      )!;
      final predicted = estimate ?? fallback;
      rows.add({
        'subject': row['subject'],
        'file': row['file'] ?? row['filename'],
        'reference_m': reference,
        'height_cm': height,
        'cadence_spm': cadence,
        'runtime_m': predicted,
        'fallback_m': fallback,
        'adaptive': estimate != null,
        'error_m': predicted - reference,
      });
    }
    double mean(num Function(Map<String, dynamic>) fn) =>
        rows.fold<double>(0, (s, r) => s + fn(r)) / rows.length;
    report[mode] = {
      'sessions': rows.length,
      'adaptive_sessions': adaptive,
      'fallback_sessions': rows.length - adaptive,
      'mae_cm': 100 * mean((r) => (r['error_m'] as double).abs()),
      'rmse_cm':
          100 * math.sqrt(mean((r) => math.pow(r['error_m'] as double, 2))),
      'mape_pct':
          100 *
          mean(
            (r) =>
                (r['error_m'] as double).abs() / (r['reference_m'] as double),
          ),
      'rows': rows,
    };
  }
  File('$root/step_length_runtime.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  for (final mode in ['walking', 'running']) {
    stdout.writeln(
      '$mode: ${Map<String, dynamic>.from(report[mode] as Map)..remove('rows')}',
    );
  }
}
