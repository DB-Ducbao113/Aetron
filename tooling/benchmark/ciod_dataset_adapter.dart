import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'iod_benchmark_models.dart';

/// Dataset adapter for the University of Cambridge CIOD Benchmark:
/// "Data Supporting IOD DL MTSC JIoT" (Bakirtzis et al., DOI: 10.17863/CAM.82668).
///
/// Published Specification & Provenance:
/// - Source: Cambridge Apollo Repository (DSpace 7 UUID: 7e5b7161-c3a9-465a-8595-c04cb356ecfa)
/// - License: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 (CC BY-NC-SA 4.0).
/// - Format: CSV (~104.88 MB; 109,975,945 bytes; 1,473,287 rows). MD5: c44eb2fee44d853fed9c8b0f4ba1c42b.
/// - Exact Schema:
///   `RSRP,RSRQ,Light,Mag,Acc,Sound,Proximity,Daytime,New_Recording,IO`
///   * Sequence separator: `New_Recording` (1 = start of new session, 0 = continuing)
///   * Ground truth target: `IO` (1.0 = Indoor [913,917 rows], 0.0 = Outdoor [559,370 rows])
///   * Features: `Light` (lux), `Mag` (uT scalar), `Acc` (m/s^2 scalar), `Daytime` (1/0), `Proximity` (cm)
///   * Missing signals: GNSS C/N0 is not recorded in CIOD; strictly preserved as missing (null/false).
class CiodDatasetAdapter {
  /// Parses Cambridge CIOD CSV file and returns benchmark samples grouped by independent sessions.
  static Future<List<IodBenchmarkSample>> parseCsvFile({
    required File file,
    int maxSessions = 50, // evaluate first N sessions or all if 0
    int maxSamplesPerSession = 500, // sample cap per session for fast benchmark execution
  }) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) return [];

    final headerLine = lines.first.trim();
    final headers = headerLine.split(',').map((h) => h.trim()).toList();

    // Identify key column indices
    int newSeqIdx = -1;
    int labelIdx = -1;
    int luxIdx = -1;
    int magScalarIdx = -1;
    int accScalarIdx = -1;
    int daytimeIdx = -1;
    int proximityIdx = -1;

    // 3-axis fallback indices
    int accXIdx = -1, accYIdx = -1, accZIdx = -1;
    int magXIdx = -1, magYIdx = -1, magZIdx = -1;
    int gyrXIdx = -1, gyrYIdx = -1, gyrZIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      if (h == 'new_recording' || h == 'new_seq' || h == 'new_sequence' || h == 'sequence_id') {
        newSeqIdx = i;
      } else if (h == 'io' || h == 'label' || h == 'target' || h == 'class' || h == 'environment') {
        labelIdx = i;
      } else if (h == 'light' || h == 'lux') {
        luxIdx = i;
      } else if (h == 'mag') {
        magScalarIdx = i;
      } else if (h == 'acc') {
        accScalarIdx = i;
      } else if (h == 'daytime') {
        daytimeIdx = i;
      } else if (h == 'proximity') {
        proximityIdx = i;
      } else if (h.contains('acc') && h.contains('x')) {
        accXIdx = i;
      } else if (h.contains('acc') && h.contains('y')) {
        accYIdx = i;
      } else if (h.contains('acc') && h.contains('z')) {
        accZIdx = i;
      } else if (h.contains('mag') && h.contains('x')) {
        magXIdx = i;
      } else if (h.contains('mag') && h.contains('y')) {
        magYIdx = i;
      } else if (h.contains('mag') && h.contains('z')) {
        magZIdx = i;
      } else if (h.contains('gyr') && h.contains('x')) {
        gyrXIdx = i;
      } else if (h.contains('gyr') && h.contains('y')) {
        gyrYIdx = i;
      } else if (h.contains('gyr') && h.contains('z')) {
        gyrZIdx = i;
      }
    }

    if (labelIdx == -1) labelIdx = headers.length - 1;

    final samples = <IodBenchmarkSample>[];
    int currentSessionId = 1;
    int sampleIdxInSession = 0;
    int samplesInCurrentSession = 0;
    DateTime simulatedTime = DateTime.utc(2022, 7, 1, 10, 0, 0);
    final recentMags = <double>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length <= labelIdx) continue;

      // Check session boundary
      if (newSeqIdx != -1 && newSeqIdx < parts.length) {
        final seqVal = double.tryParse(parts[newSeqIdx]) ?? 0;
        if (seqVal == 1.0 && i > 1) {
          currentSessionId++;
          sampleIdxInSession = 0;
          samplesInCurrentSession = 0;
          recentMags.clear();
          if (maxSessions > 0 && currentSessionId > maxSessions) {
            break; // Finished requested session quota
          }
        }
      }

      // Check per-session sample limit to avoid quadratic memory and runtime
      if (maxSamplesPerSession > 0 && samplesInCurrentSession >= maxSamplesPerSession) {
        continue;
      }

      // Parse ground-truth label: 1 = Indoor, 0 = Outdoor
      final rawLabel = double.tryParse(parts[labelIdx]) ?? -1;
      final IndoorOutdoorState groundTruth;
      if (rawLabel == 1.0) {
        groundTruth = IndoorOutdoorState.indoor;
      } else if (rawLabel == 0.0) {
        groundTruth = IndoorOutdoorState.outdoor;
      } else {
        groundTruth = IndoorOutdoorState.unknown;
      }

      // Parse light (lux)
      double? lux;
      if (luxIdx != -1 && luxIdx < parts.length) {
        lux = double.tryParse(parts[luxIdx]);
      }

      // Parse Accelerometer magnitude
      double? accMag;
      if (accScalarIdx != -1 && accScalarIdx < parts.length) {
        accMag = double.tryParse(parts[accScalarIdx]);
      } else if (accXIdx != -1 && accYIdx != -1 && accZIdx != -1) {
        final ax = double.tryParse(parts[accXIdx]) ?? 0.0;
        final ay = double.tryParse(parts[accYIdx]) ?? 0.0;
        final az = double.tryParse(parts[accZIdx]) ?? 0.0;
        accMag = IodSensorSnapshot.computeVectorMagnitude(ax, ay, az);
      }

      // Parse Magnetometer magnitude
      double? magMag;
      if (magScalarIdx != -1 && magScalarIdx < parts.length) {
        magMag = double.tryParse(parts[magScalarIdx]);
      } else if (magXIdx != -1 && magYIdx != -1 && magZIdx != -1) {
        final mx = double.tryParse(parts[magXIdx]) ?? 0.0;
        final my = double.tryParse(parts[magYIdx]) ?? 0.0;
        final mz = double.tryParse(parts[magZIdx]) ?? 0.0;
        magMag = IodSensorSnapshot.computeMagneticMagnitude(mx, my, mz);
      }

      // Compute sliding-window empirical magnetic variance (w=5)
      double? magVar;
      if (magMag != null) {
        recentMags.add(magMag);
        if (recentMags.length > 5) recentMags.removeAt(0);
        if (recentMags.length > 1) {
          final mean = recentMags.reduce((a, b) => a + b) / recentMags.length;
          final sumSq = recentMags.fold<double>(0.0, (acc, v) => acc + math.pow(v - mean, 2));
          magVar = sumSq / (recentMags.length - 1);
        } else {
          magVar = 1.0; // Baseline quiescent variance
        }
      }

      // Parse Gyroscope magnitude if present
      double? gyrMag;
      if (gyrXIdx != -1 && gyrYIdx != -1 && gyrZIdx != -1) {
        final gx = double.tryParse(parts[gyrXIdx]) ?? 0.0;
        final gy = double.tryParse(parts[gyrYIdx]) ?? 0.0;
        final gz = double.tryParse(parts[gyrZIdx]) ?? 0.0;
        gyrMag = IodSensorSnapshot.computeVectorMagnitude(gx, gy, gz);
      }

      // Parse contextual indicators
      bool isNight = false;
      if (daytimeIdx != -1 && daytimeIdx < parts.length) {
        final dt = double.tryParse(parts[daytimeIdx]) ?? 1.0;
        isNight = dt == 0.0;
      }

      bool isPocket = false;
      if (proximityIdx != -1 && proximityIdx < parts.length) {
        final prox = double.tryParse(parts[proximityIdx]) ?? 5.0;
        isPocket = prox < 2.0; // Covered proximity sensor
      }

      final hasImu = accMag != null || magMag != null || gyrMag != null;

      final snapshot = IodSensorSnapshot(
        timestamp: simulatedTime.add(Duration(seconds: sampleIdxInSession)),
        hasGnssStatus: false, // Preserved as missing; never fabricated
        satelliteCount: null,
        usedInFixCount: null,
        meanCn0DbHz: null,
        maxCn0DbHz: null,
        top4Cn0DbHz: null,
        hasGpsFix: false,
        latitude: null,
        longitude: null,
        horizontalAccuracy: null,
        speed: null,
        altitude: null,
        heading: null,
        hasLightSensor: lux != null,
        ambientLux: lux,
        hasImuData: hasImu,
        accelMagnitudeMean: accMag,
        accelVariance: 0.5,
        gyroMagnitudeMean: gyrMag,
        magneticMagnitudeMean: magMag,
        magneticVariance: magVar,
        stepDelta: 1,
        isNightTime: isNight,
        isScreenOff: isPocket,
      );

      samples.add(IodBenchmarkSample(
        sessionId: 'CIOD_session_$currentSessionId',
        sequenceIndex: sampleIdxInSession++,
        timestamp: snapshot.timestamp,
        snapshot: snapshot,
        groundTruth: groundTruth,
        environmentType: groundTruth == IndoorOutdoorState.indoor ? 'cambridge_indoor' : 'cambridge_outdoor',
      ));
      samplesInCurrentSession++;
    }

    return samples;
  }
}
