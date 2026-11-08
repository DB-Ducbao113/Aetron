import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

/// Live Target Progress HUD banner on RecordScreen during workouts.
class WorkoutTargetProgressHud extends StatelessWidget {
  final WorkoutTarget target;
  final double distanceMeters;
  final int durationSeconds;
  final int calories;
  final AppLanguage currentLang;
  final Color accentColor;

  const WorkoutTargetProgressHud({
    super.key,
    required this.target,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.calories,
    required this.currentLang,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (target.type == WorkoutTargetType.none || target.value <= 0) {
      return const SizedBox.shrink();
    }

    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    double progress = 0.0;
    String targetLabel = '';
    String remainingLabel = '';

    switch (target.type) {
      case WorkoutTargetType.distance:
        final currentKm = distanceMeters / 1000.0;
        progress = (currentKm / target.value).clamp(0.0, 1.0);
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toStringAsFixed(1)} km'
            : 'Target: ${target.value.toStringAsFixed(1)} km';
        final remainingKm = (target.value - currentKm).clamp(0.0, target.value);
        remainingLabel = isVi
            ? (remainingKm <= 0 ? 'Đã hoàn thành! 🎉' : 'Còn ${remainingKm.toStringAsFixed(1)} km')
            : (remainingKm <= 0 ? 'Completed! 🎉' : '${remainingKm.toStringAsFixed(1)} km left');
        break;

      case WorkoutTargetType.duration:
        final targetSec = (target.value * 60).round();
        progress = (durationSeconds / targetSec).clamp(0.0, 1.0);
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toInt()} phút'
            : 'Target: ${target.value.toInt()} mins';
        final remainingSec = (targetSec - durationSeconds).clamp(0, targetSec);
        final remMins = (remainingSec / 60).ceil();
        remainingLabel = isVi
            ? (remainingSec <= 0 ? 'Đã hoàn thành! 🎉' : 'Còn $remMins phút')
            : (remainingSec <= 0 ? 'Completed! 🎉' : '$remMins mins left');
        break;

      case WorkoutTargetType.calories:
        progress = (calories / target.value).clamp(0.0, 1.0);
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toInt()} kcal'
            : 'Target: ${target.value.toInt()} kcal';
        final remKcal = (target.value - calories).clamp(0, target.value.toInt());
        remainingLabel = isVi
            ? (remKcal <= 0 ? 'Đã hoàn thành! 🎉' : 'Còn $remKcal kcal')
            : (remKcal <= 0 ? 'Completed! 🎉' : '$remKcal kcal left');
        break;

      case WorkoutTargetType.none:
        break;
    }

    final isDone = progress >= 1.0;
    final displayColor = isDone ? colors.tertiary : accentColor;
    final percentInt = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: KineticGradients.hudSurface(colors),
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: displayColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: KineticTokens.shadowPanel(Colors.black),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isDone ? Icons.military_tech_rounded : Icons.track_changes_rounded,
                    color: displayColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    targetLabel,
                    style: KineticTypography.unitLabel.copyWith(
                      fontWeight: FontWeight.w900,
                      color: displayColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    remainingLabel,
                    style: KineticTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDone ? colors.tertiary : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.18),
                      borderRadius:
                          BorderRadius.circular(KineticTokens.radiusSM),
                    ),
                    child: Text(
                      '$percentInt%',
                      style: KineticTypography.unitLabel.copyWith(
                        fontWeight: FontWeight.w900,
                        color: displayColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: colors.surface3,
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
