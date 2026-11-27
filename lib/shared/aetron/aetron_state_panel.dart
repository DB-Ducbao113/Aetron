import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AetronStateTone { error, offline }

class AetronStatePanel extends ConsumerWidget {
  const AetronStatePanel({
    super.key,
    required this.title,
    required this.message,
    required this.tone,
    this.retryLabel,
    this.onRetry,
  });

  final String title;
  final String message;
  final AetronStateTone tone;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isVi = lang == AppLanguage.vi;
    final isOffline = tone == AetronStateTone.offline;
    final accent = isOffline ? AetronColors.gold : AetronColors.danger;
    final icon = isOffline
        ? Icons.cloud_off_rounded
        : Icons.error_outline_rounded;
    return AetronGlassCard(
      radius: 14,
      borderColor: accent.withValues(alpha: 0.42),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AetronColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: const TextStyle(
              color: AetronColors.muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: Text(
                  retryLabel ?? (isVi ? 'Thử lại' : 'Retry'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AetronOfflineBanner extends ConsumerWidget {
  const AetronOfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isVi = lang == AppLanguage.vi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AetronColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AetronColors.gold.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AetronColors.gold, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVi
                  ? 'CHẾ ĐỘ NGOẠI TUYẾN - HIỂN THỊ DỮ LIỆU ĐÃ LƯU'
                  : 'OFFLINE MODE - SHOWING SAVED DATA',
              style: const TextStyle(
                color: AetronColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
