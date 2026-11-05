import 'dart:math' as math;

import '../models/indoor_outdoor_state.dart';
import '../models/iod_prediction.dart';
import '../models/iod_sensor_snapshot.dart';

/// Literature-inspired baseline classifier implementing the multi-source fusion
/// principles of DeepIOD (Sensors 2024, 24(16), 5125; PMCID: PMC11360063).
///
/// Published Architecture & Declared Adaptations:
/// 1. DeepIOD uses proprietary deep neural network models (CNN/LSTM) trained by KAIST.
///    Because model weights and datasets are unreleased, this class implements an
///    explicitly labeled Literature Baseline rather than an exact DNN reproduction.
/// 2. Multi-sensor inputs: 1 Hz normalized epoch, 9-axis IMU, Lux photodiode, GPS.
/// 3. Adaptive Majority Voter (AMV): Reliability-weighted consensus dynamically
///    attenuating degraded sensor streams.
class DeepIodBaselineClassifier {
  static const String modelVersion = 'deepiod-baseline-v1.1';

  // Light module constants (lux)
  static const double kLuxOutdoorOvercastThreshold = 1000.0;
  static const double kLuxIndoorTypicalMax = 400.0;
  static const double kLuxPocketThreshold = 5.0;

  // GNSS / GPS module constants
  static const double kGpsAccuracyOutdoorMeters = 15.0;
  static const double kGpsAccuracyIndoorMeters = 40.0;
  static const double kCn0StrongDbHz = 35.0;
  static const double kCn0WeakDbHz = 28.0;

  // IMU / Magnetometer constants (microTesla uT)
  // Indoor structures with steel rebars and appliances create high local spatial variance
  static const double kMagVarianceIndoorThreshold = 18.0;
  static const double kMagVarianceOutdoorThreshold = 5.0;

  /// Performs inference on a normalized 1 Hz sensor snapshot.
  IodPrediction classify(IodSensorSnapshot snapshot) {
    final stopwatch = Stopwatch()..start();

    final imuResult = _evaluateImuModule(snapshot);
    final lightResult = _evaluateLightModule(snapshot);
    final gpsResult = _evaluateGpsModule(snapshot);

    // Adaptive Majority Voter (AMV):
    // Computes normalized reliability weights based on sensor availability and quality
    final totalWeight =
        imuResult.weight + lightResult.weight + gpsResult.weight;

    final Map<String, bool> availability = {
      'imu': snapshot.hasImuData,
      'light': snapshot.hasLightSensor,
      'gps': snapshot.hasGpsFix,
      'gnss_status': snapshot.hasGnssStatus,
    };

    if (totalWeight <= 0.01) {
      stopwatch.stop();
      return IodPrediction.unknown(
        reason: 'no_reliable_sensors_available',
        modelVersion: modelVersion,
        latencyMs: stopwatch.elapsedMilliseconds,
        sensorAvailability: availability,
      );
    }

    final normalizedImuWeight = imuResult.weight / totalWeight;
    final normalizedLightWeight = lightResult.weight / totalWeight;
    final normalizedGpsWeight = gpsResult.weight / totalWeight;

    // Fused probability of Outdoor environment
    final outdoorProbability = (imuResult.outdoorScore * normalizedImuWeight) +
        (lightResult.outdoorScore * normalizedLightWeight) +
        (gpsResult.outdoorScore * normalizedGpsWeight);

    // Resolve state and confidence
    final IndoorOutdoorState resolvedState;
    final double confidence;

    if (outdoorProbability >= 0.58) {
      resolvedState = IndoorOutdoorState.outdoor;
      confidence = ((outdoorProbability - 0.5) * 2.0).clamp(0.0, 1.0);
    } else if (outdoorProbability <= 0.42) {
      resolvedState = IndoorOutdoorState.indoor;
      confidence = (((1.0 - outdoorProbability) - 0.5) * 2.0).clamp(0.0, 1.0);
    } else {
      resolvedState = IndoorOutdoorState.transition;
      confidence = (1.0 - (outdoorProbability - 0.5).abs() * 4.0).clamp(0.0, 1.0);
    }

    stopwatch.stop();

    final reasoning = _buildReasoningSummary(
      imuResult,
      lightResult,
      gpsResult,
      outdoorProbability,
      snapshot,
    );

    return IodPrediction(
      state: resolvedState,
      confidence: confidence,
      deepIodOutdoorProbability: outdoorProbability,
      nativeClass: resolvedState.code,
      modelVersion: modelVersion,
      inferenceLatencyMs: stopwatch.elapsedMilliseconds,
      sensorAvailability: availability,
      reasoningSummary: reasoning,
      isObservationalOnly: true,
    );
  }

  /// IMU Module: Evaluates magnetic field perturbations and motion dynamics.
  _ModuleScore _evaluateImuModule(IodSensorSnapshot snapshot) {
    if (!snapshot.hasImuData) {
      return const _ModuleScore(outdoorScore: 0.5, weight: 0.0, note: 'no_imu');
    }

    final magVar = snapshot.magneticVariance ?? 0.0;
    double outdoorScore = 0.5;
    double weight = 0.35; // Standard baseline weight

    // Low magnetic variance indicates a uniform natural geomagnetic field (Outdoor)
    if (magVar <= kMagVarianceOutdoorThreshold) {
      outdoorScore = 0.75;
    } else if (magVar >= kMagVarianceIndoorThreshold) {
      // High magnetic disturbance from structural steel / indoor appliances
      outdoorScore = 0.20;
    } else {
      final ratio = (magVar - kMagVarianceOutdoorThreshold) /
          (kMagVarianceIndoorThreshold - kMagVarianceOutdoorThreshold);
      outdoorScore = 0.75 - (ratio * 0.55);
    }

    return _ModuleScore(
      outdoorScore: outdoorScore,
      weight: weight,
      note: 'mag_var=${magVar.toStringAsFixed(1)}',
    );
  }

