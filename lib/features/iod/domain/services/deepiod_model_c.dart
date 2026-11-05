import 'dart:math' as math;
import 'dart:typed_data';

/// Depth-Wise Separable 2D CNN (Model C from PMC11360063 Table 1).
///
/// Implements exact forward pass matching the trained PyTorch Model C checkpoint:
/// Input: 2D temporal window (10 time steps x 8 sensor channels).
/// - Layer 1: DWS-Conv2D (3x3, padding 1, ReLU)
/// - Layer 2: Pointwise Conv2D (32, 1x1, folded BN, ReLU)
/// - Layer 3: DWS-Conv2D (3x3, 32 channels, groups 32, padding 1, ReLU)
/// - Layer 4: Pointwise Conv2D (32, 1x1, in_ch 32, folded BN, ReLU)
/// - Layer 5: MaxPool2D (2x1) -> (32 x 5 x 8)
/// - Global Average Pooling over (5 x 8 = 40) -> 32
/// - Dense (32 -> 32, ReLU)
/// - Output Dense (32 -> 1, Sigmoid)
class DeepIodModelC {
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

  DeepIodModelC({
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

  factory DeepIodModelC.fromJson(Map<String, dynamic> json) {
    List<List<double>> parse2d(dynamic data) =>
        (data as List).map((row) => (row as List).map((v) => (v as num).toDouble()).toList()).toList();

    List<double> parse1d(dynamic data) =>
        (data as List).map((v) => (v as num).toDouble()).toList();

    List<List<List<double>>> parse3d(dynamic data) =>
        (data as List).map((ch) => parse2d(ch)).toList();

    return DeepIodModelC(
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

  /// Evaluates a 10x8 normalized temporal window and returns P(Outdoor) in [0.0, 1.0].
  double predict(List<List<double>> window) {
    assert(window.length == 10 && window[0].length == 8, 'Window must be 10x8');

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
