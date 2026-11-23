import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/notification_settings_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_top_bar.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_time_input_sheet.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  @visibleForTesting
  final bool? osPermissionOverride;

  const NotificationSettingsScreen({
    super.key,
    this.osPermissionOverride,
  });

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
      allowed =
          widget.osPermissionOverride ??
          await NotificationService.instance.areNotificationsAllowed();
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
              child: KineticSettingsTopBar(
                currentLang: currentLang,
                title: isVi ? 'Thông báo' : 'Notifications',
                subtitle: isVi ? 'Nhắc nhở luyện tập' : 'Smart Reminders',
                showVersionPill: false,
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
                      padding: EdgeInsets.fromLTRB(
                        hPad,
                        KineticTokens.spaceXS,
                        hPad,
                        MediaQuery.viewPaddingOf(context).bottom +
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
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: colors.error.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        KineticTokens.radiusMD,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.notifications_off_rounded,
                                      color: colors.error,
                                      size: 20,
                                    ),
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
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () => openAppSettings(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.primary,
                                      minimumSize: const Size(48, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
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
                            const SizedBox(height: KineticTokens.spaceMD),
                          ],

                          // 1. Master Push Notification Card (Glassline V3)
                          KineticCard(
                            useLiquidGlass: true,
                            borderRadius: 21,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KineticTokens.spaceMD,
                              vertical: 14,
                            ),
                            borderColor: _masterEnabled
                                ? colors.primary.withValues(alpha: 0.35)
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _masterEnabled
                                        ? (isLight
                                            ? colors.surface1
                                            : colors.primaryTint)
                                        : colors.surface2,
                                    borderRadius: BorderRadius.circular(
                                      KineticTokens.radiusMD,
                                    ),
                                  ),
                                  child: BladeIcon(
                                    BladeIconName.bell,
                                    size: 20,
                                    color: _masterEnabled
                                        ? colors.primary
                                        : colors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isVi
                                            ? 'Nhận thông báo'
                                            : 'Push Notifications',
                                        style: KineticTypography.headlineSmall
                                            .copyWith(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isVi
                                            ? 'Bật hoặc tắt toàn bộ nhắc nhở thể thao'
                                            : 'Enable or disable all fitness reminders',
                                        style: KineticTypography.bodySmall
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoSwitch(
                                  value: _masterEnabled,
                                  activeTrackColor: const Color(0xFF34C759),
                                  inactiveTrackColor: colors.surface3,
                                  thumbColor: Colors.white,
                                  onChanged: _updateMaster,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceLG),

                          // 2. Smart Reminders Section
                          IgnorePointer(
                            ignoring: !_masterEnabled,
                            child: KineticSettingsSectionGroup(
                              title: isVi
                                  ? 'Tùy chọn nhắc nhở'
                                  : 'Smart Reminders',
                              children: [
                                KineticSettingsTile(
                                  icon: Icons.local_fire_department_rounded,
                                  bladeIcon: BladeIconName.flame,
                                  title: isVi
                                      ? 'Luyện tập & Chuỗi ngày'
                                      : 'Workouts & Streak',
                                  subtitle: isVi
                                      ? 'Nhắc giờ tập hàng ngày & giữ ngọn lửa Streak'
                                      : 'Daily workout alerts & streak protection',
                                  accentColor: _masterEnabled
                                      ? colors.tertiary
                                      : colors.textMuted,
                                  trailing: CupertinoSwitch(
                                    value: _workoutAndStreakEnabled &&
                                        _masterEnabled,
                                    activeTrackColor: const Color(0xFF34C759),
                                    inactiveTrackColor: colors.surface3,
                                    thumbColor: Colors.white,
                                    onChanged: _masterEnabled
                                        ? _toggleWorkoutAndStreak
                                        : null,
                                  ),
                                  onTap: _masterEnabled
                                      ? () => _toggleWorkoutAndStreak(
                                            !_workoutAndStreakEnabled,
                                          )
                                      : () {},
                                ),
                                if (_workoutAndStreakEnabled && _masterEnabled)
                                  KineticSettingsTile(
                                    icon: Icons.access_time_rounded,
                                    bladeIcon: BladeIconName.clock,
                                    title: isVi
                                        ? 'Giờ nhắc tập mỗi ngày'
                                        : 'Daily Reminder Time',
                                    subtitle: '',
                                    accentColor: colors.primary,
                                    trailing: _TimePillChip(time: _morningTime),
                                    onTap: () => _pickTime(
                                      _morningTime,
                                      _updateMorningTime,
                                    ),
                                  ),
                                KineticSettingsTile(
                                  icon: Icons.emoji_events_rounded,
                                  bladeIcon: BladeIconName.trophy,
                                  title: isVi
                                      ? 'Mục tiêu & Thành tích'
                                      : 'Goals & Achievements',
                                  subtitle: isVi
                                      ? 'Cập nhật tiến độ tuần và thông báo huy hiệu mới'
                                      : 'Weekly target updates & badge unlocks',
                                  accentColor: _masterEnabled
                                      ? colors.tertiary
                                      : colors.textMuted,
                                  trailing: CupertinoSwitch(
                                    value: _goalsAndMilestonesEnabled &&
                                        _masterEnabled,
                                    activeTrackColor: const Color(0xFF34C759),
                                    inactiveTrackColor: colors.surface3,
                                    thumbColor: Colors.white,
                                    onChanged: _masterEnabled
                                        ? _toggleGoalsAndMilestones
                                        : null,
                                  ),
                                  onTap: _masterEnabled
                                      ? () => _toggleGoalsAndMilestones(
                                            !_goalsAndMilestonesEnabled,
                                          )
                                      : () {},
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: KineticTokens.spaceLG),

                          // 3. Quiet Hours Section
                          IgnorePointer(
                            ignoring: !_masterEnabled,
                            child: KineticSettingsSectionGroup(
                              title: isVi ? 'Khung giờ yên tĩnh' : 'Quiet Hours',
                              children: [
                                KineticSettingsTile(
                                  icon: Icons.nights_stay_rounded,
                                  bladeIcon: BladeIconName.moon,
                                  title: isVi
                                      ? 'Chế độ yên tĩnh'
                                      : 'Quiet Mode',
                                  subtitle: isVi
                                      ? 'Tắt thông báo trong khoảng thời gian nghỉ ngơi'
                                      : 'Mute alerts during sleep & rest window',
                                  accentColor: _masterEnabled
                                      ? colors.secondary
                                      : colors.textMuted,
                                  trailing: CupertinoSwitch(
                                    value: _quietHours && _masterEnabled,
                                    activeTrackColor: const Color(0xFF34C759),
                                    inactiveTrackColor: colors.surface3,
                                    thumbColor: Colors.white,
                                    onChanged: _masterEnabled
                                        ? _toggleQuietHours
                                        : null,
                                  ),
                                  onTap: _masterEnabled
                                      ? () => _toggleQuietHours(!_quietHours)
                                      : () {},
                                ),
                                if (_quietHours && _masterEnabled)
                                  _QuietWindowRow(
                                    isVi: isVi,
                                    quietStart: _quietStart,
                                    quietEnd: _quietEnd,
                                    onTapStart: () => _pickTime(
                                      _quietStart,
                                      (val) => _updateQuietTime(start: val),
                                    ),
                                    onTapEnd: () => _pickTime(
                                      _quietEnd,
                                      (val) => _updateQuietTime(end: val),
                                    ),
                                  ),
                              ],
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

class _TimePillChip extends StatelessWidget {
  final String time;

  const _TimePillChip({required this.time});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Container(
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
            time,
            style: KineticTypography.label.copyWith(
              color: colors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
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
    );
  }
}

class _QuietWindowRow extends StatelessWidget {
  final bool isVi;
  final String quietStart;
  final String quietEnd;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;

  const _QuietWindowRow({
    required this.isVi,
    required this.quietStart,
    required this.quietEnd,
    required this.onTapStart,
    required this.onTapEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceMD,
        vertical: 12,
      ),
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
                  BladeIconName.clock,
                  size: 17,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isVi ? 'Thời gian nghỉ ngơi' : 'Quiet Window',
                  style: KineticTypography.headlineSmall.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Row(
              children: [
                Expanded(
                  child: _QuietTimeChip(
                    time: quietStart,
                    onTap: onTapStart,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                ),
                Expanded(
                  child: _QuietTimeChip(
                    time: quietEnd,
                    onTap: onTapEnd,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietTimeChip extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _QuietTimeChip({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return InkWell(
      borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          border: Border.all(color: colors.borderSubtle),
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: KineticTypography.label.copyWith(
            color: colors.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
