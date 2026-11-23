// http is a transitive Supabase dependency; the mock transport never uses a network.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fitness_exercise_application/core/storage/database_helper.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_processing_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/workout_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/pending_workout_sync_store.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:fitness_exercise_application/features/workout/data/models/workout_session_model.dart';
import 'package:fitness_exercise_application/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = 'owner-a';
const _b = 'owner-b';

class _Auth extends Fake implements GoTrueClient {
  String? userId = _a;

  @override
  User? get currentUser => userId == null
      ? null
      : User(
          id: userId!,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        );
}

class _Client extends SupabaseClient {
  final _Auth fakeAuth = _Auth();

  _Client(MockClient transport)
    : super(
        'https://example.invalid',
        'test-anon-key',
        httpClient: transport,
        accessToken: () async => null,
      );

  @override
  GoTrueClient get auth => fakeAuth;
}

class _PendingStore extends PendingWorkoutSyncStore {
  _PendingStore() : super(DatabaseHelper.instance);

  final List<PendingWorkoutSyncOperation> operations = [];
  final List<String> failures = [];

  @override
  Future<List<PendingWorkoutSyncOperation>> listForUser(String userId) async =>
      operations.where((operation) => operation.userId == userId).toList();

  @override
  Future<List<PendingWorkoutSyncOperation>> listDue(
    String userId, {
    DateTime? now,
  }) => listForUser(userId);

  @override
  Future<void> enqueueDeleteSession({
    required String userId,
    required String sessionId,
  }) async => operations.add(
    PendingWorkoutSyncOperation.deleteSession(
      userId: userId,
      sessionId: sessionId,
    ),
  );

  @override
  Future<void> complete(String operationKey) async =>
      operations.removeWhere((operation) => operation.key == operationKey);

  @override
  Future<void> recordFailure(
    PendingWorkoutSyncOperation operation,
    Object error,
  ) async => failures.add(operation.key);
}

class _Raw extends RawTrackingRemoteDataSource {
  _Raw(super.supabase);
  final List<String> uploaded = [];
  void Function()? afterUpload;

  @override
  Future<void> saveRawGpsPoints(List<RawGpsPointPayload> points) async {
    uploaded.addAll(points.map((point) => point.workoutId));
    afterUpload?.call();
  }
}

WorkoutSession _session(
  String id, {
  String owner = _a,
  int duration = 60,
  int day = 1,
}) => WorkoutSession(
  id: id,
  userId: owner,
  activityType: 'running',
  startedAt: DateTime.utc(2026, 1, day),
  endedAt: DateTime.utc(2026, 1, day, 0, 1),
  durationSec: duration,
  movingTimeSec: duration,
  distanceKm: duration == 0 ? 0 : 1,
  steps: 0,
  avgSpeedKmh: 0,
  caloriesKcal: 0,
  mode: 'outdoor',
  createdAt: DateTime.utc(2026, 1, day),
);

