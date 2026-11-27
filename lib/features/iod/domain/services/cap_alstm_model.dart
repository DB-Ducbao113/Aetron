import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart inference engine for CAP-ALSTM:
/// Convolutional Atrous Spatial Pyramid Pooling Attention LSTM
/// (Bakirtzis et al., IEEE Internet of Things Journal 2022,
///  DOI: 10.1109/JIOT.2022.3190555).
///
/// Matches PyTorch `CapAlstmNet` forward pass for exact Python-Dart parity.
class CapAlstmModel {
  final int inFeatures;
  final int windowSize;
  final int numPools;
  final List<String> features;
  final List<double> clipHi;
  final List<double> scaleMin;
  final List<double> scaleRange;

  final double rawThreshold;
  final double hmmThreshold;
  final double pStayIn;
  final double pStayOut;

  // Block 1: Conv1D (inFeatures -> 32 -> 64)
  final List<List<List<double>>> conv1W;
  final List<double> conv1B;
  final List<List<List<double>>> conv2W;
  final List<double> conv2B;

  // Block 2: ASPP (r=1,2,3,4, each 64->64, k=3) + 1x1 fuse (256->32)
  final List<List<List<double>>> aspp1W;
  final List<double> aspp1B;
  final List<List<List<double>>> aspp2W;
  final List<double> aspp2B;
  final List<List<List<double>>> aspp3W;
  final List<double> aspp3B;
  final List<List<List<double>>> aspp4W;
  final List<double> aspp4B;
  final List<List<List<double>>> asppFuseW;
  final List<double> asppFuseB;

  // Block 3: LSTM1 (32->32) + Bahdanau Self-Attention + LSTM2Cell (32->32)
  final List<List<double>> lstm1WIh;
  final List<List<double>> lstm1WHh;
  final List<double> lstm1BIh;
  final List<double> lstm1BHh;
  final List<List<double>> attnWW;
  final List<double> attnWB;
  final List<List<double>> attnUW;
  final List<double> attnVW; // flattened (32,)
  final List<List<double>> lstm2WIh;
  final List<List<double>> lstm2WHh;
  final List<double> lstm2BIh;
  final List<double> lstm2BHh;

  // Block 4: MLP (32 -> 32 -> 1)
  final List<List<double>> dense1W;
  final List<double> dense1B;
  final List<double> outW;
  final double outB;

  CapAlstmModel({
    required this.inFeatures,
    required this.windowSize,
    required this.numPools,
    required this.features,
    required this.clipHi,
    required this.scaleMin,
    required this.scaleRange,
    required this.rawThreshold,
    required this.hmmThreshold,
    required this.pStayIn,
    required this.pStayOut,
    required this.conv1W,
    required this.conv1B,
    required this.conv2W,
    required this.conv2B,
    required this.aspp1W,
    required this.aspp1B,
    required this.aspp2W,
    required this.aspp2B,
    required this.aspp3W,
    required this.aspp3B,
    required this.aspp4W,
    required this.aspp4B,
    required this.asppFuseW,
    required this.asppFuseB,
    required this.lstm1WIh,
    required this.lstm1WHh,
    required this.lstm1BIh,
    required this.lstm1BHh,
    required this.attnWW,
    required this.attnWB,
    required this.attnUW,
    required this.attnVW,
    required this.lstm2WIh,
    required this.lstm2WHh,
    required this.lstm2BIh,
    required this.lstm2BHh,
    required this.dense1W,
    required this.dense1B,
    required this.outW,
    required this.outB,
  });

