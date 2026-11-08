import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticOverallProgressCard extends StatelessWidget {
  final AppLanguage currentLang;
  final int unlockedCount;
  final int totalCount;
  final double overallProgress;
  final int totalWorkouts;
  final int longestStreak;
  final double totalDistanceKm;

  const KineticOverallProgressCard({
    super.key,
    required this.currentLang,
    required this.unlockedCount,
    required this.totalCount,
    required this.overallProgress,
    required this.totalWorkouts,
    required this.longestStreak,
    required this.totalDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final progressPercent = (overallProgress * 100).round();

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentLang == AppLanguage.vi ? 'TIẾN TRÌNH DANH HIỆU' : 'ACHIEVEMENT PROGRESS',
                style: KineticTypography.pageEyebrow.copyWith(
                  color: colors.primary,
                ),
              ),
              Text(
                '$progressPercent%',
                style: KineticTypography.headlineSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(KineticTokens.radiusXS),
            child: LinearProgressIndicator(
              value: overallProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colors.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          Divider(height: 1, thickness: 1, color: colors.borderSubtle),
          const SizedBox(height: KineticTokens.spaceSM),

          // 3 Telemetry Metrics — flat row, hairline separated
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  context: context,
                  icon: Icons.directions_run_rounded,
                  label: currentLang == AppLanguage.vi ? 'Buổi tập' : 'Sessions',
                  value: '$totalWorkouts',
                  color: colors.primary,
                ),
              ),
              Container(width: 1, height: 40, color: colors.borderSubtle),
              Expanded(
                child: _buildMiniStat(
                  context: context,
                  icon: Icons.local_fire_department_rounded,
                  label: currentLang == AppLanguage.vi ? 'Chuỗi max' : 'Best Streak',
                  value: '$longestStreak ${currentLang == AppLanguage.vi ? 'ngày' : 'd'}',
                  color: colors.tertiary,
                ),
              ),
              Container(width: 1, height: 40, color: colors.borderSubtle),
              Expanded(
                child: _buildMiniStat(
                  context: context,
                  icon: Icons.route_rounded,
                  label: currentLang == AppLanguage.vi ? 'Quãng đường' : 'Distance',
                  value: '${totalDistanceKm.toStringAsFixed(1)} km',
                  color: colors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: KineticTokens.spaceXXS),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KineticTypography.label.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KineticTypography.caption.copyWith(
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
