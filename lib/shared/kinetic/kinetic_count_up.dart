import 'dart:io';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

/// KineticCountUp — Smooth number counter animation (450ms easeOutCubic)
/// for endurance metrics, telemetry stats, and summary cards.
///
/// Respects OS Reduce Motion and Flutter test environments for immediate value
/// rendering while delivering silky smooth 60/120fps counting on live devices.
class KineticCountUp extends StatefulWidget {
  final num value;
  final int decimalPlaces;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final TextStyle? suffixStyle;
  final Duration duration;
  final Curve curve;
  final String Function(num current)? formatter;

  const KineticCountUp({
    super.key,
    required this.value,
    int? decimalPlaces,
    int? decimals,
    this.style,
    this.prefix,
    String? suffix,
    String? unit,
    this.suffixStyle,
    this.duration = KineticTokens.motionCounter,
    this.curve = KineticTokens.motionCounterCurve,
    this.formatter,
  })  : decimalPlaces = decimalPlaces ?? decimals ?? 0,
        suffix = suffix ?? unit;

  @override
  State<KineticCountUp> createState() => _KineticCountUpState();
}

class _KineticCountUpState extends State<KineticCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  num _fromValue = 0;
  num _toValue = 0;
  bool _motionStarted = false;

  bool get _isTestOrReduced =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      KineticTokens.reduceMotionOf(context);

  @override
  void initState() {
    super.initState();
    _toValue = widget.value;
    _fromValue = 0;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionStarted) return;
    _motionStarted = true;
    if (_isTestOrReduced) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant KineticCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (_isTestOrReduced) {
        _fromValue = widget.value;
        _toValue = widget.value;
        _controller.value = 1.0;
      } else {
        _fromValue = _currentValue;
        _toValue = widget.value;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num get _currentValue {
    if (_isTestOrReduced) return _toValue;
    return _fromValue + (_toValue - _fromValue) * _animation.value;
  }

  String _formatNumber(num val) {
    if (widget.formatter != null) {
      return widget.formatter!(val);
    }
    if (widget.decimalPlaces > 0) {
      return val.toStringAsFixed(widget.decimalPlaces);
    }
    return val.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? const TextStyle()).copyWith(
      fontFeatures: [
        ...?widget.style?.fontFeatures,
        ...KineticTypography.tabularFigures,
      ],
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _currentValue;
        final formatted = _formatNumber(val);
        final fullText = '${widget.prefix ?? ''}$formatted';

        if (widget.suffix != null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fullText, style: effectiveStyle),
              if (widget.suffix!.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  widget.suffix!,
                  style: widget.suffixStyle ??
                      effectiveStyle.copyWith(
                        fontSize: (effectiveStyle.fontSize ?? 14) * 0.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          );
        }

        return Text(fullText, style: effectiveStyle);
      },
    );
  }
}
