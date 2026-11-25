import 'dart:async';
import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kinetic 3D Globe Orbit Screen / Màn hình visualizer địa cầu 3D Kinetic
class AetronGlobeOrbitScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final String? customTitle;
  final String? customSubtitle;
  final bool showCloseButton;
  final String? statusPillText;
  final bool forceDarkPalette;
  final bool showTelemetryChips;
  final bool showSubtitle;

  const AetronGlobeOrbitScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 3600),
    this.customTitle,
    this.customSubtitle,
    this.showCloseButton = false,
    this.statusPillText,
    this.forceDarkPalette = false,
    this.showTelemetryChips = false,
    this.showSubtitle = false,
  });

  @override
  ConsumerState<AetronGlobeOrbitScreen> createState() =>
      _AetronGlobeOrbitScreenState();
}

class _AetronGlobeOrbitScreenState extends ConsumerState<AetronGlobeOrbitScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;
  Timer? _completionTimer;
  bool? _animationsDisabled;
  final _userRotationOffset = ValueNotifier<double>(0);
  late final Listenable _globeMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            !_completed &&
            widget.onComplete != null) {
          _completed = true;
          _completionTimer = Timer(const Duration(milliseconds: 180), () {
            if (mounted) widget.onComplete?.call();
          });
        }
      });
    _globeMotion = Listenable.merge([_controller, _userRotationOffset]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;
    _animationsDisabled = animationsDisabled;
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant AetronGlobeOrbitScreen oldWidget) {
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
      _controller.value = widget.onComplete == null ? 0.18 : 1;
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
    _userRotationOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.forceDarkPalette
        ? KineticColors.dark
        : context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Radial Glow Background aligned with Kinetic palette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.35,
                  colors: [
                    colors.primary.withValues(alpha: 0.12),
                    colors.surface1.withValues(alpha: 0.5),
                    colors.background,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. Safe Area Interactive Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactWidth = constraints.maxWidth <= 360;
                final compactHeight = constraints.maxHeight < 650;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (canPop && widget.showCloseButton)
                            Positioned(
                              left: 12,
                              child: IconButton(
                                tooltip: isVi ? 'Đóng' : 'Close',
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: colors.surface2.withValues(
                                    alpha: 0.8,
                                  ),
                                  side: BorderSide(color: colors.borderSubtle),
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 64),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface2.withValues(
                                      alpha: 0.85,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary.withValues(
                                                alpha: 0.7,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        widget.statusPillText ??
                                            (isVi
                                                ? 'Đang tải dữ liệu'
                                                : 'Loading data'),
                                        style: KineticTypography.unitLabel
                                            .copyWith(
                                              color: colors.primary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: LayoutBuilder(
                              builder: (context, globeConstraints) {
                                final globeSize = math.min(
                                  310.0,
                                  math.min(
                                    math.max(
                                      0.0,
                                      globeConstraints.maxWidth - 24,
                                    ),
                                    globeConstraints.maxHeight,
                                  ),
                                );
                                return Center(
                                  heightFactor: 1,
                                  child: Semantics(
                                    image: true,
                                    label: isVi
                                        ? 'Địa cầu GPS đang đồng bộ'
                                        : 'GPS globe synchronizing',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragUpdate: (details) {
                                        _userRotationOffset.value -=
                                            (details.primaryDelta ?? 0) / 85.0;
                                      },
                                      child: SizedBox.square(
                                        key: const ValueKey(
                                          'aetron-globe-canvas',
                                        ),
                                        dimension: globeSize,
                                        child: ClipRect(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              for (final layer
                                                  in _GlobeLayer.values)
                                                RepaintBoundary(
                                                  child: CustomPaint(
                                                    painter: _CyberGlobePainter(
                                                      progress: _controller,
                                                      userRotation:
                                                          _userRotationOffset,
                                                      colors: colors,
                                                      layer: layer,
                                                      motion: _globeMotion,
                                                    ),
                                                    isComplex: true,
                                                    willChange: layer.animated,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compactHeight ? 6 : 20),
                          Text(
                            widget.customTitle ?? 'Aetron',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: KineticTypography.headlineLarge.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: colors.primary.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          if (widget.showTelemetryChips) ...[
                            SizedBox(height: compactHeight ? 12 : 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _telemetryChip(
                                      icon: Icons.satellite_alt_rounded,
                                      label: compactWidth
                                          ? '12 GPS'
                                          : (isVi
                                                ? '12 vệ tinh GPS'
                                                : '12 GPS sats'),
                                      semanticLabel: isVi
                                          ? 'Đã kết nối 12 vệ tinh GPS'
                                          : 'Connected to 12 GPS satellites',
                                      color: colors.primary,
                                      colors: colors,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _telemetryChip(
                                      icon: Icons.wifi_tethering_rounded,
                                      label: compactWidth
                                          ? '20,200 km'
                                          : (isVi
                                                ? 'Độ cao 20,200 km'
                                                : 'Alt 20,200 km'),
                                      semanticLabel: isVi
                                          ? 'Độ cao vệ tinh 20.200 ki-lô-mét'
                                          : 'Satellite altitude 20,200 kilometers',
                                      color: colors.secondary,
                                      colors: colors,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: compactHeight ? 14 : 28,
                      ),
                      child: Center(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => _buildProgress(
                              progress: _controller.value,
                              colors: colors,
                              isVi: isVi,
                              barWidth: compactWidth ? 260.0 : 310.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _telemetryChip({
    required IconData icon,
    required String label,
    required String semanticLabel,
    required Color color,
    required KineticColors colors,
  }) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: KineticTypography.unitLabel.copyWith(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress({
    required double progress,
    required KineticColors colors,
    required bool isVi,
    required double barWidth,
  }) {
    final percentInt = (progress.clamp(0.0, 1.0) * 100).toInt();
    final track = BoxDecoration(
      color: colors.isDark ? const Color(0x2995BDE4) : const Color(0x295490CB),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colors.isDark ? const Color(0x21B6D3F2) : const Color(0x42A1CFF8),
        width: 1.0,
      ),
    );

    const barHeight = 7.0;
    final Widget bar;
    if (widget.onComplete != null) {
      bar = Container(
        width: barWidth,
        height: barHeight,
        decoration: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: DecoratedBox(decoration: _progressFill(colors)),
        ),
      );
    } else {
      bar = Container(
        width: barWidth,
        height: barHeight,
        decoration: track,
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pillWidth = constraints.maxWidth * 0.45;
            final offset =
                (constraints.maxWidth + pillWidth) * progress - pillWidth;
            return Stack(
              children: [
                Positioned(
                  left: offset,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: DecoratedBox(decoration: _progressFill(colors)),
                ),
              ],
            );
          },
        ),
      );
    }

    final label =
        widget.customSubtitle ?? (isVi ? 'Đang tải...' : 'Loading...');

    return SizedBox(
      width: barWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.bodyMedium.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percentInt%',
                style: KineticTypography.headlineSmall.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                  letterSpacing: 0.5,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          bar,
        ],
      ),
    );
  }

  BoxDecoration _progressFill(KineticColors colors) => BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF398BF6),
        Color(0xFF71B6FC),
        Color(0xFFACE9F7),
      ],
      stops: [0.0, 0.56, 1.0],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: Color(0x6353A6F3),
        blurRadius: 10,
      ),
    ],
  );
}

/// Pure 3D Kinetic Earth Globe with Atmospheric Glow, Rotating Continents & Orbital Telemetry
enum _GlobeLayer {
  background,
  surface,
  foreground,
  telemetry;

  bool get animated => this == surface || this == telemetry;
}

class _CyberGlobePainter extends CustomPainter {
  final Animation<double> progress;
  final ValueListenable<double> userRotation;
  final KineticColors colors;
  final _GlobeLayer layer;

  _CyberGlobePainter({
    required this.progress,
    required this.userRotation,
    required this.colors,
    required this.layer,
    required Listenable motion,
  }) : super(repaint: layer.animated ? motion : null);

  @override
  void paint(Canvas canvas, Size size) {
    // One canonical scene ensures all details, including stars and beacon,
    // scale uniformly and stay centered on small and large viewports.
    final scale = size.shortestSide / 310;
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    const center = Offset.zero;
    const globeRadius = 310 * 0.28;
    const orbitRadiusX = 310 * 0.44;
    const orbitRadiusY = 310 * 0.22;
    final orbitTilt = -math.pi / 7.5; // ~ -24 degrees

    // Current rotation of Earth (auto animation + touch user offset)
    final phase = progress.value;
    final earthRotation = (phase * 2 * math.pi) + userRotation.value;
    final globeRect = Rect.fromCircle(center: center, radius: globeRadius);

    if (layer == _GlobeLayer.background) {
      // ── 1. Atmospheric Nebula Glow (Behind Globe) ───────────────────────────
      final glowAtmospherePrimary = colors.isDark
          ? colors.primary
          : const Color(0xFF0EA5E9);
      final glowAtmosphereSecondary = colors.isDark
          ? colors.secondary
          : const Color(0xFF38BDF8);

      canvas.drawCircle(
        center,
        globeRadius + 32,
        Paint()
          ..color = glowAtmospherePrimary.withValues(
            alpha: colors.isDark ? 0.16 : 0.22,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
      canvas.drawCircle(
        center,
        globeRadius + 14,
        Paint()
          ..color = glowAtmosphereSecondary.withValues(
            alpha: colors.isDark ? 0.18 : 0.24,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );

      // ── 2. Back Half of Tilted Orbital Telemetry Track ──────────────────────
      _drawOrbitTrack(
        canvas: canvas,
        center: center,
        radiusX: orbitRadiusX,
        radiusY: orbitRadiusY,
        tilt: orbitTilt,
        isFrontHalf: false,
      );

      // ── 3. Cyber Earth Sphere Base (Blue Ocean with 3D Spherical Shader) ────
      // Outer Globe Rim Glow (Pre-clip)
      final outerRimColor = colors.isDark
          ? colors.primary
          : const Color(0xFF0284C7);

      canvas.drawCircle(
        center,
        globeRadius + 1.5,
        Paint()
          ..color = outerRimColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Clip to Globe Sphere for all surface rendering
      canvas.save();
      canvas.clipPath(Path()..addOval(globeRect));

      // 3a. Deep Ocean 3D Gradient (True Blue Planet Earth)
      final oceanColors = colors.isDark
          ? const [
              Color(0xFF1E3A8A), // Deep oceanic sapphire highlight
              Color(0xFF0F172A), // Midnight oceanic navy
              Color(0xFF020617), // Cosmic abyss
            ]
          : const [
              Color(0xFF2563EB), // Rich vibrant royal sapphire blue
              Color(0xFF1D4ED8), // Deep cobalt oceanic blue
              Color(0xFF0F172A), // Deep oceanic navy depth
            ];

      final oceanPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: oceanColors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(globeRect);
      canvas.drawRect(globeRect, oceanPaint);

      // 3b. Latitude Grid Lines (Parallels)
      final gridColor = colors.isDark
          ? colors.primary.withValues(alpha: 0.22)
          : const Color(0xFF93C5FD).withValues(alpha: 0.45);

      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;

      final equatorColor = colors.isDark
          ? colors.secondary.withValues(alpha: 0.38)
          : const Color(0xFFFBBF24).withValues(alpha: 0.65);

      final equatorPaint = Paint()
        ..color = equatorColor
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const latAngles = [-60.0, -40.0, -20.0, 0.0, 20.0, 40.0, 60.0];
      for (final lat in latAngles) {
        final yOffset = -math.sin(lat * math.pi / 180) * globeRadius;
        final rSlice = math.cos(lat * math.pi / 180) * globeRadius;
        final rect = Rect.fromCenter(
          center: Offset(center.dx, center.dy + yOffset),
          width: rSlice * 2,
          height: rSlice * 0.38,
        );
        canvas.drawOval(rect, lat == 0.0 ? equatorPaint : gridPaint);
      }
      canvas.restore(); // Globe clip.
    }

    if (layer == _GlobeLayer.surface) {
      canvas.save();
      canvas.clipPath(Path()..addOval(globeRect));

      // 3c. Longitude Meridians (Rotating seamlessly with Earth)
      final meridianBaseColor = colors.isDark
          ? colors.primary
          : const Color(0xFF93C5FD);

      const meridianCount = 12;
      for (var i = 0; i < meridianCount; i++) {
        final angle = earthRotation + (i * math.pi / (meridianCount / 2));
        final cosA = math.cos(angle);
        final isFacingFront = cosA > 0;

        final meridianPaint = Paint()
          ..color = meridianBaseColor.withValues(
            alpha: isFacingFront ? (0.10 + 0.18 * cosA) : 0.05,
          )
          ..strokeWidth = isFacingFront ? 1.0 : 0.6
          ..style = PaintingStyle.stroke;

        final rect = Rect.fromCenter(
          center: center,
          width: globeRadius * 2 * cosA.abs(),
          height: globeRadius * 2,
        );
        canvas.drawOval(rect, meridianPaint);
      }

      // 3d. 3D Rotating Continents (Orthographic Mathematical Projection)
      _drawContinents(canvas, center, globeRadius, earthRotation);
      canvas.restore();
    }

    if (layer == _GlobeLayer.foreground) {
      canvas.save();
      canvas.clipPath(Path()..addOval(globeRect));
      // 3e. Atmospheric Rim Light & Specular 3D Lighting Overlay
      final specularColor = colors.isDark
          ? colors.primary
          : const Color(0xFF60A5FA);

      final specularPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.55),
          radius: 0.75,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            specularColor.withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(globeRect);
      canvas.drawRect(globeRect, specularPaint);

      // Dark Terminator Shadow on Night Side (Bottom-Right) - Deep Space Shadow
      const shadowColor = Color(0xFF020617);
      final shadowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.65, 0.65),
          radius: 0.85,
          colors: [
            shadowColor.withValues(alpha: 0.72),
            shadowColor.withValues(alpha: 0.35),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(globeRect);
      canvas.drawRect(globeRect, shadowPaint);

      canvas.restore(); // End Globe Clip

      // ── 4. Front Atmospheric Crescent Rim (Gives Crisp Optical Depth) ────────
      final crescentColor = colors.isDark
          ? colors.primary
          : const Color(0xFF0EA5E9);

      canvas.drawArc(
        globeRect,
        math.pi * 0.95,
        math.pi * 0.85,
        false,
        Paint()
          ..color = crescentColor.withValues(alpha: 0.75)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
      );

      // ── 5. Front Half of Tilted Orbital Telemetry Track ─────────────────────
      _drawOrbitTrack(
        canvas: canvas,
        center: center,
        radiusX: orbitRadiusX,
        radiusY: orbitRadiusY,
        tilt: orbitTilt,
        isFrontHalf: true,
      );
    }

    if (layer == _GlobeLayer.telemetry) {
      _drawStarfield(canvas, center, phase);
      // ── 6. Luminous Orbiting GPS Telemetry Beacon / Satellite Pulse ─────────
      _drawOrbitBeacon(
        canvas: canvas,
        center: center,
        radiusX: orbitRadiusX,
        radiusY: orbitRadiusY,
        tilt: orbitTilt,
        progress: phase,
      );
    }
    canvas.restore();
  }

  /// Draw realistic rotating continental landmasses with Kinetic styling
  void _drawContinents(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
  ) {
    const continents = <List<List<double>>>[
      // North America
      [
        [70, -165],
        [72, -120],
        [70, -75],
        [58, -55],
        [45, -60],
        [30, -80],
        [25, -80],
        [18, -96],
        [12, -85],
        [16, -93],
        [28, -112],
        [38, -123],
        [50, -126],
        [60, -140],
        [65, -168],
      ],
      // South America
      [
        [12, -75],
        [8, -52],
        [-5, -35],
        [-22, -40],
        [-40, -62],
        [-54, -68],
        [-52, -75],
        [-35, -73],
        [-18, -71],
        [-4, -80],
        [8, -78],
      ],
      // Eurasia (Europe + Asia)
      [
        [70, 25],
        [75, 60],
        [75, 110],
        [70, 168],
        [60, 160],
        [45, 140],
        [35, 120],
        [22, 115],
        [10, 105],
        [15, 100],
        [22, 88],
        [10, 78],
        [25, 65],
        [25, 55],
        [15, 45],
        [30, 32],
        [36, 28],
        [38, -8],
        [55, -5],
        [60, 5],
        [70, 25],
      ],
      // Africa
      [
        [35, -5],
        [37, 10],
        [32, 32],
        [12, 44],
        [12, 51],
        [0, 42],
        [-15, 40],
        [-28, 32],
        [-34, 18],
        [-34, 26],
        [-18, 12],
        [5, 9],
        [5, -5],
        [15, -17],
        [25, -15],
        [35, -5],
      ],
      // Australia
      [
        [-12, 130],
        [-12, 136],
        [-18, 146],
        [-28, 153],
        [-38, 148],
        [-38, 140],
        [-35, 115],
        [-22, 114],
        [-15, 124],
      ],
      // Greenland
      [
        [80, -40],
        [70, -20],
        [60, -45],
        [70, -55],
        [80, -40],
      ],
      // Southeast Asia Islands & Japan archipelago
      [
        [45, 142],
        [36, 140],
        [33, 130],
        [38, 138],
      ],
      [
        [5, 115],
        [0, 102],
        [-8, 115],
        [-2, 120],
        [5, 115],
      ],
    ];

    for (final continent in continents) {
      final path = Path();
      var isFirst = true;
      var hasVisiblePoint = false;

      for (final pt in continent) {
        final lat = pt[0] * math.pi / 180;
        final lon = (pt[1] * math.pi / 180) + rotation;

        // 3D Spherical Orthographic Projection
        final cosLat = math.cos(lat);
        final sinLat = math.sin(lat);
        final cosLon = math.cos(lon);
        final sinLon = math.sin(lon);

        final z = cosLat * cosLon; // Facing camera when z > 0

        final x = center.dx + (radius * cosLat * sinLon);
        final y = center.dy - (radius * sinLat);

        if (z > -0.15) {
          hasVisiblePoint = true;
          if (isFirst) {
            path.moveTo(x, y);
            isFirst = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }

      if (hasVisiblePoint && !isFirst) {
        path.close();

        // 1. Glowing Landmass Base Fill (Emerald Mint)
        final landFillColor = colors.isDark
            ? const Color(0xFF10B981)
            : const Color(0xFF059669);
        final landFillPaint = Paint()
          ..color = landFillColor.withValues(alpha: colors.isDark ? 0.35 : 0.44)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, landFillPaint);

        // 2. High-Tech Kinetic Primary Coastline Contour
        final coastColor = colors.isDark
            ? colors.primary
            : const Color(0xFF38BDF8);
        final coastPaint = Paint()
          ..color = coastColor.withValues(alpha: 0.95)
          ..strokeWidth = 1.25
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, coastPaint);
      }
    }
  }

  /// Draws 3D tilted orbital route
  void _drawOrbitTrack({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tilt,
    required bool isFrontHalf,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    final trackPaint = Paint()
      ..color = colors.primary.withValues(alpha: isFrontHalf ? 0.40 : 0.14)
      ..strokeWidth = isFrontHalf ? 1.4 : 0.8
      ..style = PaintingStyle.stroke;

    final outerGuidePaint = Paint()
      ..color = colors.primary.withValues(alpha: isFrontHalf ? 0.18 : 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final orbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 2,
      height: radiusY * 2,
    );

    final outerOrbitRect = Rect.fromCenter(
      center: Offset.zero,
      width: (radiusX + 9) * 2,
      height: (radiusY + 5) * 2,
    );

    final startAngle = isFrontHalf ? 0.0 : math.pi;
    final sweepAngle = isFrontHalf ? math.pi : math.pi;

    canvas.drawArc(
      outerOrbitRect,
      startAngle,
      sweepAngle,
      false,
      outerGuidePaint,
    );

    // Dashed GPS Orbital Route
    const segments = 24;
    final segAngle = math.pi / segments;
    for (var i = 0; i < segments; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          orbitRect,
          startAngle + (i * segAngle),
          segAngle * 0.75,
          false,
          trackPaint,
        );
      }
    }

    canvas.restore();
  }

  /// Draws high-precision GPS satellite beacon orbiting smoothly around the globe
  void _drawOrbitBeacon({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tilt,
    required double progress,
  }) {
    final orbitAngle = progress * 2 * math.pi;
    final localX = radiusX * math.cos(orbitAngle);
    final localY = radiusY * math.sin(orbitAngle);

    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);

    final beaconX = center.dx + (localX * cosT - localY * sinT);
    final beaconY = center.dy + (localX * sinT + localY * cosT);
    final beaconPos = Offset(beaconX, beaconY);

    final isFront = localY >= -radiusY * 0.4;
    final opacity = isFront ? 1.0 : 0.35;

    // 1. Glowing Trail Arc behind Beacon
    const trailCount = 14;
    for (var i = 1; i <= trailCount; i++) {
      final trailProgress = orbitAngle - (i * 0.035);
      final tX = radiusX * math.cos(trailProgress);
      final tY = radiusY * math.sin(trailProgress);
      final ptX = center.dx + (tX * cosT - tY * sinT);
      final ptY = center.dy + (tX * sinT + tY * cosT);

      final trailAlpha = (1.0 - (i / trailCount)) * 0.70 * opacity;
      final trailRadius = (3.2 - (i * 0.18)).clamp(0.8, 3.2);

      canvas.drawCircle(
        Offset(ptX, ptY),
        trailRadius,
        Paint()
          ..color = colors.primary.withValues(alpha: trailAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // 2. Telemetry Beacon Radar Pulse Rings
    final pulseScale = (progress * 4) % 1.0;
    final pulseRadius = 5.0 + (pulseScale * 14.0);
    final pulseAlpha = (1.0 - pulseScale) * 0.75 * opacity;

    canvas.drawCircle(
      beaconPos,
      pulseRadius,
      Paint()
        ..color = colors.secondary.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 3. Glowing Satellite Beacon Head
    // Outer Neon Halo
    canvas.drawCircle(
      beaconPos,
      8.0,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.40 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Core Cyan Bead
    canvas.drawCircle(
      beaconPos,
      4.2,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.95 * opacity)
        ..style = PaintingStyle.fill,
    );

    // Crisp Pure White Center Point
    canvas.drawCircle(
      beaconPos,
      2.0,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill,
    );
  }

  /// Ambient background starfield & data twinkles
  void _drawStarfield(Canvas canvas, Offset center, double progress) {
    const stars = [
      [-110.0, -100.0, 1.4, 0.4],
      [120.0, -90.0, 1.2, 0.5],
      [-125.0, 80.0, 1.6, 0.3],
      [115.0, 95.0, 1.3, 0.45],
      [-80.0, -125.0, 1.1, 0.35],
      [90.0, -120.0, 1.5, 0.55],
      [-130.0, -20.0, 1.0, 0.25],
      [135.0, 30.0, 1.4, 0.4],
      [0.0, -135.0, 1.2, 0.5],
      [-50.0, 130.0, 1.3, 0.3],
      [60.0, 125.0, 1.5, 0.45],
    ];

    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final twinkle = math.sin((progress * math.pi * 4) + i);
      final alpha = (s[3] + (twinkle * 0.2)).clamp(0.1, 0.85);

      canvas.drawCircle(
        Offset(center.dx + s[0], center.dy + s[1]),
        s[2],
        Paint()
          ..color = colors.primary.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGlobePainter oldDelegate) =>
      oldDelegate.layer != layer ||
      oldDelegate.progress != progress ||
      oldDelegate.userRotation != userRotation ||
      oldDelegate.colors != colors;
}
