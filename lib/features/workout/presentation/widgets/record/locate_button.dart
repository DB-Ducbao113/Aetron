import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
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

    return KineticGlassIconButton(
      label: isVi ? 'Định vị vị trí của tôi' : 'Center on my location',
      onPressed: onPressed,
      size: 37,
      visualSize: 37,
      active: isFollowEnabled,
      blurBackdrop: true,
      icon: BladeIcon(
        BladeIconName.gps,
        color: isFollowEnabled ? activeColor : colors.textSecondary,
        size: 18,
        strokeWidth: 1.7,
      ),
    );
  }
}
