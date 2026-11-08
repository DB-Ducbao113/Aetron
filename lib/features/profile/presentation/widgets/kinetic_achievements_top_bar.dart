import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticAchievementsTopBar extends StatelessWidget {
  final AppLanguage currentLang;
  final int unlockedCount;
  final int totalCount;

  const KineticAchievementsTopBar({
    super.key,
    required this.currentLang,
    required this.unlockedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      children: [
        // Back Button
        Semantics(
          button: true,
          label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            child: Container(
              padding: const EdgeInsets.all(KineticTokens.spaceXS),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: KineticTokens.spaceSM),

        // Eyebrow & Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentLang == AppLanguage.vi
                    ? 'THÀNH TÍCH AETRON'
                    : 'AETRON ACHIEVEMENTS',
                style: KineticTypography.pageEyebrow.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentLang == AppLanguage.vi ? 'Kho Huy Hiệu' : 'Badge Vault',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.pageTitleCompact.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Counter Chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KineticTokens.spaceSM,
            vertical: KineticTokens.spaceXXS + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            border: Border.all(color: colors.borderAccent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                '$unlockedCount / $totalCount',
                style: KineticTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
