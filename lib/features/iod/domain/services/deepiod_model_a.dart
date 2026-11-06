import 'dart:math' as math;
import 'dart:typed_data';

/// 1D-CNN Encoder + LSTM Sequence Decoder (Model A from DeepIOD PMC11360063 Table 1).
///
/// Implements exact forward pass matching the trained PyTorch Model A checkpoint:
/// Input: 10 temporal steps x 8 sensor channels.
/// - Layer 1: Conv1D (in_ch=8, out_ch=64, k=3, pad=1, ReLU)
/// - Layer 2: MaxPool1D (2) -> length 5
/// - Layer 3: LSTM (in_dim=64, hidden_dim=64, 5 steps)
/// - Layer 4: Dropout (0.2) -> identity during inference
/// - Layer 5: Dense (64 -> 32, ReLU)
/// - Output: Dense (32 -> 1, Sigmoid)
class DeepIodModelA {
  final List<List<List<double>>> convW; // (64, 8, 3)
  final List<double> convB; // (64,)
  final List<List<double>> lstmWIh; // (256, 64)
  final List<List<double>> lstmWHh; // (256, 64)
  final List<double> lstmBIh; // (256,)
  final List<double> lstmBHh; // (256,)
  final List<List<double>> denseW; // (32, 64)
  final List<double> denseB; // (32,)
  final List<double> outW; // (32,)
  final double outB;
  final List<double> mean;
  final List<double> std;

  DeepIodModelA({
    required this.convW,
    required this.convB,
    required this.lstmWIh,
    required this.lstmWHh,
    required this.lstmBIh,
    required this.lstmBHh,
    required this.denseW,
    required this.denseB,
    required this.outW,
    required this.outB,
    required this.mean,
    required this.std,
  });

  factory DeepIodModelA.fromJson(Map<String, dynamic> json) {
    List<double> parse1d(dynamic data) =>
        (data as List).map((v) => (v as num).toDouble()).toList();

    List<List<double>> parse2d(dynamic data) =>
        (data as List).map((row) => parse1d(row)).toList();

    List<List<List<double>>> parse3d(dynamic data) =>
        (data as List).map((plane) => parse2d(plane)).toList();

    return DeepIodModelA(
      convW: parse3d(json['conv_w']),
      convB: parse1d(json['conv_b']),
      lstmWIh: parse2d(json['lstm_w_ih']),
      lstmWHh: parse2d(json['lstm_w_hh']),
      lstmBIh: parse1d(json['lstm_b_ih']),
      lstmBHh: parse1d(json['lstm_b_hh']),
      denseW: parse2d(json['dense_w']),
      denseB: parse1d(json['dense_b']),
      outW: parse1d(json['out_w']),
      outB: (json['out_b'] as num).toDouble(),
      mean: parse1d(json['mean']),
      std: parse1d(json['std']),
    );
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final ep = math.exp(x);
    final em = math.exp(-x);
    return (ep - em) / (ep + em);
  }

  /// Evaluates a 10x8 normalized temporal window and returns P(Outdoor) in [0.0, 1.0].
  double predict(List<List<double>> window) {
    assert(window.length == 10, 'Window must have 10 temporal steps');
    final inCh = window[0].length;
    assert(inCh == 8, 'Model A requires 8 sensor features');

    // Layer 1: Conv1D (64, k=3, pad=1) + ReLU
    // window is 10 time steps x 8 channels
    final h1 = List.generate(64, (_) => Float64List(10));
    for (int c = 0; c < 64; c++) {
      final bc = convB[c];
      final wc = convW[c]; // (8, 3)
      for (int t = 0; t < 10; t++) {
        double sum = bc;
        for (int k = 0; k < 8; k++) {
          final wck = wc[k];
          for (int m = -1; m <= 1; m++) {
            final pt = t + m;
            if (pt >= 0 && pt < 10) {
              sum += window[pt][k] * wck[m + 1];
            }
          }
        }
        h1[c][t] = sum > 0.0 ? sum : 0.0; // ReLU
      }
    }

    // Layer 2: MaxPool1D(2) -> length 5
    // h2 shape: 64 channels x 5 steps
    final h2 = List.generate(64, (_) => Float64List(5));
    for (int c = 0; c < 64; c++) {
      final ch1 = h1[c];
      for (int t = 0; t < 5; t++) {
        final a = ch1[2 * t];
        final b = ch1[2 * t + 1];
        h2[c][t] = a > b ? a : b;
      }
    }

    // Layer 3: LSTM (64 hidden units, 5 steps)
    final hState = Float64List(64);
    final cState = Float64List(64);

    for (int step = 0; step < 5; step++) {
      final preGates = Float64List(256);
      for (int g = 0; g < 256; g++) {
        double val = lstmBIh[g] + lstmBHh[g];
        final wIhRow = lstmWIh[g];
        final wHhRow = lstmWHh[g];
        for (int c = 0; c < 64; c++) {
          val += wIhRow[c] * h2[c][step] + wHhRow[c] * hState[c];
        }
        preGates[g] = val;
      }

      for (int j = 0; j < 64; j++) {
        final iGate = _sigmoid(preGates[j]);
        final fGate = _sigmoid(preGates[64 + j]);
        final gGate = _tanh(preGates[128 + j]);
        final oGate = _sigmoid(preGates[192 + j]);

        final newC = fGate * cState[j] + iGate * gGate;
        cState[j] = newC;
        hState[j] = oGate * _tanh(newC);
      }
    }

    // Layer 4: Dropout(0.2) is identity in inference.

    // Layer 5: Dense (64 -> 32, ReLU)
    final d = Float64List(32);
    for (int i = 0; i < 32; i++) {
      double sum = denseB[i];
      final wRow = denseW[i];
      for (int j = 0; j < 64; j++) {
        sum += wRow[j] * hState[j];
      }
      d[i] = sum > 0.0 ? sum : 0.0;
    }

    // Output: Dense (32 -> 1, Sigmoid)
    double logit = outB;
    for (int j = 0; j < 32; j++) {
      logit += outW[j] * d[j];
    }
    return _sigmoid(logit);
  }
}
