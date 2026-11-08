import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? badgeText;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool isDestructive;

  const KineticProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.badgeText,
    this.iconColor,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveColor = isDestructive
        ? colors.error
        : (iconColor ?? colors.primary);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KineticTokens.spaceXS,
          vertical: KineticTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: effectiveColor),
            const SizedBox(width: KineticTokens.spaceSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: KineticTypography.bodyMedium.copyWith(
                      color: isDestructive ? colors.error : colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: KineticTypography.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceXS,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius:
                      BorderRadius.circular(KineticTokens.radiusPill),
                ),
                child: Text(
                  badgeText!,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
