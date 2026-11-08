import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';

/// Interactive Timeline Roadmap for Structured Running Programs (V4: flat).
class ProgramInteractiveTimeline extends StatelessWidget {
  final StructuredRunningProgram program;
  final AppLanguage currentLang;

  const ProgramInteractiveTimeline({
    super.key,
    required this.program,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final steps = program.steps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStepNode(
            step: steps[i],
            index: i + 1,
            totalSteps: steps.length,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isVi: isVi,
          ),
      ],
    );
  }
}

class _TimelineStepNode extends StatelessWidget {
  final ProgramStep step;
  final int index;
  final int totalSteps;
  final bool isFirst;
  final bool isLast;
  final bool isVi;

  const _TimelineStepNode({
    required this.step,
    required this.index,
    required this.totalSteps,
    required this.isFirst,
    required this.isLast,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final color = step.phaseColor;
    final title = isVi ? step.titleVi : step.titleEn;
    final tip = isVi ? step.tipVi : step.tipEn;
    final durStr = WorkoutFormatters.formatDurationFromSeconds(step.durationSeconds);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Node Icon + Flat Hairline Track
          Column(
            children: [
              // Node Orb (V4: flat — no glow)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Icon(
                    step.phaseIcon,
                    color: color,
                    size: 15,
                  ),
                ),
              ),
              // Connecting Line — flat hairline track
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: colors.borderSubtle,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Right Column: Step Info Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                border: Border.all(
                  color: colors.borderSubtle,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Header: Name & Duration Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: KineticTypography.label.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          durStr,
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Metrics Badges: Pace & HR Zone
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _StepPill(
                        icon: Icons.speed_rounded,
                        label: 'Pace: ${step.targetPaceDisplay}',
                        color: color,
                      ),
                      _StepPill(
                        icon: Icons.favorite_rounded,
                        label: step.targetHrZone,
                        color: colors.primary,
                      ),
                    ],
                  ),

                  // Coaching Form Tip
                  if (tip.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 13,
                          color: colors.tertiary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            tip,
                            style: KineticTypography.caption.copyWith(
                              color: colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StepPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KineticTypography.unitLabel.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
