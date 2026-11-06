import 'dart:math' as math;
import 'dart:typed_data';

/// 1D-CNN + Multi-Head Self-Attention (Model B from DeepIOD PMC11360063 Table 1).
///
/// Implements exact forward pass matching the trained PyTorch Model B checkpoint:
/// Input: 10 temporal steps x 8 sensor channels.
/// - Layer 1: Conv1D (in_ch=8, out_ch=64, k=3, pad=1, ReLU)
/// - Layer 2: LayerNorm (64) + Multi-Head Attention (8 heads, embed_dim=64, d_k=8)
/// - Layer 3: MaxPool1D (2) -> length 5
/// - Layer 4: Global Average Pooling (5 -> 1) -> 64
/// - Layer 5: Dense (64 -> 32, ReLU)
/// - Output: Dense (32 -> 1, Sigmoid)
class DeepIodModelB {
  final List<List<List<double>>> convW; // (64, 8, 3)
  final List<double> convB; // (64,)
  final List<double> lnW; // (64,)
  final List<double> lnB; // (64,)
  final List<List<double>> mhaInProjW; // (192, 64)
  final List<double> mhaInProjB; // (192,)
  final List<List<double>> mhaOutProjW; // (64, 64)
  final List<double> mhaOutProjB; // (64,)
  final List<List<double>> denseW; // (32, 64)
  final List<double> denseB; // (32,)
  final List<double> outW; // (32,)
  final double outB;
  final List<double> mean;
  final List<double> std;

  DeepIodModelB({
    required this.convW,
    required this.convB,
    required this.lnW,
    required this.lnB,
    required this.mhaInProjW,
    required this.mhaInProjB,
    required this.mhaOutProjW,
    required this.mhaOutProjB,
    required this.denseW,
    required this.denseB,
    required this.outW,
    required this.outB,
    required this.mean,
    required this.std,
  });

