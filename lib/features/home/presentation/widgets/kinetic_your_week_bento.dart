import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticYourWeekBento extends StatelessWidget {
  final double weeklyDistanceKm;
  final int workoutCount;
  final double targetDistanceKm;
  final int targetWorkoutCount;
  final String dateRangeText;
  final VoidCallback? onSetGoalTap;
  final bool isVi;
  final bool useMetricUnits;

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
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final progress = targetDistanceKm > 0
        ? (weeklyDistanceKm / targetDistanceKm).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();
    final unit = useMetricUnits ? 'km' : 'mi';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      child: KineticCard(
        padding: const EdgeInsets.all(KineticTokens.spaceMD),
        borderRadius: KineticTokens.radiusLG,
        gradient: KineticGradients.heroMesh(colors),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Tuần này của bạn' : 'Your Week',
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: KineticTokens.spaceXXS),
                    Text(
                      dateRangeText,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSetGoalTap,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KineticTokens.spaceSM,
                        vertical: KineticTokens.spaceXS,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusPill,
                        ),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.track_changes_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Text(
                            isVi ? 'Mục tiêu: $percent%' : 'Goal: $percent%',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KineticTokens.spaceMD),

            // 2. Week Stats — V4: flat divided row (no boxes-in-boxes)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Tổng quãng đường' : 'Total Distance',
                        style: KineticTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            weeklyDistanceKm.toStringAsFixed(1),
                            style: KineticTypography.metricHero.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Text(
                            unit.toUpperCase(),
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 14,
                            color: colors.secondary,
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Expanded(
                            child: Text(
                              isVi
                                  ? '+12% so với tuần trước'
                                  : '+12% vs last week',
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hairline divider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KineticTokens.spaceMD,
                  ),
                  child: Container(
                    width: 1,
                    height: 76,
                    color: colors.borderSubtle,
                  ),
                ),

                // Workouts Count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Số buổi tập' : 'Workouts',
                        style: KineticTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$workoutCount',
                            style: KineticTypography.metricHero.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Text(
                            isVi ? 'BUỔI' : 'SESSIONS',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Expanded(
                            child: Text(
                              isVi
                                  ? 'Mục tiêu: $targetWorkoutCount buổi/tuần'
                                  : 'Target: $targetWorkoutCount sessions/wk',
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KineticTokens.spaceMD),

            // 3. Progress Bar (flat)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi
                      ? 'Tiến độ tích lũy (${weeklyDistanceKm.toStringAsFixed(1)} / ${targetDistanceKm.toStringAsFixed(0)} $unit)'
                      : 'Accumulated Progress (${weeklyDistanceKm.toStringAsFixed(1)} / ${targetDistanceKm.toStringAsFixed(0)} $unit)',
                  style: KineticTypography.bodySmall.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  '$percent%',
                  style: KineticTypography.label.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KineticTokens.spaceXXS),
            ClipRRect(
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: Container(
                height: 8,
                color: colors.surface3,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius:
                              BorderRadius.circular(KineticTokens.radiusPill),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KineticTokens.spaceSM),

            // 4. Dedicated Adjust Goal Action Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSetGoalTap,
                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: KineticTokens.spaceXXS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Text(
                            isVi
                                ? 'Điều chỉnh mục tiêu rèn luyện'
                                : 'Adjust your fitness goals',
                            style: KineticTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'Cài đặt' : 'Settings',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: KineticTokens.spaceXXS),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
