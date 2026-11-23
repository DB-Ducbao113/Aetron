import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 52.0,
    this.fontSize,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final double? fontSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = AetronColors.primary;
        fg = AetronColors.space;
        border = null;
        break;
      case AppButtonVariant.secondary:
        bg = AetronColors.panelHigh;
        fg = AetronColors.cyanSoft;
        border = BorderSide(color: AetronColors.cyan.withValues(alpha: 0.3));
        break;
      case AppButtonVariant.outlined:
        bg = Colors.transparent;
        fg = AetronColors.primary;
        border = const BorderSide(color: AetronColors.primary);
        break;
      case AppButtonVariant.danger:
        bg = AetronColors.danger.withValues(alpha: 0.2);
        fg = AetronColors.danger;
        border = BorderSide(color: AetronColors.danger.withValues(alpha: 0.6));
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AetronColors.textSecondary;
        border = null;
        break;
    }

    if (isDisabled && variant == AppButtonVariant.primary) {
      bg = AetronColors.disabled;
      fg = AetronColors.textSecondary;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: AetronColors.panelBright.withValues(alpha: 0.4),
      disabledForegroundColor: AetronColors.textSecondary.withValues(
        alpha: 0.5,
      ),
      elevation: !ios && variant == AppButtonVariant.primary ? 4 : 0,
      shadowColor: !ios && variant == AppButtonVariant.primary
          ? AetronColors.primary.withValues(alpha: 0.3)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ios ? 999 : AetronRadius.medium),
        side: border ?? BorderSide.none,
      ),
    );

    Widget childWidget;
    if (isLoading) {
      childWidget = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else if (icon != null) {
      childWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              ios ? label : label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AetronTypography.button.copyWith(
                color: fg,
                fontSize: fontSize ?? 15,
              ),
            ),
          ),
        ],
      );
    } else {
      childWidget = Text(
        ios ? label : label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AetronTypography.button.copyWith(
          color: fg,
          fontSize: fontSize ?? 15,
        ),
      );
    }

    final button = SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: childWidget,
      ),
    );

    return button;
  }
}
