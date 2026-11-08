import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticActivityQuickSwitch extends StatelessWidget {
  final String selectedActivity;
  final ValueChanged<String> onSelected;
  final bool isVi;

  const KineticActivityQuickSwitch({
    super.key,
    required this.selectedActivity,
    required this.onSelected,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final activities = [
      {
        'id': 'cycling',
        'label': isVi ? 'Đạp xe' : 'Cycling',
        'icon': Icons.directions_bike_rounded,
      },
      {
        'id': 'running',
        'label': isVi ? 'Chạy bộ' : 'Running',
        'icon': Icons.directions_run_rounded,
      },
      {
        'id': 'walking',
        'label': isVi ? 'Đi bộ' : 'Walking',
        'icon': Icons.directions_walk_rounded,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        KineticTokens.spaceXXS,
        KineticTokens.page,
        KineticTokens.spaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'CHỌN BỘ MÔN NHANH' : 'QUICK ACTIVITY SWITCH',
            style: KineticTypography.sectionEyebrow.copyWith(
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          Row(
            children: [
              for (int i = 0; i < activities.length; i++) ...[
                if (i > 0) const SizedBox(width: KineticTokens.spaceXS),
                Expanded(
                  child: _ActivityQuickSwitchCard(
                    id: activities[i]['id'] as String,
                    label: activities[i]['label'] as String,
                    icon: activities[i]['icon'] as IconData,
                    isSelected: selectedActivity == activities[i]['id'],
                    onTap: () => onSelected(activities[i]['id'] as String),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityQuickSwitchCard extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityQuickSwitchCard({
    required this.id,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final bg = isSelected ? colors.surface2 : colors.surface1;
    final borderColor = isSelected ? colors.primary : colors.borderSubtle;
    final contentColor = isSelected ? colors.primary : colors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          child: AnimatedContainer(
            duration: KineticTokens.motionTab,
            curve: KineticTokens.animCurve,
            padding: const EdgeInsets.symmetric(
              vertical: KineticTokens.spaceSM,
              horizontal: KineticTokens.spaceXS,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: contentColor,
                ),
                const SizedBox(width: KineticTokens.spaceXS),
                Flexible(
                  child: Text(
                    label,
                    style: KineticTypography.label.copyWith(
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
