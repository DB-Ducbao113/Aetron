import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

part 'local_workout.g.dart';

@collection
class LocalWorkout {
  Id id = Isar.autoIncrement; // Local ID

  @Index(unique: true, replace: true)
  late String sessionId; // UUID from client

  late String userId;
  late String activityType;

  late DateTime startedAt;
  late DateTime endedAt;

  int durationSec = 0;
  int movingTimeSec = 0;
  double distanceKm = 0;
  int steps = 0;
  double avgSpeedKmh = 0;
  double caloriesKcal = 0;
  String mode = 'outdoor';
  late DateTime createdAt;
  String lapSplitsJson = '[]';
  String gpsAnalysisJson = '{}';
  String filteredRouteJson = '[]';
  String matchedRouteJson = '[]';
  String routeMatchStatus = 'pending';
  double? routeMatchConfidence;
  String routeDistanceSource = 'filtered';
  double? matchedDistanceKm;
  String routeMatchMetricsJson = '{}';

  // Sync tracking
  bool isSynced = false;

  WorkoutSession toEntity() {
    return WorkoutSession(
      id: sessionId,
      userId: userId,
      activityType: activityType,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      durationSec: durationSec,
      movingTimeSec: movingTimeSec,
      distanceKm: distanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      caloriesKcal: caloriesKcal,
      mode: mode,
      createdAt: createdAt.toUtc(),
      lapSplits: _decodeLapSplits(lapSplitsJson),
      gpsAnalysis: _decodeGpsAnalysis(gpsAnalysisJson),
      filteredRouteJson: filteredRouteJson,
      matchedRouteJson: matchedRouteJson,
      routeMatchStatus: routeMatchStatus,
      routeMatchConfidence: routeMatchConfidence,
      routeDistanceSource: routeDistanceSource,
      matchedDistanceKm: matchedDistanceKm,
      routeMatchMetricsJson: routeMatchMetricsJson,
    );
  }

  static LocalWorkout fromEntity(
    WorkoutSession session, {
    bool isSynced = false,
  }) {
    return LocalWorkout()
      ..sessionId = session.id
      ..userId = session.userId
      ..activityType = session.activityType
      ..startedAt = session.startedAt.toUtc()
      ..endedAt = session.endedAt.toUtc()
      ..durationSec = session.durationSec
      ..movingTimeSec = session.movingTimeSec
      ..distanceKm = session.distanceKm
      ..steps = session.steps
      ..avgSpeedKmh = session.avgSpeedKmh
      ..caloriesKcal = session.caloriesKcal
      ..mode = session.mode
      ..createdAt = session.createdAt.toUtc()
      ..lapSplitsJson = jsonEncode(
        session.lapSplits.map((split) => split.toJson()).toList(),
      )
      ..gpsAnalysisJson = jsonEncode(session.gpsAnalysis.toJson())
      ..filteredRouteJson = session.filteredRouteJson
      ..matchedRouteJson = session.matchedRouteJson
      ..routeMatchStatus = session.routeMatchStatus
      ..routeMatchConfidence = session.routeMatchConfidence
      ..routeDistanceSource = session.routeDistanceSource
      ..matchedDistanceKm = session.matchedDistanceKm
      ..routeMatchMetricsJson = session.routeMatchMetricsJson
      ..isSynced = isSynced;
  }

  /// Compare persisted payload values, not Dart object identity. Isar returns
  /// local-zone DateTimes and GPS analysis/laps are reconstructed instances.
  bool sameSnapshot(LocalWorkout other) =>
      sessionId == other.sessionId &&
      userId == other.userId &&
      activityType == other.activityType &&
      startedAt.isAtSameMomentAs(other.startedAt) &&
      endedAt.isAtSameMomentAs(other.endedAt) &&
      createdAt.isAtSameMomentAs(other.createdAt) &&
      durationSec == other.durationSec &&
      movingTimeSec == other.movingTimeSec &&
      distanceKm == other.distanceKm &&
      steps == other.steps &&
      avgSpeedKmh == other.avgSpeedKmh &&
      caloriesKcal == other.caloriesKcal &&
      mode == other.mode &&
      lapSplitsJson == other.lapSplitsJson &&
      gpsAnalysisJson == other.gpsAnalysisJson &&
      filteredRouteJson == other.filteredRouteJson &&
      matchedRouteJson == other.matchedRouteJson &&
      routeMatchStatus == other.routeMatchStatus &&
      routeMatchConfidence == other.routeMatchConfidence &&
      routeDistanceSource == other.routeDistanceSource &&
      matchedDistanceKm == other.matchedDistanceKm &&
      routeMatchMetricsJson == other.routeMatchMetricsJson;

  static List<WorkoutLapSplit> _decodeLapSplits(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => WorkoutLapSplit.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static WorkoutGpsAnalysis _decodeGpsAnalysis(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WorkoutGpsAnalysis();
      return WorkoutGpsAnalysis.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const WorkoutGpsAnalysis();
    }
  }
}
