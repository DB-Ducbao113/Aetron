import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/iod_controller.dart';
import 'iod_ground_truth_sheet.dart';

/// Compact debug display pill showing live detected environment and sensor status.
///
/// Designed in accordance with Aetron's dark Kinetic theme.
/// Tapping the pill triggers the ground-truth marking modal during real-world tests.
class IodDebugPill extends ConsumerWidget {
  final bool isVi;

  const IodDebugPill({
    super.key,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iodState = ref.watch(iodControllerProvider);
    final prediction = iodState.currentPrediction;
    final snapshot = iodState.latestSnapshot;
    final state = prediction.state;

    final themeColor = state.color;
    final stateLabel = state.localizedLabel(isVi);
    final confidencePct = (prediction.confidence * 100).toStringAsFixed(0);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => IodGroundTruthSheet(isVi: isVi),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E212A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // State Icon with pulsing colored dot
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.icon,
                color: themeColor,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),

            // State Name + Confidence
            Text(
              '$stateLabel $confidencePct%',
              style: TextStyle(
                color: themeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),

            // Vertical divider
            Container(
              height: 12,
              width: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),

            // Mini sensor indicator dots
            _buildSensorPill(
              label: 'GNSS',
              isActive: snapshot?.hasGnssStatus == true || snapshot?.hasGpsFix == true,
              value: snapshot?.top4Cn0DbHz != null
                  ? '${snapshot!.top4Cn0DbHz!.toStringAsFixed(0)}dB'
                  : (snapshot?.horizontalAccuracy != null
                      ? '${snapshot!.horizontalAccuracy!.toStringAsFixed(0)}m'
                      : null),
              activeColor: (snapshot?.top4Cn0DbHz ?? 0) >= 28.0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 6),

            _buildSensorPill(
              label: 'LUX',
              isActive: snapshot?.hasLightSensor == true,
              value: snapshot?.ambientLux != null
                  ? '${snapshot!.ambientLux!.toStringAsFixed(0)}lx'
                  : null,
              activeColor: (snapshot?.ambientLux ?? 0) >= 1000.0
                  ? const Color(0xFF10B981)
                  : const Color(0xFF60A5FA),
            ),

            if (iodState.activeGroundTruth != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GT: ${iodState.activeGroundTruth!.code}',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorPill({
    required String label,
    required bool isActive,
    String? value,
    required Color activeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value ?? label,
          style: TextStyle(
            color: isActive
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
