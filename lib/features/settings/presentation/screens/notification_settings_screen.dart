import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/notification_settings_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_time_input_sheet.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _masterEnabled = true;

  // Group 1: Luyện tập & Chuỗi ngày (Daily Workout & Streak)
  bool _workoutAndStreakEnabled = true;
  String _morningTime = '08:00';

  // Group 2: Mục tiêu & Thành tích (Goals & Milestones)
  bool _goalsAndMilestonesEnabled = true;

  // Group 3: Khung giờ yên tĩnh (Quiet Hours)
  bool _quietHours = true;
  String _quietStart = '22:00';
  String _quietEnd = '07:00';

  bool _isOsAllowed = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var allowed = true;
    try {
      allowed = await NotificationService.instance.areNotificationsAllowed();
    } catch (_) {
      allowed = true;
    }

    if (!mounted) return;
    setState(() {
      _masterEnabled = prefs.getBool(kNotificationsPrefKey) ?? true;

      // Group 1: Tập luyện & Chuỗi ngày
      final workout = prefs.getBool(kWorkoutRemindersPrefKey) ?? true;
      final streak = prefs.getBool(kStreakRemindersPrefKey) ?? true;
      final inactivity = prefs.getBool(kInactivityRemindersPrefKey) ?? true;
      _workoutAndStreakEnabled = workout || streak || inactivity;
      _morningTime = prefs.getString(kMorningTimePrefKey) ?? '08:00';

      // Group 2: Mục tiêu & Thành tích
      final goal = prefs.getBool(kGoalProgressPrefKey) ?? true;
      final achievements = prefs.getBool(kAchievementPrefKey) ?? true;
      final evening = prefs.getBool(kEveningCheckInPrefKey) ?? true;
      _goalsAndMilestonesEnabled = goal || achievements || evening;

      // Group 3: Khung giờ yên tĩnh
      _quietHours = prefs.getBool(kQuietHoursPrefKey) ?? true;
      _quietStart = prefs.getString(kQuietHoursStartPrefKey) ?? '22:00';
      _quietEnd = prefs.getString(kQuietHoursEndPrefKey) ?? '07:00';

      _isOsAllowed = allowed;
      _loading = false;
    });
  }

  Future<void> _updateMaster(bool val) async {
    setState(() => _masterEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsPrefKey, val);
    if (!mounted) return;
    _triggerScheduler();
  }

  Future<void> _toggleWorkoutAndStreak(bool val) async {
    setState(() => _workoutAndStreakEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kWorkoutRemindersPrefKey, val);
    await prefs.setBool(kStreakRemindersPrefKey, val);
    await prefs.setBool(kInactivityRemindersPrefKey, val);
    if (!mounted) return;
    _triggerScheduler();
  }

  Future<void> _toggleGoalsAndMilestones(bool val) async {
    setState(() => _goalsAndMilestonesEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kGoalProgressPrefKey, val);
    await prefs.setBool(kAchievementPrefKey, val);
    await prefs.setBool(kEveningCheckInPrefKey, val);
    if (!mounted) return;
    _triggerScheduler();
  }

  Future<void> _toggleQuietHours(bool val) async {
    setState(() => _quietHours = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kQuietHoursPrefKey, val);
    if (!mounted) return;
    _triggerScheduler();
  }

  Future<void> _updateMorningTime(String val) async {
    setState(() => _morningTime = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kMorningTimePrefKey, val);
    if (!mounted) return;
    _triggerScheduler();
  }

  Future<void> _updateQuietTime({String? start, String? end}) async {
    final prefs = await SharedPreferences.getInstance();
    if (start != null) {
      setState(() => _quietStart = start);
      await prefs.setString(kQuietHoursStartPrefKey, start);
    }
    if (end != null) {
      setState(() => _quietEnd = end);
      await prefs.setString(kQuietHoursEndPrefKey, end);
    }
    if (!mounted) return;
    _triggerScheduler();
  }

  void _triggerScheduler() {
    if (!mounted) return;
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(notificationsPreferenceProvider);

    try {
      final lang = ref.read(appLanguageProvider);
      final workouts = ref.read(workoutListProvider).valueOrNull ?? [];
      final activeGoal = ref.read(userGoalProvider).valueOrNull;
      final streak = ref.read(streakProvider).currentStreak;
      final useMetric = ref.read(metricUnitsPreferenceProvider).value ?? true;

      NotificationScheduler.refreshSchedules(
        notificationsEnabled: _masterEnabled,
        workoutRemindersEnabled: _workoutAndStreakEnabled,
        morningReminderTime: _morningTime,
        goalProgressEnabled: _goalsAndMilestonesEnabled,
        eveningCheckInEnabled: _goalsAndMilestonesEnabled,
        eveningCheckInTime: '20:00',
        achievementEnabled: _goalsAndMilestonesEnabled,
        streakRemindersEnabled: _workoutAndStreakEnabled,
        inactivityRemindersEnabled: _workoutAndStreakEnabled,
        quietHoursEnabled: _quietHours,
        quietHoursStart: _quietStart,
        quietHoursEnd: _quietEnd,
        lang: lang,
        workouts: workouts,
        activeGoal: activeGoal,
        currentStreak: streak,
        useMetricUnits: useMetric,
      );
    } catch (e) {
      debugPrint('[NotificationSettings] Trigger scheduler error: $e');
    }
  }

  Future<void> _pickTime(String current, Function(String) onPicked) async {
    final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
    final picked = await showKineticTimeInputSheet(
      context,
      initialTime: current,
      isVi: isVi,
    );
    if (picked != null && mounted) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'THÔNG BÁO' : 'NOTIFICATIONS',
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          isVi ? 'NHẮC NHỞ LUYỆN TẬP' : 'SMART REMINDERS',
                          style: KineticTypography.sectionEyebrow.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        KineticTokens.spaceMD,
                        KineticTokens.spaceXS,
                        KineticTokens.spaceMD,
                        KineticTokens.spaceXL,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // OS Permission Notice (if OS disabled)
                          if (!_isOsAllowed) ...[
                            KineticCard(
                              borderColor: colors.error,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_off_rounded,
                                    color: colors.error,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi
                                              ? 'Thông báo bị tắt trong hệ thống'
                                              : 'Notifications disabled in OS Settings',
                                          style: KineticTypography.bodyMedium.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isVi
                                              ? 'Bật quyền để nhận nhắc nhở đúng giờ.'
                                              : 'Allow permissions in system settings to receive timely alerts.',
                                          style: KineticTypography.bodySmall.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => openAppSettings(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.primary,
                                    ),
                                    child: Text(
                                      isVi ? 'MỞ' : 'OPEN',
                                      style: KineticTypography.unitLabel.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 1. Master Push Notification Card (scene card)
                          Container(
                            foregroundDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                KineticTokens.radiusHero,
                              ),
                              border: Border.all(
                                color: colors.borderStrong,
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                KineticTokens.radiusHero,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: KineticGradients.heroMesh(colors),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: _masterEnabled
                                            ? colors.primary.withValues(alpha: 0.14)
                                            : colors.surface2,
                                        borderRadius: BorderRadius.circular(
                                          KineticTokens.radiusSM + 2,
                                        ),
                                      ),
                                      child: BladeIcon(
                                        BladeIconName.bell,
                                        size: 24,
                                        color: _masterEnabled ? colors.primary : colors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isVi ? 'Nhận thông báo' : 'Push Notifications',
                                            style: KineticTypography.headlineSmall.copyWith(
                                              color: colors.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isVi
                                                ? 'Bật hoặc tắt toàn bộ nhắc nhở thể thao'
                                                : 'Enable or disable all fitness reminders',
                                            style: KineticTypography.bodySmall.copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _masterEnabled,
                                      activeThumbColor: colors.primary,
                                      onChanged: _updateMaster,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Section Label
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              (isVi ? 'TÙY CHỌN NHẮC NHỞ' : 'SMART REMINDERS').toUpperCase(),
                              style: KineticTypography.sectionEyebrow.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),

                          // 2. Alert groups in ONE inset card: Workouts & Streak + Goals & Achievements
                          Opacity(
                            opacity: _masterEnabled ? 1.0 : 0.5,
                            child: KineticCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: colors.tertiary.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusSM + 2),
                                        ),
                                        child: BladeIcon(
                                          BladeIconName.flame,
                                          color: colors.tertiary,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isVi ? 'Luyện tập & Chuỗi ngày' : 'Workouts & Streak',
                                              style: KineticTypography.bodyLarge.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isVi
                                                  ? 'Nhắc giờ tập hàng ngày & giữ ngọn lửa Streak'
                                                  : 'Daily workout alerts & streak protection',
                                              style: KineticTypography.bodySmall.copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _workoutAndStreakEnabled && _masterEnabled,
                                        activeThumbColor: colors.primary,
                                        onChanged: _masterEnabled ? _toggleWorkoutAndStreak : null,
                                      ),
                                    ],
                                  ),
                                  if (_workoutAndStreakEnabled && _masterEnabled) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: colors.borderSubtle,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        BladeIcon(
                                          BladeIconName.clock,
                                          size: 16,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isVi ? 'Giờ nhắc tập mỗi ngày' : 'Daily Reminder Time',
                                            style: KineticTypography.bodySmall.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                          onTap: () => _pickTime(_morningTime, _updateMorningTime),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: colors.surface2,
                                              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                              border: Border.all(color: colors.borderSubtle),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _morningTime,
                                                  style: KineticTypography.label
                                                      .copyWith(
                                                        color: colors.primary,
                                                        fontFeatures: const [
                                                          FontFeature.tabularFigures(),
                                                        ],
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_drop_down_rounded,
                                                  size: 18,
                                                  color: colors.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 1,
                                    color: colors.borderSubtle,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: colors.tertiary.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusSM + 2),
                                        ),
                                        child: BladeIcon(
                                          BladeIconName.trophy,
                                          color: colors.tertiary,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isVi ? 'Mục tiêu & Thành tích' : 'Goals & Achievements',
                                              style: KineticTypography.bodyLarge.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isVi
                                                  ? 'Cập nhật tiến độ tuần và thông báo huy hiệu mới'
                                                  : 'Weekly target updates & badge unlocks',
                                              style: KineticTypography.bodySmall.copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _goalsAndMilestonesEnabled && _masterEnabled,
                                        activeThumbColor: colors.primary,
                                        onChanged: _masterEnabled ? _toggleGoalsAndMilestones : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Group 3 Card: Khung giờ yên tĩnh (Quiet Hours)
                          Opacity(
                            opacity: _masterEnabled ? 1.0 : 0.5,
                            child: KineticCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: colors.secondary.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusSM + 2),
                                        ),
                                        child: BladeIcon(
                                          BladeIconName.moon,
                                          color: colors.secondary,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isVi ? 'Khung giờ yên tĩnh' : 'Quiet Hours',
                                              style: KineticTypography.bodyLarge.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isVi
                                                  ? 'Tắt thông báo trong khoảng thời gian nghỉ ngơi'
                                                  : 'Mute alerts during sleep & rest window',
                                              style: KineticTypography.bodySmall.copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _quietHours && _masterEnabled,
                                        activeThumbColor: colors.primary,
                                        onChanged: _masterEnabled ? _toggleQuietHours : null,
                                      ),
                                    ],
                                  ),
                                  if (_quietHours && _masterEnabled) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: colors.borderSubtle,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        BladeIcon(
                                          BladeIconName.moon,
                                          size: 16,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isVi ? 'Thời gian nghỉ ngơi' : 'Quiet Window',
                                            style: KineticTypography.bodySmall.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        // Start Time Chip
                                        InkWell(
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                          onTap: () => _pickTime(
                                            _quietStart,
                                            (val) => _updateQuietTime(start: val),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: colors.surface2,
                                              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                              border: Border.all(color: colors.borderSubtle),
                                            ),
                                            child: Text(
                                              _quietStart,
                                              style: KineticTypography.label
                                                  .copyWith(
                                                    color: colors.primary,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 14,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                        // End Time Chip
                                        InkWell(
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                          onTap: () => _pickTime(
                                            _quietEnd,
                                            (val) => _updateQuietTime(end: val),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: colors.surface2,
                                              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                              border: Border.all(color: colors.borderSubtle),
                                            ),
                                            child: Text(
                                              _quietEnd,
                                              style: KineticTypography.label
                                                  .copyWith(
                                                    color: colors.primary,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
