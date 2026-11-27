// Explicit opt-in benchmark. CIOD is a separately downloaded research dataset.
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/iod/ciod_dataset_adapter.dart';
import 'helpers/iod/iod_benchmark_models.dart';

void main() {
  final path = Platform.environment['AETRON_CIOD_CSV'];
  test(
    'CIOD original labels: legacy DeepIOD adaptations and live input gate',
    () async {
      final file = File(path!);
      expect(file.existsSync(), isTrue);
      final cap = int.parse(Platform.environment['AETRON_CIOD_CAP'] ?? '800');
      final samples = await CiodDatasetAdapter.parseCsvFile(
        file: file,
        targetSessionIndices: Set<int>.from(List.generate(13, (i) => 72 + i)),
        maxSamplesPerSession: cap,
      );
      expect(samples.map((s) => s.sessionId).toSet().length, 13);
      expect(
        samples.every(
          (s) =>
              s.groundTruth == IndoorOutdoorState.indoor ||
              s.groundTruth == IndoorOutdoorState.outdoor,
        ),
        isTrue,
      );
      print(
        'CIOD cap=$cap N=${samples.length}, indoor=${samples.where((s) => s.groundTruth == IndoorOutdoorState.indoor).length}, outdoor=${samples.where((s) => s.groundTruth == IndoorOutdoorState.outdoor).length}',
      );
      final variants = {
        'C-Mobile (legacy; 4 channel)': IodCompositeClassifier.mobileOnly(),
        'C-Replay (sound imputed; 8 channel)':
            IodCompositeClassifier.research8Channel(),
        if (cap > 0 || Platform.environment['AETRON_CIOD_FULL_AMV'] == '1')
          'Full AMV (sound imputed; GPS absent)':
              IodCompositeClassifier.fullDeepIod(),
        'C-Mobile (live gating)': IodCompositeClassifier.liveMobile(),
      };
      for (final entry in variants.entries) {
        String? previousSession;
        final results = <IodBenchmarkResult>[];
        for (final sample in samples) {
          if (previousSession != sample.sessionId) {
            entry.value.reset();
            previousSession = sample.sessionId;
          }
          results.add(
            IodBenchmarkResult(
              sample: sample,
              prediction: entry.value.predict(sample.snapshot),
            ),
          );
        }
        final metrics = IodEvaluationMetrics.compute(
          datasetName: 'CIOD sessions 72..84 (zero-based), cap=$cap',
          modelName: entry.key,
          results: results,
        );
        print(metrics.toMarkdownTable());
      }
    },
    skip: path == null
        ? 'Set AETRON_CIOD_CSV to the original CIOD CSV for opt-in research replay'
        : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
