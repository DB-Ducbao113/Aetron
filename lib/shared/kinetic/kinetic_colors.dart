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

  /// Aetron Dark (Nightfall) — Liquid Glass Midnight Sapphire (#0C1420) + Ice Azure (#93BFFF)
  static const dark = KineticColors(
    background: Color(0xFF0C1420),
    surface1: Color(0xFF192736),
    surface2: Color(0xFF213245),
    surface3: Color(0xFF2B3E52),
    primary: Color(0xFF93BFFF),
    onPrimary: Color(0xFF061426),
    secondary: Color(0xFF4B94F6),
    tertiary: Color(0xFFEFCB82),
    error: Color(0xFFF87171),
    textPrimary: Color(0xFFF1F6FF),
    textSecondary: Color(0xFFB1C0D1),
    textMuted: Color(0xFF9FB0C5),
    borderSubtle: Color(0xFF2D4054),
    borderAccent: Color(0x4793BFFF),
    borderStrong: Color(0xFF34495F),
    accentFill: Color(0xFF276CC5),
    glow: Color(0x3393BFFF),
  );

  /// Aetron Light (Primary) — Clean Athletic White + Electric Azure Blue (#1166DB)
  static const light = KineticColors(
    background: Color(0xFFEEF2F8),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFE5ECF6),
    surface3: Color(0xFFDBE4F0),
    primary: Color(0xFF1166DB),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF2563EB),
    tertiary: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
    textPrimary: Color(0xFF172436),
    textSecondary: Color(0xFF627387),
    textMuted: Color(0xFF8291A3),
    borderSubtle: Color(0xFFE7EDF4),
    borderAccent: Color(0x331166DB),
    borderStrong: Color(0xFFCAD6E4),
    accentFill: Color(0xFF1166DB),
    glow: Color(0x261166DB),
  );

  bool get isDark => background.computeLuminance() < 0.2;

  /// Soft brand tint for subtle pills, streak badges, and active chips.
  Color get primaryTint =>
      isDark ? const Color(0xFF16283E) : const Color(0xFFEAF3FF);

  /// Semantic positive status color (GPS lock, growth delta, PR achieved).
  Color get success =>
      isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);

  /// Soft success pill fill.
  Color get successTint =>
      isDark ? const Color(0xFF102A1A) : const Color(0xFFDCFCE7);

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
