import 'dart:ui';

import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared Glassline V3 frosted liquid-glass bottom sheet container.
class KineticGlassBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final bool floating;
  final bool showHandle;
  final bool respectViewInsets;
  final double? maxHeightFactor;

  const KineticGlassBottomSheet({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 28,
    this.borderColor,
    this.floating = false,
    this.showHandle = true,
    this.respectViewInsets = true,
    this.maxHeightFactor = 0.88,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final viewInsetsBottom = respectViewInsets
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final BorderRadius resolvedRadius = floating
        ? BorderRadius.circular(borderRadius)
        : BorderRadius.vertical(top: Radius.circular(borderRadius));

    final EdgeInsetsGeometry resolvedMargin =
        margin ??
        (floating
            ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
            : EdgeInsets.zero);

    final Color effectiveBorderColor =
        borderColor ??
        (colors.isDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.88));

    final Widget sheetBody = SafeArea(
      top: false,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );

    // Disable native UiKitView platform views inside modal bottom sheets so
    // iOS 26 Impeller never creates split FlutterOverlayView layers that clip
    // Flutter content placed after a button/orb inside the sheet.
    final Widget frostedBackground = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? [
                  colors.surface1.withValues(alpha: 0.90),
                  colors.surface2.withValues(alpha: 0.84),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  colors.surface1.withValues(alpha: 0.86),
                ],
        ),
        borderRadius: resolvedRadius,
        border: floating
            ? Border.all(color: effectiveBorderColor, width: 1.1)
            : Border(
                top: BorderSide(color: effectiveBorderColor, width: 1.1),
                left: BorderSide(color: effectiveBorderColor, width: 0.6),
                right: BorderSide(color: effectiveBorderColor, width: 0.6),
              ),
      ),
    );

    Widget glassContainer = NativeLiquidGlassScope(
      enabled: false,
      child: Container(
        margin: resolvedMargin,
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          boxShadow: KineticTokens.shadowPanel(const Color(0xFF0F172A)),
        ),
        child: ClipRRect(
          borderRadius: resolvedRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: frostedBackground,
                ),
              ),
              sheetBody,
            ],
          ),
        ),
      ),
    );

    if (maxHeightFactor != null) {
      glassContainer = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * maxHeightFactor!,
        ),
        child: glassContainer,
      );
    }

    if (viewInsetsBottom > 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: glassContainer,
      );
    }
    return glassContainer;
  }
}

/// Shared Glassline V3 frosted liquid-glass modal dialog.
class KineticGlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? child;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  const KineticGlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.child,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final resolvedRadius = BorderRadius.circular(24);
    final effectiveBorderColor =
        borderColor ??
        (colors.isDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.92));

    final Widget dialogBody = Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child:
          child ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                title!,
                const SizedBox(height: 12),
              ],
              if (content != null) ...[
                Flexible(child: SingleChildScrollView(child: content!)),
                const SizedBox(height: 20),
              ],
              if (actions.isNotEmpty)
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions,
                ),
            ],
          ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: NativeLiquidGlassScope(
        enabled: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: resolvedRadius,
            boxShadow: KineticTokens.shadowPanel(const Color(0xFF0F172A)),
          ),
          child: ClipRRect(
            borderRadius: resolvedRadius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // High-legibility frosted Glassline modal surface so dark dialog
                // barrier scrims never wash out light-mode dialogs into muddy grey.
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors.isDark
                              ? [
                                  colors.surface1.withValues(alpha: 0.94),
                                  colors.surface2.withValues(alpha: 0.90),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.95),
                                  colors.surface1.withValues(alpha: 0.91),
                                ],
                        ),
                        borderRadius: resolvedRadius,
                        border: Border.all(
                          color: effectiveBorderColor,
                          width: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                dialogBody,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted inner option tile for Glassline V3 sheets (Security, Language, Units, Theme).
class KineticGlassOptionTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final bool isSelected;
  final bool isDestructive;
  final bool showChevron;
  final VoidCallback? onTap;

  const KineticGlassOptionTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.isSelected = false,
    this.isDestructive = false,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveColor = isDestructive
        ? colors.error
        : (accentColor ?? colors.primary);

    final Color bgColor = isSelected
        ? effectiveColor.withValues(alpha: colors.isDark ? 0.18 : 0.10)
        : (colors.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.65));

    final Color rimColor = isSelected
        ? effectiveColor.withValues(alpha: 0.55)
        : (isDestructive
              ? colors.error.withValues(alpha: 0.28)
              : (colors.isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : colors.borderSubtle));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: rimColor,
              width: isSelected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: effectiveColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.30),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 19),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.bodyMedium.copyWith(
                        color: isDestructive
                            ? colors.error
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: effectiveColor,
                  size: 20,
                ),
              ] else if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(
                  Theme.of(context).platform == TargetPlatform.iOS
                      ? CupertinoIcons.chevron_forward
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
