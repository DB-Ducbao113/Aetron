import 'dart:collection';
import 'dart:math' as math;

import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';

enum IosIodEvaluationMode {
  /// Pure MagIO Magnetometer Gaussian Naive Bayes + Causal HMM
  /// (Ashraf et al. 2018, DOI: 10.3390/mi9100534 + Zhu et al. 2019, DOI: 10.3390/s19040786).
  magIoOnly,

  /// Frozen CIOD-trained [MagIO + Acc + Daytime] MLP + Causal HMM
  /// (Ashraf 2018 + Esmaeili Kelishomi 2019, DOI: 10.3390/s19030511 + Zhu 2019).
  /// Evaluated on Cambridge CIOD Held-Out Sessions 72..84 (N = 201,731):
  /// Raw Acc = 77.07%, Macro-F1 = 74.97%; HMM Acc = 75.65%, Macro-F1 = 74.77%.
  ciodSensorOnly,

  /// Production iOS Multi-Sensor Fusion combining CIOD-calibrated [MagIO + Acc + Daytime]
  /// with CoreLocation GPS accuracy/speed/outage (Bui et al. 2020, DOI: 10.3390/app10020500),
  /// CMAltimeter floor pressure shifts (Esmaeili Kelishomi et al. 2019), and
  /// IODetector confidence-weighted Causal HMM (Li et al. 2014, DOI: 10.1145/2659466).
  liveMultiSensorFusion,
}

/// Cross-platform / iOS-first Indoor–Outdoor Classifier requiring zero privileged
/// Android-only APIs (no ambient light photodiode, no raw GNSS C/N0, no Wi-Fi scan).
///
/// Grounded in peer-reviewed smartphone sensing literature:
/// 1. Ashraf, Hur & Park (2018), "MagIO: Magnetic Field Strength Based Indoor-Outdoor
///    Detection with a Commercial Smartphone", Micromachines 9(10), 534, DOI: 10.3390/mi9100534.
/// 2. Esmaeili Kelishomi et al. (2019), "Mobile User Indoor-Outdoor Detection through
///    Physical Daily Activities", Sensors 19(3), 511, DOI: 10.3390/s19030511.
/// 3. Bui et al. (2020), "GPS-Based Indoor/Outdoor Detection Scheme Using Machine Learning
///    Techniques", Applied Sciences 10(2), 500, DOI: 10.3390/app10020500.
/// 4. Zhou et al. (2012) / Li et al. (2014), "IODetector: A Generic Service for
///    Indoor/Outdoor Detection", ACM Trans. Sensor Networks 11(2), 28, DOI: 10.1145/2659466.
/// 5. Zhu et al. (2019), "A Fast Indoor/Outdoor Transition Detection Algorithm Based on
///    Machine Learning", Sensors 19(4), 786, DOI: 10.3390/s19040786.
class IosMultiSensorIodClassifier {
  static const String magIoModelVersion = 'magio-gnb-hmm-ciod-v1.0';
  static const String ciodIosModelVersion = 'ios-magio-imu-ciod-v1.0';
  static const String liveFusionModelVersion = 'aetron-ios-magio-hmm-v1.0';
  static const int windowSize = 10;
  static const int minLiveWarmupEpochs = 5;

  final IosIodEvaluationMode mode;

  final Queue<double> _magWindow = Queue<double>();
  final Queue<double> _accWindow = Queue<double>();
  DateTime? _lastTimestamp;

  // Causal 2-state HMM posterior belief: P(State = Outdoor | o_{1:t})
  double _alphaIndoor = 0.5;
  double _alphaOutdoor = 0.5;

  IosMultiSensorIodClassifier({
    this.mode = IosIodEvaluationMode.liveMultiSensorFusion,
  });

  String get activeModelVersion => switch (mode) {
    IosIodEvaluationMode.magIoOnly => magIoModelVersion,
    IosIodEvaluationMode.ciodSensorOnly => ciodIosModelVersion,
    IosIodEvaluationMode.liveMultiSensorFusion => liveFusionModelVersion,
  };

  int get bufferedEpochs => _magWindow.length;

  void reset() {
    _magWindow.clear();
    _accWindow.clear();
    _lastTimestamp = null;
    _alphaIndoor = 0.5;
    _alphaOutdoor = 0.5;
  }

