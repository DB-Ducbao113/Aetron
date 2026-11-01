// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

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

  RawCsvRecord({
    required this.workoutId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    this.heading,
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

class SessionReplayResult {
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
  final double stationaryDriftMeters;
  final int sharpTurnsCount;

  const SessionReplayResult({
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
    required this.stationaryDriftMeters,
    required this.sharpTurnsCount,
  });
}

void main() {
  const distanceCalc = Distance();
  const engine = WorkoutTrackingEngine();

  List<RawCsvRecord> loadCsv() {
    final file = File('exports/aetron_raw_gps_combined.csv');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'exports/aetron_raw_gps_combined.csv must exist',
    );
    final lines = file.readAsLinesSync();
    expect(lines.length, greaterThan(1));

    final records = <RawCsvRecord>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 8) continue;
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
        ),
      );
    }
    return records;
  }

  SessionReplayResult runPipelineReplay({
    required String workoutId,
    required List<RawCsvRecord> rawRecords,
    required GpsFilterAlgorithm algorithm,
    required bool usePostPr15Pipeline,
  }) {
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

    for (final rec in rawRecords) {
      final pos = rec.toPosition();
      positionsList.add(pos);

      // Check raw gap from hardware stream
      if (previousRawTime != null) {
        final dt =
            pos.timestamp.difference(previousRawTime).inMilliseconds / 1000.0;
        if (dt > 5.0) {
          rawGapsCount++;
          rawGapsDurationSec += dt;
        }
      }
      previousRawTime = pos.timestamp;

      if (usePostPr15Pipeline) {
        // Post-PR 15: observe raw sensor timestamp continuity
        final isChronological = continuity.observe(pos.timestamp);
        if (!isChronological) {
          outOfOrderCount++;
          continue; // ignore stale/duplicate fix
        }
      }

      final decision = engine.evaluateGpsUpdate(
        position: pos,
        activityType: 'cycling',
        routePoints: pipeline.routePoints,
        currentLatLng: pipeline.routePoints.isNotEmpty
            ? pipeline.routePoints.last
            : null,
        distanceAnchorPoint: distanceAnchor,
        lastAcceptedPositionTime: lastAcceptedTime,
        rawGpsGapDurationSec: usePostPr15Pipeline
            ? continuity.pendingGapDurationSec
            : null,
        shouldResetAnchorOnResume: false,
      );

      final currentPoint = LatLng(pos.latitude, pos.longitude);

      if (decision.type == TrackingGpsDecisionType.seedRoute) {
        if (usePostPr15Pipeline) continuity.acknowledgeRouteAnchor();
        distanceAnchor = decision.livePoint;
        lastAcceptedTime = pos.timestamp;
        pipeline.seedRoute(decision.livePoint);
        latestSmoothed = decision.livePoint;
        acceptedCount++;
      } else if (decision.type == TrackingGpsDecisionType.acceptRoute) {
        if (usePostPr15Pipeline) continuity.acknowledgeRouteAnchor();
        final prevAccepted = pipeline.routePoints.last;
        final timeDelta = lastAcceptedTime != null
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
          lastSmoothedRoutePoint: pipeline.smoothedRoutePoints.isNotEmpty
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

    // Finalize distance calculation
    final totalDurationSec = rawRecords.isNotEmpty
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

    final savedDistanceKm = analysis.validDistanceKm > 0
        ? analysis.validDistanceKm
        : (analysis.totalDistanceKm > 0
              ? analysis.totalDistanceKm
              : liveDistanceM / 1000.0);

    // Calculate filtered polyline length
    var filteredDistanceM = 0.0;
    for (final seg in pipeline.smoothedRouteSegments) {
      for (var j = 1; j < seg.length; j++) {
        filteredDistanceM += distanceCalc.distance(seg[j - 1], seg[j]);
      }
    }

    final algoStr = algorithm == GpsFilterAlgorithm.ekf4State
        ? 'EKF 4-State'
        : 'Fixed-Alpha';

    return SessionReplayResult(
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
      stationaryDriftMeters: stationaryDriftM,
      sharpTurnsCount: sharpTurnsCount,
    );
  }

  test(
    'STEP 2: Paired Replay of 7 Real Field GPS Sessions (Fixed-Alpha vs EKF 4-State)',
    () {
      final allRecords = loadCsv();
      expect(
        allRecords.length,
        equals(10779),
        reason: 'Total raw records must equal 10,779',
      );

      final sessions = <String, List<RawCsvRecord>>{};
      for (final r in allRecords) {
        sessions.putIfAbsent(r.workoutId, () => []).add(r);
      }
      expect(
        sessions.length,
        equals(7),
        reason: 'Must contain exactly 7 workout sessions',
      );

      print(
        '\n=========================================================================================================================================',
      );
      print(
        'AETRON STEP 2: PAIRED FIELD REPLAY AUDIT (7 REAL CYCLING SESSIONS — 10,779 RAW FIXES)',
      );
      print(
        '=========================================================================================================================================',
      );
      print(
        '| Session ID | Fixes | Accepted | SoftRej | HardRej | OutOfOrder | Raw Gaps (>5s) | Route Gaps (Post-PR15) | Route Gaps (Pre-PR15) |',
      );
      print('|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|');

      final postResults =
          <String, ({SessionReplayResult fixed, SessionReplayResult ekf})>{};
      final preResults =
          <String, ({SessionReplayResult fixed, SessionReplayResult ekf})>{};

      for (final entry in sessions.entries) {
        final wid = entry.key;
        final recs = entry.value;

        final postFixed = runPipelineReplay(
          workoutId: wid,
          rawRecords: recs,
          algorithm: GpsFilterAlgorithm.fixedAlpha,
          usePostPr15Pipeline: true,
        );
        final postEkf = runPipelineReplay(
          workoutId: wid,
          rawRecords: recs,
          algorithm: GpsFilterAlgorithm.ekf4State,
          usePostPr15Pipeline: true,
        );
        postResults[wid] = (fixed: postFixed, ekf: postEkf);

        final preFixed = runPipelineReplay(
          workoutId: wid,
          rawRecords: recs,
          algorithm: GpsFilterAlgorithm.fixedAlpha,
          usePostPr15Pipeline: false,
        );
        final preEkf = runPipelineReplay(
          workoutId: wid,
          rawRecords: recs,
          algorithm: GpsFilterAlgorithm.ekf4State,
          usePostPr15Pipeline: false,
        );
        preResults[wid] = (fixed: preFixed, ekf: preEkf);

        final shortId = wid.substring(0, 8);
        print(
          '| $shortId... | ${recs.length.toString().padLeft(5)} | '
          '${postEkf.acceptedCount.toString().padLeft(8)} | '
          '${postEkf.softRejectedCount.toString().padLeft(7)} | '
          '${postEkf.hardRejectedCount.toString().padLeft(7)} | '
          '${postEkf.outOfOrderCount.toString().padLeft(10)} | '
          '${postEkf.rawGapsCount.toString().padLeft(14)} | '
          '${postEkf.routeBreakGapsCount.toString().padLeft(22)} | '
          '${preEkf.routeBreakGapsCount.toString().padLeft(21)} |',
        );
      }
      print(
        '=========================================================================================================================================\n',
      );

      print(
        '=========================================================================================================================================',
      );
      print(
        'PAIRED ALGORITHM METRIC COMPARISON ACROSS 7 SESSIONS (FIXED-ALPHA VS EKF 4-STATE)',
      );
      print(
        '=========================================================================================================================================',
      );
      print(
        '| Session ID | Live Dist (km) | Filtered (Fixed-Alpha) | Filtered (EKF 4-State) | Delta Filtered (m) | Saved Dist (km) | Parity Checked |',
      );
      print('|---|:---:|:---:|:---:|:---:|:---:|:---:|');

      var totalLiveKm = 0.0;
      var totalFilteredFixedKm = 0.0;
      var totalFilteredEkfKm = 0.0;
      var totalSavedKm = 0.0;

      for (final entry in sessions.entries) {
        final wid = entry.key;
        final pair = postResults[wid]!;
        final f = pair.fixed;
        final e = pair.ekf;

        // Invariants check: Pipeline parity
        expect(
          f.acceptedCount,
          equals(e.acceptedCount),
          reason: 'Parity: accepted points must be identical',
        );
        expect(
          f.softRejectedCount,
          equals(e.softRejectedCount),
          reason: 'Parity: soft rejects must be identical',
        );
        expect(
          f.hardRejectedCount,
          equals(e.hardRejectedCount),
          reason: 'Parity: hard rejects must be identical',
        );
        expect(
          f.liveDistanceKm,
          equals(e.liveDistanceKm),
          reason: 'Parity: live distance must be identical',
        );
        expect(
          f.savedDistanceKm,
          equals(e.savedDistanceKm),
          reason: 'Parity: saved distance must be identical',
        );
        expect(
          f.routeBreakGapsCount,
          equals(e.routeBreakGapsCount),
          reason: 'Parity: route break gaps must be identical',
        );

        final deltaMeters =
            (e.filteredRouteDistanceKm - f.filteredRouteDistanceKm) * 1000.0;

        totalLiveKm += f.liveDistanceKm;
        totalFilteredFixedKm += f.filteredRouteDistanceKm;
        totalFilteredEkfKm += e.filteredRouteDistanceKm;
        totalSavedKm += f.savedDistanceKm;

        final shortId = wid.substring(0, 8);
        print(
          '| $shortId... | ${f.liveDistanceKm.toStringAsFixed(3).padLeft(14)} | '
          '${f.filteredRouteDistanceKm.toStringAsFixed(3).padLeft(22)} | '
          '${e.filteredRouteDistanceKm.toStringAsFixed(3).padLeft(22)} | '
          '${(deltaMeters >= 0 ? "+${deltaMeters.toStringAsFixed(1)}" : deltaMeters.toStringAsFixed(1)).padLeft(18)} m | '
          '${f.savedDistanceKm.toStringAsFixed(3).padLeft(15)} | '
          '     100% PASS   |',
        );
      }
      print(
        '-----------------------------------------------------------------------------------------------------------------------------------------',
      );
      print(
        '| TOTAL (7)  | ${totalLiveKm.toStringAsFixed(3).padLeft(14)} | '
        '${totalFilteredFixedKm.toStringAsFixed(3).padLeft(22)} | '
        '${totalFilteredEkfKm.toStringAsFixed(3).padLeft(22)} | '
        '${("+${((totalFilteredEkfKm - totalFilteredFixedKm) * 1000.0).toStringAsFixed(1)}").padLeft(18)} m | '
        '${totalSavedKm.toStringAsFixed(3).padLeft(15)} |     100% PASS   |',
      );
      print(
        '=========================================================================================================================================\n',
      );
    },
  );
}
