import 'dart:ui' as ui;
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

/// Exact vector geometry from the official AETRON Logo 02B pack
/// (`AETRON_Mark_Dark.svg` / `AETRON_Logo_Dark.svg` — "AETRON · E liền nét"),
/// enhanced with a custom stylized aerodynamic wordmark echoing the "E liền nét" motif.
class AetronLogoPaths {
  const AetronLogoPaths._();

  /// Official AETRON brand palette matching the startup [AetronLogoDrawScreen].
  static const Color darkAccentColor = Color(0xFF93BFFF);
  static const Color lightAccentColor = Color(0xFF1166DB);
  static const Color darkWordmarkColor = Color(0xFFF3F7FF);
  static const Color lightWordmarkColor = Color(0xFF152437);
  static const Color darkTipColor = Color(0xFFF3F7FF);
  static const Color lightTipColor = Colors.white;

  /// Original mark viewBox from `AETRON_Mark_Dark.svg`:
  /// `-52.87649 208.96629 1215.9102 866.06742`
  static const double markMinX = -52.87649;
  static const double markMinY = 208.96629;
  static const double markWidth = 1215.9102;
  static const double markHeight = 866.06742;
  static const double markAspectRatio = markWidth / markHeight;

  /// Stylized wordmark bounding box (with forward italic lean + E speed bars)
  static const double wordmarkWidth = 4420.0;
  static const double wordmarkHeight = 820.0;
  static const double wordmarkAspectRatio = wordmarkWidth / wordmarkHeight;

  static Color accentColorFor({required bool isDark}) =>
      isDark ? darkAccentColor : lightAccentColor;

  static Color wordmarkColorFor({required bool isDark}) =>
      isDark ? darkWordmarkColor : lightWordmarkColor;

  static Matrix4 _markTransform(Size size) {
    final sx = size.width / markWidth;
    final sy = size.height / markHeight;
    final s = sx < sy ? sx : sy;
    final dx = (size.width - markWidth * s) / 2 - markMinX * s;
    final dy = (size.height - markHeight * s) / 2 - markMinY * s;
    return Matrix4.translationValues(dx, dy, 0)..scaleByDouble(s, s, 1, 1);
  }

  /// Left slash + continuous 3-bar "E" polygon from `AETRON_Mark_Dark.svg`.
  static Path buildPrimaryWingPath(Size size) {
    final raw = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(697, 254)
      ..lineTo(804, 431)
      ..lineTo(408, 1030)
      ..lineTo(163, 1030)
      ..lineTo(264.15722, 883)
      ..lineTo(-7.84278, 883)
      ..lineTo(25.95103, 815)
      ..lineTo(310.95103, 815)
      ..lineTo(357.74485, 747)
      ..lineTo(161.74485, 747)
      ..lineTo(195.53866, 679)
      ..lineTo(404.53866, 679)
      ..lineTo(451.33247, 611)
      ..lineTo(187.33247, 611)
      ..lineTo(221.12629, 543)
      ..lineTo(498.12629, 543)
      ..close();
    return raw.transform(_markTransform(size).storage);
  }

  /// Right wing + crossbar polygon from `AETRON_Mark_Dark.svg`.
  static Path buildSecondaryWingPath(Size size) {
    final raw = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(820, 458)
      ..lineTo(1118, 1030)
      ..lineTo(885, 1030)
      ..lineTo(843, 946)
      ..lineTo(685, 946)
      ..lineTo(566, 832)
      ..lineTo(785, 832)
      ..lineTo(684, 638)
      ..close();
    return raw.transform(_markTransform(size).storage);
  }

  /// Combined AETRON mark path (`PathFillType.evenOdd`).
  static Path buildMarkPath(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(buildPrimaryWingPath(size), Offset.zero)
      ..addPath(buildSecondaryWingPath(size), Offset.zero);
  }

