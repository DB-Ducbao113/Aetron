import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticSensorStatusBar extends StatelessWidget {
  final bool isGpsReady;
  final String? statusText;
  final String? environmentText;
  final bool isVi;

  const KineticSensorStatusBar({
    super.key,
    this.isGpsReady = true,
    this.statusText,
    this.environmentText,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final defaultStatus = isVi ? 'Ngoài trời (GPS sẵn sàng)' : 'Outdoor (GPS Ready)';
    final defaultEnv = isVi ? 'Thời tiết lý tưởng · 24°C' : 'Optimal weather · 24°C';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXXS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // GPS / Sensor Pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceSM,
              vertical: KineticTokens.spaceXXS,
            ),
            decoration: BoxDecoration(
              color: colors.surface1.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isGpsReady ? colors.primary : colors.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: KineticTokens.spaceXXS),
                Text(
                  statusText ?? defaultStatus,
                  style: KineticTypography.unitLabel.copyWith(
                    color: isGpsReady ? colors.primary : colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Environment Pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceSM,
              vertical: KineticTokens.spaceXXS,
            ),
            decoration: BoxDecoration(
              color: colors.surface1.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 13,
                  color: colors.secondary,
                ),
                const SizedBox(width: KineticTokens.spaceXXS),
                Text(
                  environmentText ?? defaultEnv,
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
