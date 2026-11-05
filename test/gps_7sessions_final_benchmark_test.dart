// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/dbscan/dwell_route_simplifier.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/dbscan/gps_dbscan_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RawCsvRecord {
  final String workoutId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double accuracy;
  final double? heading;
  final String deviceSource;

  RawCsvRecord({
    required this.workoutId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    this.heading,
    required this.deviceSource,
  });

  Position toPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: 0.0,
      heading: heading ?? 0.0,
      headingAccuracy: 0.0,
      speed: speed,
      speedAccuracy: 0.0,
    );
  }
}

class DetailedSessionReplayResult {
  final String workoutId;
  final String algorithmName;
  final int totalRawFixes;
  final int outOfOrderCount;
  final int acceptedCount;
  final int softRejectedCount;
  final int hardRejectedCount;
  final int rawGapsCount;
  final double rawGapsDurationSec;
  final int routeBreakGapsCount;
  final double liveDistanceKm;
  final double filteredRouteDistanceKm;
  final double savedDistanceKm;
  final int routeSegmentsCount;
  final int smoothedPointsCount;
  final double stationaryDriftMeters;
  final int sharpTurnsCount;
  final int processingTimeMicroseconds;
  final int dbscanClustersCount;
  final double dbscanPhantomDriftMeters;
  final int dbscanSimplifiedPointsCount;

  const DetailedSessionReplayResult({
    required this.workoutId,
    required this.algorithmName,
    required this.totalRawFixes,
    required this.outOfOrderCount,
    required this.acceptedCount,
    required this.softRejectedCount,
    required this.hardRejectedCount,
    required this.rawGapsCount,
    required this.rawGapsDurationSec,
    required this.routeBreakGapsCount,
    required this.liveDistanceKm,
    required this.filteredRouteDistanceKm,
    required this.savedDistanceKm,
    required this.routeSegmentsCount,
    required this.smoothedPointsCount,
    required this.stationaryDriftMeters,
    required this.sharpTurnsCount,
    required this.processingTimeMicroseconds,
    this.dbscanClustersCount = 0,
    this.dbscanPhantomDriftMeters = 0.0,
    this.dbscanSimplifiedPointsCount = 0,
  });
}

