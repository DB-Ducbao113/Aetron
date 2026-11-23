import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';

/// Paint-only optical finish for Flutter controls. UIKit's native glass is
/// reserved for its existing native control views. This does not sample the
/// backdrop or claim to implement Apple's refraction algorithm.
class KineticSurfaceFinish extends StatefulWidget {
  const KineticSurfaceFinish({
    super.key,
    required this.child,
    required this.radius,
    this.pressed = false,
    this.emphasis = false,
    this.contentSurface = false,
    this.scaleOnPress = false,
  });

  final Widget child;
  final double radius;
  final bool pressed;
  final bool emphasis;
  final bool contentSurface;
  final bool scaleOnPress;

  @override
  State<KineticSurfaceFinish> createState() => _KineticSurfaceFinishState();

  /// Material buttons retain their own shapes, state resolution, hit areas and
  /// keyboard behavior; this layer adds only the optical finish.
  static Widget materialLayer(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child, {
    bool emphasis = false,
    double radius = 999,
  }) {
    final content = child ?? const SizedBox.shrink();
    if (states.contains(WidgetState.disabled)) return content;
    return KineticSurfaceFinish(
      radius: radius,
      pressed: states.contains(WidgetState.pressed),
      emphasis: emphasis,
      child: content,
    );
  }
}

class _KineticSurfaceFinishState extends State<KineticSurfaceFinish> {
  Alignment _touch = Alignment.topLeft;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final radius = widget.radius;
    final pressed = widget.pressed;
    final emphasis = widget.emphasis;
    final contentSurface = widget.contentSurface;
    final scaleOnPress = widget.scaleOnPress;
    if (Theme.of(context).platform != TargetPlatform.iOS ||
        MediaQuery.highContrastOf(context)) {
      return child;
    }
    final colors = context.kinetic;
    final reduceMotion = KineticTokens.reduceMotionOf(context);
    // No size, padding, semantics, or gesture changes; painter has no hit box.
    if (contentSurface && !scaleOnPress) {
      return CustomPaint(
        foregroundPainter: _OpticalEdge(
          radius: radius,
          dark: colors.isDark,
          press: 0,
          emphasis: emphasis,
          contentSurface: true,
          touch: _touch,
        ),
        child: child,
      );
    }
    return Listener(
      onPointerDown: (event) {
        final size = context.size;
        if (size == null || size.isEmpty || reduceMotion) return;
        setState(() {
          _touch = Alignment(
            (event.localPosition.dx / size.width * 2 - 1)
                .clamp(-1, 1)
                .toDouble(),
            (event.localPosition.dy / size.height * 2 - 1)
                .clamp(-1, 1)
                .toDouble(),
          );
        });
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: pressed ? 1.0 : 0.0),
        duration: reduceMotion
            ? Duration.zero
            : Duration(milliseconds: pressed ? 90 : 210),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, value, child) {
          final surface = CustomPaint(
            foregroundPainter: _OpticalEdge(
              radius: radius,
              dark: colors.isDark,
              press: value,
              emphasis: emphasis,
              contentSurface: contentSurface,
              touch: _touch,
            ),
            child: child,
          );
          if (!scaleOnPress || reduceMotion) return surface;
          return Transform.scale(
            scale: 1 - value * .018,
            transformHitTests: false,
            child: surface,
          );
        },
      ),
    );
  }
}

class _OpticalEdge extends CustomPainter {
  const _OpticalEdge({
    required this.radius,
    required this.dark,
    required this.press,
    required this.emphasis,
    required this.contentSurface,
    required this.touch,
  });

