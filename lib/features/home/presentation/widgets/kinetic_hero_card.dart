import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticHeroCard extends StatelessWidget {
  final String title;
  final String categoryName;
  final String weeklyProgressText;
  final String targetGoalText;
  final String ctaLabel;
  final VoidCallback onStartTap;
  final VoidCallback? onGoalTap;

  const KineticHeroCard({
    super.key,
    required this.title,
    required this.categoryName,
    required this.weeklyProgressText,
    required this.targetGoalText,
    required this.ctaLabel,
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
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(color: colors.borderSubtle, width: 1),
          boxShadow: colors.isDark
              ? KineticTokens.shadowPanel(colors.background)
              : KineticTokens.shadowCardLight(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Duotone scene base (V4)
              SceneBackdrop(tint: colors.secondary),

              // 2. Upper-right athletic emblem
              Positioned(
                top: KineticTokens.spaceLG,
                right: KineticTokens.spaceLG,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(
                      alpha: colors.isDark ? 0.14 : 0.10,
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
              ),

              // 3. Theme-adaptive surface bottom fade (Option A Light & Dark)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surface1.withValues(alpha: 0.0),
                      colors.surface1.withValues(alpha: 0.94),
                    ],
                    stops: const [0.32, 0.86],
                  ),
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
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KineticTokens.spaceXS),
                    Row(
                      children: [
                        BladeIcon(
                          BladeIconName.route,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: KineticTokens.spaceXXS),
                        Flexible(
                          child: Text(
                            weeklyProgressText,
                            style: KineticTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: KineticTokens.spaceXS),
                        Text(
                          '•',
                          style: TextStyle(color: colors.textMuted),
                        ),
                        const SizedBox(width: KineticTokens.spaceXS),
                        if (onGoalTap != null)
                          Flexible(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onGoalTap,
                                borderRadius: BorderRadius.circular(
                                  KineticTokens.radiusSM,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KineticTokens.spaceXXS,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BladeIcon(
                                        BladeIconName.flag,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: KineticTokens.spaceXXS),
                                      Flexible(
                                        child: Text(
                                          targetGoalText,
                                          style: KineticTypography.bodySmall.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                            decorationColor: colors.primary
                                                .withValues(alpha: 0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: KineticTokens.spaceXXS),
                                      BladeIcon(
                                        BladeIconName.chevR,
                                        size: 13,
                                        color: colors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BladeIcon(
                                  BladeIconName.flag,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: KineticTokens.spaceXXS),
                                Flexible(
                                  child: Text(
                                    targetGoalText,
                                    style: KineticTypography.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
