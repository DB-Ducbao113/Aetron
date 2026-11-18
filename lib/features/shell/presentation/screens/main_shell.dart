import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mainTabControllerProvider.notifier).state =
            widget.initialIndex;
      }
    });
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
        body: IndexedStack(index: currentIndex, children: _screens),
        bottomNavigationBar: _AetronBottomBar(
          currentIndex: currentIndex,
          onChanged: _onTabSelected,
        ),
      ),
    );
  }
}

class _AetronBottomBar extends ConsumerWidget {
  const _AetronBottomBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final colors = context.kinetic;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(
            top: BorderSide(color: colors.borderSubtle, width: 0.6),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _NavTabItem(
                    icon: LucideIcons.house,
                    label: AppTranslations.get('nav_home', currentLang),
                    selected: currentIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _NavTabItem(
                    icon: LucideIcons.calendar,
                    label: AppTranslations.get('nav_history', currentLang),
                    selected: currentIndex == 2,
                    onTap: () => onChanged(2),
                  ),
                ),
                Expanded(
                  child: _CenterRecordButton(
                    selected: currentIndex == 1,
                    semanticLabel:
                        AppTranslations.get('nav_activity', currentLang),
                    onTap: () => onChanged(1),
                  ),
                ),
                Expanded(
                  child: _NavTabItem(
                    icon: LucideIcons.chart_column,
                    label: AppTranslations.get('nav_analytics', currentLang),
                    selected: currentIndex == 3,
                    onTap: () => onChanged(3),
                  ),
                ),
                Expanded(
                  child: _NavTabItem(
                    icon: LucideIcons.user,
                    label: AppTranslations.get('nav_profile', currentLang),
                    selected: currentIndex == 4,
                    onTap: () => onChanged(4),
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

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final itemColor = selected ? colors.primary : colors.textMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: itemColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.caption.copyWith(
                    color: itemColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10.5,
                    letterSpacing: 0,
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

class _CenterRecordButton extends StatelessWidget {
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  const _CenterRecordButton({
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      selected: selected,
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: KineticTokens.motionTab,
              curve: KineticTokens.animCurve,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accentFill,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: colors.primaryTint,
                        width: 3,
                      )
                    : null,
              ),
              child: const Icon(
                LucideIcons.plus,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
