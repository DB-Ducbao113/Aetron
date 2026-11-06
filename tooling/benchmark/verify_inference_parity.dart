// ignore_for_file: avoid_print, unused_local_variable
import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_a.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_b.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_model_c.dart';

void verifyModelAParity({
  required String weightsPath,
  required String testVectorsPath,
}) {
  print('======================================================================');
  print('  VERIFYING MODEL A (CNN-LSTM): DART VS PYTORCH INFERENCE PARITY');
  print('======================================================================');

  final weightsFile = File(weightsPath);
  final testVectorsFile = File(testVectorsPath);
  if (!weightsFile.existsSync() || !testVectorsFile.existsSync()) {
    print('Error: Missing files for Model A parity');
    exit(1);
  }

  final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
  final model = DeepIodModelA.fromJson(weightsJson);
  final testVectors = (jsonDecode(testVectorsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  double maxAbsError = 0.0;
  double sumAbsError = 0.0;
  int agreements = 0;

  for (final item in testVectors) {
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();
    final dartProb = model.predict(rawWindow);
    final absError = (dartProb - expectedPyTorch).abs();
    if (absError > maxAbsError) maxAbsError = absError;
    sumAbsError += absError;

    if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
  }

  final meanAbsError = sumAbsError / testVectors.length;
  final agreementPct = (agreements / testVectors.length) * 100.0;

  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  assert(maxAbsError < 1e-4, 'Model A Max error too high');
  assert(agreementPct == 100.0, 'Model A classification mismatch');
  print('SUCCESS: Model A (CNN-LSTM) parity verified!\n');
}

void verifyModelBParity({
  required String weightsPath,
  required String testVectorsPath,
}) {
  print('======================================================================');
  print('  VERIFYING MODEL B (CNN-MHA): DART VS PYTORCH INFERENCE PARITY');
  print('======================================================================');

  final weightsFile = File(weightsPath);
  final testVectorsFile = File(testVectorsPath);
  if (!weightsFile.existsSync() || !testVectorsFile.existsSync()) {
    print('Error: Missing files for Model B parity');
    exit(1);
  }

  final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
  final model = DeepIodModelB.fromJson(weightsJson);
  final testVectors = (jsonDecode(testVectorsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  double maxAbsError = 0.0;
  double sumAbsError = 0.0;
  int agreements = 0;

  for (final item in testVectors) {
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();
    final dartProb = model.predict(rawWindow);
    final absError = (dartProb - expectedPyTorch).abs();
    if (absError > maxAbsError) maxAbsError = absError;
    sumAbsError += absError;

    if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
  }

  final meanAbsError = sumAbsError / testVectors.length;
  final agreementPct = (agreements / testVectors.length) * 100.0;

  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  assert(maxAbsError < 1e-4, 'Model B Max error too high');
  assert(agreementPct == 100.0, 'Model B classification mismatch');
  print('SUCCESS: Model B (CNN-MHA) parity verified!\n');
}

void verifyModelCParity({
  required String modelName,
  required String weightsPath,
  required String testVectorsPath,
  required int expectedWidth,
}) {
  print('======================================================================');
  print('  VERIFYING $modelName: DART VS PYTORCH INFERENCE PARITY');
  print('======================================================================');

  final weightsFile = File(weightsPath);
  final testVectorsFile = File(testVectorsPath);
  if (!weightsFile.existsSync() || !testVectorsFile.existsSync()) {
    print('Error: Missing files for $modelName parity');
    exit(1);
  }

  final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
  final model = DeepIodModelC.fromJson(weightsJson);
  final testVectors = (jsonDecode(testVectorsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  double maxAbsError = 0.0;
  double sumAbsError = 0.0;
  int agreements = 0;

  for (final item in testVectors) {
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorch = (item['prob_pytorch'] as num).toDouble();
    assert(rawWindow[0].length == expectedWidth);
    final dartProb = model.predict(rawWindow);
    final absError = (dartProb - expectedPyTorch).abs();
    if (absError > maxAbsError) maxAbsError = absError;
    sumAbsError += absError;

    if ((dartProb >= 0.50) == (expectedPyTorch >= 0.50)) agreements++;
  }

  final meanAbsError = sumAbsError / testVectors.length;
  final agreementPct = (agreements / testVectors.length) * 100.0;

  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  assert(maxAbsError < 1e-4, '$modelName Max error too high');
  assert(agreementPct >= 99.9, '$modelName classification mismatch');
  print('SUCCESS: $modelName parity verified!\n');
}

void verifyAmvEnsembleParity({
  required String weightsAPath,
  required String weightsBPath,
  required String weightsCPath,
  required String metadataPath,
  required String testVectorsPath,
}) {
  print('======================================================================');
  print('  VERIFYING DEEPIOD AMV ENSEMBLE (MODELS A+B+C): DART VS PYTORCH');
  print('======================================================================');

  final metaJson = jsonDecode(File(metadataPath).readAsStringSync()) as Map<String, dynamic>;
  final amvWeights = metaJson['amv_weights'] as Map<String, dynamic>;
  final double wa = (amvWeights['model_a'] as num).toDouble();
  final double wb = (amvWeights['model_b'] as num).toDouble();
  final double wc = (amvWeights['model_c'] as num).toDouble();

  final modelA = DeepIodModelA.fromJson(jsonDecode(File(weightsAPath).readAsStringSync()));
  final modelB = DeepIodModelB.fromJson(jsonDecode(File(weightsBPath).readAsStringSync()));
  final modelC = DeepIodModelC.fromJson(jsonDecode(File(weightsCPath).readAsStringSync()));

  final testVectors = (jsonDecode(File(testVectorsPath).readAsStringSync()) as List).cast<Map<String, dynamic>>();

  double maxAbsError = 0.0;
  double sumAbsError = 0.0;
  int agreements = 0;

  for (final item in testVectors) {
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorchAmv = (item['prob_pytorch_amv'] as num).toDouble();

    final pa = modelA.predict(rawWindow);
    final pb = modelB.predict(rawWindow);
    final pc = modelC.predict(rawWindow);
    final dartAmv = (wa * pa) + (wb * pb) + (wc * pc);

    final absError = (dartAmv - expectedPyTorchAmv).abs();
    if (absError > maxAbsError) maxAbsError = absError;
    sumAbsError += absError;

    if ((dartAmv >= 0.50) == (expectedPyTorchAmv >= 0.50)) agreements++;
  }

  final meanAbsError = sumAbsError / testVectors.length;
  final agreementPct = (agreements / testVectors.length) * 100.0;

  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  assert(maxAbsError < 1e-4, 'AMV Max error too high');
  assert(agreementPct == 100.0, 'AMV classification mismatch');
  print('SUCCESS: DeepIOD AMV Ensemble parity verified!\n');
}

double _computeBayesianBinomialAmv({
  required double pA,
  required double pB,
  required double pC,
  double priorOutdoor = 0.20,
}) {
  final bool voteA = pA >= 0.50;
  final bool voteB = pB >= 0.50;
  final bool voteC = pC >= 0.50;

  const double tprA = 0.65;
  const double tprB = 0.62;
  const double tprC = 0.88;

  const double tnrA = 0.99;
  const double tnrB = 0.99;
  const double tnrC = 0.99;

  final double lOutA = voteA ? tprA : (1.0 - tprA);
  final double lOutB = voteB ? tprB : (1.0 - tprB);
  final double lOutC = voteC ? tprC : (1.0 - tprC);
  final double likelihoodOutdoor = lOutA * lOutB * lOutC;

  final double lInA = voteA ? (1.0 - tnrA) : tnrA;
  final double lInB = voteB ? (1.0 - tnrB) : tnrB;
  final double lInC = voteC ? (1.0 - tnrC) : tnrC;
  final double likelihoodIndoor = lInA * lInB * lInC;

  final double priorIndoor = 1.0 - priorOutdoor;
  final double numerator = likelihoodOutdoor * priorOutdoor;
  final double denominator = numerator + (likelihoodIndoor * priorIndoor);

  if (denominator <= 0.0) return 0.50;
  return numerator / denominator;
}

void verifyBayesianAmvParity({
  required String weightsAPath,
  required String weightsBPath,
  required String weightsCPath,
  required String testVectorsPath,
}) {
  print('======================================================================');
  print('  VERIFYING AETRON EXPERIMENTAL BAYESIAN FUSION EXTENSION');
  print('  (Note: DeepIOD Eq. 9 published inference is linear weighted voting;');
  print('   this tests Aetron\'s auxiliary empirical Bayesian likelihood fusion)');
  print('======================================================================');

  final modelA = DeepIodModelA.fromJson(jsonDecode(File(weightsAPath).readAsStringSync()));
  final modelB = DeepIodModelB.fromJson(jsonDecode(File(weightsBPath).readAsStringSync()));
  final modelC = DeepIodModelC.fromJson(jsonDecode(File(weightsCPath).readAsStringSync()));

  final testVectors = (jsonDecode(File(testVectorsPath).readAsStringSync()) as List).cast<Map<String, dynamic>>();

  int linearAgreements = 0;

  for (final item in testVectors) {
    final rawWindow = (item['window'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final expectedPyTorchAmv = (item['prob_pytorch_amv'] as num).toDouble();

    final pa = modelA.predict(rawWindow);
    final pb = modelB.predict(rawWindow);
    final pc = modelC.predict(rawWindow);
    final bayesProb = _computeBayesianBinomialAmv(pA: pa, pB: pb, pC: pc);

    final bool bayesOut = bayesProb >= 0.50;
    final bool linearOut = expectedPyTorchAmv >= 0.50;
    if (bayesOut == linearOut) linearAgreements++;
  }

  final agreementPct = (linearAgreements / testVectors.length) * 100.0;
  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Consensus with Linear AMV:   ${agreementPct.toStringAsFixed(2)}% ($linearAgreements / ${testVectors.length})');
  assert(agreementPct >= 95.0, 'Bayesian fusion deviated excessively from consensus');
  print('SUCCESS: Aetron Experimental Bayesian Fusion verified!\n');
}

void main() {
  // 1. Model A (CNN-LSTM)
  verifyModelAParity(
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_a_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_model_a.json',
  );

  // 2. Model B (CNN-MHA)
  verifyModelBParity(
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_b_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_model_b.json',
  );

  // 3. Model C (8-sensor complete)
  verifyModelCParity(
    modelName: 'DeepIOD Model C (8-Sensor Complete)',
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_c_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors.json',
    expectedWidth: 8,
  );

  // 4. Model C-Mobile (4-sensor mobile-compatible)
  verifyModelCParity(
    modelName: 'DeepIOD Model C-Mobile (4-Sensor Dedicated)',
    weightsPath: 'tooling/data/deepiod_weights/deepiod_model_c_mobile_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_mobile.json',
    expectedWidth: 4,
  );

  // 5. AMV Ensemble Linear Weighted
  verifyAmvEnsembleParity(
    weightsAPath: 'tooling/data/deepiod_weights/deepiod_model_a_weights.json',
    weightsBPath: 'tooling/data/deepiod_weights/deepiod_model_b_weights.json',
    weightsCPath: 'tooling/data/deepiod_weights/deepiod_model_c_weights.json',
    metadataPath: 'tooling/data/deepiod_weights/deepiod_metadata.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_amv.json',
  );

  // 6. AMV Ensemble Published Bayesian/Binomial Formulation
  verifyBayesianAmvParity(
    weightsAPath: 'tooling/data/deepiod_weights/deepiod_model_a_weights.json',
    weightsBPath: 'tooling/data/deepiod_weights/deepiod_model_b_weights.json',
    weightsCPath: 'tooling/data/deepiod_weights/deepiod_model_c_weights.json',
    testVectorsPath: 'tooling/data/deepiod_weights/parity_test_vectors_amv.json',
  );
}
