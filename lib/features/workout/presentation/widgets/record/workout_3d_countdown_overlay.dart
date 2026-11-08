import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 3D Holographic Countdown Overlay for workout start (3... 2... 1... GO!).
class Workout3DCountdownOverlay extends StatefulWidget {
  final int countdown;
  final bool isLockingGps;
  final String activityType;
  final AppLanguage currentLang;
  final VoidCallback onSkip;

  const Workout3DCountdownOverlay({
    super.key,
    required this.countdown,
    required this.isLockingGps,
    required this.activityType,
    required this.currentLang,
    required this.onSkip,
  });

  @override
  State<Workout3DCountdownOverlay> createState() =>
      _Workout3DCountdownOverlayState();
}

class _Workout3DCountdownOverlayState extends State<Workout3DCountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotateAnimation;

  int _prevCountdown = -1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.linear),
    );

    _triggerHaptic(widget.countdown);
  }

  @override
  void didUpdateWidget(covariant Workout3DCountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.countdown != _prevCountdown) {
      _prevCountdown = widget.countdown;
      _triggerHaptic(widget.countdown);
    }
  }

  void _triggerHaptic(int count) {
    if (count > 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getAccentColor(KineticColors colors) {
    final type = widget.activityType.toLowerCase();
    if (type == 'running') return colors.secondary;
    return colors.tertiary;
  }

  IconData get _activityIcon {
    final type = widget.activityType.toLowerCase();
    if (type == 'cycling') return Icons.directions_bike_rounded;
    if (type == 'walking') return Icons.directions_walk_rounded;
    return Icons.directions_run_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;
    final accent = _getAccentColor(colors);

    final String statusText;
    final String subText;

    if (widget.isLockingGps) {
      statusText = isVi ? 'ĐANG KẾT NỐI GPS' : 'CONNECTING GPS';
      subText = isVi
          ? 'Đang xác định vị trí chính xác...'
          : 'Acquiring precise satellite location...';
    } else {
      switch (widget.countdown) {
        case 3:
          statusText = isVi ? 'CHUẨN BỊ' : 'GET READY';
          subText = isVi
              ? 'Hít thở sâu & chuẩn bị tư thế...'
              : 'Take a deep breath & get ready...';
          break;
        case 2:
          statusText = isVi ? 'SẴN SÀNG' : 'STEADY';
          subText = isVi
              ? 'GPS và cảm biến đã sẵn sàng...'
              : 'Sensors and GPS ready...';
          break;
        case 1:
          statusText = isVi ? 'XUẤT PHÁT' : 'SET';
          subText = isVi
              ? 'Bắt đầu trong 1 giây!'
              : 'Starting in 1 second!';
          break;
        default:
          statusText = isVi ? 'BẮT ĐẦU!' : 'GO!';
          subText = isVi
              ? 'Chúc bạn một buổi tập tuyệt vời!'
              : 'Have a great workout!';
          break;
      }
    }

    return GestureDetector(
      onTap: widget.onSkip,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: colors.background.withValues(alpha: 0.90),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ambient Radial Glow Background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.8 * _pulseAnimation.value,
                        colors: [
                          accent.withValues(alpha: 0.28),
                          accent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Corner Tech Brackets Overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _CountdownGridPainter(accent: accent),
              ),
            ),

            // 3. Central Holographic Countdown Ring & Number
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Activity Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_activityIcon, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.activityType.toUpperCase(),
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Center Holographic Orbital Ring & Giant Number
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Spinning Outer Dashed Ring
                        AnimatedBuilder(
                          animation: _rotateAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value,
                              child: Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Pulsing Inner Glow Core
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 175,
                                height: 175,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.75),
                                    width: 3,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Giant Number or GPS Spinner
                        if (widget.isLockingGps)
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          )
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.elasticOut,
                                ),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              widget.countdown > 0
                                  ? '${widget.countdown}'
                                  : 'GO!',
                              key: ValueKey(widget.countdown),
                              style: KineticTypography.metricMega.copyWith(
                                fontSize: widget.countdown > 0 ? 88 : 58,
                                color: colors.textPrimary,
                                letterSpacing: widget.countdown > 0 ? -4 : -1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Motivation & Status Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: KineticTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subText,
                          textAlign: TextAlign.center,
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 54),

                  // Tap to Skip / Start Immediate Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface2.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: accent.withValues(alpha: 0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVi ? 'CHẠM ĐỂ BẮT ĐẦU NGAY' : 'TAP TO START IMMEDIATELY',
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent.withValues(alpha: 0.9),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Cyber Corner Brackets Painter for Countdown Overlay.
class _CountdownGridPainter extends CustomPainter {
  final Color accent;

  const _CountdownGridPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const pad = 24.0;
    const len = 28.0;

    // Top-Left
    canvas.drawLine(
        const Offset(pad, pad + len), const Offset(pad, pad), paint);
    canvas.drawLine(
        const Offset(pad, pad), const Offset(pad + len, pad), paint);

    // Top-Right
    canvas.drawLine(
        Offset(size.width - pad - len, pad), Offset(size.width - pad, pad), paint);
    canvas.drawLine(
        Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), paint);

    // Bottom-Left
    canvas.drawLine(
        Offset(pad, size.height - pad - len), Offset(pad, size.height - pad), paint);
    canvas.drawLine(
        Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad - len, size.height - pad),
        Offset(size.width - pad, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad - len),
        Offset(size.width - pad, size.height - pad), paint);
  }

  @override
  bool shouldRepaint(covariant _CountdownGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
