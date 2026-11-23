import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticDetailsDeleteDialog extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onConfirm;

  const KineticDetailsDeleteDialog({
    super.key,
    required this.currentLang,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return KineticGlassDialog(
      borderColor: colors.error.withValues(alpha: 0.38),
      padding: const EdgeInsets.all(22),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: colors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppTranslations.get('delete_workout', currentLang),
                    style: KineticTypography.pageTitleCompact.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.get('confirm_delete_workout', currentLang),
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: KineticButton(
                    label: AppTranslations.get('cancel', currentLang),
                    variant: KineticButtonVariant.secondary,
                    height: KineticTokens.buttonHeight,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),

                // Delete Confirm Button
                Expanded(
                  child: KineticButton(
                    label: currentLang == AppLanguage.vi
                        ? 'Xác nhận xóa'
                        : 'Confirm Delete',
                    icon: Icons.delete_outline_rounded,
                    variant: KineticButtonVariant.danger,
                    height: KineticTokens.buttonHeight,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
