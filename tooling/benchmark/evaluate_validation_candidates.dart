// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ciod_dataset_adapter.dart';

void main() {
  test('Evaluate IOD Candidate Improvements on Validation Partition (Sessions 60..71)', () async {
    print('======================================================================');
    print('  AETRON IOD CANDIDATE IMPROVEMENT RESEARCH ON VALIDATION DATA ONLY');
    print('  (SESSIONS 60..71, 12 UNSEEN SESSIONS, 0 LEAKAGE WITH TEST 72..84)');
    print('======================================================================\n');

    final ciodFile = File('tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv');
    if (!ciodFile.existsSync()) {
      fail('Cambridge CIOD CSV not found at: ${ciodFile.path}');
    }

    final valSessionIds = Set<int>.from(List.generate(12, (i) => 60 + i));
    print('Loading all Validation samples (Sessions 60..71, maxSamplesPerSession = 0)...');
    final swLoad = Stopwatch()..start();
    final valSamples = await CiodDatasetAdapter.parseCsvFile(
      file: ciodFile,
      targetSessionIndices: valSessionIds,
      maxSamplesPerSession: 0,
    );
    print('Loaded ${valSamples.length} validation samples in ${swLoad.elapsedMilliseconds} ms.');

    final indoorCount = valSamples.where((s) => s.groundTruth == IndoorOutdoorState.indoor).length;
    final outdoorCount = valSamples.where((s) => s.groundTruth == IndoorOutdoorState.outdoor).length;
    print('Validation Split Distribution:');
    print('  - Total:   ${valSamples.length}');
    print('  - Indoor:  $indoorCount (${(indoorCount / valSamples.length * 100).toStringAsFixed(2)}%)');
    print('  - Outdoor: $outdoorCount (${(outdoorCount / valSamples.length * 100).toStringAsFixed(2)}%)\n');

    // 1. Run Model C-Mobile forward pass to obtain raw continuous outdoor probability p_out
    final mobileClassifier = DeepIodNeuralClassifier.mobile();
    final rawProbabilities = <double>[];
    String? lastSess;
    final swInfer = Stopwatch()..start();
    for (final s in valSamples) {
      if (s.sessionId != lastSess) {
        mobileClassifier.reset();
        lastSess = s.sessionId;
      }
      final pred = mobileClassifier.classify(s.snapshot);
      rawProbabilities.add(pred.deepIodOutdoorProbability ?? 0.5);
    }
    print('Computed ${rawProbabilities.length} raw inferences in ${swInfer.elapsedMilliseconds} ms.\n');

    // Helper evaluation function
    Map<String, double> computeMetrics(List<IndoorOutdoorState> predictions) {
      int inTp = 0, inFp = 0, inFn = 0;
      int outTp = 0, outFp = 0, outFn = 0;
      for (int i = 0; i < valSamples.length; i++) {
        final gt = valSamples[i].groundTruth;
        final pr = predictions[i];
        if (gt == IndoorOutdoorState.indoor) {
          if (pr == IndoorOutdoorState.indoor) {
            inTp++;
          } else {
            inFn++;
            outFp++;
          }
        } else if (gt == IndoorOutdoorState.outdoor) {
          if (pr == IndoorOutdoorState.outdoor) {
            outTp++;
          } else {
            outFn++;
            inFp++;
          }
        }
      }
      final acc = (inTp + outTp) / valSamples.length;
      final inRec = inTp / (inTp + inFn);
      final inPrec = inTp / (inTp + inFp);
      final inF1 = 2 * inPrec * inRec / (inPrec + inRec);
      final outRec = outTp / (outTp + outFn);
      final outPrec = (outTp + outFp) > 0 ? outTp / (outTp + outFp) : 0.0;
      final outF1 = (outPrec + outRec) > 0 ? 2 * outPrec * outRec / (outPrec + outRec) : 0.0;
      final macroF1 = (inF1 + outF1) / 2.0;
      return {
        'acc': acc,
        'macroF1': macroF1,
        'inRec': inRec,
        'inPrec': inPrec,
        'inF1': inF1,
        'outRec': outRec,
        'outPrec': outPrec,
        'outF1': outF1,
      };
    }

    // =========================================================================
    // EXPERIMENT 1: THRESHOLD CALIBRATION SWEEP ON VALIDATION DATA
    // =========================================================================
    print('======================================================================');
    print('  EXPERIMENT 1: THRESHOLD CALIBRATION SWEEP ON VALIDATION SESSIONS');
    print('======================================================================');
    print('| Threshold θ | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Outdoor Prec |');
    print('| :---: | :---: | :---: | :---: | :---: | :---: |');

    final thresholds = [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60];
    double bestF1 = 0.0;
    double bestTheta = 0.50;

    for (final th in thresholds) {
      final preds = rawProbabilities
          .map((p) => p >= th ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor)
          .toList();
      final m = computeMetrics(preds);
      if (m['macroF1']! > bestF1) {
        bestF1 = m['macroF1']!;
        bestTheta = th;
      }
      print('| ${th.toStringAsFixed(2)} | ${(m['acc']! * 100).toStringAsFixed(2)}% | '
          '${(m['macroF1']! * 100).toStringAsFixed(2)}% | ${(m['inRec']! * 100).toStringAsFixed(1)}% | '
          '${(m['outRec']! * 100).toStringAsFixed(1)}% | ${(m['outPrec']! * 100).toStringAsFixed(1)}% |');
    }
    print('Validation Optimal Threshold by Macro-F1: θ = ${bestTheta.toStringAsFixed(2)} (Macro-F1: ${(bestF1 * 100).toStringAsFixed(2)}%)\n');

    // =========================================================================
    // EXPERIMENT 2: TEMPORAL HYSTERESIS FILTERING (SCHMITT TRIGGER + EMA)
    // =========================================================================
    print('======================================================================');
    print('  EXPERIMENT 2: TEMPORAL HYSTERESIS FILTERING ON VALIDATION SESSIONS');
    print('======================================================================');
    print('| Config (Hysteresis / EMA) | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Outdoor Prec |');
    print('| :--- | :---: | :---: | :---: | :---: | :---: |');

    // Dual Threshold Hysteresis
    final hysteresisConfigs = [
      (0.35, 0.25),
      (0.40, 0.25),
      (0.40, 0.20),
      (0.45, 0.25),
      (0.45, 0.30),
      (0.50, 0.30),
    ];

    for (final (thHigh, thLow) in hysteresisConfigs) {
      final preds = <IndoorOutdoorState>[];
      IndoorOutdoorState state = IndoorOutdoorState.indoor;
      String? curSess;
      for (int i = 0; i < valSamples.length; i++) {
        if (valSamples[i].sessionId != curSess) {
          state = IndoorOutdoorState.indoor;
          curSess = valSamples[i].sessionId;
        }
        final p = rawProbabilities[i];
        if (state == IndoorOutdoorState.indoor && p >= thHigh) {
          state = IndoorOutdoorState.outdoor;
        } else if (state == IndoorOutdoorState.outdoor && p <= thLow) {
          state = IndoorOutdoorState.indoor;
        }
        preds.add(state);
      }
      final m = computeMetrics(preds);
      print('| Hysteresis [High=$thHigh, Low=$thLow] | ${(m['acc']! * 100).toStringAsFixed(2)}% | '
          '${(m['macroF1']! * 100).toStringAsFixed(2)}% | ${(m['inRec']! * 100).toStringAsFixed(1)}% | '
          '${(m['outRec']! * 100).toStringAsFixed(1)}% | ${(m['outPrec']! * 100).toStringAsFixed(1)}% |');
    }

    // Exponential Moving Average (EMA) + Threshold
    print('\n-- EMA Filter --');
    final emaAlphas = [0.2, 0.4, 0.6, 0.8];
    for (final alpha in emaAlphas) {
      final preds = <IndoorOutdoorState>[];
      double ema = 0.5;
      String? curSess;
      for (int i = 0; i < valSamples.length; i++) {
        if (valSamples[i].sessionId != curSess) {
          ema = 0.5;
          curSess = valSamples[i].sessionId;
        }
        final p = rawProbabilities[i];
        ema = (alpha * ema) + ((1.0 - alpha) * p);
        preds.add(ema >= bestTheta ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor);
      }
      final m = computeMetrics(preds);
      print('| EMA (α=$alpha, θ=$bestTheta) | ${(m['acc']! * 100).toStringAsFixed(2)}% | '
          '${(m['macroF1']! * 100).toStringAsFixed(2)}% | ${(m['inRec']! * 100).toStringAsFixed(1)}% | '
          '${(m['outRec']! * 100).toStringAsFixed(1)}% | ${(m['outPrec']! * 100).toStringAsFixed(1)}% |');
    }

    // =========================================================================
    // EXPERIMENT 3: SENSOR-AWARE POCKET/DARKNESS MITIGATION
    // =========================================================================
    print('\n======================================================================');
    print('  EXPERIMENT 3: SENSOR-AWARE DARKNESS & ACTIVITY MITIGATION');
    print('  (When Light < 5 and Daytime == 0, light is non-informative)');
    print('======================================================================');
    print('| Sensor-Aware Mitigation Mode | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Outdoor Prec |');
    print('| :--- | :---: | :---: | :---: | :---: | :---: |');

    // Rule: When light is dark/stowed (ambientLux < 5.0 and Daytime == 0),
    // if user is actively walking (accel > threshold or stepDelta > 0),
    // lower threshold θ from 0.50 to adaptive θ_dark.
    for (final thDark in [0.25, 0.30, 0.35, 0.40]) {
      final preds = <IndoorOutdoorState>[];
      for (int i = 0; i < valSamples.length; i++) {
        final s = valSamples[i].snapshot;
        final p = rawProbabilities[i];
        final isDarkPocket = (s.ambientLux == null || s.ambientLux! < 5.0) && s.isNightTime;
        final effectiveTh = isDarkPocket ? thDark : 0.50;
        preds.add(p >= effectiveTh ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor);
      }
      final m = computeMetrics(preds);
      print('| Adaptive Pocket-Dark (θ_normal=0.50, θ_dark=$thDark) | ${(m['acc']! * 100).toStringAsFixed(2)}% | '
          '${(m['macroF1']! * 100).toStringAsFixed(2)}% | ${(m['inRec']! * 100).toStringAsFixed(1)}% | '
          '${(m['outRec']! * 100).toStringAsFixed(1)}% | ${(m['outPrec']! * 100).toStringAsFixed(1)}% |');
    }

    print('\nCandidate evaluation on Validation Partition complete.');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

