import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_ai_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact AI Post-Workout Insight Card for Aetron (V4: flat, accent bar)
class WorkoutAiInsightCard extends ConsumerWidget {
  final String workoutId;
  final bool hasMargin;

  const WorkoutAiInsightCard({
    super.key,
    required this.workoutId,
    this.hasMargin = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final insightAsync = ref.watch(workoutAiInsightProvider(workoutId));

    return insightAsync.when(
      data: (insight) {
        if (insight == null) {
          return const SizedBox.shrink();
        }
        return _CompactAiInsightCard(
          insight: insight,
          currentLang: currentLang,
          hasMargin: hasMargin,
        );
      },
      loading: () => _AiInsightLoadingCard(
        currentLang: currentLang,
        hasMargin: hasMargin,
      ),
      error: (error, _) => _AiInsightErrorCard(
        currentLang: currentLang,
        hasMargin: hasMargin,
        onRetry: () => ref.invalidate(workoutAiInsightProvider(workoutId)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact Main AI Insight Display Card
// ---------------------------------------------------------------------------
class _CompactAiInsightCard extends StatelessWidget {
  final WorkoutAiInsight insight;
  final AppLanguage currentLang;
  final bool hasMargin;

  const _CompactAiInsightCard({
    required this.insight,
    required this.currentLang,
    required this.hasMargin,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;
    final isLlm = insight.source == 'llm';
    final accentColor = isLlm ? colors.primary : colors.secondary;

    // V4: flat surface1 with a primary accent bar — no cyberpunk glow.
    return Container(
      margin: hasMargin ? const EdgeInsets.symmetric(vertical: 6) : EdgeInsets.zero,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutAiInsightDetailScreen(insight: insight),
              ),
            );
          },
          borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Header & Status Badge ────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        isLlm ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isVi ? 'AI COACH INSIGHT' : 'AI COACH INSIGHT',
                        style: KineticTypography.pageEyebrow.copyWith(
                          color: accentColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isLlm ? 'AI ACTIVE' : 'SMART OFFLINE',
                        style: KineticTypography.unitLabel.copyWith(
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Headline & Short Insight ──────────────────────────────────
                if (insight.headline.isNotEmpty) ...[
                  Text(
                    insight.headline,
                    style: KineticTypography.headlineSmall.copyWith(
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  insight.mainInsight,
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textPrimary.withValues(alpha: 0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // ── Bottom Row: Next Session Tag + View More CTA ──────────────
                Row(
                  children: [
                    // Next session mini pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getActivityIcon(insight.nextSessionSuggestion.recommendedActivity),
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_formatActivityLabel(insight.nextSessionSuggestion.recommendedActivity, currentLang)} • ${insight.nextSessionSuggestion.targetDurationMin} ${isVi ? 'phút' : 'min'} • ${_formatIntensityLabel(insight.nextSessionSuggestion.targetIntensity, currentLang)}',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // View Full Analysis link
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVi ? 'Chi tiết' : 'Details',
                          style: KineticTypography.unitLabel.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Loading State Widget (Pulsing Scanner Shimmer)
// ---------------------------------------------------------------------------
class _AiInsightLoadingCard extends StatefulWidget {
  final AppLanguage currentLang;
  final bool hasMargin;

  const _AiInsightLoadingCard({
    required this.currentLang,
    required this.hasMargin,
  });

  @override
  State<_AiInsightLoadingCard> createState() => _AiInsightLoadingCardState();
}

class _AiInsightLoadingCardState extends State<_AiInsightLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: widget.hasMargin
              ? const EdgeInsets.symmetric(vertical: 6)
              : EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isVi
                        ? 'AI COACH ĐANG PHÂN TÍCH...'
                        : 'AI COACH IS ANALYZING...',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surface2.withValues(alpha: _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: 180,
                decoration: BoxDecoration(
                  color: colors.surface2.withValues(alpha: _pulseAnimation.value * 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// AI Error / Retry State Widget
// ---------------------------------------------------------------------------
class _AiInsightErrorCard extends StatelessWidget {
  final AppLanguage currentLang;
  final bool hasMargin;
  final VoidCallback onRetry;

  const _AiInsightErrorCard({
    required this.currentLang,
    required this.hasMargin,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    return Container(
      margin: hasMargin ? const EdgeInsets.symmetric(vertical: 6) : EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVi ? 'Không thể tải AI insight' : 'Unable to load AI insight',
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              isVi ? 'Thử lại' : 'Retry',
              style: KineticTypography.label.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
