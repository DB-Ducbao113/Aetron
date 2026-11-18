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

  /// Aetron Dark — OLED Charcoal + Sky-Azure synced with logo.png
  static const dark = KineticColors(
    background: Color(0xFF0B0B0E),
    surface1: Color(0xFF16161A),
    surface2: Color(0xFF1F2026),
    surface3: Color(0xFF2A2B33),
    primary: Color(0xFF38BDF8),
    onPrimary: Color(0xFF061926),
    secondary: Color(0xFF0EA5E9),
    tertiary: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD1D5DB),
    textMuted: Color(0xFF8E8E93),
    borderSubtle: Color(0xFF26262E),
    borderAccent: Color(0x4038BDF8),
    borderStrong: Color(0xFF3A3A44),
    accentFill: Color(0xFF006EE6),
    glow: Color(0xFF38BDF8),
  );

  /// Aetron Light (Primary) — Clean Athletic White + Electric Azure Blue (#006EE6)
  static const light = KineticColors(
    background: Color(0xFFF7F7FA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEFF4),
    surface3: Color(0xFFE4E4EC),
    primary: Color(0xFF006EE6),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF0284C7),
    tertiary: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF6B7280),
    borderSubtle: Color(0xFFE8E8EE),
    borderAccent: Color(0x33006EE6),
    borderStrong: Color(0xFFD1D5DB),
    accentFill: Color(0xFF006EE6),
    glow: Color(0xFF006EE6),
  );

  bool get isDark => background.computeLuminance() < 0.2;

  /// Soft brand tint for subtle pills, streak badges, and active chips.
  Color get primaryTint =>
      isDark ? const Color(0xFF12263A) : const Color(0xFFEAF3FF);

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
