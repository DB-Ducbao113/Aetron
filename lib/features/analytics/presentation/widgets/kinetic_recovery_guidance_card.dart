import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KineticRecoveryGuidanceCard extends ConsumerWidget {
  final List<WorkoutSession> workouts;
  final bool isVi;
  final TimePeriod period;

  const KineticRecoveryGuidanceCard({
    super.key,
    required this.workouts,
    required this.isVi,
    this.period = TimePeriod.week,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;

    // Estimate training load based on workout volume
    final int sessionCount = workouts.length;
    final double totalKm = workouts.fold(
      0.0,
      (sum, item) =>
          sum +
          (item.gpsAnalysis.validDistanceKm > 0
              ? item.gpsAnalysis.validDistanceKm
              : item.distanceKm),
    );

    // Scale strain thresholds according to the viewing period
    final (
      double highKmThreshold,
      int highSessionsThreshold,
    ) = switch (period) {
      TimePeriod.week => (30.0, 5),
      TimePeriod.month => (120.0, 18),
      TimePeriod.year => (1200.0, 180),
    };

    final (double modKmThreshold, int modSessionsThreshold) = switch (period) {
      TimePeriod.week => (10.0, 2),
      TimePeriod.month => (40.0, 6),
      TimePeriod.year => (400.0, 60),
    };

    final String strainPercent;
    final String adviceText;
    final bool isHighStrain;

    if (totalKm >= highKmThreshold || sessionCount >= highSessionsThreshold) {
      strainPercent = '88%';
      isHighStrain = true;
      adviceText = isVi
          ? 'Bạn đã hoàn thành cường độ vận động cao trong giai đoạn này. Hãy chú trọng các bài phục hồi chủ động và duy trì giấc ngủ chất lượng để tránh quá tải.'
          : 'High training volume reached for this period. Prioritize active recovery sessions and quality sleep to avoid overtraining.';
    } else if (totalKm >= modKmThreshold ||
        sessionCount >= modSessionsThreshold) {
      strainPercent = '65%';
      isHighStrain = false;
      adviceText = isVi
          ? 'Thể lực của bạn đang ở trạng thái tối ưu. Bạn có thể duy trì nhịp độ này hoặc xen kẽ một buổi đạp xe biến tốc để bứt phá thể tích oxy tối đa (VO2 max).'
          : 'Optimal fitness equilibrium. Maintain your cadence or integrate a cycling interval session to expand aerobic threshold.';
    } else {
      strainPercent = '35%';
      isHighStrain = false;
      adviceText = isVi
          ? 'Khối lượng vận động nhẹ nhàng. Bạn hoàn toàn sẵn sàng cho một cữ chạy bộ hoặc đạp xe ngoài trời tiếp theo.'
          : 'Low physical strain. Your body is well-rested and fully primed for your next endurance workout.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(Icons.spa_rounded, color: colors.primary, size: 20),
              ),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'CHỈ DẪN HỒI PHỤC' : 'RECOVERY GUIDANCE',
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          isVi
                              ? 'Tải vận động: $strainPercent'
                              : 'Strain: $strainPercent',
                          style: KineticTypography.unitLabel.copyWith(
                            color: isHighStrain
                                ? colors.tertiary
                                : colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adviceText,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              KineticButton(
                label: isVi ? 'Lên lịch đi bộ nhẹ' : 'Schedule light walk',
                icon: Icons.directions_walk_rounded,
                variant: KineticButtonVariant.secondary,
                isFullWidth: false,
                onPressed: () {
                  ref.read(mainTabControllerProvider.notifier).state =
                      activityTabIndex;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
