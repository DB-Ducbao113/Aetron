// Aetron "Blade" icon system — custom stroke icons derived from the Aetron
// logo mark (blade terminals, A-angle diagonals, speed lines).
//
// Geometry transcribed 1:1 from the approved SVG set (24x24 grid, 2px
// stroke, round caps/joins). Icons inherit color from context; a few icons
// carry filled parts (rec/gps/target/medal centers, pause, play, bolt,
// sound speaker) exactly as in the source SVGs.

import 'package:flutter/material.dart';

enum BladeIconName {
  home,
  pulse,
  rec,
  cal,
  user,
  bell,
  gear,
  hist,
  run,
  bike,
  walk,
  hike,
  gps,
  heart,
  flag,
  cam,
  pause,
  play,
  chart,
  route,
  pin,
  map,
  target,
  trophy,
  medal,
  bolt,
  flame,
  moon,
  sunrise,
  mail,
  lock,
  eye,
  shield,
  globe,
  units,
  sound,
  export,
  download,
  help,
  info,
  chevR,
  chevL,
  more,
  plus,
  edit,
  check,
  x,
  search,
  layers,
  share,
  clock,
  star,
  sliders,
  logout,
  trash,
  doc,
  link,
}

class BladeIcon extends StatelessWidget {
  const BladeIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
  });

  final BladeIconName name;
  final double size;
  final Color? color;

  /// Stroke width in 24-grid units (scaled with [size]). Defaults to 2.
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BladePainter(name, resolved, strokeWidth ?? 2.0),
        size: Size.square(size),
      ),
    );
  }
}

class _BladePainter extends CustomPainter {
  const _BladePainter(this.name, this.color, this.strokeWidth);

