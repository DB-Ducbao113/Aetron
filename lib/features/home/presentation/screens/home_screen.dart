import 'dart:math' as math;
import 'dart:convert';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_explore_routes.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_home_top_bar.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_recent_activity_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_streak_details_sheet.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_your_week_bento.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/scientific_result_metadata.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User? _getSafeUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int weeklyWorkoutsDurationSec;
  final int workoutCount;
  final Set<int> activeWeekdays;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.weeklyWorkoutsDurationSec,
    required this.workoutCount,
    required this.activeWeekdays,
  });
}

class _WeeklyHeroData {
  final double current;
  final double target;
  final String unit;
  final double distanceTargetKm;

  const _WeeklyHeroData({
    required this.current,
    required this.target,
    required this.unit,
    required this.distanceTargetKm,
  });
}

final _weeklyHomeStatsProvider = Provider<_WeeklyHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final start = _startOfWeek(DateTime.now());
  final end = start.add(const Duration(days: 6));

  final weeklyWorkouts = workouts.where((workout) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final activeWeekdays = weeklyWorkouts
      .map((workout) => workout.startedAt.toLocal().weekday)
      .toSet();

  double effectiveDistance(WorkoutSession w) {
    return w.gpsAnalysis.validDistanceKm > 0
        ? w.gpsAnalysis.validDistanceKm
        : w.distanceKm;
  }

  return _WeeklyHomeStats(
    startOfWeek: start,
    weeklyDistanceKm: weeklyWorkouts.fold(
      0.0,
      (sum, w) => sum + effectiveDistance(w),
    ),
    weeklyCalories: weeklyWorkouts.fold(0.0, (sum, w) => sum + w.caloriesKcal),
    weeklyWorkoutsDurationSec: weeklyWorkouts.fold(
      0,
      (sum, w) => sum + w.durationSec,
    ),
    workoutCount: weeklyWorkouts.length,
    activeWeekdays: activeWeekdays,
  );
});

final _weeklyHeroProvider = Provider<_WeeklyHeroData>((ref) {
  final currentLang = ref.watch(appLanguageProvider);
  final weekly = ref.watch(_weeklyHomeStatsProvider);
  final goal = ref.watch(userGoalProvider).valueOrNull;
  final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

  if (goal != null) {
    final double current;
    final String unit;
    switch (goal.goalType) {
      case GoalType.distance:
        current = useMetricUnits
            ? weekly.weeklyDistanceKm
            : WorkoutFormatters.kmToMi(weekly.weeklyDistanceKm);
        unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
        break;
      case GoalType.workouts:
        current = weekly.workoutCount.toDouble();
        unit = currentLang == AppLanguage.vi ? 'buổi' : 'sessions';
        break;
      case GoalType.calories:
        current = weekly.weeklyCalories;
        unit = 'kcal';
        break;
    }

    final rawTarget = goal.period == GoalPeriod.weekly
        ? goal.targetValue
        : _monthlyTargetToWeeklyTarget(goal.targetValue, weekly.startOfWeek);
    var target = (goal.goalType == GoalType.distance && !useMetricUnits)
        ? WorkoutFormatters.kmToMi(rawTarget)
        : rawTarget;
    target = target <= 0 ? 1 : target;

    return _WeeklyHeroData(
      current: current,
      target: target,
      unit: unit,
      distanceTargetKm: goal.goalType == GoalType.distance ? rawTarget : 50.0,
    );
  }

  final dist = useMetricUnits
      ? weekly.weeklyDistanceKm
      : WorkoutFormatters.kmToMi(weekly.weeklyDistanceKm);
  final distUnit = WorkoutFormatters.distanceUnitLabel(
    useMetric: useMetricUnits,
  );

  return _WeeklyHeroData(
    current: dist,
    target: useMetricUnits ? 50.0 : 30.0,
    unit: distUnit,
    distanceTargetKm: 50.0,
  );
});

class HomeScreen extends ConsumerStatefulWidget {
  final bool showMapTiles;

