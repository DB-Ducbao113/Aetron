import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_gradients.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum KineticButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

/// Unified Kinetic Button — the single button component for the app.
///
/// Features:
/// - 4 variants: primary, secondary, ghost, danger
/// - Consistent height from KineticTokens
/// - Loading state with spinner
/// - Built-in semantics for accessibility
/// - Material ink ripple feedback
/// - Primary variant: lit cyan gradient + bright edge + soft shadow (board v3)
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
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleHighlightChanged(bool highlighted) {
    if (KineticTokens.reduceMotionOf(context)) return;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    final Color bgColor;
    final Color fgColor;
    final BorderSide? border;
    final List<BoxShadow>? shadows;
    final Gradient? gradient;

    switch (widget.variant) {
      case KineticButtonVariant.primary:
        // Board v3: lit cyan gradient pill, bright 1.5px edge, soft cyan
        // shadow. The gradient is a brand object — identical in dark and
        // light ("Morning") themes, so the ink on it is a fixed dark teal,
        // NOT onPrimary (which is white in the light palette).
        gradient = isDisabled ? null : KineticGradients.buttonPrimary(colors);
        bgColor = isDisabled ? colors.surface3 : colors.primary;
        fgColor = isDisabled ? colors.textMuted : const Color(0xFF06222B);
        border = isDisabled
            ? null
            : BorderSide(
                color: Color.lerp(colors.accentFill, Colors.white, 0.78)!,
                width: 1.5,
              );
        shadows = isDisabled
            ? null
            : [
                BoxShadow(
                  color: colors.accentFill.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                  spreadRadius: -10,
                ),
              ];
        break;
      case KineticButtonVariant.secondary:
        // Board v3 secondary: surface fill + strong 1.5px edge.
        gradient = null;
        bgColor = isDisabled ? colors.surface1 : colors.surface2;
        fgColor = isDisabled ? colors.textMuted : colors.textPrimary;
        border = BorderSide(color: colors.borderStrong, width: 1.5);
        shadows = null;
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
        bgColor = isDisabled ? colors.surface1 : colors.error.withValues(alpha: 0.15);
        fgColor = isDisabled ? colors.textMuted : colors.error;
        border = BorderSide(color: colors.error.withValues(alpha: 0.4), width: 1);
        shadows = null;
        break;
    }

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KineticTypography.label.copyWith(
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
          scale: _scale,
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
                onHighlightChanged: isDisabled ? null : _handleHighlightChanged,
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                splashColor: fgColor.withValues(alpha: 0.12),
                highlightColor: fgColor.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
