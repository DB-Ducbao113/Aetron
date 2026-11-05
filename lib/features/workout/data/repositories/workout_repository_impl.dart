import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/pending_workout_sync_store.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/route_match_quality_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource _remoteDataSource;
  final RawTrackingRemoteDataSource _rawTrackingRemoteDataSource;
  final WorkoutProcessingRemoteDataSource _processingRemoteDataSource;
  final SupabaseClient _supabase;
  final PendingWorkoutSyncStore _pendingSyncStore;
  final RouteMatchQualityService _routeMatchQualityService =
      const RouteMatchQualityService();
  bool _isSyncingPendingData = false;

  WorkoutRepositoryImpl(
    this._remoteDataSource,
    this._rawTrackingRemoteDataSource,
    this._processingRemoteDataSource,
    this._supabase, {
    PendingWorkoutSyncStore? pendingSyncStore,
  }) : _pendingSyncStore =
           pendingSyncStore ?? PendingWorkoutSyncStore(DatabaseHelper.instance);

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {
    await _remoteDataSource.saveSession(session);
  }

  @override
  Future<void> cacheSessionLocal(
    WorkoutSession session, {
    bool isSynced = false,
  }) async {
    final localWorkout = LocalWorkout.fromEntity(session, isSynced: isSynced);
    await LocalDB.saveSession(localWorkout);
  }

  @override
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId) async {
    final remoteWorkouts = await _remoteDataSource.getSessionsByUser(userId);
    return _withoutPendingDeletions(userId, remoteWorkouts);
  }

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async {
    if (kIsWeb) {
      return await fetchSessionsRemote(userId);
    }
    try {
      final localWorkouts = await LocalDB.getSessionsByUser(userId);
      final sessions = localWorkouts.map((w) => w.toEntity()).toList();
      return await _withoutPendingDeletions(userId, sessions);
    } catch (e) {
      debugPrint('[WorkoutRepository] LocalDB getSessionsByUser error: $e');
    }
    return const [];
  }

  @override
  Future<void> replaceLocalCache(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    if (kIsWeb) return;
    // Do NOT wipe the cache first. `sessions` is the *filtered* server list
    // (`getSessionsByUser` hides `client_recording` shells and zero-metric
    // rows), so a blind `clearAllForUser` destroys local rows the server query
    // simply chose not to return — including a workout whose background save is
    // still in flight. The Details screen reads the local cache first, which is
    // how a finished workout ended up showing on Summary but "not found" in
    // History.
    //
    // `syncRemoteSessions` already reconciles correctly: it updates/inserts the
    // server rows, preserves unsynced local work, and applies remote deletions
    // to rows that were previously confirmed as synced. Remote fetch failures
    // throw before this method is called, so an offline request cannot masquerade
    // as a successful empty result and wipe the cache.
    final filtered = await _withoutPendingDeletions(userId, sessions);
    await LocalDB.syncRemoteSessions(filtered, forUserId: userId);
  }

  @override
  Future<List<WorkoutSession>> getSessionsByType(String activityType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final remotes = await fetchSessionsRemote(userId);
      final filtered = remotes
          .where(
            (w) => w.activityType.toLowerCase() == activityType.toLowerCase(),
          )
          .toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}

    if (kIsWeb) return [];

    final localWorkouts = await LocalDB.getSessionsByUserByType(
      userId,
      activityType,
    );
    return await _withoutPendingDeletions(
      userId,
      localWorkouts.map((w) => w.toEntity()).toList(),
    );
  }

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async {
    // Diagnostics: a "Workout not found" screen is ambiguous unless we know
    // WHICH stage returned null. Each branch below logs its outcome so a single
    // run identifies the failing layer.
    var localHit = false;
    if (!kIsWeb) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final pending = await _pendingSyncStore.listForUser(userId);
        if (_isHiddenByPendingDeletion(pending, sessionId)) return null;
      }
      try {
        final w = await LocalDB.getSessionById(sessionId);
        if (w != null) {
          localHit = true;
          debugPrint(
            '[WorkoutRepository][getSessionById] local HIT $sessionId',
          );
          return w.toEntity();
        }
        debugPrint('[WorkoutRepository][getSessionById] local MISS $sessionId');
      } catch (e) {
        debugPrint('[WorkoutRepository] LocalDB.getSessionById error: $e');
      }
    }

    try {
      final remote = await _remoteDataSource.getSessionById(sessionId);
      if (remote != null) {
        debugPrint(
          '[WorkoutRepository][getSessionById] remote HIT $sessionId '
          '(localHit=$localHit)',
        );
        if (!kIsWeb) {
          await cacheSessionLocal(remote, isSynced: true);
        }
        return remote;
      }
      debugPrint(
        '[WorkoutRepository][getSessionById] remote MISS $sessionId — '
        'the row is absent from workout_sessions or RLS blocked the SELECT',
      );
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch remote session: $e');
    }
    return null;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (kIsWeb) {
      await _remoteDataSource.deleteSession(sessionId);
      return;
    }

    if (userId != null) {
      await _pendingSyncStore.enqueueDeleteSession(
        userId: userId,
        sessionId: sessionId,
      );
    }

    var localDeleted = true;
    try {
      final w = await LocalDB.getSessionById(sessionId);
      if (w != null) {
        localDeleted = await LocalDB.deleteWorkout(w.id);
      }
    } catch (e) {
      localDeleted = false;
      debugPrint('[WorkoutRepository] Failed to delete local session: $e');
    }

    if (userId == null) return;
    final pending = (await _pendingSyncStore.listForUser(
      userId,
    )).where((operation) => operation.sessionId == sessionId).firstOrNull;
    try {
      await _remoteDataSource.deleteSession(sessionId);
      if (pending != null) {
        if (localDeleted) {
          await _pendingSyncStore.complete(pending.key);
        } else {
          await _pendingSyncStore.recordFailure(
            pending,
            StateError('Local workout deletion failed'),
          );
        }
      }
    } catch (e) {
      if (pending != null) await _pendingSyncStore.recordFailure(pending, e);
      debugPrint('[WorkoutRepository] Failed to delete remote session: $e');
    }
  }

  @override
  Future<void> deleteAllSessions(String userId) async {
    if (kIsWeb) {
      await _remoteDataSource.deleteAllSessions(userId);
      return;
    }

    await LocalDB.claimGuestWorkouts(userId);
    await _pendingSyncStore.enqueueDeleteAll(userId);
    var localCleared = false;
    try {
      localCleared = await LocalDB.clearAllForUser(userId);
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to clear local sessions: $e');
    }

    final pending = (await _pendingSyncStore.listForUser(userId))
        .where(
          (operation) => operation.type == PendingWorkoutSyncType.deleteAll,
        )
        .firstOrNull;
    try {
      await _remoteDataSource.deleteAllSessions(userId);
      if (pending != null) {
        if (localCleared) {
          await _pendingSyncStore.complete(pending.key);
        } else {
          await _pendingSyncStore.recordFailure(
            pending,
            StateError('Local workout cache deletion failed'),
          );
        }
      }
    } catch (e) {
      if (pending != null) await _pendingSyncStore.recordFailure(pending, e);
      debugPrint(
        '[WorkoutRepository] Failed to delete all remote sessions: $e',
      );
    }
  }

  @override
  Future<void> syncPendingData() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    if (_isSyncingPendingData) return;
    _isSyncingPendingData = true;

    try {
      if (!kIsWeb) {
        await _flushPendingDeletions(currentUserId);
        final remainingDeletes = await _pendingSyncStore.listForUser(
          currentUserId,
        );
        if (PendingWorkoutSyncStore.deletesAll(remainingDeletes)) {
          return;
        }
        final sessionsPendingDeletion =
            PendingWorkoutSyncStore.hiddenSessionIds(remainingDeletes);
        await LocalDB.claimGuestWorkouts(currentUserId);
        final unsyncedWorkouts = await LocalDB.getUnsyncedWorkoutsForUser(
          currentUserId,
        );
        await _uploadPendingWorkouts(
          unsyncedWorkouts.where(
            (workout) => !sessionsPendingDeletion.contains(workout.sessionId),
          ),
        );
        await _syncAllUnsyncedRawTracking(
          currentUserId,
          sessionsPendingDeletion: sessionsPendingDeletion,
        );
        return;
      }
      final unsyncedWorkouts = await LocalDB.getUnsyncedWorkoutsForUser(
        currentUserId,
      );
      await _uploadPendingWorkouts(unsyncedWorkouts);
    } catch (e) {
      debugPrint('[Sync] syncPendingData error: $e');
    } finally {
      _isSyncingPendingData = false;
    }
  }

  Future<void> _uploadPendingWorkouts(Iterable<LocalWorkout> workouts) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    for (final workout in workouts) {
      if (workout.userId != currentUserId) continue;
      if (workout.durationSec <= 0 &&
          workout.distanceKm <= 0 &&
          workout.steps <= 0) {
        await LocalDB.deleteWorkout(workout.id);
        continue;
      }
      try {
        final session = workout.toEntity();
        await _remoteDataSource.saveSession(session);
        await _syncRawTrackingForSession(workout.sessionId);
        await _enqueueDeterministicProcessing(session);
        await _enqueueRouteCorrectionIfNeeded(session);
        workout.isSynced = true;
        await LocalDB.saveSession(workout);
      } catch (e) {
        debugPrint(
          '[WorkoutRepository] Failed to sync pending session ${workout.sessionId}: $e',
        );
      }
    }
  }

  Future<void> _flushPendingDeletions(String userId) async {
    final due = await _pendingSyncStore.listDue(userId);
    for (final operation in due) {
      try {
        if (operation.type == PendingWorkoutSyncType.deleteAll) {
          final localCleared = await LocalDB.clearAllForUser(userId);
          if (!localCleared) {
            throw StateError('Local workout cache deletion failed');
          }
          await _remoteDataSource.deleteAllSessions(userId);
        } else if (operation.sessionId != null) {
          final local = await LocalDB.getSessionById(operation.sessionId!);
          if (local != null && !await LocalDB.deleteWorkout(local.id)) {
            throw StateError('Local workout deletion failed');
          }
          await _remoteDataSource.deleteSession(operation.sessionId!);
        }
        await _pendingSyncStore.complete(operation.key);
      } catch (error) {
        await _pendingSyncStore.recordFailure(operation, error);
      }
    }
  }

  Future<List<WorkoutSession>> _withoutPendingDeletions(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    if (kIsWeb) return sessions;
    final pending = await _pendingSyncStore.listForUser(userId);
    if (PendingWorkoutSyncStore.deletesAll(pending)) {
      return const [];
    }
    final deletedSessionIds = PendingWorkoutSyncStore.hiddenSessionIds(pending);
    return sessions
        .where((session) => !deletedSessionIds.contains(session.id))
        .toList(growable: false);
  }

  bool _isHiddenByPendingDeletion(
    List<PendingWorkoutSyncOperation> operations,
    String sessionId,
  ) {
    return operations.any(
      (operation) =>
          operation.type == PendingWorkoutSyncType.deleteAll ||
          operation.sessionId == sessionId,
    );
  }

  Future<void> _syncRawTrackingForSession(String sessionId) async {
    final unsyncedGpsPoints = await LocalDB.getUnsyncedGpsPointsForSession(
      sessionId,
    );
    if (unsyncedGpsPoints.isNotEmpty) {
      await _rawTrackingRemoteDataSource.saveRawGpsPoints(
        unsyncedGpsPoints.map(LocalDB.rawGpsPointToPayload).toList(),
      );
      await LocalDB.markGpsPointsAsSynced(
        unsyncedGpsPoints.map((point) => point.id).toList(),
      );
    }

    final unsyncedStepIntervals =
        await LocalDB.getUnsyncedStepIntervalsForSession(sessionId);
    if (unsyncedStepIntervals.isNotEmpty) {
      await _rawTrackingRemoteDataSource.saveRawStepIntervals(
        unsyncedStepIntervals.map((interval) => interval.toPayload()).toList(),
      );
      await LocalDB.markStepIntervalsAsSynced(
        unsyncedStepIntervals.map((interval) => interval.id).toList(),
      );
    }
  }

  Future<void> _syncAllUnsyncedRawTracking(
    String userId, {
    Set<String> sessionsPendingDeletion = const {},
  }) async {
    final sessionIds = await LocalDB.getSessionIdsWithUnsyncedRawTracking();
    for (final sessionId in sessionIds) {
      if (sessionsPendingDeletion.contains(sessionId)) continue;
      final localWorkout = await LocalDB.getSessionById(sessionId);
      if (localWorkout != null && localWorkout.userId != userId) {
        continue;
      }
      try {
        await _syncRawTrackingForSession(sessionId);
      } catch (e) {
        debugPrint(
          '[WorkoutRepository] Failed to sync raw tracking for $sessionId: $e',
        );
      }
    }
  }

  Future<void> _enqueueDeterministicProcessing(WorkoutSession session) async {
    await _processingRemoteDataSource.enqueueDeterministicJob(
      workoutId: session.id,
      payload: {
        'session_id': session.id,
        'activity_type': session.activityType,
        'mode': session.mode,
        'duration_sec': session.durationSec,
        'moving_time_sec': session.movingTimeSec,
        'distance_km': session.distanceKm,
        'steps': session.steps,
        'avg_speed_kmh': session.avgSpeedKmh,
        'calories_kcal': session.caloriesKcal,
        'source': 'offline_sync',
      },
    );
  }

  Future<void> _enqueueRouteCorrectionIfNeeded(WorkoutSession session) async {
    final routeSummary = _summarizeRouteSegments(session.filteredRouteJson);
    if (routeSummary.pointCount < 10 || routeSummary.segmentCount == 0) return;

    try {
      await _processingRemoteDataSource.enqueueRouteCorrectionJob(
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
          'source': 'offline_sync',
        },
      );
    } catch (e) {
      debugPrint(
        '[WorkoutRepository] Failed to enqueue route correction for ${session.id}: $e',
      );
    }
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

  @override
  Future<bool> syncRouteMatchResult(String sessionId) async {
    try {
      final payload = await _remoteDataSource.getRouteMatchPayload(sessionId);
      if (payload == null) return false;

      final rawResult = RouteMatchResult(
        sessionId: sessionId,
        matchedRouteJson: payload['matched_route_json'] as String? ?? '[]',
        routeMatchStatus: payload['route_match_status'] as String? ?? 'pending',
        routeMatchConfidence: (payload['route_match_confidence'] as num?)
            ?.toDouble(),
        routeDistanceSource:
            payload['route_distance_source'] as String? ?? 'filtered',
        matchedDistanceKm: (payload['matched_distance_km'] as num?)?.toDouble(),
        routeMatchMetricsJson:
            payload['route_match_metrics_json'] as String? ?? '{}',
      );

      final normalized = _routeMatchQualityService.normalize(rawResult);
      await LocalDB.updateRouteMatchResult(normalized);
      return true;
    } catch (e) {
      debugPrint('[WorkoutRepository] syncRouteMatchResult error: $e');
      return false;
    }
  }

  @override
  Future<void> syncFromCloud() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await syncPendingData();
      final remoteWorkouts = await fetchSessionsRemote(userId);
      await replaceLocalCache(userId, remoteWorkouts);
    } catch (e) {
      debugPrint('[Sync] syncFromCloud error: $e');
    }
  }
}

class _RouteSegmentSummary {
  final int segmentCount;
  final int pointCount;

  const _RouteSegmentSummary({
    required this.segmentCount,
    required this.pointCount,
  });
}