  final BladeIconName name;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    _draw(canvas, stroke, fill);
    canvas.restore();
  }

  Path _dash(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      var draw = true;
      while (d < metric.length) {
        final len = draw ? dash : gap;
        final end = (d + len).clamp(0.0, metric.length);
        if (draw && end > d) {
          out.addPath(metric.extractPath(d, end), Offset.zero);
        }
        d = end;
        draw = !draw;
      }
    }
    return out;
  }

  void _draw(Canvas c, Paint s, Paint f) {
    switch (name) {
      case BladeIconName.home:
        c.drawPath(
            Path()
              ..moveTo(4, 11)
              ..lineTo(12, 4)
              ..lineTo(20, 11),
            s);
        c.drawPath(
            Path()
              ..moveTo(6, 9.5)
              ..lineTo(6, 20)
              ..lineTo(18, 20)
              ..lineTo(18, 9.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(10, 20)
              ..lineTo(10, 15)
              ..lineTo(14, 15)
              ..lineTo(14, 20),
            s);
      case BladeIconName.pulse:
        c.drawPath(
            Path()
              ..moveTo(2.5, 12)
              ..lineTo(6.7, 12)
              ..lineTo(9, 5.5)
              ..lineTo(13.2, 18.5)
              ..lineTo(15.5, 12)
              ..lineTo(21.5, 12),
            s);
      case BladeIconName.rec:
        c.drawCircle(const Offset(12, 12), 8.5, s);
        c.drawCircle(const Offset(12, 12), 3.4, f);
      case BladeIconName.cal:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(4, 6, 16, 14), const Radius.circular(2.5)),
            s);
        c.drawPath(
            Path()
              ..moveTo(4, 10.5)
              ..lineTo(20, 10.5)
              ..moveTo(8.5, 4)
              ..lineTo(8.5, 8)
              ..moveTo(15.5, 4)
              ..lineTo(15.5, 8),
            s);
        c.drawCircle(const Offset(9, 14.6), 0.4, f);
        c.drawCircle(const Offset(12, 14.6), 0.4, f);
        c.drawCircle(const Offset(15, 14.6), 0.4, f);
      case BladeIconName.user:
        c.drawCircle(const Offset(12, 8.2), 3.6, s);
        c.drawPath(
            Path()
              ..moveTo(5, 20)
              ..cubicTo(6.2, 16.6, 8.8, 15, 12, 15)
              ..cubicTo(15.2, 15, 17.8, 16.6, 19, 20),
            s);
      case BladeIconName.bell:
        c.drawPath(
            Path()
              ..moveTo(6, 16.5)
              ..lineTo(6, 11.5)
              ..arcToPoint(const Offset(18, 11.5),
                  radius: const Radius.circular(6))
              ..lineTo(18, 16.5)
              ..lineTo(19.2, 19.2)
              ..lineTo(4.8, 19.2)
              ..lineTo(6, 16.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(10, 21)
              ..arcToPoint(const Offset(14, 21),
                  radius: const Radius.circular(2.2), clockwise: false),
            s);
      case BladeIconName.gear:
        c.drawCircle(const Offset(12, 12), 3.2, s);
        c.drawPath(
            Path()
              ..moveTo(12, 3.5)
              ..lineTo(12, 6.5)
              ..moveTo(12, 17.5)
              ..lineTo(12, 20.5)
              ..moveTo(3.5, 12)
              ..lineTo(6.5, 12)
              ..moveTo(17.5, 12)
              ..lineTo(20.5, 12)
              ..moveTo(6, 6)
              ..lineTo(8.1, 8.1)
              ..moveTo(15.9, 15.9)
              ..lineTo(18, 18)
              ..moveTo(18, 6)
              ..lineTo(15.9, 8.1)
              ..moveTo(8.1, 15.9)
              ..lineTo(6, 18),
            s);
      case BladeIconName.hist:
        c.drawPath(
            Path()
              ..moveTo(4.6, 9.2)
              ..arcToPoint(const Offset(3.9, 15),
                  radius: const Radius.circular(8.5), largeArc: true),
            s);
        c.drawPath(
            Path()
              ..moveTo(4.1, 4.6)
              ..lineTo(4.1, 9.4)
              ..lineTo(8.9, 9.4),
            s);
        c.drawPath(
            Path()
              ..moveTo(12, 8)
              ..lineTo(12, 12.2)
              ..lineTo(15, 14),
            s);
      case BladeIconName.run:
        c.drawCircle(const Offset(14.8, 4.6), 1.9, s);
        c.drawPath(
            Path()
              ..moveTo(12.6, 8)
              ..lineTo(9.2, 12)
              ..lineTo(12.4, 14.4)
              ..lineTo(13.3, 19.2),
            s);
        c.drawPath(
            Path()
              ..moveTo(12.6, 8)
              ..lineTo(16.3, 9.7)
              ..lineTo(18.6, 9),
            s);
        c.drawPath(
            Path()
              ..moveTo(9.2, 12)
              ..lineTo(5.8, 13.8)
              ..lineTo(4.2, 17.6),
            s);
        c.drawPath(
            Path()
              ..moveTo(12.4, 14.4)
              ..lineTo(9.2, 17.8)
              ..lineTo(5.6, 18.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(1.8, 9.6)
              ..lineTo(5.4, 9.6)
              ..moveTo(1.2, 13.2)
              ..lineTo(5, 13.2),
            s);
      case BladeIconName.bike:
        c.drawCircle(const Offset(6.5, 16.5), 3.4, s);
        c.drawCircle(const Offset(17.5, 16.5), 3.4, s);
        c.drawPath(
            Path()
              ..moveTo(6.5, 16.5)
              ..lineTo(10, 9.8)
              ..lineTo(14.8, 9.8)
              ..lineTo(17.5, 16.5)
              ..moveTo(10, 9.8)
              ..lineTo(13.6, 16.5)
              ..moveTo(13.2, 6.6)
              ..lineTo(15.4, 6.6)
              ..lineTo(17, 9.8)
              ..moveTo(9.2, 6.8)
              ..lineTo(11.6, 6.8),
            s);
      case BladeIconName.walk:
        c.drawCircle(const Offset(12.9, 4.6), 1.9, s);
        c.drawPath(
            Path()
              ..moveTo(12.1, 7.8)
              ..lineTo(11, 13)
              ..lineTo(13.6, 16)
              ..lineTo(14.6, 20.6),
            s);
        c.drawPath(
            Path()
              ..moveTo(11, 13)
              ..lineTo(8, 15.2)
              ..lineTo(6.5, 19.1),
            s);
        c.drawPath(
            Path()
              ..moveTo(10.9, 9.6)
              ..lineTo(8.2, 11.9)
              ..lineTo(5.2, 12.4),
            s);
        c.drawPath(
            Path()
              ..moveTo(12.4, 8.1)
              ..lineTo(15.3, 9.9)
              ..lineTo(18.1, 9.6),
            s);
      case BladeIconName.hike:
        c.drawPath(
            Path()
              ..moveTo(3, 19.5)
              ..lineTo(9.5, 8)
              ..lineTo(13.3, 13.4)
              ..lineTo(15.5, 10)
              ..lineTo(21, 19.5)
              ..lineTo(3, 19.5)
              ..close(),
            s);
        c.drawCircle(const Offset(17.6, 5.2), 1.6, s);
      case BladeIconName.gps:
        c.drawCircle(const Offset(12, 12), 6.4, s);
        c.drawCircle(const Offset(12, 12), 1.4, f);
        c.drawPath(
            Path()
              ..moveTo(12, 2.8)
              ..lineTo(12, 5.8)
              ..moveTo(12, 18.2)
              ..lineTo(12, 21.2)
              ..moveTo(2.8, 12)
              ..lineTo(5.8, 12)
              ..moveTo(18.2, 12)
              ..lineTo(21.2, 12),
            s);
      case BladeIconName.heart:
        c.drawPath(
            Path()
              ..moveTo(12, 20.3)
              ..cubicTo(7, 16.5, 3.5, 13.2, 3.5, 9.6)
              ..cubicTo(3.5, 6.9, 5.5, 5, 8, 5)
              ..cubicTo(9.7, 5, 11.2, 5.9, 12, 7.3)
              ..cubicTo(12.8, 5.9, 14.3, 5, 16, 5)
              ..cubicTo(18.5, 5, 20.5, 6.9, 20.5, 9.6)
              ..cubicTo(20.5, 13.2, 17, 16.5, 12, 20.3)
              ..close(),
            s);
      case BladeIconName.flag:
        c.drawPath(
            Path()
              ..moveTo(6, 21.5)
              ..lineTo(6, 4.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(6, 4.8)
              ..cubicTo(9, 3, 11, 6.2, 15, 5)
              ..lineTo(16, 4.6)
              ..lineTo(16, 10.8)
              ..cubicTo(12.6, 12.1, 10.6, 9.1, 6, 10.6),
            s);
      case BladeIconName.cam:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(3.5, 7.5, 17, 12),
                const Radius.circular(2.5)),
            s);
        c.drawCircle(const Offset(12, 13.5), 3.4, s);
        c.drawPath(
            Path()
              ..moveTo(8.5, 7.5)
              ..lineTo(10, 5)
              ..lineTo(14, 5)
              ..lineTo(15.5, 7.5),
            s);
      case BladeIconName.pause:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(7.4, 5, 3.1, 14),
                const Radius.circular(1.2)),
            f);
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(13.5, 5, 3.1, 14),
                const Radius.circular(1.2)),
            f);
      case BladeIconName.play:
        c.drawPath(
            Path()
              ..moveTo(8, 5.1)
              ..lineTo(8, 18.9)
              ..cubicTo(8, 19.8, 9, 20.3, 9.7, 19.8)
              ..lineTo(20.2, 13)
              ..arcToPoint(const Offset(20.2, 11),
                  radius: const Radius.circular(1.2), clockwise: false)
              ..lineTo(9.7, 4.2)
              ..cubicTo(9, 3.7, 8, 4.2, 8, 5.1)
              ..close(),
            f);
      case BladeIconName.chart:
        c.drawPath(
            Path()
              ..moveTo(4, 4)
              ..lineTo(4, 19.5)
              ..lineTo(20, 19.5),
            s);
        final bars = Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.strokeWidth * 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        c.drawPath(
            Path()
              ..moveTo(8.3, 19.5)
              ..lineTo(8.3, 14)
              ..moveTo(12.3, 19.5)
              ..lineTo(12.3, 9.8)
              ..moveTo(16.3, 19.5)
              ..lineTo(16.3, 11),
            bars);
      case BladeIconName.route:
        c.drawCircle(const Offset(6, 19), 2.2, s);
        c.drawCircle(const Offset(18, 5), 2.2, s);
        final routePath = Path()
          ..moveTo(8.2, 19)
          ..lineTo(15, 19)
          ..arcToPoint(const Offset(15, 13),
              radius: const Radius.circular(3), clockwise: false)
          ..lineTo(9, 13)
          ..arcToPoint(const Offset(9, 7),
              radius: const Radius.circular(3))
          ..lineTo(9.8, 7);
        c.drawPath(_dash(routePath, 3.2, 3.2), s);
      case BladeIconName.pin:
        c.drawPath(
            Path()
              ..moveTo(12, 21.5)
              ..cubicTo(12, 21.5, 5, 15.5, 5, 10)
              ..arcToPoint(const Offset(19, 10),
                  radius: const Radius.circular(7))
              ..cubicTo(19, 15.5, 12, 21.5, 12, 21.5)
              ..close(),
            s);
        c.drawCircle(const Offset(12, 10), 2.6, s);
      case BladeIconName.map:
        c.drawPath(
            Path()
              ..moveTo(9, 4)
              ..lineTo(3.5, 6)
              ..lineTo(3.5, 20)
              ..lineTo(9, 18)
              ..lineTo(15, 20)
              ..lineTo(20.5, 18)
              ..lineTo(20.5, 4)
              ..lineTo(15, 6)
              ..lineTo(9, 4)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(9, 4)
              ..lineTo(9, 18)
              ..moveTo(15, 6)
              ..lineTo(15, 20),
            s);
      case BladeIconName.target:
        c.drawCircle(const Offset(12, 12), 8.5, s);
        c.drawCircle(const Offset(12, 12), 4.8, s);
        c.drawCircle(const Offset(12, 12), 1.3, f);
      case BladeIconName.trophy:
        c.drawPath(
            Path()
              ..moveTo(7.5, 4)
              ..lineTo(16.5, 4)
              ..lineTo(16.5, 9)
              ..arcToPoint(const Offset(7.5, 9),
                  radius: const Radius.circular(4.5))
              ..lineTo(7.5, 4)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(7.5, 5.6)
              ..lineTo(4.7, 5.6)
              ..arcToPoint(const Offset(7.7, 10),
                  radius: const Radius.circular(2.8), clockwise: false)
              ..moveTo(16.5, 5.6)
              ..lineTo(19.3, 5.6)
              ..arcToPoint(const Offset(16.3, 10),
                  radius: const Radius.circular(2.8)),
            s);
        c.drawPath(
            Path()
              ..moveTo(12, 13.6)
              ..lineTo(12, 16)
              ..moveTo(8.6, 20)
              ..lineTo(15.4, 20)
              ..moveTo(12, 16)
              ..lineTo(12, 20),
            s);
      case BladeIconName.medal:
        c.drawCircle(const Offset(12, 14.5), 5, s);
        c.drawCircle(const Offset(12, 14.5), 1.4, f);
        c.drawPath(
            Path()
              ..moveTo(8.8, 10.2)
              ..lineTo(6, 3.5)
              ..lineTo(10.2, 3.5)
              ..lineTo(12, 6.8)
              ..lineTo(13.8, 3.5)
              ..lineTo(18, 3.5)
              ..lineTo(15.2, 10.2),
            s);
      case BladeIconName.bolt:
        c.drawPath(
            Path()
              ..moveTo(13.1, 2.8)
              ..lineTo(5.2, 13.4)
              ..lineTo(10.1, 13.4)
              ..lineTo(9.6, 21.2)
              ..lineTo(18.9, 10.2)
              ..lineTo(13.8, 10.2)
              ..lineTo(13.1, 2.8)
              ..close(),
            f);
      case BladeIconName.flame:
        c.drawPath(
            Path()
              ..moveTo(12, 21)
              ..arcToPoint(const Offset(18.5, 14.5),
                  radius: const Radius.circular(6.5), clockwise: false)
              ..cubicTo(18.5, 11.9, 17, 10.1, 15.7, 8.5)
              ..cubicTo(14.3, 6.7, 13, 4.9, 13, 2.8)
              ..cubicTo(10.7, 4.2, 9.3, 6.1, 8.9, 8.2)
              ..cubicTo(8.7, 9.2, 8.7, 10.1, 8.3, 10.8)
              ..cubicTo(8, 10.3, 7.7, 9.7, 7.5, 8.8)
              ..cubicTo(6.2, 10.3, 5.5, 12.2, 5.5, 14.5)
              ..arcToPoint(const Offset(12, 21),
                  radius: const Radius.circular(6.5), clockwise: false)
              ..close(),
            s);
      case BladeIconName.moon:
        c.drawPath(
            Path()
              ..moveTo(20, 14.5)
              ..arcToPoint(const Offset(9.5, 4),
                  radius: const Radius.circular(8.5), largeArc: true)
              ..arcToPoint(const Offset(20, 14.5),
                  radius: const Radius.circular(7), clockwise: false)
              ..close(),
            s);
      case BladeIconName.sunrise:
        c.drawPath(
            Path()
              ..moveTo(3.5, 19)
              ..lineTo(20.5, 19)
              ..moveTo(7.5, 19)
              ..arcToPoint(const Offset(16.5, 19),
                  radius: const Radius.circular(4.5))
              ..moveTo(12, 5.5)
              ..lineTo(12, 7.8)
              ..moveTo(5.1, 9.4)
              ..lineTo(6.6, 11.1)
              ..moveTo(18.9, 9.4)
              ..lineTo(17.4, 11.1)
              ..moveTo(12, 11.5)
              ..lineTo(12, 12),
            s);
      case BladeIconName.mail:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(3.5, 5.5, 17, 13),
                const Radius.circular(2)),
            s);
        c.drawPath(
            Path()
              ..moveTo(4.2, 7.6)
              ..lineTo(12, 13.5)
              ..lineTo(19.8, 7.6),
            s);
      case BladeIconName.lock:
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(5.5, 10.5, 13, 9.5),
                const Radius.circular(2)),
            s);
        c.drawPath(
            Path()
              ..moveTo(8.5, 10.5)
              ..lineTo(8.5, 8)
              ..arcToPoint(const Offset(15.5, 8),
                  radius: const Radius.circular(3.5))
              ..lineTo(15.5, 10.5),
            s);
        c.drawCircle(const Offset(12, 15.2), 1.3, f);
      case BladeIconName.eye:
        c.drawPath(
            Path()
              ..moveTo(2.8, 12)
              ..cubicTo(2.8, 12, 6, 5.8, 12, 5.8)
              ..cubicTo(18, 5.8, 21.2, 12, 21.2, 12)
              ..cubicTo(21.2, 12, 18, 18.2, 12, 18.2)
              ..cubicTo(6, 18.2, 2.8, 12, 2.8, 12)
              ..close(),
            s);
        c.drawCircle(const Offset(12, 12), 3, s);
      case BladeIconName.shield:
        c.drawPath(
            Path()
              ..moveTo(12, 3)
              ..lineTo(19, 5.6)
              ..lineTo(19, 11.2)
              ..cubicTo(19, 15.8, 16, 18.9, 12, 20.5)
              ..cubicTo(8, 18.9, 5, 15.8, 5, 11.2)
              ..lineTo(5, 5.6)
              ..lineTo(12, 3)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(9, 11.8)
              ..lineTo(11.2, 14)
              ..lineTo(15.2, 9.8),
            s);
      case BladeIconName.globe:
        c.drawCircle(const Offset(12, 12), 8.8, s);
        c.drawPath(
            Path()
              ..moveTo(3.2, 12)
              ..lineTo(20.8, 12)
              ..moveTo(12, 3.2)
              ..cubicTo(14.4, 5.5, 15.6, 8.5, 15.6, 12)
              ..cubicTo(15.6, 15.5, 14.4, 18.5, 12, 20.8)
              ..cubicTo(9.6, 18.5, 8.4, 15.3, 8.4, 12)
              ..cubicTo(8.4, 8.7, 9.6, 5.5, 12, 3.2)
              ..close(),
            s);
      case BladeIconName.units:
        c.drawPath(
            Path()
              ..moveTo(4, 19.5)
              ..lineTo(20, 19.5)
              ..moveTo(6, 19.5)
              ..lineTo(6, 15.5)
              ..moveTo(10, 19.5)
              ..lineTo(10, 13)
              ..moveTo(14, 19.5)
              ..lineTo(14, 15.5)
              ..moveTo(18, 19.5)
              ..lineTo(18, 13),
            s);
      case BladeIconName.sound:
        c.drawPath(
            Path()
              ..moveTo(4, 9.8)
              ..lineTo(4, 14.2)
              ..lineTo(7.2, 14.2)
              ..lineTo(12, 18.6)
              ..lineTo(12, 5.4)
              ..lineTo(7.2, 9.8)
              ..close(),
            f);
        c.drawPath(
            Path()
              ..moveTo(15.5, 9.5)
              ..arcToPoint(const Offset(15.5, 14.5),
                  radius: const Radius.circular(4))
              ..moveTo(18, 7)
              ..arcToPoint(const Offset(18, 17),
                  radius: const Radius.circular(7.6)),
            s);
      case BladeIconName.export:
        c.drawPath(
            Path()
              ..moveTo(5, 14.5)
              ..lineTo(5, 18.5)
              ..arcToPoint(const Offset(6.5, 20),
                  radius: const Radius.circular(1.5), clockwise: false)
              ..lineTo(17.5, 20)
              ..arcToPoint(const Offset(19, 18.5),
                  radius: const Radius.circular(1.5), clockwise: false)
              ..lineTo(19, 14.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(12, 3.5)
              ..lineTo(12, 14.5)
              ..moveTo(7.8, 7.8)
              ..lineTo(12, 3.5)
              ..lineTo(16.2, 7.8),
            s);
      case BladeIconName.download:
        c.drawPath(
            Path()
              ..moveTo(5, 14.5)
              ..lineTo(5, 18.5)
              ..arcToPoint(const Offset(6.5, 20),
                  radius: const Radius.circular(1.5), clockwise: false)
              ..lineTo(17.5, 20)
              ..arcToPoint(const Offset(19, 18.5),
                  radius: const Radius.circular(1.5), clockwise: false)
              ..lineTo(19, 14.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(12, 14.5)
              ..lineTo(12, 3.5)
              ..moveTo(7.8, 9.7)
              ..lineTo(12, 14)
              ..lineTo(16.2, 9.7),
            s);
      case BladeIconName.help:
        c.drawCircle(const Offset(12, 12), 8.8, s);
        c.drawPath(
            Path()
              ..moveTo(9.6, 9.4)
              ..arcToPoint(const Offset(12, 12.4),
                  radius: const Radius.circular(2.6), largeArc: true)
              ..lineTo(12, 13.5),
            s);
        c.drawCircle(const Offset(12, 17), 0.6, f);
      case BladeIconName.info:
        c.drawCircle(const Offset(12, 12), 8.8, s);
        c.drawPath(
            Path()
              ..moveTo(12, 11.2)
              ..lineTo(12, 16.4),
            s);
        c.drawCircle(const Offset(12, 7.8), 0.7, f);
      case BladeIconName.chevR:
        c.drawPath(
            Path()
              ..moveTo(9.5, 5.5)
              ..lineTo(16, 12)
              ..lineTo(9.5, 18.5),
            s);
      case BladeIconName.chevL:
        c.drawPath(
            Path()
              ..moveTo(14.5, 5.5)
              ..lineTo(8, 12)
              ..lineTo(14.5, 18.5),
            s);
      case BladeIconName.more:
        c.drawCircle(const Offset(5, 12), 1.6, f);
        c.drawCircle(const Offset(12, 12), 1.6, f);
        c.drawCircle(const Offset(19, 12), 1.6, f);
      case BladeIconName.plus:
        c.drawPath(
            Path()
              ..moveTo(12, 5)
              ..lineTo(12, 19)
              ..moveTo(5, 12)
              ..lineTo(19, 12),
            s);
      case BladeIconName.edit:
        c.drawPath(
            Path()
              ..moveTo(4.6, 19.4)
              ..lineTo(5.6, 15.7)
              ..lineTo(16.9, 4.4)
              ..arcToPoint(const Offset(19.6, 7.1),
                  radius: const Radius.circular(1.9))
              ..lineTo(8.3, 18.4)
              ..lineTo(4.6, 19.4)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(14.9, 6.4)
              ..lineTo(17.6, 9.1),
            s);
      case BladeIconName.check:
        c.drawPath(
            Path()
              ..moveTo(4.5, 12.6)
              ..lineTo(9.5, 17.6)
              ..lineTo(19.5, 6.4),
            s);
      case BladeIconName.x:
        c.drawPath(
            Path()
              ..moveTo(6, 6)
              ..lineTo(18, 18)
              ..moveTo(18, 6)
              ..lineTo(6, 18),
            s);
      case BladeIconName.search:
        c.drawCircle(const Offset(11, 11), 6.5, s);
        c.drawPath(
            Path()
              ..moveTo(15.8, 15.8)
              ..lineTo(20.5, 20.5),
            s);
      case BladeIconName.layers:
        c.drawPath(
            Path()
              ..moveTo(12, 3.8)
              ..lineTo(21, 8.5)
              ..lineTo(12, 13.2)
              ..lineTo(3, 8.5)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(4, 13.4)
              ..lineTo(12, 17.6)
              ..lineTo(20, 13.4),
            s);
      case BladeIconName.share:
        c.drawCircle(const Offset(6, 12), 2.6, s);
        c.drawCircle(const Offset(17, 5.5), 2.6, s);
        c.drawCircle(const Offset(17, 18.5), 2.6, s);
        c.drawPath(
            Path()
              ..moveTo(8.4, 10.8)
              ..lineTo(14.6, 6.8)
              ..moveTo(8.4, 13.2)
              ..lineTo(14.6, 17.2),
            s);
      case BladeIconName.clock:
        c.drawCircle(const Offset(12, 12), 8.8, s);
        c.drawPath(
            Path()
              ..moveTo(12, 7)
              ..lineTo(12, 12.2)
              ..lineTo(15.4, 14.2),
            s);
      case BladeIconName.star:
        c.drawPath(
            Path()
              ..moveTo(12, 3.6)
              ..lineTo(14.5, 8.9)
              ..lineTo(20.3, 9.6)
              ..lineTo(16, 13.6)
              ..lineTo(17.1, 19.3)
              ..lineTo(12, 16.5)
              ..lineTo(6.9, 19.3)
              ..lineTo(8, 13.6)
              ..lineTo(3.7, 9.6)
              ..lineTo(9.5, 8.9)
              ..lineTo(12, 3.6)
              ..close(),
            s);
      case BladeIconName.sliders:
        c.drawPath(
            Path()
              ..moveTo(4.5, 7.5)
              ..lineTo(12.5, 7.5)
              ..moveTo(17.5, 7.5)
              ..lineTo(19.5, 7.5)
              ..moveTo(4.5, 16.5)
              ..lineTo(7, 16.5)
              ..moveTo(12, 16.5)
              ..lineTo(19.5, 16.5),
            s);
        c.drawCircle(const Offset(14.8, 7.5), 2.3, s);
        c.drawCircle(const Offset(9.5, 16.5), 2.3, s);
      case BladeIconName.logout:
        c.drawPath(
            Path()
              ..moveTo(13.5, 5)
              ..lineTo(6.8, 5)
              ..arcToPoint(const Offset(5, 6.8),
                  radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(5, 17.2)
              ..arcToPoint(const Offset(6.8, 19),
                  radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(13.5, 19),
            s);
        c.drawPath(
            Path()
              ..moveTo(10.5, 12)
              ..lineTo(21, 12)
              ..moveTo(17.4, 8.2)
              ..lineTo(21, 12)
              ..lineTo(17.4, 15.8),
            s);
      case BladeIconName.trash:
        c.drawPath(
            Path()
              ..moveTo(4.5, 6.5)
              ..lineTo(19.5, 6.5)
              ..moveTo(9.6, 6.2)
              ..lineTo(9.6, 4.9)
              ..arcToPoint(const Offset(10.5, 4),
                  radius: const Radius.circular(0.9))
              ..lineTo(13.5, 4)
              ..arcToPoint(const Offset(14.4, 4.9),
                  radius: const Radius.circular(0.9))
              ..lineTo(14.4, 6.2)
              ..moveTo(6.6, 6.5)
              ..lineTo(7.4, 18.2)
              ..arcToPoint(const Offset(9.2, 20),
                  radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(14.8, 20)
              ..arcToPoint(const Offset(16.6, 18.2),
                  radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(17.4, 6.5),
            s);
        c.drawPath(
            Path()
              ..moveTo(10, 10.5)
              ..lineTo(10, 16.5)
              ..moveTo(14, 10.5)
              ..lineTo(14, 16.5),
            s);
      case BladeIconName.doc:
        c.drawPath(
            Path()
              ..moveTo(6.5, 3.5)
              ..lineTo(14, 3.5)
              ..lineTo(18.5, 8)
              ..lineTo(18.5, 20.5)
              ..lineTo(6.5, 20.5)
              ..close(),
            s);
        c.drawPath(
            Path()
              ..moveTo(13.8, 3.8)
              ..lineTo(13.8, 8.2)
              ..lineTo(18.2, 8.2),
            s);
      case BladeIconName.link:
        c.drawPath(
            Path()
              ..moveTo(9.8, 14.2)
              ..lineTo(14.2, 9.8)
              ..moveTo(11.2, 6.6)
              ..lineTo(12.9, 4.9)
              ..arcToPoint(const Offset(18.4, 10.4),
                  radius: const Radius.circular(3.9))
              ..lineTo(16.5, 12.3)
              ..moveTo(12.8, 17.4)
              ..lineTo(11.1, 19.1)
              ..arcToPoint(const Offset(5.6, 13.6),
                  radius: const Radius.circular(3.9))
              ..lineTo(7.5, 11.7),
            s);
    }
  }

  @override
  bool shouldRepaint(covariant _BladePainter oldDelegate) =>
      oldDelegate.name != name ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
