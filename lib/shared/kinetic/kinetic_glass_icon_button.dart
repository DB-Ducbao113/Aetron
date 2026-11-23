import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';

import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adaptive circular action button. On iOS, a translucent material and
/// specular edge give floating controls depth; Android keeps an opaque surface.
class KineticGlassIconButton extends StatefulWidget {
  const KineticGlassIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 37.0,
    this.visualSize = 37.0,
    this.active = false,
    this.blurBackdrop = true,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final double size;
  final double? visualSize;
  final bool active;
  final bool blurBackdrop;

  @override
  State<KineticGlassIconButton> createState() => _KineticGlassIconButtonState();
}

class _KineticGlassIconButtonState extends State<KineticGlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final onPressed = widget.onPressed;
    final size = widget.size;
    final visualSize =
        widget.visualSize ??
        (size < 37.0 ? size : 37.0);
    final active = widget.active;
    final blurBackdrop = widget.blurBackdrop;
    final colors = context.kinetic;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final highContrast = MediaQuery.highContrastOf(context);
    final useBlur = blurBackdrop && !highContrast;
    final glyph = icon;
    if (NativeLiquidGlass.enabledOf(context) && glyph is BladeIcon) {
      final symbol = switch (glyph.name) {
        BladeIconName.home => 'house',
        BladeIconName.user => 'person.crop.circle',
        BladeIconName.bell => 'bell',
        BladeIconName.chevL => 'chevron.backward',
        BladeIconName.chevR => 'chevron.forward',
        BladeIconName.gear => 'gearshape',
        BladeIconName.map => 'map',
        BladeIconName.chart => 'chart.bar',
        BladeIconName.gps => active ? 'location.fill' : 'location',
        BladeIconName.locate => 'location.viewfinder',
        BladeIconName.refresh => 'arrow.clockwise',
        BladeIconName.heart => 'heart',
        BladeIconName.flag => 'flag',
        BladeIconName.cam => 'camera',
        BladeIconName.pause => 'pause.fill',
        BladeIconName.play => 'play.fill',
        BladeIconName.route =>
          'point.topleft.down.to.point.bottomright.curvepath',
        BladeIconName.pin => 'mappin.and.ellipse',
        BladeIconName.target => 'scope',
        BladeIconName.trophy => 'trophy',
        BladeIconName.medal => 'medal',
        BladeIconName.bolt => 'bolt.fill',
        BladeIconName.flame => 'flame.fill',
        BladeIconName.moon => 'moon',
        BladeIconName.sunrise => 'sun.max',
        BladeIconName.mail => 'envelope',
        BladeIconName.lock => 'lock.fill',
        BladeIconName.eye => 'eye',
        BladeIconName.shield => 'shield',
        BladeIconName.globe => 'globe',
        BladeIconName.units => 'ruler',
        BladeIconName.sound => 'speaker.wave.2',
        BladeIconName.export || BladeIconName.share => 'square.and.arrow.up',
        BladeIconName.download => 'arrow.down.to.line',
        BladeIconName.help => 'questionmark.circle',
        BladeIconName.info => 'info.circle',
        BladeIconName.trash => 'trash',
        BladeIconName.x => 'xmark',
        BladeIconName.plus => 'plus',
        BladeIconName.edit => 'pencil',
        BladeIconName.check => 'checkmark',
        BladeIconName.search => 'magnifyingglass',
        BladeIconName.layers => 'square.3.layers.3d',
        BladeIconName.clock => 'clock',
        BladeIconName.star => 'star',
        BladeIconName.sliders => 'slider.horizontal.3',
        BladeIconName.logout => 'rectangle.portrait.and.arrow.right',
        BladeIconName.doc => 'doc.text',
        BladeIconName.link => 'link',
        BladeIconName.run => 'figure.run',
        BladeIconName.bike => 'bicycle',
        BladeIconName.walk => 'figure.walk',
        _ => null,
      };
      if (symbol != null) {
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: SizedBox.square(
              dimension: visualSize,
              child: NativeGlassControl(
                properties: {
                  'kind': 'button',
                  'label': label,
                  'symbol': symbol,
                  'iconSize': glyph.size > 17 ? 17.0 : glyph.size,
                  'active': active,
                  'accent': colors.primary.toARGB32(),
                  'foreground': (glyph.color ?? colors.textPrimary).toARGB32(),
                  'dark': colors.isDark,
                  'reduceMotion': KineticTokens.reduceMotionOf(context),
                },
                onTap: (_) => onPressed(),
              ),
            ),
          ),
        );
      }
    }

    final border = active ? colors.primary : colors.borderStrong;
    void tap() {
      HapticFeedback.selectionClick();
      onPressed();
    }

    final Widget displayIcon;
    if (icon is BladeIcon && isIOS && icon.name == BladeIconName.gps) {
      displayIcon = Icon(
        active ? CupertinoIcons.location_fill : CupertinoIcons.location,
        size: icon.size,
        color: icon.color,
      );
    } else {
      displayIcon = icon;
    }
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: !highContrast
            ? (colors.isDark
                ? const Color(0x36314B6B)
                : const Color(0x73FFFFFF))
            : colors.surface1,
        gradient: !highContrast
            ? (colors.isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x26CAE9FF),
                      Color(0x1F314B6B),
                      Color(0x2E1A4781),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x9EFFFFFF),
                      Color(0x4DFFFFFF),
                      Color(0x264EABE7),
                    ],
                  ))
            : null,
        boxShadow: colors.isDark
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 13,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Color(0x1F1F406E),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
        border: Border.all(
          color: !highContrast
              ? (colors.isDark
                  ? (active ? colors.primary : const Color(0x4DB6DCFF))
                  : (active ? colors.primary : Colors.white.withValues(alpha: .90)))
              : border,
          width: 1.0,
        ),
      ),
      child: isIOS
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashFactory: NoSplash.splashFactory,
                onTap: tap,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                child: Center(child: displayIcon),
              ),
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: tap,
                child: Center(child: icon),
              ),
            ),
    );

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: SizedBox.square(
              dimension: visualSize,
              child: AnimatedScale(
                scale:
                    isIOS && _pressed && !KineticTokens.reduceMotionOf(context)
                    ? .96
                    : 1,
                duration: isIOS
                    ? KineticTokens.respectingReduceMotion(
                        context,
                        Duration(milliseconds: _pressed ? 90 : 210),
                      )
                    : Duration.zero,
                curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
                child: ClipOval(
                  child: useBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: surface,
                        )
                      : surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