  /// Stylized aerodynamic `AETRON` wordmark glyphs:
  /// - Forward athletic italic slant (~11 deg) matching the mark's velocity
  /// - Stylized `A` with crisp aerodynamic crossbar slice
  /// - Stylized `E` with 3 staggered speed-bars echoing "E liền nét"
  static List<Path> buildWordmarkGlyphPaths(Size size) {
    final sx = size.width / wordmarkWidth;
    final sy = size.height / wordmarkHeight;
    final s = sx < sy ? sx : sy;
    final dx = (size.width - wordmarkWidth * s) / 2 + 120 * s;
    final dy = (size.height + 640 * s) / 2;

    // Combine translation, Y-flip, and aerodynamic italic slant (skewX = 0.19 in Y-flipped space)
    Path transformGlyph(Path p, double tx) {
      final m = Matrix4.identity()
        ..translateByDouble(dx + tx * s, dy, 0, 1)
        ..scaleByDouble(s, -s, 1, 1);
      // Apply forward slant: x' = x + 0.19 * y (since y is up in glyph coords, top leans right)
      final skew = Matrix4.identity()..setEntry(0, 1, 0.19);
      m.multiply(skew);
      return p.transform(m.storage);
    }

    // Stylized A: crisp athletic arch + angled wing crossbar
    final glyphA = Path()
      ..fillType = PathFillType.nonZero
      ..moveTo(0, 0)
      ..lineTo(295, 706)
      ..lineTo(445, 706)
      ..lineTo(725, 0)
      ..lineTo(552, 0)
      ..lineTo(342, 578)
      ..lineTo(395, 578)
      ..lineTo(175, 0)
      ..close()
      // Angled kinetic crossbar slice echoing the mark's crossbar
      ..moveTo(220, 128)
      ..lineTo(285, 250)
      ..lineTo(570, 250)
      ..lineTo(525, 128)
      ..close();

    // Stylized E ("E liền nét"): vertical spine + 3 staggered speed-bar arms
    final glyphE = Path()
      ..fillType = PathFillType.nonZero
      // Main spine with angled speed cut
      ..moveTo(64, 0)
      ..lineTo(64, 706)
      ..lineTo(222, 706)
      ..lineTo(222, 0)
      ..close()
      // Bottom speed bar (longest reach)
      ..moveTo(-20, 0)
      ..lineTo(22, 134)
      ..lineTo(580, 134)
      ..lineTo(580, 0)
      ..close()
      // Middle speed bar
      ..moveTo(8, 294)
      ..lineTo(48, 424)
      ..lineTo(530, 424)
      ..lineTo(530, 294)
      ..close()
      // Top speed bar
      ..moveTo(40, 572)
      ..lineTo(78, 706)
      ..lineTo(590, 706)
      ..lineTo(590, 572)
      ..close();

    // T (crisp wide aerodynamic top bar)
    final glyphT = Path()
      ..fillType = PathFillType.nonZero
      ..moveTo(241, 0)
      ..lineTo(241, 696)
      ..lineTo(398, 696)
      ..lineTo(398, 0)
      ..close()
      ..moveTo(10, 569)
      ..lineTo(48, 706)
      ..lineTo(628, 706)
      ..lineTo(594, 569)
      ..close();

    // R
    final glyphR = Path()
      ..fillType = PathFillType.nonZero
      ..moveTo(188, 291)
      ..lineTo(188, 407)
      ..lineTo(337, 407)
      ..quadraticBezierTo(384, 407, 409.5, 431.0)
      ..quadraticBezierTo(435, 455, 435, 496)
      ..quadraticBezierTo(435, 534, 410.0, 559.0)
      ..quadraticBezierTo(385, 584, 338, 584)
      ..lineTo(188, 584)
      ..lineTo(188, 706)
      ..lineTo(356, 706)
      ..quadraticBezierTo(426, 706, 479.0, 679.5)
      ..quadraticBezierTo(532, 653, 562.0, 606.0)
      ..quadraticBezierTo(592, 559, 592, 498)
      ..quadraticBezierTo(592, 436, 562.0, 389.5)
      ..quadraticBezierTo(532, 343, 478.0, 317.0)
      ..quadraticBezierTo(424, 291, 351, 291)
      ..close()
      ..moveTo(68, 0)
      ..lineTo(68, 706)
      ..lineTo(225, 706)
      ..lineTo(225, 0)
      ..close()
      ..moveTo(452, 0)
      ..lineTo(232, 304)
      ..lineTo(376, 343)
      ..lineTo(638, 0)
      ..close();

    // O
    final glyphO = Path()
      ..fillType = PathFillType.nonZero
      ..moveTo(405, -12)
      ..quadraticBezierTo(325, -12, 257.5, 16.0)
      ..quadraticBezierTo(190, 44, 139.0, 94.0)
      ..quadraticBezierTo(88, 144, 60.0, 210.5)
      ..quadraticBezierTo(32, 277, 32, 354)
      ..quadraticBezierTo(32, 432, 60.0, 498.0)
      ..quadraticBezierTo(88, 564, 138.0, 613.5)
      ..quadraticBezierTo(188, 663, 255.5, 690.5)
      ..quadraticBezierTo(323, 718, 403, 718)
      ..quadraticBezierTo(482, 718, 549.5, 690.5)
      ..quadraticBezierTo(617, 663, 667.5, 613.5)
      ..quadraticBezierTo(718, 564, 746.0, 497.5)
      ..quadraticBezierTo(774, 431, 774, 353)
      ..quadraticBezierTo(774, 276, 746.0, 209.5)
      ..quadraticBezierTo(718, 143, 668.0, 93.5)
      ..quadraticBezierTo(618, 44, 550.5, 16.0)
      ..quadraticBezierTo(483, -12, 405, -12)
      ..close()
      ..moveTo(403, 131)
      ..quadraticBezierTo(466, 131, 513.5, 159.0)
      ..quadraticBezierTo(561, 187, 587.0, 237.5)
      ..quadraticBezierTo(613, 288, 613, 354)
      ..quadraticBezierTo(613, 404, 598.0, 444.5)
      ..quadraticBezierTo(583, 485, 555.0, 514.5)
      ..quadraticBezierTo(527, 544, 488.5, 559.5)
      ..quadraticBezierTo(450, 575, 403, 575)
      ..quadraticBezierTo(340, 575, 292.5, 547.5)
      ..quadraticBezierTo(245, 520, 219.0, 470.5)
      ..quadraticBezierTo(193, 421, 193, 354)
      ..quadraticBezierTo(193, 304, 208.0, 263.0)
      ..quadraticBezierTo(223, 222, 250.5, 192.5)
      ..quadraticBezierTo(278, 163, 317.0, 147.0)
      ..quadraticBezierTo(356, 131, 403, 131)
      ..close();

    // N
    final glyphN = Path()
      ..fillType = PathFillType.nonZero
      ..moveTo(68, 0)
      ..lineTo(68, 706)
      ..lineTo(178, 706)
      ..lineTo(225, 565)
      ..lineTo(225, 0)
      ..close()
      ..moveTo(555, 0)
      ..lineTo(139, 533)
      ..lineTo(178, 706)
      ..lineTo(594, 173)
      ..close()
      ..moveTo(555, 0)
      ..lineTo(513, 141)
      ..lineTo(513, 706)
      ..lineTo(670, 706)
      ..lineTo(670, 0)
      ..close();

    return [
      transformGlyph(glyphA, 0),
      transformGlyph(glyphE, 755.0),
      transformGlyph(glyphT, 1395.0),
      transformGlyph(glyphR, 2050.0),
      transformGlyph(glyphO, 2720.0),
      transformGlyph(glyphN, 3545.0),
    ];
  }
}

