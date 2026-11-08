import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSettingsTopBar extends StatelessWidget {
  final AppLanguage currentLang;

  const KineticSettingsTopBar({
    super.key,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button
        Semantics(
          button: true,
          label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                border: Border.all(color: colors.borderStrong),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: KineticTokens.spaceSM),

        // Title
        Expanded(
          child: Text(
            AppTranslations.get('settings', currentLang),
            style: KineticTypography.pageTitle.copyWith(
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // System Version Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            border: Border.all(color: colors.borderStrong),
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
                'v1.0.0',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
