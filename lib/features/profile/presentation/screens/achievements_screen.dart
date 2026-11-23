import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/personal_records_trophy_wall.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
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
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  BadgeCategory _selectedCategory = BadgeCategory.all;
  bool _showRecords = false;
  String _recordActivity = 'running';

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workoutsAsync = ref.watch(workoutListProvider);
    final streak = ref.watch(streakProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    final workouts = workoutsAsync.valueOrNull ?? <WorkoutSession>[];
    final totalDistanceKm = workouts.fold<double>(
      0.0,
      (sum, w) =>
          sum +
          (w.gpsAnalysis.validDistanceKm > 0
              ? w.gpsAnalysis.validDistanceKm
              : w.distanceKm),
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

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                KineticTokens.spaceSM,
                hPad,
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
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  KineticTokens.spaceXS,
                  hPad,
                  MediaQuery.viewPaddingOf(context).bottom +
                      KineticTokens.spaceXL,
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

                  _AchievementPillSegmented(
                    key: const ValueKey('achievement-view'),
                    labels: [
                      isVi ? 'Huy hiệu' : 'Badges',
                      isVi ? 'Kỷ lục' : 'Records',
                    ],
                    selectedIndex: _showRecords ? 1 : 0,
                    onChanged: (index) {
                      setState(() => _showRecords = index == 1);
                    },
                  ),
                  const SizedBox(height: KineticTokens.spaceMD),
                  if (_showRecords) ...[
                    _AchievementPillSegmented(
                      key: const ValueKey('achievement-record-activity'),
                      labels: [
                        isVi ? 'Chạy bộ' : 'Running',
                        isVi ? 'Đi bộ' : 'Walking',
                        isVi ? 'Đạp xe' : 'Cycling',
                      ],
                      selectedIndex: switch (_recordActivity) {
                        'walking' => 1,
                        'cycling' => 2,
                        _ => 0,
                      },
                      onChanged: (index) {
                        setState(() {
                          _recordActivity = switch (index) {
                            1 => 'walking',
                            2 => 'cycling',
                            _ => 'running',
                          };
                        });
                      },
                    ),
                    const SizedBox(height: KineticTokens.spaceMD),
                    PersonalRecordsTrophyWall(
                      records: DetailedPersonalRecords.fromWorkouts(
                        workouts
                            .where(
                              (w) =>
                                  w.activityType.toLowerCase() ==
                                  _recordActivity,
                            )
                            .toList(),
                      ),
                      activityType: _recordActivity,
                      useMetricUnits: useMetricUnits,
                      currentLang: currentLang,
                    ),
                  ] else ...[
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
                        Expanded(
                          child: Text(
                            _selectedCategory == BadgeCategory.all
                                ? (currentLang == AppLanguage.vi
                                      ? 'TẤT CẢ HUY HIỆU'
                                      : 'ALL BADGES')
                                : _selectedCategory
                                      .label(currentLang)
                                      .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KineticTypography.pageEyebrow.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: KineticTokens.spaceXS),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: KineticTokens.spaceSM,
                        mainAxisSpacing: KineticTokens.spaceSM,
                        mainAxisExtent:
                            164 +
                            (MediaQuery.textScalerOf(context).scale(14) - 14)
                                    .clamp(0, 36) *
                                3,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementPillSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _AchievementPillSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    if (NativeLiquidGlass.enabledOf(context)) {
      return SizedBox(
        height: KineticTokens.segmentedControlHeight,
        child: NativeGlassSegmentedControl(
          labels: labels,
          symbols: const [],
          selectedIndex: selectedIndex,
          onChanged: (index) {
            if (index < 0 || index >= labels.length) return;
            HapticFeedback.selectionClick();
            onChanged(index);
          },
        ),
      );
    }

    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0x28314B6B)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: Border.all(
          color: colors.isDark
              ? const Color(0x38B6DCFF)
              : Colors.white.withValues(alpha: 0.85),
        ),
      ),
      child: KineticSlidingSelection(
        index: selectedIndex,
        count: labels.length,
        gap: KineticTokens.spaceXXS,
        child: Row(
          children: [
            for (int i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: KineticTokens.spaceXXS),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    borderRadius: BorderRadius.circular(
                      KineticTokens.radiusPill,
                    ),
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selectedIndex && !ios
                            ? colors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.segmentedLabel.copyWith(
                          color: i == selectedIndex
                              ? (ios ? colors.primary : Colors.white)
                              : colors.textSecondary,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
