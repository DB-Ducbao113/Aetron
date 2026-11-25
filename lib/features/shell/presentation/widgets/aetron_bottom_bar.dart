import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _DockMetrics {
  final double horizontalMargin;
  final double bottomMargin;
  final double height;
  final double maxWidth;
  final double labelFontSize;
  final double iconSize;
  final double centerButtonSize;
  final double centerIconSize;

  const _DockMetrics({
    required this.horizontalMargin,
    required this.bottomMargin,
    required this.height,
    required this.maxWidth,
    required this.labelFontSize,
    required this.iconSize,
    required this.centerButtonSize,
    required this.centerIconSize,
  });
}

_DockMetrics _resolveDockMetrics(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final viewPadding = MediaQuery.viewPaddingOf(context);
  final width = size.width;
  final screenHeight = size.height;

  final double horizontalMargin;
  final double dockHeight;
  final double labelFontSize;
  final double iconSize;
  final double centerButtonSize;
  final double centerIconSize;
  final double maxWidth;

  if (width < 370) {
    // Ultra compact phones (e.g. 320px width)
    horizontalMargin = 10.0;
    dockHeight = 58.0;
    labelFontSize = 9.8;
    iconSize = 20.0;
    centerButtonSize = 44.0;
    centerIconSize = 22.0;
    maxWidth = 360.0;
  } else if (width <= 390) {
    // Compact phones (iPhone SE 375x667, iPhone mini 375x812)
    horizontalMargin = 12.0;
    dockHeight = 60.0;
    labelFontSize = 10.2;
    iconSize = 21.0;
    centerButtonSize = 44.0;
    centerIconSize = 22.0;
    maxWidth = 390.0;
  } else if (width <= 415) {
    // Standard phones (iPhone 15 / 16 / 14 / 13 @ 390-393px)
    horizontalMargin = 14.0;
    dockHeight = 61.0;
    labelFontSize = 10.5;
    iconSize = 21.5;
    centerButtonSize = 44.0;
    centerIconSize = 22.0;
    maxWidth = 420.0;
  } else {
    // Large Plus & Pro Max phones (iPhone 15 Plus, 15 Pro Max @ 430px)
    horizontalMargin = 16.0;
    dockHeight = 62.0;
    labelFontSize = 10.8;
    iconSize = 22.0;
    centerButtonSize = 44.0;
    centerIconSize = 22.0;
    maxWidth = 430.0;
  }

  final double bottomMargin;
  if (viewPadding.bottom >= 20) {
    // On Face ID / Dynamic Island iPhones (34pt safe area), place the floating
    // dock just above the home indicator (~17pt from bottom) instead of
    // SafeArea's 34pt + padding which lifts the bar too high.
    bottomMargin = (viewPadding.bottom - 17.0).clamp(12.0, 19.0);
  } else if (viewPadding.bottom > 0) {
    bottomMargin = (viewPadding.bottom + 2.0).clamp(10.0, 16.0);
  } else {
    bottomMargin = screenHeight < 700 ? 8.0 : 12.0;
  }

  return _DockMetrics(
    horizontalMargin: horizontalMargin,
    bottomMargin: bottomMargin,
    height: dockHeight,
    maxWidth: maxWidth,
    labelFontSize: labelFontSize,
    iconSize: iconSize,
    centerButtonSize: centerButtonSize,
    centerIconSize: centerIconSize,
  );
}

class AetronBottomBar extends ConsumerWidget {
  const AetronBottomBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Total vertical footprint of the floating dock from the physical bottom
  /// edge of the screen (dock height + bottom clearance), adapted per phone.
  static double bottomFootprintOf(BuildContext context) {
    final metrics = _resolveDockMetrics(context);
    return metrics.height + metrics.bottomMargin;
  }

  /// Bottom padding for scrollable tab content so items clear the floating dock.
  static double scrollBottomPaddingOf(BuildContext context) {
    return bottomFootprintOf(context) + 28.0;
  }

