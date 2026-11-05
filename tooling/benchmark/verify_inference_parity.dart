// ignore_for_file: avoid_print, unused_local_variable
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  print('======================================================================');
  print('       VERIFYING DART VS PYTORCH DEEPIOD INFERENCE PARITY');
  print('======================================================================');

  final weightsFile = File('tooling/data/deepiod_weights/deepiod_model_c_weights.json');
  if (!weightsFile.existsSync()) {
    print('Error: Weights file not found at ${weightsFile.path}');
    exit(1);
  }

  final testVectorsFile = File('tooling/data/deepiod_weights/parity_test_vectors.json');
  if (!testVectorsFile.existsSync()) {
    print('Error: Test vectors file not found at ${testVectorsFile.path}');
    exit(1);
  }

  print('Loading weights from: ${weightsFile.path}');
  final weightsJson = jsonDecode(weightsFile.readAsStringSync()) as Map<String, dynamic>;
  final model = DartModelC.fromJson(weightsJson);

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
  print('                      PARITY VERIFICATION METRICS');
  print('----------------------------------------------------------------------');
  print('Total Evaluated Samples:     ${testVectors.length}');
  print('Maximum Absolute Error:      ${maxAbsError.toStringAsExponential(6)}');
  print('Mean Absolute Error:         ${meanAbsError.toStringAsExponential(6)}');
  print('Classification Agreement:    ${agreementPct.toStringAsFixed(2)}% ($agreements / ${testVectors.length})');
  print('----------------------------------------------------------------------\n');

  if (maxAbsError > 1e-4) {
    print('FAILED: Maximum absolute error exceeded tolerance 1e-4!');
    exit(1);
  }

  if (agreementPct < 99.9) {
    print('FAILED: Classification agreement below 99.9%!');
    exit(1);
  }

  print('SUCCESS: Exact numerical and classification parity verified between Dart and PyTorch!');
}

class DartModelC {
  final List<List<double>> dws1DepthW;
  final double dws1DepthB;
  final List<double> dws1PointW;
  final List<double> dws1PointB;
  final List<List<List<double>>> dws2DepthW;
  final List<double> dws2DepthB;
  final List<List<double>> dws2PointW;
  final List<double> dws2PointB;
  final List<List<double>> dense1W;
  final List<double> dense1B;
  final List<double> outW;
  final double outB;
  final List<double> mean;
  final List<double> std;

  DartModelC({
    required this.dws1DepthW,
    required this.dws1DepthB,
    required this.dws1PointW,
    required this.dws1PointB,
    required this.dws2DepthW,
    required this.dws2DepthB,
    required this.dws2PointW,
    required this.dws2PointB,
    required this.dense1W,
    required this.dense1B,
    required this.outW,
    required this.outB,
    required this.mean,
    required this.std,
  });

  factory DartModelC.fromJson(Map<String, dynamic> json) {
    List<List<double>> parse2d(dynamic data) =>
        (data as List).map((row) => (row as List).map((v) => (v as num).toDouble()).toList()).toList();

    List<double> parse1d(dynamic data) =>
        (data as List).map((v) => (v as num).toDouble()).toList();

    List<List<List<double>>> parse3d(dynamic data) =>
        (data as List).map((ch) => parse2d(ch)).toList();

    return DartModelC(
      dws1DepthW: parse2d(json['dws1_depth_w']),
      dws1DepthB: (json['dws1_depth_b'] as num).toDouble(),
      dws1PointW: parse1d(json['dws1_point_w']),
      dws1PointB: parse1d(json['dws1_point_b']),
      dws2DepthW: parse3d(json['dws2_depth_w']),
      dws2DepthB: parse1d(json['dws2_depth_b']),
      dws2PointW: parse2d(json['dws2_point_w']),
      dws2PointB: parse1d(json['dws2_point_b']),
      dense1W: parse2d(json['dense1_w']),
      dense1B: parse1d(json['dense1_b']),
      outW: parse1d(json['out_w']),
      outB: (json['out_b'] as num).toDouble(),
      mean: parse1d(json['mean']),
      std: parse1d(json['std']),
    );
  }

