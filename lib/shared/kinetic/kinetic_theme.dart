import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'kinetic_tokens.dart';
export 'kinetic_skeleton.dart';
export 'kinetic_entrance.dart';

class KineticTheme {
  const KineticTheme._();

  static ThemeData get darkTheme => buildTheme(Brightness.dark);
  static ThemeData get lightTheme => buildTheme(Brightness.light);

  static ThemeData buildTheme(
    Brightness brightness, {
    TargetPlatform? platform,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final ios = target == TargetPlatform.iOS;
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? KineticColors.dark : KineticColors.light;

    return ThemeData(
      useMaterial3: true,
      platform: target,
      splashFactory: ios ? NoSplash.splashFactory : null,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.primary,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.surface1,
      ),
      iconButtonTheme: ios
          ? IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: colors.textPrimary,
                backgroundColor: Colors.transparent,
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                highlightColor: colors.primary.withValues(alpha: .12),
              ),
            )
          : null,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      fontFamily: KineticTypography.bodyFontFamily,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.secondary,
        onSecondary: colors.onPrimary,
        tertiary: colors.tertiary,
        onTertiary: colors.textPrimary,
        error: colors.error,
        onError: Colors.white,
        surface: colors.surface1,
        onSurface: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: KineticTypography.headlineMedium.copyWith(
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
          side: isDark
              ? const BorderSide(
                  color: Color(0xFF34495F),
                  width: 1.0,
                )
              : BorderSide(
                  color: colors.borderSubtle,
                  width: 1.0,
                ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.accentFill,
              foregroundColor: Colors.white,
              minimumSize: Size(
                ios ? KineticTokens.minTouchTarget : 48,
                ios ? KineticTokens.buttonHeight : 48,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: ios ? 14 : 20,
                vertical: ios ? 8 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              ),
              textStyle: KineticTypography.label.copyWith(
                fontSize: ios ? 12.5 : null,
                fontWeight: ios ? FontWeight.w600 : FontWeight.w700,
                letterSpacing: ios ? 0 : null,
              ),
              elevation: 0,
            ).copyWith(
              backgroundBuilder: ios
                  ? (context, states, child) =>
                        KineticSurfaceFinish.materialLayer(
                          context,
                          states,
                          child,
                          emphasis: true,
                        )
                  : null,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface1,
          minimumSize: Size(
            ios ? KineticTokens.minTouchTarget : 48,
            ios ? KineticTokens.buttonHeight : 48,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: ios ? 14 : 20,
            vertical: ios ? 8 : 14,
          ),
          side: BorderSide(color: colors.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          textStyle: KineticTypography.label.copyWith(
            fontSize: ios ? 12.5 : null,
            fontWeight: FontWeight.w600,
            letterSpacing: ios ? 0 : null,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: Size(
            ios ? KineticTokens.minTouchTarget : 48,
            ios ? 40 : 48,
          ),
          padding: EdgeInsets.symmetric(horizontal: ios ? 10 : 16),
          textStyle: KineticTypography.label.copyWith(
            fontSize: ios ? 12.5 : null,
            fontWeight: ios ? FontWeight.w600 : null,
            letterSpacing: ios ? 0 : null,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface1,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: ios ? 12 : 14,
        ),
        hintStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textMuted,
        ),
        labelStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.error, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface1,
        modalBackgroundColor: colors.surface1,
        elevation: ios ? 0 : 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface1,
        elevation: ios ? 0 : 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.borderSubtle, width: 0.5),
        ),
        titleTextStyle: KineticTypography.headlineMedium.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 0.5,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _KineticPageTransition(),
          TargetPlatform.iOS: _KineticIOSPageTransition(),
          TargetPlatform.macOS: _KineticPageTransition(),
          TargetPlatform.linux: _KineticPageTransition(),
          TargetPlatform.windows: _KineticPageTransition(),
          TargetPlatform.fuchsia: _KineticPageTransition(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surface3,
        contentTextStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
        ),
        elevation: 8,
      ),
      textTheme: TextTheme(
        displayLarge: KineticTypography.displayLarge.copyWith(
          color: colors.textPrimary,
        ),
        headlineLarge: KineticTypography.headlineLarge.copyWith(
          color: colors.textPrimary,
        ),
        headlineMedium: KineticTypography.headlineMedium.copyWith(
          color: colors.textPrimary,
        ),
        headlineSmall: KineticTypography.headlineSmall.copyWith(
          color: colors.textPrimary,
        ),
        bodyLarge: KineticTypography.bodyLarge.copyWith(
          color: colors.textPrimary,
        ),
        bodyMedium: KineticTypography.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        bodySmall: KineticTypography.bodySmall.copyWith(
          color: colors.textMuted,
        ),
        labelLarge: KineticTypography.label.copyWith(color: colors.textPrimary),
        labelMedium: KineticTypography.unitLabel.copyWith(
          color: colors.textMuted,
        ),
      ),
    );
  }
}

/// Kinetic page transition — 300ms easeInOutCubic fade
/// (motion spec window 250–320ms). Instant when OS Reduce Motion is on.
class _KineticPageTransition extends PageTransitionsBuilder {
  const _KineticPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (KineticTokens.reduceMotionOf(context)) {
      return child;
    }
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: KineticTokens.motionPageCurve,
      ),
      child: child,
    );
  }
}

/// Preserve Apple's horizontal push/pop and interactive edge-swipe behavior.
class _KineticIOSPageTransition extends CupertinoPageTransitionsBuilder {
  const _KineticIOSPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (KineticTokens.reduceMotionOf(context)) return child;
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
