import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/cap_alstm_iod_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/cap_alstm_model.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const models = [
    'cap_alstm_7ch_nosound_w12_wbce',
    'cap_alstm_6ch_android_motionfree_w12_wbce',
    'cap_alstm_4ch_mobile_w12_wbce',
    'cap_alstm_3ch_ios_lightfree_w12_wbce',
  ];

  group('CAP-ALSTM Python-Dart Exact Inference Parity', () {
    for (final name in models) {
      test('Parity <= 1e-5 for $name (500 held-out CIOD windows)', () {
        final ckptFile = File('assets/models/iod/$name.json');
        final parityFile = File(
          'tooling/data/cap_alstm_weights/parity_$name.json',
        );
        expect(ckptFile.existsSync(), isTrue, reason: 'Missing ${ckptFile.path}');
        expect(
          parityFile.existsSync(),
          isTrue,
          reason: 'Missing ${parityFile.path}',
        );

        final ckptJson =
            jsonDecode(ckptFile.readAsStringSync()) as Map<String, dynamic>;
        final model = CapAlstmModel.fromJson(ckptJson);

        final parityJson =
            jsonDecode(parityFile.readAsStringSync()) as Map<String, dynamic>;
        final vectors = parityJson['vectors'] as List<dynamic>;
        expect(vectors.length, 500);

        double maxLogitDiff = 0.0;
        double maxProbDiff = 0.0;
        int classMatches = 0;

        for (final v in vectors) {
          final vm = v as Map<String, dynamic>;
          final rawWindow = (vm['raw_window'] as List)
              .map(
                (r) => (r as List).map((e) => (e as num).toDouble()).toList(),
              )
              .toList();
          final pyNorm = (vm['norm_window'] as List)
              .map(
                (r) => (r as List).map((e) => (e as num).toDouble()).toList(),
              )
              .toList();

          // Verify Dart normalizeFrame matches Python preprocessing
          final dartNorm = rawWindow
              .map((row) => model.normalizeFrame(row).toList())
              .toList();
          for (int t = 0; t < model.windowSize; t++) {
            for (int f = 0; f < model.inFeatures; f++) {
              expect(
                (dartNorm[t][f] - pyNorm[t][f]).abs(),
                lessThanOrEqualTo(1e-5),
              );
            }
          }

          final dartLogit = model.predictLogit(dartNorm);
          final dartProb = model.predict(dartNorm);
          final pyLogit = (vm['pytorch_logit'] as num).toDouble();
          final pyProb = (vm['pytorch_prob'] as num).toDouble();

          maxLogitDiff = math.max(maxLogitDiff, (dartLogit - pyLogit).abs());
          maxProbDiff = math.max(maxProbDiff, (dartProb - pyProb).abs());
          if ((dartProb >= 0.5) == (pyProb >= 0.5)) {
            classMatches++;
          }
        }

        expect(maxLogitDiff, lessThanOrEqualTo(1e-5));
        expect(maxProbDiff, lessThanOrEqualTo(1e-5));
        expect(classMatches, vectors.length);
      });
    }
  });

  group('CapAlstmIodClassifier Safety & Integration', () {
    test('Abstains on missing Light and resets on >2.5s timestamp gap', () {
      final ckptJson =
          jsonDecode(
                File(
                  'assets/models/iod/cap_alstm_4ch_mobile_w12_wbce.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final model = CapAlstmModel.fromJson(ckptJson);
      final classifier = CapAlstmIodClassifier(
        model: model,
        modelVersion: 'cap-alstm-4ch-mobile-test',
        useCausalHmm: true,
      );
      final composite = IodCompositeClassifier.capAlstm(classifier: classifier);

      final t0 = DateTime.utc(2026, 11, 27, 10, 0, 0);

      // Missing light -> must abstain (never fabricate 0 lux)
      final missingLight = composite.predict(
        IodSensorSnapshot(
          timestamp: t0,
          hasLightSensor: false,
          hasImuData: true,
          magneticMagnitudeMean: 45.0,
          accelMagnitudeMean: 0.1,
        ),
      );
      expect(missingLight.state, IndoorOutdoorState.unknown);
      expect(missingLight.isObservationalOnly, isTrue);

      // Feed 12 contiguous valid epochs -> produces indoor/outdoor decision
      for (int i = 0; i < 11; i++) {
        final warmup = composite.predict(
          IodSensorSnapshot(
            timestamp: t0.add(Duration(seconds: i + 1)),
            hasLightSensor: true,
            ambientLux: 3500.0,
            hasImuData: true,
            magneticMagnitudeMean: 45.0,
            accelMagnitudeMean: 1.2,
          ),
        );
        expect(warmup.state, IndoorOutdoorState.unknown);
      }

      final active = composite.predict(
        IodSensorSnapshot(
          timestamp: t0.add(const Duration(seconds: 12)),
          hasLightSensor: true,
          ambientLux: 3500.0,
          hasImuData: true,
          magneticMagnitudeMean: 45.0,
          accelMagnitudeMean: 1.2,
        ),
      );
      expect(
        active.state,
        anyOf(IndoorOutdoorState.indoor, IndoorOutdoorState.outdoor),
      );
      expect(active.isObservationalOnly, isTrue);

      // Gap of 5 seconds (>2.5s) -> must reset window and abstain during warmup
      final afterGap = composite.predict(
        IodSensorSnapshot(
          timestamp: t0.add(const Duration(seconds: 17)),
          hasLightSensor: true,
          ambientLux: 3500.0,
          hasImuData: true,
          magneticMagnitudeMean: 45.0,
          accelMagnitudeMean: 1.2,
        ),
      );
      expect(afterGap.state, IndoorOutdoorState.unknown);
      expect(classifier.bufferedEpochs, 1);
    });
  });
}