  factory CapAlstmModel.fromJson(Map<String, dynamic> json) {
    List<double> p1(dynamic d) =>
        (d as List).map((v) => (v as num).toDouble()).toList();
    List<List<double>> p2(dynamic d) =>
        (d as List).map((r) => p1(r)).toList();
    List<List<List<double>>> p3(dynamic d) =>
        (d as List).map((m) => p2(m)).toList();

    final scaler = json['scaler'] as Map<String, dynamic>;
    final tuning = json['validation_tuning'] as Map<String, dynamic>? ?? const {};
    final w = json['weights'] as Map<String, dynamic>;
    final attnVMat = p2(w['attn_v_w']);

    return CapAlstmModel(
      inFeatures: (json['in_features'] as num).toInt(),
      windowSize: (json['window_size'] as num).toInt(),
      numPools: (json['num_pools'] as num).toInt(),
      features: (scaler['features'] as List).map((e) => e.toString()).toList(),
      clipHi: p1(scaler['clip_hi']),
      scaleMin: p1(scaler['min']),
      scaleRange: p1(scaler['range']),
      rawThreshold: (tuning['raw_threshold'] as num?)?.toDouble() ?? 0.5,
      hmmThreshold: (tuning['threshold'] as num?)?.toDouble() ?? 0.5,
      pStayIn: (tuning['p_stay_in'] as num?)?.toDouble() ?? 0.98,
      pStayOut: (tuning['p_stay_out'] as num?)?.toDouble() ?? 0.98,
      conv1W: p3(w['conv1_w']),
      conv1B: p1(w['conv1_b']),
      conv2W: p3(w['conv2_w']),
      conv2B: p1(w['conv2_b']),
      aspp1W: p3(w['aspp1_w']),
      aspp1B: p1(w['aspp1_b']),
      aspp2W: p3(w['aspp2_w']),
      aspp2B: p1(w['aspp2_b']),
      aspp3W: p3(w['aspp3_w']),
      aspp3B: p1(w['aspp3_b']),
      aspp4W: p3(w['aspp4_w']),
      aspp4B: p1(w['aspp4_b']),
      asppFuseW: p3(w['aspp_fuse_w']),
      asppFuseB: p1(w['aspp_fuse_b']),
      lstm1WIh: p2(w['lstm1_w_ih']),
      lstm1WHh: p2(w['lstm1_w_hh']),
      lstm1BIh: p1(w['lstm1_b_ih']),
      lstm1BHh: p1(w['lstm1_b_hh']),
      attnWW: p2(w['attn_w_w']),
      attnWB: p1(w['attn_w_b']),
      attnUW: p2(w['attn_u_w']),
      attnVW: attnVMat.first,
      lstm2WIh: p2(w['lstm2_w_ih']),
      lstm2WHh: p2(w['lstm2_w_hh']),
      lstm2BIh: p1(w['lstm2_b_ih']),
      lstm2BHh: p1(w['lstm2_b_hh']),
      dense1W: p2(w['dense1_w']),
      dense1B: p1(w['dense1_b']),
      outW: p1(w['out_w']),
      outB: (w['out_b'] as num).toDouble(),
    );
  }

  /// Clips at training 99th percentile and scales into [0.0, 1.0].
  Float64List normalizeFrame(List<double> rawFrame) {
    final out = Float64List(inFeatures);
    for (int j = 0; j < inFeatures; j++) {
      var v = rawFrame[j];
      if (v > clipHi[j]) v = clipHi[j];
      v = (v - scaleMin[j]) / scaleRange[j];
      if (v < 0.0) {
        v = 0.0;
      } else if (v > 1.0) {
        v = 1.0;
      }
      out[j] = v;
    }
    return out;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final ep = math.exp(x);
    final em = math.exp(-x);
    return (ep - em) / (ep + em);
  }

  static List<Float64List> _conv1dRelu(
    List<Float64List> input,
    List<List<List<double>>> weight,
    List<double> bias, {
    int dilation = 1,
  }) {
    final outCh = weight.length;
    final inCh = input.length;
    final seqLen = input[0].length;
    final kSize = weight[0][0].length;
    final halfK = kSize ~/ 2;

    final out = List<Float64List>.generate(outCh, (_) => Float64List(seqLen));
    for (int c = 0; c < outCh; c++) {
      final bc = bias[c];
      final wc = weight[c];
      final oc = out[c];
      for (int t = 0; t < seqLen; t++) {
        double sum = bc;
        for (int ic = 0; ic < inCh; ic++) {
          final wci = wc[ic];
          final inp = input[ic];
          for (int k = 0; k < kSize; k++) {
            final pt = t + (k - halfK) * dilation;
            if (pt >= 0 && pt < seqLen) {
              sum += inp[pt] * wci[k];
            }
          }
        }
        oc[t] = sum > 0.0 ? sum : 0.0;
      }
    }
    return out;
  }

  static List<Float64List> _maxPool1d2(List<Float64List> input) {
    final ch = input.length;
    final outLen = input[0].length ~/ 2;
    final out = List<Float64List>.generate(ch, (_) => Float64List(outLen));
    for (int c = 0; c < ch; c++) {
      final inp = input[c];
      final oc = out[c];
      for (int t = 0; t < outLen; t++) {
        final a = inp[2 * t];
        final b = inp[2 * t + 1];
        oc[t] = a > b ? a : b;
      }
    }
    return out;
  }

  static void _lstmStep(
    Float64List x,
    Float64List hState,
    Float64List cState,
    List<List<double>> wIh,
    List<List<double>> wHh,
    List<double> bIh,
    List<double> bHh,
  ) {
    final hidden = hState.length;
    final inDim = x.length;
    final gates = Float64List(4 * hidden);
    for (int g = 0; g < 4 * hidden; g++) {
      double v = bIh[g] + bHh[g];
      final wi = wIh[g];
      final wh = wHh[g];
      for (int j = 0; j < inDim; j++) {
        v += wi[j] * x[j];
      }
      for (int j = 0; j < hidden; j++) {
        v += wh[j] * hState[j];
      }
      gates[g] = v;
    }
    for (int j = 0; j < hidden; j++) {
      final iG = _sigmoid(gates[j]);
      final fG = _sigmoid(gates[hidden + j]);
      final gG = _tanh(gates[2 * hidden + j]);
      final oG = _sigmoid(gates[3 * hidden + j]);
      final newC = fG * cState[j] + iG * gG;
      cState[j] = newC;
      hState[j] = oG * _tanh(newC);
    }
  }

