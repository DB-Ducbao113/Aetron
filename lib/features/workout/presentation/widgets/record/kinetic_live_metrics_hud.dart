import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticLiveMetricsHud extends StatelessWidget {
  final double distanceMeters;
  final int durationSeconds;
  final int movingTimeSeconds;
  final double speedKmh;
  final double avgSpeedKmh;
  final int calories;
  final int stepCount;
  final int cadenceSpm;
  final String activityType;
  final bool useMetricUnits;
  final bool isVi;
  final bool isLargeMetricsMode;

  const KineticLiveMetricsHud({
    super.key,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.movingTimeSeconds,
    required this.speedKmh,
    required this.avgSpeedKmh,
    required this.calories,
    required this.stepCount,
    this.cadenceSpm = 0,
    required this.activityType,
    required this.useMetricUnits,
    required this.isVi,
    this.isLargeMetricsMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isCycling = activityType.toLowerCase() == 'cycling';
    final distanceKm = distanceMeters / 1000.0;
    final displayDistance = useMetricUnits
        ? distanceKm
        : WorkoutFormatters.kmToMi(distanceKm);
    final distanceUnit = WorkoutFormatters.distanceUnitLabel(
      useMetric: useMetricUnits,
    ).toUpperCase();

    // Speed / Pace calculations
    final String primarySecondaryValue;
    final String primarySecondaryUnit;
    final String primarySecondaryLabel;
    final String? comparisonNote;
    final bool isSpeedFaster;

    if (isCycling) {
      primarySecondaryLabel = isVi ? 'Tốc độ tức thì' : 'Current Speed';
      final effectiveSpeed = useMetricUnits ? speedKmh : speedKmh * 0.621371;
      primarySecondaryValue = effectiveSpeed.toStringAsFixed(1);
      primarySecondaryUnit = useMetricUnits ? 'km/h' : 'mph';

      final diff = speedKmh - avgSpeedKmh;
      isSpeedFaster = diff >= 0;
      final diffText = '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} ${useMetricUnits ? 'km/h' : 'mph'}';
      comparisonNote = '$diffText ${isVi ? 'so với trung bình' : 'vs avg'}';
    } else {
      primarySecondaryLabel = isVi ? 'Pace tức thì' : 'Live Pace';
      primarySecondaryValue = WorkoutFormatters.formatPaceFromSpeedKmh(
        speedKmh,
        useMetric: useMetricUnits,
      );
      primarySecondaryUnit = '';
      isSpeedFaster = speedKmh >= avgSpeedKmh;
      final avgPaceStr = WorkoutFormatters.formatPaceFromSpeedKmh(
        avgSpeedKmh,
        useMetric: useMetricUnits,
      );
      comparisonNote = '${isVi ? 'Pace trung bình' : 'Avg'}: $avgPaceStr';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Primary Giant Central Hero Metric: Distance
        Center(
          child: Semantics(
            container: true,
            label: isVi ? 'Quãng đường' : 'Distance',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  displayDistance.toStringAsFixed(2),
                  style: KineticTypography.metricHero.copyWith(
                    fontSize: isLargeMetricsMode ? 56 : 52,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    shadows: [
                      Shadow(
                        color: colors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  distanceUnit,
                  style: KineticTypography.metricUnit.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                    letterSpacing: 0.8,
                    fontSize: isLargeMetricsMode ? 20 : 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Divider
        Container(
          height: 1,
          color: colors.borderSubtle.withValues(alpha: 0.4),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
        const SizedBox(height: 12),

        // 2. Secondary Row: Speed/Pace & Elapsed Workout Time
        Row(
          children: [
            // Left Metric: Speed or Pace
            Expanded(
              child: _MetricTile(
                label: primarySecondaryLabel,
                icon: isCycling
                    ? Icons.speed_rounded
                    : Icons.directions_run_rounded,
                value: primarySecondaryValue,
                unit: primarySecondaryUnit,
                note: comparisonNote,
                isNotePositive: isSpeedFaster,
              ),
            ),
            const SizedBox(width: 10),

            // Right Metric: Elapsed Time
            Expanded(
              child: _MetricTile(
                label: isVi ? 'Thời gian' : 'Time',
                icon: Icons.timer_rounded,
                value: WorkoutFormatters.formatElapsedClock(durationSeconds),
                unit: '',
                note:
                    '${isVi ? 'Di chuyển' : 'Moving'}: ${WorkoutFormatters.formatElapsedClock(movingTimeSeconds)}',
                isNotePositive: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Tertiary Row: Calories & Steps/Cadence or Avg Speed
        Row(
          children: [
            // Left: Calories burned
            Expanded(
              child: _MetricTile(
                label: isVi ? 'Calo' : 'Calories',
                icon: Icons.local_fire_department_rounded,
                value: '$calories',
                unit: 'kcal',
                note: null,
                isNotePositive: null,
              ),
            ),
            const SizedBox(width: 10),

            // Right: Steps or Avg Speed (when Cycling)
            Expanded(
              child: isCycling
                  ? _MetricTile(
                      label: isVi ? 'Tốc độ TB' : 'Avg Speed',
                      icon: Icons.trending_up_rounded,
                      value: (useMetricUnits
                              ? avgSpeedKmh
                              : avgSpeedKmh * 0.621371)
                          .toStringAsFixed(1),
                      unit: useMetricUnits ? 'km/h' : 'mph',
                      note: null,
                      isNotePositive: null,
                    )
                  : _MetricTile(
                      label: isVi ? 'Bước chân' : 'Steps',
                      icon: Icons.directions_walk_rounded,
                      value: '$stepCount',
                      unit: isVi ? 'bước' : 'steps',
                      note: cadenceSpm > 0
                          ? '$cadenceSpm spm'
                          : (isVi ? 'Tổng số bước' : 'Total steps'),
                      isNotePositive: cadenceSpm > 0 ? true : null,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String unit;
  final String? note;
  final bool? isNotePositive;

  const _MetricTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    this.note,
    this.isNotePositive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              Icon(
                icon,
                size: 14,
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Big Value + Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: KineticTypography.metricCard.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: KineticTypography.unitLabel.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          // Footnote / delta comparison
          if (note != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                if (isNotePositive != null) ...[
                  Icon(
                    isNotePositive!
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: isNotePositive! ? colors.primary : colors.tertiary,
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: Text(
                    note!,
                    style: KineticTypography.unitLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isNotePositive != null
                          ? (isNotePositive! ? colors.primary : colors.tertiary)
                          : colors.textSecondary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact glassmorphic live telemetry card floating above the control dock in Map Mode.
/// Displays instant distance, elapsed time, current speed/pace, and calories in real time.
class KineticMiniMetricsCard extends StatelessWidget {
  final double distanceMeters;
  final int durationSeconds;
  final double speedKmh;
  final double avgSpeedKmh;
  final int calories;
  final String activityType;
  final bool useMetricUnits;
  final bool isVi;
  final VoidCallback? onExpand;

  const KineticMiniMetricsCard({
    super.key,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.speedKmh,
    required this.avgSpeedKmh,
    required this.calories,
    required this.activityType,
    required this.useMetricUnits,
    required this.isVi,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isCycling = activityType.toLowerCase() == 'cycling';
    final distanceKm = distanceMeters / 1000.0;
    final displayDistance = useMetricUnits
        ? distanceKm
        : WorkoutFormatters.kmToMi(distanceKm);
    final distanceUnit = WorkoutFormatters.distanceUnitLabel(
      useMetric: useMetricUnits,
    ).toUpperCase();

    final String paceOrSpeedValue;
    final String paceOrSpeedUnit;
    final String paceOrSpeedLabel;
    if (isCycling) {
      paceOrSpeedLabel = isVi ? 'Tốc độ' : 'Speed';
      final effectiveSpeed = useMetricUnits ? speedKmh : speedKmh * 0.621371;
      paceOrSpeedValue = effectiveSpeed.toStringAsFixed(1);
      paceOrSpeedUnit = useMetricUnits ? 'km/h' : 'mph';
    } else {
      paceOrSpeedLabel = isVi ? 'Pace' : 'Pace';
      paceOrSpeedValue = WorkoutFormatters.formatPaceFromSpeedKmh(
        speedKmh,
        useMetric: useMetricUnits,
      );
      paceOrSpeedUnit = '';
    }

    final durationFormatted =
        WorkoutFormatters.formatElapsedClock(durationSeconds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final distanceLabel = isNarrow
            ? (isVi ? 'CỰ LY' : 'DIST')
            : (isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE');
        final timeLabel = isNarrow
            ? (isVi ? 'GIỜ' : 'TIME')
            : (isVi ? 'THỜI GIAN' : 'TIME');
        final caloriesLabel = isNarrow
            ? (isVi ? 'CAL' : 'CAL')
            : (isVi ? 'CALO' : 'CALORIES');

        return Material(
          color: Colors.transparent,
          child: Tooltip(
            message: isVi
                ? 'Chạm để mở rộng số liệu lớn'
                : 'Tap to view large metrics',
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onExpand?.call();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface1.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.borderSubtle.withValues(alpha: 0.75),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 1. Quãng đường (Distance Hero)
                    Expanded(
                      flex: 12,
                      child: _MiniMetricColumn(
                        label: distanceLabel,
                        value: displayDistance.toStringAsFixed(2),
                        unit: distanceUnit,
                        valueColor: colors.textPrimary,
                        highlightUnit: true,
                      ),
                    ),
                    _buildDivider(colors),
                    // 2. Thời gian (Time Clock)
                    Expanded(
                      flex: 11,
                      child: _MiniMetricColumn(
                        label: timeLabel,
                        value: durationFormatted,
                        unit: '',
                        valueColor: colors.textPrimary,
                      ),
                    ),
                    _buildDivider(colors),
                    // 3. Pace / Tốc độ
                    Expanded(
                      flex: 10,
                      child: _MiniMetricColumn(
                        label: paceOrSpeedLabel.toUpperCase(),
                        value: paceOrSpeedValue,
                        unit: paceOrSpeedUnit,
                        valueColor: colors.textPrimary,
                      ),
                    ),
                    _buildDivider(colors),
                    // 4. Calo
                    Expanded(
                      flex: 9,
                      child: _MiniMetricColumn(
                        label: caloriesLabel,
                        value: '$calories',
                        unit: 'kcal',
                        valueColor: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(KineticColors colors) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: colors.borderSubtle.withValues(alpha: 0.4),
    );
  }
}

class _MiniMetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  final bool highlightUnit;

  const _MiniMetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    this.highlightUnit = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KineticTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textSecondary.withValues(alpha: 0.85),
            letterSpacing: 0.4,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.metricSmall.copyWith(
                  color: valueColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlightUnit ? colors.primary : colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
