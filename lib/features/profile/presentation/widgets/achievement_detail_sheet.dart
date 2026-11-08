import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AchievementDetailSheet extends StatelessWidget {
  final AchievementBadge badge;
  final AppLanguage currentLang;

  const AchievementDetailSheet({
    super.key,
    required this.badge,
    required this.currentLang,
  });

  static Future<void> show(
    BuildContext context, {
    required AchievementBadge badge,
    required AppLanguage currentLang,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AchievementDetailSheet(
        badge: badge,
        currentLang: currentLang,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final tier = badge.tier;
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? colors.primary : colors.textMuted;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          KineticTokens.spaceSM,
          0,
          KineticTokens.spaceSM,
          KineticTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(
            color: isUnlocked ? colors.borderAccent : colors.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KineticTokens.spaceXL,
            KineticTokens.spaceMD,
            KineticTokens.spaceXL,
            KineticTokens.spaceXL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXL),

              // Emblem Container
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface2,
                      border: Border.all(
                        color: isUnlocked ? colors.primary : colors.borderSubtle,
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        badge.icon,
                        size: 38,
                        color: isUnlocked ? colors.primary : colors.textMuted,
                      ),
                    ),
                  ),

                  if (!isUnlocked)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              // Tier & Category Chips Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KineticTokens.spaceSM,
                      vertical: KineticTokens.spaceXXS,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius:
                          BorderRadius.circular(KineticTokens.radiusPill),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tier.tierIcon, size: 13, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          tier.label(currentLang),
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KineticTokens.spaceXS),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KineticTokens.spaceSM,
                      vertical: KineticTokens.spaceXXS,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius:
                          BorderRadius.circular(KineticTokens.radiusPill),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          badge.category.icon,
                          size: 13,
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badge.category.label(currentLang).toUpperCase(),
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.secondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KineticTokens.spaceSM),

              // Badge Title
              Text(
                badge.title(currentLang),
                textAlign: TextAlign.center,
                style: KineticTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXS),

              // Description
              Text(
                badge.description(currentLang),
                textAlign: TextAlign.center,
                style: KineticTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceMD),

              // Quote Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceMD,
                  vertical: KineticTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: isUnlocked ? colors.primary : colors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        badge.quote(currentLang),
                        style: KineticTypography.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isUnlocked ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              // Progress Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KineticTokens.spaceMD),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUnlocked
                              ? (currentLang == AppLanguage.vi ? 'TRẠNG THÁI' : 'STATUS')
                              : (currentLang == AppLanguage.vi ? 'TIẾN ĐỘ THỰC HIỆN' : 'PROGRESS'),
                          style: KineticTypography.unitLabel.copyWith(
                            color: isUnlocked ? colors.secondary : colors.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          isUnlocked
                              ? (currentLang == AppLanguage.vi ? '100% HOÀN THÀNH' : '100% CONQUERED')
                              : '${badge.progressPercent}%',
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isUnlocked ? colors.secondary : colors.primary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badge.progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: colors.surface3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUnlocked ? colors.secondary : colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          badge.formattedProgress(currentLang),
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                        Text(
                          badge.remainingText(currentLang),
                          style: KineticTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isUnlocked ? colors.secondary : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              // Action Button
              KineticButton(
                label: currentLang == AppLanguage.vi ? 'ĐÓNG' : 'CLOSE',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

