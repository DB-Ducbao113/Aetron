import 'dart:math' as math;
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummarySplitsCard extends StatelessWidget {
  final List<WorkoutLapSplit> lapSplits;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticSummarySplitsCard({
    super.key,
    required this.lapSplits,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    if (lapSplits.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.kinetic;

    // Find the fastest split (lowest pace min/km)
    double minPace = double.infinity;
    double maxPace = 0.0;
    int fastestIndex = -1;

    for (final split in lapSplits) {
      if (split.paceMinPerKm > 0) {
        if (split.paceMinPerKm < minPace) {
          minPace = split.paceMinPerKm;
          fastestIndex = split.index;
        }
        if (split.paceMinPerKm > maxPace) {
          maxPace = split.paceMinPerKm;
        }
      }
    }

    // V4: flat section — hairline frame + hairline row separators.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  BladeIcon(
                    BladeIconName.chart,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentLang == AppLanguage.vi ? 'PHÂN TÁCH CỰ LY' : 'SPLITS BREAKDOWN',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Text(
                '${lapSplits.length} ${currentLang == AppLanguage.vi ? 'chặng' : 'splits'}',
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Splits List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lapSplits.length,
            separatorBuilder: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 9),
                Container(height: 1, color: colors.borderSubtle),
                const SizedBox(height: 9),
              ],
            ),
            itemBuilder: (context, i) {
              final split = lapSplits[i];
              final isFastest = split.index == fastestIndex;
              final double paceRatio = maxPace > minPace
                  ? 1.0 - ((split.paceMinPerKm - minPace) / (maxPace - minPace)).clamp(0.0, 0.7)
                  : 1.0;

              final formattedPace = WorkoutFormatters.formatPaceFromSecondsPerKm(
                split.paceMinPerKm * 60,
                useMetric: useMetricUnits,
              );
              final splitDuration = WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds);

              return Row(
                children: [
                  // Split Index
                  SizedBox(
                    width: 44,
                    child: Text(
                      'Km ${split.index}',
                      style: KineticTypography.bodySmall.copyWith(
                        color: isFastest ? colors.primary : colors.textSecondary,
                        fontWeight: isFastest ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),

                  // Pace progress bar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: math.max(0.2, paceRatio),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: isFastest ? colors.primary : colors.textMuted,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fastest badge if applicable
                  if (isFastest) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                      ),
                      child: Text(
                        currentLang == AppLanguage.vi ? 'Nhanh nhất' : 'Fastest',
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],

                  // Pace value & duration
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedPace,
                        style: KineticTypography.bodySmall.copyWith(
                          color: isFastest ? colors.primary : colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: KineticTypography.tabularFigures,
                        ),
                      ),
                      Text(
                        splitDuration,
                        style: KineticTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
