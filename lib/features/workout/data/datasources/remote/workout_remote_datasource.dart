import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/workout/data/models/workout_session_model.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/core/constants/db_tables.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/scientific_result_metadata.dart';

class WorkoutRemoteDataSource {
  final SupabaseClient _supabase;

  WorkoutRemoteDataSource(this._supabase);

  String _requireOwner([String? expected]) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || (expected != null && expected != userId)) {
      throw StateError('Workout operation requires the active account');
    }
    return userId;
  }

  Future<void> createSessionShell({
    required String id,
    required String userId,
    required String activityType,
    required String mode,
    required DateTime startedAt,
    required DateTime createdAt,
  }) async {
    _requireOwner(userId);
    await _supabase.from(DbTables.workoutSessions).upsert({
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'mode': mode,
      'started_at': startedAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'moving_time_sec': 0,
      'processing_status': kClientRecordingStatus,
      'metrics_version': kClientMetricsVersion,
    });
    _requireOwner(userId);
  }

  /// Saves the complete session to the cloud database
  Future<void> saveSession(WorkoutSession session) async {
    _requireOwner(session.userId);
    final model = WorkoutSessionModel.fromEntity(session);
    final payload = model.toJson()
      ..remove('gps_analysis')
      ..remove('filtered_route_json')
      ..remove('matched_route_json')
      ..remove('route_match_status')
      ..remove('route_match_confidence')
      ..remove('route_distance_source')
      ..remove('matched_distance_km')
      ..remove('route_match_metrics_json');
    final research = buildResearchResult(session);
    final filtered = _decodeRouteSafely(session.filteredRouteJson);
    await _supabase.from(DbTables.workoutSessions).upsert({
      ...payload,
      'client_research_result_json': ?research,
      if (filtered.isNotEmpty) 'filtered_route_json': filtered,
      'processing_status': kClientProcessingStatus,
      'metrics_version': kClientMetricsVersion,
    });
    _requireOwner(session.userId);
  }

  /// Immutable-in-meaning final client result, separate from server audit.
  /// This is an unverified client claim, not proof of exact server replay.
  @visibleForTesting
  static Map<String, dynamic>? buildResearchResult(WorkoutSession session) {
    try {
      final audit = jsonDecode(session.routeMatchMetricsJson);
      if (audit is! Map<String, dynamic> ||
          audit['scientific_result_version'] != 1) {
        return null;
      }
      final filtered = jsonDecode(session.filteredRouteJson);
      final reconstructed = jsonDecode(session.matchedRouteJson);
      if (filtered is! List || reconstructed is! List) return null;
      return {
        'version': 1,
        'session_id': session.id,
        'activity_type': session.activityType.toLowerCase(),
        'mode': session.mode,
        'distance_km': session.distanceKm,
        'duration_sec': session.durationSec,
        'moving_time_sec': session.movingTimeSec,
        'steps': session.steps,
        'avg_speed_kmh': session.avgSpeedKmh,
        'calories_kcal': session.caloriesKcal,
        'lap_splits': session.lapSplits.map((split) => split.toJson()).toList(),
        'filtered_route': filtered,
        'reconstructed_route': reconstructed,
        'reconstruction_status': session.routeMatchStatus,
        'audit': audit,
      };
    } on FormatException {
      return null;
    }
  }

  Future<void> saveLiveRouteSnapshot({
    required String sessionId,
    required List<List<LatLng>> routeSegments,
    required bool shouldRequestRouteCorrection,
    required double? lastGpsGapDurationSec,
    required bool isGpsSignalWeak,
  }) async {
    final userId = _requireOwner();
    final filteredRouteJson = routeSegments
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) => segment
              .map((point) => {'lat': point.latitude, 'lng': point.longitude})
              .toList(growable: false),
        )
        .toList(growable: false);

    final routePointCount = filteredRouteJson.fold<int>(
      0,
      (sum, segment) => sum + segment.length,
    );

    await _supabase
        .from(DbTables.workoutSessions)
        .update({
          'filtered_route_json': filteredRouteJson,
          'route_match_status': shouldRequestRouteCorrection
              ? 'pending'
              : 'not_requested',
          'route_distance_source': 'filtered',
          'route_match_metrics_json': {
            'live_snapshot': true,
            'route_segment_count': filteredRouteJson.length,
            'route_point_count': routePointCount,
            'last_gps_gap_duration_sec': lastGpsGapDurationSec,
            'is_gps_signal_weak': isGpsSignalWeak,
            'snapshot_synced_at': DateTime.now().toUtc().toIso8601String(),
          },
        })
        .eq('id', sessionId)
        .eq('user_id', userId)
        .eq('processing_status', kClientRecordingStatus);
    _requireOwner(userId);
  }

  @visibleForTesting
  static WorkoutSession decodeRemoteSession(Map<String, dynamic> row) {
    return WorkoutSessionModel.fromJson(row).toEntity().copyWith(
      routeMatchMetricsJson: ScientificResultMetadata.fromRemote(row),
    );
  }

  /// Fetch workouts from Supabase for a specific user
  Future<List<WorkoutSession>> getSessionsByUser(String userId) async {
    try {
      _requireOwner(userId);
      // Cursor on the unique immutable primary key, so equal timestamps and
      // concurrent deletes cannot shift offsets. Fetch until an empty page:
      // the server may cap results below the requested page size.
      const pageSize = 200;
      final sessions = <WorkoutSession>[];
      String? cursor;
      while (true) {
        _requireOwner(userId);
        var query = _supabase
            .from(DbTables.workoutSessions)
            .select()
            .eq('user_id', userId)
            .neq('processing_status', kClientRecordingStatus);
        if (cursor != null) query = query.gt('id', cursor);
        final page = await query.order('id', ascending: true).limit(pageSize);
        _requireOwner(userId);
        if (page.isEmpty) break;
        for (final row in page) {
          final session = decodeRemoteSession(row);
          if (session.userId != userId ||
              (cursor != null && session.id.compareTo(cursor) <= 0)) {
            throw StateError('Invalid workout pagination response');
          }
          cursor = session.id;
          if (session.durationSec > 0 ||
              session.distanceKm > 0 ||
              session.steps > 0) {
            sessions.add(session);
          }
        }
      }
      sessions.sort((a, b) {
        final byTime = b.startedAt.compareTo(a.startedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      return sessions;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionsByUser error: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionsByUser unexpected error: $e',
      );
      rethrow;
    }
  }

  /// Fetch single workout
  Future<WorkoutSession?> getSessionById(String id) async {
    try {
      final userId = _requireOwner();
      final response = await _supabase
          .from(DbTables.workoutSessions)
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      _requireOwner(userId);
      if (response == null || response['user_id'] != userId) return null;
      return decodeRemoteSession(response);
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionById error: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getSessionById unexpected error: $e',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRouteMatchPayload(String id) async {
    try {
      final userId = _requireOwner();
      final response = await _supabase
          .from(DbTables.workoutSessions)
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      _requireOwner(userId);
      if (response == null || response['user_id'] != userId) return null;
      final payload = Map<String, dynamic>.from(response);
      final hasAnyRouteMatchField =
          payload.containsKey('matched_route_json') ||
          payload.containsKey('route_match_status') ||
          payload.containsKey('route_match_confidence') ||
          payload.containsKey('route_distance_source') ||
          payload.containsKey('matched_distance_km') ||
          payload.containsKey('route_match_metrics_json');
      return hasAnyRouteMatchField ? payload : null;
    } on PostgrestException catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getRouteMatchPayload error: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[WorkoutRemoteDataSource] getRouteMatchPayload unexpected error: $e',
      );
      return null;
    }
  }

  /// Delete workout from Supabase
  Future<void> deleteSession(String id) async {
    try {
      final userId = _requireOwner();
      await _supabase
          .from(DbTables.workoutSessions)
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      _requireOwner(userId);
    } catch (e) {
      debugPrint('[WorkoutRemoteDataSource] deleteSession error: $e');
      rethrow;
    }
  }

  /// Delete all workouts for a user from Supabase
  Future<void> deleteAllSessions(String userId) async {
    try {
      _requireOwner(userId);
      await _supabase
          .from(DbTables.workoutSessions)
          .delete()
          .eq('user_id', userId);
      _requireOwner(userId);
    } catch (e) {
      debugPrint('[WorkoutRemoteDataSource] deleteAllSessions error: $e');
      rethrow;
    }
  }
}

List<dynamic> _decodeRouteSafely(String encoded) {
  try {
    final value = jsonDecode(encoded);
    return value is List ? value : const [];
  } on FormatException {
    return const [];
  }
}