/// Theme-adaptive transparent vector logo mark widget — sits directly on the
/// app's background without any black box or dark tile container.
class AetronBrandMark extends StatelessWidget {
  final double size;
  final Color? color;
  final bool? forceDark;

  const AetronBrandMark({
    super.key,
    this.size = 44.0,
    this.color,
    this.forceDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDark ??
        (Theme.of(context).extension<KineticColors>()?.isDark ??
            Theme.of(context).brightness == Brightness.dark);
    final markColor = color ?? AetronLogoPaths.accentColorFor(isDark: isDark);
    final height =
        size * (AetronLogoPaths.markHeight / AetronLogoPaths.markWidth);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(size, height),
          painter: AetronBrandMarkPainter(
            strokeProgress: 1.0,
            fillProgress: 1.0,
            color: markColor,
          ),
        ),
      ),
    );
  }
}

/// Static theme-adaptive stylized aerodynamic `AETRON` vector wordmark widget
/// matching the startup [AetronLogoDrawScreen] ("AETRON · E liền nét").
class AetronWordmark extends StatelessWidget {
  final double height;
  final double? width;
  final Color? accentColor;
  final Color? color;
  final bool? forceDark;
  final bool showUnderline;
  final String? semanticLabel;

  const AetronWordmark({
    super.key,
    this.height = 20.0,
    this.width,
    this.accentColor,
    this.color,
    this.forceDark,
    this.showUnderline = true,
    this.semanticLabel = 'AETRON',
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDark ??
        (Theme.of(context).extension<KineticColors>()?.isDark ??
            Theme.of(context).brightness == Brightness.dark);
    final resolvedAccent =
        accentColor ?? AetronLogoPaths.accentColorFor(isDark: isDark);
    final resolvedColor =
        color ?? AetronLogoPaths.wordmarkColorFor(isDark: isDark);

    final double resolvedWidth =
        width ?? height * AetronLogoPaths.wordmarkAspectRatio;
    final double resolvedHeight = width != null
        ? width! / AetronLogoPaths.wordmarkAspectRatio
        : height;

    final paint = SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
      child: CustomPaint(
        size: Size(resolvedWidth, resolvedHeight),
        painter: AetronWordmarkPainter(
          progress: 1.0,
          accentColor: resolvedAccent,
          color: resolvedColor,
          showUnderline: showUnderline,
        ),
      ),
    );

    if (semanticLabel == null) return paint;
    return Semantics(label: semanticLabel, child: paint);
  }
}

