import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _FakeRawTrackingRemoteDataSource implements RawTrackingRemoteDataSource {
  final List<List<RawGpsPointPayload>> uploadedGpsBatches = [];
  final List<List<RawStepIntervalPayload>> uploadedStepBatches = [];
  bool shouldThrowGps = false;
  bool shouldThrowStep = false;
  int gpsSaveCalls = 0;
  int stepSaveCalls = 0;

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    gpsSaveCalls++;
    if (shouldThrowGps) {
      throw StateError('Simulated network timeout during raw GPS upload');
    }
    uploadedGpsBatches.add(List<RawGpsPointPayload>.from(points));
  }

  @override
  Future<void> saveRawStepIntervals(
    List<RawStepIntervalPayload> intervals,
  ) async {
    stepSaveCalls++;
    if (shouldThrowStep) {
      throw StateError('Simulated network timeout during step interval upload');
    }
    uploadedStepBatches.add(List<RawStepIntervalPayload>.from(intervals));
  }
}

class _FakeWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  final List<String> createdShells = [];
  bool shellCreationThrows = false;

  @override
  Future<void> createSessionShell({
    required String id,
    required String userId,
    required String activityType,
    required String mode,
    required DateTime startedAt,
    required DateTime createdAt,
  }) async {
    if (shellCreationThrows) {
      throw StateError('Simulated error creating session shell');
    }
    createdShells.add(id);
  }

  @override
  Future<void> saveLiveRouteSnapshot({
    required String sessionId,
    required List<List<LatLng>> routeSegments,
    required bool shouldRequestRouteCorrection,
    required double? lastGpsGapDurationSec,
    required bool isGpsSignalWeak,
  }) async {}

  @override
  Future<void> saveSession(WorkoutSession session) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorkoutProcessingRemoteDataSource
    implements WorkoutProcessingRemoteDataSource {
  @override
  Future<String?> enqueueDeterministicJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async => 'job-123';

  @override
  Future<String?> enqueueRouteCorrectionJob({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) async => 'job-456';

  @override
  Future<void> insertLog({
    required String workoutId,
    String? jobId,
    required String eventType,
    required String message,
    required Map<String, dynamic> payload,
    String logLevel = 'info',
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _createPosition({
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  double accuracy = 4.0,
  double speed = 5.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 90.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 0.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRawTrackingRemoteDataSource fakeRawTracking;
  late _FakeWorkoutRemoteDataSource fakeWorkoutRemote;
  late _FakeWorkoutProcessingRemoteDataSource fakeProcessingRemote;
  late WorkoutRecordingCoordinator coordinator;

  setUp(() {
    fakeRawTracking = _FakeRawTrackingRemoteDataSource();
    fakeWorkoutRemote = _FakeWorkoutRemoteDataSource();
    fakeProcessingRemote = _FakeWorkoutProcessingRemoteDataSource();
    coordinator = WorkoutRecordingCoordinator(
      rawTracking: fakeRawTracking,
      workoutRemote: fakeWorkoutRemote,
      processingRemote: fakeProcessingRemote,
      currentUserId: () => 'test-user-uuid',
    );
  });

  tearDown(() {
    coordinator.dispose();
  });

  group('Raw tracking upload lifecycle and persistence resilience', () {
    test('delayed shell creation holds buffered points in RAM and flushes on ready', () async {
      const sessionId = 'session-delayed-shell';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 0, 0);

      // Buffer 5 points while remote shell is NOT ready
      for (var i = 0; i < 5; i++) {
        coordinator.bufferRawGpsPoint(
          _createPosition(
            latitude: 10.77 + i * 0.001,
            longitude: 106.69 + i * 0.001,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          workoutId: sessionId,
        );
      }

      expect(coordinator.pendingRawGpsPointCount, equals(5));
      expect(fakeRawTracking.uploadedGpsBatches, isEmpty);

      // Explicit flush without shell ready does not upload
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: false);
      expect(fakeRawTracking.uploadedGpsBatches, isEmpty);
      expect(coordinator.pendingRawGpsPointCount, equals(5));

      // Now remote shell becomes ready
      coordinator.markRemoteWorkoutShellReady();
      // Allow the unawaited flush inside markRemoteWorkoutShellReady to run
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fakeRawTracking.uploadedGpsBatches.length, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches.first.length, equals(5));
      expect(coordinator.pendingRawGpsPointCount, equals(0));
    });

    test('network upload failure retains buffered points without dropping data', () async {
      const sessionId = 'session-network-failure';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 10, 0);

      coordinator.markRemoteWorkoutShellReady();
      fakeRawTracking.shouldThrowGps = true;

      for (var i = 0; i < 4; i++) {
        coordinator.bufferRawGpsPoint(
          _createPosition(
            latitude: 10.77 + i * 0.001,
            longitude: 106.69 + i * 0.001,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          workoutId: sessionId,
        );
      }

      expect(coordinator.pendingRawGpsPointCount, equals(4));

      // Attempt flush - fails due to simulated network failure
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);

      expect(fakeRawTracking.gpsSaveCalls, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches, isEmpty);
      // Points MUST be retained in pending buffer!
      expect(coordinator.pendingRawGpsPointCount, equals(4));

      // Network recovers
      fakeRawTracking.shouldThrowGps = false;

      // Retry flush
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);

      expect(fakeRawTracking.gpsSaveCalls, equals(2));
      expect(fakeRawTracking.uploadedGpsBatches.length, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches.first.length, equals(4));
      expect(coordinator.pendingRawGpsPointCount, equals(0));
    });

    test('threshold auto-flush flushes batch of 24 points automatically', () async {
      const sessionId = 'session-threshold-flush';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 20, 0);

      coordinator.markRemoteWorkoutShellReady();

      // Buffer 23 points (threshold is 24)
      for (var i = 0; i < 23; i++) {
        coordinator.bufferRawGpsPoint(
          _createPosition(
            latitude: 10.77 + i * 0.0001,
            longitude: 106.69 + i * 0.0001,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          workoutId: sessionId,
        );
      }

      // No auto-flush yet
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(coordinator.pendingRawGpsPointCount, equals(23));
      expect(fakeRawTracking.uploadedGpsBatches, isEmpty);

      // Buffer the 24th point -> triggers auto-flush
      coordinator.bufferRawGpsPoint(
        _createPosition(
          latitude: 10.7724,
          longitude: 106.6924,
          timestamp: baseTime.add(const Duration(seconds: 24)),
        ),
        workoutId: sessionId,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(fakeRawTracking.uploadedGpsBatches.length, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches.first.length, equals(24));
      expect(coordinator.pendingRawGpsPointCount, equals(0));
    });

    test('step interval buffering and failure retry mirrors GPS point resilience', () async {
      const sessionId = 'session-step-intervals';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 30, 0);

      coordinator.markRemoteWorkoutShellReady();
      fakeRawTracking.shouldThrowStep = true;

      coordinator.bufferRawStepInterval(
        15,
        startedAt: baseTime,
        workoutId: sessionId,
      );
      coordinator.bufferRawStepInterval(
        22,
        startedAt: baseTime.add(const Duration(seconds: 10)),
        workoutId: sessionId,
      );

      expect(coordinator.pendingRawStepIntervalCount, equals(2));

      // Attempt forced flush with network error
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);
      expect(fakeRawTracking.stepSaveCalls, equals(1));
      expect(fakeRawTracking.uploadedStepBatches, isEmpty);
      expect(coordinator.pendingRawStepIntervalCount, equals(2));

      // Recover and retry
      fakeRawTracking.shouldThrowStep = false;
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);

      expect(fakeRawTracking.stepSaveCalls, equals(2));
      expect(fakeRawTracking.uploadedStepBatches.length, equals(1));
      expect(fakeRawTracking.uploadedStepBatches.first.length, equals(2));
      expect(coordinator.pendingRawStepIntervalCount, equals(0));
    });

    test('forced flush flushes remaining sub-threshold points at workout completion', () async {
      const sessionId = 'session-finish-flush';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 40, 0);

      coordinator.markRemoteWorkoutShellReady();

      // Buffer only 3 points (well below threshold 24)
      for (var i = 0; i < 3; i++) {
        coordinator.bufferRawGpsPoint(
          _createPosition(
            latitude: 10.77 + i * 0.001,
            longitude: 106.69 + i * 0.001,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          workoutId: sessionId,
        );
      }

      expect(coordinator.pendingRawGpsPointCount, equals(3));
      expect(fakeRawTracking.uploadedGpsBatches, isEmpty);

      // Emulate workout finalization: await forced flush
      await coordinator.flushPendingRawTracking(workoutId: sessionId, force: true);

      expect(fakeRawTracking.uploadedGpsBatches.length, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches.first.length, equals(3));
      expect(coordinator.pendingRawGpsPointCount, equals(0));

      // Disposal after flush cleanly terminates without error
      coordinator.dispose();
      expect(coordinator.pendingRawGpsPointCount, equals(0));
    });

    test('simultaneous forced flush calls serialize cleanly without double-flushing', () async {
      const sessionId = 'session-concurrent-flush';
      final baseTime = DateTime.utc(2026, 4, 15, 8, 50, 0);

      coordinator.markRemoteWorkoutShellReady();

      for (var i = 0; i < 6; i++) {
        coordinator.bufferRawGpsPoint(
          _createPosition(
            latitude: 10.77 + i * 0.001,
            longitude: 106.69 + i * 0.001,
            timestamp: baseTime.add(Duration(seconds: i)),
          ),
          workoutId: sessionId,
        );
      }

      expect(coordinator.pendingRawGpsPointCount, equals(6));

      // Launch 3 simultaneous flushPendingRawTracking calls
      await Future.wait([
        coordinator.flushPendingRawTracking(workoutId: sessionId, force: true),
        coordinator.flushPendingRawTracking(workoutId: sessionId, force: true),
        coordinator.flushPendingRawTracking(workoutId: sessionId, force: true),
      ]);

      // Exactly 1 upload batch occurred, remaining calls safely observed buffer drained
      expect(fakeRawTracking.uploadedGpsBatches.length, equals(1));
      expect(fakeRawTracking.uploadedGpsBatches.first.length, equals(6));
      expect(coordinator.pendingRawGpsPointCount, equals(0));
    });
  });
}
