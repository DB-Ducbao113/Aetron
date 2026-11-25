import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticProfileTopBar extends StatelessWidget {
  final AppLanguage currentLang;

  const KineticProfileTopBar({super.key, required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLang == AppLanguage.vi ? 'Tài khoản' : 'Account',
                style: KineticTypography.tabEyebrowOf(colors),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppTranslations.get('profile', currentLang),
                  style: KineticTypography.tabTitleOf(colors),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        KineticGlassIconButton(
          size: 37,
          visualSize: 37,
          label: AppTranslations.get('settings', currentLang),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: BladeIcon(
            BladeIconName.gear,
            color: colors.textSecondary,
            size: 18,
            strokeWidth: 1.7,
          ),
        ),
      ],
    );
  }
}
