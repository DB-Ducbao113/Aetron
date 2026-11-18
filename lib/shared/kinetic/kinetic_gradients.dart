import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/material.dart';

/// Clean gradient helpers derived strictly from [KineticColors].
class KineticGradients {
  const KineticGradients._();

  static LinearGradient heroMesh(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.primaryTint.withValues(alpha: c.isDark ? 0.45 : 0.65),
          c.background,
        ],
        stops: const [0.0, 1.0],
      );

  static LinearGradient sceneWash(KineticColors c, Color base) =>
      LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          base.withValues(alpha: 0.22),
          c.surface2,
        ],
        stops: const [0.0, 1.0],
      );

  static LinearGradient scrimBottom(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.65),
        ],
        stops: const [0.4, 1.0],
      );

  static LinearGradient scrimTop(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.background.withValues(alpha: 0.72),
          c.background.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55],
      );

  static LinearGradient hudSurface(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.surface1.withValues(alpha: 0.96),
          c.surface1.withValues(alpha: 0.92),
        ],
      );
}
