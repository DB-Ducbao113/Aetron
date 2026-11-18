import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

export 'kinetic_tokens.dart';
export 'kinetic_skeleton.dart';
export 'kinetic_entrance.dart';

class KineticTheme {
  const KineticTheme._();

  static ThemeData get darkTheme => buildTheme(Brightness.dark);
  static ThemeData get lightTheme => buildTheme(Brightness.light);

  static ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? KineticColors.dark : KineticColors.light;

    return ThemeData(
      useMaterial3: true,
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
              ? BorderSide(color: colors.borderSubtle.withValues(alpha: 0.5), width: 0.5)
              : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentFill,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          textStyle: KineticTypography.label.copyWith(
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface1,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          textStyle: KineticTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          textStyle: KineticTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: KineticTypography.bodyMedium.copyWith(color: colors.textMuted),
        labelStyle: KineticTypography.bodyMedium.copyWith(color: colors.textSecondary),
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
        elevation: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface1,
        elevation: 16,
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
          TargetPlatform.iOS: _KineticPageTransition(),
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
        displayLarge: KineticTypography.displayLarge.copyWith(color: colors.textPrimary),
        headlineLarge: KineticTypography.headlineLarge.copyWith(color: colors.textPrimary),
        headlineMedium: KineticTypography.headlineMedium.copyWith(color: colors.textPrimary),
        headlineSmall: KineticTypography.headlineSmall.copyWith(color: colors.textPrimary),
        bodyLarge: KineticTypography.bodyLarge.copyWith(color: colors.textPrimary),
        bodyMedium: KineticTypography.bodyMedium.copyWith(color: colors.textSecondary),
        bodySmall: KineticTypography.bodySmall.copyWith(color: colors.textMuted),
        labelLarge: KineticTypography.label.copyWith(color: colors.textPrimary),
        labelMedium: KineticTypography.unitLabel.copyWith(color: colors.textMuted),
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
