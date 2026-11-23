import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AetronLogoutDialog extends ConsumerWidget {
  const AetronLogoutDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AetronLogoutDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);

    return KineticGlassBottomSheet(
      floating: true,
      borderRadius: 28,
      borderColor: colors.error.withValues(alpha: 0.28),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Red Danger Icon Container
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.error.withValues(alpha: 0.14),
              border: Border.all(
                color: colors.error.withValues(alpha: 0.38),
                width: 1.4,
              ),
            ),
            child: Icon(
              Icons.logout_rounded,
              color: colors.error,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            AppTranslations.get('logout_title', currentLang),
            style: KineticTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            AppTranslations.get('logout_sub', currentLang),
            style: KineticTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),

          // Action Buttons (Unified KineticButton pills — avoids ElevatedButton double-surface artifact)
          Row(
            children: [
              Expanded(
                child: KineticButton(
                  label: AppTranslations.get('cancel', currentLang),
                  variant: KineticButtonVariant.secondary,
                  height: 48,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KineticButton(
                  label: AppTranslations.get('logout', currentLang),
                  variant: KineticButtonVariant.danger,
                  height: 48,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
