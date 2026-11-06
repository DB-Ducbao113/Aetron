// ignore_for_file: invalid_use_of_protected_member, avoid_print
import 'dart:ffi';
import 'dart:io';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

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

  test('Test Isar.open with restored schema IDs succeeds', () async {
    final tempDir = Directory.systemTemp.createTempSync('isar_open_test_success_');
    try {
      final isar = await Isar.open(
        [
          LocalWorkoutSchema,
          LocalGPSPointSchema,
          LocalStepIntervalSchema,
        ],
        name: 'isar_investigation_success_test',
        directory: tempDir.path,
        inspector: false,
      );
      expect(isar.isOpen, isTrue);
      await isar.close();
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('Test Isar.open with truncated schema ID throws IllegalArg: Collection id is invalid', () async {
    final tempDir = Directory.systemTemp.createTempSync('isar_open_test_fail_');
    try {
      final truncatedLocalWorkoutSchema = CollectionSchema(
        name: LocalWorkoutSchema.name,
        id: -3038458621972263, // Truncated! (missing 742 at end from commit caaa0c29)
        properties: LocalWorkoutSchema.properties,
        estimateSize: LocalWorkoutSchema.estimateSize,
        serialize: LocalWorkoutSchema.serialize,
        deserialize: LocalWorkoutSchema.deserialize,
        deserializeProp: LocalWorkoutSchema.deserializeProp,
        idName: LocalWorkoutSchema.idName,
        indexes: LocalWorkoutSchema.indexes,
        links: LocalWorkoutSchema.links,
        embeddedSchemas: LocalWorkoutSchema.embeddedSchemas,
        getId: LocalWorkoutSchema.getId,
        getLinks: LocalWorkoutSchema.getLinks,
        attach: LocalWorkoutSchema.attach,
        version: LocalWorkoutSchema.version,
      );

      expect(
        () async => await Isar.open(
          [truncatedLocalWorkoutSchema],
          name: 'isar_investigation_fail_test',
          directory: tempDir.path,
          inspector: false,
        ),
        throwsA(predicate((e) => e.toString().contains('Collection id is invalid'))),
      );
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
