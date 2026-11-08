import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/core/utils/date_time_helper.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_home_top_bar.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_hero_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_activity_quick_switch.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_your_week_bento.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_recent_activity_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_explore_routes.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_streak_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User? _getSafeUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

// --- Helper Data Classes ---
class _WeeklyHomeStats {
  final DateTime startOfWeek;
  final double weeklyDistanceKm;
  final double weeklyCalories;
  final int weeklyWorkoutsDurationSec;
  final int workoutCount;
  final int activeDayCount;

  const _WeeklyHomeStats({
    required this.startOfWeek,
    required this.weeklyDistanceKm,
    required this.weeklyCalories,
    required this.weeklyWorkoutsDurationSec,
    required this.workoutCount,
    required this.activeDayCount,
  });
}

class _WeeklyHeroData {
  final int weekNumber;
  final double current;
  final double target;
  final String unit;
  final String badgeLabel;
  final String helperLabel;

  const _WeeklyHeroData({
    required this.weekNumber,
    required this.current,
    required this.target,
    required this.unit,
    required this.badgeLabel,
    required this.helperLabel,
  });
}

// --- Business Providers (PRESERVED) ---
final _weeklyHomeStatsProvider = Provider<_WeeklyHomeStats>((ref) {
  final workouts =
      ref.watch(workoutListProvider).valueOrNull ?? <WorkoutSession>[];
  final start = _startOfWeek(DateTime.now());
  final end = start.add(const Duration(days: 6));

  final weeklyWorkouts = workouts.where((workout) {
    final date = DateTimeHelper.localDateOnly(workout.startedAt);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final activeDates = weeklyWorkouts
      .map((workout) => DateTimeHelper.localDateOnly(workout.startedAt))
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
    activeDayCount: activeDates.length,
  );
});

final _weeklyHeroProvider = Provider<_WeeklyHeroData>((ref) {
  final currentLang = ref.watch(appLanguageProvider);
  final weekly = ref.watch(_weeklyHomeStatsProvider);
  final goal = ref.watch(userGoalProvider).valueOrNull;
  final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;

  double current;
  double target;
  String unit;
  String badgeLabel;
  String helperLabel;

  if (goal != null) {
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
    target = (goal.goalType == GoalType.distance && !useMetricUnits)
        ? WorkoutFormatters.kmToMi(rawTarget)
        : rawTarget;
    target = target <= 0 ? 1 : target;
    final displayUnit = (unit == 'kcal' && currentLang == AppLanguage.vi)
        ? 'CALO'
        : unit.toUpperCase();
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} $displayUnit';
    helperLabel = goal.period == GoalPeriod.weekly
        ? (currentLang == AppLanguage.vi
              ? 'Liên kết với mục tiêu tuần của bạn'
              : 'Linked to your weekly goal')
        : (currentLang == AppLanguage.vi
              ? 'Dựa trên mục tiêu tháng của bạn'
              : 'Based on your monthly goal');
  } else {
    current = weekly.weeklyCalories;
    target = math.max(4200.0, current <= 0 ? 4200.0 : current * 1.35);
    unit = 'kcal';
    final displayUnit = currentLang == AppLanguage.vi ? 'CALO' : 'KCAL';
    badgeLabel =
        '${_formatMetric(current, unit)} / ${_formatMetric(target, unit)} $displayUnit';
    helperLabel = currentLang == AppLanguage.vi
        ? 'Nhấn để đặt mục tiêu'
        : 'Tap to set your goal';
  }

  return _WeeklyHeroData(
    weekNumber: _weekNumber(weekly.startOfWeek),
    current: current,
    target: target,
    unit: unit,
    badgeLabel: badgeLabel,
    helperLabel: helperLabel,
  );
});