DetailedSessionReplayResult executePipelineReplay({
  required String workoutId,
  required List<RawCsvRecord> rawRecords,
  required GpsFilterAlgorithm algorithm,
  bool applyDbscan = false,
}) {
  const distanceCalc = Distance();
  const engine = WorkoutTrackingEngine();

  final stopwatch = Stopwatch()..start();

  final continuity = GpsRawSignalContinuity(gapThresholdSec: 5.0);
  final smoother = GpsSmoothingService(algorithm: algorithm);
  final pipeline = GpsPipeline();

  var outOfOrderCount = 0;
  var acceptedCount = 0;
  var softRejectedCount = 0;
  var hardRejectedCount = 0;
  var rawGapsCount = 0;
  var rawGapsDurationSec = 0.0;
  var liveDistanceM = 0.0;
  var stationaryDriftM = 0.0;
  var sharpTurnsCount = 0;

  LatLng? distanceAnchor;
  DateTime? lastAcceptedTime;
  LatLng? latestSmoothed;
  DateTime? previousRawTime;

  final positionsList = <Position>[];
  final timedPoints = <TimedGpsPoint>[];

  for (final rec in rawRecords) {
    final pos = rec.toPosition();
    positionsList.add(pos);

    if (previousRawTime != null) {
      final dt =
          pos.timestamp.difference(previousRawTime).inMilliseconds / 1000.0;
      if (dt > 5.0) {
        rawGapsCount++;
        rawGapsDurationSec += dt;
      }
    }
    previousRawTime = pos.timestamp;

    final isChronological = continuity.observe(pos.timestamp);
    if (!isChronological) {
      outOfOrderCount++;
      continue;
    }

    final decision = engine.evaluateGpsUpdate(
      position: pos,
      activityType: 'cycling',
      routePoints: pipeline.routePoints,
      currentLatLng:
          pipeline.routePoints.isNotEmpty ? pipeline.routePoints.last : null,
      distanceAnchorPoint: distanceAnchor,
      lastAcceptedPositionTime: lastAcceptedTime,
      rawGpsGapDurationSec: continuity.pendingGapDurationSec,
      shouldResetAnchorOnResume: false,
    );

    final currentPoint = LatLng(pos.latitude, pos.longitude);

    if (decision.type == TrackingGpsDecisionType.seedRoute) {
      continuity.acknowledgeRouteAnchor();
      distanceAnchor = decision.livePoint;
      lastAcceptedTime = pos.timestamp;
      pipeline.seedRoute(decision.livePoint);
      latestSmoothed = decision.livePoint;
      acceptedCount++;
      timedPoints.add(
        TimedGpsPoint(
          point: decision.livePoint,
          timestamp: pos.timestamp,
          speedMs: pos.speed,
          accuracyMeters: pos.accuracy,
        ),
      );
    } else if (decision.type == TrackingGpsDecisionType.acceptRoute) {
      continuity.acknowledgeRouteAnchor();
      final prevAccepted = pipeline.routePoints.last;
      final timeDelta =
          lastAcceptedTime != null
              ? math.max(
                0.1,
                pos.timestamp.difference(lastAcceptedTime).inMilliseconds /
                    1000.0,
              )
              : 1.0;

      final update = smoother.smoothAcceptedPoint(
        activityType: 'cycling',
        acceptedPoint: currentPoint,
        previousAcceptedPoint: prevAccepted,
        previousSmoothedPoint: latestSmoothed,
        lastSmoothedRoutePoint:
            pipeline.smoothedRoutePoints.isNotEmpty
                ? pipeline.smoothedRoutePoints.last
                : null,
        accuracyMeters: pos.accuracy,
        speedMs: pos.speed,
        timeDeltaSec: timeDelta,
        gpsGapDurationSec: decision.gpsGapDurationSec,
      );

      pipeline.appendAcceptedSegment(
        routeCandidate: currentPoint,
        displayRoutePoint: update.smoothedPoint,
        shouldBreakRouteForDisplay: decision.shouldBreakRouteForDisplay,
        gpsGapDurationSec: decision.gpsGapDurationSec,
        shouldAppendSmoothedPoint: update.shouldAppendRoutePoint,
      );

      if (decision.shouldAddDistance) {
        liveDistanceM += decision.segmentMeters;
        if (pos.speed <= 0.8) {
          stationaryDriftM += decision.segmentMeters;
        }
      }

      distanceAnchor = decision.livePoint;
      lastAcceptedTime = pos.timestamp;
      latestSmoothed = update.smoothedPoint;
      acceptedCount++;

      timedPoints.add(
        TimedGpsPoint(
          point: update.smoothedPoint,
          timestamp: pos.timestamp,
          speedMs: pos.speed,
          accuracyMeters: pos.accuracy,
        ),
      );

      if (pos.heading > 0 && pipeline.routePoints.length >= 2) {
        final bPrev = distanceCalc.bearing(
          pipeline.routePoints[pipeline.routePoints.length - 2],
          currentPoint,
        );
        final turnAngle = (bPrev - pos.heading).abs();
        final normTurn = turnAngle > 180 ? 360 - turnAngle : turnAngle;
        if (normTurn > 28.0) sharpTurnsCount++;
      }
    } else {
      if (decision.outcome == GpsPointOutcome.softRejected) {
        softRejectedCount++;
      } else {
        hardRejectedCount++;
      }
    }
  }

  final totalDurationSec =
      rawRecords.isNotEmpty
          ? rawRecords.last.timestamp
              .difference(rawRecords.first.timestamp)
              .inSeconds
          : 0;

  final analysis = engine.analyzeGpsWorkout(
    GpsWorkoutAnalysisInput(
      rawPositions: positionsList,
      activityType: 'cycling',
      totalDurationSec: totalDurationSec,
      fallbackDistanceMeters: liveDistanceM,
    ),
  );

  final savedDistanceKm =
      analysis.validDistanceKm > 0
          ? analysis.validDistanceKm
          : (analysis.totalDistanceKm > 0
              ? analysis.totalDistanceKm
              : liveDistanceM / 1000.0);

  var filteredDistanceM = 0.0;
  var dbscanClustersCount = 0;
  var dbscanPhantomDriftMeters = 0.0;
  var dbscanSimplifiedPointsCount = 0;

  if (applyDbscan && timedPoints.isNotEmpty) {
    const simplifier = DwellRouteSimplifier(
      dbscanService: GpsDbscanService(
        epsilonMeters: 6.5,
        minDurationSeconds: 10.0,
        minPts: 4,
        stationarySpeedThreshold: 1.0,
      ),
    );
    final segments = <List<TimedGpsPoint>>[];
    var currentSeg = <TimedGpsPoint>[];
    for (var i = 0; i < timedPoints.length; i++) {
      if (i > 0 &&
          timedPoints[i]
                  .timestamp
                  .difference(timedPoints[i - 1].timestamp)
                  .inSeconds >
              5) {
        if (currentSeg.isNotEmpty) segments.add(currentSeg);
        currentSeg = <TimedGpsPoint>[];
      }
      currentSeg.add(timedPoints[i]);
    }
    if (currentSeg.isNotEmpty) segments.add(currentSeg);

    for (final seg in segments) {
      if (seg.isEmpty) continue;
      final (simplified, clusters, phantomDrift) =
          simplifier.simplifyTimedPoints(seg);
      dbscanClustersCount += clusters.length;
      dbscanPhantomDriftMeters += phantomDrift;
      dbscanSimplifiedPointsCount += simplified.length;

      for (var j = 1; j < simplified.length; j++) {
        filteredDistanceM += distanceCalc.distance(
          simplified[j - 1].point,
          simplified[j].point,
        );
      }
    }
  } else {
    for (final seg in pipeline.smoothedRouteSegments) {
      for (var j = 1; j < seg.length; j++) {
        filteredDistanceM += distanceCalc.distance(seg[j - 1], seg[j]);
      }
    }
  }

  stopwatch.stop();

  String algoStr;
  if (applyDbscan) {
    algoStr = 'EKF + DBSCAN';
  } else if (algorithm == GpsFilterAlgorithm.ekf4State) {
    algoStr = 'EKF 4-State';
  } else {
    algoStr = 'Fixed-Alpha Baseline';
  }

  return DetailedSessionReplayResult(
    workoutId: workoutId,
    algorithmName: algoStr,
    totalRawFixes: rawRecords.length,
    outOfOrderCount: outOfOrderCount,
    acceptedCount: acceptedCount,
    softRejectedCount: softRejectedCount,
    hardRejectedCount: hardRejectedCount,
    rawGapsCount: rawGapsCount,
    rawGapsDurationSec: rawGapsDurationSec,
    routeBreakGapsCount: pipeline.gpsGapSegments.length,
    liveDistanceKm: liveDistanceM / 1000.0,
    filteredRouteDistanceKm: filteredDistanceM / 1000.0,
    savedDistanceKm: savedDistanceKm,
    routeSegmentsCount: pipeline.smoothedRouteSegments.length,
    smoothedPointsCount: pipeline.smoothedRoutePoints.length,
    stationaryDriftMeters: stationaryDriftM,
    sharpTurnsCount: sharpTurnsCount,
    processingTimeMicroseconds: stopwatch.elapsedMicroseconds,
    dbscanClustersCount: dbscanClustersCount,
    dbscanPhantomDriftMeters: dbscanPhantomDriftMeters,
    dbscanSimplifiedPointsCount: dbscanSimplifiedPointsCount,
  );
}

