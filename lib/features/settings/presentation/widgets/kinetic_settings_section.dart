import 'package:flutter/cupertino.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
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

    final groupContent = Column(
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
    );

    final Widget sectionCard = KineticCard(
      useLiquidGlass: true,
      borderRadius: 21,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: groupContent,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: KineticTokens.spaceXS,
            bottom: KineticTokens.spaceSM,
          ),
          child: Text(
            title,
            style: KineticTypography.sectionEyebrow.copyWith(
              color: colors.textMuted,
            ),
          ),
        ),
        sectionCard,
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
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
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
        splashColor: isIOS ? Colors.transparent : null,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveColor.withValues(alpha: isIOS ? 0.16 : 0.14),
            border: Border.all(
              color: isIOS
                  ? effectiveColor.withValues(alpha: 0.35)
                  : effectiveColor.withValues(alpha: 0.20),
              width: 1.0,
            ),
          ),
          child: Center(
            child: bladeIcon != null
                ? BladeIcon(
                    bladeIcon!,
                    size: 17,
                    color: effectiveColor,
                    strokeWidth: 1.7,
                  )
                : Icon(icon, color: effectiveColor, size: 16),
          ),
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
        trailing:
            isIOS &&
                trailing is Icon &&
                (trailing as Icon).icon == Icons.chevron_right_rounded
            ? Icon(
                CupertinoIcons.chevron_forward,
                size: (trailing as Icon).size,
                color: (trailing as Icon).color ?? colors.textMuted,
              )
            : trailing,
      ),
    );
  }
}