  factory DeepIodModelB.fromJson(Map<String, dynamic> json) {
    List<double> parse1d(dynamic data) =>
        (data as List).map((v) => (v as num).toDouble()).toList();

    List<List<double>> parse2d(dynamic data) =>
        (data as List).map((row) => parse1d(row)).toList();

    List<List<List<double>>> parse3d(dynamic data) =>
        (data as List).map((plane) => parse2d(plane)).toList();

    return DeepIodModelB(
      convW: parse3d(json['conv_w']),
      convB: parse1d(json['conv_b']),
      lnW: parse1d(json['ln_w']),
      lnB: parse1d(json['ln_b']),
      mhaInProjW: parse2d(json['mha_in_proj_w']),
      mhaInProjB: parse1d(json['mha_in_proj_b']),
      mhaOutProjW: parse2d(json['mha_out_proj_w']),
      mhaOutProjB: parse1d(json['mha_out_proj_b']),
      denseW: parse2d(json['dense_w']),
      denseB: parse1d(json['dense_b']),
      outW: parse1d(json['out_w']),
      outB: (json['out_b'] as num).toDouble(),
      mean: parse1d(json['mean']),
      std: parse1d(json['std']),
    );
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  /// Evaluates a 10x8 normalized temporal window and returns P(Outdoor) in [0.0, 1.0].
  double predict(List<List<double>> window) {
    assert(window.length == 10, 'Window must have 10 temporal steps');
    final inCh = window[0].length;
    assert(inCh == 8, 'Model B requires 8 sensor features');

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

    // Transpose to seq: (10, 64)
    final seq = List.generate(10, (t) {
      final row = Float64List(64);
      for (int c = 0; c < 64; c++) {
        row[c] = h1[c][t];
      }
      return row;
    });

    // Layer 2: LayerNorm (64)
    final normSeq = List.generate(10, (t) {
      final row = seq[t];
      double sum = 0.0;
      for (int c = 0; c < 64; c++) {
        sum += row[c];
      }
      final mean = sum / 64.0;
      double varSum = 0.0;
      for (int c = 0; c < 64; c++) {
        final diff = row[c] - mean;
        varSum += diff * diff;
      }
      final invStd = 1.0 / math.sqrt((varSum / 64.0) + 1e-5);
      final normed = Float64List(64);
      for (int c = 0; c < 64; c++) {
        normed[c] = (row[c] - mean) * invStd * lnW[c] + lnB[c];
      }
      return normed;
    });

    // Multi-Head Attention (8 heads, 64 dim, d_k=8)
    final q = List.generate(10, (_) => Float64List(64));
    final k = List.generate(10, (_) => Float64List(64));
    final v = List.generate(10, (_) => Float64List(64));

    for (int t = 0; t < 10; t++) {
      final xRow = normSeq[t];
      for (int c = 0; c < 64; c++) {
        double qVal = mhaInProjB[c];
        double kVal = mhaInProjB[64 + c];
        double vVal = mhaInProjB[128 + c];
        final wQRow = mhaInProjW[c];
        final wKRow = mhaInProjW[64 + c];
        final wVRow = mhaInProjW[128 + c];
        for (int j = 0; j < 64; j++) {
          final xj = xRow[j];
          qVal += wQRow[j] * xj;
          kVal += wKRow[j] * xj;
          vVal += wVRow[j] * xj;
        }
        q[t][c] = qVal;
        k[t][c] = kVal;
        v[t][c] = vVal;
      }
    }

    // Scaled dot-product attention per head
    final mhaConcat = List.generate(10, (_) => Float64List(64));
    final double scale = 1.0 / math.sqrt(8.0);

    for (int h = 0; h < 8; h++) {
      final hOffset = h * 8;
      // Compute scores (10 x 10)
      for (int ti = 0; ti < 10; ti++) {
        final scores = Float64List(10);
        double maxScore = -double.infinity;
        for (int tj = 0; tj < 10; tj++) {
          double dot = 0.0;
          for (int d = 0; d < 8; d++) {
            dot += q[ti][hOffset + d] * k[tj][hOffset + d];
          }
          final s = dot * scale;
          scores[tj] = s;
          if (s > maxScore) maxScore = s;
        }

        // Softmax across tj
        double expSum = 0.0;
        final attn = Float64List(10);
        for (int tj = 0; tj < 10; tj++) {
          final e = math.exp(scores[tj] - maxScore);
          attn[tj] = e;
          expSum += e;
        }
        for (int tj = 0; tj < 10; tj++) {
          attn[tj] /= expSum;
        }

        // Output head projection: attn @ V_h
        for (int d = 0; d < 8; d++) {
          double val = 0.0;
          for (int tj = 0; tj < 10; tj++) {
            val += attn[tj] * v[tj][hOffset + d];
          }
          mhaConcat[ti][hOffset + d] = val;
        }
      }
    }

    // Output projection: mhaConcat @ mhaOutProjW^T + mhaOutProjB
    final attnOut = List.generate(10, (t) {
      final row = Float64List(64);
      final cRow = mhaConcat[t];
      for (int c = 0; c < 64; c++) {
        double val = mhaOutProjB[c];
        final wRow = mhaOutProjW[c];
        for (int j = 0; j < 64; j++) {
          val += wRow[j] * cRow[j];
        }
        row[c] = val;
      }
      return row;
    });

    // Layer 3: MaxPool1D(2) -> pools across time (10 -> 5)
    final h3 = List.generate(64, (_) => Float64List(5));
    for (int c = 0; c < 64; c++) {
      for (int t = 0; t < 5; t++) {
        final a = attnOut[2 * t][c];
        final b = attnOut[2 * t + 1][c];
        h3[c][t] = a > b ? a : b;
      }
    }

    // Layer 4: Global Average Pooling across length 5 -> (64,)
    final gap = Float64List(64);
    for (int c = 0; c < 64; c++) {
      double sum = 0.0;
      for (int t = 0; t < 5; t++) {
        sum += h3[c][t];
      }
      gap[c] = sum / 5.0;
    }

    // Layer 5: Dense (64 -> 32, ReLU)
    final d = Float64List(32);
    for (int i = 0; i < 32; i++) {
      double sum = denseB[i];
      final wRow = denseW[i];
      for (int j = 0; j < 64; j++) {
        sum += wRow[j] * gap[j];
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
