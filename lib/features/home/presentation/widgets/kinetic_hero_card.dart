import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticHeroCard extends StatelessWidget {
  final String title;
  final String categoryName;
  final String weeklyProgressText;
  final String targetGoalText;
  final String ctaLabel;
  final String imageAsset;
  final VoidCallback onStartTap;
  final VoidCallback? onGoalTap;

  const KineticHeroCard({
    super.key,
    required this.title,
    required this.categoryName,
    required this.weeklyProgressText,
    required this.targetGoalText,
    required this.ctaLabel,
    this.imageAsset = 'assets/home_hero_runner.jpg',
    required this.onStartTap,
    this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Semantics(
      label: '$title, $weeklyProgressText',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: KineticTokens.page,
          vertical: KineticTokens.spaceXS,
        ),
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(color: colors.borderSubtle, width: 1),
          boxShadow: KineticTokens.shadowPanel(colors.background),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Duotone scene base (V4) — also the photo error fallback
              SceneBackdrop(tint: colors.secondary),

              // 2. Background Photo
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stackTrace) =>
                    SceneBackdrop(tint: colors.secondary),
              ),

              // 3. Legibility Scrim Gradient (DS)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KineticGradients.scrimBottom(colors),
                ),
              ),

              // 4. Bottom Content Overlay
              Positioned(
                bottom: KineticTokens.spaceMD,
                left: KineticTokens.spaceMD,
                right: KineticTokens.spaceMD,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KineticTokens.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: KineticTokens.spaceXXS),
                        Text(
                          weeklyProgressText,
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: KineticTokens.spaceXS),
                        Text(
                          '•',
                          style: TextStyle(color: colors.textMuted),
                        ),
                        const SizedBox(width: KineticTokens.spaceXS),
                        if (onGoalTap != null)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onGoalTap,
                              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KineticTokens.spaceXXS,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: KineticTokens.spaceXXS),
                                    Text(
                                      targetGoalText,
                                      style: KineticTypography.bodySmall.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: colors.primary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: KineticTokens.spaceXXS),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 13,
                                      color: colors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: KineticTokens.spaceXXS),
                              Text(
                                targetGoalText,
                                style: KineticTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceMD),

                    // Primary Action CTA
                    KineticButton(
                      label: ctaLabel,
                      icon: Icons.play_arrow_rounded,
                      variant: KineticButtonVariant.primary,
                      onPressed: onStartTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
