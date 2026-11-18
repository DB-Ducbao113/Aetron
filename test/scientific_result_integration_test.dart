import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/models/workout_session_model.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/route_match_quality_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/scientific_result_metadata.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final started = DateTime.utc(2026, 11, 18);
  const route = [
    [LatLng(10, 106), LatLng(10.0001, 106)],
    [LatLng(10.01, 106), LatLng(10.0101, 106)],
  ];

  test(
    'mixed workout keeps separated step distance, never bridges route gaps',
    () {
      final expectedGps = route.fold<double>(
        0,
        (sum, s) =>
            sum +
            Geolocator.distanceBetween(
              s.first.latitude,
              s.first.longitude,
              s.last.latitude,
              s.last.longitude,
            ),
      );
      for (final finalMode in ['outdoor', 'indoor']) {
        final session = const WorkoutSessionFinalizer()
            .finalize(
              state: WorkoutSessionState(
                status: RecordingState.stopping,
                activityType: 'Walking',
                trackingMode: finalMode,
                startedAt: started,
                durationSeconds: 120,
                movingTimeSeconds: 100,
                distanceMeters: expectedGps + 50,
                gpsDistanceMeters: expectedGps,
                stepDistanceMeters: 50,
                stepCount: 90,
                researchDetectedSteps: 70,
                adaptiveStepCount: 40,
              ),
              userId: 'user-test',
              finishedAt: started.add(const Duration(seconds: 120)),
              caloriesBurned: 10,
              fallbackStrideLengthMeters: .75,
              trackingEngine: const WorkoutTrackingEngine(),
              rawGpsPositions: const [],
              filteredRouteSegments: route,
              gpsAlgorithm: 'aekf_4state',
              enableTrajectoryPreprocessing: true,
            )
            .session;
        expect(session.distanceKm, closeTo((expectedGps + 50) / 1000, 1e-9));
        expect(session.matchedRouteJson, '[]');
        expect(session.steps, 90);
        final archive = WorkoutRemoteDataSource.buildResearchResult(session)!;
        expect(archive['version'], 1);
        expect(archive['session_id'], session.id);
        expect(archive['activity_type'], 'walking');
        expect(archive['filtered_route'], hasLength(2));
        expect(archive['audit']['step_distance_m'], 50);
        expect(archive['audit']['oxford_detected_step_count'], 70);
        expect(
          archive['audit']['distance_selection_policy'],
          'segmented_gps_plus_step_distance',
        );

        final remote = WorkoutSessionModel.fromEntity(session).toJson()
          ..['client_research_result_json'] = archive
          ..['route_match_metrics_json'] = {
            'client_scientific_reconciliation': {
              'selected': false,
              'exact_replay': false,
            },
            'route_source': 'none',
          }
          ..['processing_status'] = 'client_finalized'
          ..['filtered_route_json'] = []
          ..['matched_route_json'] = []
          ..['route_match_status'] = 'not_requested';
        final decoded = WorkoutRemoteDataSource.decodeRemoteSession(remote);
        final audit = jsonDecode(decoded.routeMatchMetricsJson) as Map;
        expect(
          audit['client_research_summary']['audit']['step_distance_m'],
          50,
        );
        expect(
          audit['client_research_summary'].containsKey('filtered_route'),
          false,
        );
        expect(audit['client_scientific_reconciliation']['selected'], false);
        expect(
          ScientificResultMetadata.hasFinalServerVerdict(
            decoded.routeMatchMetricsJson,
          ),
          true,
        );
        expect(
          WorkoutRemoteDataSource.buildResearchResult(decoded),
          isNull,
          reason: 'Server records must not be uploaded as fresh client claims',
        );
      }
    },
  );

  test(
    'pending remote data does not erase cached scientific audit or claim final verdict',
    () {
      const local =
          '{"scientific_result_version":1,"gps_algorithm":"aekf_4state"}';
      final pending = ScientificResultMetadata.fromRemote({
        'processing_status': 'client_finished_pending_processing',
        'client_research_result_json': {'version': 1},
        'route_match_metrics_json': {'live_snapshot': true},
      });
      expect(ScientificResultMetadata.hasFinalServerVerdict(pending), false);
      final merged = ScientificResultMetadata.mergeCache(
        local,
        '{"legacy":true}',
      );
      expect(
        jsonDecode(merged)['client_research_summary']['audit']['gps_algorithm'],
        'aekf_4state',
      );
      expect(ScientificResultMetadata.mergeCache(merged, '{}'), merged);
    },
  );

  test('raw evidence count follows remote GPS conflict keys', () {
    Position fix(double latitude) => Position(
      latitude: latitude,
      longitude: 106,
      timestamp: started,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final first = fix(10);
    final finalization = const WorkoutSessionFinalizer().finalize(
      state: WorkoutSessionState(
        status: RecordingState.stopping,
        activityType: 'Walking',
        trackingMode: 'outdoor',
        startedAt: started,
        durationSeconds: 10,
        movingTimeSeconds: 10,
      ),
      userId: 'user-test',
      finishedAt: started.add(const Duration(seconds: 10)),
      caloriesBurned: 0,
      fallbackStrideLengthMeters: .75,
      trackingEngine: const WorkoutTrackingEngine(),
      rawGpsPositions: [first, first, fix(10.00001)],
      filteredRouteSegments: const [],
      enableTrajectoryPreprocessing: false,
      enableTrajectoryReconstruction: false,
    );
    final archive = WorkoutRemoteDataSource.buildResearchResult(
      finalization.session,
    )!;
    expect(archive['audit']['raw_gps_observation_count'], 3);
    expect(archive['audit']['raw_gps_fix_count'], 2);
  });

  test('reconstruction never becomes map-matched distance', () {
    const service = RouteMatchQualityService();
    for (final status in [
      'reconstructed_pchip',
      'reconstructed_linear',
      'not_requested',
    ]) {
      final result = service.normalize(
        RouteMatchResult(
          sessionId: 'session',
          matchedRouteJson: '[[{"lat":10,"lng":106},{"lat":10.001,"lng":106}]]',
          routeMatchStatus: status,
          routeDistanceSource: 'matched',
          routeMatchConfidence: .99,
          matchedDistanceKm: 2,
          routeMatchMetricsJson: '{}',
        ),
      );
      expect(result.routeDistanceSource, 'filtered');
      expect(result.matchedDistanceKm, isNull);
      expect(result.routeMatchConfidence, isNull);
      expect(result.routeMatchStatus, status);
      if (status == 'not_requested') {
        expect(result.matchedRouteJson, '[]');
      }
    }
  });
}
