import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AetronSpacing.md),
    this.margin,
    this.radius = AetronRadius.large,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.hasGlow = false,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hasGlow;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AetronColors.borderSubtle;
    final effectiveBg =
        backgroundColor ?? AetronColors.panel.withValues(alpha: 0.95);

    final cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          if (hasGlow)
            BoxShadow(
              color: (glowColor ?? AetronColors.cyan).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -2,
            ),
        ],
      ),
      child: child,
    );

    final finished = KineticSurfaceFinish(
      radius: radius,
      contentSurface: true,
      child: cardContent,
    );
    if (onTap == null) return finished;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: finished,
      ),
    );
  }
}
