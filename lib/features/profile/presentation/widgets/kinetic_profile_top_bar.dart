import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticProfileTopBar extends StatelessWidget {
  final AppLanguage currentLang;

  const KineticProfileTopBar({
    super.key,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppTranslations.get('profile', currentLang),
          style: KineticTypography.pageTitle.copyWith(
            color: colors.textPrimary,
          ),
        ),

        // Settings Orb Button
        Semantics(
          button: true,
          label: AppTranslations.get('settings', currentLang),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            child: Container(
              width: KineticTokens.minTouchTarget,
              height: KineticTokens.minTouchTarget,
              decoration: BoxDecoration(
                color: colors.surface1,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: BladeIcon(
                BladeIconName.gear,
                color: colors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
