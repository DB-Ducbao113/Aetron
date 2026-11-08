import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/features/profile/domain/services/achievement_evaluator.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_badge_item.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_detail_sheet.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_achievements_top_bar.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_category_filter_tabs.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_next_milestone_spotlight.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_overall_progress_card.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  BadgeCategory _selectedCategory = BadgeCategory.all;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final streak = ref.watch(streakProvider);

    final workouts = workoutsAsync.valueOrNull ?? <WorkoutSession>[];
    final totalDistanceKm = workouts.fold<double>(
      0.0,
      (sum, w) => sum + (w.gpsAnalysis.validDistanceKm > 0 ? w.gpsAnalysis.validDistanceKm : w.distanceKm),
    );

    final allBadges = AchievementEvaluator.evaluateAchievements(
      workouts: workouts,
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      totalDistanceKm: totalDistanceKm,
    );

    final unlockedCount = allBadges.where((b) => b.isUnlocked).length;
    final totalCount = allBadges.length;
    final overallProgress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    // Filter badges based on selected category
    final filteredBadges = _selectedCategory == BadgeCategory.all
        ? allBadges
        : allBadges.where((b) => b.category == _selectedCategory).toList();

    // Next nearest milestone
    final nextMilestone = allBadges
        .where((b) => !b.isUnlocked)
        .fold<AchievementBadge?>(null, (nearest, b) {
      if (nearest == null || b.progress > nearest.progress) {
        return b;
      }
      return nearest;
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KineticTokens.spaceMD,
                KineticTokens.spaceSM,
                KineticTokens.spaceMD,
                KineticTokens.spaceXS,
              ),
              child: KineticAchievementsTopBar(
                currentLang: currentLang,
                unlockedCount: unlockedCount,
                totalCount: totalCount,
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  KineticTokens.spaceMD,
                  KineticTokens.spaceXS,
                  KineticTokens.spaceMD,
                  KineticTokens.spaceXXL,
                ),
                children: [
                  // 1. Overall Progress & Telemetry Banner
                  KineticOverallProgressCard(
                    currentLang: currentLang,
                    unlockedCount: unlockedCount,
                    totalCount: totalCount,
                    overallProgress: overallProgress,
                    totalWorkouts: workouts.length,
                    longestStreak: streak.longestStreak,
                    totalDistanceKm: totalDistanceKm,
                  ),
                  const SizedBox(height: KineticTokens.spaceMD),

                  // 2. Next Milestone Spotlight (if available)
                  if (nextMilestone != null) ...[
                    KineticNextMilestoneSpotlight(
                      badge: nextMilestone,
                      currentLang: currentLang,
                    ),
                    const SizedBox(height: KineticTokens.spaceMD),
                  ],

                  // 3. Category Filter Tabs
                  KineticCategoryFilterTabs(
                    selectedCategory: _selectedCategory,
                    currentLang: currentLang,
                    onSelectCategory: (cat) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                  const SizedBox(height: KineticTokens.spaceMD),

                  // 4. Section Title & Filter Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory == BadgeCategory.all
                            ? (currentLang == AppLanguage.vi ? 'TẤT CẢ HUY HIỆU' : 'ALL BADGES')
                            : _selectedCategory.label(currentLang).toUpperCase(),
                        style: KineticTypography.pageEyebrow.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        '${filteredBadges.where((b) => b.isUnlocked).length} / ${filteredBadges.length}',
                        style: KineticTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.textSecondary,
                          fontFeatures: KineticTypography.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KineticTokens.spaceSM),

                  // 5. Badges Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredBadges.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: KineticTokens.spaceSM,
                      mainAxisSpacing: KineticTokens.spaceSM,
                      childAspectRatio: 1.08,
                    ),
                    itemBuilder: (context, index) {
                      final badge = filteredBadges[index];
                      return AchievementBadgeItem(
                        badge: badge,
                        currentLang: currentLang,
                        onTap: () => AchievementDetailSheet.show(
                          context,
                          badge: badge,
                          currentLang: currentLang,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

