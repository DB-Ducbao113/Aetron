import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/material.dart';

/// Shared Glassline V3 scaffold body wrapper used across all primary scrolling tabs.
///
/// Renders the atmospheric radial backdrop, a top-safe scrolling surface that
/// extends behind the floating bottom dock, and a responsive bottom diffusion scrim.
class KineticGlasslineScaffoldBody extends StatelessWidget {
  final Widget child;
  final bool showBottomScrim;

  const KineticGlasslineScaffoldBody({
    super.key,
    required this.child,
    this.showBottomScrim = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: KineticGlasslineBackdrop(isDark: colors.isDark),
          ),
        ),
        SafeArea(
          top: true,
          bottom: false,
          child: child,
        ),
        if (showBottomScrim)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: KineticBottomDiffusionScrim(),
          ),
      ],
    );
  }
}

/// Atmospheric Glassline V3 radial glow backdrop shared across Light & Dark themes.
class KineticGlasslineBackdrop extends StatelessWidget {
  final bool isDark;

  const KineticGlasslineBackdrop({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlasslineBackdropPainter(isDark: isDark),
      child: const SizedBox.expand(),
    );
  }
}

/// Bottom diffusion scrim fading scrolled content smoothly behind the lowered dock.
class KineticBottomDiffusionScrim extends StatelessWidget {
  const KineticBottomDiffusionScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final height = AetronBottomBar.bottomFootprintOf(context) + 14.0;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                colors.background.withValues(alpha: 0.72),
                colors.background,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlasslineBackdropPainter extends CustomPainter {
  final bool isDark;

  const _GlasslineBackdropPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (isDark) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.2, -1.0),
            end: Alignment(0.2, 1.0),
            colors: [
              Color(0xFF111D2C),
              Color(0xFF0C1522),
              Color(0xFF0B1420),
            ],
            stops: [0.0, 0.63, 1.0],
          ).createShader(rect),
      );
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * 1.05, size.height * 0.03),
        rx: size.width * 0.91,
        ry: size.height * 0.29,
        color: const Color(0x303983DB),
      );
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * -0.22, size.height * 0.62),
        rx: size.width * 0.78,
        ry: size.height * 0.34,
        color: const Color(0x24276FC7),
      );
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * 1.10, size.height * 1.06),
        rx: size.width * 0.82,
        ry: size.height * 0.36,
        color: const Color(0x1A396FC1),
      );
    } else {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFEEF2F8));
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * 1.05, size.height * 0.05),
        rx: size.width * 0.95,
        ry: size.height * 0.27,
        color: const Color(0x245BA9F8),
      );
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * -0.18, size.height * 0.65),
        rx: size.width * 0.94,
        ry: size.height * 0.34,
        color: const Color(0x2166B7FF),
      );
      _drawEllipticalGlow(
        canvas,
        center: Offset(size.width * 1.12, size.height * 1.06),
        rx: size.width * 0.86,
        ry: size.height * 0.40,
        color: const Color(0x17AEA0F7),
      );
    }
  }

  void _drawEllipticalGlow(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required Color color,
  }) {
    if (rx <= 0 || ry <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, ry / rx);
    final circleRect = Rect.fromCircle(center: Offset.zero, radius: rx);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 0.78],
        ).createShader(circleRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlasslineBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
