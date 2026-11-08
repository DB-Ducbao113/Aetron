import 'package:flutter/material.dart';

@immutable
class KineticColors extends ThemeExtension<KineticColors> {
  final Color background;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color borderAccent;

  /// Stronger edge tier (board v3): large containers, switches, inputs.
  final Color borderStrong;

  /// The cyan fill (#A8DCE7) in BOTH themes — fills, washes, the primary
  /// button gradient. In the light "Morning" identity, [primary] becomes
  /// deep teal for text, so cyan fills must come from here instead.
  final Color accentFill;
  final Color glow;

  const KineticColors({
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.borderAccent,
    required this.borderStrong,
    required this.accentFill,
    required this.glow,
  });

  /// Kinetic Telemetry (Dark Mode - Default)
  static const dark = KineticColors(
    background: Color(0xFF0C1113),
    surface1: Color(0xFF12181B),
    surface2: Color(0xFF192226),
    surface3: Color(0xFF232F35),
    primary: Color(0xFFA8DCE7),
    onPrimary: Color(0xFF09181C),
    secondary: Color(0xFF50B4C8),
    tertiary: Color(0xFFF38D68),
    error: Color(0xFFFFB4AB),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE1E8EB),
    textMuted: Color(0xFF7D919A),
    borderSubtle: Color(0xFF3D4650),
    borderAccent: Color(0x33A8DCE7),
    borderStrong: Color(0xFF57626E),
    accentFill: Color(0xFFA8DCE7),
    glow: Color(0xFFA8DCE7),
  );

  /// Kinetic Morning (Light Mode) — its own identity, not an inverted
  /// dark theme: paper background, white cards defined by soft shadow,
  /// deep teal carries text/accents, cyan survives as [accentFill] only.
  static const light = KineticColors(
    background: Color(0xFFF6F9F6),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF3EE),
    surface3: Color(0xFFDFE9E0),
    primary: Color(0xFF2F7E96),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF4E9DB5),
    tertiary: Color(0xFFE8734D),
    error: Color(0xFFBA1A1A),
    textPrimary: Color(0xFF0D1517),
    textSecondary: Color(0xFF3E4C52),
    textMuted: Color(0xFF5A6A70),
    borderSubtle: Color(0xFFD9E3DB),
    borderAccent: Color(0x662F7E96),
    borderStrong: Color(0xFFB7C8BB),
    accentFill: Color(0xFFA8DCE7),
    glow: Color(0xFF2F7E96),
  );

  @override
  KineticColors copyWith({
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? tertiary,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? borderAccent,
    Color? borderStrong,
    Color? accentFill,
    Color? glow,
  }) {
    return KineticColors(
      background: background ?? this.background,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderAccent: borderAccent ?? this.borderAccent,
      borderStrong: borderStrong ?? this.borderStrong,
      accentFill: accentFill ?? this.accentFill,
      glow: glow ?? this.glow,
    );
  }

  @override
  KineticColors lerp(ThemeExtension<KineticColors>? other, double t) {
    if (other is! KineticColors) return this;
    return KineticColors(
      background: Color.lerp(background, other.background, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderAccent: Color.lerp(borderAccent, other.borderAccent, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

extension KineticThemeContext on BuildContext {
  KineticColors get kinetic =>
      Theme.of(this).extension<KineticColors>() ?? KineticColors.dark;
}
