import 'dart:async';
import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

final workoutRecordingCoordinatorProvider =
    Provider.autoDispose<WorkoutRecordingCoordinator>((ref) {
      return WorkoutRecordingCoordinator(
        rawTracking: ref.watch(rawTrackingRemoteDataSourceProvider),
        workoutRemote: ref.watch(workoutRemoteDataSourceProvider),
        processingRemote: ref.watch(workoutProcessingRemoteDataSourceProvider),
        currentUserId: () => ref.read(currentUserIdProvider),
      );
    });

class WorkoutRecordingCoordinator {
  WorkoutRecordingCoordinator({
    required RawTrackingRemoteDataSource rawTracking,
    required WorkoutRemoteDataSource workoutRemote,
    required WorkoutProcessingRemoteDataSource processingRemote,
    required String? Function() currentUserId,
  }) : _rawTracking = rawTracking,
       _workoutRemote = workoutRemote,
       _processingRemote = processingRemote,
       _currentUserId = currentUserId;

  final RawTrackingRemoteDataSource _rawTracking;
  final WorkoutRemoteDataSource _workoutRemote;
  final WorkoutProcessingRemoteDataSource _processingRemote;
  final String? Function() _currentUserId;
  final WorkoutTrackingEngine _trackingEngine = const WorkoutTrackingEngine();

  static const int _kRawGpsFlushThreshold = 24;
  static const int _kRawStepFlushThreshold = 6;
  static const Duration _kRawTrackingFlushInterval = Duration(seconds: 5);
  static const Duration _kLiveRouteSnapshotInterval = Duration(seconds: 5);

  final List<_BufferedRawGpsPoint> _pendingRawGpsPoints = [];
  final List<_BufferedRawStepInterval> _pendingRawStepIntervals = [];

  DateTime? _lastRawStepIntervalEnd;
  DateTime? _lastLiveRouteSnapshotSyncAt;
  String? _activeWorkoutId;
  bool _remoteWorkoutShellReady = false;
  bool _isFlushingRawGpsPoints = false;
  bool _isFlushingRawStepIntervals = false;
  bool _isSyncingLiveRouteSnapshot = false;
  bool _hasLocalStorageError = false;
  Timer? _rawTrackingFlushTimer;
  _PendingLiveRouteSnapshot? _pendingLiveRouteSnapshot;

  int get pendingRawGpsPointCount => _pendingRawGpsPoints.length;
  int get pendingRawStepIntervalCount => _pendingRawStepIntervals.length;
  bool get hasLocalStorageError => _hasLocalStorageError;

  void reset() {
    if (_pendingRawGpsPoints.isNotEmpty ||
        _pendingRawStepIntervals.isNotEmpty) {
      debugPrint(
        '[WorkoutRecordingCoordinator] reset called with '
        '${_pendingRawGpsPoints.length} GPS points and '
        '${_pendingRawStepIntervals.length} step intervals pending in memory '
        '(persisted in LocalDB).',
      );
    }
    _pendingRawGpsPoints.clear();
    _pendingRawStepIntervals.clear();
    _pendingLiveRouteSnapshot = null;
    _lastRawStepIntervalEnd = null;
    _lastLiveRouteSnapshotSyncAt = null;
    _activeWorkoutId = null;
    _remoteWorkoutShellReady = false;
    _isFlushingRawGpsPoints = false;
    _isFlushingRawStepIntervals = false;
    _isSyncingLiveRouteSnapshot = false;
    _hasLocalStorageError = false;
    _rawTrackingFlushTimer?.cancel();
    _rawTrackingFlushTimer = null;
  }

