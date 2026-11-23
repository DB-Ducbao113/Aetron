import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';

class KineticChip extends StatefulWidget {
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
  State<KineticChip> createState() => _KineticChipState();
}

class _KineticChipState extends State<KineticChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isSelected = widget.isSelected;
    final label = widget.label;
    final icon = widget.icon;
    final onTap = widget.onTap;
    final semanticLabel = widget.semanticLabel;

    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final bg = isSelected
        ? (ios ? colors.primaryTint : colors.accentFill)
        : colors.surface1;
    final borderColor = isSelected ? colors.primary : colors.borderSubtle;
    final textColor = isSelected
        ? (ios ? colors.primary : Colors.white)
        : colors.textSecondary;

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
              onHighlightChanged: ios && onTap != null
                  ? (value) => setState(() => _pressed = value)
                  : null,
              splashFactory: ios ? NoSplash.splashFactory : null,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: KineticSurfaceFinish(
                radius: KineticTokens.radiusPill,
                pressed: _pressed && onTap != null,
                emphasis: isSelected,
                scaleOnPress: true,
                child: AnimatedContainer(
                  duration: KineticTokens.respectingReduceMotion(
                    context,
                    KineticTokens.motionTab,
                  ),
                  curve: KineticTokens.animCurve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(
                      KineticTokens.radiusPill,
                    ),
                    border: isSelected && !ios
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
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
      ),
    );
  }
}
