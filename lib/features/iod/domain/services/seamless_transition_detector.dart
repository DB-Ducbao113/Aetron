import 'dart:math' as math;

import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';
import '../models/transition_handover_event.dart';

/// Research implementation of the probabilistic transition detection and handover framework
/// from: *Seamless Indoor–Outdoor Localization Through Transition Detection*
/// (Jaehyun Yoo, Electronics 2025, 14(13), 2598; DOI: 10.3390/electronics14132598).
///
/// Published Methodology & Architecture (Section 3):
/// 1. GNSS Distribution Model (Section 3.2):
///    - C/N0 upper threshold: 40 dB-Hz (strong outdoor line-of-sight).
///    - C/N0 lower threshold: 30 dB-Hz (attenuated indoor).
///    - Intermediate boundary zone (30 <= C/N0 <= 40 dB-Hz) scaled via: (40 - C/N0) / 10.
///    - Satellite visibility conditions (min 5 satellites for outdoor, <= 2 for indoor).
/// 2. Position-Based Distribution Model (Section 3.3):
///    - Maps user position relative to known physical transition points (e.g. building doorways).
///    - Computes Gaussian proximity kernel peaking at the entrance boundary.
///    - When entrance coordinates are absent (un-surveyed environment): cleanly abstains (w_pos = 0.0).
/// 3. Wi-Fi / BLE RSSI Model (Section 3.1):
///    - Evaluates wireless signal strength against pre-surveyed radio maps or entrance beacons.
///    - When no pre-surveyed radio map is configured on mobile: cleanly abstains (w_rssi = 0.0),
///      explicitly reported as BLOCKED without fabricating artificial fingerprints.
/// 4. Weighted State Probability Fusion (Section 3):
///    P(S) = (w_gnss * P_gnss(S) + w_pos * P_pos(S) + w_rssi * P_rssi(S)) / (w_gnss + w_pos + w_rssi).
/// 5. State Selection & Handover Execution (Section 3.4):
///    S* = argmax P(S). Records handover event across state transitions.
///    Observational only: Does not disrupt production GPS/EKF positioning.
class SeamlessTransitionDetector {
  static const String modelVersion = 'yoo-transition-2025-v2.0';

  // Physical GNSS boundaries from Yoo (Electronics 2025, 14(13), 2598)
  static const double kCn0UpperThresholdDbHz = 40.0;
  static const double kCn0LowerThresholdDbHz = 30.0;
  static const int kMinSatellitesOutdoor = 5;
  static const int kMaxSatellitesIndoor = 2;

  // Position distribution kernel parameter (meters)
  static const double kPositionSigmaMeters = 5.0;

  // Configured building transition points (optional)
  final List<BuildingTransitionPoint> transitionPoints;

  // Handover event history
  final List<TransitionHandoverEvent> _handoverEvents = [];
  List<TransitionHandoverEvent> get handoverEvents => List.unmodifiable(_handoverEvents);

  // Temporal gradient tracking across epochs
  double? _lastTop4Cn0;
  int? _lastUsedSatCount;
  IndoorOutdoorState _lastLeadingState = IndoorOutdoorState.unknown;

  SeamlessTransitionDetector({
    List<BuildingTransitionPoint>? transitionPoints,
  }) : transitionPoints = transitionPoints ?? const [];

  void reset() {
    _lastTop4Cn0 = null;
    _lastUsedSatCount = null;
    _lastLeadingState = IndoorOutdoorState.unknown;
    _handoverEvents.clear();
  }

