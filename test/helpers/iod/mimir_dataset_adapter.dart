import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'iod_benchmark_models.dart';

/// Aggregates raw Mimir / Android GNSS Logger sensor events within a 1-second epoch.
class _EpochData {
  final int epochSec;
  final Map<int, double> svCn0Map = {}; // Svid -> max Cn0 in epoch
  double? lat;
  double? lon;
  double? alt;
  double? speed;
  double? accuracy;
  double? bearing;
  bool hasFix = false;

  final List<double> accelMags = [];
  final List<double> magMags = [];
  int stepCount = 0;

  _EpochData(this.epochSec);

  IodSensorSnapshot toSnapshot() {
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(epochSec * 1000, isUtc: true);

    // GNSS metrics
    final svCount = svCn0Map.length;
    final hasGnss = svCount > 0;
    double? meanCn0;
    double? maxCn0;
    double? top4Cn0;
    int? usedInFix;

    if (hasGnss) {
      final sortedCn0 = svCn0Map.values.toList()..sort((a, b) => b.compareTo(a));
      maxCn0 = sortedCn0.first;
      meanCn0 = sortedCn0.reduce((a, b) => a + b) / sortedCn0.length;

      final topCount = math.min(4, sortedCn0.length);
      top4Cn0 = sortedCn0.take(topCount).reduce((a, b) => a + b) / topCount;

      // Count satellites above typical tracking sensitivity (>= 20 dB-Hz)
      usedInFix = sortedCn0.where((c) => c >= 20.0).length;
    }

    // IMU metrics
    final hasImu = accelMags.isNotEmpty && magMags.isNotEmpty;
    double? accelMean;
    double? accelVar;
    double? magMean;
    double? magVar;

    if (accelMags.isNotEmpty) {
      accelMean = accelMags.reduce((a, b) => a + b) / accelMags.length;
      if (accelMags.length > 1) {
        final sumSq = accelMags.fold<double>(
            0.0, (acc, val) => acc + math.pow(val - accelMean!, 2));
        accelVar = sumSq / (accelMags.length - 1);
      } else {
        accelVar = 0.0;
      }
    }

    if (magMags.isNotEmpty) {
      magMean = magMags.reduce((a, b) => a + b) / magMags.length;
      if (magMags.length > 1) {
        final sumSq = magMags.fold<double>(
            0.0, (acc, val) => acc + math.pow(val - magMean!, 2));
        magVar = sumSq / (magMags.length - 1);
      } else {
        magVar = 0.0;
      }
    }

    return IodSensorSnapshot(
      timestamp: timestamp,
      hasGnssStatus: hasGnss,
      satelliteCount: hasGnss ? svCount : null,
      usedInFixCount: usedInFix,
      meanCn0DbHz: meanCn0,
      maxCn0DbHz: maxCn0,
      top4Cn0DbHz: top4Cn0,
      hasGpsFix: hasFix,
      latitude: lat,
      longitude: lon,
      horizontalAccuracy: accuracy,
      speed: speed,
      altitude: alt,
      heading: bearing,
      hasLightSensor: false, // Mimir logger on GP7 did not capture lux; preserved as missing
      ambientLux: null,
      hasImuData: hasImu,
      accelMagnitudeMean: accelMean,
      accelVariance: accelVar,
      gyroMagnitudeMean: null,
      magneticMagnitudeMean: magMean,
      magneticVariance: magVar,
      stepDelta: stepCount,
      isNightTime: false,
      isScreenOff: false,
    );
  }
}

