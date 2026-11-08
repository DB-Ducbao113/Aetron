import 'dart:async';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating 3D HUD Toast banner shown at the top of the Record screen
/// whenever a new 1km (or lap) split is recorded.
class LiveLapHudToast extends StatefulWidget {
  final WorkoutLapSplit split;
  final WorkoutLapSplit? previousSplit;
  final bool useMetricUnits;
  final AppLanguage currentLang;
  final VoidCallback onDismiss;

  const LiveLapHudToast({
    super.key,
    required this.split,
    this.previousSplit,
    required this.useMetricUnits,
    required this.currentLang,
    required this.onDismiss,
  });

  @override
  State<LiveLapHudToast> createState() => _LiveLapHudToastState();
}

class _LiveLapHudToastState extends State<LiveLapHudToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    // Haptic feedback alert
    HapticFeedback.heavyImpact();

    // Auto dismiss after 5 seconds
    _dismissTimer = Timer(const Duration(seconds: 5), _hideAndDismiss);
  }

  Future<void> _hideAndDismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void didUpdateWidget(LiveLapHudToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.split != widget.split) {
      _dismissTimer?.cancel();
      _ctrl.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      _dismissTimer = Timer(const Duration(seconds: 5), _hideAndDismiss);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;
    final split = widget.split;
    final prev = widget.previousSplit;

    final unitLabel =
        WorkoutFormatters.distanceUnitLabel(useMetric: widget.useMetricUnits)
            .toUpperCase();
    final lapTitle = isVi
        ? '$unitLabel ${split.index} HOÀN THÀNH!'
        : '$unitLabel ${split.index} COMPLETED!';

    final paceStr = WorkoutFormatters.formatPaceFromSecondsPerKm(
      split.durationSeconds.toDouble(),
      useMetric: widget.useMetricUnits,
    );

    // Delta pace vs previous lap split
    String? deltaText;
    Color deltaColor = colors.primary;
    IconData deltaIcon = Icons.bolt_rounded;

    if (prev != null) {
      final diffSec = prev.durationSeconds - split.durationSeconds;
      if (diffSec > 1) {
        // Faster
        deltaText = isVi
            ? '⚡ Nhanh hơn ${diffSec}s so với $unitLabel ${prev.index}'
            : '⚡ ${diffSec}s faster than $unitLabel ${prev.index}';
        deltaColor = const Color(0xFF2AF598);
        deltaIcon = Icons.trending_up_rounded;
      } else if (diffSec < -1) {
        // Slower
        final absDiff = -diffSec;
        deltaText = isVi
            ? '🐢 Chậm hơn ${absDiff}s so với $unitLabel ${prev.index}'
            : '🐢 ${absDiff}s slower than $unitLabel ${prev.index}';
        deltaColor = const Color(0xFFFF9F1C);
        deltaIcon = Icons.trending_down_rounded;
      } else {
        // Steady
        deltaText = isVi ? '🎯 Giữ nhịp độ hoàn hảo' : '🎯 Steady pace maintained';
        deltaColor = colors.primary;
        deltaIcon = Icons.remove_rounded;
      }
    }

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: _hideAndDismiss,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: KineticGradients.hudSurface(colors),
              borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
              border: Border.all(
                color: deltaColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: KineticTokens.shadowPanel(Colors.black),
            ),
            child: Row(
              children: [
                // Lap Emblem
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: deltaColor.withValues(alpha: 0.18),
                    border: Border.all(color: deltaColor.withValues(alpha: 0.6)),
                  ),
                  child: Center(
                    child: Text(
                      '${split.index}',
                      style: KineticTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: deltaColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lapTitle,
                        style: KineticTypography.unitLabel.copyWith(
                          fontWeight: FontWeight.w800,
                          color: deltaColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            paceStr,
                            style: KineticTypography.metricSmall.copyWith(
                              color: colors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isVi ? 'Pace chặng' : 'Split Pace',
                            style: KineticTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      if (deltaText != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(deltaIcon, size: 12, color: deltaColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                deltaText,
                                style: KineticTypography.unitLabel.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: deltaColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Dismiss Icon
                Icon(
                  Icons.close_rounded,
                  color: colors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live Pace Consistency & Delta Bar Widget
/// Shows real-time delta between candidate current speed and average speed.
class LiveDeltaPaceGauge extends StatelessWidget {
  final double currentSpeedKmh;
  final double avgSpeedKmh;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const LiveDeltaPaceGauge({
    super.key,
    required this.currentSpeedKmh,
    required this.avgSpeedKmh,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    final diffKmh = currentSpeedKmh - avgSpeedKmh;
    final isFaster = diffKmh > 0.3;
    final isSlower = diffKmh < -0.3;

    final statusColor = isFaster
        ? const Color(0xFF2AF598)
        : isSlower
            ? const Color(0xFFFF9F1C)
            : colors.primary;

    final statusText = isFaster
        ? (isVi ? '▲ Nhanh hơn TB' : '▲ Faster than avg')
        : isSlower
            ? (isVi ? '▼ Chậm hơn TB' : '▼ Slower than avg')
            : (isVi ? '● Đúng nhịp độ' : '● On Pace');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: KineticTypography.unitLabel.copyWith(
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
