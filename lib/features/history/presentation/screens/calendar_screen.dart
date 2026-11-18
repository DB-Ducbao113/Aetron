import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/daily_workout_list.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_empty_state.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_range_tabs.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_sport_filter.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_telemetry_bento.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_top_bar.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRangeProvider = StateProvider<HistoryRange>(
  (ref) => HistoryRange.all,
);

final historyActivityFilterProvider = StateProvider<String>((ref) => 'all');

enum HistoryRange { all, week, month, year }

extension HistoryRangeX on HistoryRange {
  String getLabel(AppLanguage lang) {
    switch (this) {
      case HistoryRange.all:
        return AppTranslations.get('all', lang);
      case HistoryRange.week:
        return AppTranslations.get('week', lang);
      case HistoryRange.month:
        return AppTranslations.get('month', lang);
      case HistoryRange.year:
        return AppTranslations.get('year', lang);
    }
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(workoutListProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<WorkoutSession> _filterWorkouts(
    List<WorkoutSession> workouts,
    HistoryRange range,
  ) {
    if (range == HistoryRange.all) return workouts;

    final now = DateTime.now();
    return workouts.where((w) {
      if (w.startedAt.isAfter(now)) return false;
      final diff = now.difference(w.startedAt);
      if (diff.isNegative) return false;
      switch (range) {
        case HistoryRange.all:
          return true;
        case HistoryRange.week:
          return diff.inDays <= 7;
        case HistoryRange.month:
          return diff.inDays <= 30;
        case HistoryRange.year:
          return diff.inDays <= 365;
      }
    }).toList();
  }

  HistorySummaryData _computeSummary(List<WorkoutSession> workouts) {
    var totalDist = 0.0;
    var totalDuration = 0;
    var totalCalories = 0;
    var totalSteps = 0;

    for (final w in workouts) {
      final validDist = w.gpsAnalysis.validDistanceKm > 0
          ? w.gpsAnalysis.validDistanceKm
          : w.distanceKm;
      totalDist += validDist;
      totalDuration += w.durationSec;
      totalCalories += w.caloriesKcal.round();
      totalSteps += w.steps;
    }

    return HistorySummaryData(
      workouts: workouts.length,
      distanceKm: totalDist,
      durationSec: totalDuration,
      calories: totalCalories,
      steps: totalSteps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final range = ref.watch(historyRangeProvider);
    final activityFilter = ref.watch(historyActivityFilterProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    // A just-finished workout is saved to the cloud in the background, often
    // after the record controller was disposed (its late invalidate is
    // skipped). Refresh whenever this tab (index 2) becomes active so the new
    // session always shows up without requiring an app reload.
    ref.listen(mainTabControllerProvider, (previous, next) {
      if (previous != next && next == 2) {
        unawaited(ref.read(workoutListProvider.notifier).refresh());
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface2,
          onRefresh: _handleRefresh,
          child: _isRefreshing
              ? const CalendarSkeletonView()
              : workoutsAsync.when(
                  data: (workouts) {
                    if (workouts.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(KineticTokens.page, KineticTokens.spaceSM, KineticTokens.page, 100),
                        children: [
                          KineticHistoryTopBar(
                            totalCount: 0,
                            currentLang: currentLang,
                            isOffline: isOffline,
                          ),
                          const SizedBox(height: 40),
                          KineticHistoryEmptyState(
                            currentLang: currentLang,
                            isFiltered: false,
                          ),
                        ],
                      );
                    }

                    // Filter by time range and activity type
                    final timeFiltered = _filterWorkouts(workouts, range)
                      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

                    final filtered = activityFilter == 'all'
                        ? timeFiltered
                        : timeFiltered
                              .where(
                                (w) =>
                                    w.activityType.toLowerCase() ==
                                    activityFilter.toLowerCase(),
                              )
                              .toList();

                    final summary = _computeSummary(filtered);

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(KineticTokens.page, KineticTokens.spaceSM, KineticTokens.page, 112),
                      children: [
                        // 1. Top Bar
                        KineticHistoryTopBar(
                          totalCount: filtered.length,
                          currentLang: currentLang,
                          isOffline: isOffline,
                        ),
                        const SizedBox(height: KineticTokens.spaceMD),

                        // 2. Sport Filter (All, Running, Cycling, Walking)
                        KineticHistorySportFilter(
                          selected: activityFilter,
                          currentLang: currentLang,
                          onSelected: (val) {
                            ref
                                    .read(
                                      historyActivityFilterProvider.notifier,
                                    )
                                    .state =
                                val;
                          },
                        ),
                        const SizedBox(height: KineticTokens.spaceXS),

                        // 3. Time Range Segmented Selector
                        KineticHistoryRangeTabs(
                          selected: range,
                          currentLang: currentLang,
                          onChanged: (value) {
                            ref.read(historyRangeProvider.notifier).state =
                                value;
                          },
                        ),
                        const SizedBox(height: KineticTokens.spaceMD),

                        // 4. Telemetry Bento Overview (Only if there are workouts)
                        if (filtered.isNotEmpty) ...[
                          KineticHistoryTelemetryBento(
                            summary: summary,
                            useMetricUnits: useMetricUnits,
                            currentLang: currentLang,
                          ),
                          const SizedBox(height: KineticTokens.spaceLG),
                        ],

                        // 5. Daily Workout List or Filtered Empty State
                        DailyWorkoutList(
                          workouts: filtered,
                          range: range.getLabel(currentLang),
                        ),
                      ],
                    );
                  },
                  loading: () => const CalendarSkeletonView(),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(KineticTokens.spaceXL),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: colors.error,
                            ),
                            const SizedBox(height: KineticTokens.spaceSM),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'Không thể tải lịch sử tập'
                                  : 'History unavailable',
                              style: KineticTypography.headlineSmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: KineticTokens.spaceSM),
                            TextButton(
                              onPressed: () => ref
                                  .read(workoutListProvider.notifier)
                                  .refresh(),
                              child: Text(
                                currentLang == AppLanguage.vi
                                    ? 'Thử lại'
                                    : 'Retry',
                                style: KineticTypography.label.copyWith(color: colors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
