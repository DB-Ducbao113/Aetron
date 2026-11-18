import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData? icon;
  final Color? accentColor;
  final bool compact;

  /// V4: render the value at metricMega — the single biggest number on
  /// screen (live record distance, summary headline).
  final bool hero;
  final String? semanticLabel;

  const KineticMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.icon,
    this.accentColor,
    this.compact = false,
    this.hero = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final accent = accentColor ?? colors.primary;

    return Semantics(
      label: semanticLabel ?? '$label: $value $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 5),
              ],
              Text(
                label.toUpperCase(),
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textMuted,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: hero
                        ? KineticTypography.metricMega.copyWith(
                            color: colors.textPrimary,
                          )
                        : compact
                            ? KineticTypography.metricMedium.copyWith(
                                color: colors.textPrimary,
                              )
                            : KineticTypography.metricHero.copyWith(
                                color: colors.textPrimary,
                              ),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit.toUpperCase(),
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textMuted,
                    fontSize: compact ? 10 : 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
