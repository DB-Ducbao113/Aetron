import 'package:flutter/material.dart';

export 'app_button.dart';
export 'app_card.dart';
export 'app_states.dart';
export 'aetron_skeleton.dart';
export 'aetron_globe_orbit_screen.dart';

class AetronColors {
  const AetronColors._();

  // Core Palette - Kinetic Aligned
  static const voidBlack = Color(0xFF0C1113);
  static const space = Color(0xFF12181B);
  static const panel = Color(0xFF192226);
  static const panelHigh = Color(0xFF192226);
  static const panelBright = Color(0xFF222F35);
  static const cyan = Color(0xFFA8DCE7);
  static const cyanDim = Color(0xFF7CB8C4);
  static const cyanSoft = Color(0xFFE2F4F7);
  static const blue = Color(0xFFA8DCE7);
  static const gold = Color(0xFFFFD54F);
  static const mint = Color(0xFF2AF598);
  static const danger = Color(0xFFFF5252);
  static const muted = Color(0xFF75838A);
  static const text = Color(0xFFF3F7F8);
  static const border = Color(0x14ffffff);

  // Semantic Tokens
  static const primary = cyan;
  static const secondary = mint;
  static const background = voidBlack;
  static const surface = space;
  static const card = panel;
  static const cardElevated = panelHigh;
  static const textPrimary = text;
  static const textSecondary = muted;
  static const borderSubtle = Color(0x14ffffff);
  static const borderAccent = Color(0x28A8DCE7);
  static const success = mint;
  static const warning = gold;
  static const error = danger;
  static const disabled = Color(0xff334155);
  static const workoutActive = mint;
}

class AetronSpacing {
  const AetronSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const page = 16.0;
  static const gutter = 12.0;
  static const cardRadius = 18.0;
  static const controlRadius = 14.0;
}

class AetronRadius {
  const AetronRadius._();

  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 18.0;
  static const double extraLarge = 24.0;
  static const double pill = 999.0;
}

class AetronTypography {
  const AetronTypography._();

  static const String fontFamily = 'BeVietnamPro';

  static const display = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.6,
  );

  static const headingLarge = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static const headingMedium = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const headingSmall = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.cyan,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const bodySmall = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    color: AetronColors.space,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );
}

class AetronGlassCard extends StatelessWidget {
  const AetronGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = AetronSpacing.cardRadius,
    this.borderColor = AetronColors.border,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Ink(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AetronColors.panel.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AetronColors.cyan.withValues(alpha: 0.07),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}
