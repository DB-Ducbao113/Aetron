import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:uuid/uuid.dart';

import 'package:latlong2/latlong.dart';

part 'workout_providers.g.dart';

/// Workout List Provider
@riverpod
class WorkoutList extends _$WorkoutList {
  /// Sessions finished on this device whose background remote save is still
  /// in flight, partitioned by owner so an account switch can never expose a
  /// previous user's optimistic data.
  final Map<String, List<WorkoutSession>> _pendingLocalSessionsByUser = {};
  bool _reconnectSyncInFlight = false;
  bool _disposed = false;

  @override
  Future<List<WorkoutSession>> build() async {
    final user = ref.watch(currentUserIdProvider);
    if (user == null) return const [];

    _disposed = false;
    ref.onDispose(() => _disposed = true);
    ref.listen(appConnectionProvider, (previous, next) {
      if (previous?.valueOrNull == false && next.valueOrNull == true) {
        unawaited(_syncAfterReconnect());
      }
    });

    final repository = ref.read(workoutRepositoryProvider);

    // 1. First sync any pending offline sessions to Cloud
    try {
      await repository.syncPendingData();
    } catch (e) {
      debugPrint('[WorkoutList] syncPendingData error: $e');
    }

    // 2. Fetch remote sessions from Cloud so all devices (Web, iOS, Mac)
    // stay in perfect real-time sync.
    try {
      final remoteSessions = await repository.fetchSessionsRemote(user);
      if (!kIsWeb) {
        await repository.replaceLocalCache(user, remoteSessions);
      }
      return _mergePendingLocalSessions(remoteSessions, userId: user);
    } catch (e) {
      debugPrint('[WorkoutList] Remote fetch fallback to local: $e');
    }

    // 3. Fallback to local cache if offline or remote fetch failed
    return _mergePendingLocalSessions(
      await repository.getSessionsLocal(user),
      userId: user,
    );
  }

  Future<void> _syncAfterReconnect() async {
    if (_reconnectSyncInFlight) return;
    _reconnectSyncInFlight = true;
    try {
      await ref.read(workoutRepositoryProvider).syncPendingData();
      if (!_disposed) ref.invalidateSelf();
    } catch (error) {
      debugPrint('[WorkoutList] reconnect sync failed: $error');
    } finally {
      _reconnectSyncInFlight = false;
    }
  }

  /// Shows a just-finished session in the list immediately, without waiting
  /// for its background remote save (which can take tens of seconds; a plain
  /// refetch would race the save and leave the list stale on web).
  void insertLocalSession(WorkoutSession session) {
    final activeUserId = ref.read(currentUserIdProvider);
    if (activeUserId == null || session.userId != activeUserId) {
      debugPrint(
        '[WorkoutList] Ignored optimistic session ${session.id}: '
        'owner ${session.userId} does not match active user $activeUserId',
      );
      return;
    }

    final pending = _pendingLocalSessionsByUser.putIfAbsent(
      activeUserId,
      () => [],
    );
    if (pending.any((s) => s.id == session.id)) return;
    pending.insert(0, session);
    state = AsyncData<List<WorkoutSession>>(
      _mergePendingLocalSessions(
        state.valueOrNull ?? const [],
        userId: activeUserId,
      ),
    );
  }

