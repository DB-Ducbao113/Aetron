import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
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

  /// Mega Metric — single biggest telemetry value on screen (live distance,
  /// summary headline). Crisp tabular figures.
  static const TextStyle metricMega = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.0,
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

  /// Tiêu đề page của các tab chính & sub-screen (Cài đặt, Thông báo).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.35,
    height: 1.2,
  );

  /// Tiêu đề section sạch dạng sentence-case (Mục tiêu tuần, Hoạt động gần đây, Lọc theo môn).
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
  );

  /// Eyebrow đồng bộ cho cả 5 tab chính.
  static const TextStyle tabEyebrow = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.05,
    height: 1.2,
  );

  /// Tiêu đề lớn đồng bộ cho cả 5 tab chính (Home, Activity, History, Analytics, Profile).
  static const TextStyle tabTitle = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.45,
    height: 1.18,
  );

  /// Eyebrow in hoa cho thẻ / nhóm mục (TỔNG QUAN GIAI ĐOẠN, CHỈ SỐ TỔNG HỢP, TIỆN ÍCH & CÀI ĐẶT).
  static const TextStyle cardEyebrow = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    height: 1.2,
  );

  /// Nhãn chữ bên trong mọi thanh segmented control (Activity, History, Analytics).
  static const TextStyle segmentedLabel = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static TextStyle tabEyebrowOf(KineticColors colors) => tabEyebrow.copyWith(
    color: colors.isDark ? const Color(0xFF839AB4) : colors.textMuted,
  );

  static TextStyle tabTitleOf(KineticColors colors) => tabTitle.copyWith(
    color: colors.isDark ? const Color(0xFFF4F8FE) : colors.textPrimary,
  );

  static TextStyle sectionTitleOf(KineticColors colors) =>
      sectionTitle.copyWith(
        color: colors.isDark ? const Color(0xFFE9F1FD) : colors.textPrimary,
      );

  static TextStyle cardEyebrowOf(KineticColors colors, {Color? color}) =>
      cardEyebrow.copyWith(color: color ?? colors.primary);

  static TextStyle linkActionOf(KineticColors colors) => label.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: colors.isDark ? const Color(0xFF9BC5FF) : colors.primary,
  );

  /// Tiêu đề page con (Details, Summary, Achievements, Programs, ProfileSetup).
  static const TextStyle pageTitleCompact = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
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
