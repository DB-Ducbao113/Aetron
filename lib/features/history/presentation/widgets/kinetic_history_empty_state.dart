import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_backdrop.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KineticHistoryEmptyState extends ConsumerWidget {
  final AppLanguage currentLang;
  final bool isFiltered;

  const KineticHistoryEmptyState({
    super.key,
    required this.currentLang,
    this.isFiltered = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;

    return ClipRRect(
      borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
      child: Stack(
        children: [
          const Positioned.fill(child: TopographicBackdrop()),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceXL,
              vertical: KineticTokens.spaceXXXL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_list_off_rounded
                    : Icons.history_rounded,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: KineticTokens.spaceMD),
            Text(
              isFiltered
                  ? (currentLang == AppLanguage.vi
                        ? 'Không có buổi tập phù hợp bộ lọc'
                        : 'No workouts match your filter')
                  : AppTranslations.get('no_workouts_yet', currentLang),
              style: KineticTypography.headlineMedium.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KineticTokens.spaceXS),
            Text(
              isFiltered
                  ? (currentLang == AppLanguage.vi
                        ? 'Thử đổi khoảng thời gian hoặc môn tập khác để xem lại lịch sử.'
                        : 'Try selecting a different time range or sport filter.')
                  : AppTranslations.get('empty_history_desc', currentLang),
              style: KineticTypography.bodyMedium.copyWith(
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isFiltered) ...[
              const SizedBox(height: KineticTokens.spaceXL),
              KineticButton(
                label: currentLang == AppLanguage.vi
                    ? 'BẮT ĐẦU BUỔI TẬP'
                    : 'START A WORKOUT',
                icon: Icons.directions_run_rounded,
                isFullWidth: false,
                onPressed: () {
                  ref.read(mainTabControllerProvider.notifier).state =
                      activityTabIndex;
                },
              ),
            ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
