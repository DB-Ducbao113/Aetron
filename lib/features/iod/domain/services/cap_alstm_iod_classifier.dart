import 'dart:collection';

import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import 'cap_alstm_model.dart';

/// Stateful causal classifier wrapping [CapAlstmModel] (Bakirtzis et al.,
/// IEEE IoT J 2022, DOI: 10.1109/JIOT.2022.3190555) with optional Causal
/// 2-state HMM temporal smoothing (Zhu et al., Sensors 2019, 10.3390/s19040786).
///
/// Strictly checks availability of every sensor feature declared in
/// `model.features` and abstains (`IndoorOutdoorState.unknown`) rather than
/// fabricating missing channels.
class CapAlstmIodClassifier {
  final CapAlstmModel model;
  final String modelVersion;
  final bool useCausalHmm;
  final bool prefixPadOnFirstEpoch;

  final ListQueue<List<double>> _window = ListQueue<List<double>>();
  DateTime? _lastTimestamp;
  double _alphaIndoor = 0.5;
  double _alphaOutdoor = 0.5;

  CapAlstmIodClassifier({
    required this.model,
    required this.modelVersion,
    this.useCausalHmm = true,
    this.prefixPadOnFirstEpoch = false,
  });

  int get bufferedEpochs => _window.length;

  void reset() {
    _window.clear();
    _lastTimestamp = null;
    _alphaIndoor = 0.5;
    _alphaOutdoor = 0.5;
  }

  /// Extracts raw feature vector matching `model.features`; returns null plus
  /// missing channel name if any required sensor is unavailable.
  (List<double>?, String?) _extractFrame(IodSensorSnapshot s) {
    final values = <double>[];
    for (final f in model.features) {
      switch (f) {
        case 'RSRP':
          if (!s.hasTelephonyLte || !(s.lteRsrpDbm?.isFinite ?? false)) {
            return (null, 'RSRP');
          }
          values.add(s.lteRsrpDbm!);
        case 'RSRQ':
          if (!s.hasTelephonyLte || !(s.lteRsrqDb?.isFinite ?? false)) {
            return (null, 'RSRQ');
          }
          values.add(s.lteRsrqDb!);
        case 'Light':
          if (!s.hasLightSensor ||
              !(s.ambientLux?.isFinite ?? false) ||
              s.ambientLux! < 0.0) {
            return (null, 'Light');
          }
          values.add(s.ambientLux!);
        case 'Mag':
          if (!s.hasImuData ||
              !(s.magneticMagnitudeMean?.isFinite ?? false) ||
              s.magneticMagnitudeMean! < 0.0) {
            return (null, 'Mag');
          }
          values.add(s.magneticMagnitudeMean!);
        case 'Acc':
          if (!s.hasImuData ||
              !(s.accelMagnitudeMean?.isFinite ?? false) ||
              s.accelMagnitudeMean! < 0.0) {
            return (null, 'Acc');
          }
          values.add(s.accelMagnitudeMean!);
        case 'Proximity':
          if (!s.hasProximitySensor ||
              !(s.proximityCm?.isFinite ?? false) ||
              s.proximityCm! < 0.0) {
            return (null, 'Proximity');
          }
          values.add(s.proximityCm!);
        case 'Daytime':
          values.add(s.isNightTime ? 0.0 : 1.0);
        default:
          return (null, f);
      }
    }
    return (values, null);
  }

  IodPrediction classify(IodSensorSnapshot snapshot) {
    final sw = Stopwatch()..start();
    final availability = <String, bool>{
      'light': snapshot.hasLightSensor && (snapshot.ambientLux?.isFinite ?? false),
      'mag': snapshot.hasImuData && (snapshot.magneticMagnitudeMean?.isFinite ?? false),
      'acc': snapshot.hasImuData && (snapshot.accelMagnitudeMean?.isFinite ?? false),
      'lte': snapshot.hasTelephonyLte && (snapshot.lteRsrpDbm?.isFinite ?? false),
      'proximity': snapshot.hasProximitySensor && (snapshot.proximityCm?.isFinite ?? false),
      'daytime': true,
    };

    if (_lastTimestamp != null) {
      final dtMs = snapshot.timestamp.difference(_lastTimestamp!).inMilliseconds;
      if (dtMs <= 0 || dtMs > 2500) {
        reset();
      }
    }

    final (rawFrame, missingFeature) = _extractFrame(snapshot);
    if (rawFrame == null) {
      reset();
      sw.stop();
      return IodPrediction.unknown(
        reason: 'missing_required_feature:$missingFeature',
        modelVersion: modelVersion,
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    _lastTimestamp = snapshot.timestamp;
    final normFrame = model.normalizeFrame(rawFrame);

    if (_window.isEmpty && prefixPadOnFirstEpoch) {
      for (int i = 0; i < model.windowSize - 1; i++) {
        _window.addLast(normFrame);
      }
    }
    _window.addLast(normFrame);
    while (_window.length > model.windowSize) {
      _window.removeFirst();
    }

    if (_window.length < model.windowSize) {
      sw.stop();
      return IodPrediction.unknown(
        reason: 'warming_up_${_window.length}_of_${model.windowSize}',
        modelVersion: modelVersion,
        latencyMs: sw.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    final rawPOut = model.predict(_window.toList(growable: false));
    double finalPOut = rawPOut;
    double threshold = model.rawThreshold;

    if (useCausalHmm) {
      final bOut = rawPOut.clamp(1e-4, 1.0 - 1e-4);
      final bIn = 1.0 - bOut;
      final predIn =
          _alphaIndoor * model.pStayIn + _alphaOutdoor * (1.0 - model.pStayOut);
      final predOut =
          _alphaIndoor * (1.0 - model.pStayIn) + _alphaOutdoor * model.pStayOut;
      final aIn = predIn * bIn;
      final aOut = predOut * bOut;
      final norm = aIn + aOut;
      _alphaIndoor = aIn / norm;
      _alphaOutdoor = aOut / norm;
      finalPOut = _alphaOutdoor;
      threshold = model.hmmThreshold;
    }

    final isOutdoor = finalPOut >= threshold;
    final state =
        isOutdoor ? IndoorOutdoorState.outdoor : IndoorOutdoorState.indoor;
    final conf = isOutdoor ? finalPOut : (1.0 - finalPOut);
    sw.stop();

    return IodPrediction(
      state: state,
      confidence: conf,
      deepIodOutdoorProbability: rawPOut,
      nativeClass: isOutdoor ? 'outdoor' : 'indoor',
      modelVersion: modelVersion,
      inferenceLatencyMs: sw.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary:
          'CAP-ALSTM(${model.features.join("+")},w=${model.windowSize}'
          '${useCausalHmm ? "+HMM" : ""}): p_out=${finalPOut.toStringAsFixed(3)}',
      isObservationalOnly: true,
    );
  }
}
