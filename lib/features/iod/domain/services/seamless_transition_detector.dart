import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';

/// Literature-inspired transition detection algorithm adapted from:
/// *Seamless Indoor–Outdoor Localization Through Transition Detection*
/// (Yoo, Electronics 2025, 14(13), 2598; DOI: 10.3390/electronics14132598).
///
/// Published Methodology & Adaptations:
/// - Yoo (2025) models GNSS carrier-to-noise density ratio (C/N0) transitions using
///   an upper bound of 40 dB-Hz (strong line-of-sight outdoor) and a lower bound of
///   30 dB-Hz (attenuated indoor), with a linear transition scaling function:
///   (40 - C/N0) / 10 for the intermediate boundary zone (30 <= C/N0 <= 40 dB-Hz).
/// - Declared Adaptation: The original publication combines GNSS C/N0 with Wi-Fi/BLE
///   fingerprinting and a GNSS-IMU Kalman filter. This mobile sensor slice implements
///   the GNSS C/N0 boundary model and motion continuity, but omits Wi-Fi/BLE mapping.
///
/// Output classifies states into:
/// - [IndoorOutdoorState.outdoor]: Direct line-of-sight GNSS (C/N0 >= 40 dB-Hz).
/// - [IndoorOutdoorState.indoor]: Deeply obstructed signals (C/N0 <= 30 dB-Hz).
/// - [IndoorOutdoorState.transition]: Boundary zone (building entrance, doorway,
///   threshold, covered porch, bridge underpass: 30 <= C/N0 <= 40 dB-Hz).
class SeamlessTransitionDetector {
  static const String modelVersion = 'yoo-transition-2025-v1.1';

  // Physical GNSS boundaries from Yoo (Electronics 2025, 14(13), 2598)
  static const double kCn0UpperThresholdDbHz = 40.0;
  static const double kCn0LowerThresholdDbHz = 30.0;
  static const int kMinSatellitesOutdoor = 5;
  static const int kMaxSatellitesIndoor = 2;

  // Historical memory for tracking signal gradients across epochs
  double? _lastTop4Cn0;
  int? _lastUsedSatCount;

  void reset() {
    _lastTop4Cn0 = null;
    _lastUsedSatCount = null;
  }

  /// Evaluates transition state probability for a 1 Hz snapshot.
  IodPrediction evaluate(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    final Map<String, bool> availability = {
      'gnss_status': snapshot.hasGnssStatus,
      'gps': snapshot.hasGpsFix,
      'imu': snapshot.hasImuData,
    };

    if (!snapshot.hasGnssStatus && !snapshot.hasGpsFix) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_gnss_or_gps_data',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    // 1. Compute Base Probabilities from Satellite Metrics
    final currentCn0 = snapshot.top4Cn0DbHz ??
        _estimateCn0FromAccuracy(snapshot.horizontalAccuracy);
    final currentSatUsed = snapshot.usedInFixCount ??
        (snapshot.hasGpsFix ? 4 : 0);

    final double pOutdoor;
    final double pIndoor;
    final double pTransition;

    if (currentCn0 >= kCn0UpperThresholdDbHz &&
        currentSatUsed >= kMinSatellitesOutdoor) {
      // Strong GNSS line-of-sight (C/N0 >= 40 dB-Hz) -> High probability Outdoor
      pOutdoor = 0.85;
      pIndoor = 0.05;
      pTransition = 0.10;
    } else if (currentCn0 <= kCn0LowerThresholdDbHz ||
        currentSatUsed <= kMaxSatellitesIndoor) {
      // Heavily attenuated GNSS (C/N0 <= 30 dB-Hz) -> High probability Indoor
      pOutdoor = 0.05;
      pIndoor = 0.85;
      pTransition = 0.10;
    } else {
      // Intermediate signal region: 30 <= C/N0 <= 40 dB-Hz (Yoo 2025)
      // Published transitional scaling: (40 - C/N0) / 10
      final tRatio = (kCn0UpperThresholdDbHz - currentCn0) /
          (kCn0UpperThresholdDbHz - kCn0LowerThresholdDbHz);
      double transitionBoost = 0.35 + (tRatio * 0.25);

      // Check if user is actively walking (motion continuity)
      final isMoving = snapshot.stepDelta > 0 ||
          (snapshot.speed != null && snapshot.speed! > 0.4);

      if (isMoving) {
        transitionBoost += 0.20;
      }

      // Check for rapid signal drop or surge (entering or exiting a building)
      if (_lastTop4Cn0 != null) {
        final cn0Delta = (currentCn0 - _lastTop4Cn0!).abs();
        if (cn0Delta >= 4.0) {
          transitionBoost += 0.15;
        }
      }

      // Check for abrupt change in used satellites
      if (_lastUsedSatCount != null) {
        final satDelta = (currentSatUsed - _lastUsedSatCount!).abs();
        if (satDelta >= 2) {
          transitionBoost += 0.10;
        }
      }

      pTransition = transitionBoost.clamp(0.0, 0.90);
      final remaining = 1.0 - pTransition;
      final normalizedOutdoorWeight = 1.0 - tRatio;
      pOutdoor = (remaining * normalizedOutdoorWeight).clamp(0.0, 1.0);
      pIndoor = (remaining * tRatio).clamp(0.0, 1.0);
    }

    // Update gradient history
    _lastTop4Cn0 = currentCn0;
    _lastUsedSatCount = currentSatUsed;

    // Determine leading state
    final IndoorOutdoorState state;
    final double confidence;

    if (pTransition >= 0.50) {
      state = IndoorOutdoorState.transition;
      confidence = pTransition;
    } else if (pOutdoor >= pIndoor) {
      state = IndoorOutdoorState.outdoor;
      confidence = pOutdoor;
    } else {
      state = IndoorOutdoorState.indoor;
      confidence = pIndoor;
    }

    stopwatch.stop();

    final reasoning = 'Yoo-2025(Adaptation) cn0=${currentCn0.toStringAsFixed(1)}dB '
        'sats=$currentSatUsed '
        'P(out)=${(pOutdoor * 100).toStringAsFixed(0)}% '
        'P(in)=${(pIndoor * 100).toStringAsFixed(0)}% '
        'P(trans)=${(pTransition * 100).toStringAsFixed(0)}%';

    return IodPrediction(
      state: state,
      confidence: confidence,
      deepIodOutdoorProbability: pOutdoor,
      transitionProbability: pTransition,
      nativeClass: state.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }

  /// Approximation when only Geolocator horizontal accuracy is available.
  double _estimateCn0FromAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null || accuracyMeters <= 0.0) return 25.0;
    // Strong accuracy (<5m) maps to ~42 dB-Hz C/N0
    // Poor accuracy (>40m) maps to <28 dB-Hz C/N0
    final estimated = 44.0 - (accuracyMeters * 0.40);
    return estimated.clamp(15.0, 42.0);
  }
}
