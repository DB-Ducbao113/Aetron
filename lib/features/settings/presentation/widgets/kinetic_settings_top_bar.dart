import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSettingsTopBar extends StatelessWidget {
  final AppLanguage currentLang;
  final String? title;
  final String? subtitle;
  final bool showVersionPill;

  const KineticSettingsTopBar({
    super.key,
    required this.currentLang,
    this.title,
    this.subtitle,
    this.showVersionPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final effectiveTitle =
        title ?? AppTranslations.get('settings', currentLang);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KineticGlassIconButton(
          size: 37,
          visualSize: 37,
          label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Theme.of(context).platform == TargetPlatform.iOS
              ? BladeIcon(
                  BladeIconName.chevL,
                  size: 18,
                  color: colors.textSecondary,
                  strokeWidth: 1.7,
                )
              : Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
        ),
        const SizedBox(width: KineticTokens.spaceSM),

        // Title
        Expanded(
          child: hasSubtitle
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      effectiveTitle,
                      style: KineticTypography.pageTitleCompact.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Text(
                  effectiveTitle,
                  style: KineticTypography.pageTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),

        // System Version Pill
        if (showVersionPill)
          ClipRRect(
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: colors.isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x2ECAE9FF),
                            Color(0x21314B6B),
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xCCFFFFFF),
                            Color(0x404EABE7),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  border: Border.all(
                    color: colors.isDark
                        ? const Color(0x4DB6DCFF)
                        : Colors.white.withValues(alpha: .90),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark
                          ? Colors.black.withValues(alpha: 0.20)
                          : const Color(0xFF1F406E).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'v1.0.0',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
