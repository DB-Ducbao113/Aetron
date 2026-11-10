import 'package:flutter/material.dart';

class KineticTypography {
  const KineticTypography._();

  /// Display face for headings, controls, and performance telemetry.
  /// V4 (2026-11-08): single typeface for the whole app — Be Vietnam Pro
  /// (weight + width axes). Owner direction: modern, clean, one stable font.
  static const String displayFontFamily = 'BeVietnamPro';

  /// Reading face — same family as display in V4 (single-font system).
  static const String bodyFontFamily = 'BeVietnamPro';

  /// Compatibility alias for custom telemetry styles outside this token file.
  static const String fontFamily = displayFontFamily;

  /// Standard tabular figures feature for non-jittering telemetry digits
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Hero Metric — Primary focal metric for recording, summary, details and streaks.
  static const TextStyle metricHero = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 52,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Mega Metric — V4: the single biggest number on screen (live distance,
  /// summary headline). Be Vietnam Pro ExtraBold.
  static const TextStyle metricMega = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 76,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 0.95,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Display XL — V4: page-level statement headlines.
  static const TextStyle displayXL = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry Metric (Medium)
  static const TextStyle metricMedium = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry Metric (Small)
  static const TextStyle metricSmall = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.15,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Display Large
  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Headline Large
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.48,
    height: 1.25,
  );

  /// Headline Medium
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.18,
    height: 1.3,
  );

  /// Headline Small
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Body Large
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body Medium
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Body Small
  static const TextStyle bodySmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Unit Descriptors & Section Micro Labels (e.g. "BPM", "KM/H", "AVG PACE")
  static const TextStyle unitLabel = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
    height: 1.2,
  );

  /// Interactive Label
  static const TextStyle label = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.26,
    height: 1.2,
  );

  /// Tiêu đề page của 5 tab chính (Activity, Analytics, History, Profile, Settings).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.44, // -0.02em × 22
    height: 1.2,
  );

  /// Tiêu đề page con (Details, Summary, Achievements).
  static const TextStyle pageTitleCompact = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.18,
    height: 1.25,
  );

  /// Dòng nhỏ phía trên tiêu đề (eyebrow).
  static const TextStyle pageEyebrow = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
  );

  /// Greeting line trên Home top bar ("Chào buổi sáng,")
  static const TextStyle greeting = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  /// User display name trên Home top bar (nặng hơn headlineSmall)
  static const TextStyle displayName = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Section eyebrow — uppercase micro label với spacing nhẹ
  static const TextStyle sectionEyebrow = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
    height: 1.2,
  );

  /// Caption — small supporting text (labels, metadata)
  static const TextStyle caption = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Card title trên ảnh (activity card, explore route) — dùng kèm white + shadow
  static const TextStyle cardTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// Telemetry Metric (Compact) — 4-up bento grid values (Analytics key telemetry)
  static const TextStyle metricCompact = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Telemetry Metric (Card) — Summary/Details telemetry card values (2×2 grid)
  static const TextStyle metricCard = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Unit descriptor next to a big metric (e.g. "KM", "MI" beside metricHero)
  static const TextStyle metricUnit = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
