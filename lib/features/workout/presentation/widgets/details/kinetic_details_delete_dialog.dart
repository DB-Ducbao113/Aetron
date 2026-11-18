import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
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
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                      ),
                    ),
                    child: Text(
                      AppTranslations.get('cancel', currentLang),
                      style: KineticTypography.label.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Delete Confirm Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      currentLang == AppLanguage.vi
                          ? 'Xác nhận xóa'
                          : 'Confirm Delete',
                      style: KineticTypography.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
