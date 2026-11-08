import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummaryHeader extends StatelessWidget {
  final String activityType;
  final String trackingMode;
  final AppLanguage currentLang;
  final VoidCallback onBackToHome;
  final VoidCallback? onShare;

  const KineticSummaryHeader({
    super.key,
    required this.activityType,
    this.trackingMode = 'outdoor',
    required this.currentLang,
    required this.onBackToHome,
    this.onShare,
  });

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'running':
      default:
        return Icons.directions_run_rounded;
    }
  }

  String _getActivityName(String type, AppLanguage lang) {
    switch (type.toLowerCase()) {
      case 'cycling':
        return lang == AppLanguage.vi ? 'Đạp xe' : 'Cycling';
      case 'walking':
        return lang == AppLanguage.vi ? 'Đi bộ' : 'Walking';
      case 'running':
      default:
        return lang == AppLanguage.vi ? 'Chạy bộ' : 'Running';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final activityIcon = _getActivityIcon(activityType);
    final activityName = _getActivityName(activityType, currentLang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Action Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              button: true,
              label: currentLang == AppLanguage.vi ? 'Quay về trang chủ' : 'Return to home',
              child: InkWell(
                onTap: onBackToHome,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                AppTranslations.get('workout_summary', currentLang),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.pageTitleCompact.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (onShare != null)
              Semantics(
                button: true,
                label: currentLang == AppLanguage.vi ? 'Chia sẻ buổi tập' : 'Share workout',
                child: InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Icon(
                      Icons.ios_share_rounded,
                      color: colors.primary,
                      size: 19,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 16),

        // Activity & Status Row (Đã bỏ GPS Ngoài trời)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(activityIcon, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    activityName,
                    style: KineticTypography.label.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              currentLang == AppLanguage.vi ? 'Đã lưu' : 'Saved',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