// --- KINETIC TELEMETRY HOME SCREEN ---
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedActivity = 'cycling';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedActivity = ref.read(selectedActivityTypeProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedActivityTypeProvider, (previous, next) {
      if (next != _selectedActivity && mounted) {
        setState(() {
          _selectedActivity = next;
        });
      }
    });

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
    final hour = DateTime.now().hour;
    final greeting = _greetingForHour(hour, isVi);
    final recoverableSession = ref
        .watch(recoverableInterruptedSessionProvider)
        .valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface2,
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
                    // 1. Top Bar — greeting zone sits on the V4 topographic
                    // backdrop (rich background, clean foreground).
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          const Positioned.fill(child: TopographicBackdrop()),
                          KineticHomeTopBar(
                        avatarImage: avatar.imageProvider,
                        initials: initials,
                        displayName: displayName,
                        greeting: greeting,
                        streakCount: streak.currentStreak,
                        isVi: isVi,
                        onAvatarTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(mainTabControllerProvider.notifier).state =
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
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        ),
                          ),
                        ],
                      ),
                    ),

                    // Recoverable Unsaved Session Banner (H4)
                    if (recoverableSession != null)
                      SliverToBoxAdapter(
                        child: _RecoverableWorkoutBanner(
                          session: recoverableSession,
                          isVi: isVi,
                        ),
                      ),

                    // Offline Banner if disconnected
                    if (isOffline)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: KineticTokens.page,
                            vertical: KineticTokens.spaceXXS,
                          ),
                          child: KineticOfflineBanner(),
                        ),
                      ),

                    // 2. Quick Activity Selector (Đưa lên trên thay cho thanh trạng thái môi trường)
                    SliverToBoxAdapter(
                      child: KineticActivityQuickSwitch(
                        selectedActivity: _selectedActivity,
                        isVi: isVi,
                        onSelected: (act) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedActivity = act;
                          });
                          ref
                                  .read(selectedActivityTypeProvider.notifier)
                                  .state =
                              act;
                        },
                      ),
                    ),

                    // 3. Hero Card
                    SliverToBoxAdapter(
                      child: KineticHeroCard(
                        title: _heroTitleForActivity(_selectedActivity, isVi),
                        categoryName: _activityName(_selectedActivity, isVi),
                        imageAsset: _heroImageForActivity(_selectedActivity),
                        weeklyProgressText:
                            'Tuần này: ${weekly.weeklyDistanceKm.toStringAsFixed(1)} km',
                        targetGoalText:
                            'Mục tiêu: ${hero.target.toStringAsFixed(0)} ${hero.unit}',
                        ctaLabel: _ctaForActivity(_selectedActivity, isVi),
                        onStartTap: () {
                          HapticFeedback.selectionClick();
                          ref
                                  .read(selectedActivityTypeProvider.notifier)
                                  .state =
                              _selectedActivity;
                          ref.read(mainTabControllerProvider.notifier).state =
                              1;
                        },
                        onGoalTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GoalScreen()),
                        ),
                      ),
                    ),

                    // 5. Your Week Bento Grid
                    SliverToBoxAdapter(
                      child: KineticYourWeekBento(
                        weeklyDistanceKm: weekly.weeklyDistanceKm,
                        workoutCount: weekly.workoutCount,
                        targetDistanceKm: hero.target > 0 ? hero.target : 50.0,
                        targetWorkoutCount: 5,
                        dateRangeText: _formatWeekDateRange(
                          weekly.startOfWeek,
                          isVi,
                        ),
                        isVi: isVi,
                        useMetricUnits: useMetricUnits,
                        onSetGoalTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GoalScreen()),
                        ),
                      ),
                    ),

                    // 6. Recent Activity Section (With Empty State CTA)
                    SliverToBoxAdapter(
                      child: workoutsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: KineticTokens.page,
                            vertical: KineticTokens.spaceXS,
                          ),
                          child: AetronShimmer(
                            child: AetronSkeletonCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AetronSkeletonBox(
                                    height: 170,
                                    borderRadius: KineticTokens.radiusXL,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(
                                      KineticTokens.spaceMD,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AetronSkeletonBox(
                                          width: 140,
                                          height: 20,
                                          borderRadius: KineticTokens.radiusSM,
                                        ),
                                        SizedBox(
                                          height: KineticTokens.spaceSM,
                                        ),
                                        AetronSkeletonBox(
                                          height: 36,
                                          borderRadius: KineticTokens.radiusMD,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KineticTokens.page,
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
                          onSeeAllTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(mainTabControllerProvider.notifier).state =
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
                            ref.read(mainTabControllerProvider.notifier).state =
                                1;
                          },
                        ),
                      ),
                    ),

                    // 6. Explore Routes & Programs
                    SliverToBoxAdapter(child: KineticExploreRoutes(isVi: isVi)),

                    // Bottom Padding for Dock
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        ),
      ),
    );
  }
}

String _greetingForHour(int hour, bool isVi) {
  if (hour >= 5 && hour < 12) {
    return isVi ? 'Chào buổi sáng,' : 'Good morning,';
  } else if (hour >= 12 && hour < 18) {
    return isVi ? 'Chào buổi chiều,' : 'Good afternoon,';
  } else {
    return isVi ? 'Chào buổi tối,' : 'Good evening,';
  }
}

String _heroTitleForActivity(String activity, bool isVi) {
  switch (activity) {
    case 'cycling':
      return isVi
          ? 'Sẵn sàng cho chuyến đạp xe hôm nay?'
          : 'Ready for today\'s cycling ride?';
    case 'running':
      return isVi
          ? 'Bứt phá tốc độ cùng buổi chạy bộ!'
          : 'Break your limits on today\'s run!';
    case 'walking':
      return isVi
          ? 'Thư giãn & tái tạo năng lượng với đi bộ'
          : 'Recharge with an energizing walk';
    default:
      return isVi
          ? 'Sẵn sàng cho buổi tập hôm nay?'
          : 'Ready for today\'s workout?';
  }
}

