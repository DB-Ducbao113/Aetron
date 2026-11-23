// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';

import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:fitness_exercise_application/features/iod/data/datasources/iod_sensor_acquisition_service.dart';
import 'package:fitness_exercise_application/features/iod/data/repositories/iod_experiment_storage.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_lifecycle.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRepository implements WorkoutRepository {
  final attempts = <WorkoutSession>[];
  final persisted = <String, WorkoutSession>{};
  Completer<void>? checkpointBlocker;
  bool rejectFinalSave = false;

  @override
  Future<void> cacheSessionLocal(
    WorkoutSession session, {
    bool isSynced = false,
  }) async {
    attempts.add(session);
    final metrics = jsonDecode(session.routeMatchMetricsJson) as Map;
    if (metrics['recording_checkpoint'] == true) {
      await checkpointBlocker?.future;
    } else if (rejectFinalSave) {
      throw StateError('injected local save failure');
    }
    persisted[session.id] = session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorageCoordinator implements WorkoutRecordingCoordinator {
  @override
  Future<void> drainLocalWrites() async {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocationService implements LocationTrackingService {
  @override
  void stopTracking() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StepService implements StepTrackingService {
  @override
  void pauseTracking([DateTime? timestamp]) {}

  @override
  void stopTracking() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'checkpoint failure does not poison the serialized terminal write',
    () async {
      final persistence = RecordingPersistence<Object>();
      final writes = <String>[];
      final errors = <Object>[];
      final checkpoint = persistence.checkpoint(() async {
        writes.add('checkpoint');
        throw StateError('disk failure');
      }, onError: (error, _) => errors.add(error));
      final value = persistence.freezeFinalization(Object.new);
      await persistence.saveFinal((session) async {
        expect(identical(session, value), isTrue);
        writes.add('final');
      });
      await checkpoint;
      expect(errors, hasLength(1));
      expect(writes, ['checkpoint', 'final']);
    },
  );

  test(
    'final save waits for pending checkpoint, seals queue, and freezes retry',
    () async {
      final persistence = RecordingPersistence<Object>();
      final blocked = Completer<void>();
      final writes = <String>[];
      final checkpoint = persistence.checkpoint(() async {
        writes.add('checkpoint-start');
        await blocked.future;
        writes.add('checkpoint-end');
      }, onError: (_, _) => fail('unexpected checkpoint error'));
      final frozen = persistence.freezeFinalization(Object.new);
      final firstWrite = persistence.saveFinal((session) async {
        expect(identical(session, frozen), isTrue);
        writes.add('final-attempt-1');
        throw StateError('disk full');
      });
      final rejected = expectLater(firstWrite, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(writes, ['checkpoint-start']);
      await persistence.checkpoint(
        () async {
          writes.add('late-checkpoint');
        },
        onError: (_, _) {},
        force: true,
      );
      blocked.complete();
      await checkpoint;
      await rejected;
      expect(
        identical(persistence.freezeFinalization(Object.new), frozen),
        isTrue,
      );
      await persistence.saveFinal((session) async {
        expect(identical(session, frozen), isTrue);
        writes.add('final-attempt-2');
      });
      expect(writes, [
        'checkpoint-start',
        'checkpoint-end',
        'final-attempt-1',
        'final-attempt-2',
      ]);
    },
  );

  test(
    'real recorder pauses early, awaits checkpoint and retries same final session',
    () async {
      final repo = _RecordingRepository()
        ..checkpointBlocker = Completer<void>()
        ..rejectFinalSave = true;
      final acquisition = IodSensorAcquisitionService();
      final controller = IodController(
        acquisitionService: acquisition,
        storage: IodExperimentStorage(),
        classifier: IodCompositeClassifier.liveMobile(),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => null),
          workoutRepositoryProvider.overrideWithValue(repo),
          workoutRecordingCoordinatorProvider.overrideWithValue(
            _NoStorageCoordinator(),
          ),
          iodControllerProvider.overrideWith((ref) => controller),
          locationTrackingServiceProvider.overrideWithValue(_LocationService()),
          stepTrackingServiceProvider.overrideWithValue(_StepService()),
        ],
      );
      addTearDown(acquisition.dispose);
      addTearDown(container.dispose);
      final transitions = <RecordingState>[];
      final listener = container.listen(workoutSessionProvider, (_, next) {
        transitions.add(next.status);
      });
      addTearDown(listener.close);
      final notifier = container.read(workoutSessionProvider.notifier);
      const sessionId = 'a6e3e2f7-2bd1-4a23-873b-1c9fe8ff649d';
      notifier.state = WorkoutSessionState(
        status: RecordingState.active,
        sessionId: sessionId,
        activityType: 'Walking',
        trackingMode: 'indoor',
        recordingSource: 'step_fallback',
        durationSeconds: 4,
        movingTimeSeconds: 4,
        distanceMeters: 8,
        stepCount: 10,
        startedAt: DateTime.now().subtract(const Duration(seconds: 4)),
      );
      final pausing = notifier.pauseWorkout();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(workoutSessionProvider).status,
        RecordingState.paused,
      );
      expect(repo.attempts, hasLength(1));
      expect(repo.attempts.first.durationSec, 4);
      expect(
        (jsonDecode(repo.attempts.first.routeMatchMetricsJson)
            as Map)['recording_checkpoint'],
        true,
      );

      final stopping = notifier.stopWorkout();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(workoutSessionProvider).status,
        RecordingState.stopping,
      );
      expect(repo.attempts, hasLength(1));
      repo.checkpointBlocker!.complete();
      await pausing;
      await stopping;
      expect(
        container.read(workoutSessionProvider).status,
        RecordingState.error,
      );
      expect(transitions, isNot(contains(RecordingState.finished)));
      expect(repo.attempts, hasLength(2));
      final frozen = repo.attempts.last;
      expect(frozen.id, sessionId);
      expect(
        (jsonDecode(frozen.routeMatchMetricsJson)
            as Map)['recording_checkpoint'],
        isNull,
      );
      expect(repo.persisted[sessionId], same(repo.attempts.first));

      repo.rejectFinalSave = false;
      await notifier.stopWorkout();
      expect(
        container.read(workoutSessionProvider).status,
        RecordingState.finished,
      );
      expect(repo.attempts, hasLength(3));
      expect(repo.attempts.last, same(frozen));
      expect(repo.persisted[sessionId], same(frozen));
      expect(
        container.read(workoutSessionProvider).durationSeconds,
        frozen.durationSec,
      );
    },
  );
}
