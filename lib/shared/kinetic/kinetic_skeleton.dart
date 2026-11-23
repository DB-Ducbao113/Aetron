import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';

/// Kinetic Skeleton — unified skeleton loading placeholders.
///
/// Features:
/// - Theme-aware shimmer animation
/// - Consistent border radius from KineticTokens
/// - Reusable building blocks for all screens
/// - 7 pre-built screen skeleton views
class KineticSkeleton {
  const KineticSkeleton._();

  /// Shimmer duration — matches KineticTokens.animSlowest
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  // ── Building Blocks ──────────────────────────────────────────────────────

  /// A shimmering box placeholder for text lines, avatars, etc.
  static Widget box({
    double? width,
    double? height,
    double borderRadius = KineticTokens.radiusSM,
    EdgeInsetsGeometry? margin,
  }) {
    return _ShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }

  /// A shimmering card placeholder for card-like content areas.
  static Widget card({
    double? width,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(KineticTokens.spaceMD),
    double borderRadius = KineticTokens.radiusMD,
    EdgeInsetsGeometry? margin,
  }) {
    return _ShimmerCard(
      width: width,
      height: height,
      padding: padding,
      borderRadius: borderRadius,
      margin: margin,
    );
  }

  /// A shimmering circle placeholder for avatars, icons, etc.
  static Widget circle({double size = 48, EdgeInsetsGeometry? margin}) {
    return _ShimmerCircle(size: size, margin: margin);
  }

  // ── Screen Skeletons ─────────────────────────────────────────────────────

  /// Home screen skeleton
  static Widget home() => const _HomeSkeleton();

  /// Analytics screen skeleton
  static Widget analytics() => const _AnalyticsSkeleton();

  /// Calendar/History screen skeleton
  static Widget calendar() => const _CalendarSkeleton();

  /// Profile screen skeleton
  static Widget profile() => const _ProfileSkeleton();

  /// Activity screen skeleton
  static Widget activity() => const _ActivitySkeleton();

  /// Workout details screen skeleton
  static Widget workoutDetails() => const _WorkoutDetailsSkeleton();

  /// Settings screen skeleton
  static Widget settings() => const _SettingsSkeleton();
}

// ── Shimmer Painter ──────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color highlightColor;

  _ShimmerPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    canvas.drawRect(Offset.zero & size, paint);

    final shimmerWidth = size.width * 0.4;
    final dx = (size.width + shimmerWidth) * progress - shimmerWidth;

    final gradient = LinearGradient(
      colors: [Colors.transparent, highlightColor, Colors.transparent],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final rect = Rect.fromLTWH(dx, 0, shimmerWidth, size.height);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── Shimmer Widgets ──────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const _ShimmerBox({
    this.width,
    this.height,
    this.borderRadius = KineticTokens.radiusSM,
    this.margin,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KineticSkeleton.shimmerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? colors.surface2 : colors.surface3;
    final highlightColor = isDark
        ? colors.primary.withValues(alpha: 0.08)
        : colors.primary.withValues(alpha: 0.06);

    Widget box = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShimmerPainter(
            progress: _controller.value,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
          size: Size(widget.width ?? double.infinity, widget.height ?? 16),
        );
      },
    );

    if (widget.borderRadius > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: box,
      );
    }

    if (widget.margin != null) {
      box = Padding(padding: widget.margin!, child: box);
    }

    return box;
  }
}

class _ShimmerCard extends StatefulWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const _ShimmerCard({
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(KineticTokens.spaceMD),
    this.borderRadius = KineticTokens.radiusMD,
    this.margin,
  });

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KineticSkeleton.shimmerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? colors.surface1 : colors.surface2;
    final highlightColor = isDark
        ? colors.primary.withValues(alpha: 0.06)
        : colors.primary.withValues(alpha: 0.04);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: colors.borderSubtle, width: 1),
          ),
          child: CustomPaint(
            painter: _ShimmerPainter(
              progress: _controller.value,
              baseColor: Colors.transparent,
              highlightColor: highlightColor,
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCircle extends StatefulWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const _ShimmerCircle({this.size = 48, this.margin});

  @override
  State<_ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<_ShimmerCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KineticSkeleton.shimmerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? colors.surface2 : colors.surface3;
    final highlightColor = isDark
        ? colors.primary.withValues(alpha: 0.08)
        : colors.primary.withValues(alpha: 0.06);

    Widget circle = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor,
            border: Border.all(color: colors.borderSubtle, width: 1),
          ),
          child: CustomPaint(
            painter: _ShimmerPainter(
              progress: _controller.value,
              baseColor: Colors.transparent,
              highlightColor: highlightColor,
            ),
          ),
        );
      },
    );

    if (widget.margin != null) {
      circle = Padding(padding: widget.margin!, child: circle);
    }

    return circle;
  }
}