  /// Light Module: Evaluates illuminance while guarding against pocket & night false-positives.
  _ModuleScore _evaluateLightModule(IodSensorSnapshot snapshot) {
    if (!snapshot.hasLightSensor || snapshot.ambientLux == null) {
      return const _ModuleScore(
        outdoorScore: 0.5,
        weight: 0.0,
        note: 'no_light_sensor',
      );
    }

    final lux = snapshot.ambientLux!;

    // Guard 1: Night-time condition -> Light sensor is uninformative for outdoor sunlight
    if (snapshot.isNightTime) {
      return _ModuleScore(
        outdoorScore: 0.5,
        weight: 0.05,
        note: 'night_mode lux=${lux.toStringAsFixed(0)}',
      );
    }

    // Guard 2: Pocket / Bag mode -> Extreme dark while daytime indicates phone is stowed
    if (lux < kLuxPocketThreshold && snapshot.isScreenOff) {
      return _ModuleScore(
        outdoorScore: 0.5,
        weight: 0.05,
        note: 'pocket_stowed lux=${lux.toStringAsFixed(0)}',
      );
    }

    double outdoorScore;
    double weight = 0.45; // High confidence during daytime

    if (lux >= kLuxOutdoorOvercastThreshold) {
      // Overcast or direct daylight is strong proof of outdoor
      outdoorScore = math.min(1.0, 0.75 + (lux / 10000.0) * 0.25);
    } else if (lux <= kLuxIndoorTypicalMax) {
      // Indoor artificial illumination
      outdoorScore = math.max(0.05, (lux / kLuxIndoorTypicalMax) * 0.30);
    } else {
      // Intermediate (covered outdoor, large window, or twilight)
      final t = (lux - kLuxIndoorTypicalMax) /
          (kLuxOutdoorOvercastThreshold - kLuxIndoorTypicalMax);
      outdoorScore = 0.30 + (t * 0.45);
      weight = 0.30;
    }

    return _ModuleScore(
      outdoorScore: outdoorScore,
      weight: weight,
      note: 'lux=${lux.toStringAsFixed(0)}',
    );
  }

  /// GPS Module: Evaluates satellite availability, C/N0, and horizontal accuracy.
  /// Does NOT force weak GPS to mean Indoor; handles urban canyons with care.
  _ModuleScore _evaluateGpsModule(IodSensorSnapshot snapshot) {
    if (!snapshot.hasGpsFix && !snapshot.hasGnssStatus) {
      return const _ModuleScore(
        outdoorScore: 0.5,
        weight: 0.0,
        note: 'no_gps_telemetry',
      );
    }

    double outdoorScore = 0.5;
    double weight = 0.40;

    // 1. Hardware GNSS C/N0 telemetry if available (Highest physical fidelity)
    if (snapshot.hasGnssStatus && snapshot.top4Cn0DbHz != null) {
      final top4 = snapshot.top4Cn0DbHz!;
      if (top4 >= kCn0StrongDbHz) {
        outdoorScore = 0.85;
      } else if (top4 <= kCn0WeakDbHz) {
        outdoorScore = 0.15;
      } else {
        final t = (top4 - kCn0WeakDbHz) / (kCn0StrongDbHz - kCn0WeakDbHz);
        outdoorScore = 0.15 + (t * 0.70);
      }
    } else if (snapshot.hasGpsFix && snapshot.horizontalAccuracy != null) {
      // 2. Fallback to location accuracy radius
      final acc = snapshot.horizontalAccuracy!;
      if (acc <= kGpsAccuracyOutdoorMeters) {
        outdoorScore = 0.80;
      } else if (acc >= kGpsAccuracyIndoorMeters) {
        // Weak GPS alone does NOT automatically mean indoor; downweight confidence
        outdoorScore = 0.35;
        weight = 0.25;
      } else {
        final t = (acc - kGpsAccuracyOutdoorMeters) /
            (kGpsAccuracyIndoorMeters - kGpsAccuracyOutdoorMeters);
        outdoorScore = 0.80 - (t * 0.45);
      }
    }

    return _ModuleScore(
      outdoorScore: outdoorScore,
      weight: weight,
      note: snapshot.hasGnssStatus
          ? 'cn0=${snapshot.top4Cn0DbHz?.toStringAsFixed(1)}dB'
          : 'acc=${snapshot.horizontalAccuracy?.toStringAsFixed(1)}m',
    );
  }

  String _buildReasoningSummary(
    _ModuleScore imu,
    _ModuleScore light,
    _ModuleScore gps,
    double pOutdoor,
    IodSensorSnapshot s,
  ) {
    return 'AMV p_out=${(pOutdoor * 100).toStringAsFixed(1)}% '
        '[IMU: ${imu.note} w=${imu.weight.toStringAsFixed(2)}] '
        '[Light: ${light.note} w=${light.weight.toStringAsFixed(2)}] '
        '[GPS: ${gps.note} w=${gps.weight.toStringAsFixed(2)}]';
  }
}

class _ModuleScore {
  final double outdoorScore;
  final double weight;
  final String note;

  const _ModuleScore({
    required this.outdoorScore,
    required this.weight,
    required this.note,
  });
}
