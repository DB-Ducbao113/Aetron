import 'dart:ui' show ImageFilter;

import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';

/// Clean modern surface card:
/// - Light mode: pure white (#FFFFFF) with subtle whisper elevation (borderless unless specified)
/// - Dark mode: elevated charcoal (#16161A) separated by tonal contrast
class KineticCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? topAccentColor;
  final Color? glowColor;
  final bool hasGlow;
  final double borderRadius;
  final String? semanticLabel;
  final Gradient? gradient;
  final bool useLiquidGlass;

  const KineticCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KineticTokens.spaceMD),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.topAccentColor,
    this.glowColor,
    this.hasGlow = false,
    this.borderRadius = KineticTokens.radiusLG,
    this.semanticLabel,
    this.gradient,
    this.useLiquidGlass = false,
  });

  @override
  State<KineticCard> createState() => _KineticCardState();
}

class _KineticCardState extends State<KineticCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final backgroundColor = widget.backgroundColor;
    final borderRadius = widget.borderRadius;
    final padding = widget.padding;
    final margin = widget.margin;
    final gradient = widget.gradient;
    final borderColor = widget.borderColor;
    final hasGlow = widget.hasGlow;
    final glowColor = widget.glowColor;
    final topAccentColor = widget.topAccentColor;
    final onTap = widget.onTap;
    final semanticLabel = widget.semanticLabel;
    final child = widget.child;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = backgroundColor ?? colors.surface1;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(borderRadius);

    Widget content;
    if (widget.useLiquidGlass && ios && !highContrast) {
      final glassGradient =
          gradient ??
          (isLight
              ? const LinearGradient(
                  begin: Alignment(-0.7, -1.0),
                  end: Alignment(0.8, 1.0),
                  colors: [
                    Color(0xB8F6FBFF),
                    Color(0x8CF0F7FF),
                    Color(0x6EC6E0FA),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment(-0.7, -1.0),
                  end: Alignment(0.8, 1.0),
                  colors: [
                    Color(0xAD2E4A6B),
                    Color(0x961D314A),
                    Color(0xA6192C44),
                  ],
                ));
      final glassBorder =
          borderColor ??
          (isLight
              ? Colors.white.withValues(alpha: 0.90)
              : const Color(0x54ACD8FF));
      final sigma = isLight ? 18.0 : 20.0;

      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? const Color(0x21235189)
                  : const Color(0x5900091C),
              blurRadius: isLight ? 22 : 27,
              offset: Offset(0, isLight ? 9 : 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: glassGradient,
                      borderRadius: radius,
                      border: Border.all(color: glassBorder, width: 1.0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ],
          ),
        ),
      );
    } else {
      content = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: radius,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : Border.all(
                  color: isLight
                      ? colors.borderSubtle
                      : const Color(0xFF34495F),
                  width: 1.0,
                ),
          boxShadow: ios
              ? (isLight
                    ? KineticTokens.shadowCardLight()
                    : KineticTokens.shadowCardDark())
              : hasGlow
              ? [
                  BoxShadow(
                    color: (glowColor ?? colors.primary).withValues(
                      alpha: 0.14,
                    ),
                    blurRadius: 18,
                    spreadRadius: -2,
                  ),
                ]
              : (isLight
                    ? KineticTokens.shadowCardLight()
                    : KineticTokens.shadowCardDark()),
        ),
        child: child,
      );
    }

    if (topAccentColor != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: Container(color: topAccentColor),
            ),
          ),
        ],
      );
    }

    content = KineticSurfaceFinish(
      radius: borderRadius,
      pressed: _pressed && onTap != null,
      contentSurface: true,
      scaleOnPress: onTap != null,
      child: content,
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onHighlightChanged: ios
              ? (value) => setState(() => _pressed = value)
              : null,
          borderRadius: radius,
          splashFactory: ios ? NoSplash.splashFactory : null,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin, child: content);
    }

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: content,
      );
    }

    return content;
  }
}
