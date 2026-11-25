import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the premium Cyber-Kinetic Workout Stop Confirmation Sheet
Future<bool?> showKineticWorkoutStopConfirmation(
  BuildContext context, {
  required double distanceMeters,
  required int durationSeconds,
  required int caloriesBurned,
  required double speedKmh,
  required String activityType,
  required bool useMetricUnits,
  required bool isVi,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => KineticWorkoutStopSheet(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned,
      speedKmh: speedKmh,
      activityType: activityType,
      useMetricUnits: useMetricUnits,
      isVi: isVi,
    ),
  );
}

class KineticWorkoutStopSheet extends StatelessWidget {
  final double distanceMeters;
  final int durationSeconds;
  final int caloriesBurned;
  final double speedKmh;
  final String activityType;
  final bool useMetricUnits;
  final bool isVi;

  const KineticWorkoutStopSheet({
    super.key,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.speedKmh,
    required this.activityType,
    required this.useMetricUnits,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final distanceDisplay = useMetricUnits
        ? (distanceMeters / 1000.0).toStringAsFixed(2)
        : (distanceMeters / 1609.34).toStringAsFixed(2);
    final distanceUnit = useMetricUnits ? 'KM' : 'MI';

    final durationDisplay = WorkoutFormatters.formatElapsedClock(
      durationSeconds,
    );
    final isCycling = activityType.toLowerCase() == 'cycling';
    final paceOrSpeedLabel = isCycling
        ? (isVi ? 'Tốc độ' : 'Speed')
        : (isVi ? 'Nhịp độ' : 'Pace');
    final paceOrSpeedValue = isCycling
        ? speedKmh.toStringAsFixed(1)
        : (speedKmh > 0.1
              ? WorkoutFormatters.formatPaceFromSpeedKmh(
                  speedKmh,
                  useMetric: useMetricUnits,
                ).replaceAll('/km', '').replaceAll('/mi', '')
              : '--');
    final paceOrSpeedUnit = isCycling
        ? (useMetricUnits ? 'km/h' : 'mph')
        : (useMetricUnits ? '/km' : '/mi');

    return KineticGlassBottomSheet(
      floating: true,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Warning / Stop Badge
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryTint,
                ),
                child: BladeIcon(
                  BladeIconName.flag,
                  size: 32,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isVi ? 'Bạn có chắc chắn muốn dừng?' : 'Finish this workout?',
              textAlign: TextAlign.center,
              style: KineticTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              isVi
                  ? 'Quãng đường và thông số bài tập sẽ được lưu vào lịch sử hoạt động.'
                  : 'Your workout metrics and route will be saved to your history.',
              textAlign: TextAlign.center,
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Quick Telemetry Snapshot Bento
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                border: Border.all(
                  color: colors.borderSubtle.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  // Distance
                  Expanded(
                    child: _MiniMetricItem(
                      label: isVi ? 'Quãng đường' : 'Distance',
                      value: distanceDisplay,
                      unit: distanceUnit,
                      colors: colors,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: colors.borderSubtle.withValues(alpha: 0.6),
                  ),
                  // Time
                  Expanded(
                    child: _MiniMetricItem(
                      label: isVi ? 'Thời gian' : 'Duration',
                      value: durationDisplay,
                      unit: '',
                      colors: colors,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: colors.borderSubtle.withValues(alpha: 0.6),
                  ),
                  // Pace or Speed / Calories
                  Expanded(
                    child: _MiniMetricItem(
                      label: paceOrSpeedLabel,
                      value: paceOrSpeedValue,
                      unit: paceOrSpeedUnit,
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Primary Action: STOP & SAVE WORKOUT
            KineticButton(
              label: isVi ? 'Kết thúc & lưu bài tập' : 'Finish & save session',
              icon: Icons.flag_rounded,
              height: KineticTokens.buttonHeightPrimary,
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 10),

            // Secondary Action: CONTINUE WORKOUT (Dismiss sheet & continue)
            KineticButton(
              label: isVi ? 'Tiếp tục tập luyện' : 'Continue workout',
              icon: Icons.play_arrow_rounded,
              variant: KineticButtonVariant.secondary,
              height: KineticTokens.buttonHeight,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final KineticColors colors;

  const _MiniMetricItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: KineticTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.metricSmall.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
