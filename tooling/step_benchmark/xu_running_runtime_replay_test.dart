// Explicit dataset replay through the same adapter/service used by workouts.
// Not a physical-device or per-step timing measurement.
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
  test(
    'author Running traces reproduce detector counts through production service',
    () async {
      final baseline =
          jsonDecode(
                File(
                  'tooling/step_benchmark/results/xu_running_adaptation.json',
                ).readAsStringSync(),
              )
              as Map;
      final dir = Directory('../../xu_step_counting_20261118');
      final rows = <Map<String, dynamic>>[];
      for (final row in baseline['traces'] as List) {
        final id = row['subject_id'];
        final file = dir.listSync().whereType<File>().singleWhere(
          (f) =>
              f.uri.pathSegments.last.startsWith('${id}_') &&
              f.path.endsWith('.txt'),
        );
        final os = MockStepSensorAdapter();
        final raw = StreamController<AccelerometerEvent>();
        final adapter = ResearchWalkingStepSensorAdapter(
          fallback: os,
          running: true,
          rawStream: () => raw.stream,
        );
        final service = StepTrackingService(
          adapter: os,
          runningResearchAdapter: adapter,
        );
        final updates = <WorkoutStepUpdate>[];
        final sub = service.updateStream.listen(updates.add);
        final started = service.startTracking(
          activityType: 'running',
          useResearchImu: true,
        );
        await Future<void>.delayed(Duration.zero);
        final epoch = DateTime.now();
        int? firstUs;
        for (final line in file.readAsLinesSync()) {
          if (line.trim().isEmpty) continue;
          final p = line
              .trim()
              .split(RegExp(r'\s+'))
              .map(double.parse)
              .toList();
          final us = (p[0] * 1000000).round();
          firstUs ??= us;
          raw.add(
            AccelerometerEvent(
              p[1],
              p[2],
              p[3],
              epoch.add(Duration(microseconds: us - firstUs)),
            ),
          );
        }
        await started;
        await Future<void>.delayed(Duration.zero);
        expect(
          service.currentActiveSteps,
          row['detector_steps'],
          reason: 'subject $id',
        );
        expect(os.isStreaming, false);
        expect(
          updates.every((u) => u.source == StepSensorSource.xuRunning),
          true,
        );
        expect(
          updates.fold<int>(0, (sum, u) => sum + u.deltaSteps),
          service.currentActiveSteps,
        );
        expect(
          updates.every(
            (u) => u.currentCadenceSpm >= 0 && u.currentCadenceSpm <= 270,
          ),
          true,
        );
        rows.add({
          'subject_id': id,
          'reference_steps': row['reference_steps'],
          'runtime_steps': service.currentActiveSteps,
          'reference_full_session_count_per_min':
              row['reference_session_count_per_min'],
          'runtime_full_session_count_per_min':
              row['detector_session_count_per_min'],
          'last_emitted_average_cadence_spm': service.currentAvgCadenceSpm,
          'source': updates.last.source.name,
          'os_fallback': os.isStreaming,
        });
        service.stopTracking();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        await raw.close();
        service.dispose();
      }
      final report = const JsonEncoder.withIndent('  ').convert({
        'dataset_commit': baseline['dataset_commit'],
        'detector_sha256': baseline['detector_sha256'],
        'scope':
            'Actual Running adapter and service; replayed timestamps, no OS sensor or independent event cadence reference.',
        'total_runtime_steps': rows.fold<int>(
          0,
          (sum, r) => sum + (r['runtime_steps'] as int),
        ),
        'traces': rows,
      });
      File(
        'tooling/step_benchmark/results/xu_running_runtime_replay.json',
      ).writeAsStringSync('$report\n');
    },
  );
}