  /// Responsive horizontal page padding across narrow SE and wide Pro Max phones.
  static double horizontalPagePaddingOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 370 ? 16.0 : KineticTokens.page;
  }

  Widget _wrapDockContainer(
    BuildContext context,
    _DockMetrics metrics,
    Widget child,
  ) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final left = math.max(metrics.horizontalMargin, viewPadding.left);
    final right = math.max(metrics.horizontalMargin, viewPadding.right);
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 0, right, metrics.bottomMargin),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.maxWidth),
          child: SizedBox(height: metrics.height, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final colors = context.kinetic;
    final metrics = _resolveDockMetrics(context);

    final highContrast = MediaQuery.highContrastOf(context);
    if (NativeLiquidGlass.enabledOf(context)) {
      return _wrapDockContainer(
        context,
        metrics,
        NativeGlassControl(
          properties: {
            'kind': 'dock',
            'labels': [
              'nav_home',
              'nav_history',
              'nav_activity',
              'nav_analytics',
              'nav_profile',
            ].map((key) => AppTranslations.get(key, currentLang)).join('|'),
            'selected': currentIndex,
            'accent': colors.primary.toARGB32(),
            'recordFill': colors.accentFill.toARGB32(),
            'foreground': colors.textPrimary.toARGB32(),
            'dark': colors.isDark,
            'reduceMotion': KineticTokens.reduceMotionOf(context),
          },
          onTap: (index) {
            if (index >= 0 && index < 5) onChanged(index);
          },
        ),
      );
    }

    final isDark = colors.isDark;
    final capsuleRadius = metrics.height / 2;
    final tabs = Container(
      decoration: BoxDecoration(
        color: highContrast ? colors.surface1 : null,
        gradient: !highContrast
            ? (isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x3671A1D4),
                      Color(0x33142C4B),
                      Color(0x78162A44),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xE6FFFFFF),
                      Color(0xCBF0F6FF),
                    ],
                  ))
            : null,
        borderRadius: BorderRadius.circular(capsuleRadius),
        border: Border.all(
          color: isDark
              ? const Color(0x4DB2D8F9)
              : Colors.white.withValues(alpha: .85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF1F406E).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final position = const [
                0,
                2,
                1,
                3,
                4,
              ][currentIndex.clamp(0, 4)];
              final width = constraints.maxWidth / 5;
              return Stack(
                children: [
                  Positioned(
                    left: 3,
                    top: 4,
                    bottom: 4,
                    width: width - 6,
                    child: AnimatedSlide(
                      offset: Offset(width * position / (width - 6), 0),
                      duration: KineticTokens.respectingReduceMotion(
                        context,
                        const Duration(milliseconds: 240),
                      ),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        key: const ValueKey('glass-tab-indicator'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            capsuleRadius - 4,
                          ),
                          gradient: isDark
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0x2E91C4F7),
                                    Color(0x1C1D4071),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0x8CFFFFFF),
                                    Color(0x2E64B3FF),
                                  ],
                                ),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x47B8E1FF)
                                : Colors.white.withValues(alpha: .85),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x26000000)
                                  : const Color(0xFF1F5FA7).withValues(
                                      alpha: 0.10,
                                    ),
                              blurRadius: 9,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: _NavTabItem(
                  bladeIcon: BladeIconName.home,
                  label: AppTranslations.get('nav_home', currentLang),
                  selected: currentIndex == 0,
                  height: metrics.height - 6,
                  fontSize: metrics.labelFontSize,
                  iconSize: metrics.iconSize,
                  onTap: () => onChanged(0),
                ),
              ),
              Expanded(
                child: _NavTabItem(
                  bladeIcon: BladeIconName.hist,
                  label: AppTranslations.get('nav_history', currentLang),
                  selected: currentIndex == 2,
                  height: metrics.height - 6,
                  fontSize: metrics.labelFontSize,
                  iconSize: metrics.iconSize,
                  onTap: () => onChanged(2),
                ),
              ),
              Expanded(
                child: _CenterRecordButton(
                  selected: currentIndex == 1,
                  semanticLabel: AppTranslations.get(
                    'nav_activity',
                    currentLang,
                  ),
                  size: metrics.centerButtonSize,
                  iconSize: metrics.centerIconSize,
                  onTap: () => onChanged(1),
                ),
              ),
              Expanded(
                child: _NavTabItem(
                  bladeIcon: BladeIconName.chart,
                  label: AppTranslations.get('nav_analytics', currentLang),
                  selected: currentIndex == 3,
                  height: metrics.height - 6,
                  fontSize: metrics.labelFontSize,
                  iconSize: metrics.iconSize,
                  onTap: () => onChanged(3),
                ),
              ),
              Expanded(
                child: _NavTabItem(
                  bladeIcon: BladeIconName.user,
                  label: AppTranslations.get('nav_profile', currentLang),
                  selected: currentIndex == 4,
                  height: metrics.height - 6,
                  fontSize: metrics.labelFontSize,
                  iconSize: metrics.iconSize,
                  onTap: () => onChanged(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return _wrapDockContainer(
      context,
      metrics,
      ClipRRect(
        borderRadius: BorderRadius.circular(capsuleRadius),
        child: highContrast
            ? tabs
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: tabs,
              ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final BladeIconName bladeIcon;
  final String label;
  final bool selected;
  final double height;
  final double fontSize;
  final double iconSize;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.bladeIcon,
    required this.label,
    required this.selected,
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDark = colors.isDark;
    final itemColor = selected
        ? (isDark ? const Color(0xFFA5CFFF) : colors.primary)
        : (isDark ? const Color(0xFF91A7BF) : colors.textMuted);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashFactory: isIOS ? NoSplash.splashFactory : null,
          borderRadius: BorderRadius.circular(25),
          child: AnimatedContainer(
            duration: KineticTokens.respectingReduceMotion(
              context,
              KineticTokens.motionTab,
            ),
            margin: isIOS
                ? const EdgeInsets.symmetric(horizontal: 2, vertical: 1)
                : EdgeInsets.zero,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isIOS && selected ? 1.05 : 1,
                  duration: KineticTokens.respectingReduceMotion(
                    context,
                    KineticTokens.motionTab,
                  ),
                  curve: Curves.easeOutCubic,
                  child: BladeIcon(
                    bladeIcon,
                    size: iconSize,
                    color: itemColor,
                    strokeWidth: 1.7,
                  ),
                ),
                const SizedBox(height: 2.5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.caption.copyWith(
                    color: itemColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: fontSize,
                    letterSpacing: -0.15,
                    height: 1.15,
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
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _CenterRecordButton({
    required this.selected,
    required this.semanticLabel,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = colors.isDark;

    return Semantics(
      selected: selected,
      button: true,
      label: semanticLabel,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: isIOS ? NoSplash.splashFactory : null,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: KineticTokens.respectingReduceMotion(
                context,
                KineticTokens.motionTab,
              ),
              constraints: BoxConstraints.tightFor(width: size, height: size),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selected
                            ? const [
                                Color(0x738CC4F9),
                                Color(0x4D2460A8),
                              ]
                            : const [
                                Color(0x526BAAF5),
                                Color(0x3D193C71),
                              ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selected
                            ? const [
                                Color(0xFFE8F4FF),
                                Color(0xFFC5E2FF),
                              ]
                            : [
                                Colors.white.withValues(alpha: .96),
                                const Color(
                                  0xFFCCE4FF,
                                ).withValues(alpha: .55),
                              ],
                      ),
                border: Border.all(
                  color: isDark
                      ? const Color(0x6BC6E1FF)
                      : Colors.white.withValues(alpha: .95),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x4D020C1A)
                        : const Color(
                            0xFF1F66BB,
                          ).withValues(alpha: .18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: BladeIcon(
                  BladeIconName.plus,
                  color: isDark
                      ? const Color(0xFFB6D8FF)
                      : colors.primary,
                  size: iconSize,
                  strokeWidth: 2.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
