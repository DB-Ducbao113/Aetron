import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticCategoryFilterTabs extends StatelessWidget {
  final BadgeCategory selectedCategory;
  final AppLanguage currentLang;
  final ValueChanged<BadgeCategory> onSelectCategory;

  const KineticCategoryFilterTabs({
    super.key,
    required this.selectedCategory,
    required this.currentLang,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    const categories = BadgeCategory.values;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: KineticTokens.spaceXS),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;

          return Semantics(
            button: true,
            selected: isSelected,
            label: cat.label(currentLang),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectCategory(cat);
              },
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: AnimatedContainer(
                duration: KineticTokens.motionTab,
                padding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceSM,
                  vertical: KineticTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.surface1,
                  borderRadius:
                      BorderRadius.circular(KineticTokens.radiusPill),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.borderSubtle,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 14,
                      color: isSelected ? colors.onPrimary : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label(currentLang),
                      style: KineticTypography.bodySmall.copyWith(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? colors.onPrimary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
