import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticHistorySportFilter extends StatelessWidget {
  final String selected;
  final AppLanguage currentLang;
  final ValueChanged<String> onSelected;

  const KineticHistorySportFilter({
    super.key,
    required this.selected,
    required this.currentLang,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    final filters = [
      {'id': 'all', 'label': isVi ? 'Tất cả' : 'All', 'icon': Icons.apps_rounded},
      {'id': 'running', 'label': isVi ? 'Chạy bộ' : 'Running', 'icon': Icons.directions_run_rounded},
      {'id': 'cycling', 'label': isVi ? 'Đạp xe' : 'Cycling', 'icon': Icons.directions_bike_rounded},
      {'id': 'walking', 'label': isVi ? 'Đi bộ' : 'Walking', 'icon': Icons.directions_walk_rounded},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: KineticTokens.spaceXS),
        itemBuilder: (context, index) {
          final f = filters[index];
          final id = f['id'] as String;
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = selected.toLowerCase() == id.toLowerCase();

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(id);
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
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? colors.onPrimary : colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: KineticTypography.label.copyWith(
                      color: isSelected
                          ? colors.onPrimary
                          : colors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
