import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class KineticWorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticWorkoutHistoryCard({
    super.key,
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'running':
      default:
        return Icons.directions_run_rounded;
    }
  }

  String _getActivityName(String type, AppLanguage lang) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return lang == AppLanguage.vi ? 'Đạp xe' : 'Cycling';
      case 'walking':
        return lang == AppLanguage.vi ? 'Đi bộ' : 'Walking';
      case 'running':
      default:
        return lang == AppLanguage.vi ? 'Chạy bộ' : 'Running';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isCycling = workout.activityType.toLowerCase() == 'cycling';
    final activityIcon = _getActivityIcon(workout.activityType);
    final activityName = _getActivityName(workout.activityType, currentLang);
    final timeStr = DateFormat('HH:mm').format(workout.startedAt.toLocal());

    final distanceKm = workout.distanceKm;

    final distanceStr = WorkoutFormatters.formatDistance(
      distanceKm,
      useMetric: useMetricUnits,
      decimals: 2,
    );

    final durationStr = workout.durationSec > 0
        ? WorkoutFormatters.formatDurationFromSeconds(workout.durationSec)
        : '0s';

    final paceSpeedStr = isCycling
        ? '${(useMetricUnits ? workout.avgSpeedKmh : workout.avgSpeedKmh * 0.621371).toStringAsFixed(1)} ${useMetricUnits ? 'km/h' : 'mph'}'
        : (workout.gpsAnalysis.effectivePaceSecPerKm != null &&
                workout.gpsAnalysis.effectivePaceSecPerKm! > 0
            ? WorkoutFormatters.formatPaceFromSecondsPerKm(
                workout.gpsAnalysis.effectivePaceSecPerKm!,
                useMetric: useMetricUnits,
              )
            : WorkoutFormatters.formatPaceFromSpeedKmh(
                workout.avgSpeedKmh,
                useMetric: useMetricUnits,
              ));

    return KineticCard(
      useLiquidGlass: false,
      padding: const EdgeInsets.all(17),
      borderRadius: 21,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutDetailsScreen(
              workoutId: workout.id,
              initialWorkout: workout,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Activity Pill + Time + Arrow
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(activityIcon, size: 12, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      activityName,
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.primary,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),

              Text(
                timeStr,
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),
              BladeIcon(BladeIconName.chevR, size: 16, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),

          // Main Metrics Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Distance
              Text(
                distanceStr.replaceAll(RegExp(r'[a-zA-Z]'), '').trim(),
                style: KineticTypography.metricMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                useMetricUnits ? 'KM' : 'MI',
                style: KineticTypography.label.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: KineticTokens.spaceSM),

              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Duration
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 12,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              durationStr,
                              style: KineticTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: KineticTokens.spaceSM),

                        // Pace or Speed
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 12,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              paceSpeedStr,
                              style: KineticTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }
}
