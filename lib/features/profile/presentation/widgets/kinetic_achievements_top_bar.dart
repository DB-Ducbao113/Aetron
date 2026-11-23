import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
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
        KineticGlassIconButton(
          size: 37,
          visualSize: 37,
          label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: BladeIcon(
            BladeIconName.chevL,
            size: 18,
            color: colors.textSecondary,
            strokeWidth: 1.7,
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
              Icon(Icons.emoji_events_rounded, size: 14, color: colors.primary),
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
