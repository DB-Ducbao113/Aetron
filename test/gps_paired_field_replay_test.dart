// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const String kExpectedDatasetSha256 =
    '4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5';

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

  SessionReplayResult runPipelineReplay({
    required String workoutId,
    required List<RawCsvRecord> rawRecords,
    required GpsFilterAlgorithm algorithm,
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
        currentLatLng: pipeline.routePoints.isNotEmpty
            ? pipeline.routePoints.last
            : null,
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
      } else if (decision.type == TrackingGpsDecisionType.acceptRoute) {
        continuity.acknowledgeRouteAnchor();
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

  group('Aetron Step 2 Paired Replay Verification', () {
    test(
      'Safe Fixture-Based Paired Replay (Always reproducible without local CSV)',
      () {
        final t0 = DateTime.utc(2026, 10, 1, 8, 0, 0);
        final syntheticRecords = <RawCsvRecord>[];
        for (var s = 0; s < 30; s++) {
          syntheticRecords.add(
            RawCsvRecord(
              workoutId: 'fixture-synth-001',
              timestamp: t0.add(Duration(seconds: s)),
              latitude: 10.77 + s * 0.00003,
              longitude: 106.69 + (s > 15 ? (s - 15) * 0.00003 : 0.0),
              altitude: 10.0,
              speed: 4.5,
              accuracy: 5.0,
              heading: s > 15 ? 45.0 : 0.0,
            ),
          );
        }

        final fixedRes = runPipelineReplay(
          workoutId: 'fixture-synth-001',
          rawRecords: syntheticRecords,
          algorithm: GpsFilterAlgorithm.fixedAlpha,
        );
        final ekfRes = runPipelineReplay(
          workoutId: 'fixture-synth-001',
          rawRecords: syntheticRecords,
          algorithm: GpsFilterAlgorithm.ekf4State,
        );

        expect(fixedRes.acceptedCount, equals(ekfRes.acceptedCount));
        expect(fixedRes.liveDistanceKm, equals(ekfRes.liveDistanceKm));
        expect(fixedRes.savedDistanceKm, equals(ekfRes.savedDistanceKm));
        expect(
          fixedRes.routeBreakGapsCount,
          equals(ekfRes.routeBreakGapsCount),
        );
        expect(fixedRes.acceptedCount, greaterThan(15));
      },
    );

    test(
      'Local Dataset Replay on 7 Real Field GPS Sessions (When exports CSV is present)',
      () {
        final file = File('exports/aetron_raw_gps_combined.csv');
        if (!file.existsSync()) {
          print(
            '[SKIP] exports/aetron_raw_gps_combined.csv not present in working tree. Test skipped safely.',
          );
          return;
        }

        final bytes = file.readAsBytesSync();
        final actualSha256 = sha256.convert(bytes).toString();
        expect(
          actualSha256,
          equals(kExpectedDatasetSha256),
          reason: 'Dataset SHA-256 checksum must match verified record',
        );

        final lines = utf8.decode(bytes).split('\n');
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

        expect(
          records.length,
          equals(10779),
          reason: 'Total raw records must equal exactly 10,779',
        );

        final sessions = <String, List<RawCsvRecord>>{};
        for (final r in records) {
          sessions.putIfAbsent(r.workoutId, () => []).add(r);
        }
        expect(
          sessions.length,
          equals(7),
          reason: 'Must contain exactly 7 workout sessions',
        );

        var sumAccepted = 0;
        var sumSoft = 0;
        var sumHard = 0;
        var sumOutOfOrder = 0;
        var sumRawGaps = 0;
        var sumRouteBreaks = 0;

        for (final entry in sessions.entries) {
          final wid = entry.key;
          final recs = entry.value;

          final fixed = runPipelineReplay(
            workoutId: wid,
            rawRecords: recs,
            algorithm: GpsFilterAlgorithm.fixedAlpha,
          );
          final ekf = runPipelineReplay(
            workoutId: wid,
            rawRecords: recs,
            algorithm: GpsFilterAlgorithm.ekf4State,
          );

          // Assert 100% parity across validation and distance accumulation
          expect(fixed.acceptedCount, equals(ekf.acceptedCount));
          expect(fixed.softRejectedCount, equals(ekf.softRejectedCount));
          expect(fixed.hardRejectedCount, equals(ekf.hardRejectedCount));
          expect(fixed.outOfOrderCount, equals(ekf.outOfOrderCount));
          expect(fixed.liveDistanceKm, equals(ekf.liveDistanceKm));
          expect(fixed.savedDistanceKm, equals(ekf.savedDistanceKm));
          expect(fixed.routeBreakGapsCount, equals(ekf.routeBreakGapsCount));

          sumAccepted += fixed.acceptedCount;
          sumSoft += fixed.softRejectedCount;
          sumHard += fixed.hardRejectedCount;
          sumOutOfOrder += fixed.outOfOrderCount;
          sumRawGaps += fixed.rawGapsCount;
          sumRouteBreaks += fixed.routeBreakGapsCount;
        }

        // Exact arithmetic audit check:
        // accepted + softRejected + hardRejected + outOfOrder == totalRawFixes
        final totalAccounted = sumAccepted + sumSoft + sumHard + sumOutOfOrder;
        expect(
          totalAccounted,
          equals(10779),
          reason: 'All 10,779 raw fixes must be accounted for without loss',
        );
        expect(sumAccepted, equals(8097));
        expect(sumSoft, equals(2254));
        expect(sumHard, equals(379));
        expect(sumOutOfOrder, equals(49));
        expect(sumRawGaps, equals(89));
        expect(sumRouteBreaks, equals(47));
      },
    );
  });
}