  double predict(List<List<double>> window) {
    // window is 10 x 8
    // Layer 1: DWS Conv2D (3x3), in_ch=1, out_ch=1, pad=1
    final h1 = List.generate(10, (_) => Float64List(8));
    for (int t = 0; t < 10; t++) {
      for (int s = 0; s < 8; s++) {
        double sum = dws1DepthB;
        for (int di = -1; di <= 1; di++) {
          final pt = t + di;
          if (pt < 0 || pt >= 10) continue;
          for (int dj = -1; dj <= 1; dj++) {
            final ps = s + dj;
            if (ps < 0 || ps >= 8) continue;
            sum += window[pt][ps] * dws1DepthW[di + 1][dj + 1];
          }
        }
        h1[t][s] = sum > 0.0 ? sum : 0.0; // ReLU
      }
    }

    // Layer 2: Pointwise Conv2D (32, 1x1) with folded BN
    final h2 = List.generate(32, (_) => List.generate(10, (_) => Float64List(8)));
    for (int c = 0; c < 32; c++) {
      final wc = dws1PointW[c];
      final bc = dws1PointB[c];
      for (int t = 0; t < 10; t++) {
        for (int s = 0; s < 8; s++) {
          final val = bc + wc * h1[t][s];
          h2[c][t][s] = val > 0.0 ? val : 0.0; // ReLU
        }
      }
    }

    // Layer 3: DWS Conv2D (3x3), 32 channels, groups=32, pad=1
    final h3 = List.generate(32, (_) => List.generate(10, (_) => Float64List(8)));
    for (int c = 0; c < 32; c++) {
      final bc = dws2DepthB[c];
      final kw = dws2DepthW[c];
      for (int t = 0; t < 10; t++) {
        for (int s = 0; s < 8; s++) {
          double sum = bc;
          for (int di = -1; di <= 1; di++) {
            final pt = t + di;
            if (pt < 0 || pt >= 10) continue;
            for (int dj = -1; dj <= 1; dj++) {
              final ps = s + dj;
              if (ps < 0 || ps >= 8) continue;
              sum += h2[c][pt][ps] * kw[di + 1][dj + 1];
            }
          }
          h3[c][t][s] = sum > 0.0 ? sum : 0.0; // ReLU
        }
      }
    }

    // Layer 4: Pointwise Conv2D (32, 1x1, in_channels 32) with folded BN
    final h4 = List.generate(32, (_) => List.generate(10, (_) => Float64List(8)));
    for (int c = 0; c < 32; c++) {
      final bc = dws2PointB[c];
      final wRow = dws2PointW[c];
      for (int t = 0; t < 10; t++) {
        for (int s = 0; s < 8; s++) {
          double sum = bc;
          for (int k = 0; k < 32; k++) {
            sum += wRow[k] * h3[k][t][s];
          }
          h4[c][t][s] = sum > 0.0 ? sum : 0.0; // ReLU
        }
      }
    }

    // Layer 5: MaxPool2D (2, 1) -> shape 32 x 5 x 8
    // Followed by Global Average Pooling across the 5 x 8 = 40 entries
    final gap = Float64List(32);
    for (int c = 0; c < 32; c++) {
      double sum = 0.0;
      for (int t = 0; t < 5; t++) {
        final t2 = t * 2;
        for (int s = 0; s < 8; s++) {
          final v1 = h4[c][t2][s];
          final v2 = h4[c][t2 + 1][s];
          sum += v1 > v2 ? v1 : v2;
        }
      }
      gap[c] = sum / 40.0;
    }

    // Dense 1 (32 -> 32) + ReLU
    final d1 = Float64List(32);
    for (int j = 0; j < 32; j++) {
      double sum = dense1B[j];
      final wRow = dense1W[j];
      for (int c = 0; c < 32; c++) {
        sum += wRow[c] * gap[c];
      }
      d1[j] = sum > 0.0 ? sum : 0.0;
    }

    // Output Dense (32 -> 1) + Sigmoid
    double logit = outB;
    for (int j = 0; j < 32; j++) {
      logit += outW[j] * d1[j];
    }

    return 1.0 / (1.0 + math.exp(-logit));
  }
}
