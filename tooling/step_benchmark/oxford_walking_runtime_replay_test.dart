// Replays author validation samples using the actual Walking adapter/service.
// Ground-truth counter is only used for evaluation, never as input.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/sensor/research_walking_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/sensor/step_sensor_types.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('Walking runtime on all Oxford author validation traces', () async {
    final root = Directory('../../oxford_wpd_validation_20261118');
    final baseline =
        jsonDecode(
              File(
                'tooling/step_benchmark/results/oxford_author_validation.json',
              ).readAsStringSync(),
            )
            as Map;
    final rows = <Map<String, dynamic>>[];
    for (final row in baseline['traces'] as List) {
      final file = File('${root.path}/validation/${row['file']}');
      final os = MockStepSensorAdapter();
      final raw = StreamController<AccelerometerEvent>();
      final adapter = ResearchWalkingStepSensorAdapter(
        fallback: os,
        rawStream: () => raw.stream,
      );
      final service = StepTrackingService(
        adapter: os,
        researchAdapter: adapter,
      );
      final updates = <WorkoutStepUpdate>[];
      final sub = service.updateStream.listen(updates.add);
      final started = service.startTracking(
        activityType: 'walking',
        useResearchImu: true,
      );
      await Future<void>.delayed(Duration.zero);
      final epoch = DateTime.now();
      int? firstNs, firstGt;
      final gtEvents = <int>[];
      var gt = 0, durationUs = 0;
      for (final line in file.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final p = line.split(',');
        final ns = int.parse(p[0]);
        firstNs ??= ns;
        final us = (ns - firstNs) ~/ 1000;
        firstGt ??= int.parse(p[5]);
        final count = int.parse(p[5]) - firstGt;
        expect(count, greaterThanOrEqualTo(gt));
        for (var i = gt; i < count; i++) {
          gtEvents.add(us);
        }
        gt = count;
        durationUs = us;
        raw.add(
          AccelerometerEvent(
            double.parse(p[1]),
            double.parse(p[2]),
            double.parse(p[3]),
            epoch.add(Duration(microseconds: us)),
          ),
        );
      }
      await started;
      await Future<void>.delayed(Duration.zero);
      expect(gt, row['ground_truth']);
      expect(os.isStreaming, false, reason: row['file'].toString());
      expect(
        updates.every((u) => u.source == StepSensorSource.oxfordWpd),
        true,
      );
      final detected = service.currentActiveSteps;
      expect(updates.fold<int>(0, (s, u) => s + u.deltaSteps), detected);
      // Evaluate last available real cadence output on the same 6 s GT
      // window and 1 s reporting grid as the detector-only benchmark.
      final t0 = updates.first.timestamp;
      var gi = 0, gj = 0, ui = 0, windows = 0;
      var error = 0.0;
      for (var t = 6000000; t <= durationUs; t += 1000000) {
        while (gj < gtEvents.length && gtEvents[gj] <= t) {
          gj++;
        }
        while (gi < gj && gtEvents[gi] <= t - 6000000) {
          gi++;
        }
        while (ui + 1 < updates.length &&
            updates[ui + 1].timestamp.difference(t0).inMicroseconds <= t) {
          ui++;
        }
        error += (updates[ui].currentCadenceSpm - (gj - gi) * 10).abs();
        windows++;
      }
      rows.add({
        'file': row['file'],
        'ground_truth_steps': gt,
        'detector_steps': row['dart_detector'],
        'runtime_steps': detected,
        'relative_error': (detected - gt).abs() / gt,
        'absolute_error': (detected - gt).abs(),
        'cadence_windows': windows,
        'cadence_error_sum_spm': error,
      });
      service.stopTracking();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await raw.close();
      service.dispose();
    }
    num sum(String k) => rows.fold<num>(0, (s, r) => s + (r[k] as num));
    final output = {
      'dataset_commit': baseline['summary']['dataset_commit'],
      'sessions': rows.length,
      'reference_steps': sum('ground_truth_steps'),
      'runtime_steps': sum('runtime_steps'),
      'macro_accuracy_pct': 100 * (1 - sum('relative_error') / rows.length),
      'wape_pct': 100 * sum('absolute_error') / sum('ground_truth_steps'),
      'cadence_windows': sum('cadence_windows'),
      'runtime_cadence_mae_spm':
          sum('cadence_error_sum_spm') / sum('cadence_windows'),
      'scope':
          'Production adapter/service replay. Held last available actual cadence output on one-second grid compared with six-second reference counter increments; not independent heel-strike timing.',
      'traces': rows,
    };
    final json = const JsonEncoder.withIndent('  ').convert(output);
    File(
      'tooling/benchmark/results/app_benchmark_20261118/oxford_walking_runtime.json',
    ).writeAsStringSync('$json\n');
    stdout.writeln(json);
  });
}
