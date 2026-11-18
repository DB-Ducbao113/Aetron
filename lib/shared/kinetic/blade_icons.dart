import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Unified icon system backed by `flutter_lucide` (clean 2px geometric strokes)
/// and crisp sport glyphs, replacing the legacy custom-drawn `BladeIcon` paths.
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
        BladeIconName.sunrise => LucideIcons.sun,
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
        BladeIconName.chevR => LucideIcons.chevron_right,
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

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return Icon(
      iconDataFor(name),
      size: size,
      color: resolved,
    );
  }
}