  const HomeScreen({super.key, this.showMapTiles = true});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workoutsAsync = ref.watch(workoutListProvider);
    final isOffline = ref.watch(appConnectionProvider).valueOrNull == false;
    final user = _getSafeUser();
    final avatar = ref.watch(currentAvatarDisplayProvider);
    final streak = ref.watch(streakProvider);
    final weekly = ref.watch(_weeklyHomeStatsProvider);
    final hero = ref.watch(_weeklyHeroProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    final displayName = _homeDisplayName(user);
    final initials = _initialsFromEmail(user?.email);
    final greeting = _greetingForHour(DateTime.now().hour, isVi);
    final recoverableSession = ref
        .watch(recoverableInterruptedSessionProvider)
        .valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        child: RefreshIndicator(
              color: colors.primary,
              backgroundColor: colors.surface1,
              onRefresh: () async {
                setState(() => _isRefreshing = true);
                try {
                  await ref.read(workoutListProvider.notifier).refresh();
                  final userId = ref.read(currentUserIdProvider);
                  if (userId != null) {
                    ref.invalidate(userProfileProvider(userId));
                  }
                  ref.invalidate(recoverableInterruptedSessionProvider);
                  await ref.read(userGoalProvider.notifier).refresh();
                } finally {
                  if (mounted) setState(() => _isRefreshing = false);
                }
              },
              child: _isRefreshing
                  ? const HomeSkeletonView()
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // 1. Clean Top Bar (Date eyebrow + Greeting + Bell & Profile Orbs)
                        SliverToBoxAdapter(
                          child: KineticHomeTopBar(
                            avatarImage: avatar.imageProvider,
                            initials: initials,
                            displayName: displayName,
                            greeting: greeting,
                            streakCount: streak.currentStreak,
                            isVi: isVi,
                            onAvatarTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                      .read(mainTabControllerProvider.notifier)
                                      .state =
                                  4;
                            },
                            onStreakTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  KineticStreakDetailsSheet(streak: streak),
                            ),
                            onNotificationTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsScreen(),
                              ),
                            ),
                          ),
                        ),

                        // Recoverable Unsaved Session Banner
                        if (recoverableSession != null)
                          SliverToBoxAdapter(
                            child: _RecoverableWorkoutBanner(
                              session: recoverableSession,
                              isVi: isVi,
                            ),
                          ),

                        // Offline Banner
                        if (isOffline)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AetronBottomBar.horizontalPagePaddingOf(context),
                                vertical: KineticTokens.spaceXXS,
                              ),
                              child: const KineticOfflineBanner(),
                            ),
                          ),

                        // 2. Weekly Goal & 7-Day Activity Strip
                        SliverToBoxAdapter(
                          child: KineticYourWeekBento(
                            weeklyDistanceKm: weekly.weeklyDistanceKm,
                            workoutCount: weekly.workoutCount,
                            targetDistanceKm: hero.distanceTargetKm,
                            targetWorkoutCount: 5,
                            dateRangeText: _formatWeekDateRange(
                              weekly.startOfWeek,
                              isVi,
                            ),
                            isVi: isVi,
                            useMetricUnits: useMetricUnits,
                            activeWeekdays: weekly.activeWeekdays,
                            goalCurrent: hero.current,
                            goalTarget: hero.target,
                            goalUnit: hero.unit,
                            onSetGoalTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GoalScreen(),
                              ),
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: KineticTokens.spaceXS),
                        ),

                        // 3. Recent Activity Card (Route + 3 metrics)
                        SliverToBoxAdapter(
                          child: workoutsAsync.when(
                            loading: () => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AetronBottomBar.horizontalPagePaddingOf(context),
                                vertical: KineticTokens.spaceXS,
                              ),
                              child: const AetronShimmer(
                                child: AetronSkeletonCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AetronSkeletonBox(
                                        height: 150,
                                        borderRadius: KineticTokens.radiusLG,
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(
                                          KineticTokens.spaceMD,
                                        ),
                                        child: AetronSkeletonBox(
                                          height: 44,
                                          borderRadius: KineticTokens.radiusMD,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            error: (err, _) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AetronBottomBar.horizontalPagePaddingOf(context),
                                vertical: KineticTokens.spaceXS,
                              ),
                              child: ErrorState(
                                title: isVi
                                    ? 'Không thể tải dữ liệu'
                                    : 'Unable to load data',
                                message: isVi
                                    ? 'Đã xảy ra lỗi khi đồng bộ buổi tập gần đây.'
                                    : 'An error occurred while syncing recent workouts.',
                                onRetry: () => ref
                                    .read(workoutListProvider.notifier)
                                    .refresh(),
                              ),
                            ),
                            data: (workouts) => KineticRecentActivityCard(
                              workouts: workouts,
                              useMetricUnits: useMetricUnits,
                              isVi: isVi,
                              showMapTiles: widget.showMapTiles,
                              onSeeAllTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                        .read(
                                          mainTabControllerProvider.notifier,
                                        )
                                        .state =
                                    2;
                              },
                              onWorkoutTap: (id) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WorkoutDetailsScreen(workoutId: id),
                                ),
                              ),
                              onStartFirstWorkoutTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                        .read(
                                          mainTabControllerProvider.notifier,
                                        )
                                        .state =
                                    1;
                              },
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: KineticTokens.spaceSM),
                        ),

                        // 4. Training Plans Horizontal Strip
                        SliverToBoxAdapter(
                          child: KineticExploreRoutes(isVi: isVi),
                        ),

                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: AetronBottomBar.scrollBottomPaddingOf(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
      ),
    );
  }
}

String _greetingForHour(int hour, bool isVi) {
  if (hour >= 5 && hour < 12) {
    return isVi ? 'Chào buổi sáng.' : 'Good morning.';
  } else if (hour >= 12 && hour < 18) {
    return isVi ? 'Chào buổi chiều.' : 'Good afternoon.';
  } else {
    return isVi ? 'Chào buổi tối.' : 'Good evening.';
  }
}