  List<WorkoutSession> _mergePendingLocalSessions(
    List<WorkoutSession> serverSessions, {
    required String userId,
  }) {
    // Enforce tenant isolation at the presentation boundary as defense in
    // depth, even if a repository implementation returns an unexpected row.
    final ownedServerSessions = serverSessions
        .where((session) => session.userId == userId)
        .toList(growable: false);
    final pending = _pendingLocalSessionsByUser.putIfAbsent(userId, () => []);

    // A server result only proves a pending session was saved when it carries
    // real metrics. Two different rows can share the session id:
    //   1. the `client_recording` shell inserted when the workout STARTED, and
    //   2. the finalized row written by the background `saveSession`.
    // `getSessionsByUser` hides (1), and also hides any zero-metric row, so the
    // refetch legitimately returns nothing for this id while the save is in
    // flight. Treating "the id is present" as confirmation (the previous
    // behaviour) both deleted the optimistic entry AND let an empty shell
    // shadow the real workout, making a persisted workout invisible in
    // History/Analytics.
    bool serverHasPersistedMetrics(String id) => ownedServerSessions.any(
      (s) =>
          s.id == id && (s.durationSec > 0 || s.distanceKm > 0 || s.steps > 0),
    );

    pending.removeWhere((pending) => serverHasPersistedMetrics(pending.id));

    // Server rows win, but never let a zero-metric shell (or a stale filtered
    // response) hide a pending session that still has real metrics locally.
    final merged = ownedServerSessions
        .where(
          (s) =>
              !pending.any((p) => p.id == s.id) ||
              s.durationSec > 0 ||
              s.distanceKm > 0 ||
              s.steps > 0,
        )
        .toList(growable: true);

    merged.insertAll(0, pending);
    merged.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged;
  }

  /// Refresh workout list
  Future<void> refresh() async {
    state = AsyncLoading<List<WorkoutSession>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserIdProvider);
      if (user == null) return const [];

      final repository = ref.read(workoutRepositoryProvider);

      // 1. Sync pending offline sessions first
      try {
        await repository.syncPendingData();
      } catch (e) {
        debugPrint('[WorkoutList.refresh] syncPendingData error: $e');
      }

      // 2. Fetch remote sessions
      try {
        final remoteSessions = await repository.fetchSessionsRemote(user);
        if (!kIsWeb) {
          await repository.replaceLocalCache(user, remoteSessions);
        }
        return _mergePendingLocalSessions(remoteSessions, userId: user);
      } catch (e) {
        debugPrint('[WorkoutList.refresh] Remote fetch error, using local: $e');
      }

      // 3. Fallback to local cache
      return _mergePendingLocalSessions(
        await repository.getSessionsLocal(user),
        userId: user,
      );
    });
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    final repository = ref.read(workoutRepositoryProvider);
    await repository.deleteSession(workoutId);
    for (final pending in _pendingLocalSessionsByUser.values) {
      pending.removeWhere((session) => session.id == workoutId);
    }
    ref.invalidateSelf();
  }

  /// Delete all workouts
  Future<void> deleteAllWorkouts() async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) return;

    final repository = ref.read(workoutRepositoryProvider);
    await repository.deleteAllSessions(user);
    _pendingLocalSessionsByUser.remove(user);
    ref.invalidateSelf();
  }

  /// Save a completed workout session verbatim
  Future<void> saveSession(WorkoutSession session) async {
    final repository = ref.read(workoutRepositoryProvider);
    bool savedRemotely = false;
    try {
      await repository.saveSessionRemote(session);
      savedRemotely = true;
    } catch (e) {
      debugPrint('[WorkoutList] saveSession remote failed: $e');
    }
    await repository.cacheSessionLocal(session, isSynced: savedRemotely);
    ref.invalidateSelf();
  }

  /// Quick Add Workout
  Future<WorkoutSession> quickAddWorkout({
    required String activityType,
    required double durationMinutes,
    double distanceKm = 0.0,
    int steps = 0,
    double? avgSpeedKmh,
    double? caloriesKcal,
    String mode = 'indoor',
  }) async {
    final user = ref.read(currentUserIdProvider);
    if (user == null) throw Exception('No user logged in');

    final durationSec = (durationMinutes * 60).round();
    final resolvedCalories =
        caloriesKcal ??
        await (() async {
          final profile = await ref.read(userProfileProvider(user).future);
          if (profile == null) return 0.0;
          return profile.calculateCalories(
            activityType: activityType,
            distanceKm: distanceKm,
            speedKmh: avgSpeedKmh ?? 0.0,
            durationSec: durationSec,
          );
        })();

    // Quick Add -> Generate UUID -> Save immediately
    final endedAt = DateTime.now().toUtc();
    final session = WorkoutSession(
      id: const Uuid().v4(),
      userId: user,
      activityType: activityType,
      startedAt: endedAt.subtract(Duration(seconds: durationSec)),
      endedAt: endedAt,
      durationSec: durationSec,
      movingTimeSec: durationSec,
      distanceKm: distanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh ?? 0.0,
      caloriesKcal: resolvedCalories,
      mode: mode,
      createdAt: endedAt,
    );

    await saveSession(session);
    return session;
  }
}

