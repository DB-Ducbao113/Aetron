import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_gradients.dart';
import 'package:flutter/material.dart';

/// Clean atmospheric header backdrop without distracting line-art wave clutter.
class TopographicBackdrop extends StatelessWidget {
  final double contourOpacity;

  const TopographicBackdrop({super.key, this.contourOpacity = 0.08});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KineticGradients.heroMesh(colors),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Clean scene wash backdrop for cards with photo fallback.
class SceneBackdrop extends StatelessWidget {
  final Color tint;

  const SceneBackdrop({super.key, required this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KineticGradients.sceneWash(colors, tint),
      ),
      child: const SizedBox.expand(),
    );
  }
}
