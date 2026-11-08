import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_activity_mix_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_analytics_header.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_key_telemetry_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_performance_story_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_recovery_guidance_card.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/personal_records_trophy_wall.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_state_panel.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedPeriodProvider = StateProvider<TimePeriod>(
  (ref) => TimePeriod.week,
);

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(workoutListProvider.notifier).refresh(),
        ref.read(userGoalProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workoutsAsync = ref.watch(workoutListProvider);
    final period = ref.watch(selectedPeriodProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    // Same as History: refresh the shared workout list whenever this tab
    // (index 3) becomes active so sessions saved by the record flow's
    // background sync appear without requiring an app reload.
    ref.listen(mainTabControllerProvider, (previous, next) {
      if (previous != next && next == 3) {
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
              ? const AnalyticsSkeletonView()
              : workoutsAsync.when(
                  data: (workouts) {
                    final filtered = _filterWorkouts(workouts, period);
                    final comparison = _calculateComparison(workouts, period);
                    final records = DetailedPersonalRecords.fromWorkouts(
                      workouts,
                    );

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        KineticTokens.page,
                        KineticTokens.spaceSM,
                        KineticTokens.page,
                        112,
                      ),
                      children: [
                        KineticAnalyticsHeader(
                          selectedPeriod: period,
                          onPeriodChanged: (value) {
                            ref.read(selectedPeriodProvider.notifier).state =
                                value;
                          },
                          isOffline: isOffline,
                          isVi: isVi,
                        ),
                        if (isOffline) ...[
                          const SizedBox(height: KineticTokens.spaceSM),
                          const AetronOfflineBanner(),
                        ],
                        const SizedBox(height: KineticTokens.spaceMD),
                        if (workouts.isEmpty || filtered.isEmpty) ...[
                          _EmptyAnalyticsPanel(period: period),
                        ] else ...[
                          // 1. Performance Narrative Story Bento
                          RepaintBoundary(
                            child: KineticPerformanceStoryBento(
                              workouts: filtered,
                              period: period,
                              currentDistanceKm: comparison.currentDistanceKm,
                              previousDistanceKm: comparison.previousDistanceKm,
                              useMetricUnits: useMetricUnits,
                              isVi: isVi,
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceMD),

                          // 2. 4 Key Telemetry Metrics Bento
                          RepaintBoundary(
                            child: KineticKeyTelemetryBento(
                              workouts: filtered,
                              useMetricUnits: useMetricUnits,
                              isVi: isVi,
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceMD),

                          // 3. Multi-sport Endurance Activity Mix
                          RepaintBoundary(
                            child: KineticActivityMixBento(
                              workouts: filtered,
                              useMetricUnits: useMetricUnits,
                              isVi: isVi,
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceMD),

                          // 4. Goal Progress Section
                          RepaintBoundary(
                            child: _GoalProgressCard(
                              progress: ref.watch(goalProgressProvider),
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceMD),

                          // 5. Recovery Guidance Card
                          RepaintBoundary(
                            child: KineticRecoveryGuidanceCard(
                              workouts: filtered,
                              isVi: isVi,
                              period: period,
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceMD),

                          // 6. Personal Records Trophy Wall
                          RepaintBoundary(
                            child: PersonalRecordsTrophyWall(
                              records: records,
                              useMetricUnits: useMetricUnits,
                              currentLang: currentLang,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const AnalyticsSkeletonView(),
                  error: (error, _) {
                    final isVi =
                        ref.watch(appLanguageProvider) == AppLanguage.vi;
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(KineticTokens.spaceXL),
                          child: AetronStatePanel(
                            title: isVi
                                ? 'Không thể tải phân tích'
                                : 'Analytics unavailable',
                            message: isVi
                                ? 'Hiện tại không thể phân tích dữ liệu buổi tập đã lưu của bạn.'
                                : 'Your saved workout data could not be analyzed right now.',
                            tone: AetronStateTone.error,
                            retryLabel: isVi ? 'Thử lại' : 'Retry',
                            onRetry: () => ref
                                .read(workoutListProvider.notifier)
                                .refresh(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ─── Goal Progress Card ───────────────────────────────────────────────────────
class _GoalProgressCard extends ConsumerWidget {
  const _GoalProgressCard({required this.progress});

  final GoalProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    if (progress == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KineticTokens.spaceLG),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(
            color: colors.borderSubtle,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.get('goal_progress', currentLang).toUpperCase(),
              style: KineticTypography.unitLabel.copyWith(
                color: colors.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isVi
                  ? 'Đặt mục tiêu tập luyện đầu tiên'
                  : 'Set your fitness goal',
              style: KineticTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: KineticTokens.spaceXXS),
            Text(
              isVi
                  ? 'Tạo mục tiêu để theo dõi tiến độ tuần/tháng của bạn.'
                  : 'Create a goal to start tracking your progress.',
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: KineticTokens.spaceMD),
            KineticButton(
              label: isVi ? 'ĐẶT MỤC TIÊU' : 'SET A GOAL',
              icon: Icons.flag_rounded,
              variant: KineticButtonVariant.secondary,
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GoalScreen()));
              },
            ),
          ],
        ),
      );
    }

    final goal = progress!;
    final remaining = (goal.target - goal.current).clamp(0, 99999);
    final remainingLabel = remaining == 0
        ? (isVi ? 'Đã hoàn thành mục tiêu!' : 'Goal achieved! Great job!')
        : '${goal.unit == 'km' || goal.unit == 'mi' ? remaining.toStringAsFixed(1) : remaining.toInt()} ${goal.unit} ${isVi ? 'còn lại' : 'remaining'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: goal.isAchieved
              ? colors.primary.withValues(alpha: 0.8)
              : colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppTranslations.get(
                      'goal_progress',
                      currentLang,
                    ).toUpperCase(),
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.primary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GoalScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GoalScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${goal.percent}%',
                        style: KineticTypography.pageTitleCompact.copyWith(
                          color: goal.isAchieved
                              ? colors.primary
                              : colors.textPrimary,
                          fontFeatures: KineticTypography.tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          Text(
            '${goal.currentLabel} / ${goal.targetLabel} ${goal.unit}',
            style: KineticTypography.metricSmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: KineticTokens.spaceXXS),
          Text(
            remainingLabel,
            style: KineticTypography.bodySmall.copyWith(
              color: goal.isAchieved ? colors.primary : colors.textSecondary,
              fontWeight: goal.isAchieved ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
            child: LinearProgressIndicator(
              value: (goal.percent / 100.0).clamp(0.0, 1.0),
              backgroundColor: colors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Analytics Panel ──────────────────────────────────────────────────
class _EmptyAnalyticsPanel extends ConsumerWidget {
  const _EmptyAnalyticsPanel({required this.period});

  final TimePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final label = _periodLabel(period, currentLang);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KineticTokens.spaceXL),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 44, color: colors.textSecondary),
          const SizedBox(height: KineticTokens.spaceSM),
          Text(
            isVi
                ? 'Chưa có hoạt động ($label)'
                : 'No workouts in this period ($label)',
            style: KineticTypography.headlineSmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isVi
                ? 'Hãy hoàn thành thêm bài tập để mở khóa biểu đồ phân tích và kỷ lục cá nhân.'
                : 'Complete workouts during this time frame to unlock performance charts.',
            textAlign: TextAlign.center,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          KineticButton(
            label: AppTranslations.get(
              'start_workout',
              currentLang,
            ).toUpperCase(),
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              ref.read(mainTabControllerProvider.notifier).state =
                  activityTabIndex;
            },
          ),
        ],
      ),
    );
  }
}

// ─── Helper Functions & Models ──────────────────────────────────────────────
String _periodLabel(TimePeriod p, AppLanguage lang) {
  switch (p) {
    case TimePeriod.week:
      return AppTranslations.get('week', lang);
    case TimePeriod.month:
      return AppTranslations.get('month', lang);
    case TimePeriod.year:
      return AppTranslations.get('year', lang);
  }
}

double _effectiveDistanceKm(WorkoutSession w) {
  return w.gpsAnalysis.validDistanceKm > 0
      ? w.gpsAnalysis.validDistanceKm
      : w.distanceKm;
}

List<WorkoutSession> _filterWorkouts(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  if (workouts.isEmpty) return [];
  final now = DateTime.now();

  List<WorkoutSession> getForRef(DateTime refDate) {
    final refDay = DateTimeHelper.localDateOnly(refDate);
    switch (period) {
      case TimePeriod.week:
        final start = refDay.subtract(const Duration(days: 6));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case TimePeriod.month:
        final start = refDay.subtract(const Duration(days: 29));
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && !d.isAfter(refDay);
        }).toList();

      case TimePeriod.year:
        final start = DateTime(refDay.year, 1, 1);
        return workouts.where((w) {
          final d = DateTimeHelper.localDateOnly(w.startedAt);
          return !d.isBefore(start) && d.year == refDay.year;
        }).toList();
    }
  }

  final currentFiltered = getForRef(now);
  if (currentFiltered.isNotEmpty) return currentFiltered;

  final latestDate = workouts.first.startedAt;
  return getForRef(latestDate);
}

class _PeriodComparison {
  final double currentDistanceKm;
  final double previousDistanceKm;
  final double? percentageChange;

  const _PeriodComparison({
    required this.currentDistanceKm,
    this.previousDistanceKm = 0.0,
    this.percentageChange,
  });
}

_PeriodComparison _calculateComparison(
  List<WorkoutSession> workouts,
  TimePeriod period,
) {
  final current = _filterWorkouts(workouts, period);
  final currentDist = current.fold(
    0.0,
    (sum, item) => sum + _effectiveDistanceKm(item),
  );

  if (workouts.isEmpty) {
    return const _PeriodComparison(
      currentDistanceKm: 0.0,
      previousDistanceKm: 0.0,
    );
  }

  final now = DateTime.now();
  final refDay = DateTimeHelper.localDateOnly(now);

  List<WorkoutSession> previous = [];
  switch (period) {
    case TimePeriod.week:
      final prevEnd = refDay.subtract(const Duration(days: 7));
      final prevStart = prevEnd.subtract(const Duration(days: 6));
      previous = workouts.where((w) {
        final d = DateTimeHelper.localDateOnly(w.startedAt);
        return !d.isBefore(prevStart) && !d.isAfter(prevEnd);
      }).toList();
      break;

    case TimePeriod.month:
      final prevEnd = refDay.subtract(const Duration(days: 30));
      final prevStart = prevEnd.subtract(const Duration(days: 29));
      previous = workouts.where((w) {
        final d = DateTimeHelper.localDateOnly(w.startedAt);
        return !d.isBefore(prevStart) && !d.isAfter(prevEnd);
      }).toList();
      break;

    case TimePeriod.year:
      final prevYear = refDay.year - 1;
      final prevStart = DateTime(prevYear, 1, 1);
      final prevEnd = DateTime(prevYear, refDay.month, refDay.day);
      previous = workouts.where((w) {
        final d = DateTimeHelper.localDateOnly(w.startedAt);
        return !d.isBefore(prevStart) && !d.isAfter(prevEnd);
      }).toList();
      break;
  }

  final prevDist = previous.fold(
    0.0,
    (sum, item) => sum + _effectiveDistanceKm(item),
  );

  if (prevDist < 0.05) {
    return _PeriodComparison(
      currentDistanceKm: currentDist,
      previousDistanceKm: prevDist,
      percentageChange: null,
    );
  }

  final rawPct = ((currentDist - prevDist) / prevDist) * 100.0;
  final pct = rawPct.isFinite ? rawPct.clamp(-100.0, 999.0) : null;

  return _PeriodComparison(
    currentDistanceKm: currentDist,
    previousDistanceKm: prevDist,
    percentageChange: pct,
  );
}
