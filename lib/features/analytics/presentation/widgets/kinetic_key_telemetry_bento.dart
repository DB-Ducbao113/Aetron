import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticKeyTelemetryBento extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final bool useMetricUnits;
  final bool isVi;

  const KineticKeyTelemetryBento({
    super.key,
    required this.workouts,
    required this.useMetricUnits,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    // Aggregate statistics
    double totalDistKm = 0.0;
    int totalDurationSec = 0;
    int totalCalories = 0;

    for (final w in workouts) {
      totalDistKm += w.distanceKm;
      totalDurationSec += w.durationSec;
      totalCalories += w.caloriesKcal.round();
    }

    final displayDistance =
        useMetricUnits ? totalDistKm : WorkoutFormatters.kmToMi(totalDistKm);
    final distanceUnit =
        WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final durationStr = totalDurationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(totalDurationSec)
        : '00:00';

    final caloriesStr = totalCalories > 0
        ? totalCalories.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'Chỉ số tổng hợp' : 'Key telemetry',
          style: KineticTypography.cardEyebrowOf(colors),
        ),
        const SizedBox(height: KineticTokens.spaceXS),
        Row(
          children: [
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'Quãng đường' : 'Distance',
                value: displayDistance > 0
                    ? displayDistance.toStringAsFixed(1)
                    : '—',
                numericValue: displayDistance > 0 ? displayDistance : null,
                decimalPlaces: 1,
                unit: displayDistance > 0 ? distanceUnit.toUpperCase() : '',
                icon: Icons.route_rounded,
                accentColor: colors.primary,
              ),
            ),
            const SizedBox(width: KineticTokens.spaceXS),
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'Thời gian' : 'Active time',
                value: durationStr,
                unit: '',
                icon: Icons.timer_rounded,
                accentColor: colors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: KineticTokens.spaceXS),
        Row(
          children: [
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'Năng lượng' : 'Calories',
                value: caloriesStr,
                numericValue: totalCalories > 0 ? totalCalories : null,
                decimalPlaces: 0,
                unit: totalCalories > 0 ? 'kcal' : '',
                icon: Icons.local_fire_department_rounded,
                accentColor: colors.tertiary,
              ),
            ),
            const SizedBox(width: KineticTokens.spaceXS),
            Expanded(
              child: _TelemetryCard(
                label: isVi ? 'Buổi tập' : 'Sessions',
                value: '${workouts.length}',
                numericValue: workouts.length,
                decimalPlaces: 0,
                unit: isVi ? 'buổi' : 'workouts',
                icon: Icons.sports_score_rounded,
                accentColor: colors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final num? numericValue;
  final int decimalPlaces;
  final String unit;
  final IconData icon;
  final Color accentColor;

  const _TelemetryCard({
    required this.label,
    required this.value,
    this.numericValue,
    this.decimalPlaces = 0,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return KineticCard(
      useLiquidGlass: true,
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      borderRadius: 21,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXXS),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (numericValue != null)
                  KineticCountUp(
                    value: numericValue!,
                    decimalPlaces: decimalPlaces,
                    style: KineticTypography.metricCompact.copyWith(
                      color: colors.textPrimary,
                    ),
                  )
                else
                  Text(
                    value,
                    style: KineticTypography.metricCompact.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: KineticTokens.spaceXXS),
                  Text(
                    unit,
                    style: KineticTypography.unitLabel.copyWith(
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
