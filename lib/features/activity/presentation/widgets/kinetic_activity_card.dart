import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActivityOptionItem {
  final String type;
  final String nameVi;
  final String nameEn;
  final String? tagVi;
  final String? tagEn;
  final String imagePath;
  final IconData icon;
  final Color accentColor;
  final bool requireGps;

  const ActivityOptionItem({
    required this.type,
    required this.nameVi,
    required this.nameEn,
    this.tagVi,
    this.tagEn,
    required this.imagePath,
    required this.icon,
    required this.accentColor,
    required this.requireGps,
  });
}

class KineticActivityCard extends StatelessWidget {
  final ActivityOptionItem option;
  final bool isSelected;
  final List<WorkoutSession> workouts;
  final bool isVi;
  final VoidCallback onSelect;

  const KineticActivityCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.workouts,
    required this.isVi,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final activityWorkouts = workouts
        .where((w) => w.activityType.toLowerCase() == option.type.toLowerCase())
        .toList();

    // Compute real athlete statistics for this activity (only for valid sessions >= 0.1km)
    String? statLeft;
    String? statRight;

    final validWorkouts = activityWorkouts.where((w) => w.distanceKm >= 0.1).toList();

    if (validWorkouts.isNotEmpty) {
      final totalDist = validWorkouts.fold<double>(
        0.0,
        (sum, w) => sum + w.distanceKm,
      );
      final avgDist = totalDist / validWorkouts.length;
      final totalSec = validWorkouts.fold<int>(
        0,
        (sum, w) => sum + w.durationSec,
      );
      final avgSec = (totalSec / validWorkouts.length).round();

      if (avgDist >= 0.1) {
        statLeft = '${avgDist.toStringAsFixed(1)} ${isVi ? 'km / buổi' : 'km / session'}';
        if (option.type == 'cycling') {
          final totalSpeed = validWorkouts.fold<double>(
            0.0,
            (sum, w) => sum + w.avgSpeedKmh,
          );
          final avgSpeed = totalSpeed / validWorkouts.length;
          if (avgSpeed > 0) {
            statRight = 'TB ${avgSpeed.toStringAsFixed(1)} km/h';
          }
        } else {
          if (avgSec > 0 && avgDist > 0) {
            statRight = 'Pace ${WorkoutFormatters.formatPaceFromDistanceAndDuration(distanceKm: avgDist, durationSec: avgSec)}';
          }
        }
      }
    }

    final name = isVi ? option.nameVi : option.nameEn;

    // V4 scene identity per sport: running → secondary, walking/cycling →
    // tertiary. The scene is decoration (background); selection is signaled
    // by border + check badge only.
    final Color sceneTint;
    switch (option.type.toLowerCase()) {
      case 'running':
        sceneTint = colors.secondary;
        break;
      default:
        sceneTint = colors.tertiary;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: name,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect();
        },
        child: AnimatedContainer(
          duration: KineticTokens.motionTab,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.borderSubtle.withValues(alpha: 0.6),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: ClipRRect(
            // 1px less than card radius to sit inside the 1px border
            borderRadius: BorderRadius.circular(KineticTokens.radiusXL - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main duotone scene body (V4: rich background, clean front)
                SizedBox(
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Duotone scene backdrop in the sport's tint
                      SceneBackdrop(tint: sceneTint),

                      // Legibility scrim for the title
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KineticGradients.scrimBottom(colors),
                        ),
                      ),

                      // Sport glyph as part of the scene, bottom-right
                      Positioned(
                        right: 14,
                        bottom: 10,
                        child: Icon(
                          option.icon,
                          size: 56,
                          color: sceneTint.withValues(alpha: 0.4),
                        ),
                      ),

                      // Check badge — the only selection marker besides the
                      // primary border
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),

                      // Bottom Content: Title
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Text(
                          name,
                          style: KineticTypography.cardTitle.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Telemetry Specification Strip at Bottom (rendered only when stats exist)
                if (statLeft != null && statRight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      border: Border(
                        top: BorderSide(
                          color: colors.borderSubtle.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          statLeft,
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          statRight,
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
