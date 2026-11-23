import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticDetailsTopBar extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onBack;
  final VoidCallback onDelete;

  const KineticDetailsTopBar({
    super.key,
    required this.currentLang,
    required this.onBack,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          KineticGlassIconButton(
            size: 37,
            visualSize: 37,
            label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
            onPressed: onBack,
            icon: BladeIcon(
              BladeIconName.chevL,
              size: 18,
              color: colors.textSecondary,
              strokeWidth: 1.7,
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              AppTranslations.get('workout_details', currentLang),
              style: KineticTypography.pageTitleCompact.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          KineticGlassIconButton(
            size: 37,
            visualSize: 37,
            label: currentLang == AppLanguage.vi
                ? 'Xóa buổi tập'
                : 'Delete workout',
            onPressed: onDelete,
            icon: BladeIcon(
              BladeIconName.trash,
              size: 18,
              color: colors.error,
              strokeWidth: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
