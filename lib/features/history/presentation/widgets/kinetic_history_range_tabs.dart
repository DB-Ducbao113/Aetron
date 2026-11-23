import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_sliding_selection.dart';
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
    final ios = Theme.of(context).platform == TargetPlatform.iOS;

    if (NativeLiquidGlass.enabledOf(context)) {
      return SizedBox(
        height: KineticTokens.segmentedControlHeight,
        child: NativeGlassSegmentedControl(
          labels: HistoryRange.values
              .map((range) => range.getLabel(currentLang))
              .toList(growable: false),
          symbols: const [],
          selectedIndex: HistoryRange.values.indexOf(selected),
          onChanged: (index) {
            if (index < 0 || index >= HistoryRange.values.length) return;
            HapticFeedback.selectionClick();
            onChanged(HistoryRange.values[index]);
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceXXS),
      decoration: BoxDecoration(
        color: colors.isDark
            ? colors.surface1.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: Border.all(
          color: colors.isDark
              ? Colors.white.withValues(alpha: 0.14)
              : colors.borderSubtle,
        ),
      ),
      child: KineticSlidingSelection(
        index: HistoryRange.values.indexOf(selected),
        count: HistoryRange.values.length,
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
                  duration: KineticTokens.respectingReduceMotion(
                    context,
                    KineticTokens.motionTab,
                  ),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected && !ios
                        ? colors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      KineticTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    label,
                    style: KineticTypography.segmentedLabel.copyWith(
                      color: isSelected
                          ? (ios ? colors.primary : colors.onPrimary)
                          : colors.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
