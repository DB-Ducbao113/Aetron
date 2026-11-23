import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_sliding_selection.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
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
    final ios = Theme.of(context).platform == TargetPlatform.iOS;

    final filters = [
      {
        'id': 'all',
        'label': isVi ? 'Tất cả' : 'All',
      },
      {
        'id': 'running',
        'label': isVi ? 'Chạy bộ' : 'Running',
      },
      {
        'id': 'cycling',
        'label': isVi ? 'Đạp xe' : 'Cycling',
      },
      {
        'id': 'walking',
        'label': isVi ? 'Đi bộ' : 'Walking',
      },
    ];

    final selectedIndex = filters.indexWhere(
      (filter) =>
          (filter['id'] as String).toLowerCase() == selected.toLowerCase(),
    );
    final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    if (NativeLiquidGlass.enabledOf(context)) {
      return SizedBox(
        height: KineticTokens.segmentedControlHeight,
        child: NativeGlassSegmentedControl(
          labels: filters
              .map((filter) => filter['label'] as String)
              .toList(growable: false),
          symbols: const [],
          selectedIndex: activeIndex,
          onChanged: (index) {
            if (index < 0 || index >= filters.length) return;
            HapticFeedback.selectionClick();
            onSelected(filters[index]['id'] as String);
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
        index: activeIndex,
        count: filters.length,
        child: Row(
          children: filters.asMap().entries.map((entry) {
            final index = entry.key;
            final f = entry.value;
            final id = f['id'] as String;
            final label = f['label'] as String;
            final isSelected = activeIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(id);
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
