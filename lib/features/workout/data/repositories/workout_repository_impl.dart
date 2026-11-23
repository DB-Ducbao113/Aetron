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
import 'package:fitness_exercise_application/features/workout/domain/services/scientific_result_metadata.dart';

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

  String? get _activeUserId => _supabase.auth.currentUser?.id;

  bool _isActive(String userId) => _activeUserId == userId;

  void _requireActive(String userId) {
    if (!_isActive(userId)) {
      throw StateError('Workout operation requires the active account');
    }
  }

  @override
  Future<void> saveSessionRemote(WorkoutSession session) async {
    if (ScientificResultMetadata.decode(
          session.routeMatchMetricsJson,
        )['recording_checkpoint'] ==
        true) {
      throw StateError(
        'Recording checkpoint must be recovered or finalized before upload',
      );
    }
    _requireActive(session.userId);
    if (!kIsWeb) {
      final existing = await LocalDB.getSessionById(session.id);
      _requireActive(session.userId);
      if (existing != null && existing.userId != session.userId) {
        throw StateError('Workout id belongs to another account');
      }
      final pending = await _pendingSyncStore.listForUser(session.userId);
      _requireActive(session.userId);
      if (_isHiddenByPendingDeletion(pending, session.id)) {
        throw StateError('Workout has a pending deletion');
      }
    }
    await _remoteDataSource.saveSession(session);
    _requireActive(session.userId);
  }

  @override
  Future<void> cacheSessionLocal(
    WorkoutSession session, {
    bool isSynced = false,
  }) async {
    if (kIsWeb) return;
    // An offline finalization may belong to a signed-out guest.
    final owner = session.userId;
    void requireCacheOwner() {
      if (owner == 'local_user' && _activeUserId == null && !isSynced) return;
      _requireActive(owner);
    }

    requireCacheOwner();
    final existing = await LocalDB.getSessionById(session.id);
    requireCacheOwner();
    if (existing != null && existing.userId != owner) {
      throw StateError('Workout id belongs to another account');
    }
    final localWorkout = LocalWorkout.fromEntity(session, isSynced: isSynced);
    if (owner != 'local_user') {
      final pending = await _pendingSyncStore.listForUser(owner);
      requireCacheOwner();
      if (_isHiddenByPendingDeletion(pending, session.id)) {
        throw StateError('Workout has a pending deletion');
      }
    }
    // A completed request must not replace a newer offline edit.
    if (isSynced &&
        existing != null &&
        !existing.isSynced &&
        !existing.sameSnapshot(localWorkout)) {
      return;
    }
    await LocalDB.saveSession(localWorkout);
  }

  @override
  Future<List<WorkoutSession>> fetchSessionsRemote(String userId) async {
    _requireActive(userId);
    final remoteWorkouts = await _remoteDataSource.getSessionsByUser(userId);
    _requireActive(userId);
    if (remoteWorkouts.any((session) => session.userId != userId)) {
      throw StateError('Remote workout owner mismatch');
    }
    final visible = await _withoutPendingDeletions(userId, remoteWorkouts);
    _requireActive(userId);
    return visible;
  }

  @override
  Future<List<WorkoutSession>> getSessionsLocal(String userId) async {
    if (!_isActive(userId)) return const [];
    if (kIsWeb) {
      return await fetchSessionsRemote(userId);
    }
    try {
      final localWorkouts = await LocalDB.getSessionsByUser(userId);
      final sessions = localWorkouts.map((w) => w.toEntity()).toList();
      final visible = await _withoutPendingDeletions(userId, sessions);
      return _isActive(userId) ? visible : const [];
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
    _requireActive(userId);
    // The history query deliberately hides shells and zero-metric rows.
    // A paginated history response is not a deletion manifest or snapshot.
    if (sessions.any((session) => session.userId != userId)) {
      throw StateError('Cannot cache workouts owned by another account');
    }
    final filtered = await _withoutPendingDeletions(userId, sessions);
    _requireActive(userId);
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
      if (!_isActive(userId)) return [];
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}

    if (kIsWeb || !_isActive(userId)) return [];

    final localWorkouts = await LocalDB.getSessionsByUserByType(
      userId,
      activityType,
    );
    final visible = await _withoutPendingDeletions(
      userId,
      localWorkouts.map((w) => w.toEntity()).toList(),
    );
    return _isActive(userId) ? visible : const [];
  }

  @override
  Future<WorkoutSession?> getSessionById(String sessionId) async {
    final userId = _activeUserId;
    if (userId == null) return null;
    if (!kIsWeb) {
      final pending = await _pendingSyncStore.listForUser(userId);
      if (!_isActive(userId) ||
          _isHiddenByPendingDeletion(pending, sessionId)) {
        return null;
      }
      try {
        final local = await LocalDB.getSessionById(sessionId);
        if (!_isActive(userId)) return null;
        if (local != null) {
          return local.userId == userId ? local.toEntity() : null;
        }
      } catch (e) {
        debugPrint('[WorkoutRepository] Local session lookup failed: $e');
      }
    }

    try {
      _requireActive(userId);
      final remote = await _remoteDataSource.getSessionById(sessionId);
      if (!_isActive(userId) ||
          remote == null ||
          remote.userId != userId ||
          remote.id != sessionId) {
        return null;
      }
      if (!kIsWeb) {
        final pending = await _pendingSyncStore.listForUser(userId);
        if (!_isActive(userId) ||
            _isHiddenByPendingDeletion(pending, sessionId)) {
          return null;
        }
        // A detail response is never an authoritative history snapshot.
        // Re-read because a local save may have landed during the fetch.
        final local = await LocalDB.getSessionById(sessionId);
        if (!_isActive(userId)) return null;
        if (local != null) {
          return local.userId == userId ? local.toEntity() : null;
        }
        await cacheSessionLocal(remote, isSynced: true);
        if (!_isActive(userId)) return null;
      }
      return remote;
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch remote session: $e');
      return null;
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final userId = _activeUserId;
    if (userId == null) return;
    if (kIsWeb) {
      await _remoteDataSource.deleteSession(sessionId);
      return;
    }

    // Never enqueue or delete a local workout owned by a different account.
    final local = await LocalDB.getSessionById(sessionId);
    _requireActive(userId);
    if (local != null && local.userId != userId) {
      throw StateError('Workout id belongs to another account');
    }
    await _pendingSyncStore.enqueueDeleteSession(
      userId: userId,
      sessionId: sessionId,
    );
    _requireActive(userId);
    await _flushPendingDeletions(userId);
  }

  @override
  Future<void> deleteAllSessions(String userId) async {
    _requireActive(userId);
    if (kIsWeb) {
      await _remoteDataSource.deleteAllSessions(userId);
      return;
    }

    // Deleting this account's workouts must not claim/delete guest workouts.
    await _pendingSyncStore.enqueueDeleteAll(userId);
    _requireActive(userId);
    await _flushPendingDeletions(userId);
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
        _requireActive(currentUserId);
        final remainingDeletes = await _pendingSyncStore.listForUser(
          currentUserId,
        );
        _requireActive(currentUserId);
        if (PendingWorkoutSyncStore.deletesAll(remainingDeletes)) {
          return;
        }
        final sessionsPendingDeletion =
            PendingWorkoutSyncStore.hiddenSessionIds(remainingDeletes);
        await LocalDB.claimGuestWorkouts(currentUserId);
        _requireActive(currentUserId);
        final unsyncedWorkouts = await LocalDB.getUnsyncedWorkoutsForUser(
          currentUserId,
        );
        _requireActive(currentUserId);
        await _uploadPendingWorkouts(
          currentUserId,
          unsyncedWorkouts.where(
            (workout) => !sessionsPendingDeletion.contains(workout.sessionId),
          ),
        );
        _requireActive(currentUserId);
        await _syncAllUnsyncedRawTracking(
          currentUserId,
          sessionsPendingDeletion: sessionsPendingDeletion,
        );
        return;
      }
      final unsyncedWorkouts = await LocalDB.getUnsyncedWorkoutsForUser(
        currentUserId,
      );
      _requireActive(currentUserId);
      await _uploadPendingWorkouts(currentUserId, unsyncedWorkouts);
    } catch (e) {
      debugPrint('[Sync] syncPendingData error: $e');
    } finally {
      _isSyncingPendingData = false;
    }
  }

  Future<void> _uploadPendingWorkouts(
    String currentUserId,
    Iterable<LocalWorkout> workouts,
  ) async {
    for (final workout in workouts) {
      _requireActive(currentUserId);
      if (workout.userId != currentUserId) continue;
      final current = await LocalDB.getSessionById(workout.sessionId);
      _requireActive(currentUserId);
      if (current == null ||
          current.userId != currentUserId ||
          current.isSynced ||
          LocalDB.isRecordingCheckpoint(current) ||
          LocalDB.isRecordingActive(current.sessionId)) {
        continue;
      }
      final pending = await _pendingSyncStore.listForUser(currentUserId);
      _requireActive(currentUserId);
      if (_isHiddenByPendingDeletion(pending, current.sessionId)) continue;
      if (current.durationSec <= 0 &&
          current.distanceKm <= 0 &&
          current.steps <= 0) {
        // Legacy interrupted recordings may have raw evidence despite an
        // empty summary. Keep the row and its raw samples until an explicit
        // recovery or discard; routine sync must neither delete nor finalize it.
        continue;
      }
      try {
        final session = current.toEntity();
        await saveSessionRemote(session);
        await _syncRawTrackingForSession(currentUserId, workout.sessionId);
        await _requireOwnedWorkout(currentUserId, session.id);
        await _enqueueDeterministicProcessing(session);
        await _requireOwnedWorkout(currentUserId, session.id);
        await _enqueueRouteCorrectionIfNeeded(session);
        await _requireOwnedWorkout(currentUserId, session.id);
        final latest = await LocalDB.getSessionById(session.id);
        _requireActive(currentUserId);
        if (latest != null &&
            latest.userId == currentUserId &&
            latest.sameSnapshot(current)) {
          latest.isSynced = true;
          await LocalDB.saveSession(latest);
        }
      } catch (e) {
        debugPrint(
          '[WorkoutRepository] Failed to sync pending session ${workout.sessionId}: $e',
        );
      }
    }
  }

  Future<void> _flushPendingDeletions(String userId) async {
    _requireActive(userId);
    final due = await _pendingSyncStore.listDue(userId);
    for (final operation in due) {
      _requireActive(userId);
      if (operation.userId != userId) continue;
      try {
        if (operation.type == PendingWorkoutSyncType.deleteAll) {
          final localCleared = await LocalDB.clearAllForUser(userId);
          if (!localCleared) {
            throw StateError('Local workout cache deletion failed');
          }
          _requireActive(userId);
          await _remoteDataSource.deleteAllSessions(userId);
        } else if (operation.sessionId != null) {
          final local = await LocalDB.getSessionById(operation.sessionId!);
          _requireActive(userId);
          if (local != null && local.userId != userId) {
            throw StateError('Workout id belongs to another account');
          }
          if (local != null && !await LocalDB.deleteWorkout(local.id)) {
            throw StateError('Local workout deletion failed');
          }
          _requireActive(userId);
          await _remoteDataSource.deleteSession(operation.sessionId!);
        }
        _requireActive(userId);
        await _pendingSyncStore.complete(operation.key);
      } catch (error) {
        if (!_isActive(userId)) return;
        await _pendingSyncStore.recordFailure(operation, error);
      }
    }
  }

  Future<List<WorkoutSession>> _withoutPendingDeletions(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    _requireActive(userId);
    final owned = sessions.where((session) => session.userId == userId);
    if (kIsWeb) return owned.toList(growable: false);
    final pending = await _pendingSyncStore.listForUser(userId);
    _requireActive(userId);
    if (PendingWorkoutSyncStore.deletesAll(pending)) {
      return const [];
    }
    final deletedSessionIds = PendingWorkoutSyncStore.hiddenSessionIds(pending);
    return owned
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

  Future<void> _requireOwnedWorkout(String userId, String sessionId) async {
    _requireActive(userId);
    final workout = await LocalDB.getSessionById(sessionId);
    _requireActive(userId);
    if (workout == null || workout.userId != userId) {
      throw StateError('Raw tracking requires an owned local workout');
    }
    final pending = await _pendingSyncStore.listForUser(userId);
    _requireActive(userId);
    if (_isHiddenByPendingDeletion(pending, sessionId)) {
      throw StateError('Workout has a pending deletion');
    }
  }

  Future<void> _syncRawTrackingForSession(
    String userId,
    String sessionId,
  ) async {
    await _requireOwnedWorkout(userId, sessionId);
    final unsyncedGpsPoints = await LocalDB.getUnsyncedGpsPointsForSession(
      sessionId,
    );
    const chunkSize = 250;
    for (var i = 0; i < unsyncedGpsPoints.length; i += chunkSize) {
      await _requireOwnedWorkout(userId, sessionId);
      final end = (i + chunkSize).clamp(0, unsyncedGpsPoints.length);
      final chunk = unsyncedGpsPoints.sublist(i, end);
      await _rawTrackingRemoteDataSource.saveRawGpsPoints(
        chunk.map(LocalDB.rawGpsPointToPayload).toList(),
      );
      await _requireOwnedWorkout(userId, sessionId);
      await LocalDB.markGpsPointsAsSynced(
        chunk.map((point) => point.id).toList(),
      );
    }

    await _requireOwnedWorkout(userId, sessionId);
    final unsyncedStepIntervals =
        await LocalDB.getUnsyncedStepIntervalsForSession(sessionId);
    for (var i = 0; i < unsyncedStepIntervals.length; i += chunkSize) {
      await _requireOwnedWorkout(userId, sessionId);
      final end = (i + chunkSize).clamp(0, unsyncedStepIntervals.length);
      final chunk = unsyncedStepIntervals.sublist(i, end);
      await _rawTrackingRemoteDataSource.saveRawStepIntervals(
        chunk.map((interval) => interval.toPayload()).toList(),
      );
      await _requireOwnedWorkout(userId, sessionId);
      await LocalDB.markStepIntervalsAsSynced(
        chunk.map((interval) => interval.id).toList(),
      );
    }
  }

  Future<void> _syncAllUnsyncedRawTracking(
    String userId, {
    Set<String> sessionsPendingDeletion = const {},
  }) async {
    _requireActive(userId);
    final sessionIds = await LocalDB.getSessionIdsWithUnsyncedRawTracking();
    for (final sessionId in sessionIds) {
      _requireActive(userId);
      if (sessionsPendingDeletion.contains(sessionId)) continue;
      final localWorkout = await LocalDB.getSessionById(sessionId);
      _requireActive(userId);
      // Failed workout uploads remain pending; never send orphan raw records.
      if (localWorkout == null ||
          localWorkout.userId != userId ||
          !localWorkout.isSynced) {
        continue;
      }
      try {
        await _syncRawTrackingForSession(userId, sessionId);
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
      rethrow;
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
    final userId = _activeUserId;
    if (userId == null || kIsWeb) return false;
    try {
      await _requireOwnedWorkout(userId, sessionId);
      final payload = await _remoteDataSource.getRouteMatchPayload(sessionId);
      if (!_isActive(userId) ||
          payload == null ||
          payload['user_id'] != userId ||
          payload['id'] != sessionId) {
        return false;
      }
      final metadata = ScientificResultMetadata.fromRemote(payload);
      if (ScientificResultMetadata.hasResearchSummary(metadata) &&
          !ScientificResultMetadata.hasFinalServerVerdict(metadata)) {
        // Keep local P03 until the server finishes auditing the raw evidence.
        return false;
      }

      final rawResult = RouteMatchResult(
        sessionId: sessionId,
        matchedRouteJson: _jsonField(payload['matched_route_json'], '[]'),
        routeMatchStatus: payload['route_match_status'] as String? ?? 'pending',
        routeMatchConfidence: (payload['route_match_confidence'] as num?)
            ?.toDouble(),
        routeDistanceSource:
            payload['route_distance_source'] as String? ?? 'filtered',
        matchedDistanceKm: (payload['matched_distance_km'] as num?)?.toDouble(),
        routeMatchMetricsJson: metadata,
      );

      final normalized = _routeMatchQualityService.normalize(rawResult);
      await _requireOwnedWorkout(userId, sessionId);
      await LocalDB.updateRouteMatchResult(normalized);
      return _isActive(userId);
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
      _requireActive(userId);
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

String _jsonField(Object? value, String fallback) =>
    value == null ? fallback : (value is String ? value : jsonEncode(value));
