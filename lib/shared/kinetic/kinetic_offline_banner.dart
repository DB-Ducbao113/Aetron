import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KineticOfflineBanner extends ConsumerWidget {
  final AppLanguage? language;
  const KineticOfflineBanner({super.key, this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final lang = language ?? ref.watch(appLanguageProvider);
    final isVi = lang == AppLanguage.vi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.tertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isVi
                  ? 'Chế độ ngoại tuyến — Hiển thị dữ liệu đã lưu'
                  : 'Offline mode — Showing saved data',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
