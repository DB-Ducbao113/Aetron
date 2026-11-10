import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
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
              backgroundColor: colors.surface2,
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
        bottomNavigationBar: _AetronDock(
          currentIndex: currentIndex,
          onChanged: _onTabSelected,
        ),
      ),
    );
  }
}

class _AetronDock extends ConsumerWidget {
  const _AetronDock({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (BladeIconName.home, 'nav_home'),
    (BladeIconName.pulse, 'nav_activity'),
    (BladeIconName.cal, 'nav_history'),
    (BladeIconName.chart, 'nav_analytics'),
    (BladeIconName.user, 'nav_profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    final colors = context.kinetic;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KineticTokens.spaceMD,
          0,
          KineticTokens.spaceMD,
          bottom > 0 ? bottom : KineticTokens.spaceSM,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KineticTokens.spaceXS,
            vertical: KineticTokens.spaceXS,
          ),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusXXL),
            border: Border.all(color: colors.borderSubtle, width: 1.0),
            boxShadow: KineticTokens.shadowPanel(colors.background),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _DockItem(
                    icon: _items[i].$1,
                    label: AppTranslations.get(_items[i].$2, currentLang),
                    selected: i == currentIndex,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final BladeIconName icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: KineticTokens.motionTab,
              curve: KineticTokens.animCurve,
              width: selected ? 48 : 36,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              ),
              child: BladeIcon(
                icon,
                color: selected ? colors.onPrimary : colors.textMuted,
                size: selected ? 20 : 18,
              ),
            ),
            const SizedBox(height: KineticTokens.spaceXXS),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KineticTypography.caption.copyWith(
                color: selected ? colors.textPrimary : colors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
