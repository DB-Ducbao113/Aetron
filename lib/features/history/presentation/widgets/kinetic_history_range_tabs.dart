import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticHistoryRangeTabs extends StatelessWidget {
  final HistoryRange selected;
  final AppLanguage currentLang;
  final ValueChanged<HistoryRange> onChanged;

  const KineticHistoryRangeTabs({
    super.key,
    required this.selected,
    required this.currentLang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceXXS),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: HistoryRange.values.map((range) {
          final isSelected = selected == range;
          final label = range.getLabel(currentLang);

          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(range);
              },
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: AnimatedContainer(
                duration: KineticTokens.motionTab,
                padding: const EdgeInsets.symmetric(
                  vertical: KineticTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    KineticTokens.radiusPill,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: KineticTypography.label.copyWith(
                      color: isSelected
                          ? colors.onPrimary
                          : colors.textMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