// ── Screen Skeleton Views ────────────────────────────────────────────────────

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              KineticSkeleton.circle(size: 48),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KineticSkeleton.box(height: 14, width: 120),
                    const SizedBox(height: KineticTokens.spaceXS),
                    KineticSkeleton.box(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceLG),
          // Hero card
          KineticSkeleton.card(
            height: 180,
            borderRadius: KineticTokens.radiusLG,
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Section title
          KineticSkeleton.box(height: 12, width: 100),
          const SizedBox(height: KineticTokens.spaceSM),
          // Activity cards
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 120)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 120)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Week bento
          KineticSkeleton.card(height: 140),
          const SizedBox(height: KineticTokens.spaceMD),
          // Recent activity
          KineticSkeleton.card(height: 100),
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KineticSkeleton.box(height: 20, width: 160),
          const SizedBox(height: KineticTokens.spaceLG),
          // Period selector
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < 3 ? KineticTokens.spaceXS : 0,
                  ),
                  child: KineticSkeleton.box(
                    height: 36,
                    borderRadius: KineticTokens.radiusSM,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KineticTokens.spaceLG),
          // Hero metric
          KineticSkeleton.card(
            height: 160,
            borderRadius: KineticTokens.radiusLG,
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Telemetry grid
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 100)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 100)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 100)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 100)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Activity mix
          KineticSkeleton.card(height: 180),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KineticSkeleton.box(height: 20, width: 140),
          const SizedBox(height: KineticTokens.spaceLG),
          // Calendar grid
          KineticSkeleton.card(height: 280),
          const SizedBox(height: KineticTokens.spaceMD),
          // Range tabs
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < 2 ? KineticTokens.spaceXS : 0,
                  ),
                  child: KineticSkeleton.box(
                    height: 36,
                    borderRadius: KineticTokens.radiusSM,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Daily list
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: KineticTokens.spaceSM),
              child: KineticSkeleton.card(height: 80),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(
            children: [
              KineticSkeleton.circle(size: 72),
              const SizedBox(width: KineticTokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KineticSkeleton.box(height: 18, width: 140),
                    const SizedBox(height: KineticTokens.spaceXS),
                    KineticSkeleton.box(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceLG),
          // Stats row
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 80)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 80)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 80)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Settings sections
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: KineticTokens.spaceSM),
              child: KineticSkeleton.card(height: 60),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KineticSkeleton.box(height: 20, width: 120),
          const SizedBox(height: KineticTokens.spaceLG),
          // Activity cards
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: KineticTokens.spaceSM),
              child: KineticSkeleton.card(height: 140),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutDetailsSkeleton extends StatelessWidget {
  const _WorkoutDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KineticSkeleton.box(height: 20, width: 160),
          const SizedBox(height: KineticTokens.spaceLG),
          // Hero distance
          KineticSkeleton.card(
            height: 140,
            borderRadius: KineticTokens.radiusLG,
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Telemetry grid
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 100)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 100)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),
          Row(
            children: [
              Expanded(child: KineticSkeleton.card(height: 100)),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(child: KineticSkeleton.card(height: 100)),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),
          // Splits
          KineticSkeleton.card(height: 120),
          const SizedBox(height: KineticTokens.spaceMD),
          // Route
          KineticSkeleton.card(height: 160),
        ],
      ),
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KineticSkeleton.box(height: 20, width: 140),
          const SizedBox(height: KineticTokens.spaceLG),
          // Settings sections
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: KineticTokens.spaceSM),
              child: KineticSkeleton.card(height: 80),
            ),
          ),
        ],
      ),
    );
  }
}
