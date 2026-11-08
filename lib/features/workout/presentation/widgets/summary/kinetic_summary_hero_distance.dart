import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticSummaryHeroDistance extends StatefulWidget {
  final double distanceKm;
  final String activityType;
  final bool useMetricUnits;
  final WorkoutValidityFlag validityFlag;
  final AppLanguage currentLang;

  const KineticSummaryHeroDistance({
    super.key,
    required this.distanceKm,
    required this.activityType,
    required this.useMetricUnits,
    this.validityFlag = WorkoutValidityFlag.verified,
    required this.currentLang,
  });

  @override
  State<KineticSummaryHeroDistance> createState() =>
      _KineticSummaryHeroDistanceState();
}

class _KineticSummaryHeroDistanceState
    extends State<KineticSummaryHeroDistance>
    with TickerProviderStateMixin {
  late final AnimationController _countController;
  late final AnimationController _entranceController;
  late final Animation<double> _count;
  late final Animation<double> _entranceScale;
  bool _motionStarted = false;

  double get _displayDistance =>
      widget.useMetricUnits ? widget.distanceKm : widget.distanceKm * 0.621371;

  @override
  void initState() {
    super.initState();
    // Controllers are created once here — never in build().
    _countController = AnimationController(
      vsync: this,
      duration: KineticTokens.motionCounter,
    );
    _count = CurvedAnimation(
      parent: _countController,
      curve: KineticTokens.motionCounterCurve,
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: KineticTokens.motionSuccess,
    );
    _entranceScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: KineticTokens.motionSuccessCurve,
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
      _countController.value = 1.0;
      _entranceController.value = 1.0;
    } else {
      _countController.forward();
      _entranceController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant KineticSummaryHeroDistance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distanceKm != widget.distanceKm ||
        oldWidget.useMetricUnits != widget.useMetricUnits) {
      _countController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final distanceUnit = widget.useMetricUnits ? 'KM' : 'MI';

    final Color validityColor;
    final String validityText;
    switch (widget.validityFlag) {
      case WorkoutValidityFlag.verified:
        validityColor = colors.primary;
        validityText = widget.currentLang == AppLanguage.vi
            ? 'GPS ĐÃ XÁC MINH'
            : 'GPS VERIFIED';
        break;
      case WorkoutValidityFlag.partial:
        validityColor = colors.secondary;
        validityText = widget.currentLang == AppLanguage.vi
            ? 'GPS HIỆU CHỈNH'
            : 'GPS CALIBRATED';
        break;
      case WorkoutValidityFlag.unverified:
        validityColor = colors.tertiary;
        validityText = widget.currentLang == AppLanguage.vi
            ? 'CẢM BIẾN NỘI SUY'
            : 'SENSOR INTERPOLATED';
        break;
    }

    return ScaleTransition(
      scale: _entranceScale,
      child: KineticCard(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.currentLang == AppLanguage.vi
                              ? 'HOÀN THÀNH XUẤT SẮC'
                              : 'SESSION COMPLETE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.primary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: validityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  ),
                  child: Text(
                    validityText,
                    style: KineticTypography.unitLabel.copyWith(
                      color: validityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Big Metric Value — count-up (450ms easeOutCubic)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedBuilder(
                  animation: _count,
                  builder: (context, child) {
                    return Text(
                      (_displayDistance * _count.value).toStringAsFixed(2),
                      style: KineticTypography.metricMega.copyWith(
                        color: colors.textPrimary,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  distanceUnit,
                  style: KineticTypography.metricUnit.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
