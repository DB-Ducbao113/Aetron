import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static Isar? _isar;
  static Future<void>? _initFuture;
  static bool _terminalOpenFailure = false;
  static bool _recoveryAttempted = false;

  /// Directory that owns [_isar]. A reused instance must live in the exact same
  /// directory, so it is remembered next to the instance.
  static String? _dirPath;

  /// The schema every open must use. Kept in one place so the initial open and
  /// the recovery re-open can never drift apart.
  static const _schemas = [
    LocalWorkoutSchema,
    LocalGPSPointSchema,
    LocalStepIntervalSchema,
  ];

  /// True only when [_isar] is a fully initialized database: either opened
  /// here, or an instance re-used from the Isar registry after it was verified
  /// against the document directory.
  ///
  /// A *placeholder* instance (constructed but never initialized) reports
  /// `isOpen == true` while its internal `_collections` is still unassigned, so
  /// every query on it throws `LateInitializationError: Field '_collections@...'
  /// has not been initialized` — which is exactly how History ended up
  /// permanently empty.
  static bool _openedByUs = false;

  static Future<void> init() async {
    if (_openedByUs && _isar != null && _isar!.isOpen) return;
    if (_terminalOpenFailure) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _open();
    try {
      await _initFuture!;
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _open() async {
    if (kIsWeb) return;

    late final Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (e) {
      // No platform channel for the path provider (e.g. headless unit tests,
      // background process, or platform isolate). Nothing is broken — `init()`
      // retries once the engine is back.
      debugPrint('[LocalDB] no document directory yet: $e');
      return;
    }

    final registered = Isar.getInstance();
    if (registered != null &&
        _openedByUs &&
        identical(registered, _isar) &&
        hasAttachedCollections(registered)) {
      // Re-entrant `_open()` (init raced with itself): trust only our own,
      // already verified instance.
      _isar = registered;
      _dirPath = dir.path;
      return;
    }

    try {
      _isar = await Isar.open(_schemas, directory: dir.path, inspector: false);
      _openedByUs = true;
      _dirPath = dir.path;
      _terminalOpenFailure = false;
      _recoveryAttempted = false;
      debugPrint('[LocalDB] opened at ${dir.path}');
    } catch (e) {
      debugPrint('[LocalDB] _open error: $e');
      _openedByUs = false;
      _isar = null;
      _dirPath = null;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('already been opened')) {
        if (await _adoptRegisteredInstance(dir.path)) return;
        // CLEANUP: A stale instance from an earlier app run (hot restart) is
        // holding the native handle. Closing it unblocks the open below and,
        // crucially, hands back a database whose `_collections` is initialized
        // — unlike `Isar.getInstance()`, which returns the placeholder whose
        // queries throw LateInitializationError and left History empty.
        final stale = Isar.getInstance();
        if (stale != null) {
          try {
            await stale.close();
            debugPrint('[LocalDB] closed stale Isar instance, retrying open');
          } catch (closeError) {
            debugPrint('[LocalDB] stale instance close error: $closeError');
          }
          try {
            _isar = await Isar.open(
              _schemas,
              directory: dir.path,
              inspector: false,
            );
            _openedByUs = true;
            _dirPath = dir.path;
            debugPrint('[LocalDB] opened after releasing stale instance');
            return;
          } catch (retryError) {
            debugPrint('[LocalDB] reopen after close error: $retryError');
            _isar = null;
            _openedByUs = false;
            _dirPath = null;
            if (isRecoverableCacheOpenError(retryError)) {
              await _recoverDamagedCache(dir, retryError);
            }
          }
        }
        return;
      }
      if (isRecoverableCacheOpenError(e)) {
        await _recoverDamagedCache(dir, e);
      }
      // Any other failure leaves `_isar` null on purpose. Adopting
      // `Isar.getInstance()` there returned a placeholder whose queries threw
      // LateInitializationError on every read.
    }
  }

  /// Adopt the instance currently registered with Isar **only** when it provably
  /// lives in [dirPath] (same database file) or is one we verified earlier.
  ///
  /// Adopting a foreign instance used to produce a database that reported
  /// `isOpen == true` while every query threw `LateInitializationError: Field
  /// '_collections@...' has not been initialized`, which is why the workout list
  /// and History came up empty. Returns true when [_isar] is usable.
  static Future<bool> _adoptRegisteredInstance(String dirPath) async {
    final existing = Isar.getInstance();
    if (existing == null) return false;
    if (_openedByUs &&
        identical(existing, _isar) &&
        hasAttachedCollections(existing)) {
      _dirPath = dirPath;
      return true;
    }
    bool sameFile;
    try {
      final existingDir = existing.directory;
      sameFile =
          existingDir != null &&
          existingDir == dirPath &&
          existing.path == p.join(dirPath, 'default.isar');
    } catch (e) {
      debugPrint('[LocalDB] registered instance path is unavailable: $e');
      sameFile = false;
    }
    if (!sameFile || !hasAttachedCollections(existing)) return false;
    _isar = existing;
    _openedByUs = true;
    _dirPath = dirPath;
    debugPrint('[LocalDB] reusing open instance at $dirPath');
    return true;
  }

  /// Isar registers an instance before it attaches generated collections.
  /// When opening fails between those two steps, `getInstance()` returns an
  /// object whose `isOpen`, `directory`, and `path` all look valid, but every
  /// collection access throws a `LateInitializationError`.
  ///
  /// Probe the same collections used by this database before adopting a
  /// registered instance. Kept public only so the half-open regression can be
  /// reproduced without depending on a real database file.
  @visibleForTesting
  static bool hasAttachedCollections(Isar isar) {
    try {
      isar.localWorkouts;
      isar.localGPSPoints;
      isar.localStepIntervals;
      return true;
    } catch (e) {
      debugPrint('[LocalDB] registered instance has no collections: $e');
      return false;
    }
  }

  @visibleForTesting
  static bool isRecoverableCacheOpenError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('collection id') ||
        message.contains('schema') ||
        message.contains('corrupt') ||
        message.contains('illegalarg');
  }

  /// Moves the unreadable database aside so no local bytes are destroyed.
  /// Supabase can hydrate the newly-created cache; the backup remains available
  /// for manual recovery if it contained a workout that never reached cloud.
  @visibleForTesting
  static Future<String?> backupCacheForRecovery(
    Directory directory, {
    DateTime? timestamp,
  }) async {
    final database = File(p.join(directory.path, 'default.isar'));
    final lock = File(p.join(directory.path, 'default.isar.lock'));
    String? backupPath;

    if (await database.exists()) {
      final compactTimestamp = (timestamp ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[-:.]'), '');
      backupPath = p.join(
        directory.path,
        'default.isar.recovery-$compactTimestamp.bak',
      );
      await database.rename(backupPath);
    }
    if (await lock.exists()) {
      await lock.delete();
    }
    return backupPath;
  }

  static Future<void> _recoverDamagedCache(
    Directory directory,
    Object cause,
  ) async {
    if (_recoveryAttempted) {
      _terminalOpenFailure = true;
      debugPrint(
        '[LocalDB] cache recovery already attempted; using cloud-only mode '
        'until the app restarts (cause: $cause)',
      );
      return;
    }
    _recoveryAttempted = true;

    final registered = Isar.getInstance();
    if (registered != null) {
      try {
        await registered.close();
      } catch (closeError) {
        debugPrint('[LocalDB] recovery close error: $closeError');
      }
    }

    try {
      final backupPath = await backupCacheForRecovery(directory);
      if (backupPath != null) {
        debugPrint('[LocalDB] preserved unreadable cache at $backupPath');
      }

      final reopened = await Isar.open(
        _schemas,
        directory: directory.path,
        inspector: false,
      );
      if (!hasAttachedCollections(reopened)) {
        throw StateError('Recreated Isar has no attached collections');
      }
      _isar = reopened;
      _openedByUs = true;
      _dirPath = directory.path;
      _terminalOpenFailure = false;
      _recoveryAttempted = false;
      debugPrint('[LocalDB] recreated cache after open error: $cause');
    } catch (recoveryError) {
      _isar = null;
      _openedByUs = false;
      _dirPath = null;
      _terminalOpenFailure = true;
      final failed = Isar.getInstance();
      if (failed != null) {
        try {
          await failed.close();
        } catch (_) {
          // The terminal guard prevents repeated opens until app restart.
        }
      }
      debugPrint(
        '[LocalDB] cache recovery failed; using cloud-only mode until restart: '
        '$recoveryError',
      );
    }
  }

  static Isar get instance {
    final isar = _isar;
    if (isar == null || !_openedByUs) {
      if (kIsWeb) throw StateError('LocalDB not supported on web');
      debugPrint(
        '[LocalDB] instance requested but the database is not open '
        '(directory=${_dirPath ?? 'unknown'})',
      );
      throw StateError('LocalDB has not been initialized');
    }
    return isar;
  }

  // New Workout Methods

  /// Insert locally. Used when finishing a session.
  static Future<void> saveSession(LocalWorkout workout) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) {
      debugPrint(
        '[LocalDB] CRITICAL: Isar is unavailable; cannot save workout session ${workout.sessionId}',
      );
      throw StateError(
        'LocalDB Isar instance is unavailable for saving workout session',
      );
    }
    await isar.writeTxn(() async {
      await isar.localWorkouts.put(workout);
    });
  }

  /// Get all sessions for a user, sorted descending. UI uses this.
  static Future<List<LocalWorkout>> getSessionsByUser(String userId) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    final workouts = await isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .sortByStartedAtDesc()
        .findAll();
    return workouts
        .where((w) => w.durationSec > 0 || w.distanceKm > 0 || w.steps > 0)
        .toList();
  }

  /// Filtered by activity type.
  static Future<List<LocalWorkout>> getSessionsByUserByType(
    String userId,
    String activityType,
  ) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    final workouts = await isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .activityTypeEqualTo(activityType, caseSensitive: false)
        .sortByStartedAtDesc()
        .findAll();
    return workouts
        .where((w) => w.durationSec > 0 || w.distanceKm > 0 || w.steps > 0)
        .toList();
  }

  static Future<LocalWorkout?> getSessionById(String sessionId) async {
    if (kIsWeb) return null;
    await init();
    final isar = _isar;
    if (isar == null) return null;
    return await isar.localWorkouts
        .filter()
        .sessionIdEqualTo(sessionId)
        .findFirst();
  }

  static Future<bool> deleteWorkout(int id) async {
    if (kIsWeb) return true;
    try {
      await init();
      final isar = _isar;
      if (isar == null) return false;
      final workout = await isar.localWorkouts.get(id);
      final sessionId = workout?.sessionId;
      await isar.writeTxn(() async {
        if (sessionId != null && sessionId.isNotEmpty) {
          await isar.localGPSPoints
              .filter()
              .sessionIdEqualTo(sessionId)
              .deleteAll();
          await isar.localStepIntervals
              .filter()
              .sessionIdEqualTo(sessionId)
              .deleteAll();
        }
        await isar.localWorkouts.delete(id);
      });
      return true;
    } catch (e) {
      debugPrint('[LocalDB] deleteWorkout error: $e');
      return false;
    }
  }

  static Future<List<LocalWorkout>> getUnsyncedWorkouts() async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    return await isar.localWorkouts.filter().isSyncedEqualTo(false).findAll();
  }

  /// Get unsynced workouts belonging strictly to a specific user.
  static Future<List<LocalWorkout>> getUnsyncedWorkoutsForUser(
    String userId,
  ) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    return await isar.localWorkouts
        .filter()
        .userIdEqualTo(userId)
        .isSyncedEqualTo(false)
        .findAll();
  }

  /// Assign workouts recorded before sign-in to the user who explicitly signs
  /// in on this device. Raw GPS and step rows are linked by session id and do
  /// not need to be rewritten.
  static Future<int> claimGuestWorkouts(String userId) async {
    if (kIsWeb || userId.isEmpty || userId == 'local_user') return 0;
    await init();
    final isar = _isar;
    if (isar == null) return 0;
    return isar.writeTxn(() async {
      final guestWorkouts = await isar.localWorkouts
          .filter()
          .userIdEqualTo('local_user')
          .findAll();
      for (final workout in guestWorkouts) {
        workout.userId = userId;
        workout.isSynced = false;
      }
      await isar.localWorkouts.putAll(guestWorkouts);
      return guestWorkouts.length;
    });
  }

  /// Wipe all local cache for a specific user (used on logout).
  static Future<bool> clearAllForUser(String userId) async {
    if (kIsWeb) return true;
    try {
      await init();
      final isar = _isar;
      if (isar == null) return false;
      final workouts = await isar.localWorkouts
          .filter()
          .userIdEqualTo(userId)
          .findAll();
      final sessionIds = workouts
          .map((w) => w.sessionId)
          .where((s) => s.isNotEmpty)
          .toList();

      await isar.writeTxn(() async {
        for (final sessionId in sessionIds) {
          await isar.localGPSPoints
              .filter()
              .sessionIdEqualTo(sessionId)
              .deleteAll();
          await isar.localStepIntervals
              .filter()
              .sessionIdEqualTo(sessionId)
              .deleteAll();
        }
        await isar.localWorkouts.filter().userIdEqualTo(userId).deleteAll();
      });
      return true;
    } catch (e) {
      debugPrint('[LocalDB] clearAllForUser error: $e');
      return false;
    }
  }

  /// Hydrate local DB from cloud models to implement sync across devices.
  static Future<void> syncRemoteSessions(
    List<WorkoutSession> remotes, {
    String? forUserId,
  }) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    final targetUserId =
        forUserId ?? (remotes.isNotEmpty ? remotes.first.userId : null);
    final scopedRemotes = targetUserId == null
        ? remotes
        : remotes
              .where((session) => session.userId == targetUserId)
              .toList(growable: false);

    await isar.writeTxn(() async {
      for (final remote in scopedRemotes) {
        // Skip orphaned recording shells with 0 metrics
        if (remote.durationSec <= 0 &&
            remote.distanceKm <= 0 &&
            remote.steps <= 0) {
          continue;
        }

        var existing = await isar.localWorkouts
            .filter()
            .sessionIdEqualTo(remote.id)
            .findFirst();

        if (existing == null) {
          // If it doesn't exist locally, add it to the cache
          final newWorkout = LocalWorkout.fromEntity(remote, isSynced: true);
          await isar.localWorkouts.put(newWorkout);
        } else {
          // If it exists locally, ensure it matches the cloud source of truth
          existing.userId = remote.userId;
          existing.activityType = remote.activityType;
          existing.startedAt = remote.startedAt;
          existing.endedAt = remote.endedAt;
          existing.durationSec = remote.durationSec;
          existing.movingTimeSec = remote.movingTimeSec;
          existing.distanceKm = remote.distanceKm;
          existing.steps = remote.steps;
          existing.avgSpeedKmh = remote.avgSpeedKmh;
          existing.caloriesKcal = remote.caloriesKcal;
          existing.mode = remote.mode;
          existing.createdAt = remote.createdAt;
          existing.lapSplitsJson = jsonEncode(
            remote.lapSplits.map((split) => split.toJson()).toList(),
          );
          final shouldPreserveLocalAnalysis =
              remote.gpsAnalysis.totalDistanceKm <= 0 &&
              remote.gpsAnalysis.validDistanceKm <= 0 &&
              existing.gpsAnalysisJson.isNotEmpty &&
              existing.gpsAnalysisJson != '{}';
          final shouldPreserveFilteredRoute =
              (remote.filteredRouteJson.isEmpty ||
                  remote.filteredRouteJson == '[]') &&
              existing.filteredRouteJson.isNotEmpty &&
              existing.filteredRouteJson != '[]';
          final shouldPreserveMatchedRoute =
              (remote.matchedRouteJson.isEmpty ||
                  remote.matchedRouteJson == '[]') &&
              existing.matchedRouteJson.isNotEmpty &&
              existing.matchedRouteJson != '[]';
          if (!shouldPreserveLocalAnalysis) {
            existing.gpsAnalysisJson = jsonEncode(remote.gpsAnalysis.toJson());
          }
          if (!shouldPreserveFilteredRoute) {
            existing.filteredRouteJson = remote.filteredRouteJson;
          }
          if (!shouldPreserveMatchedRoute) {
            existing.matchedRouteJson = remote.matchedRouteJson;
          }
          existing.routeMatchStatus = remote.routeMatchStatus.isNotEmpty
              ? remote.routeMatchStatus
              : existing.routeMatchStatus;
          existing.routeMatchConfidence = remote.routeMatchConfidence;
          existing.routeDistanceSource = remote.routeDistanceSource.isNotEmpty
              ? remote.routeDistanceSource
              : existing.routeDistanceSource;
          existing.matchedDistanceKm = remote.matchedDistanceKm;
          existing.routeMatchMetricsJson =
              (remote.routeMatchMetricsJson.isNotEmpty &&
                  remote.routeMatchMetricsJson != '{}')
              ? remote.routeMatchMetricsJson
              : existing.routeMatchMetricsJson;
          existing.isSynced = true;

          await isar.localWorkouts.put(existing);
        }
      }

      if (targetUserId != null && targetUserId.isNotEmpty) {
        final remoteIds = scopedRemotes.map((r) => r.id).toSet();
        final localForUser = await isar.localWorkouts
            .filter()
            .userIdEqualTo(targetUserId)
            .findAll();
        for (final local in localForUser) {
          if (!shouldDeleteLocalSessionMissingFromRemote(
            isSynced: local.isSynced,
            isPresentRemotely: remoteIds.contains(local.sessionId),
          )) {
            continue;
          }

          // A successful cloud response is authoritative. Synced rows that
          // disappeared remotely were deleted elsewhere and must be removed
          // locally too; turning them back into pending rows resurrected them
          // on the next upload. Unsynced rows remain queued and are never
          // deleted by reconciliation.
          await isar.localGPSPoints
              .filter()
              .sessionIdEqualTo(local.sessionId)
              .deleteAll();
          await isar.localStepIntervals
              .filter()
              .sessionIdEqualTo(local.sessionId)
              .deleteAll();
          await isar.localWorkouts.delete(local.id);
        }
      }
    });
  }

  @visibleForTesting
  static bool shouldDeleteLocalSessionMissingFromRemote({
    required bool isSynced,
    required bool isPresentRemotely,
  }) => isSynced && !isPresentRemotely;

  // GPS Point Methods
  static Future<void> savePoints(List<LocalGPSPoint> points) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.localGPSPoints.putAll(points);
    });
  }

  static Future<void> saveRawGpsPoint(LocalGPSPoint point) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) {
      debugPrint(
        '[LocalDB] CRITICAL: Isar is unavailable; cannot persist raw GPS point for session ${point.sessionId}',
      );
      throw StateError(
        'LocalDB Isar instance is unavailable for raw GPS persistence',
      );
    }
    await isar.writeTxn(() async {
      await isar.localGPSPoints.put(point);
    });
  }

  /// Get all GPS points for a workout by its local Isar integer ID.
  /// Prefer [getPointsForSession] (uses sessionId index).
  static Future<List<LocalGPSPoint>> getPointsForWorkout(int workoutId) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    final workout = await isar.localWorkouts.get(workoutId);
    if (workout == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(workout.sessionId)
        .sortByTimestamp()
        .findAll();
  }

  /// Get unsynced GPS points for a session by its local Isar integer ID.
  static Future<List<LocalGPSPoint>> getUnsyncedPoints(int workoutId) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    final workout = await isar.localWorkouts.get(workoutId);
    if (workout == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(workout.sessionId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getUnsyncedGpsPointsForSession(
    String sessionId,
  ) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  static Future<List<LocalGPSPoint>> getPointsForSession(
    String sessionId,
  ) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    return await isar.localGPSPoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByTimestamp()
        .findAll();
  }

  static Future<void> markPointsAsSynced(List<int> pointIds) async {
    await markGpsPointsAsSynced(pointIds);
  }

  static Future<void> markGpsPointsAsSynced(List<int> pointIds) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      for (final id in pointIds) {
        final point = await isar.localGPSPoints.get(id);
        if (point != null) {
          point.isSynced = true;
          await isar.localGPSPoints.put(point);
        }
      }
    });
  }

  static Future<void> markGpsPointsAsSyncedForSession(
    String sessionId, {
    DateTime? upToTimestamp,
  }) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    final unsynced = await getUnsyncedGpsPointsForSession(sessionId);
    final targetPoints = upToTimestamp == null
        ? unsynced
        : unsynced.where((p) => !p.timestamp.isAfter(upToTimestamp)).toList();
    if (targetPoints.isEmpty) return;
    await isar.writeTxn(() async {
      for (final point in targetPoints) {
        point.isSynced = true;
      }
      await isar.localGPSPoints.putAll(targetPoints);
    });
  }

  static RawGpsPointPayload rawGpsPointToPayload(LocalGPSPoint point) {
    return RawGpsPointPayload(
      workoutId: point.sessionId,
      timestamp: point.timestamp,
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude,
      speed: point.speed,
      accuracy: point.accuracy,
      heading: point.heading,
      deviceSource: point.deviceSource,
    );
  }

  static Future<void> saveRawStepInterval(LocalStepInterval interval) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) {
      debugPrint(
        '[LocalDB] CRITICAL: Isar is unavailable; cannot persist step interval for session ${interval.sessionId}',
      );
      throw StateError(
        'LocalDB Isar instance is unavailable for raw step interval persistence',
      );
    }
    await isar.writeTxn(() async {
      await isar.localStepIntervals.put(interval);
    });
  }

  static Future<List<LocalStepInterval>> getUnsyncedStepIntervalsForSession(
    String sessionId,
  ) async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    return await isar.localStepIntervals
        .filter()
        .sessionIdEqualTo(sessionId)
        .isSyncedEqualTo(false)
        .sortByIntervalStart()
        .findAll();
  }

  static Future<void> markStepIntervalsAsSynced(List<int> intervalIds) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      for (final id in intervalIds) {
        final interval = await isar.localStepIntervals.get(id);
        if (interval != null) {
          interval.isSynced = true;
          await isar.localStepIntervals.put(interval);
        }
      }
    });
  }

  static Future<void> markStepIntervalsAsSyncedForSession(
    String sessionId, {
    DateTime? upToTimestamp,
  }) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    final unsynced = await getUnsyncedStepIntervalsForSession(sessionId);
    final targetIntervals = upToTimestamp == null
        ? unsynced
        : unsynced
            .where((i) => !i.intervalEnd.isAfter(upToTimestamp))
            .toList();
    if (targetIntervals.isEmpty) return;
    await isar.writeTxn(() async {
      for (final interval in targetIntervals) {
        interval.isSynced = true;
      }
      await isar.localStepIntervals.putAll(targetIntervals);
    });
  }

  static Future<List<String>> getSessionIdsWithUnsyncedRawTracking() async {
    if (kIsWeb) return const [];
    await init();
    final isar = _isar;
    if (isar == null) return const [];
    final unsyncedPoints = await isar.localGPSPoints
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    final unsyncedSteps = await isar.localStepIntervals
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    final sessionIds = <String>{};
    for (final p in unsyncedPoints) {
      if (p.sessionId.isNotEmpty) sessionIds.add(p.sessionId);
    }
    for (final s in unsyncedSteps) {
      if (s.sessionId.isNotEmpty) sessionIds.add(s.sessionId);
    }
    return sessionIds.toList();
  }

  static Future<void> updateRouteMatchResult(RouteMatchResult result) async {
    if (kIsWeb) return;
    await init();
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final workout = await isar.localWorkouts
          .filter()
          .sessionIdEqualTo(result.sessionId)
          .findFirst();
      if (workout == null) return;

      workout.matchedRouteJson = result.matchedRouteJson;
      workout.routeMatchStatus = result.routeMatchStatus;
      workout.routeMatchConfidence = result.routeMatchConfidence;
      workout.routeDistanceSource = result.routeDistanceSource;
      workout.matchedDistanceKm = result.matchedDistanceKm;
      workout.routeMatchMetricsJson = result.routeMatchMetricsJson;

      await isar.localWorkouts.put(workout);
    });
  }
}
