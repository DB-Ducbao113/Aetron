import 'dart:async';

import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';

/// Staggered card entrance — fade + gentle slide-up
/// (motion spec: 280–380ms easeOutCubic, 60ms stagger).
///
/// Instant (no animation) when OS Reduce Motion is enabled.
/// Text and semantics are always in the tree, so accessibility
/// and widget tests see content immediately.
class KineticEntrance extends StatefulWidget {
  final Widget child;

  /// Zero-based position in the stagger sequence.
  final int index;

  /// Delay between successive entrances.
  final Duration stagger;

  const KineticEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 60),
  });

  @override
  State<KineticEntrance> createState() => _KineticEntranceState();
}

class _KineticEntranceState extends State<KineticEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _motionStarted = false;

  @override
  void initState() {
    super.initState();
    // Created once here — never in build().
    _controller = AnimationController(
      vsync: this,
      duration: KineticTokens.motionCardEntrance,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: KineticTokens.motionEntranceCurve,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: KineticTokens.motionEntranceCurve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion is an inherited (MediaQuery) dependency —
    // safe to read here, not in initState().
    if (_motionStarted) return;
    _motionStarted = true;
    if (KineticTokens.reduceMotionOf(context)) {
      _controller.value = 1.0;
    } else if (widget.index > 0) {
      _timer = Timer(widget.stagger * widget.index, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
