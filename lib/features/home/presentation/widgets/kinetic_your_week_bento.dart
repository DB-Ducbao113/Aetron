import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
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

    final displayCurrent = goalCurrent ??
        (useMetricUnits
            ? weeklyDistanceKm
            : WorkoutFormatters.kmToMi(weeklyDistanceKm));
    final displayTarget = goalTarget ??
        (useMetricUnits
            ? targetDistanceKm
            : WorkoutFormatters.kmToMi(targetDistanceKm));
    final unit = goalUnit ?? (useMetricUnits ? 'km' : 'mi');

    final progress = displayTarget > 0
        ? (displayCurrent / displayTarget).clamp(0.0, 1.0)
        : 0.0;

    final currentStr = (unit == 'km' || unit == 'mi')
        ? displayCurrent.toStringAsFixed(1)
        : displayCurrent.round().toString();
    final targetStr = (unit == 'km' || unit == 'mi')
        ? displayTarget.toStringAsFixed(0)
        : displayTarget.round().toString();

    final todayWeekday = DateTime.now().weekday;
    final dayLabels = isVi
        ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      child: KineticCard(
        padding: const EdgeInsets.all(KineticTokens.spaceMD),
        borderRadius: KineticTokens.radiusLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi ? 'Mục tiêu tuần' : 'Weekly goal',
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSetGoalTap,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'Điều chỉnh' : 'Adjust',
                            style: KineticTypography.label.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevron_right,
                            size: 15,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 2. Hero Distance / Target Figure
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentStr,
                  style: KineticTypography.displayLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ $targetStr $unit',
                  style: KineticTypography.headlineMedium.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontFeatures: KineticTypography.tabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KineticTokens.spaceSM),

            // 3. Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: Container(
                height: 8,
                color: colors.surface2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.accentFill,
                        borderRadius:
                            BorderRadius.circular(KineticTokens.radiusPill),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KineticTokens.spaceMD),

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
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? colors.accentFill : colors.surface2,
            border: !isActive && isToday
                ? Border.all(color: colors.primary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: isActive
              ? const Icon(
                  LucideIcons.check,
                  size: 15,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: KineticTypography.caption.copyWith(
            color: isToday ? colors.textPrimary : colors.textMuted,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}
