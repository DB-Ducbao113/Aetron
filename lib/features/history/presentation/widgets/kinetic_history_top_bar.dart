import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticHistoryTopBar extends StatelessWidget {
  final int totalCount;
  final AppLanguage currentLang;
  final bool isOffline;

  const KineticHistoryTopBar({
    super.key,
    required this.totalCount,
    required this.currentLang,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Page Title (Clear & Prominent)
            Expanded(
              child: Text(
                AppTranslations.get('workout_history', currentLang),
                style: KineticTypography.pageTitle.copyWith(
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: KineticTokens.spaceSM),

            // Workout Count Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceSM, vertical: KineticTokens.spaceXXS),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalCount ${currentLang == AppLanguage.vi ? 'BUỔI' : 'SESSIONS'}',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (isOffline) ...[
          const SizedBox(height: KineticTokens.spaceXS),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceSM, vertical: KineticTokens.spaceXS),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 14, color: colors.tertiary),
                const SizedBox(width: KineticTokens.spaceXS),
                Expanded(
                  child: Text(
                    currentLang == AppLanguage.vi
                        ? 'Chế độ ngoại tuyến: dữ liệu được lưu cục bộ an toàn.'
                        : 'Offline mode: workouts saved locally.',
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
