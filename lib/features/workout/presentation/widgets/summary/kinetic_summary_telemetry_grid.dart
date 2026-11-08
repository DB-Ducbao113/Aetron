import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummaryTelemetryGrid extends StatelessWidget {
  final String activityType;
  final int durationSeconds;
  final int movingTimeSeconds;
  final double avgSpeedKmh;
  final double? effectivePaceSecPerKm;
  final int calories;
  final int steps;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticSummaryTelemetryGrid({
    super.key,
    required this.activityType,
    required this.durationSeconds,
    required this.movingTimeSeconds,
    required this.avgSpeedKmh,
    this.effectivePaceSecPerKm,
    required this.calories,
    required this.steps,
    required this.useMetricUnits,
    required this.currentLang,
  });

  bool get _isCycling => activityType.toLowerCase() == 'cycling';

  @override
  Widget build(BuildContext context) {
    // Moving vs Elapsed Time
    final effectiveMovingSec = movingTimeSeconds > 0 ? movingTimeSeconds : durationSeconds;
    final movingTimeFormatted = WorkoutFormatters.formatDurationFromSeconds(effectiveMovingSec);
    final hasPausedTime = durationSeconds > effectiveMovingSec;
    final totalTimeFormatted = WorkoutFormatters.formatDurationFromSeconds(durationSeconds);

    // Pace or Speed
    final String primaryPaceSpeedValue;
    final String primaryPaceSpeedUnit;
    final String paceSpeedLabel;

    if (_isCycling) {
      paceSpeedLabel = currentLang == AppLanguage.vi ? 'TỐC ĐỘ TB' : 'AVG SPEED';
      final speedVal = useMetricUnits ? avgSpeedKmh : avgSpeedKmh * 0.621371;
      primaryPaceSpeedValue = speedVal.toStringAsFixed(1);
      primaryPaceSpeedUnit = useMetricUnits ? 'km/h' : 'mph';
    } else {
      paceSpeedLabel = currentLang == AppLanguage.vi ? 'PACE TRUNG BÌNH' : 'AVG PACE';
      final formattedPace = effectivePaceSecPerKm != null
          ? WorkoutFormatters.formatPaceFromSecondsPerKm(
              effectivePaceSecPerKm!,
              useMetric: useMetricUnits,
            )
          : WorkoutFormatters.formatPaceFromSpeedKmh(
              avgSpeedKmh,
              useMetric: useMetricUnits,
            );
      primaryPaceSpeedValue = formattedPace;
      primaryPaceSpeedUnit = useMetricUnits ? '/km' : '/mi';
    }

    // Fourth Tile: Steps (for Run/Walk) or Cadence/Speed max
    final String fourthLabel;
    final String fourthValue;
    final String fourthUnit;
    final IconData fourthIcon;
    final String? fourthSubtitle;

    if (_isCycling) {
      fourthLabel = currentLang == AppLanguage.vi ? 'VẬN TỐC TỐI ĐA' : 'MAX SPEED';
      final maxSpeed = avgSpeedKmh * 1.35; // Estimated max speed
      final dispMax = useMetricUnits ? maxSpeed : maxSpeed * 0.621371;
      fourthValue = dispMax.toStringAsFixed(1);
      fourthUnit = useMetricUnits ? 'km/h' : 'mph';
      fourthIcon = Icons.speed_rounded;
      fourthSubtitle = currentLang == AppLanguage.vi ? 'Ước tính cao điểm' : 'Peak estimate';
    } else {
      fourthLabel = currentLang == AppLanguage.vi ? 'TỔNG SỐ BƯỚC' : 'TOTAL STEPS';
      fourthValue = steps > 0 ? '$steps' : '--';
      fourthUnit = currentLang == AppLanguage.vi ? 'bước' : 'steps';
      fourthIcon = Icons.directions_walk_rounded;
      if (steps > 0 && effectiveMovingSec > 60) {
        final cadenceSpm = ((steps / effectiveMovingSec) * 60).round();
        fourthSubtitle = '$cadenceSpm spm ${currentLang == AppLanguage.vi ? 'nhịp bước' : 'cadence'}';
      } else {
        fourthSubtitle = null;
      }
    }

    final colors = context.kinetic;
    final hairline = colors.borderSubtle;

    // V4: flat 2x2 grid — hairline dividers instead of boxed bento cards.
    Widget cell(Widget child) => Expanded(child: child);
    Widget vDivider() => Container(width: 1, color: hairline);
    Widget hDivider() => Container(height: 1, color: hairline);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: hairline),
          bottom: BorderSide(color: hairline),
        ),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Moving Time
                cell(
                  _TelemetryCard(
                    label: currentLang == AppLanguage.vi ? 'THỜI GIAN DI CHUYỂN' : 'MOVING TIME',
                    value: movingTimeFormatted,
                    unit: null,
                    icon: Icons.timer_rounded,
                    subtitle: hasPausedTime
                        ? (currentLang == AppLanguage.vi
                            ? 'Tổng: $totalTimeFormatted'
                            : 'Elapsed: $totalTimeFormatted')
                        : null,
                  ),
                ),
                vDivider(),

                // 2. Pace / Speed
                cell(
                  _TelemetryCard(
                    label: paceSpeedLabel,
                    value: primaryPaceSpeedValue,
                    unit: primaryPaceSpeedUnit,
                    icon: Icons.speed_rounded,
                    subtitle: null,
                  ),
                ),
              ],
            ),
          ),
          hDivider(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3. Active Calories
                cell(
                  _TelemetryCard(
                    label: currentLang == AppLanguage.vi ? 'NĂNG LƯỢNG' : 'ENERGY BURN',
                    value: '$calories',
                    unit: 'kcal',
                    icon: Icons.local_fire_department_rounded,
                    subtitle: currentLang == AppLanguage.vi ? 'Calo hoạt động' : 'Active burn',
                  ),
                ),
                vDivider(),

                // 4. Steps / Max speed
                cell(
                  _TelemetryCard(
                    label: fourthLabel,
                    value: fourthValue,
                    unit: fourthUnit,
                    icon: fourthIcon,
                    subtitle: fourthSubtitle,
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

class _TelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final String? subtitle;

  const _TelemetryCard({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    // V4: flat cell — no card chrome; the grid's hairlines do the framing.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceSM,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: KineticTypography.metricCard.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: KineticTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