  /// Evaluates a normalized [windowSize] x [inFeatures] window and returns raw logit.
  double predictLogit(List<List<double>> normalizedWindow) {
    assert(normalizedWindow.length == windowSize);
    assert(normalizedWindow[0].length == inFeatures);

    // Transpose (W, M) -> (M, W)
    final xCh = List<Float64List>.generate(inFeatures, (m) {
      final row = Float64List(windowSize);
      for (int t = 0; t < windowSize; t++) {
        row[t] = normalizedWindow[t][m];
      }
      return row;
    });

    // Block 1
    var h = _conv1dRelu(xCh, conv1W, conv1B, dilation: 1);
    if (numPools >= 1) h = _maxPool1d2(h);
    h = _conv1dRelu(h, conv2W, conv2B, dilation: 1);
    if (numPools >= 2) h = _maxPool1d2(h);

    // Block 2: ASPP
    final a1 = _conv1dRelu(h, aspp1W, aspp1B, dilation: 1);
    final a2 = _conv1dRelu(h, aspp2W, aspp2B, dilation: 2);
    final a3 = _conv1dRelu(h, aspp3W, aspp3B, dilation: 3);
    final a4 = _conv1dRelu(h, aspp4W, aspp4B, dilation: 4);
    final concat = <Float64List>[...a1, ...a2, ...a3, ...a4];
    final seqCh = _conv1dRelu(concat, asppFuseW, asppFuseB, dilation: 1); // (32, T)

    final seqLen = seqCh[0].length;
    // Block 3a: LSTM1
    final hEnc = List<Float64List>.generate(seqLen, (_) => Float64List(32));
    final h1 = Float64List(32);
    final c1 = Float64List(32);
    final stepIn = Float64List(32);
    for (int t = 0; t < seqLen; t++) {
      for (int k = 0; k < 32; k++) {
        stepIn[k] = seqCh[k][t];
      }
      _lstmStep(stepIn, h1, c1, lstm1WIh, lstm1WHh, lstm1BIh, lstm1BHh);
      hEnc[t].setAll(0, h1);
    }

    // Precompute U_a * hEnc[t]
    final uh = List<Float64List>.generate(seqLen, (t) {
      final row = Float64List(32);
      final ht = hEnc[t];
      for (int k = 0; k < 32; k++) {
        final uw = attnUW[k];
        double s = 0.0;
        for (int j = 0; j < 32; j++) {
          s += uw[j] * ht[j];
        }
        row[k] = s;
      }
      return row;
    });

    // Block 3b: LSTM2Cell with Bahdanau Self-Attention
    final hDec = Float64List(32);
    final cDec = Float64List(32);
    final wh = Float64List(32);
    final scores = Float64List(seqLen);
    final context = Float64List(32);

    for (int step = 0; step < seqLen; step++) {
      for (int k = 0; k < 32; k++) {
        double s = attnWB[k];
        final ww = attnWW[k];
        for (int j = 0; j < 32; j++) {
          s += ww[j] * hDec[j];
        }
        wh[k] = s;
      }

      double maxScore = -double.infinity;
      for (int t = 0; t < seqLen; t++) {
        final uht = uh[t];
        double sc = 0.0;
        for (int k = 0; k < 32; k++) {
          sc += attnVW[k] * _tanh(wh[k] + uht[k]);
        }
        scores[t] = sc;
        if (sc > maxScore) maxScore = sc;
      }

      double expSum = 0.0;
      for (int t = 0; t < seqLen; t++) {
        final e = math.exp(scores[t] - maxScore);
        scores[t] = e;
        expSum += e;
      }

      context.fillRange(0, 32, 0.0);
      for (int t = 0; t < seqLen; t++) {
        final a = scores[t] / expSum;
        final ht = hEnc[t];
        for (int j = 0; j < 32; j++) {
          context[j] += a * ht[j];
        }
      }

      _lstmStep(context, hDec, cDec, lstm2WIh, lstm2WHh, lstm2BIh, lstm2BHh);
    }

    // Block 4: MLP
    final d1 = Float64List(32);
    for (int i = 0; i < 32; i++) {
      double s = dense1B[i];
      final wRow = dense1W[i];
      for (int j = 0; j < 32; j++) {
        s += wRow[j] * hDec[j];
      }
      d1[i] = s > 0.0 ? s : 0.0;
    }

    double logit = outB;
    for (int j = 0; j < 32; j++) {
      logit += outW[j] * d1[j];
    }
    return logit;
  }

  /// Returns P(Outdoor) in [0.0, 1.0].
  double predict(List<List<double>> normalizedWindow) =>
      _sigmoid(predictLogit(normalizedWindow));
}
