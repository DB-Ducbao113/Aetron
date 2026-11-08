import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/notification_settings_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_skeleton.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_backdrop.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

User? _getSafeUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionState _photosStatus = PermissionState.notDetermined;
  bool _loadingPermissions = true;
  bool _notificationsEnabled = true;
  bool _useMetricUnits = true;
  String _appVersion = 'Loading...';
  bool _isClearingCache = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
    _loadPreferences();
    _loadVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled =
          prefs.getBool(kNotificationsPrefKey) ?? _notificationsEnabled;
      _useMetricUnits = prefs.getBool(kMetricUnitsPrefKey) ?? _useMetricUnits;
    });
  }

  Future<void> _showLanguageSelector(AppLanguage currentLang) async {
    final colors = context.kinetic;
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(KineticTokens.spaceMD),
          padding: const EdgeInsets.all(KineticTokens.spaceLG),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
            border: Border.all(color: colors.borderAccent, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('select_language', currentLang),
                style: KineticTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _LanguageOptionTile(
                flag: '🇻🇳',
                name: 'Tiếng Việt',
                isSelected: currentLang == AppLanguage.vi,
                onTap: () => Navigator.of(context).pop(AppLanguage.vi),
              ),
              const SizedBox(height: 10),
              _LanguageOptionTile(
                flag: '🇬🇧',
                name: 'English',
                isSelected: currentLang == AppLanguage.en,
                onTap: () => Navigator.of(context).pop(AppLanguage.en),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != currentLang) {
      await ref.read(appLanguageProvider.notifier).setLanguage(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == AppLanguage.vi
                  ? 'Đã đổi ngôn ngữ sang Tiếng Việt'
                  : 'App language set to English',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showUnitSelector(AppLanguage currentLang) async {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(KineticTokens.spaceMD),
          padding: const EdgeInsets.all(KineticTokens.spaceLG),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
            border: Border.all(color: colors.borderAccent, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Chọn hệ đơn vị đo lường' : 'Select Measurement Unit',
                style: KineticTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _UnitOptionTile(
                icon: Icons.straighten_rounded,
                title: isVi ? 'Hệ mét (Metric)' : 'Metric System',
                subtitle: isVi
                    ? 'Kilômét (km), Mét (m), Vận tốc (km/h), Pace (min/km)'
                    : 'Kilometers (km), Meters (m), Speed (km/h), Pace (min/km)',
                isSelected: _useMetricUnits,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              _UnitOptionTile(
                icon: Icons.speed_rounded,
                title: isVi ? 'Hệ Anh (Imperial)' : 'Imperial System',
                subtitle: isVi
                    ? 'Dặm (mi), Feet (ft), Vận tốc (mph), Pace (min/mi)'
                    : 'Miles (mi), Feet (ft), Speed (mph), Pace (min/mi)',
                isSelected: !_useMetricUnits,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != _useMetricUnits) {
      await _setUseMetricUnits(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected
                  ? (isVi ? 'Đã chuyển sang Hệ mét (km, km/h)' : 'Switched to Metric units (km, km/h)')
                  : (isVi ? 'Đã chuyển sang Hệ dặm (mi, mph)' : 'Switched to Imperial units (mi, mph)'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showThemeSelector(AppLanguage currentLang) async {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;
    final currentMode = ref.read(themeModeProvider);

    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(KineticTokens.spaceMD),
          padding: const EdgeInsets.all(KineticTokens.spaceLG),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
            border: Border.all(
              color: colors.borderAccent,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Chọn giao diện hiển thị' : 'Select Appearance Theme',
                style: KineticTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _UnitOptionTile(
                icon: Icons.dark_mode_rounded,
                title: isVi ? 'Tối • Kinetic Telemetry' : 'Dark • Kinetic Telemetry',
                subtitle: isVi
                    ? 'Nền tối sẫm, độ tương phản cao, tối ưu pin & mắt'
                    : 'Dark precision with aqua-mint accents',
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => Navigator.of(context).pop(ThemeMode.dark),
              ),
              const SizedBox(height: 10),
              _UnitOptionTile(
                icon: Icons.light_mode_rounded,
                title: isVi ? 'Sáng • Kinetic Editorial' : 'Light • Kinetic Editorial',
                subtitle: isVi
                    ? 'Nền sáng thanh lịch, phong cách tạp chí thể thao'
                    : 'Clean editorial styling with deep emerald accents',
                isSelected: currentMode == ThemeMode.light,
                onTap: () => Navigator.of(context).pop(ThemeMode.light),
              ),
              const SizedBox(height: 10),
              _UnitOptionTile(
                icon: Icons.brightness_auto_rounded,
                title: isVi ? 'Tự động theo hệ thống' : 'System Default',
                subtitle: isVi
                    ? 'Tự động đổi theo chế độ sáng/tối của thiết bị'
                    : 'Follow device OS light/dark schedule',
                isSelected: currentMode == ThemeMode.system,
                onTap: () => Navigator.of(context).pop(ThemeMode.system),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != currentMode) {
      await ref.read(themeModeProvider.notifier).setThemeMode(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi ? 'Đã cập nhật giao diện ứng dụng' : 'Appearance theme updated',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadVersion() async {
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    if (kIsWeb || !isMobile) {
      if (!mounted) return;
      setState(() => _appVersion = '1.0.0 (1)');
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = '1.0.0 (1)');
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    if (value) {
      final allowed = await NotificationService.instance.requestPermissions();
      if (!allowed && mounted) {
        openAppSettings();
      }
    }
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationsPrefKey, value);
    ref.invalidate(notificationsPreferenceProvider);
    ref.invalidate(notificationSettingsProvider);

    final lang = ref.read(appLanguageProvider);
    final workouts = ref.read(workoutListProvider).valueOrNull ?? [];
    final activeGoal = ref.read(userGoalProvider).valueOrNull;
    final streak = ref.read(streakProvider).currentStreak;
    final useMetric = _useMetricUnits;

    final workoutReminders = prefs.getBool(kWorkoutRemindersPrefKey) ?? true;
    final morningTime = prefs.getString(kMorningTimePrefKey) ?? '08:00';
    final goalProgress = prefs.getBool(kGoalProgressPrefKey) ?? true;
    final eveningCheckIn = prefs.getBool(kEveningCheckInPrefKey) ?? true;
    final eveningTime = prefs.getString(kEveningTimePrefKey) ?? '20:00';
    final achievement = prefs.getBool(kAchievementPrefKey) ?? true;
    final streakReminders = prefs.getBool(kStreakRemindersPrefKey) ?? true;
    final inactivityReminders = prefs.getBool(kInactivityRemindersPrefKey) ?? true;
    final quietHours = prefs.getBool(kQuietHoursPrefKey) ?? true;
    final quietStart = prefs.getString(kQuietHoursStartPrefKey) ?? '22:00';
    final quietEnd = prefs.getString(kQuietHoursEndPrefKey) ?? '07:00';

    NotificationScheduler.refreshSchedules(
      notificationsEnabled: value,
      workoutRemindersEnabled: workoutReminders,
      morningReminderTime: morningTime,
      goalProgressEnabled: goalProgress,
      eveningCheckInEnabled: eveningCheckIn,
      eveningCheckInTime: eveningTime,
      achievementEnabled: achievement,
      streakRemindersEnabled: streakReminders,
      inactivityRemindersEnabled: inactivityReminders,
      quietHoursEnabled: quietHours,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
      lang: lang,
      workouts: workouts,
      activeGoal: activeGoal,
      currentStreak: streak,
      useMetricUnits: useMetric,
    );
  }

  Future<void> _setUseMetricUnits(bool value) async {
    setState(() => _useMetricUnits = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMetricUnitsPrefKey, value);
    ref.invalidate(metricUnitsPreferenceProvider);
  }

  Future<void> _refreshPermissions() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (!mounted) return;
      setState(() {
        _loadingPermissions = false;
        _notificationStatus = PermissionStatus.denied;
        _cameraStatus = PermissionStatus.denied;
        _locationStatus = PermissionStatus.denied;
        _photosStatus = PermissionState.notDetermined;
        _notificationsEnabled = false;
      });
      return;
    }

    try {
      // 1. Notification Permission Check
      PermissionStatus notifStatus = PermissionStatus.denied;
      try {
        final notifAllowed =
            await NotificationService.instance.areNotificationsAllowed();
        if (notifAllowed) {
          notifStatus = PermissionStatus.granted;
        } else {
          final s = await Permission.notification.status;
          notifStatus = (s.isGranted || s.isLimited)
              ? PermissionStatus.granted
              : s;
        }
      } catch (_) {
        try {
          final s = await Permission.notification.status;
          notifStatus = (s.isGranted || s.isLimited)
              ? PermissionStatus.granted
              : PermissionStatus.denied;
        } catch (_) {
          notifStatus = PermissionStatus.denied;
        }
      }

      // 2. Camera Permission Check
      PermissionStatus camStatus = PermissionStatus.denied;
      try {
        camStatus = await Permission.camera.status;
      } catch (_) {
        camStatus = PermissionStatus.denied;
      }

      // 3. Location (GPS) Permission Check - Query Geolocator first across all platforms
      PermissionStatus locStatus = PermissionStatus.denied;
      try {
        final geoPerm = await Geolocator.checkPermission();
        if (geoPerm == LocationPermission.always ||
            geoPerm == LocationPermission.whileInUse) {
          locStatus = PermissionStatus.granted;
        } else if (geoPerm == LocationPermission.deniedForever) {
          locStatus = PermissionStatus.permanentlyDenied;
        } else {
          locStatus = PermissionStatus.denied;
        }
      } catch (_) {
        try {
          final s = await Permission.locationWhenInUse.status;
          locStatus = s;
        } catch (_) {
          locStatus = PermissionStatus.denied;
        }
      }

      // 4. Photos Permission Check
      PermissionState photoState = PermissionState.notDetermined;
      try {
        photoState = await PhotoManager.getPermissionState(
          requestOption: const PermissionRequestOption(
            iosAccessLevel: IosAccessLevel.readWrite,
          ),
        );
      } catch (_) {
        try {
          final p = await Permission.photos.status;
          photoState = (p.isGranted || p.isLimited)
              ? PermissionState.authorized
              : PermissionState.denied;
        } catch (_) {
          photoState = PermissionState.denied;
        }
      }

      if (!mounted) return;
      final notifGranted = notifStatus.isGranted || notifStatus.isLimited;
      setState(() {
        _notificationStatus = notifStatus;
        _cameraStatus = camStatus;
        _locationStatus = locStatus;
        _photosStatus = photoState;
        _notificationsEnabled = notifGranted;
        _loadingPermissions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPermissions = false;
      });
    }
  }


  bool get _isNotificationGranted =>
      _notificationStatus.isGranted || _notificationStatus.isLimited;

  bool get _isCameraGranted =>
      _cameraStatus.isGranted || _cameraStatus.isLimited;

  bool get _isPhotosGranted =>
      _photosStatus.isAuth ||
      _photosStatus == PermissionState.authorized ||
      _photosStatus == PermissionState.limited;

  bool get _isLocationGranted =>
      _locationStatus.isGranted || _locationStatus.isLimited;

  Future<void> _showRevokePermissionDialog(
    BuildContext context,
    String permissionName,
    AppLanguage lang,
  ) async {
    final colors = context.kinetic;
    final isVi = lang == AppLanguage.vi;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
          side: BorderSide(
            color: colors.borderAccent,
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.settings_outlined, color: colors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Quản lý quyền $permissionName' : 'Manage $permissionName Access',
                style: KineticTypography.headlineSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Để cấp quyền hoặc thay đổi quyền $permissionName, bạn vui lòng chuyển nút gạt trong phần Cài đặt của thiết bị.'
              : 'To grant or update $permissionName access, please toggle it in your device Settings.',
          style: KineticTypography.bodyMedium.copyWith(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Đóng' : 'Cancel',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isVi ? 'Mở Cài Đặt' : 'Open Settings',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openAppSettings();
    }
  }

  Future<void> _toggleNotificationPermission(bool value, AppLanguage lang) async {
    if (value) {
      final allowed = await NotificationService.instance.requestPermissions();
      await _refreshPermissions();
      if (!allowed && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
          lang,
        );
      } else {
        await _setNotificationsEnabled(true);
      }
    } else {
      await _setNotificationsEnabled(false);
      if (mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
          lang,
        );
      }
    }
  }

  Future<void> _toggleCameraPermission(bool value, AppLanguage lang) async {
    if (value) {
      final status = await Permission.camera.request();
      await _refreshPermissions();
      if (!status.isGranted && !status.isLimited && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Camera' : 'Camera',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Camera' : 'Camera',
        lang,
      );
    }
  }

  Future<void> _togglePhotoPermission(bool value, AppLanguage lang) async {
    if (value) {
      final status = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        ),
      );
      await _refreshPermissions();
      if (!status.isAuth && mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Thư viện ảnh' : 'Photo Library',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Thư viện ảnh' : 'Photo Library',
        lang,
      );
    }
  }

  Future<void> _toggleLocationPermission(bool value, AppLanguage lang) async {
    if (value) {
      LocationPermission geoPerm;
      try {
        geoPerm = await Geolocator.requestPermission();
      } catch (_) {
        final status = await Permission.locationWhenInUse.request();
        geoPerm = (status.isGranted || status.isLimited)
            ? LocationPermission.whileInUse
            : LocationPermission.denied;
      }
      await _refreshPermissions();
      if (geoPerm != LocationPermission.always &&
          geoPerm != LocationPermission.whileInUse &&
          mounted) {
        await _showRevokePermissionDialog(
          context,
          lang == AppLanguage.vi ? 'Vị trí (GPS)' : 'Location (GPS)',
          lang,
        );
      }
    } else {
      await _showRevokePermissionDialog(
        context,
        lang == AppLanguage.vi ? 'Vị trí (GPS)' : 'Location (GPS)',
        lang,
      );
    }
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    final lang = ref.read(appLanguageProvider);
    final isVi = lang == AppLanguage.vi;
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          if (tempDir.existsSync()) {
            final entities = tempDir.listSync(followLinks: false);
            for (final entity in entities) {
              try {
                if (entity is File) {
                  await entity.delete();
                } else if (entity is Directory) {
                  await entity.delete(recursive: true);
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Đã xóa bộ nhớ đệm thành công' : 'Cache cleared successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Không thể xóa bộ nhớ đệm' : 'Could not clear cache',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppLanguage lang) async {
    final colors = context.kinetic;
    final isVi = lang == AppLanguage.vi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
          side: BorderSide(
            color: colors.error.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.error.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Xóa tài khoản vĩnh viễn' : 'Delete Account',
                style: KineticTypography.headlineSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Hành động này sẽ xóa vĩnh viễn toàn bộ lịch sử tập luyện, huy hiệu, mục tiêu và dữ liệu cá nhân của bạn. Dữ liệu không thể phục hồi sau khi xóa.'
              : 'This action will permanently delete all your workout history, badges, goals, and personal data. This cannot be undone.',
          style: KineticTypography.bodyMedium.copyWith(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Hủy bỏ' : 'Cancel',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isVi ? 'Xác nhận xóa' : 'Confirm Delete',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = _getSafeUser();
      if (user != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.error),
                    const SizedBox(height: KineticTokens.spaceLG),
                    Text(
                      isVi ? 'Đang xóa tài khoản...' : 'Deleting account...',
                      style: KineticTypography.bodyLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          ref.invalidate(workoutListProvider);
          ref.invalidate(userProfileProvider(user.id));
          ref.invalidate(currentAvatarDisplayProvider);
          ref.invalidate(userGoalProvider);

          await ref.read(userProfileRepositoryProvider).deleteAccount(user.id);

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isVi
                      ? 'Tài khoản và toàn bộ dữ liệu đã được xóa thành công.'
                      : 'Account and all data deleted successfully.',
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: colors.error,
                content: Text(
                  isVi
                      ? 'Lỗi khi xóa tài khoản: $e'
                      : 'Error deleting account: $e',
                ),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final user = _getSafeUser();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: KineticSettingsTopBar(
                currentLang: currentLang,
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: colors.primary,
                backgroundColor: colors.surface2,
                onRefresh: () async {
                  setState(() => _isRefreshing = true);
                  try {
                    await _refreshPermissions();
                  } finally {
                    if (mounted) setState(() => _isRefreshing = false);
                  }
                },
                child: _isRefreshing
                    ? const SettingsSkeletonView()
                    : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    // SECTION 0: PROFILE HERO CARD
                    _ProfileHeroCard(
                      displayName: _settingsDisplayName(user),
                      email: user?.email,
                      nameLabel: AppTranslations.get('display_name', currentLang),
                      editLabel: currentLang == AppLanguage.vi ? 'Đổi tên' : 'Edit',
                      onTap: () async {
                        final updated = await showEditDisplayNameSheet(
                          context,
                          currentName: _settingsDisplayName(user),
                        );
                        if (updated == true && mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: KineticTokens.spaceLG),

                    // SECTION 1: APP PREFERENCES
                    KineticSettingsSectionGroup(
                      title: AppTranslations.get('app_preferences', currentLang),
                      children: [
                        KineticSettingsTile(
                          icon: Icons.language_rounded,
                          title: AppTranslations.get('app_language', currentLang),
                          subtitle: currentLang == AppLanguage.vi ? '🇻🇳 Tiếng Việt' : '🇬🇧 English',
                          accentColor: colors.primary,
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                          onTap: () => _showLanguageSelector(currentLang),
                        ),
                        KineticSettingsTile(
                          icon: Icons.straighten_rounded,
                          title: AppTranslations.get('units', currentLang),
                          subtitle: _useMetricUnits
                              ? (currentLang == AppLanguage.vi ? 'Hệ mét (km, m, km/h)' : 'Metric (km, m, km/h)')
                              : (currentLang == AppLanguage.vi ? 'Hệ Anh (mi, ft, mph)' : 'Imperial (mi, ft, mph)'),
                          accentColor: colors.secondary,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Text(
                              _useMetricUnits ? 'KM / H' : 'MI / H',
                              style: KineticTypography.unitLabel.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colors.secondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          onTap: () => _showUnitSelector(currentLang),
                        ),
                        KineticSettingsTile(
                          icon: Icons.palette_outlined,
                          title: currentLang == AppLanguage.vi ? 'Giao diện' : 'Appearance',
                          subtitle: switch (ref.watch(themeModeProvider)) {
                            ThemeMode.dark => currentLang == AppLanguage.vi
                                ? 'Tối • Kinetic Telemetry'
                                : 'Dark • Kinetic Telemetry',
                            ThemeMode.light => currentLang == AppLanguage.vi
                                ? 'Sáng • Kinetic Editorial'
                                : 'Light • Kinetic Editorial',
                            ThemeMode.system => currentLang == AppLanguage.vi
                                ? 'Theo hệ thống'
                                : 'System default',
                          },
                          accentColor: colors.primary,
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                          onTap: () => _showThemeSelector(currentLang),
                        ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceLG),

                    // SECTION 2: PRIVACY & PERMISSIONS ACCESS
                    KineticSettingsSectionGroup(
                      title: AppTranslations.get('privacy_access', currentLang),
                      children: [
                        KineticSettingsTile(
                          icon: Icons.notifications_active_rounded,
                          title: currentLang == AppLanguage.vi ? 'Thông báo' : 'Notifications',
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _isNotificationGranted
                                  ? (currentLang == AppLanguage.vi
                                      ? 'Đã cho phép • Nhắc nhở tập & chuỗi Streak'
                                      : 'Allowed • Workout & streak alerts')
                                  : (currentLang == AppLanguage.vi
                                      ? 'Chưa cho phép • Bật để nhận thông báo từ iPhone'
                                      : 'Denied • Tap to allow alerts'),
                          accentColor: colors.secondary,
                          trailing: Switch.adaptive(
                            value: _isNotificationGranted,
                            onChanged: (val) => _toggleNotificationPermission(val, currentLang),
                            activeTrackColor: colors.secondary.withValues(alpha: 0.5),
                            activeThumbColor: colors.secondary,
                          ),
                          onTap: () => _toggleNotificationPermission(!_isNotificationGranted, currentLang),
                        ),
                        KineticSettingsTile(
                          icon: Icons.camera_alt_rounded,
                          title: AppTranslations.get('camera_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _permissionDescription(
                                  _cameraStatus,
                                  allowed: AppTranslations.get('camera_ready', currentLang),
                                  denied: AppTranslations.get('camera_denied', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: colors.primary,
                          trailing: Switch.adaptive(
                            value: _isCameraGranted,
                            onChanged: (val) => _toggleCameraPermission(val, currentLang),
                            activeTrackColor: colors.primary.withValues(alpha: 0.5),
                            activeThumbColor: colors.primary,
                          ),
                          onTap: () => _toggleCameraPermission(!_isCameraGranted, currentLang),
                        ),
                        KineticSettingsTile(
                          icon: Icons.photo_library_rounded,
                          title: AppTranslations.get('photo_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _photoPermissionDescription(
                                  _photosStatus,
                                  full: AppTranslations.get('photos_ready', currentLang),
                                  denied: AppTranslations.get('photos_denied', currentLang),
                                  limited: AppTranslations.get('photos_limited', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: colors.secondary,
                          trailing: Switch.adaptive(
                            value: _isPhotosGranted,
                            onChanged: (val) => _togglePhotoPermission(val, currentLang),
                            activeTrackColor: colors.secondary.withValues(alpha: 0.5),
                            activeThumbColor: colors.secondary,
                          ),
                          onTap: () => _togglePhotoPermission(!_isPhotosGranted, currentLang),
                        ),
                        KineticSettingsTile(
                          icon: Icons.location_on_rounded,
                          title: AppTranslations.get('location_access', currentLang),
                          subtitle: _loadingPermissions
                              ? AppTranslations.get('checking_access', currentLang)
                              : _permissionDescription(
                                  _locationStatus,
                                  allowed: AppTranslations.get('location_ready', currentLang),
                                  denied: AppTranslations.get('location_denied', currentLang),
                                  lang: currentLang,
                                ),
                          accentColor: colors.tertiary,
                          trailing: Switch.adaptive(
                            value: _isLocationGranted,
                            onChanged: (val) => _toggleLocationPermission(val, currentLang),
                            activeTrackColor: colors.tertiary.withValues(alpha: 0.5),
                            activeThumbColor: colors.tertiary,
                          ),
                          onTap: () => _toggleLocationPermission(!_isLocationGranted, currentLang),
                        ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceLG),

                    // SECTION 3: DATA & STORAGE
                    KineticSettingsSectionGroup(
                      title: AppTranslations.get('data', currentLang),
                      children: [
                        KineticSettingsTile(
                          icon: Icons.delete_sweep_rounded,
                          title: AppTranslations.get('clear_cache', currentLang),
                          subtitle: _isClearingCache
                              ? AppTranslations.get('clearing_cache', currentLang)
                              : (currentLang == AppLanguage.vi ? 'Xóa tệp tạm và bộ nhớ đệm hình ảnh' : 'Clear temporary files and cached images'),
                          accentColor: colors.tertiary,
                          trailing: _isClearingCache
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                          onTap: _clearCache,
                        ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceLG),

                    // SECTION 4: LEGAL & SUPPORT
                    KineticSettingsSectionGroup(
                      title: AppTranslations.get('legal_and_support', currentLang),
                      children: [
                        KineticSettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: AppTranslations.get('privacy_policy', currentLang),
                          subtitle: AppTranslations.get('privacy_sub', currentLang),
                          accentColor: colors.primary,
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                            );
                          },
                        ),
                        KineticSettingsTile(
                          icon: Icons.description_outlined,
                          title: AppTranslations.get('terms_of_service', currentLang),
                          subtitle: AppTranslations.get('terms_sub', currentLang),
                          accentColor: colors.secondary,
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                            );
                          },
                        ),
                        KineticSettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: currentLang == AppLanguage.vi ? 'Phiên bản ứng dụng' : 'App Version',
                          subtitle: _appVersion,
                          accentColor: colors.secondary,
                          onTap: () {},
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Text(
                              'AETRON',
                              style: KineticTypography.unitLabel.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colors.secondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceLG),

                    // SECTION 5: ACCOUNT DELETION
                    KineticSettingsSectionGroup(
                      title: currentLang == AppLanguage.vi ? 'QUẢN LÝ TÀI KHOẢN' : 'ACCOUNT MANAGEMENT',
                      children: [
                        KineticSettingsTile(
                          icon: Icons.person_remove_rounded,
                          title: currentLang == AppLanguage.vi ? 'Xóa tài khoản' : 'Delete Account',
                          subtitle: currentLang == AppLanguage.vi
                              ? 'Xóa vĩnh viễn tài khoản và toàn bộ dữ liệu'
                              : 'Permanently remove your account and all data',
                          accentColor: colors.error,
                          danger: true,
                          trailing: Icon(Icons.chevron_right_rounded, color: colors.error),
                          onTap: () => _confirmDeleteAccount(context, currentLang),
                        ),
                      ],
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

  String _permissionDescription(
    PermissionStatus status, {
    required String allowed,
    required String denied,
    required AppLanguage lang,
  }) {
    if (status.isGranted) return allowed;
    if (status.isLimited) return AppTranslations.get('photos_limited', lang);
    if (status.isRestricted) return AppTranslations.get('location_blocked', lang);
    return denied;
  }

  String _photoPermissionDescription(
    PermissionState status, {
    required String full,
    required String denied,
    required String limited,
    required AppLanguage lang,
  }) {
    if (status == PermissionState.authorized) return full;
    if (status == PermissionState.limited) return limited;
    return denied;
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface1 : colors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: KineticTypography.headlineSmall.copyWith(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface1 : colors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: isSelected ? colors.primary : colors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.headlineSmall.copyWith(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KineticTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile hero card (board v2/v3 composition): the identity block at the
/// top of Settings, rendered as a scene card — topographic backdrop,
/// strong 1.5px edge, initials avatar, name + email, and the same Edit
/// affordance the old identity tile carried.
class _ProfileHeroCard extends StatelessWidget {
  final String displayName;
  final String? email;
  final String nameLabel;
  final String editLabel;
  final VoidCallback onTap;

  const _ProfileHeroCard({
    required this.displayName,
    required this.email,
    required this.nameLabel,
    required this.editLabel,
    required this.onTap,
  });

  String get _initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final hasEmail = email != null && email!.isNotEmpty;

    return Semantics(
      button: true,
      label: hasEmail ? '$nameLabel, $displayName, $email' : '$nameLabel, $displayName',
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(color: colors.borderStrong, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  const Positioned.fill(child: TopographicBackdrop()),
                  Padding(
                    padding: const EdgeInsets.all(KineticTokens.spaceMD),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary.withValues(alpha: 0.16),
                            border: Border.all(
                              color: colors.borderStrong,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials,
                            style: KineticTypography.headlineMedium.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: KineticTokens.spaceSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameLabel.toUpperCase(),
                                style: KineticTypography.sectionEyebrow.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
                                style: KineticTypography.headlineSmall.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (hasEmail) ...[
                                const SizedBox(height: 2),
                                Text(
                                  email!,
                                  style: KineticTypography.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: KineticTokens.spaceSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface1,
                            borderRadius: BorderRadius.circular(
                              KineticTokens.radiusSM,
                            ),
                            border: Border.all(color: colors.borderStrong),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                editLabel,
                                style: KineticTypography.label.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: colors.primary,
                              ),
                            ],
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
      ),
    );
  }
}

String _settingsDisplayName(User? user) {
  final meta = user?.userMetadata;
  final displayName = (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name']) as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final email = user?.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return 'Athlete';
}