/// Parses raw Mimir GNSS / IMU sensor logs and maps them to [IodBenchmarkSample]s.
class MimirDatasetAdapter {
  /// Parses a Mimir log file and returns a list of 1-second [IodBenchmarkSample]s.
  static Future<List<IodBenchmarkSample>> parseLogFile({
    required File file,
    required String sessionId,
    required String scenarioId,
  }) async {
    final lines = await file.readAsLines();
    final Map<int, _EpochData> epochs = {};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split(',');
      if (parts.length < 2) continue;

      final tag = parts[0];

      if (tag == 'Raw') {
        // Raw,utcTimeMillis,TimeNanos,...,Svid,...,Cn0DbHz,...
        if (parts.length <= 16) continue;
        final millis = int.tryParse(parts[1]);
        final svid = int.tryParse(parts[11]);
        final cn0 = double.tryParse(parts[16]);
        if (millis != null && svid != null && cn0 != null) {
          final sec = millis ~/ 1000;
          final epoch = epochs.putIfAbsent(sec, () => _EpochData(sec));
          final existing = epoch.svCn0Map[svid];
          if (existing == null || cn0 > existing) {
            epoch.svCn0Map[svid] = cn0;
          }
        }
      } else if (tag == 'Fix') {
        // Fix,Provider,Latitude_decimalDegree,Longitude_decimalDegree,Altitude_meter,Speed_meterPerSecond,Accuracy_meter,Bearing_degree,UnixTime_millisecond,...
        if (parts.length <= 8) continue;
        final millis = int.tryParse(parts[8]);
        final lat = double.tryParse(parts[2]);
        final lon = double.tryParse(parts[3]);
        final alt = double.tryParse(parts[4]);
        final speed = double.tryParse(parts[5]);
        final acc = double.tryParse(parts[6]);
        final bearing = double.tryParse(parts[7]);
        if (millis != null && lat != null && lon != null) {
          final sec = millis ~/ 1000;
          final epoch = epochs.putIfAbsent(sec, () => _EpochData(sec));
          epoch.hasFix = true;
          epoch.lat = lat;
          epoch.lon = lon;
          epoch.alt = alt;
          epoch.speed = speed;
          epoch.accuracy = acc;
          epoch.bearing = bearing;
        }
      } else if (tag == 'ACC_UNCAL') {
        // ACC_UNCAL,utcTimeMillis,elapsedRealtime_nanosecond,x,y,z,...
        if (parts.length <= 5) continue;
        final millis = int.tryParse(parts[1]);
        final x = double.tryParse(parts[3]);
        final y = double.tryParse(parts[4]);
        final z = double.tryParse(parts[5]);
        if (millis != null && x != null && y != null && z != null) {
          final sec = millis ~/ 1000;
          final epoch = epochs.putIfAbsent(sec, () => _EpochData(sec));
          final mag = math.sqrt(x * x + y * y + z * z);
          epoch.accelMags.add(mag);
        }
      } else if (tag == 'MAG_UNCAL') {
        // MAG_UNCAL,utcTimeMillis,elapsedRealtime_nanosecond,x,y,z,...
        if (parts.length <= 5) continue;
        final millis = int.tryParse(parts[1]);
        final x = double.tryParse(parts[3]);
        final y = double.tryParse(parts[4]);
        final z = double.tryParse(parts[5]);
        if (millis != null && x != null && y != null && z != null) {
          final sec = millis ~/ 1000;
          final epoch = epochs.putIfAbsent(sec, () => _EpochData(sec));
          final mag = math.sqrt(x * x + y * y + z * z);
          epoch.magMags.add(mag);
        }
      } else if (tag == 'STEP_D') {
        // STEP_D,utcTimeMillis,...
        final millis = int.tryParse(parts[1]);
        if (millis != null) {
          final sec = millis ~/ 1000;
          final epoch = epochs.putIfAbsent(sec, () => _EpochData(sec));
          epoch.stepCount++;
        }
      }
    }

    // Sort epochs chronologically
    final sortedSecs = epochs.keys.toList()..sort();
    if (sortedSecs.isEmpty) return [];

    final samples = <IodBenchmarkSample>[];
    int seqIdx = 0;
    final totalEpochs = sortedSecs.length;

    for (int i = 0; i < totalEpochs; i++) {
      final sec = sortedSecs[i];
      final epoch = epochs[sec]!;
      final snapshot = epoch.toSnapshot();

      // Resolve ground truth according to published survey description
      final (IndoorOutdoorState gt, String envType, LabelProvenance prov) = _resolveGroundTruth(
        scenarioId: scenarioId,
        epochIndex: i,
        totalEpochs: totalEpochs,
        snapshot: snapshot,
      );

      samples.add(IodBenchmarkSample(
        sessionId: sessionId,
        sequenceIndex: seqIdx++,
        timestamp: snapshot.timestamp,
        snapshot: snapshot,
        groundTruth: gt,
        environmentType: envType,
        labelProvenance: prov,
      ));
    }

