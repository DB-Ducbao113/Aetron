import 'achievement_medallion.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class AchievementBadgeItem extends StatefulWidget {
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
  State<AchievementBadgeItem> createState() => _AchievementBadgeItemState();
}

class _AchievementBadgeItemState extends State<AchievementBadgeItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final currentLang = widget.currentLang;
    final colors = context.kinetic;
    final tier = badge.tier;
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? colors.textPrimary : colors.textMuted;

    return Semantics(
      button: true,
      label:
          '${badge.title(currentLang)} - ${badge.remainingText(currentLang)}',
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        child: AnimatedScale(
          scale: _pressed && !KineticTokens.reduceMotionOf(context) ? .95 : 1,
          duration: KineticTokens.respectingReduceMotion(
            context,
            KineticTokens.motionPress,
          ),
          curve: KineticTokens.motionPressCurve,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceSM,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: colors.isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isUnlocked
                          ? const [Color(0x9C2C4666), Color(0x881A2C44)]
                          : const [Color(0x6621354D), Color(0x55162438)],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isUnlocked
                          ? const [Color(0xD8FFFFFF), Color(0xB8EEF6FF)]
                          : const [Color(0x99FFFFFF), Color(0x78EAF2FA)],
                    ),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: isUnlocked
                    ? (colors.isDark
                          ? tier.primaryColor.withValues(alpha: 0.42)
                          : Colors.white.withValues(alpha: 0.92))
                    : (colors.isDark
                          ? const Color(0x2EB6DCFF)
                          : Colors.white.withValues(alpha: 0.72)),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.isDark
                      ? const Color(0x3800091C)
                      : const Color(0x14235189),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Emblem Circle & Tier Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AchievementMedallion(badge: badge, size: 60),

                    // Tier Tag
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KineticTokens.spaceXS,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusSM,
                          ),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Text(
                          tier.label(currentLang),
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  badge.title(currentLang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.label.copyWith(
                    fontSize: 12.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: isUnlocked
                        ? colors.textPrimary
                        : colors.textMuted.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),

                // Status / Remaining
                Text(
                  isUnlocked
                      ? (currentLang == AppLanguage.vi
                            ? 'Đã đạt được'
                            : 'Unlocked')
                      : badge.remainingText(currentLang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.unitLabel.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isUnlocked ? colors.primary : colors.textMuted,
                    letterSpacing: isUnlocked ? 0.6 : 0.0,
                  ),
                ),
                const SizedBox(height: 6),

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
      ),
    );
  }
}