  Future<void> createRemoteWorkoutShell({
    required String? sessionId,
    required DateTime? startedAt,
    required String activityType,
    required String mode,
  }) async {
    final userId = _currentUserId();
    if (sessionId == null || startedAt == null || userId == null) return;

    try {
      await _workoutRemote.createSessionShell(
        id: sessionId,
        userId: userId,
        activityType: activityType,
        mode: mode,
        startedAt: startedAt,
        createdAt: startedAt,
      );
      _activeWorkoutId = sessionId;
      _remoteWorkoutShellReady = true;
      debugPrint('[Workout][RemoteShell] ready for session $sessionId');
      _ensurePeriodicFlushTimer();
      await flushPendingRawTracking(workoutId: sessionId, force: true);
      await syncLiveRouteSnapshot(force: true);
    } catch (e) {
      debugPrint('[Workout][RemoteShell] create failed for $sessionId: $e');
    }
  }

  void bufferRawGpsPoint(
    Position position, {
    required String? workoutId,
    String deviceSource = 'geolocator_position_stream',
  }) {
    if (workoutId != null && workoutId.isNotEmpty) {
      final localPoint = LocalGPSPoint()
        ..sessionId = workoutId
        ..localWorkoutId = 0
        ..timestamp = position.timestamp.toUtc()
        ..latitude = position.latitude
        ..longitude = position.longitude
        ..altitude = position.altitude
        ..speed = position.speed >= 0 ? position.speed : null
        ..accuracy = position.accuracy >= 0 ? position.accuracy : null
        ..heading = position.heading >= 0 ? position.heading : null
        ..deviceSource = deviceSource
        ..confidence = _trackingEngine.confidenceForAccuracy(
          position.accuracy >= 0 ? position.accuracy : null,
        );
      unawaited(
        LocalDB.saveRawGpsPoint(localPoint).catchError((err, st) {
          _hasLocalStorageError = true;
          debugPrint(
            '[Workout][StorageError] Failed to persist raw GPS point locally: $err',
          );
        }),
      );
    }

    _pendingRawGpsPoints.add(
      _BufferedRawGpsPoint(
        timestamp: position.timestamp.toUtc(),
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed >= 0 ? position.speed : null,
        accuracy: position.accuracy >= 0 ? position.accuracy : null,
        heading: position.heading >= 0 ? position.heading : null,
        deviceSource: deviceSource,
      ),
    );
    debugPrint(
      '[Workout][RawTracking] buffered raw fix #$pendingRawGpsPointCount: '
      'lat=${position.latitude.toStringAsFixed(6)}, '
      'lng=${position.longitude.toStringAsFixed(6)}, '
      'acc=${position.accuracy.toStringAsFixed(1)}m, '
      'time=${position.timestamp.toUtc().toIso8601String()}',
    );
    _maybeFlushRawTrackingBuffers(workoutId);
  }

