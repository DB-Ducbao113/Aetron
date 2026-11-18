import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';

/// Clean modern surface card:
/// - Light mode: pure white (#FFFFFF) with subtle whisper elevation (borderless unless specified)
/// - Dark mode: elevated charcoal (#16161A) separated by tonal contrast
class KineticCard extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = backgroundColor ?? colors.surface1;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : (isLight
                ? null
                : Border.all(
                    color: colors.borderSubtle.withValues(alpha: 0.5),
                    width: 0.5,
                  )),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: (glowColor ?? colors.primary).withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : (isLight ? KineticTokens.shadowCardLight() : null),
      ),
      child: child,
    );

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

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
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
