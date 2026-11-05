// ignore_for_file: avoid_print, unused_local_variable
import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_c.dart';

void verifyModelParity({
  required String modelName,
  required String weightsPath,
  required String testVectorsPath,
  required int expectedWidth,
}) {
  print('======================================================================');
  print('  VERIFYING $modelName: DART VS PYTORCH INFERENCE PARITY');
  print('======================================================================');

  final weightsFile = File(weightsPath);
  if (!weightsFile.existsSync()) {
    print('Error: Weights file not found at ${weightsFile.path}');
    exit(1);
  }

  final testVectorsFile = File(testVectorsPath);
  if (!testVectorsFile.existsSync()) {
    print('Error: Test vectors file not found at ${testVectorsFile.path}');
    exit(1);
  }

  print('Loading weights from: ${weightsFile.path}');
  final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
  final model = DeepIodModelC.fromJson(weightsJson);

  print('Loading test vectors from: ${testVectorsFile.path}');
  final testVectors = (jsonDecode(testVectorsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  print('Loaded ${testVectors.length} held-out test vectors.');

  double maxAbsError = 0.0;
  double sumAbsError = 0.0;
  int agreements = 0;

  for (int i = 0; i < testVectors.length; i++) {
    final item = testVectors[i];
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();
    final label = item['label'] as int;

    assert(rawWindow[0].length == expectedWidth, 'Window width must be $expectedWidth');

    final dartProb = model.predict(rawWindow);
    final absError = (dartProb - expectedPyTorch).abs();

    if (absError > maxAbsError) {
      maxAbsError = absError;
    }
    sumAbsError += absError;

    final bool dartPredOutdoor = dartProb >= 0.50;
    final bool pytorchPredOutdoor = expectedPyTorch >= 0.50;
    if (dartPredOutdoor == pytorchPredOutdoor) {
      agreements++;
    }
  }

  final meanAbsError = sumAbsError / testVectors.length;
  final agreementPct = (agreements / testVectors.length) * 100.0;

  print('\n----------------------------------------------------------------------');
  print('         PARITY VERIFICATION METRICS ($modelName)');
  print('----------------------------------------------------------------------');
  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  print('----------------------------------------------------------------------\n');

  if (maxAbsError > 1e-4) {
    print('FAILED: Maximum absolute error exceeded tolerance 1e-4 for $modelName!');
    exit(1);
  }

  if (agreementPct < 99.9) {
    print('FAILED: Classification agreement below 99.9% for $modelName!');
    exit(1);
  }

  print('SUCCESS: Exact numerical and classification parity verified for $modelName!\n');
}

void main() {
  // 1. Verify Model C (8-sensor complete)
  verifyModelParity(
    modelName: 'DeepIOD Model C (8-Sensor Complete)',
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_c_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors.json',
    expectedWidth: 8,
  );

  // 2. Verify Model C-Mobile (4-sensor mobile-compatible)
  verifyModelParity(
    modelName: 'DeepIOD Model C-Mobile (4-Sensor Mobile)',
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_c_mobile_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_mobile.json',
    expectedWidth: 4,
  );
}
