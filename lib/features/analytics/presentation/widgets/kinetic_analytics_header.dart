import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticAnalyticsHeader extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final bool isOffline;
  final bool isVi;

  const KineticAnalyticsHeader({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.isOffline,
    required this.isVi,
  });

  String _periodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.week:
        return isVi ? 'Tuần này' : 'This Week';
      case TimePeriod.month:
        return isVi ? 'Tháng này' : 'This Month';
      case TimePeriod.year:
        return isVi ? 'Năm nay' : 'This Year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final useNativeGlass = NativeLiquidGlass.enabledOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: KineticTokens.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Sync Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVi ? 'Hiệu suất' : 'Performance',
                      style: KineticTypography.tabEyebrowOf(colors),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isVi ? 'Phân tích' : 'Analytics',
                        style: KineticTypography.tabTitleOf(colors),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // Period Filter — pill segmented control (Concept A)
          if (useNativeGlass)
            SizedBox(
              height: KineticTokens.segmentedControlHeight,
              child: NativeGlassSegmentedControl(
                labels: TimePeriod.values
                    .map(_periodLabel)
                    .toList(growable: false),
                symbols: const [],
                selectedIndex: TimePeriod.values.indexOf(selectedPeriod),
                onChanged: (index) {
                  if (index < 0 || index >= TimePeriod.values.length) return;
                  HapticFeedback.selectionClick();
                  onPeriodChanged(TimePeriod.values[index]);
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              ),
              child: KineticSlidingSelection(
                index: TimePeriod.values.indexOf(selectedPeriod),
                count: TimePeriod.values.length,
                gap: KineticTokens.spaceXXS,
                child: Row(
                  children: [
                    for (int i = 0; i < TimePeriod.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: KineticTokens.spaceXXS),
                      Expanded(
                        child: _buildPeriodTab(
                          context,
                          colors,
                          TimePeriod.values[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(
    BuildContext context,
    KineticColors colors,
    TimePeriod period,
  ) {
    final isSelected = selectedPeriod == period;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final bg = isSelected && !ios
        ? const Color(0xFF006EE6)
        : Colors.transparent;
    final textColor = isSelected
        ? (ios ? colors.primary : Colors.white)
        : colors.textSecondary;
    final label = _periodLabel(period);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onPeriodChanged(period);
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
            color: bg,
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          child: Text(
            label,
            style: KineticTypography.segmentedLabel.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
