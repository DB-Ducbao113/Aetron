// ignore_for_file: avoid_print
import 'dart:ffi';
import 'dart:io';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Platform.isMacOS) {
      final pubCacheLib = File(
        '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/macos/libisar.dylib',
      );
      if (pubCacheLib.existsSync()) {
        await Isar.initializeIsarCore(
          libraries: {
            Abi.macosArm64: pubCacheLib.path,
            Abi.macosX64: pubCacheLib.path,
          },
        );
      }
    }
  });

  test('Inspect live iPhone default.isar contents', () async {
    final liveDb = File('/tmp/iphone_live_check/Documents/default.isar');
    expect(liveDb.existsSync(), isTrue);

    final tempDir = Directory.systemTemp.createTempSync('live_inspect_');
    try {
      final targetDb = File(p.join(tempDir.path, 'default.isar'));
      liveDb.copySync(targetDb.path);

      final isar = await Isar.open(
        [
          LocalWorkoutSchema,
          LocalGPSPointSchema,
          LocalStepIntervalSchema,
        ],
        directory: tempDir.path,
        name: 'default',
        inspector: false,
      );

      final workouts = await isar.localWorkouts.where().findAll();
      final gpsPoints = await isar.localGPSPoints.where().findAll();
      final steps = await isar.localStepIntervals.where().findAll();

      print('================ LIVE IPHONE ISAR STATUS ================');
      print('Total Workouts in Isar: ${workouts.length}');
      print('Total GPS Points in Isar: ${gpsPoints.length}');
      print('Total Step Intervals in Isar: ${steps.length}');

      for (final w in workouts) {
        print('Workout: ${w.sessionId} | ${w.activityType} | dist=${w.distanceKm}km | dur=${w.durationSec}s | synced=${w.isSynced}');
      }

      final pointsBySession = <String, int>{};
      final unsyncedBySession = <String, int>{};
      for (final pt in gpsPoints) {
        pointsBySession[pt.sessionId] = (pointsBySession[pt.sessionId] ?? 0) + 1;
        if (!pt.isSynced) {
          unsyncedBySession[pt.sessionId] = (unsyncedBySession[pt.sessionId] ?? 0) + 1;
        }
      }

      pointsBySession.forEach((sid, count) {
        final unsynced = unsyncedBySession[sid] ?? 0;
        print('Session $sid: totalPoints=$count, unsyncedPoints=$unsynced');
      });
      print('=========================================================');

      await isar.close();
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}

