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

  test('Verify newly initialized phone database schema and write/read capability', () async {
    final phoneDb = File('/tmp/iphone_post_launch/Documents/default.isar');
    expect(phoneDb.existsSync(), isTrue);

    final tempDir = Directory.systemTemp.createTempSync('phone_db_test_');
    try {
      final targetDb = File(p.join(tempDir.path, 'default.isar'));
      phoneDb.copySync(targetDb.path);

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

      expect(isar.isOpen, isTrue);
      print('Database from physical iPhone opened successfully with 0 errors!');

      // Verify all collections exist
      expect(isar.localWorkouts, isNotNull);
      expect(isar.localGPSPoints, isNotNull);
      expect(isar.localStepIntervals, isNotNull);
      print('Collections verified: localWorkouts, localGPSPoints, localStepIntervals');

      // Test write/read of a sample GPS point
      final testPoint = LocalGPSPoint()
        ..sessionId = 'test_smoke_session'
        ..timestamp = DateTime.now().toUtc()
        ..latitude = 10.762622
        ..longitude = 106.660172
        ..altitude = 12.0
        ..speed = 4.5
        ..accuracy = 3.2
        ..heading = 90.0
        ..confidence = 'high'
        ..isSynced = false;

      await isar.writeTxn(() async {
        await isar.localGPSPoints.put(testPoint);
      });

      final readBack = await isar.localGPSPoints
          .filter()
          .sessionIdEqualTo('test_smoke_session')
          .findFirst();

      expect(readBack, isNotNull);
      expect(readBack!.latitude, equals(10.762622));
      expect(readBack.longitude, equals(106.660172));
      expect(readBack.isSynced, isFalse);
      print('Local write and readback verified: point id=${readBack.id}, lat=${readBack.latitude}, lng=${readBack.longitude}');

      await isar.close();
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}

