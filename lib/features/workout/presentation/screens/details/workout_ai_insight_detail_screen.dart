import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-Page AI Coach Insight & Telemetry Analytics Screen
class WorkoutAiInsightDetailScreen extends ConsumerWidget {
  final WorkoutAiInsight insight;

  const WorkoutAiInsightDetailScreen({
    super.key,
    required this.insight,
  });

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  String _formatActivityLabel(String activity, AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      switch (activity.toLowerCase()) {
        case 'running':
          return 'CHẠY BỘ';
        case 'walking':
          return 'ĐI BỘ';
        case 'cycling':
          return 'ĐẠP XE';
        case 'rest':
          return 'NGHỈ NGƠI';
        default:
          return activity.toUpperCase();
      }
    }
    return activity.toUpperCase();
  }

  String _formatIntensityLabel(String intensity, AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      switch (intensity.toLowerCase()) {
        case 'recovery':
          return 'PHỤC HỒI';
        case 'aerobic':
          return 'AEROBIC';
        case 'tempo':
          return 'TEMPO';
        case 'interval':
          return 'INTERVAL';
        default:
          return intensity.toUpperCase();
      }
    }
    return intensity.toUpperCase();
  }

  String _formatSignalName(String signalKey, AppLanguage lang) {
    switch (signalKey) {
      case 'pace_fatigue_slope':
        return lang == AppLanguage.vi ? 'Độ dốc suy giảm Pace (Fatigue Slope)' : 'Pace Fatigue Slope';
      case 'pace_consistency_cv':
        return lang == AppLanguage.vi ? 'Hệ số biến thiên nhịp (Consistency CV)' : 'Pace Consistency CV';
      case 'rest_ratio':
        return lang == AppLanguage.vi ? 'Tỷ lệ thời gian nghỉ (Rest Ratio)' : 'Rest Ratio %';
      case 'gps_reliability_score':
        return lang == AppLanguage.vi ? 'Độ tin cậy vị trí GPS' : 'GPS Reliability Score';
      case 'baseline_pace_zscore':
        return lang == AppLanguage.vi ? 'Lệch chuẩn Pace so với 30 ngày (Z-Score)' : '30-Day Pace Z-Score';
      case 'baseline_distance_zscore':
        return lang == AppLanguage.vi ? 'Lệch chuẩn quãng đường so với 30 ngày' : '30-Day Distance Z-Score';
      case 'recent_7d_volume_km':
        return lang == AppLanguage.vi ? 'Tổng khối lượng vận động 7 ngày gần nhất' : 'Recent 7-Day Training Volume';
      case 'goal_alignment':
        return lang == AppLanguage.vi ? 'Mức độ phù hợp với mục tiêu' : 'Goal Alignment Status';
      default:
        return signalKey.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final isLlm = insight.source == 'llm';
    final accentColor = isLlm ? colors.primary : colors.secondary;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'PHÂN TÍCH TỪ AI COACH' : 'AI COACH ANALYSIS',
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLlm ? 'Google Gemini 1.5 Flash • Active' : 'Adaptive Smart Engine • Active',
                          style: KineticTypography.bodySmall.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isLlm ? 'AI ACTIVE' : 'SMART OFFLINE',
                      style: KineticTypography.unitLabel.copyWith(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // 1. Hero Summary Card — V4: flat + primary accent bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                      border: Border(
                        left: BorderSide(color: colors.primary, width: 3),
                        top: BorderSide(color: colors.borderSubtle),
                        right: BorderSide(color: colors.borderSubtle),
                        bottom: BorderSide(color: colors.borderSubtle),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isLlm ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isVi ? 'TỔNG QUAN HIỆU SUẤT' : 'PERFORMANCE OVERVIEW',
                                    style: KineticTypography.unitLabel.copyWith(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isVi
                                        ? 'Độ chuẩn xác tín hiệu: 100%'
                                        : 'Signal Match Confidence: 100%',
                                    style: KineticTypography.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (insight.headline.isNotEmpty) ...[
                          Text(
                            insight.headline,
                            style: KineticTypography.headlineSmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          insight.mainInsight,
                          style: KineticTypography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Strengths Section Card
                  if (insight.strengths.isNotEmpty) ...[
                    _DetailCardSection(
                      title: isVi ? 'ĐIỂM NỔI BẬT ĐẠT ĐƯỢC' : 'KEY STRENGTHS ACHIEVED',
                      icon: Icons.check_circle_rounded,
                      accentColor: colors.secondary,
                      items: insight.strengths,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Watchouts / Focus Areas Card
                  if (insight.watchouts.isNotEmpty) ...[
                    _DetailCardSection(
                      title: isVi ? 'LƯU Ý VỀ THỂ LỰC & CẢI THIỆN' : 'PHYSIOLOGICAL FOCUS AREAS',
                      icon: Icons.lightbulb_rounded,
                      accentColor: colors.tertiary,
                      items: insight.watchouts,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Next Session Blueprint Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.surface2,
                                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                              ),
                              child: Icon(
                                Icons.track_changes_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isVi ? 'KẾ HOẠCH BUỔI TẬP KẾ TIẾP' : 'NEXT SESSION BLUEPRINT',
                                    style: KineticTypography.unitLabel.copyWith(
                                      color: colors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isVi
                                        ? 'Được AI Coach đề xuất dựa trên tải vận động'
                                        : 'Prescribed by AI Coach based on training load',
                                    style: KineticTypography.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3 Metric Pills
                        Row(
                          children: [
                            Expanded(
                              child: _MetricPillBox(
                                label: isVi ? 'HOẠT ĐỘNG' : 'ACTIVITY',
                                value: _formatActivityLabel(
                                  insight.nextSessionSuggestion.recommendedActivity,
                                  currentLang,
                                ),
                                icon: _getActivityIcon(insight.nextSessionSuggestion.recommendedActivity),
                                accentColor: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricPillBox(
                                label: isVi ? 'THỜI LƯỢNG' : 'DURATION',
                                value: '${insight.nextSessionSuggestion.targetDurationMin} ${isVi ? 'phút' : 'min'}',
                                icon: Icons.timer_rounded,
                                accentColor: colors.secondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricPillBox(
                                label: isVi ? 'CƯỜNG ĐỘ' : 'INTENSITY',
                                value: _formatIntensityLabel(
                                  insight.nextSessionSuggestion.targetIntensity,
                                  currentLang,
                                ),
                                icon: Icons.bolt_rounded,
                                accentColor: colors.tertiary,
                              ),
                            ),
                          ],
                        ),

                        if (insight.nextSessionSuggestion.reason.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface2,
                              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                              border: Border.all(
                                color: colors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  color: colors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    insight.nextSessionSuggestion.reason,
                                    style: KineticTypography.bodyMedium.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Mathematical Telemetry Signals Card
                  if (insight.usedSignals.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface1,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.data_usage_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVi ? 'CƠ SỞ TÍN HIỆU TOÁN HỌC ĐÃ PHÂN TÍCH' : 'TELEMETRY SIGNALS ANALYZED',
                                style: KineticTypography.unitLabel.copyWith(
                                  color: colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...insight.usedSignals.map((sig) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _formatSignalName(sig, currentLang),
                                      style: KineticTypography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6. Done Button
                  KineticButton(
                    label: isVi ? 'QUAY LẠI' : 'BACK TO WORKOUT',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Detail Section Card for Strengths & Watchouts
// ---------------------------------------------------------------------------
class _DetailCardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> items;

  const _DetailCardSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: KineticTypography.unitLabel.copyWith(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric Pill Box inside Blueprint Card
// ---------------------------------------------------------------------------
class _MetricPillBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MetricPillBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: KineticTypography.unitLabel.copyWith(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
