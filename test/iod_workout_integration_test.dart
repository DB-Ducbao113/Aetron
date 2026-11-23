// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';

import 'package:fitness_exercise_application/features/iod/data/datasources/iod_sensor_acquisition_service.dart';
import 'package:fitness_exercise_application/features/iod/data/repositories/iod_experiment_storage.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_environment_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tooling/benchmark/ciod_dataset_adapter.dart';

class _NoStorageCoordinator implements WorkoutRecordingCoordinator {
  @override
  Future<void> drainLocalWrites() async {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestIodController extends IodController {
  _TestIodController(IodSensorAcquisitionService acquisition)
    : super(
        acquisitionService: acquisition,
        storage: IodExperimentStorage(),
        classifier: IodCompositeClassifier.liveMobile(),
      );

  void publish(IodState next) => state = next;
}

IodSensorSnapshot snapshot(DateTime timestamp, {double? lux = 200}) =>
    IodSensorSnapshot(
      timestamp: timestamp,
      hasLightSensor: lux != null,
      ambientLux: lux,
      hasImuData: true,
      magneticMagnitudeMean: 44,
      accelMagnitudeMean: 0.3,
    );

IodState neuralState(DateTime now, {String session = 'session-1'}) {
  final classifier = IodCompositeClassifier.liveMobile();
  late IodSensorSnapshot latest;
  late IodPrediction prediction;
  for (var i = 0; i < 10; i++) {
    latest = snapshot(now.subtract(Duration(seconds: 9 - i)));
    prediction = classifier.predict(latest);
  }
  return IodState(
    isRecording: true,
    sessionId: session,
    currentPrediction: prediction,
    latestSnapshot: latest,
    totalSamplesCount: 10,
  );
}

WorkoutSessionState workout(
  DateTime now, {
  String activity = 'Walking',
  RecordingState status = RecordingState.active,
  String mode = 'outdoor',
  String source = 'gps',
  bool fallback = false,
}) => WorkoutSessionState(
  status: status,
  sessionId: 'session-1',
  activityType: activity,
  trackingMode: mode,
  recordingSource: source,
  environmentHint: 'detecting',
  gpsFallbackActive: fallback,
  modeDecisionLocked: true,
  startedAt: now.subtract(const Duration(minutes: 1)),
  distanceMeters: 123.4,
  stepCount: 20,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clock = DateTime.utc(2026, 11, 18, 10);

  test('real C-Mobile output advises unresolved hint, not tracking mode', () {
    final iod = neuralState(clock);
    final current = workout(clock);
    final advice = WorkoutEnvironmentController.resolveIodAdvice(
      workout: current,
      legacyHint: 'detecting',
      iod: iod,
      now: clock,
      lastAcceptedGpsAt: null,
    );
    expect(advice.usedForHint, isTrue);
    expect(advice.hint, iod.currentPrediction.state.code);
    expect(current.trackingMode, 'outdoor');
    expect(current.recordingSource, 'gps');
    expect(current.distanceMeters, 123.4);
  });

  test('legacy agreement corroborates, disagreement and fresh GPS win', () {
    final iod = neuralState(clock);
    final hint = iod.currentPrediction.state.code;
    final opposite = hint == 'indoor' ? 'outdoor' : 'indoor';
    IodEnvironmentAdvice resolve(String base, {DateTime? gps}) =>
        WorkoutEnvironmentController.resolveIodAdvice(
          workout: workout(clock),
          legacyHint: base,
          iod: iod,
          now: clock,
          lastAcceptedGpsAt: gps,
        );
    expect(resolve(hint).corroborated, isTrue);
    expect(resolve(opposite).hint, opposite);
    expect(resolve(opposite).usedForHint, isFalse);
    expect(resolve('detecting', gps: clock).hint, 'detecting');
  });

  test(
    'rejects stale, future, wrong-session, warm-up and GPS fallback advice',
    () {
      final valid = neuralState(clock);
      final gpsOnly = IodCompositeClassifier.liveMobile().predict(
        IodSensorSnapshot(
          timestamp: clock,
          hasGpsFix: true,
          horizontalAccuracy: 25,
        ),
      );
      final bad = [
        neuralState(clock.subtract(const Duration(seconds: 3))),
        neuralState(clock.add(const Duration(seconds: 1))),
        neuralState(clock, session: 'previous-session'),
        valid.copyWith(totalSamplesCount: 9),
        valid.copyWith(isRecording: false),
        valid.copyWith(latestSnapshot: snapshot(clock, lux: null)),
        valid.copyWith(currentPrediction: gpsOnly),
        valid.copyWith(currentPrediction: IodPrediction.unknown()),
      ];
      for (final iod in bad) {
        final advice = WorkoutEnvironmentController.resolveIodAdvice(
          workout: workout(clock),
          legacyHint: 'detecting',
          iod: iod,
          now: clock,
          lastAcceptedGpsAt: null,
        );
        expect(
          advice.hint,
          'detecting',
          reason: iod.currentPrediction.nativeClass,
        );
        expect(advice.usedForHint, isFalse);
        expect(advice.corroborated, isFalse);
      }
    },
  );

  test('paused, indoor-only and existing fallback keep their own hints', () {
    final iod = neuralState(clock);
    for (final current in [
      workout(clock, status: RecordingState.paused),
      workout(clock, activity: 'Yoga', mode: 'indoor', source: 'step_fallback'),
      workout(clock, mode: 'indoor'),
      workout(clock, mode: 'indoor', source: 'step_fallback', fallback: true),
    ]) {
      final advice = WorkoutEnvironmentController.resolveIodAdvice(
        workout: current,
        legacyHint: 'detecting',
        iod: iod,
        now: clock,
        lastAcceptedGpsAt: null,
      );
      expect(advice.usedForHint, isFalse);
      expect(advice.hint, 'detecting');
    }
  });

  test(
    'Riverpod workout listener applies and withdraws IOD hints without handover',
    () {
      final acquisition = IodSensorAcquisitionService();
      final controller = _TestIodController(acquisition);
      final container = ProviderContainer(
        overrides: [
          workoutRecordingCoordinatorProvider.overrideWithValue(
            _NoStorageCoordinator(),
          ),
          iodControllerProvider.overrideWith((ref) => controller),
        ],
      );
      addTearDown(acquisition.dispose);
      addTearDown(container.dispose);
      final sub = container.listen(workoutSessionProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(workoutSessionProvider.notifier);
      final now = DateTime.now();
      final initial = workout(now);
      notifier.state = initial;
      final iod = neuralState(now);
      controller.publish(iod);
      var actual = container.read(workoutSessionProvider);
      expect(actual.environmentHint, iod.currentPrediction.state.code);
      expect(actual.trackingMode, initial.trackingMode);
      expect(actual.recordingSource, initial.recordingSource);
      expect(actual.gpsFallbackActive, isFalse);
      expect(actual.distanceMeters, initial.distanceMeters);
      expect(actual.stepCount, initial.stepCount);
      expect(actual.modeDecisionLocked, initial.modeDecisionLocked);
      controller.publish(
        iod.copyWith(currentPrediction: IodPrediction.unknown()),
      );
      actual = container.read(workoutSessionProvider);
      expect(actual.environmentHint, 'detecting');
      notifier.state = initial.copyWith(status: RecordingState.paused);
      controller.publish(iod);
      expect(
        container.read(workoutSessionProvider).environmentHint,
        'detecting',
      );
      expect(
        container.read(workoutSessionProvider).status,
        RecordingState.paused,
      );
      notifier.state = initial.copyWith(sessionId: 'new-session');
      controller.publish(iod.copyWith(totalSamplesCount: 11));
      expect(
        container.read(workoutSessionProvider).environmentHint,
        'detecting',
      );
      notifier.state = initial.copyWith(activityType: 'Cycling');
      controller.publish(neuralState(DateTime.now()));
      actual = container.read(workoutSessionProvider);
      expect(actual.recordingSource, 'gps');
      expect(actual.gpsFallbackActive, isFalse);
    },
  );

  final ciodPath = Platform.environment['AETRON_CIOD_CSV'];
  test(
    'CIOD source labels replay through live classifier and workout hint policy',
    () async {
      final samples = await CiodDatasetAdapter.parseCsvFile(
        file: File(ciodPath!),
        targetSessionIndices: Set<int>.from(List.generate(13, (i) => 72 + i)),
        maxSamplesPerSession: 0,
      );
      expect(samples.length, 201731);
      final classifier = IodCompositeClassifier.liveMobile();
      String? session;
      late DateTime start;
      var epoch = 0;
      var correct = 0;
      var evaluated = 0;
      var indoorCount = 0;
      var outdoorCount = 0;
      final matrix = <String, int>{};
      for (final sample in samples) {
        if (sample.sessionId != session) {
          session = sample.sessionId;
          epoch = 0;
          start = sample.timestamp;
          classifier.reset();
        }
        final prediction = classifier.predict(sample.snapshot);
        final iod = IodState(
          isRecording: true,
          sessionId: session,
          currentPrediction: prediction,
          latestSnapshot: sample.snapshot,
          totalSamplesCount: ++epoch,
        );
        final current = WorkoutSessionState(
          status: RecordingState.active,
          sessionId: session,
          startedAt: start,
          activityType: 'Walking',
          trackingMode: 'outdoor',
          environmentHint: 'detecting',
        );
        // CIOD does NOT contain GPS or OS step events. This exercises the
        // unresolved hint path only; no synthetic handover truth is added.
        final advice = WorkoutEnvironmentController.resolveIodAdvice(
          workout: current,
          legacyHint: 'detecting',
          iod: iod,
          now: sample.snapshot.timestamp,
          lastAcceptedGpsAt: null,
        );
        final truth = sample.groundTruth;
        if (truth == IndoorOutdoorState.indoor) indoorCount++;
        if (truth == IndoorOutdoorState.outdoor) outdoorCount++;
        final key = '${truth.code}:${advice.hint}';
        matrix.update(key, (n) => n + 1, ifAbsent: () => 1);
        if (advice.usedForHint) {
          evaluated++;
          expect(advice.hint, prediction.state.code);
          if (advice.hint == truth.code) correct++;
        } else {
          expect(advice.hint, 'detecting');
        }
      }
      expect(indoorCount, 118964);
      expect(outdoorCount, 82767);
      expect(evaluated, 201614);
      expect(correct, 148456);
      expect(matrix, {
        'indoor:indoor': 110985,
        'indoor:outdoor': 7880,
        'indoor:detecting': 99,
        'outdoor:indoor': 45278,
        'outdoor:outdoor': 37471,
        'outdoor:detecting': 18,
      });
    },
    skip: ciodPath == null
        ? 'Set AETRON_CIOD_CSV for original source replay'
        : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