http.Response _rows(http.Request request, List<WorkoutSession> sessions) =>
    http.Response(
      jsonEncode(
        sessions
            .map((s) => WorkoutSessionModel.fromEntity(s).toJson())
            .toList(),
      ),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

WorkoutRepositoryImpl _repo(
  _Client client, {
  _PendingStore? store,
  _Raw? raw,
}) => WorkoutRepositoryImpl(
  WorkoutRemoteDataSource(client),
  raw ?? _Raw(client),
  WorkoutProcessingRemoteDataSource(client),
  client,
  pendingSyncStore: store ?? _PendingStore(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'keyset pagination continues through short and zero-metric pages',
    () async {
      final requested = <String?>[];
      final client = _Client(
        MockClient((request) async {
          final query = request.url.queryParameters;
          expect(query['user_id'], 'eq.$_a');
          expect(query['order'], 'id.asc.nullslast');
          requested.add(query['id']);
          switch (query['id']) {
            case null:
              return _rows(request, [
                _session('001'),
                _session('002', duration: 0),
              ]);
            case 'gt.002':
              return _rows(request, [_session('003', duration: 0)]);
            case 'gt.003':
              return _rows(request, [
                _session('004', day: 2),
                _session('005', day: 2),
              ]);
            case 'gt.005':
              return _rows(request, []);
            default:
              fail('Unexpected cursor: ${query['id']}');
          }
        }),
      );
      addTearDown(client.dispose);
      final result = await WorkoutRemoteDataSource(
        client,
      ).getSessionsByUser(_a);
      expect(requested, [null, 'gt.002', 'gt.003', 'gt.005']);
      expect(result.map((s) => s.id), ['004', '005', '001']);
    },
  );

  test('later page failure rejects the whole remote result', () async {
    final client = _Client(
      MockClient((request) async {
        if (request.url.queryParameters['id'] == null) {
          return _rows(request, [_session('001')]);
        }
        return http.Response(
          '{"message":"unavailable","code":"XX000"}',
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      WorkoutRemoteDataSource(client).getSessionsByUser(_a),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'nonadvancing cursor is rejected rather than returning partial data',
    () async {
      final client = _Client(
        MockClient((request) async => _rows(request, [_session('001')])),
      );
      addTearDown(client.dispose);
      await expectLater(
        WorkoutRemoteDataSource(client).getSessionsByUser(_a),
        throwsStateError,
      );
    },
  );

  test(
    'account switch while fetching a page discards old account results',
    () async {
      late _Client client;
      final release = Completer<void>();
      final started = Completer<void>();
      client = _Client(
        MockClient((request) async {
          started.complete();
          await release.future;
          return _rows(request, [_session('001')]);
        }),
      );
      addTearDown(client.dispose);
      final fetch = _repo(client).fetchSessionsRemote(_a);
      final assertion = expectLater(fetch, throwsStateError);
      await started.future;
      client.fakeAuth.userId = _b;
      release.complete();
      await assertion;
    },
  );

  test(
    'signed-out and foreign-owner operations cannot reach remote transport',
    () async {
      final client = _Client(
        MockClient((_) async => fail('Unexpected request')),
      );
      addTearDown(client.dispose);
      final repo = _repo(client);
      await expectLater(repo.fetchSessionsRemote(_b), throwsStateError);
      await expectLater(
        repo.saveSessionRemote(_session('001', owner: _b)),
        throwsStateError,
      );
      await expectLater(repo.deleteAllSessions(_b), throwsStateError);
      expect(await repo.getSessionsLocal(_b), isEmpty);
      client.fakeAuth.userId = null;
      expect(await repo.getSessionById('001'), isNull);
      expect(await repo.syncRouteMatchResult('001'), isFalse);
      await repo.deleteSession('001');
    },
  );

  test(
    'direct remote delete and detail requests include owner filter',
    () async {
      final client = _Client(
        MockClient((request) async {
          expect(request.url.queryParameters['id'], 'eq.001');
          expect(request.url.queryParameters['user_id'], 'eq.$_a');
          if (request.method == 'DELETE') {
            return http.Response('', 204, request: request);
          }
          // Even if the service returned an unexpected owner, reject it.
          return _rows(request, [_session('001', owner: _b)]);
        }),
      );
      addTearDown(client.dispose);
      final remote = WorkoutRemoteDataSource(client);
      expect(await remote.getSessionById('001'), isNull);
      expect(await remote.getRouteMatchPayload('001'), isNull);
      await remote.deleteSession('001');
    },
  );

  final nativeLib = File(
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
    'isar_flutter_libs-3.1.0+1/macos/libisar.dylib',
  );
  group(
    'actual isolated Isar repository',
    () {
      late Directory temp;
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

      setUpAll(() async {
        temp = await Directory.systemTemp.createTemp('aetron-repo-ownership-');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
        await Isar.initializeIsarCore(
          libraries: {
            Abi.macosArm64: nativeLib.path,
            Abi.macosX64: nativeLib.path,
          },
        );
        await LocalDB.init();
        expect(Isar.getInstance()!.directory, temp.path);
      });

      tearDownAll(() async {
        await Isar.getInstance()?.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        await temp.delete(recursive: true);
      });

      test(
        'foreign cached workout cannot be read, overwritten or deleted',
        () async {
          final foreign = _session('foreign-local', owner: _b);
          await LocalDB.saveSession(LocalWorkout.fromEntity(foreign));
          final client = _Client(
            MockClient((_) async => fail('Unexpected request')),
          );
          addTearDown(client.dispose);
          final store = _PendingStore();
          final repo = _repo(client, store: store);
          expect(await repo.getSessionById(foreign.id), isNull);
          await expectLater(repo.deleteSession(foreign.id), throwsStateError);
          await expectLater(
            repo.cacheSessionLocal(_session(foreign.id)),
            throwsStateError,
          );
          expect(await repo.syncRouteMatchResult(foreign.id), isFalse);
          expect(store.operations, isEmpty);
          expect((await LocalDB.getSessionById(foreign.id))!.userId, _b);
        },
      );

      test(
        'orphan and other-account raw records remain queued; owned synced raw uploads',
        () async {
          final client = _Client(
            MockClient((_) async => fail('Unexpected request')),
          );
          addTearDown(client.dispose);
          final raw = _Raw(client);
          final repo = _repo(client, raw: raw);
          await LocalDB.saveSession(
            LocalWorkout.fromEntity(_session('owned-raw'), isSynced: true),
          );
          await LocalDB.saveSession(
            LocalWorkout.fromEntity(
              _session('foreign-raw', owner: _b),
              isSynced: true,
            ),
          );
          for (final id in ['owned-raw', 'foreign-raw', 'orphan-raw']) {
            await LocalDB.saveRawGpsPoint(
              LocalGPSPoint()
                ..sessionId = id
                ..timestamp = DateTime.utc(2026, 1, 1)
                ..latitude = 10
                ..longitude = 106
                ..confidence = 'high',
            );
          }
          await repo.syncPendingData();
          expect(raw.uploaded, ['owned-raw']);
          expect(
            await LocalDB.getUnsyncedGpsPointsForSession('owned-raw'),
            isEmpty,
          );
          expect(
            await LocalDB.getUnsyncedGpsPointsForSession('foreign-raw'),
            hasLength(1),
          );
          expect(
            await LocalDB.getUnsyncedGpsPointsForSession('orphan-raw'),
            hasLength(1),
          );
        },
      );

      test(
        'switching accounts during raw upload leaves the batch pending',
        () async {
          final client = _Client(
            MockClient((_) async => fail('Unexpected request')),
          );
          addTearDown(client.dispose);
          final raw = _Raw(client)
            ..afterUpload = () => client.fakeAuth.userId = _b;
          final repo = _repo(client, raw: raw);
          const sessionId = 'switch-during-raw';
          await LocalDB.saveSession(
            LocalWorkout.fromEntity(_session(sessionId), isSynced: true),
          );
          await LocalDB.savePoints([
            for (var i = 0; i < 251; i++)
              LocalGPSPoint()
                ..sessionId = sessionId
                ..timestamp = DateTime.utc(2026, 1, 1).add(Duration(seconds: i))
                ..latitude = 10
                ..longitude = 106
                ..confidence = 'high',
          ]);
          await repo.syncPendingData();
          expect(raw.uploaded, List.filled(250, sessionId));
          expect(
            await LocalDB.getUnsyncedGpsPointsForSession(sessionId),
            hasLength(251),
          );
        },
      );

      test(
        'zero-metric pending workouts retain raw evidence and are not uploaded',
        () async {
          const owner = 'legacy-zero-metric-owner';
          var remoteRequests = 0;
          final client = _Client(
            MockClient((_) async {
              remoteRequests++;
              return http.Response('Unexpected request', 500);
            }),
          );
          client.fakeAuth.userId = owner;
          addTearDown(client.dispose);
          final raw = _Raw(client);
          final repo = _repo(client, raw: raw);
          const ids = [
            'zero-gps-pending',
            'zero-gps-synced',
            'zero-steps-pending',
            'zero-steps-synced',
            'zero-empty',
          ];
          for (final id in ids) {
            await LocalDB.saveSession(
              LocalWorkout.fromEntity(_session(id, owner: owner, duration: 0)),
            );
          }
          for (final synced in [false, true]) {
            await LocalDB.saveRawGpsPoint(
              LocalGPSPoint()
                ..sessionId = synced ? ids[1] : ids[0]
                ..timestamp = DateTime.utc(2026)
                ..latitude = 10
                ..longitude = 106
                ..confidence = 'high'
                ..isSynced = synced,
            );
            await LocalDB.saveRawStepInterval(
              LocalStepInterval()
                ..sessionId = synced ? ids[3] : ids[2]
                ..intervalStart = DateTime.utc(2026)
                ..intervalEnd = DateTime.utc(2026, 1, 1, 0, 0, 5)
                ..stepsCount = 3
                ..isSynced = synced,
            );
          }

          await repo.syncPendingData();

          for (final id in ids) {
            final workout = await LocalDB.getSessionById(id);
            expect(workout, isNotNull, reason: '$id must be retained');
            expect(workout!.isSynced, isFalse);
          }
          for (final synced in [false, true]) {
            final gps = await LocalDB.getPointsForSession(
              synced ? ids[1] : ids[0],
            );
            expect(gps.single.isSynced, synced);
            final steps = await LocalDB.instance.localStepIntervals
                .filter()
                .sessionIdEqualTo(synced ? ids[3] : ids[2])
                .findAll();
            expect(steps.single.stepsCount, 3);
            expect(steps.single.isSynced, synced);
          }
          expect(await LocalDB.getSessionsByUser(owner), isEmpty);
          expect(raw.uploaded, isEmpty);
          expect(remoteRequests, 0);
        },
      );

      test(
        'partial history preserves absent and conflicting unsynced workouts',
        () async {
          final client = _Client(
            MockClient((_) async => fail('Unexpected request')),
          );
          addTearDown(client.dispose);
          final repo = _repo(client);
          final missing = _session('absent-from-history');
          final unsynced = _session('pending-history', duration: 180);
          await LocalDB.saveSession(
            LocalWorkout.fromEntity(missing, isSynced: true),
          );
          await LocalDB.saveSession(LocalWorkout.fromEntity(unsynced));
          await repo.replaceLocalCache(_a, [
            _session('pending-history', duration: 30),
            _session('new-history'),
          ]);
          final kept = await LocalDB.getSessionById(unsynced.id);
          expect(kept!.durationSec, 180);
          expect(kept.isSynced, isFalse);
          expect(await LocalDB.getSessionById(missing.id), isNotNull);
          expect(await LocalDB.getSessionById('new-history'), isNotNull);
        },
      );

      test(
        'local transaction rejects foreign UUID and stale checkpoints',
        () async {
          final finalSession = _session('durable-final');
          await LocalDB.saveSession(LocalWorkout.fromEntity(finalSession));
          await expectLater(
            LocalDB.saveSession(
              LocalWorkout.fromEntity(finalSession.copyWith(userId: _b)),
            ),
            throwsStateError,
          );
          await expectLater(
            LocalDB.saveSession(
              LocalWorkout.fromEntity(
                finalSession.copyWith(
                  routeMatchMetricsJson: '{"recording_checkpoint":true}',
                ),
              ),
            ),
            throwsStateError,
          );
          expect(
            (await LocalDB.getSessionById(
              finalSession.id,
            ))!.sameSnapshot(LocalWorkout.fromEntity(finalSession)),
            isTrue,
          );
        },
      );

      test(
        'checkpoint remains recoverable and cannot upload as a final workout',
        () async {
          final owner = 'checkpoint-owner';
          final client = _Client(
            MockClient((_) async => fail('Unexpected request')),
          );
          client.fakeAuth.userId = owner;
          addTearDown(client.dispose);
          final repo = _repo(client);
          const id = 'recoverable-checkpoint';
          final checkpoint = _session(
            id,
            owner: owner,
          ).copyWith(routeMatchMetricsJson: '{"recording_checkpoint":true}');
          await LocalDB.saveSession(LocalWorkout.fromEntity(checkpoint));
          await repo.syncPendingData();
          await expectLater(
            repo.saveSessionRemote(checkpoint),
            throwsStateError,
          );
          expect(await LocalDB.getSessionsByUser(owner), isEmpty);
          expect(
            LocalDB.isRecordingCheckpoint((await LocalDB.getSessionById(id))!),
            isTrue,
          );
          final recovered = checkpoint.copyWith(
            routeMatchMetricsJson: '{"recording_recovered":true}',
          );
          await repo.cacheSessionLocal(recovered);
          expect(
            (await LocalDB.getSessionsByUser(
              owner,
            )).single.sameSnapshot(LocalWorkout.fromEntity(recovered)),
            isTrue,
          );
        },
      );

      test(
        'readable backup restores all three collections without modifying original',
        () async {
          final scratch = await Directory.systemTemp.createTemp(
            'isar-recovery-test-',
          );
          addTearDown(() => scratch.delete(recursive: true));
          final schemas = [
            LocalWorkoutSchema,
            LocalGPSPointSchema,
            LocalStepIntervalSchema,
          ];
          final source = await Isar.open(
            schemas,
            directory: scratch.path,
            name: 'original',
            inspector: false,
            relaxedDurability: false,
          );
          final workout = _session('recover-original');
          await source.writeTxn(() async {
            await source.localWorkouts.put(LocalWorkout.fromEntity(workout));
            await source.localGPSPoints.put(
              LocalGPSPoint()
                ..sessionId = workout.id
                ..timestamp = DateTime.utc(2026)
                ..latitude = 10
                ..longitude = 106
                ..confidence = 'high',
            );
            await source.localStepIntervals.put(
              LocalStepInterval()
                ..sessionId = workout.id
                ..intervalStart = DateTime.utc(2026)
                ..intervalEnd = DateTime.utc(2026, 1, 1, 0, 0, 1)
                ..stepsCount = 2,
            );
          });
          await source.close();
          final original = File('${scratch.path}/original.isar');
          final bytes = await original.readAsBytes();
          final target = await Isar.open(
            schemas,
            directory: scratch.path,
            name: 'target',
            inspector: false,
            relaxedDurability: false,
          );
          try {
            expect(
              await LocalDB.restoreReadableBackup(original, target),
              isTrue,
            );
            expect(
              (await target.localWorkouts.where().findAll()).single
                  .sameSnapshot(LocalWorkout.fromEntity(workout)),
              isTrue,
            );
            expect(await target.localGPSPoints.count(), 1);
            expect(await target.localStepIntervals.count(), 1);
            expect(await original.readAsBytes(), bytes);
            expect(
              await LocalDB.restoreReadableBackup(original, target),
              isFalse,
            );
            expect(await target.localWorkouts.count(), 1);
          } finally {
            await target.close();
          }
        },
      );
    },
    skip: !Platform.isMacOS || !nativeLib.existsSync()
        ? 'Requires the locally installed macOS Isar core (no download in tests).'
        : false,
  );
}
