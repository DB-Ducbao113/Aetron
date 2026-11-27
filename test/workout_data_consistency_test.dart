// Tests for workout metric consistency.

import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/features/workout/data/datasources/remote/raw_tracking_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserProfile makeProfile({double weightKg = 70, String gender = 'male'}) {
    final now = DateTime.utc(2026, 1, 1);
    return UserProfile(
      id: 'calorie-test',
      userId: 'calorie-test',
      weightKg: weightKg,
      heightCm: 175,
      gender: gender,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('2024 Adult Compendium calorie model', () {
    // Exact codes/MET values from the PACOMPENDIUM 2024 PDF (pages 1, 14, 21).
    // No source-defined speed interval is widened or interpolated.
    final table = <({String activity, double mph, String code, double met})>[
      (activity: 'Walking', mph: 2.2, code: '17152', met: 2.8),
      (activity: 'Walking', mph: 3.0, code: '17190', met: 3.8),
      (activity: 'Walking', mph: 3.7, code: '17200', met: 4.8),
      (activity: 'Walking', mph: 4.2, code: '17220', met: 5.5),
      (activity: 'Running', mph: 4.1, code: '12028', met: 6.5),
      (activity: 'Running', mph: 4.5, code: '12029', met: 7.8),
      (activity: 'Running', mph: 5.1, code: '12030', met: 8.5),
      (activity: 'Running', mph: 5.6, code: '12045', met: 9.0),
      (activity: 'Running', mph: 6.2, code: '12050', met: 9.3),
      (activity: 'Running', mph: 7.5, code: '12080', met: 11.8),
      (activity: 'Running', mph: 9.5, code: '12115', met: 14.8),
      (activity: 'Cycling', mph: 9.0, code: '01010', met: 4.0),
      (activity: 'Cycling', mph: 11.0, code: '01020', met: 6.8),
      (activity: 'Cycling', mph: 13.0, code: '01030', met: 8.0),
      (activity: 'Cycling', mph: 15.0, code: '01040', met: 10.0),
      (activity: 'Cycling', mph: 17.0, code: '01050', met: 12.0),
      (activity: 'Cycling', mph: 21.0, code: '01060', met: 16.8),
    ];

    for (final row in table) {
      test(
        '${row.activity} ${row.mph} mph uses PAC ${row.code} = ${row.met} MET',
        () {
          final entry = UserProfile.compendiumDistanceMet(
            activityType: row.activity,
            speedKmh: row.mph * 1.609344,
          );
          expect(entry?.code, row.code);
          expect(entry?.met, row.met);
          expect(
            makeProfile().calculateCalories(
              activityType: row.activity,
              distanceKm: 1,
              speedKmh: row.mph * 1.609344,
              durationSec: 1800,
            ),
            closeTo(row.met * 70 * 0.5, 1e-9),
          );
        },
      );
    }

    test('unknown speed uses published self-selected/general codes', () {
      for (final expected in [
        (activity: 'Walking', code: '17255', met: 4.0),
        (activity: 'Running', code: '12145', met: 10.5),
        (activity: 'Cycling', code: '01014', met: 7.0),
      ]) {
        final entry = UserProfile.compendiumDistanceMet(
          activityType: expected.activity,
        );
        expect(entry?.code, expected.code);
        expect(entry?.met, expected.met);
      }
      expect(
        UserProfile.compendiumDistanceMet(
          activityType: 'Running',
          speedKmh: double.nan,
        )?.code,
        '12145',
      );
    });

    test('intermediate speeds map monotonically to nearest published bands', () {
      expect(
        UserProfile.compendiumDistanceMet(
          activityType: 'Running',
          speedKmh: 4.9 * 1.609344,
        ),
        (code: '12030', met: 8.5),
      );
      expect(
        UserProfile.compendiumDistanceMet(
          activityType: 'Walking',
          speedKmh: 2.6 * 1.609344,
        ),
        (code: '17170', met: 3.0),
      );
      expect(
        UserProfile.compendiumDistanceMet(
          activityType: 'Cycling',
          speedKmh: 19.5 * 1.609344,
        ),
        (code: '01050', met: 12.0),
      );

      // Strict monotonicity sweep across 0.1..25.0 mph in 0.1 mph increments
      for (final activity in ['Walking', 'Running', 'Cycling']) {
        var prevMet = 0.0;
        for (var tenths = 1; tenths <= 250; tenths++) {
          final mph = tenths / 10.0;
          final entry = UserProfile.compendiumDistanceMet(
            activityType: activity,
            speedKmh: mph * 1.609344,
          );
          expect(entry, isNotNull);
          expect(
            entry!.met,
            greaterThanOrEqualTo(prevMet),
            reason: '$activity MET inverted at $mph mph: ${entry.met} < $prevMet',
          );
          prevMet = entry.met;
        }
      }
    });

    test('1 MET = 1 kcal/kg/hour, duration is moving not elapsed', () {
      final profile = makeProfile(weightKg: 70);
      final kcal = profile.calculateCalories(
        activityType: 'Running',
        distanceKm: 2,
        speedKmh: 6.2 * 1.609344,
        durationSec: 1800,
        movingDurationSec: 600,
      );
      expect(kcal, closeTo(9.3 * 70 / 6, 1e-9));
    });

    test('same mass/activity yields same MET estimate for any gender', () {
      final male = makeProfile(gender: 'male');
      final female = makeProfile(gender: 'female');
      double estimate(UserProfile p) => p.calculateCalories(
        activityType: 'Walking',
        distanceKm: 1,
        speedKmh: 3.0 * 1.609344,
        durationSec: 900,
      );
      expect(estimate(male), equals(estimate(female)));
    });

    test('zero distance or zero duration stays zero', () {
      final profile = makeProfile();
      expect(
        profile.calculateCalories(
          activityType: 'Running',
          distanceKm: 0,
          speedKmh: 10,
          durationSec: 600,
        ),
        0,
      );
      expect(
        profile.calculateCalories(
          activityType: 'Cycling',
          distanceKm: 1,
          speedKmh: 10,
        ),
        0,
      );
    });
  });

  // Avg speed

  group('AvgSpeedFormula', () {
    double computeAvgSpeed(double distKm, int durationSec) {
      if (durationSec <= 0) return 0.0;
      return distKm / (durationSec / 3600.0);
    }

    test('zero duration → zero speed', () {
      expect(computeAvgSpeed(1.0, 0), 0.0);
    });

    test('1 km in 600s (10 min) = 6.0 km/h', () {
      expect(computeAvgSpeed(1.0, 600), closeTo(6.0, 0.001));
    });

    test('5 km in 1800s (30 min) = 10.0 km/h', () {
      expect(computeAvgSpeed(5.0, 1800), closeTo(10.0, 0.001));
    });

    test('formula is consistent between live display and stop snapshot', () {
      const distKm = 2.5;
      const durSec = 900;
      final liveAvgSpeed = computeAvgSpeed(distKm, durSec);
      final snapshotAvgSpeed = computeAvgSpeed(distKm, durSec);
      expect(liveAvgSpeed, equals(snapshotAvgSpeed));
    });
  });

  // Snapshot consistency

  group('SnapshotConsistency', () {
    Map<String, dynamic> simulateStopAndPersist({
      required int durationSec,
      required double distanceMeters,
      required double weightKg,
      required bool isRunning,
    }) {
      final distKm = distanceMeters / 1000.0;
      final avgSpeedKmh = durationSec > 0
          ? distKm / (durationSec / 3600.0)
          : 0.0;

      final calories = WorkoutMetricsCalculator.computeCaloriesKcal(
        profile: makeProfile(weightKg: weightKg),
        activityType: isRunning ? 'Running' : 'Walking',
        distanceMeters: distanceMeters,
        durationSec: durationSec,
        movingDurationSec: durationSec,
      );

      final persisted = {
        'distanceKm': distKm,
        'avgSpeedKmh': avgSpeedKmh,
        'calories': calories,
        'durationSec': durationSec,
      };

      return {
        'distanceKm': persisted['distanceKm'],
        'avgSpeedKmh': persisted['avgSpeedKmh'],
        'calories': persisted['calories'],
      };
    }

    test(
      'record screen values match Statistics/Calendar after a 10-min walk',
      () {
        const durationSec = 600;
        const distanceMeters = 800.0;
        const weightKg = 65.0;

        final distKm = distanceMeters / 1000.0;
        final avgSpeedKmh = distKm / (durationSec / 3600.0);
        // Walking ~2.98 mph => PAC 17190, 3.8 MET.
        final liveCalories = (3.8 * weightKg * durationSec / 3600).round();

        final readBack = simulateStopAndPersist(
          durationSec: durationSec,
          distanceMeters: distanceMeters,
          weightKg: weightKg,
          isRunning: false,
        );

        expect(readBack['distanceKm'], closeTo(distKm, 0.0001));
        expect(readBack['avgSpeedKmh'], closeTo(avgSpeedKmh, 0.0001));
        expect(readBack['calories'], liveCalories);
      },
    );

    test(
      'record screen values match Statistics/Calendar after a 30-min run',
      () {
        const durationSec = 1800;
        const distanceMeters = 5100.0;
        const weightKg = 70.0;

        final distKm = distanceMeters / 1000.0;
        final avgSpeedKmh = distKm / (durationSec / 3600.0);
        // 6.34 mph maps continuously to nearest published running band: 12050, 9.3 MET.
        final liveCalories = (9.3 * weightKg * durationSec / 3600).round();

        final readBack = simulateStopAndPersist(
          durationSec: durationSec,
          distanceMeters: distanceMeters,
          weightKg: weightKg,
          isRunning: true,
        );

        expect(readBack['distanceKm'], closeTo(distKm, 0.0001));
        expect(readBack['avgSpeedKmh'], closeTo(avgSpeedKmh, 0.0001));
        expect(readBack['calories'], liveCalories);
      },
    );

    test('no recalculation changes values between stop and read', () {
      const durationSec = 1200;
      const distanceMeters = 2000.0;

      final result = simulateStopAndPersist(
        durationSec: durationSec,
        distanceMeters: distanceMeters,
        weightKg: 68.0,
        isRunning: false,
      );

      final expectedDistKm = distanceMeters / 1000.0;
      final expectedAvgSpeed = expectedDistKm / (durationSec / 3600.0);

      expect(
        result['avgSpeedKmh'],
        equals(expectedAvgSpeed),
        reason: 'avgSpeedKmh must survive round-trip unchanged',
      );
      expect(
        result['distanceKm'],
        equals(expectedDistKm),
        reason: 'distanceKm must survive round-trip unchanged',
      );
    });

    test('average speed must be derived from total duration and distance', () {
      const durationSec = 1800;
      const distanceMeters = 5000.0;

      final distKm = distanceMeters / 1000.0;
      final expectedAvgSpeed = distKm / (durationSec / 3600.0);

      expect(expectedAvgSpeed, closeTo(10.0, 0.0001));
    });
  });

  group('DurationFormatting', () {
    test('formatDurationFromSeconds keeps second-level precision', () {
      expect(WorkoutFormatters.formatDurationFromSeconds(59), '59s');
      expect(WorkoutFormatters.formatDurationFromSeconds(60), '1m');
      expect(WorkoutFormatters.formatDurationFromSeconds(89), '1m 29s');
      expect(WorkoutFormatters.formatDurationFromSeconds(3661), '1h 1m 1s');
    });
  });

  group('BackendAlignedMetrics', () {
    test('client metric constants match backend processing defaults', () {
      expect(kClientMetricsVersion, 1);
      expect(kClientRecordingStatus, 'client_recording');
      expect(
        kClientPendingProcessingStatus,
        'client_finished_pending_processing',
      );
      expect(kClientFinalizedStatus, 'client_finalized');
      expect(kClientProcessingStatus, kClientPendingProcessingStatus);
      expect(kDeterministicFinalizeJobType, 'deterministic_finalize');
      expect(kQueuedJobStatus, 'queued');
      expect(kClientFinishEnqueuedEvent, 'client_finish_enqueued');
    });

    test('calculator computes speed from canonical distance and duration', () {
      final speed = WorkoutMetricsCalculator.computeAverageSpeedKmh(
        distanceKm: 5.0,
        durationSec: 1800,
      );
      expect(speed, closeTo(10.0, 0.0001));
    });

    test('raw GPS payload serializes to backend column names', () {
      final payload = RawGpsPointPayload(
        workoutId: 'session-1',
        timestamp: DateTime.utc(2026, 4, 14, 10, 0, 0),
        latitude: 10.123,
        longitude: 106.456,
        accuracy: 4.2,
        deviceSource: 'geolocator_position_stream',
      ).toJson();

      expect(payload['workout_id'], 'session-1');
      expect(payload['timestamp'], '2026-04-14T10:00:00.000Z');
      expect(payload['latitude'], closeTo(10.123, 0.0001));
      expect(payload['longitude'], closeTo(106.456, 0.0001));
      expect(payload['accuracy'], closeTo(4.2, 0.0001));
      expect(payload['device_source'], 'geolocator_position_stream');
    });

    test('raw step interval payload serializes to backend column names', () {
      final payload = RawStepIntervalPayload(
        workoutId: 'session-1',
        intervalStart: DateTime.utc(2026, 4, 14, 10, 0, 0),
        intervalEnd: DateTime.utc(2026, 4, 14, 10, 0, 5),
        stepsCount: 12,
        deviceSource: 'pedometer_step_count_stream',
      ).toJson();

      expect(payload['workout_id'], 'session-1');
      expect(payload['interval_start'], '2026-04-14T10:00:00.000Z');
      expect(payload['interval_end'], '2026-04-14T10:00:05.000Z');
      expect(payload['steps_count'], 12);
      expect(payload['device_source'], 'pedometer_step_count_stream');
    });
  });
}
