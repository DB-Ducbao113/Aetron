import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class HistorySummaryData {
  final int workouts;
  final double distanceKm;
  final int durationSec;
  final int calories;
  final int steps;

  const HistorySummaryData({
    required this.workouts,
    required this.distanceKm,
    required this.durationSec,
    required this.calories,
    required this.steps,
  });
}

class KineticHistoryTelemetryBento extends StatelessWidget {
  final HistorySummaryData summary;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticHistoryTelemetryBento({
    super.key,
    required this.summary,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    final durationStr = WorkoutFormatters.formatDurationFromSeconds(summary.durationSec);
    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase();
    final avgPaceStr = summary.distanceKm > 0 && summary.durationSec > 0
        ? WorkoutFormatters.formatPaceFromDistanceAndDuration(
            distanceKm: summary.distanceKm,
            durationSec: summary.durationSec,
            useMetric: useMetricUnits,
          )
        : '—';

    final innerFill = colors.isDark
        ? const Color(0x28314B6B)
        : const Color(0x66FFFFFF);
    final innerBorder = colors.isDark
        ? const Color(0x38B6DCFF)
        : Colors.white.withValues(alpha: 0.85);

    return KineticCard(
      useLiquidGlass: true,
      padding: const EdgeInsets.all(17),
      borderRadius: 21,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Tổng quan giai đoạn' : 'Period telemetry matrix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.cardEyebrowOf(colors),
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: innerFill,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  border: Border.all(color: innerBorder),
                ),
                child: Text(
                  '${summary.workouts} ${isVi ? 'hoạt động' : 'workouts'}',
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // Hero Distance & Secondary Metrics Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Distance
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(KineticTokens.spaceSM),
                  decoration: BoxDecoration(
                    color: innerFill,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    border: Border.all(color: innerBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route_rounded, size: 14, color: colors.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              isVi ? 'Quãng đường' : 'Distance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KineticTokens.spaceXS),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: KineticCountUp(
                              value: useMetricUnits
                                  ? summary.distanceKm
                                  : WorkoutFormatters.kmToMi(summary.distanceKm),
                              decimals: 1,
                              style: KineticTypography.metricMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            unit,
                            style: KineticTypography.label.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),

              // Duration & Energy Right Column
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KineticTokens.spaceSM,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: innerFill,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                        border: Border.all(color: innerBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded, size: 14, color: colors.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              durationStr,
                              style: KineticTypography.label.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KineticTokens.spaceSM,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: innerFill,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                        border: Border.all(color: innerBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: KineticCountUp(
                              value: summary.calories.toDouble(),
                              formatter: (val) => '${val.round()} kcal',
                              style: KineticTypography.label.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),

          // Bottom Bar: Average Pace
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceSM,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: innerFill,
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              border: Border.all(color: innerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 13, color: colors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isVi ? 'Nhịp độ trung bình:' : 'Average pace:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KineticTokens.spaceXS),
                Text(
                  avgPaceStr,
                  style: KineticTypography.label.copyWith(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
