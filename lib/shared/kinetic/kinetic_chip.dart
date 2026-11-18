import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const KineticChip({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final bg = isSelected ? colors.accentFill : colors.surface1;
    final borderColor = isSelected ? colors.accentFill : colors.borderSubtle;
    final textColor = isSelected ? Colors.white : colors.textSecondary;

    return Semantics(
      selected: isSelected,
      button: true,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: AnimatedContainer(
                duration: KineticTokens.motionTab,
                curve: KineticTokens.animCurve,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  border: isSelected
                      ? null
                      : Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: textColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: KineticTypography.label.copyWith(
                        color: textColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
