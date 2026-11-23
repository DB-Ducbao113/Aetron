import 'dart:math' as math;
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A sculpted, tier-colored medal rendered locally with Flutter layers.
/// Locked medals retain their silhouette without implying an earned award.
class AchievementMedallion extends StatelessWidget {
  const AchievementMedallion({
    super.key,
    required this.badge,
    this.size = 80,
    this.animateEntrance = false,
  });

  final AchievementBadge badge;
  final double size;
  final bool animateEntrance;

  @override
  Widget build(BuildContext context) {
    final medal = _buildMedal(context);
    if (!animateEntrance || KineticTokens.reduceMotionOf(context)) return medal;

    return _TouchTilt(
      size: size,
      enabled: badge.isUnlocked,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        child: medal,
        builder: (context, progress, child) {
          final turn = Curves.easeOutCubic.transform(progress);
          final scale = .76 + .24 * Curves.easeOutBack.transform(progress);
          final sweep = ((progress - .23) / .64).clamp(0.0, 1.0);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .003)
              ..rotateY(-1.05 * (1 - turn))
              ..rotateX(.30 * (1 - turn)),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child!,
                  if (badge.isUnlocked && sweep > 0 && sweep < 1)
                    Positioned(
                      top: size * .035,
                      width: size * .88,
                      height: size * .88,
                      child: IgnorePointer(
                        child: ClipOval(
                          child: FractionalTranslation(
                            translation: Offset(2.4 * sweep - 1.2, 0),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1, -.45),
                                  end: Alignment(1, .45),
                                  colors: [
                                    Colors.transparent,
                                    Color(0x00FFFFFF),
                                    Color(0x88FFFFFF),
                                    Color(0x00FFFFFF),
                                    Colors.transparent,
                                  ],
                                  stops: [0, .36, .5, .64, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedal(BuildContext context) {
    final colors = context.kinetic;
    final unlocked = badge.isUnlocked;
    final metal = unlocked ? badge.tier.primaryColor : colors.textMuted;
    final dark = unlocked ? badge.tier.secondaryColor : colors.surface3;
    final rim = Color.lerp(metal, Colors.white, unlocked ? .68 : .10)!;
    final edge = Color.lerp(dark, Colors.black, .60)!;
    final face = Color.lerp(metal, dark, .52)!;
    final glint = Color.lerp(rim, Colors.white, unlocked ? .62 : .08)!;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SculptedMedalPainter(
                    metal: metal,
                    dark: dark,
                    rim: rim,
                    edge: edge,
                    face: face,
                    unlocked: unlocked,
                    tier: badge.tier,
                  ),
                ),
              ),
            ),
            Positioned(
              top: size * .035,
              width: size * .88,
              height: size * .88,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (unlocked) ...[
                      Transform.translate(
                        offset: Offset(0, size * .026),
                        child: Icon(badge.icon, size: size * .43, color: edge),
                      ),
                      Transform.translate(
                        offset: Offset(-size * .006, -size * .008),
                        child: Icon(badge.icon, size: size * .43, color: glint),
                      ),
                    ],
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [glint, rim, metal, rim, face],
                        stops: const [0, .2, .52, .76, 1],
                      ).createShader(bounds),
                      child: Icon(
                        badge.icon,
                        size: size * .43,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!unlocked)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size * .27,
                  height: size * .27,
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderStrong),
                  ),
                  child: Icon(
                    CupertinoIcons.lock_fill,
                    size: size * .13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Original procedural metalwork. Fixed normalized geometry keeps the same
/// silhouette at both grid and detail sizes without texture uploads.
class _SculptedMedalPainter extends CustomPainter {
  const _SculptedMedalPainter({
    required this.metal,
    required this.dark,
    required this.rim,
    required this.edge,
    required this.face,
    required this.unlocked,
    required this.tier,
  });
  final Color metal, dark, rim, edge, face;
  final bool unlocked;
  final BadgeTier tier;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale);
    const center = Offset(50, 47.5);
    const radius = 44.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final white = Color.lerp(rim, Colors.white, unlocked ? .8 : .02)!;
    final black = Color.lerp(edge, Colors.black, .45)!;
    final p = Paint()..isAntiAlias = true;
    void circle(double r, Shader shader, [Offset c = center]) {
      canvas.drawCircle(
        c,
        r,
        p
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
    }

    // Rounded extrusion below the front face; alternating reflections read
    // as a polished machined sidewall even at 60 logical pixels.
    final side = Rect.fromCenter(
      center: const Offset(50, 53),
      width: 88,
      height: 84,
    );
    canvas.drawOval(
      side,
      p
        ..shader = LinearGradient(
          colors: [black, dark, rim, edge, black, metal, black],
          stops: const [0, .12, .25, .45, .69, .88, 1],
        ).createShader(side),
    );
    circle(
      radius,
      SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [edge, metal, white, dark, black, rim, white, metal, edge],
        stops: const [0, .11, .23, .34, .48, .62, .73, .87, 1],
      ).createShader(rect),
    );
    circle(
      39.5,
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [black, edge, rim, dark],
        stops: const [0, .35, .82, 1],
      ).createShader(rect),
    );
    circle(
      36.8,
      RadialGradient(
        center: const Alignment(-.45, -.52),
        radius: 1.12,
        colors: [rim, face, dark, black],
        stops: const [0, .24, .69, 1],
      ).createShader(rect),
    );
    // Recessed inner bezel and thin reflected highlight.
    p
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    canvas.drawCircle(
      center,
      38.3,
      p..color = rim.withValues(alpha: unlocked ? .62 : .28),
    );
    canvas.drawCircle(center, 35.8, p..color = black.withValues(alpha: .65));
    // Fine machined radial grooves on the outer bevel, defined by tier.
    final divisions = switch (tier) {
      BadgeTier.bronze => 24,
      BadgeTier.silver => 32,
      BadgeTier.gold => 40,
      BadgeTier.quantum => 48,
    };
    if (unlocked) {
      p.strokeWidth = .55;
      for (var i = 0; i < divisions; i++) {
        final a = i * 2 * math.pi / divisions;
        final v = Offset(math.cos(a), math.sin(a));
        p.color = i % 2 == 0
            ? white.withValues(alpha: .28)
            : black.withValues(alpha: .36);
        canvas.drawLine(center + v * 40.4, center + v * 42.7, p);
      }
    }
    // Small sharp light strips, rather than a broad white overlay, give the
    // beveled face its reflective contour.
    p
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.15
      ..color = white.withValues(alpha: unlocked ? .85 : .20);
    canvas.drawArc(rect.deflate(1.0), math.pi * 1.05, math.pi * .54, false, p);
    p
      ..strokeWidth = .65
      ..color = rim.withValues(alpha: unlocked ? .65 : .25);
    canvas.drawArc(rect.deflate(3.2), math.pi * .02, math.pi * .34, false, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SculptedMedalPainter old) =>
      old.metal != metal ||
      old.dark != dark ||
      old.rim != rim ||
      old.edge != edge ||
      old.face != face ||
      old.unlocked != unlocked ||
      old.tier != tier;
}

/// Touch-controlled perspective, inspired by the interactive product tilt in
/// Shipframe. Only mounted on the detail view, with no idle animation ticker.
class _TouchTilt extends StatefulWidget {
  const _TouchTilt({
    required this.size,
    required this.enabled,
    required this.child,
  });
  final double size;
  final bool enabled;
  final Widget child;

  @override
  State<_TouchTilt> createState() => _TouchTiltState();
}

class _TouchTiltState extends State<_TouchTilt> {
  Offset _position = Offset.zero;
  bool _tracking = false;

  void _move(Offset local) {
    final center = widget.size / 2;
    setState(() {
      _tracking = true;
      _position = Offset(
        ((local.dx - center) / center).clamp(-1.0, 1.0),
        ((local.dy - center) / center).clamp(-1.0, 1.0),
      );
    });
  }

  void _reset() {
    if (!_tracking) return;
    setState(() {
      _tracking = false;
      _position = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      key: const ValueKey('achievement-touch-tilt'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (event) => _move(event.localPosition),
      onPanUpdate: (event) => _move(event.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: _position),
        duration: Duration(milliseconds: _tracking ? 110 : 420),
        curve: _tracking ? Curves.easeOut : Curves.easeOutBack,
        child: RepaintBoundary(child: widget.child),
        builder: (context, pose, child) => Transform(
          key: const ValueKey('achievement-touch-matrix'),
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0025)
            ..rotateY(pose.dx * .48)
            ..rotateX(-pose.dy * .38),
          child: Stack(
            alignment: Alignment.center,
            children: [
              child!,
              if (pose.distance > .015)
                Positioned(
                  top: widget.size * .035,
                  width: widget.size * .88,
                  height: widget.size * .88,
                  child: IgnorePointer(
                    child: ClipOval(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(
                              -.42 - pose.dx * .55,
                              -.55 - pose.dy * .45,
                            ),
                            radius: .50,
                            colors: [
                              Colors.white.withValues(alpha: .34),
                              Colors.white.withValues(alpha: .025),
                              Colors.transparent,
                            ],
                            stops: const [0, .48, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
