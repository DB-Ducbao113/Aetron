import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/features/profile/domain/services/achievement_evaluator.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AchievementEvaluator Tests', () {
    test('Empty workouts returns all badges locked', () {
      final badges = AchievementEvaluator.evaluateAchievements(
        workouts: [],
        currentStreak: 0,
        longestStreak: 0,
        totalDistanceKm: 0.0,
      );

      expect(badges.length, 18);
      expect(badges.every((b) => !b.isUnlocked), isTrue);
    });

    test('1 workout unlocks First Signal badge', () {
      final now = DateTime.now();
      final workout = WorkoutSession(
        id: 'w1',
        userId: 'u1',
        activityType: 'running',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 20)),
        durationSec: 1200,
        distanceKm: 3.5,
        steps: 3000,
        avgSpeedKmh: 10.5,
        caloriesKcal: 250,
        mode: 'gps',
        createdAt: now,
        gpsAnalysis: const WorkoutGpsAnalysis(validDistanceKm: 3.5),
      );

      final badges = AchievementEvaluator.evaluateAchievements(
        workouts: [workout],
        currentStreak: 1,
        longestStreak: 1,
        totalDistanceKm: 3.5,
      );

      final firstSignal = badges.firstWhere((b) => b.id == 'first_signal');
      final gpsLocked = badges.firstWhere((b) => b.id == 'gps_locked');
      final pioneer5k = badges.firstWhere((b) => b.id == 'pioneer_5k');

      expect(firstSignal.isUnlocked, isTrue);
      expect(gpsLocked.isUnlocked, isTrue);
      expect(pioneer5k.isUnlocked, isFalse);
    });

    test(
      'Cycling does not unlock running-specific pace or half marathon achievements',
      () {
        final now = DateTime(2026, 8, 20);
        final workout = WorkoutSession(
          id: 'cycling',
          userId: 'u1',
          activityType: 'cycling',
          startedAt: now,
          endedAt: now.add(const Duration(hours: 1)),
          durationSec: 3600,
          distanceKm: 25,
          steps: 0,
          avgSpeedKmh: 25,
          caloriesKcal: 250,
          mode: 'gps',
          createdAt: now,
        );
        final badges = AchievementEvaluator.evaluateAchievements(
          workouts: [workout],
          currentStreak: 1,
          longestStreak: 1,
          totalDistanceKm: 25,
        );
        expect(
          badges.firstWhere((b) => b.id == 'half_marathon_21k').isUnlocked,
          isFalse,
        );
        expect(
          badges.firstWhere((b) => b.id == 'pace_breaker').isUnlocked,
          isFalse,
        );
        expect(
          badges.firstWhere((b) => b.id == 'distance_25k').isUnlocked,
          isTrue,
        );
      },
    );

    test('7-day streak unlocks 3-Day Spark and Weekly Ignite', () {
      final badges = AchievementEvaluator.evaluateAchievements(
        workouts: [],
        currentStreak: 7,
        longestStreak: 7,
        totalDistanceKm: 15.0,
      );

      final spark3 = badges.firstWhere((b) => b.id == '3day_spark');
      final ignite7 = badges.firstWhere((b) => b.id == 'weekly_ignite');
      final orbit14 = badges.firstWhere((b) => b.id == '14day_orbit');

      expect(spark3.isUnlocked, isTrue);
      expect(ignite7.isUnlocked, isTrue);
      expect(orbit14.isUnlocked, isFalse);
    });

    test('Distance formatting and tier badges work correctly in VI and EN', () {
      final badge = AchievementBadge(
        id: 'test',
        tier: BadgeTier.gold,
        category: BadgeCategory.distance,
        titleVi: 'Thám Hiểm 100K',
        titleEn: 'Century Explorer',
        descriptionVi: 'Chinh phục 100 km',
        descriptionEn: 'Conquer 100 km',
        quoteVi: '100 km kiên cường',
        quoteEn: '100 km conquered',
        icon: BadgeTier.gold.tierIcon,
        currentValue: 45.5,
        targetValue: 100.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: false,
      );

      expect(badge.tier.label(AppLanguage.vi), 'Vàng');
      expect(badge.tier.label(AppLanguage.en), 'Gold');
      expect(badge.progressPercent, 46);
      expect(badge.formattedProgress(AppLanguage.vi), '45.5 / 100 km');
      expect(badge.remainingText(AppLanguage.vi), 'Còn 54.5 km');
      expect(badge.remainingText(AppLanguage.en), '54.5 km left');
    });
  });
}
