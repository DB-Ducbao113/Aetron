import 'dart:async';
import 'dart:io';

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // Keep tab indices [0..4] stable for cross-tab callers across the app:
  // 0 = Home, 1 = Record/Activity (center CTA), 2 = History, 3 = Analytics, 4 = Profile.
  static const _screens = [
    HomeScreen(),
    ActivityScreen(),
    CalendarScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];
  final Set<int> _visitedTabs = {};
  HttpServer? _debugServer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mainTabControllerProvider.notifier).state =
            widget.initialIndex;
      }
    });
    if (kDebugMode && kDebugBypassAuth) {
      _startDebugServer();
    }
  }

  void _startDebugServer() async {
    try {
      _debugServer = await HttpServer.bind(InternetAddress.anyIPv4, 8888);
      _debugServer!.listen((request) async {
        final path = request.uri.path;
        if (path == '/tab') {
          final indexStr = request.uri.queryParameters['index'];
          final idx = int.tryParse(indexStr ?? '');
          if (idx != null && idx >= 0 && idx < 5 && mounted) {
            ref.read(mainTabControllerProvider.notifier).state = idx;
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK: switched to tab $idx');
            await request.response.close();
            return;
          }
        } else if (path == '/theme') {
          final modeStr = request.uri.queryParameters['mode'];
          if (modeStr == 'dark') {
            await ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.dark);
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK: switched to dark mode');
            await request.response.close();
            return;
          } else if (modeStr == 'light') {
            await ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.light);
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK: switched to light mode');
            await request.response.close();
            return;
          }
        } else if (path == '/lang') {
          final code = request.uri.queryParameters['code'];
          if (code == 'vi' || code == 'en') {
            await ref
                .read(appLanguageProvider.notifier)
                .setLanguage(code == 'vi' ? AppLanguage.vi : AppLanguage.en);
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK: switched to lang $code');
            await request.response.close();
            return;
          }
        } else if (path == '/map') {
          final type = request.uri.queryParameters['type'];
          if (type == 'streets' || type == 'satellite') {
            await ref
                .read(appMapTypeProvider.notifier)
                .setMapType(
                  type == 'streets' ? AppMapType.streets : AppMapType.satellite,
                );
            request.response.statusCode = HttpStatus.ok;
            request.response.write('OK: switched map to $type');
            await request.response.close();
            return;
          }
        }
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Bad request');
        await request.response.close();
      });
    } catch (e) {
      debugPrint('[MainShell] Debug server failed: $e');
    }
  }

  @override
  void dispose() {
    _debugServer?.close(force: true);
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (ref.read(mainTabControllerProvider) != index) {
      HapticFeedback.selectionClick();
      ref.read(mainTabControllerProvider.notifier).state = index;
    }
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabControllerProvider);
    _visitedTabs.add(currentIndex);
    // History and Analytics refresh on activation. On the first visit their
    // own listeners are not mounted yet, so preserve that refresh here.
    ref.listen<int>(mainTabControllerProvider, (previous, next) {
      if (previous != next &&
          !_visitedTabs.contains(next) &&
          (next == historyTabIndex || next == analyticsTabIndex)) {
        unawaited(ref.read(workoutListProvider.notifier).refresh());
      }
    });
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) {
          _onTabSelected(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              backgroundColor: colors.surface1,
              content: Text(
                currentLang == AppLanguage.vi
                    ? 'Nhấn lần nữa để thoát ứng dụng'
                    : 'Press back again to exit',
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        extendBody: true,
        body: IndexedStack(
          index: currentIndex,
          children: [
            for (var i = 0; i < _screens.length; i++)
              TickerMode(
                enabled: i == currentIndex,
                child: _visitedTabs.contains(i)
                    ? _screens[i]
                    : const SizedBox.expand(),
              ),
          ],
        ),
        bottomNavigationBar: AetronBottomBar(
          currentIndex: currentIndex,
          onChanged: _onTabSelected,
        ),
      ),
    );
  }
}
