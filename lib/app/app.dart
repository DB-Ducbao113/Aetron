import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/notification_scheduler.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/notification_settings_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';

class AetronTheme {
  const AetronTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AetronColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AetronColors.surface,
        primary: AetronColors.primary,
        secondary: AetronColors.secondary,
        tertiary: AetronColors.warning,
        error: AetronColors.error,
        onSurface: AetronColors.textPrimary,
        onPrimary: AetronColors.space,
      ),
      fontFamily: AetronTypography.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AetronColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AetronColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AetronRadius.large),
          side: const BorderSide(color: AetronColors.borderAccent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AetronColors.primary,
          foregroundColor: AetronColors.space,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AetronRadius.medium),
          ),
          textStyle: AetronTypography.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AetronColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AetronColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AetronRadius.medium),
          ),
          textStyle: AetronTypography.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AetronColors.panelHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AetronRadius.medium),
          borderSide: const BorderSide(color: AetronColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AetronRadius.medium),
          borderSide: const BorderSide(color: AetronColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AetronRadius.medium),
          borderSide: const BorderSide(color: AetronColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AetronRadius.medium),
          borderSide: const BorderSide(color: AetronColors.error),
        ),
        hintStyle: AetronTypography.body.copyWith(
          color: AetronColors.textSecondary,
        ),
        labelStyle: AetronTypography.bodySmall.copyWith(
          color: AetronColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AetronColors.surface,
        modalBackgroundColor: AetronColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AetronRadius.extraLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AetronColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AetronRadius.large),
          side: const BorderSide(color: AetronColors.borderAccent),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AetronColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: AetronTypography.display,
        headlineLarge: AetronTypography.headingLarge,
        headlineMedium: AetronTypography.headingMedium,
        headlineSmall: AetronTypography.headingSmall,
        bodyLarge: AetronTypography.bodyLarge,
        bodyMedium: AetronTypography.body,
        bodySmall: AetronTypography.bodySmall,
        labelLarge: AetronTypography.button,
        labelMedium: AetronTypography.label,
        labelSmall: AetronTypography.caption,
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: aetronNavigatorKey,
      title: 'Aetron',
      theme: KineticTheme.lightTheme,
      darkTheme: KineticTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const KineticScrollBehavior(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const NotificationLifecycleObserver(child: AuthWrapper()),
    );
  }
}

class NotificationLifecycleObserver extends ConsumerStatefulWidget {
  const NotificationLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationLifecycleObserver> createState() =>
      _NotificationLifecycleObserverState();
}

class _NotificationLifecycleObserverState
    extends ConsumerState<NotificationLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshNotificationSchedules(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationSchedules();
    }
  }

  Future<void> _refreshNotificationSchedules() async {
    try {
      final settings = await ref.read(notificationSettingsProvider.future);
      final osAllowed = await NotificationService.instance
          .areNotificationsAllowed();
      if (!mounted) return;

      final lang = ref.read(appLanguageProvider);
      final workouts = ref.read(workoutListProvider).valueOrNull ?? [];
      final activeGoal = ref.read(userGoalProvider).valueOrNull;
      final streak = ref.read(streakProvider).currentStreak;
      final useMetric = ref.read(metricUnitsPreferenceProvider).value ?? true;

      await NotificationScheduler.refreshSchedules(
        notificationsEnabled: settings.notificationsEnabled && osAllowed,
        workoutRemindersEnabled: settings.workoutRemindersEnabled,
        morningReminderTime: settings.morningTime,
        goalProgressEnabled: settings.goalProgressEnabled,
        eveningCheckInEnabled: settings.eveningCheckInEnabled,
        eveningCheckInTime: settings.eveningTime,
        achievementEnabled: settings.achievementEnabled,
        streakRemindersEnabled: settings.streakRemindersEnabled,
        inactivityRemindersEnabled: settings.inactivityRemindersEnabled,
        quietHoursEnabled: settings.quietHoursEnabled,
        quietHoursStart: settings.quietHoursStart,
        quietHoursEnd: settings.quietHoursEnd,
        lang: lang,
        workouts: workouts,
        activeGoal: activeGoal,
        currentStreak: streak,
        useMetricUnits: useMetric,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