/// Active Workout Provider
@riverpod
class ActiveWorkout extends _$ActiveWorkout {
  @override
  String? build() {
    return null;
  }

  void setActive(String workoutId) {
    state = workoutId;
  }

  void clearActive() {
    state = null;
  }
}

/// Single Workout Provider
@riverpod
Future<WorkoutSession?> workout(WorkoutRef ref, String id) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return await repository.getSessionById(id);
}

class WorkoutRoutePresentation {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String source;
  final String matchStatus;
  final double? matchConfidence;

  const WorkoutRoutePresentation({
    required this.routePoints,
    required this.routeSegments,
    required this.source,
    required this.matchStatus,
    this.matchConfidence,
  });
}

final workoutRoutePresentationProvider =
    FutureProvider.family<WorkoutRoutePresentation, String>((ref, id) async {
      final workout = await ref.watch(workoutProvider(id).future);

      if (workout != null) {
        final matchedSegments = _decodeRouteSegments(workout.matchedRouteJson);
        if (matchedSegments.isNotEmpty) {
          return WorkoutRoutePresentation(
            routePoints: matchedSegments.expand((segment) => segment).toList(),
            routeSegments: matchedSegments,
            source: 'matched',
            matchStatus: workout.routeMatchStatus,
            matchConfidence: workout.routeMatchConfidence,
          );
        }

        final filteredSegments = _decodeRouteSegments(
          workout.filteredRouteJson,
        );
        if (filteredSegments.isNotEmpty) {
          return WorkoutRoutePresentation(
            routePoints: filteredSegments.expand((segment) => segment).toList(),
            routeSegments: filteredSegments,
            source: 'filtered',
            matchStatus: workout.routeMatchStatus,
            matchConfidence: workout.routeMatchConfidence,
          );
        }
      }

      final points = await LocalDB.getPointsForSession(id);
      final rawRoute = points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);

      final rawSegments = <List<LatLng>>[];
      if (points.isNotEmpty) {
        var currentSegment = <LatLng>[
          LatLng(points.first.latitude, points.first.longitude),
        ];
        for (var i = 1; i < points.length; i++) {
          final dtSec = points[i]
                  .timestamp
                  .difference(points[i - 1].timestamp)
                  .abs()
                  .inMilliseconds /
              1000.0;
          if (dtSec > WorkoutTrackingEngine.kStaleSignalGapThresholdSec) {
            if (currentSegment.length >= 2) {
              rawSegments.add(currentSegment);
            }
            currentSegment = [
              LatLng(points[i].latitude, points[i].longitude),
            ];
          } else {
            currentSegment.add(
              LatLng(points[i].latitude, points[i].longitude),
            );
          }
        }
        if (currentSegment.length >= 2) {
          rawSegments.add(currentSegment);
        }
      }

      return WorkoutRoutePresentation(
        routePoints: rawRoute,
        routeSegments: rawSegments.isNotEmpty
            ? rawSegments
            : (rawRoute.length >= 2 ? [rawRoute] : const <List<LatLng>>[]),
        source: 'raw',
        matchStatus: workout?.routeMatchStatus ?? 'pending',
        matchConfidence: workout?.routeMatchConfidence,
      );
    });