void main() {
  test('Aetron Final 7-Session GPS Algorithm Benchmark Replay', () {
    final file = File(
      'exports/research_7_sessions/aetron_7_new_sessions_raw.csv',
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Raw GPS CSV for 7 new sessions must exist',
    );

    final bytes = file.readAsBytesSync();
    final actualSha256 = sha256.convert(bytes).toString();
    print('Dataset SHA-256: $actualSha256');

    final lines = utf8.decode(bytes).split('\n');
    final records = <RawCsvRecord>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 9) continue;
      records.add(
        RawCsvRecord(
          workoutId: parts[0],
          timestamp: DateTime.parse(parts[1]),
          latitude: double.parse(parts[2]),
          longitude: double.parse(parts[3]),
          altitude: double.tryParse(parts[4]) ?? 0.0,
          speed: double.tryParse(parts[5]) ?? 0.0,
          accuracy: double.tryParse(parts[6]) ?? 10.0,
          heading: parts[7].isNotEmpty ? double.tryParse(parts[7]) : null,
          deviceSource: parts[8],
        ),
      );
    }

    print('Total raw records parsed: ${records.length}');
    expect(records.length, equals(595));

    final sessions = <String, List<RawCsvRecord>>{};
    for (final r in records) {
      sessions.putIfAbsent(r.workoutId, () => []).add(r);
    }

    expect(sessions.length, equals(7));

    final sessionOrder = [
      '1e26939b-81cb-4903-b109-50c13d270c06',
      'e64747d3-9c21-4043-87fe-2cad7f4acedc',
      'dd24bacf-dfba-495d-bad7-2a23d9d7363e',
      'cd4da398-b5d2-48f0-9065-cb6dce5f9cbf',
      '5a777e45-7c8c-4f98-8f69-7b465034682d',
      '18c54f6e-4c4f-4b93-a114-51fbde02b6e1',
      '93af3737-54c0-456a-8e2a-62319ce898aa',
    ];

    print('\n=============================================================');
    print('          AETRON FINAL 7-SESSION BENCHMARK REPLAY RESULTS    ');
    print('=============================================================\n');

    // Warmup JIT to avoid skewing initial session processing times
    for (final wid in sessionOrder) {
      final recs = sessions[wid]!;
      executePipelineReplay(
        workoutId: wid,
        rawRecords: recs,
        algorithm: GpsFilterAlgorithm.fixedAlpha,
      );
      executePipelineReplay(
        workoutId: wid,
        rawRecords: recs,
        algorithm: GpsFilterAlgorithm.ekf4State,
      );
    }

    final baselineResults = <DetailedSessionReplayResult>[];
    final ekfResults = <DetailedSessionReplayResult>[];
    final dbscanResults = <DetailedSessionReplayResult>[];

    for (final wid in sessionOrder) {
      final recs = sessions[wid]!;
      final baseline = executePipelineReplay(
        workoutId: wid,
        rawRecords: recs,
        algorithm: GpsFilterAlgorithm.fixedAlpha,
      );
      final ekf = executePipelineReplay(
        workoutId: wid,
        rawRecords: recs,
        algorithm: GpsFilterAlgorithm.ekf4State,
      );
      final dbscan = executePipelineReplay(
        workoutId: wid,
        rawRecords: recs,
        algorithm: GpsFilterAlgorithm.ekf4State,
        applyDbscan: true,
      );

      baselineResults.add(baseline);
      ekfResults.add(ekf);
      dbscanResults.add(dbscan);

      print('--- Session $wid (${recs.length} raw points) ---');
      print(
        '  Baseline: dist=${(baseline.filteredRouteDistanceKm * 1000).toStringAsFixed(1)}m, live=${(baseline.liveDistanceKm * 1000).toStringAsFixed(1)}m, acc=${baseline.acceptedCount}, soft=${baseline.softRejectedCount}, hard=${baseline.hardRejectedCount}, breaks=${baseline.routeBreakGapsCount}, drift=${baseline.stationaryDriftMeters.toStringAsFixed(1)}m, time=${baseline.processingTimeMicroseconds}us',
      );
      print(
        '  EKF 4-St: dist=${(ekf.filteredRouteDistanceKm * 1000).toStringAsFixed(1)}m, live=${(ekf.liveDistanceKm * 1000).toStringAsFixed(1)}m, acc=${ekf.acceptedCount}, soft=${ekf.softRejectedCount}, hard=${ekf.hardRejectedCount}, breaks=${ekf.routeBreakGapsCount}, drift=${ekf.stationaryDriftMeters.toStringAsFixed(1)}m, time=${ekf.processingTimeMicroseconds}us',
      );
      print(
        '  EKF+DBSC: dist=${(dbscan.filteredRouteDistanceKm * 1000).toStringAsFixed(1)}m, clusters=${dbscan.dbscanClustersCount}, phantomDriftRemoved=${dbscan.dbscanPhantomDriftMeters.toStringAsFixed(1)}m, ptsAfterDBSCAN=${dbscan.dbscanSimplifiedPointsCount}, time=${dbscan.processingTimeMicroseconds}us',
      );

      // Verify parity across prevalidation
      expect(baseline.acceptedCount, equals(ekf.acceptedCount));
      expect(baseline.softRejectedCount, equals(ekf.softRejectedCount));
      expect(baseline.hardRejectedCount, equals(ekf.hardRejectedCount));
      expect(baseline.outOfOrderCount, equals(ekf.outOfOrderCount));
      expect(baseline.liveDistanceKm, equals(ekf.liveDistanceKm));
      expect(baseline.savedDistanceKm, equals(ekf.savedDistanceKm));
      expect(
        baseline.routeBreakGapsCount,
        equals(ekf.routeBreakGapsCount),
      );
    }

    print('\n=============================================================');
    print('                      SUMMARY COMPARISON                     ');
    print('=============================================================');

    final baseTotalDist = baselineResults.fold(
      0.0,
      (sum, r) => sum + r.filteredRouteDistanceKm,
    );
    final ekfTotalDist = ekfResults.fold(
      0.0,
      (sum, r) => sum + r.filteredRouteDistanceKm,
    );
    final dbscanTotalDist = dbscanResults.fold(
      0.0,
      (sum, r) => sum + r.filteredRouteDistanceKm,
    );

    final baseTotalTime = baselineResults.fold(
      0,
      (sum, r) => sum + r.processingTimeMicroseconds,
    );
    final ekfTotalTime = ekfResults.fold(
      0,
      (sum, r) => sum + r.processingTimeMicroseconds,
    );
    final dbscanTotalTime = dbscanResults.fold(
      0,
      (sum, r) => sum + r.processingTimeMicroseconds,
    );

    print(
      'Baseline Total Filtered Distance: ${(baseTotalDist * 1000).toStringAsFixed(1)} m',
    );
    print(
      'EKF 4-State Total Filtered Dist : ${(ekfTotalDist * 1000).toStringAsFixed(1)} m (Delta: ${((ekfTotalDist - baseTotalDist) * 1000).toStringAsFixed(1)} m)',
    );
    print(
      'EKF+DBSCAN Total Filtered Dist  : ${(dbscanTotalDist * 1000).toStringAsFixed(1)} m (Delta: ${((dbscanTotalDist - baseTotalDist) * 1000).toStringAsFixed(1)} m)',
    );
    print(
      'Processing Times: Baseline=${baseTotalTime}us, EKF=${ekfTotalTime}us, EKF+DBSCAN=${dbscanTotalTime}us',
    );
  });
}

