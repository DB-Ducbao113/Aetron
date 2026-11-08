import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class AchievementBadgeItem extends StatelessWidget {
  final AchievementBadge badge;
  final AppLanguage currentLang;
  final VoidCallback onTap;

  const AchievementBadgeItem({
    super.key,
    required this.badge,
    required this.currentLang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final tier = badge.tier;
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? colors.primary : colors.textMuted;

    return Semantics(
      button: true,
      label: '${badge.title(currentLang)} - ${isUnlocked ? 'Unlocked' : badge.remainingText(currentLang)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(KineticTokens.spaceSM),
          decoration: BoxDecoration(
            color: isUnlocked ? colors.surface1 : colors.background,
            borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
            border: Border.all(
              color: isUnlocked ? colors.borderAccent : colors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Emblem Circle & Tier Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked ? colors.surface2 : colors.surface3,
                          border: Border.all(
                            color: isUnlocked ? colors.primary : colors.borderSubtle,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          badge.icon,
                          size: 20,
                          color: isUnlocked
                              ? colors.primary
                              : colors.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                      if (!isUnlocked)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: colors.background,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Tier Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KineticTokens.spaceXS,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius:
                          BorderRadius.circular(KineticTokens.radiusSM),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Text(
                      tier.label(currentLang),
                      style: KineticTypography.unitLabel.copyWith(
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KineticTokens.spaceXS),

              // Title
              Text(
                badge.title(currentLang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isUnlocked
                      ? colors.textPrimary
                      : colors.textMuted.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),

              // Status / Remaining
              Text(
                isUnlocked
                    ? (currentLang == AppLanguage.vi ? 'ĐÃ ĐẠT ĐƯỢC' : 'UNLOCKED')
                    : badge.remainingText(currentLang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isUnlocked ? colors.primary : colors.textMuted,
                  letterSpacing: isUnlocked ? 0.6 : 0.0,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXS),

              // Bottom Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(KineticTokens.radiusXS),
                child: LinearProgressIndicator(
                  value: badge.progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: colors.surface3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUnlocked
                        ? colors.primary
                        : colors.textMuted.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

