import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_step_interval.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Inspect copied iPhone Isar and reconcile stale cloud sessions',
    () async {
      final path = Platform.environment['AETRON_PHONE_AUDIT_DIR'];
    expect(path, isNotNull);
    final source = Directory(path!);
    final rows =
        jsonDecode(File('${source.path}/cloud.json').readAsStringSync())
            as List;
    final library =
        '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/macos/libisar.dylib';
    await Isar.initializeIsarCore(
      libraries: {Abi.macosArm64: library, Abi.macosX64: library},
    );
    final backups = Directory('${source.path}/backups');
    final snapshots = [
      File('${source.path}/default.isar'),
      if (backups.existsSync())
        ...backups.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.bak'),
        ),
    ];
    final reports = <Map<String, dynamic>>[];
    for (final snapshot in snapshots) {
      final scratch = Directory.systemTemp.createTempSync(
        'aetron-phone-reconcile-',
      );
      Isar? db;
      try {
        snapshot.copySync('${scratch.path}/default.isar');
        db = await Isar.open(
          [LocalWorkoutSchema, LocalGPSPointSchema, LocalStepIntervalSchema],
          directory: scratch.path,
          inspector: false,
        );
        final workouts = await db.localWorkouts.where().findAll();
        final gps = await db.localGPSPoints.where().findAll();
        final steps = await db.localStepIntervals.where().findAll();
        final result = <String, dynamic>{
          'snapshot': snapshot.uri.pathSegments.last,
          'workouts': workouts.length,
          'unsynced_workouts': workouts.where((w) => !w.isSynced).length,
          'gps': gps.length,
          'unsynced_gps': gps.where((p) => !p.isSynced).length,
          'step_intervals': steps.length,
          'unsynced_step_intervals': steps.where((p) => !p.isSynced).length,
        };
        final comparisons = <Map<String, dynamic>>[];
        for (final entry in rows) {
          final id = entry['workout_id'] as String;
          final matches = workouts.where((w) => w.sessionId == id).toList();
          final localGps = gps.where((p) => p.sessionId == id).toList();
          final localSteps = steps.where((p) => p.sessionId == id).toList();
          final w = matches.isEmpty ? null : matches.single;
          final metadata = w == null
              ? null
              : jsonDecode(w.routeMatchMetricsJson);
          final gpsLatest = DateTime.tryParse(
            entry['gps_latest']?.toString() ?? '',
          );
          final stepsLatest = DateTime.tryParse(
            entry['steps_latest']?.toString() ?? '',
          );
          comparisons.add({
            'cloud_gps': entry['raw_gps_points'],
            'cloud_step_intervals': entry['raw_step_intervals'],
            'local_summary': w != null,
            'owner_matches': w == null ? null : w.userId == entry['user_id'],
            'checkpoint':
                metadata is Map && metadata['recording_checkpoint'] == true,
            'synced': w?.isSynced,
            'duration_seconds': w?.durationSec,
            'local_gps': localGps.length,
            'local_step_intervals': localSteps.length,
            'cloud_samples_after_local_end': w == null
                ? null
                : (gpsLatest?.isAfter(w.endedAt) ?? false) ||
                      (stepsLatest?.isAfter(w.endedAt) ?? false),
            'local_samples_after_local_end': w == null
                ? null
                : localGps.any((p) => p.timestamp.isAfter(w.endedAt)) ||
                      localSteps.any((p) => p.intervalEnd.isAfter(w.endedAt)),
          });
        }
        result['interrupted_sessions'] = comparisons;
        reports.add(result);
      } catch (error) {
        reports.add({
          'snapshot': snapshot.uri.pathSegments.last,
          'read_failed': true,
        });
      } finally {
        await db?.close();
        scratch.deleteSync(recursive: true);
      }
    }
    expect(reports.first['read_failed'], isNot(true));
    File(
      '${source.path}/audit-result.json',
    ).writeAsStringSync(jsonEncode(reports));
    // ignore: avoid_print
    print(jsonEncode(reports));
  },
  skip: Platform.environment['AETRON_PHONE_AUDIT_DIR'] == null
      ? 'Requires AETRON_PHONE_AUDIT_DIR'
      : false,
  tags: 'external-data');
}
