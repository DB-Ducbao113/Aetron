import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_gradients.dart';
import 'package:flutter/material.dart';

/// TopographicBackdrop — V4 (2026-11-08).
///
/// The signature rich background of the redesign: a hero mesh gradient with
/// hand-tuned topographic contour lines flowing over it (the Strava-map
/// feel), fading out toward the bottom. Decoration lives here, in the
/// background — foreground content stays clean.
///
/// Usage: place as the bottom layer of a Stack inside a hero zone.
/// ```dart
/// Stack(children: [ Positioned.fill(child: TopographicBackdrop()), content ])
/// ```
class TopographicBackdrop extends StatelessWidget {
  final double contourOpacity;

  const TopographicBackdrop({super.key, this.contourOpacity = 0.16});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: KineticGradients.heroMesh(colors)),
      child: CustomPaint(
        painter: _ContourPainter(
          color: colors.primary.withValues(alpha: contourOpacity),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ContourPainter extends CustomPainter {
  final Color color;

  const _ContourPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Six flowing contour bands, each a smooth cubic wave. The vertical
    // rhythm (34px) and phase offsets are fixed so every hero zone in the
    // app shares the same "map".
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 6; i++) {
      final y = 30.0 + i * 34.0;
      if (y > h + 40) break;
      final path = Path()
        ..moveTo(-20, y)
        ..cubicTo(
          w * 0.22, y - 34,
          w * 0.44, y + 36,
          w * 0.68, y - 6,
        )
        ..cubicTo(
          w * 0.84, y - 28,
          w * 0.94, y + 12,
          w + 20, y - 10,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// SceneBackdrop — duotone background for sport/feature cards: a tinted
/// wash plus two contour strokes anchored bottom-right. [tint] is the
/// scene's identity color (e.g. secondary for running scenes).
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
      child: CustomPaint(
        painter: _ContourPainter(
          color: tint.withValues(alpha: 0.30),
        ),
        size: Size.infinite,
      ),
    );
  }
}
