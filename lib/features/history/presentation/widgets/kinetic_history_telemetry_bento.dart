import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
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

    final distanceStr = WorkoutFormatters.formatDistance(
      summary.distanceKm,
      useMetric: useMetricUnits,
      decimals: 1,
    );
    final durationStr = WorkoutFormatters.formatDurationFromSeconds(summary.durationSec);
    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase();
    final avgPaceStr = summary.distanceKm > 0 && summary.durationSec > 0
        ? WorkoutFormatters.formatPaceFromDistanceAndDuration(
            distanceKm: summary.distanceKm,
            durationSec: summary.durationSec,
            useMetric: useMetricUnits,
          )
        : '—';

    return KineticCard(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      borderRadius: KineticTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'TỔNG QUAN GIAI ĐOẠN' : 'PERIOD TELEMETRY MATRIX',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceXS, vertical: KineticTokens.spaceXXS),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  '${summary.workouts} ${isVi ? 'hoạt động' : 'workouts'}',
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
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
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route_rounded, size: 14, color: colors.primary),
                          const SizedBox(width: 5),
                          Text(
                            (isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE').toUpperCase(),
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.textMuted,
                              fontSize: 11,
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
                            child: Text(
                              distanceStr.replaceAll(RegExp(r'[a-zA-Z]'), '').trim(),
                              style: KineticTypography.metricMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceXS, vertical: KineticTokens.spaceXS),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded, size: 13, color: colors.secondary),
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
                      padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceXS, vertical: KineticTokens.spaceXS),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded,
                              size: 13, color: colors.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${summary.calories} kcal',
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),

          // Bottom Bar: Average Pace
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceSM, vertical: KineticTokens.spaceXS),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 13, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      isVi ? 'Pace trung bình:' : 'Average Pace:',
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
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
