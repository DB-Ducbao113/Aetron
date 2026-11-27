import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  test(
    'Compare physical recording GPS sample identities',
    () async {
      final path = Platform.environment['AETRON_PHONE_AUDIT_DIR']!;
      final session = Platform.environment['AETRON_PHONE_SESSION_ID']!;
    final library =
        '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/macos/libisar.dylib';
    await Isar.initializeIsarCore(
      libraries: {Abi.macosArm64: library, Abi.macosX64: library},
    );
    final directory = Directory.systemTemp.createTempSync('aetron-key-audit-');
    Isar? db;
    try {
      File('$path/default.isar').copySync('${directory.path}/default.isar');
      db = await Isar.open(
        [LocalWorkoutSchema, LocalGPSPointSchema, LocalStepIntervalSchema],
        directory: directory.path,
        inspector: false,
      );
      final points = await db.localGPSPoints
          .filter()
          .sessionIdEqualTo(session)
          .findAll();
      final cloud =
          jsonDecode(File('$path/gps-keys.json').readAsStringSync()) as List;
      String key(DateTime time, num lat, num lon) =>
          '${time.millisecondsSinceEpoch}|${lat.toStringAsFixed(7)}|${lon.toStringAsFixed(7)}';
      final localKeys = points
          .map((p) => key(p.timestamp, p.latitude, p.longitude))
          .toSet();
      final cloudKeys = cloud
          .map(
            (p) => key(
              DateTime.parse(p['timestamp'] as String),
              p['latitude'] as num,
              p['longitude'] as num,
            ),
          )
          .toSet();
      // Only emit aggregate evidence, never coordinates.
      // ignore: avoid_print
      print(
        jsonEncode({
          'localRows': points.length,
          'localUniqueKeys': localKeys.length,
          'cloudRows': cloud.length,
          'cloudUniqueKeys': cloudKeys.length,
          'localOnlyKeys': localKeys.difference(cloudKeys).length,
          'cloudOnlyKeys': cloudKeys.difference(localKeys).length,
          'timeOverlap': points
              .map((p) => p.timestamp.millisecondsSinceEpoch)
              .toSet()
              .intersection(
                cloud
                    .map(
                      (p) => DateTime.parse(
                        p['timestamp'] as String,
                      ).millisecondsSinceEpoch,
                    )
                    .toSet(),
              )
              .length,
        }),
      );
      expect(points, isNotEmpty);
      expect(
        localKeys,
        cloudKeys,
        reason: 'GPS identities at millisecond/7-decimal coordinate resolution',
      );
    } finally {
      await db?.close();
      directory.deleteSync(recursive: true);
    }
  },
  skip: Platform.environment['AETRON_PHONE_AUDIT_DIR'] == null
      ? 'Requires AETRON_PHONE_AUDIT_DIR'
      : false,
  tags: 'external-data');
}
