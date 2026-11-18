import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_detail_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_backdrop.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticNextMilestoneSpotlight extends StatelessWidget {
  final AchievementBadge badge;
  final AppLanguage currentLang;

  const KineticNextMilestoneSpotlight({
    super.key,
    required this.badge,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      button: true,
      label: '${badge.title(currentLang)} - ${badge.formattedProgress(currentLang)}',
      child: InkWell(
        onTap: () => AchievementDetailSheet.show(
          context,
          badge: badge,
          currentLang: currentLang,
        ),
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
            child: Stack(
              children: [
                Positioned.fill(
                  child: SceneBackdrop(tint: colors.primary),
                ),
                Padding(
                  padding: const EdgeInsets.all(KineticTokens.spaceMD),
                  child: Row(
            children: [
              // Icon Emblem
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface2,
                  border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
                ),
                child: Icon(badge.icon, size: 22, color: colors.primary),
              ),
              const SizedBox(width: KineticTokens.spaceSM),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLang == AppLanguage.vi ? 'CỘT MỐC TIẾP THEO' : 'NEXT MILESTONE',
                      style: KineticTypography.pageEyebrow.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.title(currentLang),
                      style: KineticTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${badge.formattedProgress(currentLang)} • ${badge.remainingText(currentLang)}',
                      style: KineticTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress %
              Text(
                '${badge.progressPercent}%',
                style: KineticTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
