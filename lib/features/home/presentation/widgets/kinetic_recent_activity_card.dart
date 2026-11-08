import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticRecentActivityCard extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final bool useMetricUnits;
  final bool isVi;
  final VoidCallback onSeeAllTap;
  final ValueChanged<String> onWorkoutTap;
  final VoidCallback onStartFirstWorkoutTap;

  const KineticRecentActivityCard({
    super.key,
    required this.workouts,
    required this.useMetricUnits,
    this.isVi = true,
    required this.onSeeAllTap,
    required this.onWorkoutTap,
    required this.onStartFirstWorkoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'HOẠT ĐỘNG GẦN NHẤT' : 'RECENT ACTIVITY',
                style: KineticTypography.sectionEyebrow.copyWith(
                  color: colors.textMuted,
                ),
              ),
              if (workouts.isNotEmpty)
                GestureDetector(
                  onTap: onSeeAllTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isVi ? 'Xem tất cả' : 'See all',
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: KineticTokens.spaceXXS),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),

          // Content
          if (workouts.isEmpty)
            // Empty State for New Athletes (Fixing M10)
            KineticCard(
              padding: const EdgeInsets.all(KineticTokens.spaceXL),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.directions_run_rounded,
                      color: colors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceSM),
                  Text(
                    isVi ? 'CHƯA CÓ HOẠT ĐỘNG NÀO' : 'NO RECENT ACTIVITIES',
                    style: KineticTypography.label.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceXXS),
                  Text(
                    isVi
                        ? 'Bắt đầu ghi lại buổi tập đầu tiên để theo dõi phong độ thời gian thực!'
                        : 'Record your first workout to track your performance!',
                    textAlign: TextAlign.center,
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceLG),
                  KineticButton(
                    label: isVi
                        ? 'Bắt đầu buổi tập đầu tiên'
                        : 'Start first workout',
                    icon: Icons.play_arrow_rounded,
                    isFullWidth: false,
                    onPressed: onStartFirstWorkoutTap,
                  ),
                ],
              ),
            )
          else ...[
            // Populated Recent Activity Card
            _buildWorkoutItem(context, workouts.first),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(BuildContext context, WorkoutSession workout) {
    final colors = context.kinetic;

    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;
    final distanceStr = WorkoutFormatters.formatDistance(
      effectiveDistanceKm,
      useMetric: useMetricUnits,
    );
    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(workout.durationSec);
    final speedStr = workout.avgSpeedKmh > 0
        ? '${workout.avgSpeedKmh.toStringAsFixed(1)} ${useMetricUnits ? "km/h" : "mph"}'
        : '--';

    final IconData activityIcon = switch (workout.activityType.toLowerCase()) {
      'cycling' || 'bike' => Icons.directions_bike_rounded,
      'running' || 'run' => Icons.directions_run_rounded,
      'walking' || 'walk' => Icons.directions_walk_rounded,
      _ => Icons.fitness_center_rounded,
    };

    final String title = isVi
        ? switch (workout.activityType.toLowerCase()) {
            'cycling' || 'bike' => 'Buổi đạp xe',
            'running' || 'run' => 'Buổi chạy bộ',
            'walking' || 'walk' => 'Buổi đi bộ',
            _ => 'Buổi tập',
          }
        : '${workout.activityType[0].toUpperCase()}${workout.activityType.substring(1)} Session';

    final dateStr = isVi
        ? '${workout.startedAt.day.toString().padLeft(2, '0')}/${workout.startedAt.month.toString().padLeft(2, '0')} lúc ${workout.startedAt.hour.toString().padLeft(2, '0')}:${workout.startedAt.minute.toString().padLeft(2, '0')}'
        : '${workout.startedAt.day.toString().padLeft(2, '0')}/${workout.startedAt.month.toString().padLeft(2, '0')} at ${workout.startedAt.hour.toString().padLeft(2, '0')}:${workout.startedAt.minute.toString().padLeft(2, '0')}';

    return KineticCard(
      padding: EdgeInsets.zero,
      onTap: () => onWorkoutTap(workout.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Activity Header Row
          Padding(
            padding: const EdgeInsets.all(KineticTokens.spaceMD),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(activityIcon, color: colors.primary, size: 20),
                ),
                const SizedBox(width: KineticTokens.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KineticTypography.headlineSmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Text(
                        dateStr,
                        style: KineticTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),

          // 2. Metrics Strip (3 Columns)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceMD,
              vertical: KineticTokens.spaceSM,
            ),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(KineticTokens.radiusSM),
              ),
              border: Border(
                top: BorderSide(color: colors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE',
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: KineticTokens.spaceXXS),
                      Text(
                        distanceStr,
                        style: KineticTypography.metricSmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.borderSubtle,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: KineticTokens.spaceSM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'THỜI GIAN' : 'DURATION',
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: KineticTokens.spaceXXS),
                        Text(
                          durationStr,
                          style: KineticTypography.metricSmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.borderSubtle,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: KineticTokens.spaceSM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'TỐC ĐỘ TB' : 'AVG SPEED',
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: KineticTokens.spaceXXS),
                        Text(
                          speedStr,
                          style: KineticTypography.metricSmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
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
