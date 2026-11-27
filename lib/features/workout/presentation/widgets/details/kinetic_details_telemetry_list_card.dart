import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Single unified telemetry list card for WorkoutDetailsScreen
class KineticDetailsTelemetryListCard extends StatelessWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const KineticDetailsTelemetryListCard({
    super.key,
    required this.workout,
    required this.useMetricUnits,
    required this.currentLang,
  });

  bool _hasSteps(String activityType) {
    final t = activityType.toLowerCase();
    return t == 'running' || t == 'walking';
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return NumberFormat('#,###').format(steps);
    }
    return '$steps';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    final displayDistanceKm = workout.distanceKm;
    final distanceUnit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final formattedDistance = (useMetricUnits
            ? displayDistanceKm
            : WorkoutFormatters.kmToMi(displayDistanceKm))
        .toStringAsFixed(2);

    final totalDurationSec = workout.durationSec;
    final durationFormatted = WorkoutFormatters.formatDurationFromSeconds(totalDurationSec);

    // Calculate effective moving and rest durations robustly
    final effectiveMovingSec = workout.movingTimeSec > 0
        ? workout.movingTimeSec
        : (workout.gpsAnalysis.restDurationSec > 0 &&
                totalDurationSec > workout.gpsAnalysis.restDurationSec
            ? totalDurationSec - workout.gpsAnalysis.restDurationSec
            : totalDurationSec);

    final effectiveRestSec = workout.gpsAnalysis.restDurationSec > 0
        ? workout.gpsAnalysis.restDurationSec
        : math.max(0, totalDurationSec - effectiveMovingSec);

    final movingTimeFormatted =
        WorkoutFormatters.formatDurationFromSeconds(effectiveMovingSec);
    final restTimeFormatted =
        WorkoutFormatters.formatDurationFromSeconds(effectiveRestSec);

    final isCycling = workout.activityType.toLowerCase() == 'cycling';

    // Primary Pace: prioritize effectivePaceSecPerKm from GPS analysis (excluding stops/drift),
    // then calculate from moving duration, then from avgSpeedKmh.
    final String avgPace;
    if (workout.gpsAnalysis.effectivePaceSecPerKm != null &&
        workout.gpsAnalysis.effectivePaceSecPerKm! > 0) {
      avgPace = WorkoutFormatters.formatPaceFromSecondsPerKm(
        workout.gpsAnalysis.effectivePaceSecPerKm!,
        useMetric: useMetricUnits,
      );
    } else if (displayDistanceKm > 0 && effectiveMovingSec > 0) {
      avgPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
        distanceKm: displayDistanceKm,
        durationSec: effectiveMovingSec,
        useMetric: useMetricUnits,
      );
    } else if (workout.avgSpeedKmh >= 0.1) {
      avgPace = WorkoutFormatters.formatPaceFromSpeedKmh(
        workout.avgSpeedKmh,
        useMetric: useMetricUnits,
      );
    } else {
      avgPace = '--';
    }

    // Moving pace (matches moving time)
    final movingPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: displayDistanceKm,
      durationSec: effectiveMovingSec,
      useMetric: useMetricUnits,
    );

    // Speed calculation consistent with distance and moving time
    final rawSpeedKmh = workout.avgSpeedKmh > 0
        ? workout.avgSpeedKmh
        : (effectiveMovingSec > 0 && displayDistanceKm > 0
            ? WorkoutFormatters.computeAverageSpeedKmh(
                distanceKm: displayDistanceKm,
                durationSec: effectiveMovingSec,
              )
            : 0.0);

    final speedUnit = useMetricUnits ? 'km/h' : 'mph';
    final avgSpeed = useMetricUnits
        ? rawSpeedKmh
        : WorkoutFormatters.kmToMi(rawSpeedKmh);

    // Calories: fallback to estimated 62 kcal/km if <= 0
    final effectiveCalories = workout.caloriesKcal > 0
        ? workout.caloriesKcal.round()
        : (displayDistanceKm * 62).round();

    // Steps and Cadence (SPM)
    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;
    final cadenceSpm = (showSteps && effectiveMovingSec >= 30)
        ? ((workout.steps / effectiveMovingSec) * 60).round()
        : 0;

    return KineticCard(
      useLiquidGlass: false,
      borderRadius: 21,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of unified list
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                isVi ? 'Thông số chi tiết' : 'Workout telemetry',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.primary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Quãng đường
          _TelemetryRow(
            icon: Icons.straighten_rounded,
            label: isVi ? 'Quãng đường' : 'Distance',
            value: '$formattedDistance $distanceUnit',
            colors: colors,
            isHighlighted: true,
          ),
          _divider(colors),

          // 2. Thời gian
          _TelemetryRow(
            icon: Icons.timer_outlined,
            label: isVi ? 'Thời gian' : 'Duration',
            value: durationFormatted,
            colors: colors,
            isHighlighted: true,
          ),
          _divider(colors),

          // 3. Pace TB (hoặc Tốc độ TB với đạp xe)
          _TelemetryRow(
            icon: Icons.speed_rounded,
            label: isCycling
                ? (isVi ? 'Tốc độ TB' : 'Avg Speed')
                : (isVi ? 'Nhịp độ TB' : 'Avg Pace'),
            value: isCycling ? '${avgSpeed.toStringAsFixed(1)} $speedUnit' : avgPace,
            colors: colors,
            isHighlighted: true,
          ),
          _divider(colors),

          // 4. Calo tiêu thụ
          _TelemetryRow(
            icon: Icons.local_fire_department_outlined,
            label: isVi ? 'Calo' : 'Calories',
            value: '$effectiveCalories kcal',
            colors: colors,
            isHighlighted: true,
          ),

          // 5. Số bước (nếu có)
          if (showSteps) ...[
            _divider(colors),
            _TelemetryRow(
              icon: Icons.directions_walk_rounded,
              label: isVi ? 'Số bước' : 'Steps',
              value: '${_formatSteps(workout.steps)} ${isVi ? "bước" : "steps"}',
              colors: colors,
              isHighlighted: true,
            ),
          ],

          // 5b. Nhịp bước Cadence (nếu có)
          if (cadenceSpm > 0) ...[
            _divider(colors),
            _TelemetryRow(
              icon: Icons.timer_3_rounded,
              label: isVi ? 'Nhịp bước' : 'Cadence',
              value: '$cadenceSpm spm',
              colors: colors,
              isHighlighted: true,
            ),
          ],

          _divider(colors),

          // 6. Pace di chuyển (nếu không phải cycling)
          if (!isCycling) ...[
            _TelemetryRow(
              icon: Icons.directions_run_rounded,
              label: isVi ? 'Nhịp độ di chuyển' : 'Moving Pace',
              value: movingPace,
              colors: colors,
            ),
            _divider(colors),
          ],

          // 7. Thời gian di chuyển
          _TelemetryRow(
            icon: Icons.play_circle_outline_rounded,
            label: isVi ? 'Thời gian di chuyển' : 'Moving Time',
            value: movingTimeFormatted,
            colors: colors,
          ),
          _divider(colors),

          // 8. Thời gian nghỉ
          _TelemetryRow(
            icon: Icons.pause_circle_outline_rounded,
            label: isVi ? 'Thời gian nghỉ' : 'Rest Time',
            value: restTimeFormatted,
            colors: colors,
          ),
          _divider(colors),

          // 10. Giờ bắt đầu
          _TelemetryRow(
            icon: Icons.login_rounded,
            label: isVi ? 'Bắt đầu' : 'Started',
            value: DateFormat('HH:mm:ss').format(workout.startedAt.toLocal()),
            colors: colors,
          ),
          _divider(colors),

          // 11. Giờ kết thúc
          _TelemetryRow(
            icon: Icons.logout_rounded,
            label: isVi ? 'Kết thúc' : 'Finished',
            value: DateFormat('HH:mm:ss').format(workout.endedAt.toLocal()),
            colors: colors,
          ),
          _divider(colors),

          // 12. Ngày lưu
          _TelemetryRow(
            icon: Icons.save_outlined,
            label: isVi ? 'Đã lưu' : 'Saved',
            value: DateFormat('dd/MM/yyyy HH:mm').format(workout.createdAt.toLocal()),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _divider(KineticColors colors) => Divider(
        height: 18,
        thickness: 0.8,
        color: colors.borderSubtle.withValues(alpha: 0.6),
      );
}

class _TelemetryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final KineticColors colors;
  final bool isHighlighted;

  const _TelemetryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlighted ? colors.primary : colors.textMuted,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: KineticTypography.label.copyWith(
            color: isHighlighted ? colors.textPrimary : colors.textMuted,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: KineticTypography.label.copyWith(
            color: isHighlighted ? colors.primary : colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFeatures: KineticTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}
