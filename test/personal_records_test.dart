import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetailedPersonalRecords Tests', () {
    test('Empty workouts returns all 8 records locked', () {
      final prs = DetailedPersonalRecords.fromWorkouts([]);
      expect(prs.allRecords.length, 8);
      expect(prs.unlockedCount, 0);
      expect(prs.allRecords.every((r) => !r.isUnlocked), isTrue);
    });

    test(
      'Partial closing lap is not a 1K record and cycling does not unlock running records',
      () {
        final now = DateTime(2026, 8, 20);
        final run = WorkoutSession(
          id: 'run',
          userId: 'u1',
          activityType: 'running',
          startedAt: now,
          endedAt: now.add(const Duration(seconds: 330)),
          durationSec: 330,
          distanceKm: 1.1,
          steps: 1000,
          avgSpeedKmh: 12,
          caloriesKcal: 80,
          mode: 'gps',
          createdAt: now,
          lapSplits: const [
            WorkoutLapSplit(
              index: 1,
              distanceKm: 1,
              durationSeconds: 300,
              paceMinPerKm: 5,
            ),
            WorkoutLapSplit(
              index: 2,
              distanceKm: .1,
              durationSeconds: 30,
              paceMinPerKm: 5,
            ),
          ],
        );
        final cycle = run.copyWith(
          id: 'cycle',
          activityType: 'cycling',
          distanceKm: 25,
        );
        final records = DetailedPersonalRecords.fromWorkouts([run, cycle]);
        expect(records.best1k.durationSec, 300);
        expect(records.best1k.isEstimated, isFalse);
        expect(records.best5k.isUnlocked, isFalse);
        expect(records.best21k.isUnlocked, isFalse);
        final estimate = DetailedPersonalRecords.fromWorkouts([
          run.copyWith(lapSplits: []),
        ]);
        expect(estimate.best1k.isEstimated, isTrue);
      },
    );

    test('Workouts with 5.5km and 12km unlock PRs accurately', () {
      final now = DateTime(2026, 8, 20, 7, 30);
      final w1 = WorkoutSession(
        id: 'w1',
        userId: 'u1',
        activityType: 'running',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        durationSec: 1800, // 30 mins for 5.5km
        distanceKm: 5.5,
        steps: 5000,
        avgSpeedKmh: 11.0,
        caloriesKcal: 400,
        mode: 'gps',
        createdAt: now,
        gpsAnalysis: const WorkoutGpsAnalysis(validDistanceKm: 5.5),
      );

      final w2 = WorkoutSession(
        id: 'w2',
        userId: 'u1',
        activityType: 'running',
        startedAt: now.add(const Duration(days: 2)),
        endedAt: now.add(const Duration(days: 2, hours: 1, minutes: 10)),
        durationSec: 4200, // 70 mins for 12km
        distanceKm: 12.0,
        steps: 11000,
        avgSpeedKmh: 10.28,
        caloriesKcal: 850,
        mode: 'gps',
        createdAt: now.add(const Duration(days: 2)),
        gpsAnalysis: const WorkoutGpsAnalysis(validDistanceKm: 12.0),
      );

      final prs = DetailedPersonalRecords.fromWorkouts([w1, w2]);

      expect(prs.best1k.isUnlocked, isTrue);
      expect(prs.best5k.isUnlocked, isTrue);
      expect(prs.best10k.isUnlocked, isTrue);
      expect(prs.best21k.isUnlocked, isFalse); // not yet 21.1k
      expect(prs.longestDistance.numericValue, 12.0);
      expect(prs.maxCalories.numericValue, 850);
      expect(prs.longestDuration.durationSec, 4200);
      expect(prs.fastestPace.numericValue, 11.0);
      expect(prs.unlockedCount, 7); // 7 out of 8 unlocked
    });
  });
}
