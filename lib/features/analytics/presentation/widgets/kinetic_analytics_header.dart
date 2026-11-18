import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
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
                child: Text(
                  isVi ? 'Phân tích' : 'Analytics',
                  style: KineticTypography.pageTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KineticTokens.spaceSM),

              // Sync / Offline Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceSM,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(
                    KineticTokens.radiusPill,
                  ),
                  boxShadow:
                      colors.isDark ? null : KineticTokens.shadowCardLight(),
                  border: colors.isDark
                      ? Border.all(color: colors.borderSubtle)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOffline ? colors.tertiary : colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOffline
                          ? (isVi ? 'Ngoại tuyến' : 'Offline')
                          : (isVi ? 'Đã đồng bộ' : 'Synced'),
                      style: KineticTypography.unitLabel.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // Period Filter — pill segmented control (Concept A)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            ),
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
    final bg = isSelected ? const Color(0xFF006EE6) : Colors.transparent;
    final textColor = isSelected ? Colors.white : colors.textSecondary;
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
          duration: KineticTokens.motionTab,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          ),
          child: Text(
            label,
            style: KineticTypography.label.copyWith(
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