  final double radius;
  final bool dark;
  final double press;
  final Alignment touch;
  final bool emphasis;
  final bool contentSurface;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 3 || size.height < 3) return;
    final rect = (Offset.zero & size).deflate(.65);
    final r = radius.clamp(0.0, rect.shortestSide / 2).toDouble();
    final outline = RRect.fromRectAndRadius(rect, Radius.circular(r));
    // Specular rim: graded from a bright upper edge to a quiet lower contour.
    // A second inset reflection establishes thickness without blur/saveLayer.
    if (contentSurface) {
      // Glassline V3 Conic Fresnel Rim (220deg start) + subtle top-left specular sheen.
      final conicColors = dark
          ? [
              const Color(0xFFBFE2FF).withValues(alpha: 0.54),
              Colors.white.withValues(alpha: 0.04),
              const Color(0xFF4DA1F5).withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.06),
              const Color(0xFF60AFFD).withValues(alpha: 0.14),
              const Color(0xFFBFE2FF).withValues(alpha: 0.54),
              const Color(0xFFBFE2FF).withValues(alpha: 0.54),
            ]
          : [
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.05),
              const Color(0xFF5EACFD).withValues(alpha: 0.46),
              Colors.white.withValues(alpha: 0.08),
              const Color(0xFF60AFFD).withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.92),
            ];
      canvas.drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..shader = SweepGradient(
            startAngle: 0.0,
            endAngle: math.pi * 2,
            transform: const GradientRotation(3.84),
            colors: conicColors,
            stops: const [0.0, 0.17, 0.35, 0.53, 0.72, 0.92, 1.0],
          ).createShader(rect),
      );

      canvas.save();
      canvas.clipRRect(outline);
      canvas.drawRRect(
        outline,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: dark ? 0.14 : 0.22),
              Colors.transparent,
            ],
            stops: const [0.0, 0.34],
          ).createShader(rect),
      );
      final topInner = rect.deflate(0.9);
      if (!topInner.isEmpty) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            topInner,
            Radius.circular((r - 0.9).clamp(0.0, r).toDouble()),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: dark ? 0.26 : 0.45),
                Colors.transparent,
              ],
              stops: const [0.0, 0.28],
            ).createShader(topInner),
        );
      }
      canvas.restore();

      if (press > .001) {
        canvas.drawRRect(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..shader = RadialGradient(
              center: touch,
              radius: .72,
              colors: [
                Colors.white.withValues(alpha: press * (dark ? .55 : .72)),
                Colors.transparent,
              ],
            ).createShader(rect),
        );
      }
      return;
    }

    final strength = 1.0;
    final topAlpha =
        (dark
            ? .28
            : emphasis
            ? .50
            : .84) *
        strength;
    final bottomAlpha = (dark ? .04 : .065) * strength;
    final light = Colors.white.withValues(alpha: topAlpha);
    final shade = Colors.black.withValues(alpha: bottomAlpha);
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            light,
            light.withValues(alpha: topAlpha * .25),
            shade,
          ],
          stops: const [0, .44, 1],
        ).createShader(rect),
    );
    if (press > .001) {
      canvas.drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = RadialGradient(
            center: touch,
            radius: .72,
            colors: [
              Colors.white.withValues(alpha: press * (dark ? .55 : .72)),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }
    final inner = rect.deflate(1.2);
    if (inner.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        inner,
        Radius.circular((r - 1.2).clamp(0.0, r).toDouble()),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: (dark ? .09 : .17) + press * .20),
            Colors.transparent,
            Colors.white.withValues(alpha: (dark ? .05 : .25) + press * .14),
          ],
          stops: const [0, .55, 1],
        ).createShader(inner),
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _OpticalEdge old) =>
      old.radius != radius ||
      old.dark != dark ||
      old.press != press ||
      old.touch != touch ||
      old.emphasis != emphasis ||
      old.contentSurface != contentSurface;
}

/// Visual-only press tracking for existing custom controls. The original
/// GestureDetector/InkWell still owns callbacks, semantics and cancellation.
class KineticTouchFinish extends StatefulWidget {
  const KineticTouchFinish({
    super.key,
    required this.child,
    required this.radius,
    this.enabled = true,
    this.contentSurface = false,
    this.emphasis = false,
  });
  final Widget child;
  final double radius;
  final bool enabled;
  final bool contentSurface;
  final bool emphasis;

  @override
  State<KineticTouchFinish> createState() => _KineticTouchFinishState();
}

class _KineticTouchFinishState extends State<KineticTouchFinish> {
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _pressed = false;

  void _release(int pointer) {
    if (_pointer != pointer) return;
    _pointer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(covariant KineticTouchFinish oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pressed = false;
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS ||
        MediaQuery.highContrastOf(context)) {
      return widget.child;
    }
    return Listener(
      onPointerDown: (event) {
        if (!widget.enabled || _pointer != null) return;
        _pointer = event.pointer;
        _origin = event.position;
        setState(() => _pressed = true);
      },
      onPointerMove: (event) {
        if ((event.position - _origin).distance > 14) _release(event.pointer);
      },
      onPointerCancel: (event) => _release(event.pointer),
      onPointerUp: (event) => _release(event.pointer),
      child: KineticSurfaceFinish(
        radius: widget.radius,
        pressed: widget.enabled && _pressed,
        emphasis: widget.emphasis,
        contentSurface: widget.contentSurface,
        scaleOnPress: widget.enabled,
        child: widget.child,
      ),
    );
  }
}