    return samples;
  }

  /// Assigns ground-truth environment state strictly derived from published dataset notes.
  ///
  /// - S1 (Open-sky): Walking on open road, field around, limited blockage -> 100% OUTDOOR (VERIFIED).
  /// - S4 (Urban canyon): High buildings, urban canyoning in Nantes city center -> 100% OUTDOOR (VERIFIED).
  /// - S2 (UGE Building): Initial outdoor walking -> Transition -> Ground/1st floor indoor -> Transition -> Return outdoor (INFERRED).
  /// - S3 (Nantes Train Station): North entrance outdoor -> Transition -> Glass mezzanine light indoor (INFERRED).
  /// - S5 (Atlantis Shopping Center): SE entrance outdoor -> Transition -> Indoor shopping center loops -> Transition -> Exit outdoor (INFERRED).
  static (IndoorOutdoorState, String, LabelProvenance) _resolveGroundTruth({
    required String scenarioId,
    required int epochIndex,
    required int totalEpochs,
    required IodSensorSnapshot snapshot,
  }) {
    switch (scenarioId.toUpperCase()) {
      case 'S1':
        return (IndoorOutdoorState.outdoor, 'open_sky_outdoor', LabelProvenance.verifiedGroundTruth);

      case 'S4':
        return (IndoorOutdoorState.outdoor, 'urban_canyon_outdoor', LabelProvenance.verifiedGroundTruth);

      case 'S2':
        // UGE Building survey:
        // Note: Authors did NOT record exact doorway crossing timestamps.
        // Macro progression is strictly exploratory and unverified.
        final progress = epochIndex / totalEpochs;
        if (progress < 0.15 || progress > 0.85) {
          return (IndoorOutdoorState.outdoor, 'uge_approach_road', LabelProvenance.exploratoryUnverifiedMacro);
        } else if ((progress >= 0.15 && progress < 0.20) ||
            (progress > 0.80 && progress <= 0.85)) {
          return (IndoorOutdoorState.transition, 'uge_entrance_boundary', LabelProvenance.exploratoryUnverifiedMacro);
        } else {
          return (IndoorOutdoorState.indoor, 'uge_building_indoor', LabelProvenance.exploratoryUnverifiedMacro);
        }

      case 'S3':
        // Nantes train station:
        // Note: Authors did NOT record exact doorway crossing timestamps.
        final progress = epochIndex / totalEpochs;
        if (progress < 0.15) {
          return (IndoorOutdoorState.outdoor, 'station_north_entrance', LabelProvenance.exploratoryUnverifiedMacro);
        } else if (progress < 0.23) {
          return (IndoorOutdoorState.transition, 'station_entrance_boundary', LabelProvenance.exploratoryUnverifiedMacro);
        } else {
          return (IndoorOutdoorState.indoor, 'station_mezzanine_light_indoor', LabelProvenance.exploratoryUnverifiedMacro);
        }

      case 'S5':
        // Atlantis shopping center:
        // Note: Authors did NOT record exact doorway crossing timestamps.
        final progress = epochIndex / totalEpochs;
        if (progress < 0.10 || progress > 0.90) {
          return (IndoorOutdoorState.outdoor, 'atlantis_outdoor_entrance', LabelProvenance.exploratoryUnverifiedMacro);
        } else if ((progress >= 0.10 && progress < 0.15) ||
            (progress > 0.85 && progress <= 0.90)) {
          return (IndoorOutdoorState.transition, 'atlantis_door_boundary', LabelProvenance.exploratoryUnverifiedMacro);
        } else {
          return (IndoorOutdoorState.indoor, 'atlantis_shopping_mall', LabelProvenance.exploratoryUnverifiedMacro);
        }

      default:
        return (IndoorOutdoorState.unknown, 'unspecified_scenario', LabelProvenance.unlabeled);
    }
  }
}
