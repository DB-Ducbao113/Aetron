import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_empty_state.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_workout_history_card.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DailyWorkoutList extends ConsumerWidget {
  final List<WorkoutSession> workouts;
  final String range;

  const DailyWorkoutList({
    super.key,
    required this.workouts,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    if (workouts.isEmpty) {
      return KineticHistoryEmptyState(
        currentLang: currentLang,
        isFiltered: true,
      );
    }

    final grouped = _groupWorkoutsByDate(workouts, currentLang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final dateHeader = entry.key;
        final dayWorkouts = entry.value;

        // Calculate total distance for this day
        final dayTotalDist = dayWorkouts.fold(0.0, (sum, w) {
          final d = w.gpsAnalysis.validDistanceKm > 0
              ? w.gpsAnalysis.validDistanceKm
              : w.distanceKm;
          return sum + d;
        });

        final dayDistStr = WorkoutFormatters.formatDistance(
          dayTotalDist,
          useMetric: useMetricUnits,
          decimals: 1,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: KineticTokens.spaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Header Row (Date + Day Total Distance)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
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
                        const SizedBox(width: KineticTokens.spaceXS),
                        Text(
                          dateHeader,
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    if (dayTotalDist > 0)
                      Text(
                        dayDistStr,
                        style: KineticTypography.label.copyWith(
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Workout History Cards for this day
              Column(
                children: dayWorkouts.map((workout) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KineticTokens.spaceXS),
                    child: KineticWorkoutHistoryCard(
                      workout: workout,
                      useMetricUnits: useMetricUnits,
                      currentLang: currentLang,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<WorkoutSession>> _groupWorkoutsByDate(
    List<WorkoutSession> items,
    AppLanguage lang,
  ) {
    final map = <String, List<WorkoutSession>>{};
    for (final workout in items) {
      final localStart = workout.startedAt.toLocal();
      final dateHeader = lang == AppLanguage.vi
          ? '${localStart.day.toString().padLeft(2, '0')}/${localStart.month.toString().padLeft(2, '0')}/${localStart.year}'
          : DateFormat('MMM dd, yyyy').format(localStart).toUpperCase();
      map.putIfAbsent(dateHeader, () => []).add(workout);
    }
    return map;
  }
}