  /// Evaluates multi-source transition state probability for a 1 Hz snapshot.
  IodPrediction evaluate(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    final bool hasGnss = snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null;
    final bool hasGps = snapshot.hasGpsFix && snapshot.latitude != null && snapshot.longitude != null;
    final bool hasWifi = snapshot.hasWifiScan && snapshot.meanWifiRssiDbm != null;
    final bool hasBle = snapshot.hasBleScan && snapshot.meanBleRssiDbm != null;

    final Map<String, bool> availability = {
      'gnss_status': snapshot.hasGnssStatus,
      'gnss_signals': hasGnss,
      'gps': snapshot.hasGpsFix,
      'gps_position': hasGps,
      'imu': snapshot.hasImuData,
      'wifi_scan': hasWifi,
      'ble_scan': hasBle,
      'building_transition_points': transitionPoints.isNotEmpty,
      'wifi_ble_radio_map': false, // BLOCKED on live mobile without pre-surveyed building radio map
    };

    if (!snapshot.hasGnssStatus && !snapshot.hasGpsFix && !hasWifi && !hasBle) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_positioning_signals_available',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    // 1. Evaluate GNSS Distribution Model (Section 3.2)
    final gnssResult = _evaluateGnssModel(snapshot);

    // 2. Evaluate Position Distribution Model (Section 3.3)
    final posResult = _evaluatePositionModel(snapshot);

    // 3. Evaluate Wi-Fi / BLE RSSI Model (Section 3.1)
    final rssiResult = _evaluateRssiModel(snapshot);

    // 4. Weighted Probability Fusion (Section 3)
    final double totalWeight = gnssResult.weight + posResult.weight + rssiResult.weight;

    final double pOutdoor;
    final double pIndoor;
    final double pTransition;

    if (totalWeight > 0.0) {
      pOutdoor = ((gnssResult.weight * gnssResult.pOutdoor) +
              (posResult.weight * posResult.pOutdoor) +
              (rssiResult.weight * rssiResult.pOutdoor)) /
          totalWeight;
      pIndoor = ((gnssResult.weight * gnssResult.pIndoor) +
              (posResult.weight * posResult.pIndoor) +
              (rssiResult.weight * rssiResult.pIndoor)) /
          totalWeight;
      pTransition = ((gnssResult.weight * gnssResult.pTransition) +
              (posResult.weight * posResult.pTransition) +
              (rssiResult.weight * rssiResult.pTransition)) /
          totalWeight;
    } else {
      pOutdoor = 0.333;
      pIndoor = 0.333;
      pTransition = 0.334;
    }

    // 5. State Selection (Section 3.4)
    final IndoorOutdoorState leadingState;
    final double confidence;

    if (pTransition >= pOutdoor && pTransition >= pIndoor) {
      leadingState = IndoorOutdoorState.transition;
      confidence = pTransition;
    } else if (pOutdoor >= pIndoor) {
      leadingState = IndoorOutdoorState.outdoor;
      confidence = pOutdoor;
    } else {
      leadingState = IndoorOutdoorState.indoor;
      confidence = pIndoor;
    }

    // 6. Handover Trigger Logic (Section 3.4)
    if (_lastLeadingState != IndoorOutdoorState.unknown &&
        _lastLeadingState != leadingState) {
      final handoverEvent = TransitionHandoverEvent(
        fromState: _lastLeadingState,
        toState: leadingState,
        timestamp: snapshot.timestamp,
        confidence: confidence,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        triggerReason: 'Yoo-2025 Handover [P(Out)=${(pOutdoor * 100).toStringAsFixed(0)}%, '
            'P(In)=${(pIndoor * 100).toStringAsFixed(0)}%, '
            'P(Trans)=${(pTransition * 100).toStringAsFixed(0)}%]',
      );
      _handoverEvents.add(handoverEvent);
      if (_handoverEvents.length > 50) {
        _handoverEvents.removeAt(0);
      }
    }
    _lastLeadingState = leadingState;

    stopwatch.stop();

    final reasoning = 'Yoo-2025 [State=${leadingState.code.toUpperCase()} Conf=${(confidence * 100).toStringAsFixed(0)}%] '
        'P(Out)=${(pOutdoor * 100).toStringAsFixed(1)}% '
        'P(In)=${(pIndoor * 100).toStringAsFixed(1)}% '
        'P(Trans)=${(pTransition * 100).toStringAsFixed(1)}% | '
        'GNSS(w=${gnssResult.weight.toStringAsFixed(2)}) | '
        'Pos(w=${posResult.weight.toStringAsFixed(2)}) | '
        'RSSI(w=${rssiResult.weight.toStringAsFixed(2)})';

    return IodPrediction(
      state: leadingState,
      confidence: confidence,
      deepIodOutdoorProbability: pOutdoor,
      transitionProbability: pTransition,
      nativeClass: leadingState.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }

  /// GNSS Distribution Model (Section 3.2): C/N0 boundaries, satellite counts, and rate-of-change.
  _DistributionResult _evaluateGnssModel(IodSensorSnapshot snapshot) {
    if (!snapshot.hasGnssStatus && !snapshot.hasGpsFix) {
      return const _DistributionResult(pOutdoor: 0.33, pIndoor: 0.33, pTransition: 0.34, weight: 0.0);
    }

    final double currentCn0 = snapshot.top4Cn0DbHz ??
        (snapshot.horizontalAccuracy != null
            ? math.max(10.0, 45.0 - (snapshot.horizontalAccuracy! * 0.75))
            : 30.0);
    final int currentSat = snapshot.usedInFixCount ?? (snapshot.hasGpsFix ? 4 : 0);

    double pOut;
    double pIn;
    double pTrans;

    if (currentCn0 >= kCn0UpperThresholdDbHz && currentSat >= kMinSatellitesOutdoor) {
      // Strong Line-of-Sight
      pOut = 0.90;
      pIn = 0.05;
      pTrans = 0.05;
    } else if (currentCn0 <= kCn0LowerThresholdDbHz || currentSat <= kMaxSatellitesIndoor) {
      // Heavily Attenuated / Blocked
      pOut = 0.05;
      pIn = 0.90;
      pTrans = 0.05;
    } else {
      // Intermediate boundary region: 30 <= C/N0 <= 40 dB-Hz
      final tRatio = (kCn0UpperThresholdDbHz - currentCn0) /
          (kCn0UpperThresholdDbHz - kCn0LowerThresholdDbHz);
      double transBoost = 0.35 + (tRatio * 0.25);

      // Motion continuity check
      final isMoving = snapshot.stepDelta > 0 || (snapshot.speed != null && snapshot.speed! > 0.4);
      if (isMoving) transBoost += 0.15;

      // Rate-of-change check (entering/exiting doorway creates sharp C/N0 delta)
      if (_lastTop4Cn0 != null) {
        final delta = (currentCn0 - _lastTop4Cn0!).abs();
        if (delta >= 4.0) transBoost += 0.15;
      }
      if (_lastUsedSatCount != null) {
        final satDelta = (currentSat - _lastUsedSatCount!).abs();
        if (satDelta >= 2) transBoost += 0.10;
      }

      pTrans = transBoost.clamp(0.0, 0.90);
      final remaining = 1.0 - pTrans;
      pOut = (remaining * (1.0 - tRatio)).clamp(0.0, 1.0);
      pIn = (remaining * tRatio).clamp(0.0, 1.0);
    }

    _lastTop4Cn0 = currentCn0;
    _lastUsedSatCount = currentSat;

    return _DistributionResult(pOutdoor: pOut, pIndoor: pIn, pTransition: pTrans, weight: 0.50);
  }

  /// Position-Based Distribution Model (Section 3.3): Gaussian proximity to doorway transition points.
  _DistributionResult _evaluatePositionModel(IodSensorSnapshot snapshot) {
    if (transitionPoints.isEmpty || !snapshot.hasGpsFix || snapshot.latitude == null || snapshot.longitude == null) {
      // Cleanly abstain when no building entrance coordinates are configured
      return const _DistributionResult(pOutdoor: 0.33, pIndoor: 0.33, pTransition: 0.34, weight: 0.0);
    }

    final lat = snapshot.latitude!;
    final lon = snapshot.longitude!;

    double minDistance = double.infinity;
    for (final pt in transitionPoints) {
      final d = _haversineDistanceMeters(lat, lon, pt.latitude, pt.longitude);
      if (d < minDistance) minDistance = d;
    }

    // Gaussian kernel peaking at the door
    final pTrans = math.exp(-(minDistance * minDistance) / (2.0 * kPositionSigmaMeters * kPositionSigmaMeters));
    final remaining = 1.0 - pTrans;

    // Allocate remaining probability based on distance gradient
    final pOut = remaining * 0.5;
    final pIn = remaining * 0.5;

    return _DistributionResult(pOutdoor: pOut, pIndoor: pIn, pTransition: pTrans, weight: 0.30);
  }

  /// Wi-Fi / BLE RSSI Model (Section 3.1).
  _DistributionResult _evaluateRssiModel(IodSensorSnapshot snapshot) {
    if (!snapshot.hasWifiScan && !snapshot.hasBleScan) {
      return const _DistributionResult(pOutdoor: 0.33, pIndoor: 0.33, pTransition: 0.34, weight: 0.0);
    }

    // In the absence of a pre-surveyed building radio map on unconstrained mobile devices,
    // this component cleanly abstains (w_rssi = 0.0) rather than fabricating fake fingerprints.
    return const _DistributionResult(pOutdoor: 0.33, pIndoor: 0.33, pTransition: 0.34, weight: 0.0);
  }

  static double _haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLon / 2.0) * math.sin(dLon / 2.0);
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return r * c;
  }
}

class _DistributionResult {
  final double pOutdoor;
  final double pIndoor;
  final double pTransition;
  final double weight;

  const _DistributionResult({
    required this.pOutdoor,
    required this.pIndoor,
    required this.pTransition,
    required this.weight,
  });
}
