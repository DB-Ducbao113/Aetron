import 'dart:async';
import 'dart:math' as math;
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Startup screen that draws the official AETRON Logo 02B ("E liền nét")
/// vector mark and wordmark before transitioning into [AetronGlobeOrbitScreen].
class AetronLogoDrawScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final bool? forceDarkPalette;

  const AetronLogoDrawScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1400),
    this.forceDarkPalette,
  });

  @override
  State<AetronLogoDrawScreen> createState() => _AetronLogoDrawScreenState();
}

class _AetronLogoDrawScreenState extends State<AetronLogoDrawScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _strokeAnim;
  late final Animation<double> _fillAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _wordmarkAnim;
  late final Animation<double> _glowAnim;

  bool _completed = false;
  Timer? _completionTimer;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _strokeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.48, curve: Curves.easeInOutCubic),
    );
    _fillAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.68, curve: Curves.easeOutCubic),
    );
    _wordmarkAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.76, curve: Curves.easeOutCubic),
    );
    _shimmerAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.64, 0.92, curve: Curves.easeInOut),
    );
    _glowAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.75, curve: Curves.easeOutQuad),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          !_completed &&
          widget.onComplete != null) {
        _completed = true;
        _completionTimer = Timer(const Duration(milliseconds: 280), () {
          if (mounted) widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant AetronLogoDrawScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged =
        (oldWidget.onComplete == null) != (widget.onComplete == null);
    final durationChanged = oldWidget.duration != widget.duration;
    if (!modeChanged && !durationChanged) return;
    _controller.duration = widget.duration;
    if (modeChanged) {
      _completionTimer?.cancel();
      _completed = false;
      _controller.reset();
    }
    _configureAnimation();
  }

  void _configureAnimation() {
    if (_animationsDisabled == true) {
      _controller.stop();
      _controller.value = widget.onComplete == null ? 0.65 : 1.0;
    } else if (widget.onComplete != null) {
      if (!_completed) _controller.forward(from: _controller.value);
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.forceDarkPalette ??
        (Theme.of(context).brightness == Brightness.dark);
    final bgColor = isDark ? KineticColors.dark.background : Colors.white;
    final markColor = isDark
        ? const Color(0xFF93BFFF)
        : const Color(0xFF1166DB);
    final wordmarkColor = isDark
        ? const Color(0xFFF3F7FF)
        : const Color(0xFF152437);
    final tipColor = isDark ? const Color(0xFFF3F7FF) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (isDark)
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (context, child) {
                  final g = _glowAnim.value;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.20, -0.30),
                        radius: 1.25,
                        colors: [
                          const Color(0xFF29405D).withValues(alpha: 0.48 * g),
                          const Color(0xFF182B42).withValues(alpha: 0.42 * g),
                          bgColor,
                        ],
                        stops: const [0.0, 0.48, 1.0],
                      ),
                    ),
                  );
                },
              ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final markWidth = math.min(
                    constraints.maxWidth * 0.44,
                    176.0,
                  );
                  final markHeight =
                      markWidth *
                      (AetronLogoPaths.markHeight / AetronLogoPaths.markWidth);
                  final wordmarkWidth = math.min(
                    constraints.maxWidth * 0.46,
                    184.0,
                  );
                  final wordmarkHeight =
                      wordmarkWidth *
                      (AetronLogoPaths.wordmarkHeight /
                          AetronLogoPaths.wordmarkWidth);

                  return Center(
                    child: Semantics(
                      label: 'Aetron logo',
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final slideOffset =
                              (1.0 - _wordmarkAnim.value) * 8.0;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                key: const ValueKey('aetron-logo-draw-mark'),
                                width: markWidth,
                                height: markHeight,
                                child: CustomPaint(
                                  size: Size(markWidth, markHeight),
                                  painter: AetronBrandMarkPainter(
                                    strokeProgress: _strokeAnim.value,
                                    fillProgress: _fillAnim.value,
                                    shimmerProgress: _shimmerAnim.value,
                                    color: markColor,
                                    tipColor: tipColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Transform.translate(
                                offset: Offset(0, slideOffset),
                                child: SizedBox(
                                  key: const ValueKey(
                                    'aetron-logo-draw-wordmark',
                                  ),
                                  width: wordmarkWidth,
                                  height: wordmarkHeight,
                                  child: CustomPaint(
                                    size: Size(wordmarkWidth, wordmarkHeight),
                                    painter: AetronWordmarkPainter(
                                      progress: _wordmarkAnim.value,
                                      shimmerProgress: _shimmerAnim.value,
                                      accentColor: markColor,
                                      color: wordmarkColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