String _formatWeekDateRange(DateTime startOfWeek, bool isVi) {
  final endOfWeek = startOfWeek.add(const Duration(days: 6));
  return '${startOfWeek.day.toString().padLeft(2, '0')}/${startOfWeek.month.toString().padLeft(2, '0')} – ${endOfWeek.day.toString().padLeft(2, '0')}/${endOfWeek.month.toString().padLeft(2, '0')}';
}

DateTime _startOfWeek(DateTime date) {
  final local = DateTimeHelper.localDateOnly(date);
  return local.subtract(Duration(days: local.weekday - 1));
}

double _monthlyTargetToWeeklyTarget(
  double monthlyTarget,
  DateTime startOfWeek,
) {
  final monthStart = DateTime(startOfWeek.year, startOfWeek.month, 1);
  final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
  final daysInMonth = nextMonth.difference(monthStart).inDays;
  return monthlyTarget / (daysInMonth / 7.0);
}

String _initialsFromEmail(String? email) {
  final source = (email ?? 'User').split('@').first.trim();
  if (source.isEmpty) return 'A';
  final parts = source
      .split(RegExp(r'[._\-\s]+'))
      .where((element) => element.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    return parts.first
        .substring(0, math.min(2, parts.first.length))
        .toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _homeDisplayName(User? user) {
  final meta = user?.userMetadata;
  final displayName =
      (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name']) as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final username = meta?['username'] as String?;
  if (username != null && username.trim().isNotEmpty) return username.trim();
  return (user?.email ?? 'Athlete').split('@').first;
}

class _RecoverableWorkoutBanner extends ConsumerStatefulWidget {
  final WorkoutSession session;
  final bool isVi;

  const _RecoverableWorkoutBanner({required this.session, required this.isVi});

  @override
  ConsumerState<_RecoverableWorkoutBanner> createState() =>
      _RecoverableWorkoutBannerState();
}

class _RecoverableWorkoutBannerState
    extends ConsumerState<_RecoverableWorkoutBanner> {
  bool _isSaving = false;
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();
    final colors = context.kinetic;
    final mins = (widget.session.durationSec / 60).round();
    final km = widget.session.distanceKm.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? KineticTokens.shadowCardLight()
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KineticTokens.spaceXS),
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.clock, color: colors.primary, size: 18),
              ),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isVi
                          ? 'Phát hiện buổi tập chưa lưu'
                          : 'Unsaved Workout Detected',
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isVi
                          ? '${widget.session.activityType} • $km km • $mins phút'
                          : '${widget.session.activityType} • $km km • $mins min',
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),
          Row(
            children: [
              Expanded(
                child: KineticButton(
                  label: widget.isVi ? 'Bỏ qua' : 'Discard',
                  variant: KineticButtonVariant.secondary,
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => KineticGlassDialog(
                              borderColor: colors.error.withValues(alpha: 0.4),
                              title: Text(
                                widget.isVi
                                    ? 'Bỏ buổi tập?'
                                    : 'Discard Workout?',
                                style: KineticTypography.headlineSmall.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              content: Text(
                                widget.isVi
                                    ? 'Dữ liệu của buổi tập này sẽ bị xóa hoàn toàn.'
                                    : 'This unsaved session will be permanently deleted.',
                                style: KineticTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(
                                    widget.isVi ? 'Hủy' : 'Cancel',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(
                                    widget.isVi ? 'Xóa bỏ' : 'Discard',
                                    style: TextStyle(
                                      color: colors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await ref
                                .read(workoutRepositoryProvider)
                                .deleteSession(widget.session.id);
                            ref.invalidate(
                              recoverableInterruptedSessionProvider,
                            );
                            ref.invalidate(workoutListProvider);
                            setState(() => _isDismissed = true);
                          }
                        },
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
              Expanded(
                child: KineticButton(
                  label: _isSaving
                      ? (widget.isVi ? 'Đang lưu...' : 'Saving...')
                      : (widget.isVi ? 'Lưu lại' : 'Recover & Save'),
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          setState(() => _isSaving = true);
                          try {
                            final repo = ref.read(workoutRepositoryProvider);
                            final metadata =
                                ScientificResultMetadata.decode(
                                    widget.session.routeMatchMetricsJson,
                                  )
                                  ..remove('recording_checkpoint')
                                  ..['recording_recovered'] = true;
                            final recovered = widget.session.copyWith(
                              routeMatchMetricsJson: jsonEncode(metadata),
                            );
                            await repo.cacheSessionLocal(
                              recovered,
                              isSynced: false,
                            );
                            ref.invalidate(workoutListProvider);
                            ref.invalidate(
                              recoverableInterruptedSessionProvider,
                            );
                            if (mounted) {
                              setState(() => _isDismissed = true);
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.isVi
                                        ? 'Đã khôi phục và lưu buổi tập!'
                                        : 'Workout recovered and saved!',
                                  ),
                                ),
                              );
                            }
                          } catch (error) {
                            if (mounted) {
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.isVi
                                        ? 'Chưa thể lưu buổi tập. Dữ liệu khôi phục vẫn được giữ.'
                                        : 'Workout could not be saved. Recovery data is retained.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
