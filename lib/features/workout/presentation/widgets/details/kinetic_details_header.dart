import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticDetailsHeader extends StatelessWidget {
  final WorkoutSession workout;
  final String? dateLabel;
  final AppLanguage currentLang;

  const KineticDetailsHeader({
    super.key,
    required this.workout,
    this.dateLabel,
    required this.currentLang,
  });

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _activityColor(String type, KineticColors colors) {
    switch (type.toLowerCase()) {
      case 'running':
        return colors.primary;
      case 'cycling':
        return colors.tertiary;
      case 'walking':
        return colors.secondary;
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final sportColor = _activityColor(workout.activityType, colors);
    final flag = workout.gpsAnalysis.validityFlag;

    final (badgeColor, badgeText) = switch (flag) {
      WorkoutValidityFlag.verified => (
        colors.primary,
        currentLang == AppLanguage.vi ? 'HỢP LỆ' : 'VERIFIED',
      ),
      WorkoutValidityFlag.partial => (
        colors.tertiary,
        currentLang == AppLanguage.vi ? 'CẢNH BÁO' : 'WARNING',
      ),
      WorkoutValidityFlag.unverified => (
        colors.error,
        currentLang == AppLanguage.vi ? 'KHÔNG HỢP LỆ' : 'FLAGGED',
      ),
    };

    final flagReason = workout.gpsAnalysis.flaggedSegments.isNotEmpty
        ? workout.gpsAnalysis.flaggedSegments.first.reason
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Sport Orb
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: sportColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                border: Border.all(
                  color: sportColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(
                _activityIcon(workout.activityType),
                color: sportColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Sport Title and Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    WorkoutFormatters.formatActivityType(
                      workout.activityType,
                      currentLang,
                    ).toUpperCase(),
                    style: KineticTypography.headlineMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (dateLabel != null && dateLabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLabel!,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // GPS Validity Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    flag == WorkoutValidityFlag.verified
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    size: 13,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    badgeText,
                    style: KineticTypography.unitLabel.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Suspicious activity reason banner if any
        if (flag != WorkoutValidityFlag.verified && flagReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    flagReason,
                    style: KineticTypography.caption.copyWith(
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