/// Unified horizontal AETRON brand lockup combining [AetronBrandMark] and
/// [AetronWordmark] with exact startup palette and proportions.
class AetronBrandLockup extends StatelessWidget {
  final double markSize;
  final double? wordmarkHeight;
  final double? spacing;
  final Color? accentColor;
  final Color? wordmarkColor;
  final bool? forceDark;
  final bool showUnderline;
  final String? semanticLabel;

  const AetronBrandLockup({
    super.key,
    this.markSize = 28.0,
    this.wordmarkHeight,
    this.spacing,
    this.accentColor,
    this.wordmarkColor,
    this.forceDark,
    this.showUnderline = true,
    this.semanticLabel = 'AETRON',
  });

  @override
  Widget build(BuildContext context) {
    final resolvedWordmarkHeight = wordmarkHeight ?? (markSize * 0.64);
    final resolvedSpacing = spacing ?? (markSize * 0.28);

    final lockup = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AetronBrandMark(
          size: markSize,
          color: accentColor,
          forceDark: forceDark,
        ),
        SizedBox(width: resolvedSpacing),
        AetronWordmark(
          height: resolvedWordmarkHeight,
          accentColor: accentColor,
          color: wordmarkColor,
          forceDark: forceDark,
          showUnderline: showUnderline,
          semanticLabel: null,
        ),
      ],
    );

    if (semanticLabel == null) return lockup;
    return Semantics(label: semanticLabel, child: lockup);
  }
}

