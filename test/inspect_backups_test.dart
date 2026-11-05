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

  test('Inspect all iOS device Isar backup files using real Isar engine', () async {
    final backupDir = Directory('exports/research_7_sessions/ios_device_backup_20261105');
    expect(backupDir.existsSync(), isTrue);

    final allFiles = backupDir.listSync().whereType<File>().toList();
    final isarFiles = allFiles.where((f) => f.path.endsWith('.isar') || f.path.endsWith('.bak')).toList();

    print('Found ${isarFiles.length} Isar/bak files to inspect.');

    final targetWorkouts = {
      'cd4da398-b5d2-48f0-9065-cb6dce5f9cbf': 'S4',
      '5a777e45-7c8c-4f98-8f69-7b465034682d': 'S5',
      '18c54f6e-4c4f-4b93-a114-51fbde02b6e1': 'S6',
      '93af3737-54c0-456a-8e2a-62319ce898aa': 'S7',
      '1e26939b-81cb-4903-b109-50c13d270c06': 'S1',
      'e64747d3-9c21-4043-87fe-2cad7f4acedc': 'S2',
      'dd24bacf-dfba-495d-bad7-2a23d9d7363e': 'S3',
    };

    int totalWorkoutsFound = 0;
    int totalGpsPointsFound = 0;
    final Map<String, int> sessionGpsCounts = {};

    for (final file in isarFiles) {
      final tempDir = Directory.systemTemp.createTempSync('isar_inspect_backup_');
      try {
        final targetDb = File(p.join(tempDir.path, 'default.isar'));
        file.copySync(targetDb.path);

        Isar? isar;
        try {
          isar = await Isar.open(
            [
              LocalWorkoutSchema,
              LocalGPSPointSchema,
              LocalStepIntervalSchema,
            ],
            directory: tempDir.path,
            name: 'default',
            inspector: false,
          );
        } catch (e) {
          print('Failed to open ${p.basename(file.path)}: $e');
          continue;
        }

        final workouts = await isar.localWorkouts.where().findAll();
        final gpsPoints = await isar.localGPSPoints.where().findAll();
        final steps = await isar.localStepIntervals.where().findAll();

        if (workouts.isNotEmpty || gpsPoints.isNotEmpty) {
          print('FILE ${p.basename(file.path)}: workouts=${workouts.length}, gpsPoints=${gpsPoints.length}, steps=${steps.length}');
          totalWorkoutsFound += workouts.length;
          totalGpsPointsFound += gpsPoints.length;

          for (final w in workouts) {
            final tag = targetWorkouts[w.sessionId] ?? 'Unknown';
            print('  Found Workout: $tag (${w.sessionId}) - Dist: ${w.distanceKm} km, Duration: ${w.durationSec}s');
          }

          for (final pt in gpsPoints) {
            sessionGpsCounts[pt.sessionId] = (sessionGpsCounts[pt.sessionId] ?? 0) + 1;
          }
        }

        await isar.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    }

    print('==============================================');
    print('TOTAL INSPECTION SUMMARY:');
    print('Total Workouts Found: $totalWorkoutsFound');
    print('Total GPS Points Found: $totalGpsPointsFound');
    sessionGpsCounts.forEach((sid, count) {
      final tag = targetWorkouts[sid] ?? 'Unknown';
      print('  Session $tag ($sid): $count raw GPS points');
    });
    print('==============================================');
  });
}
