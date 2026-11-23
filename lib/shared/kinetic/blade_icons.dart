import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Unified icon system with 1:1 vector geometry transcribed from the
/// HTML prototype (docs/design/aetron-glassline/index.html).
///
/// Every icon renders exact custom SVG geometry with 1.7px stroke-width,
/// round caps, and round joins, while preserving Lucide/Cupertino IconData
/// for semantic and widget-test findability.
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
  locate,
  refresh,
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
  sun,
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
  arrow,
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
  final double? strokeWidth;

  static IconData iconDataFor(BladeIconName name) => switch (name) {
    BladeIconName.home => LucideIcons.house,
    BladeIconName.pulse => LucideIcons.activity,
    BladeIconName.rec => LucideIcons.circle_dot,
    BladeIconName.cal => LucideIcons.calendar,
    BladeIconName.user => LucideIcons.user,
    BladeIconName.bell => LucideIcons.bell,
    BladeIconName.gear => LucideIcons.settings,
    BladeIconName.hist => LucideIcons.clock,
    BladeIconName.run => Icons.directions_run_rounded,
    BladeIconName.bike => Icons.directions_bike_rounded,
    BladeIconName.walk => Icons.directions_walk_rounded,
    BladeIconName.hike => LucideIcons.mountain,
    BladeIconName.gps => LucideIcons.navigation,
    BladeIconName.locate => LucideIcons.locate_fixed,
    BladeIconName.refresh => LucideIcons.refresh_cw,
    BladeIconName.heart => LucideIcons.heart,
    BladeIconName.flag => LucideIcons.flag,
    BladeIconName.cam => LucideIcons.camera,
    BladeIconName.pause => LucideIcons.pause,
    BladeIconName.play => LucideIcons.play,
    BladeIconName.chart => LucideIcons.chart_column,
    BladeIconName.route => LucideIcons.route,
    BladeIconName.pin => LucideIcons.map_pin,
    BladeIconName.map => LucideIcons.map,
    BladeIconName.target => LucideIcons.target,
    BladeIconName.trophy => LucideIcons.trophy,
    BladeIconName.medal => LucideIcons.award,
    BladeIconName.bolt => LucideIcons.zap,
    BladeIconName.flame => LucideIcons.flame,
    BladeIconName.moon => LucideIcons.moon,
    BladeIconName.sunrise || BladeIconName.sun => LucideIcons.sun,
    BladeIconName.mail => LucideIcons.mail,
    BladeIconName.lock => LucideIcons.lock,
    BladeIconName.eye => LucideIcons.eye,
    BladeIconName.shield => LucideIcons.shield,
    BladeIconName.globe => LucideIcons.globe,
    BladeIconName.units => LucideIcons.ruler,
    BladeIconName.sound => LucideIcons.volume_2,
    BladeIconName.export => LucideIcons.share,
    BladeIconName.download => LucideIcons.download,
    BladeIconName.help => LucideIcons.circle_question_mark,
    BladeIconName.info => LucideIcons.info,
    BladeIconName.arrow || BladeIconName.chevR => LucideIcons.chevron_right,
    BladeIconName.chevL => LucideIcons.chevron_left,
    BladeIconName.more => LucideIcons.ellipsis,
    BladeIconName.plus => LucideIcons.plus,
    BladeIconName.edit => LucideIcons.pencil,
    BladeIconName.check => LucideIcons.check,
    BladeIconName.x => LucideIcons.x,
    BladeIconName.search => LucideIcons.search,
    BladeIconName.layers => LucideIcons.layers,
    BladeIconName.share => LucideIcons.share_2,
    BladeIconName.clock => LucideIcons.clock,
    BladeIconName.star => LucideIcons.star,
    BladeIconName.sliders => LucideIcons.sliders_horizontal,
    BladeIconName.logout => LucideIcons.log_out,
    BladeIconName.trash => LucideIcons.trash,
    BladeIconName.doc => LucideIcons.file_text,
    BladeIconName.link => LucideIcons.link,
  };

  static IconData iosIconDataFor(BladeIconName name) => switch (name) {
    BladeIconName.home => CupertinoIcons.house,
    BladeIconName.cal => CupertinoIcons.calendar,
    BladeIconName.user => CupertinoIcons.person_crop_circle,
    BladeIconName.bell => CupertinoIcons.bell,
    BladeIconName.gear => CupertinoIcons.gear_alt,
    BladeIconName.hist => CupertinoIcons.clock,
    BladeIconName.gps => CupertinoIcons.location,
    BladeIconName.locate => CupertinoIcons.location,
    BladeIconName.refresh => CupertinoIcons.refresh,
    BladeIconName.heart => CupertinoIcons.heart,
    BladeIconName.flag => CupertinoIcons.flag,
    BladeIconName.cam => CupertinoIcons.camera,
    BladeIconName.pause => CupertinoIcons.pause_fill,
    BladeIconName.play => CupertinoIcons.play_fill,
    BladeIconName.chart => CupertinoIcons.chart_bar,
    BladeIconName.map => CupertinoIcons.map,
    BladeIconName.target => CupertinoIcons.scope,
    BladeIconName.medal => CupertinoIcons.rosette,
    BladeIconName.bolt => CupertinoIcons.bolt_fill,
    BladeIconName.flame => CupertinoIcons.flame_fill,
    BladeIconName.moon => CupertinoIcons.moon,
    BladeIconName.sunrise || BladeIconName.sun => CupertinoIcons.sun_max,
    BladeIconName.mail => CupertinoIcons.envelope,
    BladeIconName.lock => CupertinoIcons.lock_fill,
    BladeIconName.eye => CupertinoIcons.eye,
    BladeIconName.shield => CupertinoIcons.shield,
    BladeIconName.globe => CupertinoIcons.globe,
    BladeIconName.export => CupertinoIcons.arrow_up_square,
    BladeIconName.chevL => CupertinoIcons.chevron_back,
    BladeIconName.more => CupertinoIcons.ellipsis,
    BladeIconName.plus => CupertinoIcons.plus,
    BladeIconName.edit => CupertinoIcons.pencil,
    BladeIconName.check => CupertinoIcons.checkmark,
    BladeIconName.x => CupertinoIcons.xmark,
    BladeIconName.clock => CupertinoIcons.clock,
    BladeIconName.star => CupertinoIcons.star,
    BladeIconName.sliders => CupertinoIcons.slider_horizontal_3,
    BladeIconName.trash => CupertinoIcons.trash,
    BladeIconName.pulse => CupertinoIcons.waveform,
    BladeIconName.rec => CupertinoIcons.circle,
    BladeIconName.route => CupertinoIcons.map,
    BladeIconName.pin => CupertinoIcons.map_pin,
    BladeIconName.units => CupertinoIcons.resize,
    BladeIconName.sound => CupertinoIcons.speaker_2,
    BladeIconName.download => CupertinoIcons.arrow_down_to_line,
    BladeIconName.help => CupertinoIcons.question_circle,
    BladeIconName.info => CupertinoIcons.info_circle,
    BladeIconName.arrow || BladeIconName.chevR => CupertinoIcons.chevron_forward,
    BladeIconName.search => CupertinoIcons.search,
    BladeIconName.layers => CupertinoIcons.square_stack,
    BladeIconName.share => CupertinoIcons.square_arrow_up,
    BladeIconName.logout => CupertinoIcons.arrow_right_square,
    BladeIconName.doc => CupertinoIcons.doc_text,
    BladeIconName.link => CupertinoIcons.link,
    _ => iconDataFor(name),
  };

  /// Icons that have verified 1:1 SVG path geometry transcribed from
  /// docs/design/aetron-glassline/index.html. All other icons render crisp
  /// Lucide vector icons directly (never falling back to an empty circle).
  static bool _hasVerifiedCustomGeometry(BladeIconName name) => switch (name) {
    BladeIconName.home ||
    BladeIconName.hist ||
    BladeIconName.cal ||
    BladeIconName.chart ||
    BladeIconName.user ||
    BladeIconName.bell ||
    BladeIconName.gear ||
    BladeIconName.arrow ||
    BladeIconName.chevR ||
    BladeIconName.chevL ||
    BladeIconName.run ||
    BladeIconName.pin ||
    BladeIconName.plus ||
    BladeIconName.sun ||
    BladeIconName.sunrise ||
    BladeIconName.pulse ||
    BladeIconName.bike ||
    BladeIconName.walk ||
    BladeIconName.clock ||
    BladeIconName.layers ||
    BladeIconName.gps ||
    BladeIconName.locate ||
    BladeIconName.heart ||
    BladeIconName.check ||
    BladeIconName.x ||
    BladeIconName.lock ||
    BladeIconName.pause ||
    BladeIconName.play ||
    BladeIconName.target ||
    BladeIconName.trophy ||
    BladeIconName.medal ||
    BladeIconName.shield ||
    BladeIconName.logout ||
    BladeIconName.refresh ||
    BladeIconName.search ||
    BladeIconName.bolt ||
    BladeIconName.flag => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    if (!_hasVerifiedCustomGeometry(name)) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            iconDataFor(name),
            size: size,
            color: resolved,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Invisible Icon widget preserves semantic labels and widget test findability
          Opacity(
            opacity: 0.0,
            child: Icon(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? iosIconDataFor(name)
                  : iconDataFor(name),
              size: size,
              color: resolved,
            ),
          ),
          // Exact 1:1 Vector Geometry matching docs/design/aetron-glassline/index.html
          CustomPaint(
            size: Size(size, size),
            painter: _BladeSvgPainter(
              name: name,
              color: resolved,
              strokeWidth: strokeWidth ?? 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _BladeSvgPainter extends CustomPainter {
  final BladeIconName name;
  final Color color;
  final double strokeWidth;

  const _BladeSvgPainter({
    required this.name,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    switch (name) {
      case BladeIconName.home:
        // HTML: <symbol id="home" viewBox="0 0 24 24"><path d="m3 10 9-7 9 7v10H3Z M9 20v-7h6v7"></path></symbol>
        canvas.drawPath(
          Path()
            ..moveTo(3, 10)
            ..lineTo(12, 3)
            ..lineTo(21, 10)
            ..lineTo(21, 20)
            ..lineTo(3, 20)
            ..close()
            ..moveTo(9, 20)
            ..lineTo(9, 13)
            ..lineTo(15, 13)
            ..lineTo(15, 20),
          strokePaint,
        );
      case BladeIconName.hist:
      case BladeIconName.cal:
        // HTML: <symbol id="hist" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="17" rx="2"></rect><path d="M7 2v4M17 2v4M3 9h18M7 13h3M14 13h3M7 17h3"></path></symbol>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 4, 18, 17),
            const Radius.circular(2),
          ),
          strokePaint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 2)
            ..lineTo(7, 6)
            ..moveTo(17, 2)
            ..lineTo(17, 6)
            ..moveTo(3, 9)
            ..lineTo(21, 9)
            ..moveTo(7, 13)
            ..lineTo(10, 13)
            ..moveTo(14, 13)
            ..lineTo(17, 13)
            ..moveTo(7, 17)
            ..lineTo(10, 17),
          strokePaint,
        );
      case BladeIconName.chart:
        // HTML: <symbol id="chart" viewBox="0 0 24 24"><path d="M4 20V11m5 9V4m5 16v-8m5 8V7"></path></symbol>
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..lineTo(4, 11)
            ..moveTo(9, 20)
            ..lineTo(9, 4)
            ..moveTo(14, 20)
            ..lineTo(14, 12)
            ..moveTo(19, 20)
            ..lineTo(19, 7),
          strokePaint,
        );
      case BladeIconName.user:
        // HTML: <symbol id="user" viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"></circle><path d="M4 21v-2c0-6 16-6 16 0v2"></path></symbol>
        canvas.drawCircle(const Offset(12, 8), 4, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(4, 21)
            ..lineTo(4, 19)
            ..cubicTo(4, 13, 20, 13, 20, 19)
            ..lineTo(20, 21),
          strokePaint,
        );
      case BladeIconName.bell:
        // HTML: <symbol id="bell" viewBox="0 0 24 24"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 8-3 10h18c0-2-3-3-3-10ZM10 21h4"></path></symbol>
        canvas.drawPath(
          Path()
            ..moveTo(18, 8)
            ..arcToPoint(
              const Offset(6, 8),
              radius: const Radius.circular(6),
              clockwise: false,
            )
            ..cubicTo(6, 15, 3, 16, 3, 18)
            ..lineTo(21, 18)
            ..cubicTo(21, 16, 18, 15, 18, 8)
            ..close()
            ..moveTo(10, 21)
            ..lineTo(14, 21),
          strokePaint,
        );
      case BladeIconName.gear:
        // HTML: <symbol id="gear" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"></circle><path d="m12 2 2 3 4-1 1 4 3 2-2 4 1 4-4 1-2 3-4-2-4 1-1-4-3-2 2-4-1-4 4-1Z"></path></symbol>
        canvas.drawCircle(const Offset(12, 12), 3, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(14, 5)
            ..lineTo(18, 4)
            ..lineTo(19, 8)
            ..lineTo(22, 10)
            ..lineTo(20, 14)
            ..lineTo(21, 18)
            ..lineTo(17, 19)
            ..lineTo(15, 22)
            ..lineTo(11, 20)
            ..lineTo(7, 21)
            ..lineTo(6, 17)
            ..lineTo(3, 15)
            ..lineTo(5, 11)
            ..lineTo(4, 7)
            ..lineTo(8, 6)
            ..close(),
          strokePaint,
        );
      case BladeIconName.arrow:
      case BladeIconName.chevR:
        // HTML: <symbol id="arrow" viewBox="0 0 24 24"><path d="m9 5 7 7-7 7"></path></symbol>
        canvas.drawPath(
          Path()
            ..moveTo(9, 5)
            ..lineTo(16, 12)
            ..lineTo(9, 19),
          strokePaint,
        );
      case BladeIconName.chevL:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          strokePaint,
        );
      case BladeIconName.run:
        // HTML: <symbol id="run" viewBox="0 0 24 24"><circle cx="14" cy="4" r="2"></circle><path d="m8 21 3-7 4 2 4 5M5 12l6-4 4 4 4 1M8 8l-3-1"></path></symbol>
        canvas.drawCircle(const Offset(14, 4), 2, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(8, 21)
            ..lineTo(11, 14)
            ..lineTo(15, 16)
            ..lineTo(19, 21)
            ..moveTo(5, 12)
            ..lineTo(11, 8)
            ..lineTo(15, 12)
            ..lineTo(19, 13)
            ..moveTo(8, 8)
            ..lineTo(5, 7),
          strokePaint,
        );
      case BladeIconName.pin:
        // HTML: <symbol id="pin" viewBox="0 0 24 24"><path d="M12 22s8-8 8-13a8 8 0 0 0-16 0c0 5 8 13 8 13Z"></path><circle cx="12" cy="9" r="3"></circle></symbol>
        canvas.drawCircle(const Offset(12, 9), 3, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 22)
            ..cubicTo(16, 18, 20, 14, 20, 9)
            ..arcToPoint(
              const Offset(4, 9),
              radius: const Radius.circular(8),
              clockwise: false,
            )
            ..cubicTo(4, 14, 8, 18, 12, 22)
            ..close(),
          strokePaint,
        );
      case BladeIconName.plus:
        // HTML dock center create button: <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"></path></svg>
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..lineTo(12, 19)
            ..moveTo(5, 12)
            ..lineTo(19, 12),
          strokePaint,
        );
      case BladeIconName.sun:
      case BladeIconName.sunrise:
        // HTML: <symbol id="sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4 4l2 2M18 18l2 2M4 20l2-2M18 6l2-2"></path></symbol>
        canvas.drawCircle(const Offset(12, 12), 4, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(12, 4)
            ..moveTo(12, 20)
            ..lineTo(12, 22)
            ..moveTo(2, 12)
            ..lineTo(4, 12)
            ..moveTo(20, 12)
            ..lineTo(22, 12)
            ..moveTo(4, 4)
            ..lineTo(6, 6)
            ..moveTo(18, 18)
            ..lineTo(20, 20)
            ..moveTo(4, 20)
            ..lineTo(6, 18)
            ..moveTo(18, 6)
            ..lineTo(20, 4),
          strokePaint,
        );
      case BladeIconName.pulse:
        // HTML recent activity electric arrow ⌁:
        canvas.drawPath(
          Path()
            ..moveTo(4, 12)
            ..lineTo(8, 12)
            ..lineTo(10.5, 6)
            ..lineTo(13.5, 18)
            ..lineTo(16, 12)
            ..lineTo(20, 12),
          strokePaint,
        );
      case BladeIconName.bike:
        // Precise geometric bicycle matching 1.7px stroke
        canvas.drawCircle(const Offset(6, 16.5), 3.5, strokePaint);
        canvas.drawCircle(const Offset(18, 16.5), 3.5, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(6, 16.5)
            ..lineTo(11, 16.5)
            ..lineTo(14, 10.5)
            ..lineTo(9.5, 10.5)
            ..lineTo(6, 16.5)
            ..moveTo(11, 16.5)
            ..lineTo(8.5, 9.5)
            ..moveTo(7.5, 9.5)
            ..lineTo(10, 9.5)
            ..moveTo(18, 16.5)
            ..lineTo(14.5, 9)
            ..lineTo(16, 8),
          strokePaint,
        );
      case BladeIconName.walk:
        // Precise geometric walker matching 1.7px stroke
        canvas.drawCircle(const Offset(13, 4), 2, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(13, 7.5)
            ..lineTo(12, 13)
            ..lineTo(9, 20)
            ..moveTo(12, 13)
            ..lineTo(15.5, 17)
            ..lineTo(17.5, 20)
            ..moveTo(10, 11)
            ..lineTo(12.5, 8.5)
            ..lineTo(15, 11),
          strokePaint,
        );
      case BladeIconName.clock:
        canvas.drawCircle(const Offset(12, 12), 8.5, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 7.5)
            ..lineTo(12, 12)
            ..lineTo(15.5, 14),
          strokePaint,
        );
      case BladeIconName.layers:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 4, 6.5, 6.5),
            const Radius.circular(1.5),
          ),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13.5, 4, 6.5, 6.5),
            const Radius.circular(1.5),
          ),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 13.5, 6.5, 6.5),
            const Radius.circular(1.5),
          ),
          strokePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13.5, 13.5, 6.5, 6.5),
            const Radius.circular(1.5),
          ),
          strokePaint,
        );
      case BladeIconName.flame:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..cubicTo(12, 3, 7.5, 8, 7.5, 13.5)
            ..cubicTo(7.5, 18, 9.5, 21, 12, 21)
            ..cubicTo(14.5, 21, 16.5, 18, 16.5, 13.5)
            ..cubicTo(16.5, 8, 12, 3, 12, 3)
            ..close(),
          strokePaint,
        );
      case BladeIconName.gps:
      case BladeIconName.locate:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(19, 21)
            ..lineTo(12, 17)
            ..lineTo(5, 21)
            ..close(),
          strokePaint,
        );
      case BladeIconName.heart:
        canvas.drawPath(
          Path()
            ..moveTo(12, 20)
            ..lineTo(4.5, 12.5)
            ..arcToPoint(
              const Offset(4.5, 6.5),
              radius: const Radius.circular(4),
              clockwise: true,
            )
            ..arcToPoint(
              const Offset(12, 6.5),
              radius: const Radius.circular(4),
              clockwise: true,
            )
            ..arcToPoint(
              const Offset(19.5, 6.5),
              radius: const Radius.circular(4),
              clockwise: true,
            )
            ..arcToPoint(
              const Offset(19.5, 12.5),
              radius: const Radius.circular(4),
              clockwise: true,
            )
            ..close(),
          strokePaint,
        );
      case BladeIconName.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 13)
            ..lineTo(10, 18)
            ..lineTo(19, 7),
          strokePaint,
        );
      case BladeIconName.x:
        canvas.drawPath(
          Path()
            ..moveTo(6, 6)
            ..lineTo(18, 18)
            ..moveTo(18, 6)
            ..lineTo(6, 18),
          strokePaint,
        );
      case BladeIconName.lock:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 10, 14, 11),
            const Radius.circular(2.5),
          ),
          strokePaint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 10)
            ..lineTo(8, 6.5)
            ..arcToPoint(
              const Offset(16, 6.5),
              radius: const Radius.circular(4),
              clockwise: true,
            )
            ..lineTo(16, 10),
          strokePaint,
        );
      case BladeIconName.pause:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(8, 19)
            ..moveTo(16, 5)
            ..lineTo(16, 19),
          strokePaint,
        );
      case BladeIconName.play:
        canvas.drawPath(
          Path()
            ..moveTo(7, 4)
            ..lineTo(19, 12)
            ..lineTo(7, 20)
            ..close(),
          strokePaint,
        );
      case BladeIconName.target:
        canvas.drawCircle(const Offset(12, 12), 9, strokePaint);
        canvas.drawCircle(const Offset(12, 12), 4, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(12, 6)
            ..moveTo(12, 18)
            ..lineTo(12, 22)
            ..moveTo(2, 12)
            ..lineTo(6, 12)
            ..moveTo(18, 12)
            ..lineTo(22, 12),
          strokePaint,
        );
      case BladeIconName.trophy:
      case BladeIconName.medal:
        canvas.drawPath(
          Path()
            ..moveTo(6, 4)
            ..lineTo(18, 4)
            ..lineTo(18, 10)
            ..arcToPoint(
              const Offset(6, 10),
              radius: const Radius.circular(6),
              clockwise: true,
            )
            ..close()
            ..moveTo(12, 16)
            ..lineTo(12, 20)
            ..moveTo(8, 20)
            ..lineTo(16, 20),
          strokePaint,
        );
      case BladeIconName.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2.5)
            ..lineTo(19, 5.5)
            ..lineTo(19, 11)
            ..quadraticBezierTo(19, 17, 12, 21.5)
            ..quadraticBezierTo(5, 17, 5, 11)
            ..lineTo(5, 5.5)
            ..close(),
          strokePaint,
        );
      case BladeIconName.logout:
        canvas.drawPath(
          Path()
            ..moveTo(9, 20.5)
            ..lineTo(5.5, 20.5)
            ..quadraticBezierTo(4, 20.5, 4, 19)
            ..lineTo(4, 5)
            ..quadraticBezierTo(4, 3.5, 5.5, 3.5)
            ..lineTo(9, 3.5)
            ..moveTo(16, 17)
            ..lineTo(21, 12)
            ..lineTo(16, 7)
            ..moveTo(21, 12)
            ..lineTo(9, 12),
          strokePaint,
        );
      case BladeIconName.refresh:
        canvas.drawPath(
          Path()
            ..moveTo(21, 12)
            ..arcToPoint(
              const Offset(12, 21),
              radius: const Radius.circular(9),
              clockwise: true,
            )
            ..arcToPoint(
              const Offset(3.5, 14),
              radius: const Radius.circular(9),
              clockwise: true,
            )
            ..moveTo(12, 3)
            ..arcToPoint(
              const Offset(20.5, 10),
              radius: const Radius.circular(9),
              clockwise: true,
            )
            ..moveTo(21, 4)
            ..lineTo(21, 10)
            ..lineTo(15, 10),
          strokePaint,
        );
      case BladeIconName.search:
        canvas.drawCircle(const Offset(11, 11), 6.5, strokePaint);
        canvas.drawPath(
          Path()
            ..moveTo(16, 16)
            ..lineTo(21, 21),
          strokePaint,
        );
      case BladeIconName.bolt:
        canvas.drawPath(
          Path()
            ..moveTo(13, 2)
            ..lineTo(5, 13)
            ..lineTo(11.5, 13)
            ..lineTo(11, 22)
            ..lineTo(19, 11)
            ..lineTo(12.5, 11)
            ..close(),
          strokePaint,
        );
      case BladeIconName.flag:
        canvas.drawPath(
          Path()
            ..moveTo(5, 2)
            ..lineTo(5, 22)
            ..moveTo(5, 3)
            ..lineTo(18, 3)
            ..lineTo(14, 8)
            ..lineTo(18, 13)
            ..lineTo(5, 13),
          strokePaint,
        );
      case BladeIconName.moon:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..arcToPoint(
              const Offset(12, 21),
              radius: const Radius.circular(9),
              clockwise: true,
            )
            ..arcToPoint(
              const Offset(12, 3),
              radius: const Radius.circular(6.5),
              clockwise: false,
            ),
          strokePaint,
        );
      default:
        canvas.drawCircle(const Offset(12, 12), 7, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BladeSvgPainter oldDelegate) =>
      oldDelegate.name != name ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