/// CustomPainter that draws the official `AETRON · E liền nét` logo mark
/// by tracing its exact vector contours and smoothly illuminating the fill.
class AetronBrandMarkPainter extends CustomPainter {
  final double strokeProgress;
  final double fillProgress;
  final double shimmerProgress;
  final Color color;
  final Color tipColor;

  const AetronBrandMarkPainter({
    required this.strokeProgress,
    required this.fillProgress,
    this.shimmerProgress = 0.0,
    this.color = const Color(0xFF93BFFF),
    this.tipColor = const Color(0xFFF3F7FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final primaryPath = AetronLogoPaths.buildPrimaryWingPath(size);
    final secondaryPath = AetronLogoPaths.buildSecondaryWingPath(size);
    final fullPath = AetronLogoPaths.buildMarkPath(size);

    // Fast path for static rendering (e.g. AetronBrandMark widget)
    if (strokeProgress >= 0.999 &&
        fillProgress >= 0.999 &&
        shimmerProgress <= 0.001) {
      canvas.drawPath(
        fullPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
      return;
    }

    final p1 = (strokeProgress / 0.82).clamp(0.0, 1.0);
    final p2 = ((strokeProgress - 0.16) / 0.84).clamp(0.0, 1.0);
    final strokeWidth = (size.width * 0.016).clamp(1.6, 3.2);

    if (strokeProgress > 0.01) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.28 * (1.0 - fillProgress * 0.45))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      _drawPartialContour(canvas, primaryPath, p1, glowPaint, drawTip: false);
      _drawPartialContour(canvas, secondaryPath, p2, glowPaint, drawTip: false);
    }

    final outlineAlpha = (1.0 - fillProgress * 0.65).clamp(0.0, 1.0);
    if (outlineAlpha > 0.01) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: outlineAlpha);

      _drawPartialContour(
        canvas,
        primaryPath,
        p1,
        strokePaint,
        drawTip: p1 > 0.01 && p1 < 0.995,
      );
      _drawPartialContour(
        canvas,
        secondaryPath,
        p2,
        strokePaint,
        drawTip: p2 > 0.01 && p2 < 0.995,
      );
    }

    if (fillProgress > 0.005) {
      final fillAlpha = fillProgress.clamp(0.0, 1.0);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: fillAlpha);

      canvas.save();
      canvas.clipPath(fullPath);
      if (fillProgress < 0.99) {
        final sweepWidth = size.width * (0.20 + 0.85 * fillProgress);
        canvas.clipRect(Rect.fromLTWH(0, 0, sweepWidth, size.height));
      }
      canvas.drawPath(fullPath, fillPaint);