String _activityName(String activity, bool isVi) {
  switch (activity) {
    case 'cycling':
      return isVi ? 'Đạp xe ngoài trời' : 'Outdoor Cycling';
    case 'running':
      return isVi ? 'Chạy bộ ngoài trời' : 'Outdoor Running';
    case 'walking':
      return isVi ? 'Đi bộ thể thao' : 'Power Walking';
    default:
      return isVi ? 'Tập luyện' : 'Workout';
  }
}

String _heroImageForActivity(String activity) {
  switch (activity) {
    case 'cycling':
      return 'assets/activity_cycling_bright.jpg';
    case 'running':
      return 'assets/activity_running_bright.jpg';
    case 'walking':
      return 'assets/activity_walking_bright.jpg';
    default:
      return 'assets/home_hero_runner.jpg';
  }
}

String _ctaForActivity(String activity, bool isVi) {
  switch (activity) {
    case 'cycling':
      return isVi ? 'Bắt đầu đạp xe' : 'Start Cycling';
    case 'running':
      return isVi ? 'Bắt đầu chạy bộ' : 'Start Running';
    case 'walking':
      return isVi ? 'Bắt đầu đi bộ' : 'Start Walking';
    default:
      return isVi ? 'Bắt đầu tập luyện' : 'Start Workout';
  }
}

String _formatWeekDateRange(DateTime startOfWeek, bool isVi) {
  final endOfWeek = startOfWeek.add(const Duration(days: 6));
  return '${startOfWeek.day.toString().padLeft(2, '0')}/${startOfWeek.month.toString().padLeft(2, '0')} – ${endOfWeek.day.toString().padLeft(2, '0')}/${endOfWeek.month.toString().padLeft(2, '0')}';
}

// --- HELPER METHODS (PRESERVED) ---
DateTime _startOfWeek(DateTime date) {
  final local = DateTimeHelper.localDateOnly(date);
  return local.subtract(Duration(days: local.weekday - 1));
}

int _weekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  return ((thursday.difference(firstWeekStart).inDays) / 7).floor() + 1;
}

String _formatMetric(double value, String unit) {
  switch (unit) {
    case 'km':
    case 'mi':
      return value.toStringAsFixed(1);
    case 'sessions':
    case 'kcal':
    default:
      return value.round().toString();
  }
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
  if (source.isEmpty) return 'U';
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
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KineticTokens.spaceXS),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  color: colors.primary,
                  size: 20,
                ),
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
                    const SizedBox(height: KineticTokens.spaceXXS),
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
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: colors.surface2,
                              title: Text(
                                widget.isVi
                                    ? 'Bỏ buổi tập?'
                                    : 'Discard Workout?',
                                style: KineticTypography.headlineSmall.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              content: Text(
                                widget.isVi
                                    ? 'Dữ liệu của buổi tập này sẽ bị xóa hoàn toàn.'
                                    : 'This unsaved session will be permanently deleted.',
                                style: KineticTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(
                                    widget.isVi ? 'Hủy' : 'Cancel',
                                    style: TextStyle(color: colors.textMuted),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(
                                    widget.isVi ? 'Xóa bỏ' : 'Discard',
                                    style: TextStyle(color: colors.error),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    side: BorderSide(color: colors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: KineticTokens.spaceXS),
                  ),
                  child: Text(
                    widget.isVi ? 'Bỏ qua' : 'Discard',
                    style: KineticTypography.label.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          setState(() => _isSaving = true);
                          try {
                            final repo = ref.read(workoutRepositoryProvider);
                            bool saved = false;
                            try {
                              await repo
                                  .saveSessionRemote(widget.session)
                                  .timeout(const Duration(seconds: 10));
                              saved = true;
                            } catch (_) {}
                            await repo.cacheSessionLocal(
                              widget.session,
                              isSynced: saved,
                            );
                            ref.invalidate(workoutListProvider);
                            ref.invalidate(
                              recoverableInterruptedSessionProvider,
                            );
                            if (mounted) {
                              setState(() {
                                _isSaving = false;
                                _isDismissed = true;
                              });
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    widget.isVi
                                        ? 'Đã lưu buổi tập thành công!'
                                        : 'Workout saved successfully!',
                                  ),
                                  backgroundColor: colors.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: KineticTokens.spaceXS),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(
                          widget.isVi ? 'Lưu buổi tập' : 'Save Workout',
                          style: KineticTypography.label.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
