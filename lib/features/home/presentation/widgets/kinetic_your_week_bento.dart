import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class KineticYourWeekBento extends StatelessWidget {
  final double weeklyDistanceKm;
  final int workoutCount;
  final double targetDistanceKm;
  final int targetWorkoutCount;
  final String dateRangeText;
  final VoidCallback? onSetGoalTap;
  final bool isVi;
  final bool useMetricUnits;

  /// Active ISO weekdays (`DateTime.monday == 1` .. `DateTime.sunday == 7`)
  /// completed during the current week.
  final Set<int> activeWeekdays;

  /// Optional goal-aligned display override (when goal is workouts or calories).
  final double? goalCurrent;
  final double? goalTarget;
  final String? goalUnit;

  const KineticYourWeekBento({
    super.key,
    required this.weeklyDistanceKm,
    required this.workoutCount,
    required this.targetDistanceKm,
    this.targetWorkoutCount = 5,
    required this.dateRangeText,
    this.onSetGoalTap,
    this.isVi = true,
    this.useMetricUnits = true,
    this.activeWeekdays = const <int>{},
    this.goalCurrent,
    this.goalTarget,
    this.goalUnit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final displayCurrent =
        goalCurrent ??
        (useMetricUnits
            ? weeklyDistanceKm
            : WorkoutFormatters.kmToMi(weeklyDistanceKm));
    final displayTarget =
        goalTarget ??
        (useMetricUnits
            ? targetDistanceKm
            : WorkoutFormatters.kmToMi(targetDistanceKm));
    final unit = goalUnit ?? (useMetricUnits ? 'km' : 'mi');

    final progress = displayTarget > 0
        ? (displayCurrent / displayTarget).clamp(0.0, 1.0)
        : 0.0;
    final percent = displayTarget > 0
        ? ((displayCurrent / displayTarget) * 100).round().clamp(0, 999)
        : 0;

    final targetStr = (unit == 'km' || unit == 'mi')
        ? displayTarget.toStringAsFixed(0)
        : displayTarget.round().toString();

    final todayWeekday = DateTime.now().weekday;
    final dayLabels = isVi
        ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: KineticTokens.spaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row OUTSIDE & ABOVE the card (Glassline V3 layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Mục tiêu tuần' : 'Weekly goal',
                style: KineticTypography.sectionTitleOf(colors),
              ),
              GestureDetector(
                onTap: onSetGoalTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  isVi ? '$percent% hoàn thành' : '$percent% complete',
                  style: KineticTypography.linkActionOf(colors),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          KineticCard(
            useLiquidGlass: true,
            padding: const EdgeInsets.all(17),
            borderRadius: 21,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Inside-Card Top Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Quãng đường tuần này' : "This week's distance",
                      style: KineticTypography.caption.copyWith(
                        color: colors.isDark
                            ? const Color(0xFFA6B6C9)
                            : colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSetGoalTap,
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusSM,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isVi ? 'Điều chỉnh' : 'Adjust',
                                style: KineticTypography.label.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              BladeIcon(
                                BladeIconName.chevR,
                                size: 13,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Hero Distance / Target Figure
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    KineticCountUp(
                      value: displayCurrent,
                      decimals: (unit == 'km' || unit == 'mi') ? 1 : 0,
                      style: KineticTypography.displayLarge.copyWith(
                        color: colors.isDark
                            ? const Color(0xFFF3F8FF)
                            : colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 33,
                        letterSpacing: -1.4,
                        height: 1.05,
                        fontFeatures: KineticTypography.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ' / $targetStr $unit',
                      style: KineticTypography.headlineMedium.copyWith(
                        color: colors.isDark
                            ? const Color(0xFFA6B6C9)
                            : colors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: KineticTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),

                // 3. Linear Progress Bar (Glassline V3 translucent inset groove + glowing fill)
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.isDark
                        ? const Color(0x2995BDE4)
                        : const Color(0x295490CB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.isDark
                          ? const Color(0x21B6D3F2)
                          : const Color(0x42A1CFF8),
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF398BF6),
                                Color(0xFF71B6FC),
                                Color(0xFFACE9F7),
                              ],
                              stops: [0.0, 0.56, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x6353A6F3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 4. 7-Day Activity Strip (T2 - CN)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < 7; i++)
                      _DayCheckItem(
                        label: dayLabels[i],
                        isActive: activeWeekdays.contains(i + 1),
                        isToday: todayWeekday == (i + 1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCheckItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isToday;

  const _DayCheckItem({
    required this.label,
    required this.isActive,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: KineticTypography.caption.copyWith(
            color: isToday
                ? colors.textPrimary
                : (colors.isDark ? const Color(0xFFA6B7CB) : colors.textMuted),
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors.isDark
                        ? const [Color(0xF066B0FB), Color(0xE8206AD9)]
                        : const [Color(0xEE7DC5FF), Color(0xE81669DB)],
                  )
                : null,
            color: isActive
                ? null
                : (isToday
                      ? colors.primaryTint
                      : (colors.isDark
                            ? const Color(0x2E6C92B9)
                            : const Color(0x217199C5))),
            border: isActive
                ? Border.all(
                    color: colors.isDark
                        ? const Color(0x70A4D7FF)
                        : const Color(0xABC0E1FF),
                    width: 1.0,
                  )
                : Border.all(
                    color: isToday
                        ? colors.primary
                        : (colors.isDark
                              ? const Color(0x2498C4EA)
                              : const Color(0x479EC8F3)),
                    width: isToday ? 1.3 : 1.0,
                  ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x3B1D78DF),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isActive
              ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}