      if (shimmerProgress > 0.01 && shimmerProgress < 0.99) {
        final sweepX = -size.width * 0.35 + size.width * 1.7 * shimmerProgress;
        final shimmerPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(sweepX - size.width * 0.18, 0),
            Offset(sweepX + size.width * 0.18, size.height * 0.45),
            [
              Colors.transparent,
              tipColor.withValues(alpha: 0.48),
              Colors.transparent,
            ],
            const [0.0, 0.5, 1.0],
          );
        canvas.drawRect(Offset.zero & size, shimmerPaint);
      }
      canvas.restore();
    }
  }

  void _drawPartialContour(
    Canvas canvas,
    Path path,
    double t,
    Paint paint, {
    required bool drawTip,
  }) {
    if (t <= 0.001) return;
    if (t >= 0.999) {
      canvas.drawPath(path, paint);
      return;
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final len = metric.length * t;
    final partial = metric.extractPath(0.0, len);
    canvas.drawPath(partial, paint);

    if (drawTip) {
      final tangent = metric.getTangentForOffset(len);
      if (tangent != null) {
        final pos = tangent.position;
        canvas.drawCircle(
          pos,
          paint.strokeWidth * 2.6,
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          pos,
          paint.strokeWidth * 1.15,
          Paint()..color = tipColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AetronBrandMarkPainter oldDelegate) {
    return oldDelegate.strokeProgress != strokeProgress ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.color != color ||
        oldDelegate.tipColor != tipColor;
  }
}

/// CustomPainter for the stylized aerodynamic `AETRON` wordmark:
/// - Dual-tone kinetic gradient (`A` & `E` accent color -> `TRON` wordmark color)
/// - Staggered horizontal velocity glide + laser contour trace
/// - Tapered speed-streak underline echoing the 3-bar "E liền nét" mark
class AetronWordmarkPainter extends CustomPainter {
  final double progress;
  final double shimmerProgress;
  final Color accentColor;
  final Color color;
  final bool showUnderline;

  const AetronWordmarkPainter({
    required this.progress,
    this.shimmerProgress = 0.0,
    this.accentColor = AetronLogoPaths.lightAccentColor,
    this.color = AetronLogoPaths.lightWordmarkColor,
    this.showUnderline = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.005) return;
    final glyphs = AetronLogoPaths.buildWordmarkGlyphPaths(size);
    final count = glyphs.length;

    for (var i = 0; i < count; i++) {
      final start = (i / count) * 0.40;
      final localT = ((progress - start) / 0.60).clamp(0.0, 1.0);
      if (localT <= 0.0) continue;

      final glyph = glyphs[i];
      // Highlight leading "A" and "E" ("E liền nét" signature) in vibrant accent blue
      final glyphColor = i <= 1 ? accentColor : color;
      // Subtle aerodynamic horizontal slide-in from left
      final slideX = (1.0 - Curves.easeOutCubic.transform(localT)) * -10.0;

      canvas.save();
      canvas.translate(slideX, 0);

      if (localT < 0.72) {
        final traceT = (localT / 0.72).clamp(0.0, 1.0);
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (size.height * 0.042).clamp(1.0, 1.8)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = accentColor.withValues(alpha: 0.90);
        for (final metric in glyph.computeMetrics()) {
          canvas.drawPath(
            metric.extractPath(0.0, metric.length * traceT),
            strokePaint,
          );
        }
      }

      final fillT = ((localT - 0.30) / 0.70).clamp(0.0, 1.0);
      if (fillT > 0.0) {
        canvas.drawPath(
          glyph,
          Paint()
            ..style = PaintingStyle.fill
            ..color = glyphColor.withValues(alpha: fillT),
        );
      }

      canvas.restore();
    }

    // Tapered aerodynamic speed underline streak shooting beneath AETRON
    final lineT = ((progress - 0.48) / 0.52).clamp(0.0, 1.0);
    if (showUnderline && lineT > 0.01) {
      final eased = Curves.easeOutCubic.transform(lineT);
      final y = size.height * 0.96;
      final h = (size.height * 0.065).clamp(1.0, 2.8);
      final left = size.width * 0.03;
      final fullW = size.width * 0.93 * eased;

      final streak = Path()
        ..moveTo(left + h * 0.7, y)
        ..lineTo(left + fullW, y)
        ..lineTo(left + fullW - h * 0.7, y + h)
        ..lineTo(left, y + h)
        ..close();

      canvas.drawPath(
        streak,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(left, y),
            Offset(left + fullW, y),
            [
              accentColor,
              accentColor.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            const [0.0, 0.55, 1.0],
          ),
      );
    }

    // Unified specular shimmer sweep across wordmark
    if (shimmerProgress > 0.01 && shimmerProgress < 0.99) {
      final combined = Path()..fillType = PathFillType.nonZero;
      for (final g in glyphs) {
        combined.addPath(g, Offset.zero);
      }
      canvas.save();
      canvas.clipPath(combined);
      final sweepX = -size.width * 0.25 + size.width * 1.5 * shimmerProgress;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(sweepX - size.width * 0.16, 0),
            Offset(sweepX + size.width * 0.16, size.height * 0.5),
            [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AetronWordmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.color != color ||
        oldDelegate.showUnderline != showUnderline;
  }
}
