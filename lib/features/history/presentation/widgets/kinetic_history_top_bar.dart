import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticHistoryTopBar extends StatelessWidget {
  final int totalCount;
  final AppLanguage currentLang;
  final bool isOffline;
  final VoidCallback? onCalendarTap;

  const KineticHistoryTopBar({
    super.key,
    required this.totalCount,
    required this.currentLang,
    this.isOffline = false,
    this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bool isSmallPhone = screenWidth < 375;

    final double titleFontSize = isSmallPhone ? 26.0 : 28.0;
    final double eyebrowFontSize = isSmallPhone ? 10.8 : 11.5;
    final double actionButtonSize = isSmallPhone ? 38.0 : 40.0;
    final double actionIconSize = isSmallPhone ? 18.0 : 19.0;
    final double badgeFontSize = isSmallPhone ? 10.8 : 11.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Eyebrow + Page Title (Clear & Prominent)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLang == AppLanguage.vi
                        ? 'Hoạt động đã lưu'
                        : 'Saved activities',
                    style: KineticTypography.tabEyebrowOf(colors).copyWith(
                      fontSize: eyebrowFontSize,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppTranslations.get('workout_history', currentLang),
                      style: KineticTypography.tabTitleOf(colors).copyWith(
                        fontSize: titleFontSize,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KineticTokens.spaceSM),

            if (totalCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: KineticTokens.spaceXS),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryTint,
                    borderRadius:
                        BorderRadius.circular(KineticTokens.radiusPill),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$totalCount ${currentLang == AppLanguage.vi ? "buổi" : "workouts"}',
                    style: KineticTypography.caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: badgeFontSize,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            KineticGlassIconButton(
              label: currentLang == AppLanguage.vi ? 'Lịch' : 'Calendar',
              size: actionButtonSize,
              visualSize: actionButtonSize,
              onPressed: onCalendarTap ?? () {},
              icon: BladeIcon(
                BladeIconName.cal,
                size: actionIconSize,
                color: colors.textSecondary,
                strokeWidth: 1.7,
              ),
            ),
          ],
        ),

        if (isOffline) ...[
          const SizedBox(height: KineticTokens.spaceXS),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceSM, vertical: KineticTokens.spaceXS),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 14, color: colors.tertiary),
                const SizedBox(width: KineticTokens.spaceXS),
                Expanded(
                  child: Text(
                    currentLang == AppLanguage.vi
                        ? 'Chế độ ngoại tuyến: dữ liệu được lưu cục bộ an toàn.'
                        : 'Offline mode: workouts saved locally.',
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
