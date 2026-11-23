import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

enum KineticButtonVariant { primary, secondary, ghost, danger }

/// Unified Kinetic Button — the single button component for the app.
///
/// Features:
/// - 4 variants: primary, secondary, ghost, danger
/// - Consistent height from KineticTokens
/// - Loading state with spinner
/// - Built-in semantics for accessibility
/// - Material ink ripple feedback
/// - Primary variant: flat filled pill, no gradient/border/shadow (V5)
/// - 120ms press-scale micro-interaction (scale 0.97, easeOut)
///   with light haptic — instant under OS Reduce Motion
class KineticButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KineticButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final String? semanticLabel;

  const KineticButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = KineticButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = KineticTokens.buttonHeight,
    this.semanticLabel,
  });

  @override
  State<KineticButton> createState() => _KineticButtonState();
}

class _KineticButtonState extends State<KineticButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;
  late final Animation<double> _iosScale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Created once here — never in build().
    _pressController = AnimationController(
      vsync: this,
      duration: KineticTokens.motionPress,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: KineticTokens.motionPressCurve,
      ),
    );
    _iosScale = Tween<double>(begin: 1, end: .97).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleHighlightChanged(bool highlighted) {
    if (Theme.of(context).platform == TargetPlatform.iOS &&
        _pressed != highlighted) {
      setState(() => _pressed = highlighted);
    }
    if (KineticTokens.reduceMotionOf(context)) return;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      _pressController.animateTo(
        highlighted ? 1 : 0,
        duration: Duration(milliseconds: highlighted ? 90 : 210),
        curve: highlighted ? Curves.easeOutCubic : Curves.easeOutBack,
      );
      return;
    }
    if (highlighted) {
      _pressController.forward();
    } else {
      _pressController.reverse();
    }
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  String? _iosSymbol(IconData? icon) {
    if (icon == null) return null;
    if (icon == Icons.play_arrow_rounded || icon == LucideIcons.play) {
      return 'play.fill';
    }
    if (icon == Icons.check_rounded ||
        icon == Icons.check_circle_rounded ||
        icon == Icons.check_circle_outline_rounded) {
      return 'checkmark';
    }
    if (icon == Icons.shield_rounded) return 'shield';
    if (icon == Icons.arrow_forward_rounded) return 'arrow.forward';
    if (icon == Icons.send_rounded) return 'paperplane.fill';
    if (icon == Icons.refresh_rounded) return 'arrow.clockwise';
    if (icon == Icons.open_in_new_rounded) return 'arrow.up.forward.square';
    if (icon == Icons.logout_rounded) {
      return 'rectangle.portrait.and.arrow.right';
    }
    if (icon == Icons.lock_reset_rounded) return 'lock.rotation';
    if (icon == Icons.lock_open_rounded) return 'lock.open';
    if (icon == Icons.ios_share_rounded) return 'square.and.arrow.up';
    if (icon == Icons.insights_rounded) return 'chart.xyaxis.line';
    if (icon == Icons.menu_book_rounded) return 'book';
    if (icon == Icons.flag_rounded) return 'flag';
    if (icon == Icons.directions_walk_rounded) return 'figure.walk';
    if (icon == Icons.directions_run_rounded) return 'figure.run';
    if (icon == Icons.bolt_rounded) return 'bolt.fill';
    if (icon == Icons.add_rounded) return 'plus';
    if (icon == Icons.delete_outline_rounded) return 'trash';
    return null;
  }

  IconData _iosFallbackIcon(IconData icon) {
    if (icon == Icons.play_arrow_rounded || icon == LucideIcons.play) {
      return CupertinoIcons.play_fill;
    }
    if (icon == Icons.check_rounded ||
        icon == Icons.check_circle_rounded ||
        icon == Icons.check_circle_outline_rounded) {
      return CupertinoIcons.checkmark;
    }
    if (icon == Icons.arrow_forward_rounded) return CupertinoIcons.arrow_right;
    if (icon == Icons.send_rounded) return CupertinoIcons.paperplane_fill;
    if (icon == Icons.refresh_rounded) return CupertinoIcons.refresh;
    if (icon == Icons.open_in_new_rounded) {
      return CupertinoIcons.arrow_up_right_square;
    }
    if (icon == Icons.logout_rounded) return CupertinoIcons.arrow_right_square;
    if (icon == Icons.lock_open_rounded) return CupertinoIcons.lock_open;
    if (icon == Icons.ios_share_rounded) return CupertinoIcons.square_arrow_up;
    if (icon == Icons.menu_book_rounded) return CupertinoIcons.book;
    if (icon == Icons.flag_rounded) return CupertinoIcons.flag;
    if (icon == Icons.bolt_rounded) return CupertinoIcons.bolt_fill;
    if (icon == Icons.add_rounded) return CupertinoIcons.plus;
    if (icon == Icons.delete_outline_rounded) return CupertinoIcons.trash;
    return icon;
  }

  Widget _finish({
    required bool enabled,
    required double radius,
    required bool emphasis,
    required Widget child,
  }) => enabled
      ? KineticSurfaceFinish(
          radius: radius,
          emphasis: emphasis,
          pressed: _pressed,
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final nativeSymbol = _iosSymbol(widget.icon);

    if (NativeLiquidGlass.enabledOf(context) &&
        widget.isFullWidth &&
        widget.variant != KineticButtonVariant.ghost &&
        !widget.isLoading &&
        (widget.icon == null || nativeSymbol != null)) {
      final destructive = widget.variant == KineticButtonVariant.danger;
      final prominent =
          widget.variant == KineticButtonVariant.primary || destructive;
      return Semantics(
        button: true,
        enabled: !isDisabled,
        label: widget.semanticLabel ?? widget.label,
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: NativeGlassControl(
            properties: {
              'kind': 'action',
              'label': widget.label,
              'symbol': nativeSymbol ?? '',
              'prominent': prominent,
              'destructive': destructive,
              'enabled': !isDisabled,
              'accent': colors.primary.toARGB32(),
              'foreground': colors.textPrimary.toARGB32(),
              'dark': colors.isDark,
              'reduceMotion': KineticTokens.reduceMotionOf(context),
            },
            onTap: (_) {
              if (!isDisabled) widget.onPressed?.call();
            },
          ),
        ),
      );
    }

    final Color bgColor;
    final Color fgColor;
    final BorderSide? border;
    final List<BoxShadow>? shadows;
    final Gradient? gradient;

    switch (widget.variant) {
      case KineticButtonVariant.primary:
        // Pill button in Glassline sapphire blue liquid glass matching .phone .action:not(.alt)
        gradient = !isDisabled
            ? (isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xD166A9F8),
                      Color(0xCF296FD5),
                      Color(0xDB144FAB),
                    ],
                    stops: [0.0, 0.57, 1.0],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xC777BFFF),
                      Color(0xD42577EC),
                      Color(0xE31258CC),
                    ],
                    stops: [0.0, 0.56, 1.0],
                  ))
            : null;
        bgColor = isDisabled ? colors.surface3 : colors.primary;
        fgColor = isDisabled
            ? colors.textMuted
            : (isDark ? const Color(0xFFF9FCFF) : Colors.white);
        border = isIOS && !isDisabled
            ? BorderSide(
                color: isDark
                    ? const Color(0x6B9FD6FF)
                    : Colors.white.withValues(alpha: .70),
                width: 1.0,
              )
            : null;
        shadows = !isDisabled
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x4F041F4F)
                      : const Color(0xFF0F63C9).withValues(alpha: 0.22),
                  blurRadius: isDark ? 17 : 16,
                  offset: const Offset(0, 7),
                ),
              ]
            : null;
        break;
      case KineticButtonVariant.secondary:
        gradient = isIOS && !isDisabled
            ? (isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x2E74A5D8),
                      Color(0x211C2E46),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x73FFFFFF),
                      Color(0x38BDDEFF),
                    ],
                  ))
            : null;
        bgColor = isDisabled
            ? colors.surface1
            : (isDark ? const Color(0x244A6E96) : colors.surface1);
        fgColor = isDisabled
            ? colors.textMuted
            : (isDark ? const Color(0xFFD7E7FB) : colors.textPrimary);
        border = BorderSide(
          color: isIOS
              ? (isDark
                  ? const Color(0x45A0CBF5)
                  : Colors.white.withValues(alpha: .85))
              : colors.borderStrong,
          width: 1.0,
        );
        shadows = !isDisabled && isIOS
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.20)
                      : const Color(0xFF1F406E).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null;
        break;
      case KineticButtonVariant.ghost:
        gradient = null;
        bgColor = Colors.transparent;
        fgColor = isDisabled ? colors.textMuted : colors.textSecondary;
        border = null;
        shadows = null;
        break;
      case KineticButtonVariant.danger:
        gradient = null;
        bgColor = isDisabled
            ? colors.surface1
            : colors.error.withValues(alpha: 0.15);
        fgColor = isDisabled ? colors.textMuted : colors.error;
        border = BorderSide(
          color: colors.error.withValues(alpha: 0.4),
          width: 1,
        );
        shadows = null;
        break;
    }

    final content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: isIOS ? 16 : 18,
            height: isIOS ? 16 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          SizedBox(width: isIOS ? 7 : 10),
        ] else if (widget.icon != null) ...[
          Icon(
            isIOS ? _iosFallbackIcon(widget.icon!) : widget.icon,
            size: isIOS ? 16 : 18,
            color: fgColor,
          ),
          SizedBox(width: isIOS ? 6 : 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isIOS
                ? KineticTypography.label.copyWith(
                    color: fgColor,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  )
                : KineticTypography.label.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.semanticLabel ?? widget.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: KineticTokens.minTouchTarget,
          minWidth: widget.isFullWidth
              ? double.infinity
              : KineticTokens.minTouchTarget,
        ),
        child: ScaleTransition(
          scale: KineticTokens.reduceMotionOf(context)
              ? const AlwaysStoppedAnimation<double>(1)
              : isIOS
              ? _iosScale
              : _scale,
          child: _finish(
            enabled:
                !isDisabled && widget.variant != KineticButtonVariant.ghost,
            radius: KineticTokens.radiusPill,
            emphasis: widget.variant == KineticButtonVariant.primary,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: isIOS && !isDisabled && widget.variant != KineticButtonVariant.ghost && !highContrast
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: gradient == null ? bgColor : null,
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                          border: border != null ? Border.fromBorderSide(border) : null,
                          boxShadow: shadows,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isDisabled ? null : _handleTap,
                            onHighlightChanged: isDisabled
                                ? null
                                : _handleHighlightChanged,
                            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                            splashFactory: isIOS ? NoSplash.splashFactory : null,
                            splashColor: isIOS
                                ? Colors.transparent
                                : fgColor.withValues(alpha: 0.12),
                            highlightColor: fgColor.withValues(alpha: 0.06),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: isIOS ? 14 : 18),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: gradient == null ? bgColor : null,
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                        border: border != null ? Border.fromBorderSide(border) : null,
                        boxShadow: shadows,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isDisabled ? null : _handleTap,
                          onHighlightChanged: isDisabled
                              ? null
                              : _handleHighlightChanged,
                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                          splashFactory: isIOS ? NoSplash.splashFactory : null,
                          splashColor: isIOS
                              ? Colors.transparent
                              : fgColor.withValues(alpha: 0.12),
                          highlightColor: fgColor.withValues(alpha: 0.06),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: isIOS ? 14 : 18),
                            child: content,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
