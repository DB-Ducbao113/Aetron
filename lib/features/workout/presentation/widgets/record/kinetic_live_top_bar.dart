import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticLiveTopBar extends StatefulWidget {
  final String activityType;
  final bool isOutdoor;
  final bool isGpsWeak;
  final bool isAutoPaused;
  final bool isPaused;
  final int? pausedCountdownSeconds;
  final bool isLargeMetricsMode;
  final bool isVi;
  final VoidCallback onToggleMetricsMode;

  const KineticLiveTopBar({
    super.key,
    required this.activityType,
    required this.isOutdoor,
    required this.isGpsWeak,
    required this.isAutoPaused,
    required this.isPaused,
    this.pausedCountdownSeconds,
    required this.isLargeMetricsMode,
    required this.isVi,
    required this.onToggleMetricsMode,
  });

  @override
  State<KineticLiveTopBar> createState() => _KineticLiveTopBarState();
}

class _KineticLiveTopBarState extends State<KineticLiveTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!widget.isPaused && !widget.isAutoPaused) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant KineticLiveTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isInactive = widget.isPaused || widget.isAutoPaused;
    if (isInactive) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _activityLabel() {
    switch (widget.activityType.toLowerCase()) {
      case 'cycling':
        return widget.isVi ? 'Đang đạp xe' : 'Cycling';
      case 'running':
        return widget.isVi ? 'Đang chạy bộ' : 'Running';
      case 'walking':
        return widget.isVi ? 'Đang đi bộ' : 'Walking';
      default:
        return widget.isVi ? 'Đang tập luyện' : 'Workout';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final String statusText;
    final Color pulseColor;
    if (widget.isAutoPaused) {
      statusText = widget.isVi ? 'Tự động dừng' : 'Auto-paused';
      pulseColor = colors.tertiary;
    } else if (widget.isPaused) {
      if (widget.pausedCountdownSeconds != null && widget.pausedCountdownSeconds! > 0) {
        final clock = WorkoutFormatters.formatElapsedClock(widget.pausedCountdownSeconds!);
        statusText = widget.isVi ? 'Tạm dừng ($clock)' : 'Paused ($clock)';
      } else {
        statusText = widget.isVi ? 'Tạm dừng' : 'Paused';
      }
      pulseColor = colors.tertiary;
    } else {
      statusText = _activityLabel();
      pulseColor = colors.primary;
    }

    final String gpsLabel;
    final Color gpsColor;
    if (!widget.isOutdoor) {
      gpsLabel = widget.isVi ? 'Trong nhà' : 'Indoor';
      gpsColor = colors.textSecondary;
    } else if (widget.isGpsWeak) {
      gpsLabel = widget.isVi ? 'GPS Yếu' : 'Weak GPS';
      gpsColor = colors.tertiary;
    } else {
      gpsLabel = widget.isVi ? 'GPS Mạnh' : 'GPS Good';
      gpsColor = colors.primary;
    }

    final isAlertState = widget.isPaused || widget.isAutoPaused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. LEFT CORNER: Live Activity / Pause Status Pill (Góc trái màn hình)
          Flexible(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: KineticGradients.hudSurface(colors),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: isAlertState
                      ? colors.tertiary.withValues(alpha: 0.85)
                      : colors.borderSubtle.withValues(alpha: 0.7),
                  width: isAlertState ? 1.4 : 1.1,
                ),
                boxShadow: KineticTokens.shadowPanel(Colors.black),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pulse dot
                  FadeTransition(
                    opacity: isAlertState
                        ? const AlwaysStoppedAnimation(0.85)
                        : _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pulseColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KineticTypography.bodySmall.copyWith(
                        fontWeight: isAlertState ? FontWeight.w800 : FontWeight.w700,
                        color: isAlertState ? colors.tertiary : colors.textPrimary,
                        letterSpacing: isAlertState ? 0.3 : 0.0,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '•',
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Semantics(
                    label: gpsLabel,
                    child: widget.isOutdoor
                        ? BladeIcon(
                            BladeIconName.gps,
                            size: 13,
                            color: gpsColor,
                          )
                        : Icon(
                            Icons.sensors_rounded,
                            size: 13,
                            color: gpsColor,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. RIGHT CORNER: Symmetric Big Metrics Switcher (Góc phải màn hình đối xứng)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onToggleMetricsMode();
              },
              borderRadius: BorderRadius.circular(21),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: KineticGradients.hudSurface(colors),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: widget.isLargeMetricsMode
                        ? colors.primary.withValues(alpha: 0.85)
                        : colors.borderSubtle.withValues(alpha: 0.7),
                    width: widget.isLargeMetricsMode ? 1.4 : 1.1,
                  ),
                  boxShadow: KineticTokens.shadowPanel(Colors.black),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BladeIcon(
                      widget.isLargeMetricsMode
                          ? BladeIconName.map
                          : BladeIconName.chart,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isLargeMetricsMode
                          ? (widget.isVi ? 'Xem bản đồ' : 'Map View')
                          : (widget.isVi ? 'Số liệu lớn' : 'Big Metrics'),
                      style: KineticTypography.unitLabel.copyWith(
                        fontWeight: FontWeight.w800,
                        color: widget.isLargeMetricsMode
                            ? colors.primary
                            : colors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