  IodPrediction classify(IodSensorSnapshot snapshot) {
    final sw = Stopwatch()..start();

    final hasMag =
        snapshot.hasImuData &&
        (snapshot.magneticMagnitudeMean?.isFinite ?? false) &&
        snapshot.magneticMagnitudeMean! >= 0.0;
    final hasAcc =
        snapshot.hasImuData &&
        (snapshot.accelMagnitudeMean?.isFinite ?? false) &&
        snapshot.accelMagnitudeMean! >= 0.0;
    final hasGps =
        snapshot.hasGpsFix &&
        (snapshot.horizontalAccuracy?.isFinite ?? false) &&
        snapshot.horizontalAccuracy! > 0.0;
    final hasBaro =
        snapshot.hasBarometer && (snapshot.pressureHpa?.isFinite ?? false);

    final availability = <String, bool>{
      'light': snapshot.hasLightSensor,
      'mag': hasMag,
      'acc': hasAcc,
      'daytime': true,
      'gps': hasGps,
      'barometer': hasBaro,
      'gnss_status': snapshot.hasGnssStatus,
    };

    final prevTs = _lastTimestamp;
    if (prevTs != null) {
      final gap = snapshot.timestamp.difference(prevTs);
      if (gap <= Duration.zero || gap > const Duration(seconds: 3)) {
        _magWindow.clear();
        _accWindow.clear();
      }
    }
    _lastTimestamp = snapshot.timestamp;

    if (hasMag) {
      _magWindow.addLast(snapshot.magneticMagnitudeMean!);
      while (_magWindow.length > windowSize) {
        _magWindow.removeFirst();
      }
    }
    if (hasAcc) {
      _accWindow.addLast(snapshot.accelMagnitudeMean!);
      while (_accWindow.length > windowSize) {
        _accWindow.removeFirst();
      }
    }

    if (mode == IosIodEvaluationMode.magIoOnly) {
      if (!hasMag || _magWindow.isEmpty) {
        sw.stop();
        return IodPrediction.unknown(
          reason: 'magio_missing_magnetometer',
          modelVersion: activeModelVersion,
          latencyMs: sw.elapsedMilliseconds,
          sensorAvailability: availability,
        );
      }
      final magFeats = _extractMagIoFeatures(_magWindow.toList());
      final pRaw = _predictMagIoGnbOutdoorProb(magFeats);
      // Calibrated around validation threshold 0.200 (CIOD Val 60..71)
      final pCalibrated = _piecewiseCalibrate(pRaw, _kMagIoValThreshold);
      final pPost = _stepHmm(pCalibrated, fastTransition: false);
      final state = pPost >= 0.5
          ? IndoorOutdoorState.outdoor
          : IndoorOutdoorState.indoor;
      final conf = (pPost - 0.5).abs() * 2.0;
      sw.stop();
      return IodPrediction(
        state: state,
        confidence: conf.clamp(0.0, 1.0),
        deepIodOutdoorProbability: pPost,
        nativeClass: 'magio_gnb_hmm:${state.code}',
        modelVersion: activeModelVersion,
        inferenceLatencyMs: sw.elapsedMilliseconds,
        sensorAvailability: availability,
        reasoningSummary:
            'MagIO (Ashraf 2018) GNB+HMM P(Out)=${(pPost * 100).toStringAsFixed(1)}%',
        isObservationalOnly: true,
      );
    }

    if (mode == IosIodEvaluationMode.ciodSensorOnly) {
      if (!hasMag || !hasAcc) {
        sw.stop();
        return IodPrediction.unknown(
          reason: 'ios_ciod_missing_imu',
          modelVersion: activeModelVersion,
          latencyMs: sw.elapsedMilliseconds,
          sensorAvailability: availability,
        );
      }
      final daytime = snapshot.isNightTime ? 0.0 : 1.0;
      final pRaw = _predictIosMlpOutdoorProb(
        _magWindow.toList(),
        _accWindow.toList(),
        daytime,
      );
      final pPost = _stepHmm(pRaw, fastTransition: false);
      final isOutdoor = pPost >= _kIosMlpValThreshold;
      final state = isOutdoor
          ? IndoorOutdoorState.outdoor
          : IndoorOutdoorState.indoor;
      final conf = isOutdoor
          ? ((pPost - _kIosMlpValThreshold) / (1.0 - _kIosMlpValThreshold))
          : ((_kIosMlpValThreshold - pPost) / _kIosMlpValThreshold);
      sw.stop();
      return IodPrediction(
        state: state,
        confidence: conf.clamp(0.0, 1.0),
        deepIodOutdoorProbability: isOutdoor
            ? (0.5 + 0.5 * conf.clamp(0.0, 1.0))
            : (0.5 - 0.5 * conf.clamp(0.0, 1.0)),
        nativeClass: 'ios_ciod_mlp_hmm:${state.code}',
        modelVersion: activeModelVersion,
        inferenceLatencyMs: sw.elapsedMilliseconds,
        sensorAvailability: availability,
        reasoningSummary:
            'iOS CIOD [MagIO+Acc+Daytime] MLP+HMM P(Out)=${(pPost * 100).toStringAsFixed(1)}%',
        isObservationalOnly: true,
      );
    }

    // Live Multi-Sensor Fusion Mode (iPhone / Android fallback without Light sensor)
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    final cues = <String>[];

    // 1. Calibrated [MagIO + Acc + Daytime] emission (Ashraf 2018 + Kelishomi 2019)
    if (hasMag && hasAcc && _magWindow.isNotEmpty && _accWindow.isNotEmpty) {
      final daytime = snapshot.isNightTime ? 0.0 : 1.0;
      final pRaw = _predictIosMlpOutdoorProb(
        _magWindow.toList(),
        _accWindow.toList(),
        daytime,
      );
      final pImuCal = _piecewiseCalibrate(pRaw, _kIosMlpValThreshold);
      final warmupScale = (_magWindow.length / windowSize).clamp(0.3, 1.0);
      final wImu = 0.45 * warmupScale;
      weightedSum += wImu * pImuCal;
      totalWeight += wImu;
      cues.add('MagIMU=${(pImuCal * 100).toStringAsFixed(0)}%');
    } else if (hasMag && _magWindow.isNotEmpty) {
      final magFeats = _extractMagIoFeatures(_magWindow.toList());
      final pMagCal = _piecewiseCalibrate(
        _predictMagIoGnbOutdoorProb(magFeats),
        _kMagIoValThreshold,
      );
      weightedSum += 0.35 * pMagCal;
      totalWeight += 0.35;
      cues.add('MagIO=${(pMagCal * 100).toStringAsFixed(0)}%');
    }

    // 2. CoreLocation / OS GPS Signal & Kinematic Consistency Cue (Bui et al. 2020)
    bool unambiguousGpsSignal = false;
    if (hasGps) {
      final acc = snapshot.horizontalAccuracy!;
      final spd = snapshot.speed ?? 0.0;
      if (acc <= 12.0) {
        final pGps = spd >= 0.7 ? 0.94 : 0.88;
        weightedSum += 0.55 * pGps;
        totalWeight += 0.55;
        unambiguousGpsSignal = true;
        cues.add('GPS(acc=${acc.toStringAsFixed(1)}m,Out)');
      } else if (acc <= 25.0) {
        weightedSum += 0.35 * 0.68;
        totalWeight += 0.35;
        cues.add('GPS(acc=${acc.toStringAsFixed(1)}m,Mod)');
      } else if (acc < 42.0) {
        // Urban-canyon / doorway ambiguity zone: light weight so MagIO + HMM arbitrate
        weightedSum += 0.20 * 0.42;
        totalWeight += 0.20;
        cues.add('GPS(acc=${acc.toStringAsFixed(1)}m,Canyon)');
      } else {
        // Severe indoor attenuation (acc >= 42m)
        final movingIndoors = snapshot.stepDelta > 0 && spd < 0.5;
        final pGps = movingIndoors ? 0.06 : 0.14;
        weightedSum += 0.55 * pGps;
        totalWeight += 0.55;
        unambiguousGpsSignal = movingIndoors;
        cues.add('GPS(acc=${acc.toStringAsFixed(1)}m,In)');
      }
    } else if ((snapshot.gpsFixAgeSeconds ?? 0) >= 8 && snapshot.stepDelta > 0) {
      // Sustained GPS blackout while user is actively stepping on pedometer
      weightedSum += 0.55 * 0.08;
      totalWeight += 0.55;
      unambiguousGpsSignal = true;
      cues.add('GPS(blackout=${snapshot.gpsFixAgeSeconds}s+steps)');
    }

    // 3. Barometric Altimeter Multi-Floor Transition Cue (CMAltimeter, Kelishomi 2019)
    if (hasBaro && snapshot.pressureDelta10sHpa != null) {
      final absDeltaP = snapshot.pressureDelta10sHpa!.abs();
      // >= 0.35 hPa over 10s corresponds to ~3.0m vertical floor/stair/elevator shift
      if (absDeltaP >= 0.35 && snapshot.isGpsWeak) {
        weightedSum += 0.30 * 0.10;
        totalWeight += 0.30;
        cues.add('Baro(dP=${snapshot.pressureDelta10sHpa!.toStringAsFixed(2)}hPa)');
      }
    }

    if (totalWeight <= 0.0) {
      sw.stop();
      return IodPrediction.unknown(
        reason: 'ios_no_sensors_available',
        modelVersion: activeModelVersion,
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    final emissionOutdoor = (weightedSum / totalWeight).clamp(0.02, 0.98);
    final pPostOutdoor = _stepHmm(
      emissionOutdoor,
      fastTransition: unambiguousGpsSignal,
    );
    final state = pPostOutdoor >= 0.5
        ? IndoorOutdoorState.outdoor
        : IndoorOutdoorState.indoor;
    final confidence = ((pPostOutdoor - 0.5).abs() * 2.0).clamp(0.0, 1.0);

    sw.stop();
    return IodPrediction(
      state: state,
      confidence: confidence,
      deepIodOutdoorProbability: pPostOutdoor,
      nativeClass: 'ios_magio_hmm:${state.code}',
      modelVersion: activeModelVersion,
      inferenceLatencyMs: sw.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary:
          'iOS MultiSensor+HMM [${state.code.toUpperCase()} ${(pPostOutdoor * 100).toStringAsFixed(1)}%] '
          '${cues.join(" | ")}',
      isObservationalOnly: true,
    );
  }

  double _piecewiseCalibrate(double rawProb, double threshold) {
    final p = rawProb.clamp(0.0, 1.0);
    if (p >= threshold) {
      return 0.5 + 0.5 * ((p - threshold) / (1.0 - threshold));
    }
    return 0.5 * (p / threshold);
  }

  double _stepHmm(double emissionOutdoor, {required bool fastTransition}) {
    final bOut = emissionOutdoor.clamp(0.02, 0.98);
    final bIn = 1.0 - bOut;

    // Asymmetric persistence (Zhu et al. 2019, Sensors 19(4), 786):
    // Higher persistence against brief multipath dips; faster 3-4s handover on strong cues.
    final pStayOut = fastTransition ? 0.930 : 0.985;
    final pStayIn = fastTransition ? 0.920 : 0.980;

    final predIn = _alphaIndoor * pStayIn + _alphaOutdoor * (1.0 - pStayOut);
    final predOut = _alphaIndoor * (1.0 - pStayIn) + _alphaOutdoor * pStayOut;

    _alphaIndoor = predIn * bIn;
    _alphaOutdoor = predOut * bOut;
    final norm = _alphaIndoor + _alphaOutdoor;
    if (norm > 0) {
      _alphaIndoor /= norm;
      _alphaOutdoor /= norm;
    } else {
      _alphaIndoor = 0.5;
      _alphaOutdoor = 0.5;
    }
    return _alphaOutdoor;
  }

  static List<double> _extractMagIoFeatures(List<double> mag) {
    final n = mag.length;
    double sum = 0.0;
    double mn = mag.first;
    double mx = mag.first;
    double diffSum = 0.0;
    for (int i = 0; i < n; i++) {
      final v = mag[i];
      sum += v;
      if (v < mn) mn = v;
      if (v > mx) mx = v;
      if (i > 0) diffSum += (v - mag[i - 1]).abs();
    }
    final mu = sum / n;
    double sqSum = 0.0;
    for (final v in mag) {
      final d = v - mu;
      sqSum += d * d;
    }
    final variance = sqSum / n;
    final sd = math.sqrt(variance);

    final sorted = List<double>.from(mag)..sort();
    final med = _percentileSorted(sorted, 0.50);
    final iqr = n >= 4
        ? (_percentileSorted(sorted, 0.75) - _percentileSorted(sorted, 0.25))
        : (2.0 * sd);
    final rng = mx - mn;
    final cv = sd / math.max(mu.abs(), 1e-3);
    final madStep = n >= 2 ? diffSum / (n - 1) : 0.0;

    return <double>[
      mu,
      sd,
      math.log(1.0 + variance),
      med,
      iqr,
      mn,
      mx,
      rng,
      cv,
      madStep,
    ];
  }

  static double _percentileSorted(List<double> sorted, double q) {
    if (sorted.length == 1) return sorted.first;
    final pos = q * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    final frac = pos - lo;
    return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
  }

  static double _predictMagIoGnbOutdoorProb(List<double> x) {
    double llIn = 0.0;
    double llOut = 0.0;
    for (int i = 0; i < 10; i++) {
      final vIn = _kMagIoVarsIndoor[i];
      final dIn = x[i] - _kMagIoMeansIndoor[i];
      llIn += -0.5 * (math.log(2.0 * math.pi * vIn) + (dIn * dIn) / vIn);

      final vOut = _kMagIoVarsOutdoor[i];
      final dOut = x[i] - _kMagIoMeansOutdoor[i];
      llOut += -0.5 * (math.log(2.0 * math.pi * vOut) + (dOut * dOut) / vOut);
    }
    final diff = (llOut - llIn).clamp(-50.0, 50.0);
    return 1.0 / (1.0 + math.exp(-diff));
  }

  static double _predictIosMlpOutdoorProb(
    List<double> mag,
    List<double> acc,
    double daytime,
  ) {
    final magF = _extractMagIoFeatures(mag);
    final na = acc.length;
    double sumA = 0.0;
    double mxA = acc.first;
    double diffA = 0.0;
    for (int i = 0; i < na; i++) {
      final v = acc[i];
      sumA += v;
      if (v > mxA) mxA = v;
      if (i > 0) diffA += (v - acc[i - 1]).abs();
    }
    final muA = sumA / na;
    double sqA = 0.0;
    for (final v in acc) {
      final d = v - muA;
      sqA += d * d;
    }
    final sdA = math.sqrt(sqA / na);
    final stepDiffA = na >= 2 ? diffA / (na - 1) : 0.0;

    final x = <double>[...magF, muA, sdA, mxA, stepDiffA, daytime];
    final xNorm = List<double>.filled(15, 0.0);
    for (int i = 0; i < 15; i++) {
      xNorm[i] = (x[i] - _kIosMlpMu[i]) / _kIosMlpSd[i];
    }

    double logit = _kIosMlpB2;
    for (int j = 0; j < 24; j++) {
      double h = _kIosMlpB1[j];
      for (int i = 0; i < 15; i++) {
        h += xNorm[i] * _kIosMlpW1[i][j];
      }
      if (h > 0.0) {
        logit += h * _kIosMlpW2[j];
      }
    }
    final clamped = logit.clamp(-30.0, 30.0);
    return 1.0 / (1.0 + math.exp(-clamped));
  }

  // ---------------------------------------------------------------------------
  // Frozen Parameters Trained Strictly on Cambridge CIOD Sessions 00..59
  // Validation Thresholds Selected on Sessions 60..71 (Zero Held-Out Leakage)
  // ---------------------------------------------------------------------------
  static const double _kMagIoValThreshold = 0.200;
  static const double _kIosMlpValThreshold = 0.700;

  static const List<double> _kMagIoMeansIndoor = [
    44.693781001120804,
    0.8673817049974258,
    0.45873708006314373,
    44.68443911351318,
    1.081321885873273,
    43.32785527253888,
    46.09606774513723,
    2.7682124725992527,
    0.02102100626510183,
    0.79831559205375,
  ];

  static const List<double> _kMagIoVarsIndoor = [
    474.08907407455985,
    4.2341560137449195,
    0.5392747721138997,
    476.9980061712896,
    8.880502019214498,
    471.1271158524959,
    490.52243492009575,
    33.004484081540376,
    0.0015739007667818579,
    1.0748819797196527,
  ];

  static const List<double> _kMagIoMeansOutdoor = [
    44.70652854777766,
    2.038678675551946,
    1.2890955627148357,
    44.68555833842936,
    2.5027476943896314,
    41.46606195351692,
    48.05852275872995,
    6.592460805213936,
    0.04820312945100589,
    1.6575863180145134,
  ];

  static const List<double> _kMagIoVarsOutdoor = [
    312.35770845234146,
    8.938069605850782,
    1.3472566954970249,
    315.70148817039166,
    17.35292815313298,
    311.16365127860985,
    356.63088110826766,
    82.024333442466,
    0.0033888842560319543,
    3.8815452894703943,
  ];

  static const List<double> _kIosMlpMu = [
    44.69842970893206,
    1.2945240816725525,
    0.7615478143932017,
    44.684847266528564,
    1.5996799226311258,
    42.64890634399485,
    46.81172544740871,
    4.162819103414341,
    0.030933639006912768,
    1.1116698901703963,
    0.8520738055097259,
    0.3490830523717179,
    1.4126004428631425,
    0.3399690696071103,
    0.10461501730929927,
  ];

  static const List<double> _kIosMlpSd = [
    20.374250445946817,
    2.5034704600452247,
    0.9967910503652929,
    20.449390098548037,
    3.5267923796819827,
    20.33705692432169,
    21.037779658195554,
    7.366764888827683,
    0.04804088018030106,
    1.5064516191962527,
    1.4011958363812727,
    0.5095609921893172,
    2.0007735388610923,
    0.5237928017695453,
    0.3060667193556148,
  ];

  static const List<List<double>> _kIosMlpW1 = [
    [0.10040926923296453, -0.37545225831118473, 0.2869988684610626, 0.33485318098900335, -0.7289402528227144, -0.4544381110997939, 0.04909635473554495, -0.15642861332599603, -0.0008041605761958085, -0.3043721134850647, 0.3246445661393204, 0.29498525919303475, 0.04354491514637845, 0.4301116075339683, 0.18087386132734598, -0.27213948801123594, 0.1544034067943848, -0.43385857043457954, 0.2812697290127701, -0.0024737950974706175, -0.07192030517375553, -0.2095795585045844, 0.5026966081980897, -0.04897639641071209],
    [-0.1558940319444605, -0.13145117834177766, 0.21098642974863638, 0.09259931273249444, 0.13835427048215104, 0.2050092730768501, 0.7387245964869854, -0.19124779507557566, -0.19417128660137248, -0.3051371269016082, 0.2272043474233177, 0.3788844772727582, -0.022008776830870554, -0.2781703349155905, -0.2919503896640921, 0.2255898401785837, 0.2683322532254488, 0.0460304433121514, -0.27496489929011786, 0.08055913933567457, 0.024302497516458594, 0.07453044538025128, 0.3948330089250181, 0.00039460500931514254],
    [0.23225314284414492, 0.02118955663180698, 0.1957442346605639, 0.10871946756509351, -0.5491145792958407, -0.007467398922474509, -0.2984333982407272, -0.33504161001982447, -0.11365166794770055, 0.5410888317073156, -0.31038163908815036, 0.3172668677153601, -0.6303137457168189, -0.0618246419969261, 0.07462662315752715, 0.19334551439782321, 0.2470715235432531, -0.0663304111863448, -0.16080681618836842, -0.19037800582187062, 0.26257638438137354, -0.06940183214873823, -0.3376763010150654, -0.6230289561411142],
    [-0.3450926417312948, 0.18427500021677942, 0.061662685437034126, 0.24490437457086028, -0.17433117808460832, 0.07437844418257428, 0.23311109563864446, -0.15405340490731176, 0.17142969557895316, -0.23621223262576682, -0.1267233135273348, -0.13070244914915136, -0.41747890190723963, 0.19702898719955456, -0.15984790337057436, 0.035624268512497746, 0.19535474628964444, 0.0781143525361449, 0.20119932155133308, -0.02023086153178573, -0.15862468036703375, 0.004247141871989841, -0.5484906607600305, -0.5196061932788796],
    [-0.486641357819875, -0.3758269890594823, 0.16428424359734903, -0.3736022546899251, -0.1337336887837555, 0.5128799347612335, -0.16050279680487445, 0.2303008399016537, -0.34323653512608926, -0.06600027466349496, -0.3472291503740334, -0.12146474866693241, 0.34806683110767717, -0.6038856005483765, 0.16532628649990427, 0.12996219165153047, -0.2201737714859322, -0.6386882579283961, 0.02023212354870046, -0.19979583531415696, 0.06890933041644753, 0.04152668597378141, 0.5882794420172253, -0.1542544813972865],
    [-0.3813432722854363, 0.06787739691177536, 0.09257885243416566, 0.4934186695772404, 0.28550946217134676, 0.14026369070330244, 0.5404933253485688, -0.464515196276973, -0.22598678004536654, -0.3288770839116071, -0.13779524321618764, -0.48069726956476255, 0.2476987069239791, -0.06567292104953502, -0.5255389334711941, -0.321162567696119, 0.13462328626168749, 0.24955284394100766, 0.6952968291756099, 1.0763539798039097, 0.14968074578102292, -0.3187573294951339, -0.7358460281672966, 0.1217127989385926],
    [-0.3053676176466724, -0.1498486971385127, -0.199868844298207, -0.06899821199369373, 0.3653840249474809, 0.08671109544217484, -0.06764715940116282, -0.4248621343436101, -0.6054744602677766, -0.17170329548523053, -0.014671156740569225, 0.6528039653390834, 0.06868712275506433, 0.38283929194124683, -0.16956104675844547, -0.38646470860506466, -0.3321618887981655, -0.379428718989703, 0.7343217578741112, -0.2844391396407453, 0.2967496119159031, -0.28899274473637443, 0.4039425401118178, 0.13174046094733288],
    [-0.059523599957474645, -0.018821775163440684, -0.20795588562298176, 0.11371529101392218, -0.1788346104374924, -0.3901100402960758, -0.516261736280996, 0.01393306273807688, 0.5659039120979087, 0.05058525834234466, -0.04011365849205552, 0.07719473878057193, 0.48960922580131744, 0.11072137324297472, -0.14086185214501906, 0.39627464832284226, 0.15269389829631477, 0.38052286875451463, 0.03833862803837739, -0.4507671054068658, -0.518032629497648, 0.5993190988844813, 0.7039887638521309, -0.15608009515886787],
    [-0.14185178948396632, 0.5242264711901171, -0.3906412427053461, -0.3549676960691305, 0.220592605979999, -0.08751340006892822, -0.040826142466604404, -0.13093739623079187, 0.10726211991082694, 0.4911901941316643, 0.03949886181044051, 0.1630396082371448, -0.7537545899293446, 0.006564353550735942, -0.2974996048491565, -0.456796158348251, -0.3210738744530818, -0.3116019635291259, 0.2676867432953197, -0.4694785934684016, -0.0015952327803119212, -0.19734282521116228, -0.014964757606601656, 0.24271801705862364],
    [0.17573428688474052, 0.4727679756502495, 0.009727188159954653, -0.3235199940539673, -0.07825565096702519, 0.1549018805015645, -0.003249256077675406, -0.4438116467375503, 0.03051936459565453, 0.0954218112133428, 0.910698117336153, 0.7079787941243066, -0.2746281379282567, -0.06923279597652758, -0.5224430333991937, -0.15727588104346552, 0.10792115243291812, 0.22342216300739884, -0.26054847245271334, -0.2574920276339425, -0.7974410307980285, -0.016144709331310056, -0.3772265290138879, -0.27995074908901524],
    [-0.346794961392618, -0.036661222885319894, -0.6307623837667636, -0.5453170706645437, 0.7868545854067756, -0.4357880425913553, -0.4297572479636011, 0.5555633770419648, 1.0671139049897957, -0.4119625682180234, -0.12985531432057212, 0.15115335056382573, 0.6880731695769485, -0.3300768453902228, -0.061239740104458304, 0.49255900976642275, 0.1509459972990212, -0.18869502432497817, 0.005243620634410818, -0.5046393643026428, -0.09798355921419936, 0.03361379263698763, 0.001280911495276603, -0.2559040538242021],
    [0.1779016136514142, 0.3847140635528005, 0.03975389511510348, 0.06639225649419161, -0.011535180043403438, 0.07252914103662633, -0.3618316681760299, 0.01148748820046383, -0.062217470188760865, 0.7324897395698333, 0.5883327495869896, -0.0032053059212626945, -0.334039274254098, -0.3625296502611082, 0.45372499345125683, -0.04176652178461428, 0.16893992655857432, -0.8202414213959908, 0.24952510801319291, 0.19319113539030103, -0.44253688738853636, -0.21558404592846706, 0.30217154588553763, -0.17491493881827672],
    [-0.11940755229961098, -0.027164532494835456, -0.0950143121581998, 0.008739924003130778, 0.5272005026743124, -0.8676054745691989, -0.16965746052857567, -0.056671822995720676, 0.09846336351872083, -0.14013650164941902, -0.627613428417345, 0.05145030416805422, 0.6390160954864763, -0.5171947196394296, 0.3414278391261648, -0.08101788842178835, -0.030663636470227316, -0.5431572144001301, -0.14343860221128596, 0.4861969872795883, 0.1784256941245336, 0.6717369775946433, 0.5056803386677982, -0.00037127273325276034],
    [0.6338359266313962, 0.1673141779885017, 0.28399659397772914, -0.14975008942603707, -0.0025015242978359115, -0.19747211764350361, 0.28536965164537953, -0.5067388597456428, 0.26569743374025223, -0.08796685034295723, 0.4371567506841824, 0.1798210458089524, 0.6054587409000579, 0.30094044190148017, -0.5521983159055246, -0.08254999971519077, -0.4310909307553431, -0.32630501489516045, 0.4981688910276927, 0.2630453404573736, -0.27784599745263683, -0.3717692250741878, 0.14389045490010668, -0.5681453289565472],
    [-0.2146573760837345, 0.14967122196063928, 0.5042068610760172, 0.0870619908121925, -0.8575849124642714, 0.19355632567652648, -0.18804520273317962, 0.21411167441337478, 0.5824119693420046, -0.7785353153771257, -0.2059208102685302, 0.307037718338578, -0.6660225860158175, 0.5843004072010063, 0.13319670476235784, 0.1885110419301212, -0.20377137790730954, 0.10010259848638602, 0.5209448480748614, -0.05538818542695115, 0.03148133226954683, 0.0703624534086903, -0.19773112550333763, -0.014401182657128551],
  ];

  static const List<double> _kIosMlpB1 = [
    0.003986832851420533,
    -0.0011806801561045361,
    0.05711124024616429,
    -0.09182611812047468,
    0.09634500494801053,
    0.04955596239954378,
    -0.07773228122417376,
    -0.056479177966038754,
    0.00811016098012132,
    0.055743706528611825,
    -0.01434852062051599,
    0.08319705250005643,
    0.2508377615785658,
    -0.019382358719486542,
    -0.011972286967123663,
    0.022104031278432575,
    -0.016542501675135997,
    -0.24607663870572846,
    0.023706296898159673,
    -0.10488060591646171,
    -0.052806499254823135,
    -0.010024508093203845,
    -0.11798336808372874,
    -0.1770592292177698,
  ];

  static const List<double> _kIosMlpW2 = [
    -0.1476632642593559,
    -0.1591581965604562,
    0.396906488253754,
    -0.30035442595904527,
    0.2888350426135267,
    0.1841866344819475,
    -0.4652675986914024,
    -0.44617555343267973,
    -0.010934057955420186,
    0.15619131960331875,
    -0.039494116481267216,
    0.29468852976749416,
    0.5857041635612418,
    0.144349714843792,
    -0.05551135557303858,
    0.6576943743196275,
    -0.043466779232732594,
    -0.8360451763804002,
    0.26342983207860954,
    -0.32574793699820564,
    -0.2093751280695645,
    0.36928316581265824,
    -0.5876891855317923,
    -0.7245882942939812,
  ];

  static const double _kIosMlpB2 = 0.4527205017312472;
}
