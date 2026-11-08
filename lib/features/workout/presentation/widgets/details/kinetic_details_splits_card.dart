import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticDetailsSplitsCard extends StatelessWidget {
  final List<WorkoutLapSplit> lapSplits;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticDetailsSplitsCard({
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

    // Identify fastest split
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

    final unitLabel = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase();

    // V4: flat section — hairline frame, rows already hairline-divided.
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
                  Icon(
                    Icons.splitscreen_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentLang == AppLanguage.vi ? 'PHÂN TÁCH CỰ LY (SPLITS)' : 'SPLITS BREAKDOWN',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Text(
                '${lapSplits.length} $unitLabel',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Splits Table
          for (final split in lapSplits) ...[
            _SplitRow(
              split: split,
              isFastest: split.index == fastestIndex,
              minPace: minPace,
              maxPace: maxPace,
              useMetricUnits: useMetricUnits,
              colors: colors,
            ),
            if (split != lapSplits.last)
              Divider(
                height: 14,
                thickness: 0.6,
                color: colors.borderSubtle,
              ),
          ],
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final WorkoutLapSplit split;
  final bool isFastest;
  final double minPace;
  final double maxPace;
  final bool useMetricUnits;
  final KineticColors colors;

  const _SplitRow({
    required this.split,
    required this.isFastest,
    required this.minPace,
    required this.maxPace,
    required this.useMetricUnits,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final unitLabel = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits).toUpperCase();
    final paceStr = WorkoutFormatters.formatSplitPace(
      split.paceMinPerKm,
      useMetric: useMetricUnits,
    );

    // Compute pace bar ratio
    double barRatio = 0.5;
    if (maxPace > minPace) {
      barRatio = 1.0 - ((split.paceMinPerKm - minPace) / (maxPace - minPace)) * 0.7;
    } else {
      barRatio = 1.0;
    }
    barRatio = math.max(0.2, math.min(1.0, barRatio));

    final barColor = isFastest ? colors.primary : colors.secondary;

    return Row(
      children: [
        // Lap Badge
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isFastest
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          child: Text(
            '$unitLabel ${split.index}',
            style: KineticTypography.unitLabel.copyWith(
              color: isFastest ? colors.primary : colors.textMuted,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),

        // Pace Bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 5,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Container(
                    height: 5,
                    width: constraints.maxWidth * barRatio,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),

        // Split Time
        Text(
          WorkoutFormatters.formatDurationFromSeconds(split.durationSeconds),
          style: KineticTypography.bodySmall.copyWith(
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: 10),

        // Split Pace
        SizedBox(
          width: 62,
          child: Text(
            paceStr,
            textAlign: TextAlign.right,
            style: KineticTypography.bodySmall.copyWith(
              color: isFastest ? colors.primary : colors.textPrimary,
              fontWeight: isFastest ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}
