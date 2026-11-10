import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSettingsSectionGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const KineticSettingsSectionGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: KineticTokens.spaceXS,
            bottom: KineticTokens.spaceSM,
          ),
          child: Text(
            title.toUpperCase(),
            style: KineticTypography.sectionEyebrow.copyWith(
              color: colors.textMuted,
            ),
          ),
        ),
        Material(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: Theme.of(context).brightness == Brightness.light
                  ? [
                      // Morning identity: grouped cards lift off the paper
                      // background with a soft ambient shadow.
                      BoxShadow(
                        color: const Color(0xFF172B33).withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -8,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: KineticTokens.spaceMD + 42,
                      endIndent: KineticTokens.spaceMD,
                      color: colors.borderSubtle,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class KineticSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final Widget? trailing;
  final VoidCallback onTap;

  /// Optional Blade icon: when set, the tile renders this Aetron Blade
  /// glyph instead of [icon]. Call sites that omit it render exactly
  /// as before.
  final BladeIconName? bladeIcon;

  /// Danger-zone rows (log out, delete account): the title takes the
  /// tile's accent color so the row reads as destructive at a glance.
  final bool danger;

  const KineticSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor,
    this.trailing,
    required this.onTap,
    this.bladeIcon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveColor = accentColor ?? colors.primary;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KineticTokens.spaceMD,
          vertical: KineticTokens.spaceXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        ),
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KineticTokens.radiusSM + 2),
          ),
          child: bladeIcon != null
              ? BladeIcon(bladeIcon!, size: 17, color: effectiveColor)
              : Icon(icon, color: effectiveColor, size: 16),
        ),
        title: Text(
          title,
          style: KineticTypography.headlineSmall.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: danger ? effectiveColor : colors.textPrimary,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: KineticTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}
