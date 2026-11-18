import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class LocateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isFollowEnabled;
  final bool isVi;

  const LocateButton({
    super.key,
    required this.onPressed,
    required this.isFollowEnabled,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final activeColor = colors.primary;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: isVi ? 'Định vị vị trí của tôi' : 'Center on my location',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface1.withValues(alpha: 0.94),
              border: Border.all(
                color: isFollowEnabled
                    ? activeColor
                    : colors.borderSubtle.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: BladeIcon(
                BladeIconName.gps,
                color: isFollowEnabled ? activeColor : colors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