  void bufferRawStepInterval(
    int stepsCount, {
    required DateTime? startedAt,
    required String? workoutId,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final intervalStart = (_lastRawStepIntervalEnd ?? startedAt ?? nowUtc)
        .toUtc();
    final intervalEnd = nowUtc.isAfter(intervalStart)
        ? nowUtc
        : intervalStart.add(const Duration(milliseconds: 1));

    if (workoutId != null && workoutId.isNotEmpty) {
      final localInterval = LocalStepInterval()
        ..sessionId = workoutId
        ..intervalStart = intervalStart
        ..intervalEnd = intervalEnd
        ..stepsCount = stepsCount
        ..deviceSource = 'pedometer_step_count_stream';
      unawaited(
        LocalDB.saveRawStepInterval(localInterval).catchError((err, st) {
          _hasLocalStorageError = true;
          debugPrint(
            '[Workout][StorageError] Failed to persist raw step interval locally: $err',
          );
        }),
      );
    }

    _pendingRawStepIntervals.add(
      _BufferedRawStepInterval(
        intervalStart: intervalStart,
        intervalEnd: intervalEnd,
        stepsCount: stepsCount,
        deviceSource: 'pedometer_step_count_stream',
      ),
    );
    _lastRawStepIntervalEnd = intervalEnd;
    _maybeFlushRawTrackingBuffers(workoutId);
  }

  void markRemoteWorkoutShellReady() {
    _remoteWorkoutShellReady = true;
    _ensurePeriodicFlushTimer();
    final workoutId = _activeWorkoutId;
    if (workoutId != null && workoutId.isNotEmpty) {
      unawaited(flushPendingRawTracking(workoutId: workoutId, force: true));
    }
  }

  void queueLiveRouteSnapshot({
    required String? workoutId,
    required List<List<LatLng>> routeSegments,
    required double lastGpsGapDurationSec,
    required bool isGpsSignalWeak,
  }) {
    if (workoutId == null || workoutId.isEmpty) return;

    _activeWorkoutId = workoutId;

    final now = DateTime.now();
    final lastSync = _lastLiveRouteSnapshotSyncAt;
    if (lastSync != null &&
        now.difference(lastSync) < _kLiveRouteSnapshotInterval) {
      return;
    }

    _pendingLiveRouteSnapshot = _PendingLiveRouteSnapshot(
      workoutId: workoutId,
      routeSegments: routeSegments
          .where((segment) => segment.isNotEmpty)
          .map((segment) => List<LatLng>.from(segment))
          .toList(growable: false),
      lastGpsGapDurationSec: lastGpsGapDurationSec,
      isGpsSignalWeak: isGpsSignalWeak,
    );
    _ensurePeriodicFlushTimer();
    unawaited(syncLiveRouteSnapshot(force: false));
  }

  Future<void> flushPendingRawTracking({
    required String workoutId,
    required bool force,
  }) async {
    if (kIsWeb) return; // web has no Isar; raw points uploaded via live snapshot
    if (!_remoteWorkoutShellReady) return;

    // Handle concurrent forced flush by waiting briefly for any active flush to complete
    if (force) {
      var waitCycles = 0;
      while ((_isFlushingRawGpsPoints || _isFlushingRawStepIntervals) &&
          waitCycles < 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitCycles++;
      }
    }

    if ((force || _pendingRawGpsPoints.length >= _kRawGpsFlushThreshold) &&
        !_isFlushingRawGpsPoints) {
      List<RawGpsPointPayload> payloadsToUpload = [];
      DateTime? maxTimestamp;
      List<int>? localIdsToMark;
      int memoryBatchCount = 0;

      if (_pendingRawGpsPoints.isNotEmpty) {
        final memoryBatch =
            List<_BufferedRawGpsPoint>.from(_pendingRawGpsPoints);
        memoryBatchCount = memoryBatch.length;
        payloadsToUpload = memoryBatch
            .map((point) => point.toPayload(workoutId))
            .toList(growable: false);
        maxTimestamp = memoryBatch.last.timestamp;
      } else if (force) {
        final unsyncedLocal =
            await LocalDB.getUnsyncedGpsPointsForSession(workoutId);
        if (unsyncedLocal.isNotEmpty) {
          localIdsToMark = unsyncedLocal.map((p) => p.id).toList();
          payloadsToUpload =
              unsyncedLocal.map(LocalDB.rawGpsPointToPayload).toList();
          maxTimestamp = unsyncedLocal.last.timestamp;
        }
      }

      if (payloadsToUpload.isNotEmpty) {
        _isFlushingRawGpsPoints = true;
        try {
          await _rawTracking.saveRawGpsPoints(payloadsToUpload);
          if (memoryBatchCount > 0) {
            final removeCount = memoryBatchCount > _pendingRawGpsPoints.length
                ? _pendingRawGpsPoints.length
                : memoryBatchCount;
            _pendingRawGpsPoints.removeRange(0, removeCount);
          }
          if (localIdsToMark != null && localIdsToMark.isNotEmpty) {
            await LocalDB.markGpsPointsAsSynced(localIdsToMark);
          } else if (maxTimestamp != null) {
            await LocalDB.markGpsPointsAsSyncedForSession(
              workoutId,
              upToTimestamp: maxTimestamp,
            );
          }
          debugPrint(
            '[Workout][RawTracking] uploaded ${payloadsToUpload.length} raw GPS points',
          );
        } catch (e) {
          debugPrint(
            '[Workout][RawTracking] GPS upload failed for $workoutId: $e',
          );
        } finally {
          _isFlushingRawGpsPoints = false;
        }
      }
    }

    if ((force || _pendingRawStepIntervals.length >= _kRawStepFlushThreshold) &&
        !_isFlushingRawStepIntervals) {
      List<RawStepIntervalPayload> payloadsToUpload = [];
      DateTime? maxEndTimestamp;
      List<int>? localIdsToMark;
      int memoryBatchCount = 0;

      if (_pendingRawStepIntervals.isNotEmpty) {
        final memoryBatch =
            List<_BufferedRawStepInterval>.from(_pendingRawStepIntervals);
        memoryBatchCount = memoryBatch.length;
        payloadsToUpload = memoryBatch
            .map((interval) => interval.toPayload(workoutId))
            .toList(growable: false);
        maxEndTimestamp = memoryBatch.last.intervalEnd;
      } else if (force) {
        final unsyncedLocal =
            await LocalDB.getUnsyncedStepIntervalsForSession(workoutId);
        if (unsyncedLocal.isNotEmpty) {
          localIdsToMark = unsyncedLocal.map((i) => i.id).toList();
          payloadsToUpload =
              unsyncedLocal.map((interval) => interval.toPayload()).toList();
          maxEndTimestamp = unsyncedLocal.last.intervalEnd;
        }
      }

      if (payloadsToUpload.isNotEmpty) {
        _isFlushingRawStepIntervals = true;
        try {
          await _rawTracking.saveRawStepIntervals(payloadsToUpload);
          if (memoryBatchCount > 0) {
            final removeCount =
                memoryBatchCount > _pendingRawStepIntervals.length
                    ? _pendingRawStepIntervals.length
                    : memoryBatchCount;
            _pendingRawStepIntervals.removeRange(0, removeCount);
          }
          if (localIdsToMark != null && localIdsToMark.isNotEmpty) {
            await LocalDB.markStepIntervalsAsSynced(localIdsToMark);
          } else if (maxEndTimestamp != null) {
            await LocalDB.markStepIntervalsAsSyncedForSession(
              workoutId,
              upToTimestamp: maxEndTimestamp,
            );
          }
          debugPrint(
            '[Workout][RawTracking] uploaded ${payloadsToUpload.length} raw step intervals',
          );
        } catch (e) {
          debugPrint(
            '[Workout][RawTracking] step upload failed for $workoutId: $e',
          );
        } finally {
          _isFlushingRawStepIntervals = false;
        }
      }
    }
  }

  Future<void> syncLiveRouteSnapshot({required bool force}) async {
    final snapshot = _pendingLiveRouteSnapshot;
    if (!_remoteWorkoutShellReady || snapshot == null) return;
    if (_isSyncingLiveRouteSnapshot) return;

    final now = DateTime.now();
    final lastSyncAt = _lastLiveRouteSnapshotSyncAt;
    if (!force &&
        lastSyncAt != null &&
        now.difference(lastSyncAt) < _kLiveRouteSnapshotInterval) {
      return;
    }

    _isSyncingLiveRouteSnapshot = true;
    try {
      final routePointCount = snapshot.routeSegments.fold<int>(
        0,
        (sum, segment) => sum + segment.length,
      );
      await _workoutRemote.saveLiveRouteSnapshot(
        sessionId: snapshot.workoutId,
        routeSegments: snapshot.routeSegments,
        shouldRequestRouteCorrection: routePointCount >= 10,
        lastGpsGapDurationSec: snapshot.lastGpsGapDurationSec > 0
            ? snapshot.lastGpsGapDurationSec
            : null,
        isGpsSignalWeak: snapshot.isGpsSignalWeak,
      );
      _lastLiveRouteSnapshotSyncAt = now;
      if (identical(_pendingLiveRouteSnapshot, snapshot)) {
        _pendingLiveRouteSnapshot = null;
      }
      debugPrint(
        '[Workout][RouteSnapshot] synced '
        '${snapshot.routeSegments.length} segments / $routePointCount points',
      );
    } catch (e) {
      debugPrint(
        '[Workout][RouteSnapshot] sync failed for ${snapshot.workoutId}: $e',
      );
    } finally {
      _isSyncingLiveRouteSnapshot = false;
    }
  }

  Future<void> enqueueProcessingForSession(WorkoutSession session) async {
    final activityConsistency = _trackingEngine.assessActivityConsistency(
      activityType: session.activityType,
      avgSpeedKmh: session.avgSpeedKmh,
      distanceKm: session.distanceKm,
      durationSec: session.durationSec,
    );
    try {
      await _processingRemote.enqueueDeterministicJob(
        workoutId: session.id,
        payload: {
          'activity_type': session.activityType,
          'mode': session.mode,
          'duration_sec': session.durationSec,
          'moving_time_sec': session.movingTimeSec,
          'distance_km': session.distanceKm,
          'steps': session.steps,
          'avg_speed_kmh': session.avgSpeedKmh,
          'calories_kcal': session.caloriesKcal,
          'raw_gps_buffered_points': pendingRawGpsPointCount,
          'raw_step_buffered_intervals': pendingRawStepIntervalCount,
          'activity_consistency': {
            'should_invalidate_result':
                activityConsistency.shouldInvalidateResult,
            'reason': activityConsistency.reason,
            'min_expected_avg_speed_kmh':
                activityConsistency.minExpectedAvgSpeedKmh,
            'max_expected_avg_speed_kmh':
                activityConsistency.maxExpectedAvgSpeedKmh,
          },
        },
      );
    } catch (e) {
      debugPrint('[Workout][Processing] enqueue failed for ${session.id}: $e');
    }
  }

  Future<void> enqueueRouteCorrectionForSession(WorkoutSession session) async {
    if (!_remoteWorkoutShellReady) return;
    if (!_hasEnoughFilteredRouteForCorrection(session.filteredRouteJson)) {
      debugPrint(
        '[Workout][RouteCorrection] skipped for ${session.id}: insufficient filtered route data',
      );
      return;
    }

    final routeSummary = _summarizeRouteSegments(session.filteredRouteJson);
    try {
      await _processingRemote.enqueueRouteCorrectionJob(
        workoutId: session.id,
        payload: {
          'session_id': session.id,
          'activity_type': session.activityType,
          'mode': session.mode,
          'started_at': session.startedAt.toUtc().toIso8601String(),
          'ended_at': session.endedAt.toUtc().toIso8601String(),
          'duration_sec': session.durationSec,
          'moving_time_sec': session.movingTimeSec,
          'distance_km_filtered': session.distanceKm,
          'gps_gap_count': session.gpsAnalysis.gpsGapCount,
          'gps_gap_duration_sec': session.gpsAnalysis.gpsGapDurationSec,
          'filtered_route_json': session.filteredRouteJson,
          'route_match_status': session.routeMatchStatus,
          'route_distance_source': session.routeDistanceSource,
          'route_segment_count': routeSummary.segmentCount,
          'route_point_count': routeSummary.pointCount,
        },
      );
    } catch (e) {
      debugPrint(
        '[Workout][RouteCorrection] enqueue failed for ${session.id}: $e',
      );
    }
  }

  Future<void> logProcessingEvent({
    required String workoutId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {
    if (!_remoteWorkoutShellReady || workoutId.isEmpty) return;

    try {
      await _processingRemote.insertLog(
        workoutId: workoutId,
        eventType: eventType,
        message: message,
        payload: payload,
        logLevel: logLevel,
      );
    } catch (e) {
      debugPrint(
        '[Workout][Processing] log insert failed for $workoutId event=$eventType: $e',
      );
    }
  }

  void dispose() {
    reset();
  }

  void _maybeFlushRawTrackingBuffers(String? workoutId) {
    if (workoutId == null || workoutId.isEmpty) return;
    _activeWorkoutId = workoutId;
    if (!_remoteWorkoutShellReady) return;

    final gpsReady = _pendingRawGpsPoints.length >= _kRawGpsFlushThreshold;
    final stepReady =
        _pendingRawStepIntervals.length >= _kRawStepFlushThreshold;
    if (!gpsReady && !stepReady) return;

    unawaited(flushPendingRawTracking(workoutId: workoutId, force: false));
  }

  void _ensurePeriodicFlushTimer() {
    if (_rawTrackingFlushTimer != null) return;

    _rawTrackingFlushTimer = Timer.periodic(_kRawTrackingFlushInterval, (_) {
      final workoutId = _activeWorkoutId;
      if (!_remoteWorkoutShellReady || workoutId == null || workoutId.isEmpty) {
        return;
      }

      unawaited(flushPendingRawTracking(workoutId: workoutId, force: true));
      unawaited(syncLiveRouteSnapshot(force: false));
    });
  }

  bool _hasEnoughFilteredRouteForCorrection(String filteredRouteJson) {
    final summary = _summarizeRouteSegments(filteredRouteJson);
    return summary.pointCount >= 10 && summary.segmentCount > 0;
  }

  _RouteSegmentSummary _summarizeRouteSegments(String routeJson) {
    try {
      final decoded = jsonDecode(routeJson);
      if (decoded is! List) {
        return const _RouteSegmentSummary(segmentCount: 0, pointCount: 0);
      }

      var segmentCount = 0;
      var pointCount = 0;
      for (final segment in decoded) {
        if (segment is! List || segment.isEmpty) continue;
        segmentCount += 1;
        pointCount += segment.length;
      }

      return _RouteSegmentSummary(
        segmentCount: segmentCount,
        pointCount: pointCount,
      );
    } catch (_) {
      return const _RouteSegmentSummary(segmentCount: 0, pointCount: 0);
    }
  }
}

class _PendingLiveRouteSnapshot {
  final String workoutId;
  final List<List<LatLng>> routeSegments;
  final double lastGpsGapDurationSec;
  final bool isGpsSignalWeak;

  const _PendingLiveRouteSnapshot({
    required this.workoutId,
    required this.routeSegments,
    required this.lastGpsGapDurationSec,
    required this.isGpsSignalWeak,
  });
}

class _RouteSegmentSummary {
  final int segmentCount;
  final int pointCount;

  const _RouteSegmentSummary({
    required this.segmentCount,
    required this.pointCount,
  });
}

class _BufferedRawGpsPoint {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? deviceSource;

  const _BufferedRawGpsPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    this.deviceSource,
  });

  RawGpsPointPayload toPayload(String workoutId) {
    return RawGpsPointPayload(
      workoutId: workoutId,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
      accuracy: accuracy,
      heading: heading,
      deviceSource: deviceSource,
    );
  }
}

class _BufferedRawStepInterval {
  final DateTime intervalStart;
  final DateTime intervalEnd;
  final int stepsCount;
  final String? deviceSource;

  const _BufferedRawStepInterval({
    required this.intervalStart,
    required this.intervalEnd,
    required this.stepsCount,
    this.deviceSource,
  });

  RawStepIntervalPayload toPayload(String workoutId) {
    return RawStepIntervalPayload(
      workoutId: workoutId,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      stepsCount: stepsCount,
      deviceSource: deviceSource,
    );
  }
}