@riverpod
Future<List<LatLng>> workoutRoute(WorkoutRouteRef ref, String id) async {
  final presentation = await ref.watch(
    workoutRoutePresentationProvider(id).future,
  );
  return presentation.routePoints;
}

List<List<LatLng>> _decodeRouteSegments(String raw) {
  if (raw.isEmpty || raw == '[]') return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final segments = <List<LatLng>>[];
    for (final segment in decoded) {
      if (segment is! List) continue;
      final points = <LatLng>[];
      for (final point in segment) {
        if (point is! Map) continue;
        final lat = (point['lat'] as num?)?.toDouble();
        final lng = (point['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.isNotEmpty) {
        segments.add(points);
      }
    }
    return segments;
  } catch (_) {
    return const [];
  }
}

// --- Timer Logic ---

class TimerState {
  final int seconds;
  final bool isRunning;

  TimerState({required this.seconds, required this.isRunning});

  TimerState copyWith({int? seconds, bool? isRunning}) {
    return TimerState(
      seconds: seconds ?? this.seconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;

  TimerNotifier() : super(TimerState(seconds: 0, isRunning: true)) {
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(seconds: state.seconds + 1);
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    state = state.copyWith(isRunning: true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider =
    StateNotifierProvider.autoDispose<TimerNotifier, TimerState>((ref) {
      return TimerNotifier();
    });

class TodayStats {
  final double distanceKm;
  final int durationSec;
  final int caloriesKcal;
  final int steps;
  final int workoutCount;

  const TodayStats({
    required this.distanceKm,
    required this.durationSec,
    required this.caloriesKcal,
    required this.steps,
    required this.workoutCount,
  });

  static const empty = TodayStats(
    distanceKm: 0,
    durationSec: 0,
    caloriesKcal: 0,
    steps: 0,
    workoutCount: 0,
  );
}

final todayStatsProvider = Provider<TodayStats>((ref) {
  final workouts = ref.watch(workoutListProvider).valueOrNull ?? [];
  final today = DateTimeHelper.localDateOnly(DateTime.now());

  final todayWorkouts = workouts
      .where((w) => DateTimeHelper.localDateOnly(w.startedAt) == today)
      .toList();

  if (todayWorkouts.isEmpty) return TodayStats.empty;

  return TodayStats(
    distanceKm: todayWorkouts.fold(
      0.0,
      (s, w) =>
          s +
          (w.gpsAnalysis.validDistanceKm > 0
              ? w.gpsAnalysis.validDistanceKm
              : w.distanceKm),
    ),
    durationSec: todayWorkouts.fold(0, (s, w) => s + w.durationSec),
    caloriesKcal: todayWorkouts.fold(0, (s, w) => s + w.caloriesKcal.round()),
    steps: todayWorkouts.fold(0, (s, w) => s + w.steps),
    workoutCount: todayWorkouts.length,
  );
});

/// Checks if there is an interrupted session that meets recovery criteria:
/// - Under 24 hours old
/// - Meaningful: duration >= 180s (3 minutes) OR distance >= 0.5 km (500m)
/// - Currently marked unsynced
final recoverableInterruptedSessionProvider =
    FutureProvider.autoDispose<WorkoutSession?>((ref) async {
      final user = ref.watch(currentUserIdProvider);
      if (user == null) return null;

      try {
        final unsynced = await LocalDB.getUnsyncedWorkoutsForUser(user);
        if (unsynced.isEmpty) return null;

        final now = DateTime.now();
        for (final workout in unsynced) {
          if (workout.userId != user) continue;

          final age = now.difference(workout.endedAt);
          if (age.inHours >= 24) continue;

          final isMeaningful =
              workout.durationSec >= 180 || workout.distanceKm >= 0.5;
          if (isMeaningful) {
            return workout.toEntity();
          }
        }
      } catch (e) {
        debugPrint(
          '[Recovery] recoverableInterruptedSessionProvider error: $e',
        );
      }
      return null;
    });
