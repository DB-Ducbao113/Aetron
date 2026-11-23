import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minLeadingWidth: 0,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withValues(alpha: isIOS ? 0.16 : 0.12),
            border: Border.all(
              color: colors.primary.withValues(alpha: isIOS ? 0.35 : 0.20),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              isIOS ? CupertinoIcons.chevron_forward : Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 16,
            ),
        onTap: onTap,
      ),
    );
  }
}
