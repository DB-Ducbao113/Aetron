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
    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : displayDistanceKm;
    final distanceUnit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final formattedDistance = (useMetricUnits
            ? displayDistanceKm
            : WorkoutFormatters.kmToMi(displayDistanceKm))
        .toStringAsFixed(2);

    final durationFormatted = WorkoutFormatters.formatDurationFromSeconds(workout.durationSec);

    final isCycling = workout.activityType.toLowerCase() == 'cycling';
    final avgPace = WorkoutFormatters.formatPaceFromDistanceAndDuration(
      distanceKm: displayDistanceKm,
      durationSec: workout.durationSec,
      useMetric: useMetricUnits,
    );

    final movingPace = WorkoutFormatters.formatMovingPaceFromDistanceAndDuration(
      distanceKm: effectiveDistanceKm,
      durationSec: workout.movingTimeSec,
      restDurationSec: 0,
      useMetric: useMetricUnits,
    );

    final speedUnit = useMetricUnits ? 'km/h' : 'mph';
    final avgSpeed = useMetricUnits
        ? workout.avgSpeedKmh
        : WorkoutFormatters.kmToMi(workout.avgSpeedKmh);

    final showSteps = _hasSteps(workout.activityType) && workout.steps > 0;

    return KineticCard(
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
                isVi ? 'THÔNG SỐ CHI TIẾT' : 'WORKOUT TELEMETRY',
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
                : (isVi ? 'Pace TB' : 'Avg Pace'),
            value: isCycling ? '${avgSpeed.toStringAsFixed(1)} $speedUnit' : avgPace,
            colors: colors,
            isHighlighted: true,
          ),
          _divider(colors),

          // 4. Calo tiêu thụ
          _TelemetryRow(
            icon: Icons.local_fire_department_outlined,
            label: isVi ? 'Calo' : 'Calories',
            value: '${workout.caloriesKcal.round()} kcal',
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

          _divider(colors),

          // 6. Pace di chuyển (nếu không phải cycling)
          if (!isCycling) ...[
            _TelemetryRow(
              icon: Icons.directions_run_rounded,
              label: isVi ? 'Pace di chuyển' : 'Moving Pace',
              value: movingPace,
              colors: colors,
            ),
            _divider(colors),
          ],

          // 7. Thời gian di chuyển
          _TelemetryRow(
            icon: Icons.play_circle_outline_rounded,
            label: isVi ? 'Thời gian di chuyển' : 'Moving Time',
            value: WorkoutFormatters.formatElapsedClock(workout.movingTimeSec),
            colors: colors,
          ),
          _divider(colors),

          // 8. Thời gian nghỉ
          _TelemetryRow(
            icon: Icons.pause_circle_outline_rounded,
            label: isVi ? 'Thời gian nghỉ' : 'Rest Time',
            value: WorkoutFormatters.formatElapsedClock(workout.gpsAnalysis.restDurationSec),
            colors: colors,
          ),
          _divider(colors),

          // 9. Tốc độ trung bình (nếu chưa hiển thị ở trên)
          if (!isCycling) ...[
            _TelemetryRow(
              icon: Icons.speed_outlined,
              label: isVi ? 'Tốc độ trung bình' : 'Avg Speed',
              value: '${avgSpeed.toStringAsFixed(1)} $speedUnit',
              colors: colors,
            ),
            _divider(colors),
          ],

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
