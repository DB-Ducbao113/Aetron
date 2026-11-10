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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final distanceDisplay = useMetricUnits
        ? (distanceMeters / 1000.0).toStringAsFixed(2)
        : (distanceMeters / 1609.34).toStringAsFixed(2);
    final distanceUnit = useMetricUnits ? 'KM' : 'MI';

    final durationDisplay = WorkoutFormatters.formatElapsedClock(durationSeconds);
    final isCycling = activityType.toLowerCase() == 'cycling';
    final paceOrSpeedLabel = isCycling ? (isVi ? 'TỐC ĐỘ' : 'SPEED') : 'PACE';
    final paceOrSpeedValue = isCycling
        ? speedKmh.toStringAsFixed(1)
        : (speedKmh > 0.1
            ? WorkoutFormatters.formatPaceFromSpeedKmh(
                speedKmh,
                useMetric: useMetricUnits,
              ).replaceAll('/km', '').replaceAll('/mi', '')
            : '--');
    final paceOrSpeedUnit = isCycling ? (useMetricUnits ? 'km/h' : 'mph') : (useMetricUnits ? '/km' : '/mi');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusXXL),
        border: Border.all(
          color: colors.tertiary.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: KineticTokens.shadowPanel(Colors.black),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Grab Handle
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Hero Warning / Stop Badge
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.tertiary.withValues(alpha: 0.14),
                  border: Border.all(
                    color: colors.tertiary.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: BladeIcon(
                  BladeIconName.flag,
                  size: 34,
                  color: colors.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isVi ? 'BẠN CÓ CHẮC CHẮN MUỐN DỪNG?' : 'FINISH THIS WORKOUT?',
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
                      label: isVi ? 'QUÃNG ĐƯỜNG' : 'DISTANCE',
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
                      label: isVi ? 'THỜI GIAN' : 'DURATION',
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

            // Primary Action: STOP & SAVE WORKOUT (Prominent, High-Contrast)
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                color: colors.tertiary,
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).pop(true);
                },
                icon: BladeIcon(
                  BladeIconName.flag,
                  color: Colors.white,
                  size: 24,
                ),
                label: Text(
                  isVi ? 'KẾT THÚC & LƯU BÀI TẬP' : 'FINISH & SAVE SESSION',
                  style: KineticTypography.unitLabel.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(KineticTokens.radiusLG),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Action: CONTINUE WORKOUT (Dismiss sheet & continue)
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(false);
                },
                icon: BladeIcon(
                  BladeIconName.play,
                  color: colors.primary,
                  size: 22,
                ),
                label: Text(
                  isVi ? 'TIẾP TỤC TẬP LUYỆN' : 'CONTINUE WORKOUT',
                  style: KineticTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  backgroundColor: colors.surface2,
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(KineticTokens.radiusLG),
                  ),
                ),
              ),
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
