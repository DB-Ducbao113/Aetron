import 'dart:math' as math;
import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticPerformanceStoryBento extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final TimePeriod period;
  final double currentDistanceKm;
  final double previousDistanceKm;
  final bool useMetricUnits;
  final bool isVi;

  const KineticPerformanceStoryBento({
    super.key,
    required this.workouts,
    required this.period,
    required this.currentDistanceKm,
    required this.previousDistanceKm,
    required this.useMetricUnits,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    // 1. Calculate percentage change vs previous period
    final double? percentChange;
    final bool isNewBenchmark;
    if (previousDistanceKm > 0.05) {
      percentChange =
          ((currentDistanceKm - previousDistanceKm) / previousDistanceKm) * 100;
      isNewBenchmark = false;
    } else if (currentDistanceKm > 0.05) {
      percentChange = null;
      isNewBenchmark = true;
    } else {
      percentChange = null;
      isNewBenchmark = false;
    }

    final isPositive = percentChange != null && percentChange >= 0;

    // 2. Compute 7-day intervals (Monday to Sunday) for week view
    final now = DateTime.now();
    final dayNames = isVi
        ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Map workouts to day of week (1 = Mon ... 7 = Sun)
    final dayDistances = List<double>.filled(7, 0.0);
    for (final w in workouts) {
      final weekday = w.createdAt.weekday; // 1 to 7
      final distKm = w.distanceKm;
      dayDistances[weekday - 1] += distKm;
    }

    // Find peak day
    double peakVal = 0.0;
    int peakDayIdx = -1;
    for (int i = 0; i < 7; i++) {
      if (dayDistances[i] > peakVal) {
        peakVal = dayDistances[i];
        peakDayIdx = i;
      }
    }

    final double maxBarHeight = math.max(peakVal * 1.25, 5.0);

    // Hero distance
    final displayDistance = useMetricUnits
        ? currentDistanceKm
        : WorkoutFormatters.kmToMi(currentDistanceKm);
    final distanceUnit =
        WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);

    // Dynamic story narrative headline & description
    final String storyHeadline;
    final String storyBody;
    final int sessionCount = workouts.length;

    if (currentDistanceKm < 0.1) {
      storyHeadline = isVi
          ? 'Bắt đầu tuần mới tràn đầy năng lượng'
          : 'Ready for your next milestone';
      storyBody = isVi
          ? 'Chưa ghi nhận hoạt động trong giai đoạn này. Hãy chọn một môn tập và bắt đầu ngay hôm nay!'
          : 'No workouts tracked yet in this timeframe. Pick a sport and lace up!';
    } else if (percentChange != null && percentChange >= 15) {
      storyHeadline = isVi
          ? 'Giai đoạn bứt phá mạnh mẽ nhất của bạn'
          : 'Your strongest endurance breakthrough';
      storyBody = isVi
          ? 'Bạn đã hoàn thành $sessionCount buổi tập, tăng trưởng ${percentChange.abs().toStringAsFixed(0)}% khối lượng vận động so với kỳ trước.'
          : 'You completed $sessionCount sessions, achieving a ${percentChange.abs().toStringAsFixed(0)}% volume increase compared to previous.';
    } else if (sessionCount >= 4) {
      storyHeadline = isVi
          ? 'Duy trì nhịp độ ổn định và bền bỉ'
          : 'Steady endurance rhythm maintained';
      storyBody = isVi
          ? 'Khối lượng tập luyện được phân bổ đều đặn qua $sessionCount buổi tập với nền tảng thể lực rất tốt.'
          : 'Training volume evenly distributed across $sessionCount sessions with consistent fitness execution.';
    } else {
      storyHeadline = isVi
          ? 'Tiếp tục tích lũy quãng đường bền vững'
          : 'Consistent progress building up';
      storyBody = isVi
          ? 'Đã tích lũy ${displayDistance.toStringAsFixed(1)} $distanceUnit qua $sessionCount buổi tập hiệu quả.'
          : 'Accumulated ${displayDistance.toStringAsFixed(1)} $distanceUnit across $sessionCount structured sessions.';
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
          // 1. Story Header with Icon Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (period) {
                        TimePeriod.week => isVi ? 'BẢN TIN HIỆU SUẤT · TUẦN NÀY' : 'PERFORMANCE BRIEF · THIS WEEK',
                        TimePeriod.month => isVi ? 'BẢN TIN HIỆU SUẤT · THÁNG ${now.month}' : 'PERFORMANCE BRIEF · THIS MONTH',
                        TimePeriod.year => isVi ? 'BẢN TIN HIỆU SUẤT · NĂM ${now.year}' : 'PERFORMANCE BRIEF · YEAR ${now.year}',
                      },
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: KineticTokens.spaceXXS),
                    Text(
                      storyHeadline,
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // 2. Hero Distance + Comparison Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayDistance.toStringAsFixed(1),
                style: KineticTypography.metricHero.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                distanceUnit,
                style: KineticTypography.headlineSmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: KineticTokens.spaceSM),
              if (percentChange != null || isNewBenchmark)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNewBenchmark || isPositive
                        ? colors.primary.withValues(alpha: 0.15)
                        : colors.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                    border: Border.all(
                      color: isNewBenchmark || isPositive
                          ? colors.primary.withValues(alpha: 0.4)
                          : colors.tertiary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNewBenchmark
                            ? Icons.star_rounded
                            : (isPositive
                                ? Icons.north_east_rounded
                                : Icons.south_east_rounded),
                        size: 13,
                        color: isNewBenchmark || isPositive
                            ? colors.primary
                            : colors.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNewBenchmark
                            ? (isVi ? 'MỐC MỚI' : 'NEW BENCHMARK')
                            : '${isPositive ? '+' : ''}${percentChange!.clamp(-100.0, 999.0).toStringAsFixed(0)}% ${isVi ? 'so với trước' : 'vs prev'}',
                        style: KineticTypography.unitLabel.copyWith(
                          color: isNewBenchmark || isPositive
                              ? colors.primary
                              : colors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Dynamic Narrative Body
          Text(
            storyBody,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: KineticTokens.spaceLG),

          // 4. Slender 7-Day Bar Chart
          Container(
            padding: const EdgeInsets.only(top: KineticTokens.spaceMD),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.borderSubtle.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final dayDist = dayDistances[i];
                      final isPeak = i == peakDayIdx && peakVal > 0.05;
                      final double ratio =
                          (dayDist / maxBarHeight).clamp(0.06, 1.0);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Floating km tag for peak day
                              if (isPeak)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(
                                      KineticTokens.radiusSM,
                                    ),
                                  ),
                                  child: Text(
                                    '${dayDist.toStringAsFixed(1)} $distanceUnit',
                                    style: KineticTypography.unitLabel.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 19),

                              // Slender bar
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: ratio,
                                  child: Container(
                                    width: isPeak ? 12 : 8,
                                    decoration: BoxDecoration(
                                      color: isPeak
                                          ? colors.primary
                                          : (dayDist > 0
                                              ? colors.secondary.withValues(
                                                  alpha: 0.55,
                                                )
                                              : colors.surface2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: KineticTokens.spaceXS),

                              // Day label
                              Text(
                                dayNames[i],
                                style: KineticTypography.caption.copyWith(
                                  fontWeight: isPeak
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isPeak
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: KineticTokens.spaceSM),

                // Footnote
                if (peakDayIdx >= 0 && peakVal > 0.05)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isVi
                                ? 'Ngày bùng nổ: ${dayNames[peakDayIdx]} (${((peakVal / currentDistanceKm) * 100).round()}% khối lượng)'
                                : 'Peak Day: ${dayNames[peakDayIdx]} (${((peakVal / currentDistanceKm) * 100).round()}% volume)',
                            style: KineticTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isVi ? 'Tổng 7 ngày' : '7-Day Total',
                        style: KineticTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
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
