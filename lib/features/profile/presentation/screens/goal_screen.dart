import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen>
    with SingleTickerProviderStateMixin {
  GoalType _selectedType = GoalType.distance;
  GoalPeriod _selectedPeriod = GoalPeriod.weekly;
  double _targetValue = 35.0;
  bool _isSaving = false;
  bool _lastMetricUnits = true;
  bool _hasUserEditedTarget = false;

  late final AnimationController _pulseController;

  bool get _useMetricUnits =>
      ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    final existing = ref.read(userGoalProvider).valueOrNull;
    final useMetricUnits = _useMetricUnits;
    _lastMetricUnits = useMetricUnits;
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      _targetValue = existing.goalType == GoalType.distance && !useMetricUnits
          ? WorkoutFormatters.kmToMi(existing.targetValue)
          : existing.targetValue;
    } else {
      _targetValue = _defaultTargetFor(
        _selectedType,
        _selectedPeriod,
        useMetricUnits,
      );
    }
  }

  void _reconcileMetricUnits(bool isMetric) {
    if (isMetric == _lastMetricUnits) return;
    setState(() {
      _lastMetricUnits = isMetric;
      if (_selectedType != GoalType.distance) return;
      if (!_hasUserEditedTarget) {
        final existing = ref.read(userGoalProvider).valueOrNull;
        if (existing != null && existing.goalType == GoalType.distance) {
          _targetValue = isMetric
              ? existing.targetValue
              : WorkoutFormatters.kmToMi(existing.targetValue);
        } else {
          _targetValue = _defaultTargetFor(
            _selectedType,
            _selectedPeriod,
            isMetric,
          );
        }
      } else {
        final converted = isMetric
            ? _targetValue / 0.621371
            : WorkoutFormatters.kmToMi(_targetValue);
        final minVal = _minTargetFor(_selectedType, _selectedPeriod, isMetric);
        final maxVal = _maxTargetFor(_selectedType, _selectedPeriod, isMetric);
        _targetValue = converted.clamp(minVal, maxVal);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Calculation Helpers ─────────────────────────────────────────────────────

  double _defaultTargetFor(GoalType type, GoalPeriod period, [bool? metric]) {
    final useMetricUnits = metric ?? _useMetricUnits;
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        final km = isWeekly ? 35.0 : 150.0;
        return useMetricUnits
            ? km
            : WorkoutFormatters.kmToMi(km).roundToDouble();
      case GoalType.workouts:
        return isWeekly ? 4.0 : 16.0;
      case GoalType.calories:
        return isWeekly ? 3500.0 : 15000.0;
    }
  }

  double _minTargetFor(GoalType type, GoalPeriod period, [bool? metric]) {
    final useMetricUnits = metric ?? _useMetricUnits;
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        final km = isWeekly ? 5.0 : 20.0;
        return useMetricUnits
            ? km
            : WorkoutFormatters.kmToMi(km).roundToDouble();
      case GoalType.workouts:
        return isWeekly ? 1.0 : 4.0;
      case GoalType.calories:
        return isWeekly ? 500.0 : 2000.0;
    }
  }

  double _maxTargetFor(GoalType type, GoalPeriod period, [bool? metric]) {
    final useMetricUnits = metric ?? _useMetricUnits;
    final isWeekly = period == GoalPeriod.weekly;
    switch (type) {
      case GoalType.distance:
        final km = isWeekly ? 150.0 : 600.0;
        return useMetricUnits
            ? km
            : WorkoutFormatters.kmToMi(km).roundToDouble();
      case GoalType.workouts:
        return isWeekly ? 14.0 : 45.0;
      case GoalType.calories:
        return isWeekly ? 15000.0 : 60000.0;
    }
  }

  double _stepSizeFor(GoalType type) {
    switch (type) {
      case GoalType.distance:
        return 2.5;
      case GoalType.workouts:
        return 1.0;
      case GoalType.calories:
        return 250.0;
    }
  }

  void _updateTarget(double value) {
    final minVal = _minTargetFor(_selectedType, _selectedPeriod);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod);
    setState(() {
      _hasUserEditedTarget = true;
      _targetValue = value.clamp(minVal, maxVal);
    });
  }

  void _adjustTarget(double delta) {
    HapticFeedback.selectionClick();
    _updateTarget(_targetValue + delta);
  }

  Color _accentColorFor(GoalType type, KineticColors colors) {
    switch (type) {
      case GoalType.distance:
        return colors.primary; // Neon Cyan
      case GoalType.workouts:
        return colors.secondary; // Amber
      case GoalType.calories:
        return colors.tertiary; // Coral / Crimson
    }
  }

  Color _readableAccentForText(Color accent, KineticColors colors) {
    if (accent == colors.tertiary && !colors.isDark) {
      return const Color(0xFFB45309);
    }
    return accent;
  }

  Color _readableAccentForIcon(Color accent, KineticColors colors) {
    if (accent == colors.tertiary && !colors.isDark) {
      return const Color(0xFFB45309);
    }
    return accent;
  }

  String _formatTargetValue(double value, GoalType type) {
    if (type == GoalType.calories) {
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  // ── Intensity & Benchmark Calculation ──────────────────────────────────────

  ({
    String titleVi,
    String titleEn,
    String descVi,
    String descEn,
    Color color,
    IconData icon,
  })
  _getIntensityInfo(KineticColors colors) {
    final minVal = _minTargetFor(_selectedType, _selectedPeriod);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod);
    final ratio = ((_targetValue - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    if (ratio < 0.28) {
      return (
        titleVi: 'Khởi động nhẹ nhàng',
        titleEn: 'Base & Recovery',
        descVi:
            'Mục tiêu duy trì thể lực nền tảng, phù hợp để phục hồi và bắt đầu.',
        descEn:
            'Focus on active recovery, light aerobic conditioning and habit forming.',
        color: const Color(0xFF4EBE9E),
        icon: Icons.spa_rounded,
      );
    } else if (ratio < 0.60) {
      return (
        titleVi: 'Vừa sức & Đều đặn',
        titleEn: 'Steady Progression',
        descVi:
            'Tần suất tối ưu cho sức khỏe tim mạch và nâng cao độ bền vững chắc.',
        descEn:
            'Optimal cadence for cardiovascular health and sustainable fitness gains.',
        color: const Color(0xFF39B5F2),
        icon: Icons.trending_up_rounded,
      );
    } else if (ratio < 0.85) {
      return (
        titleVi: 'Thử thách bứt phá',
        titleEn: 'Challenger Tier',
        descVi:
            'Đốt mỡ tăng tốc, đòi hỏi ý chí kiên định và lộ trình dinh dưỡng tốt.',
        descEn: 'Accelerated metabolic burn and aerobic capacity enhancement.',
        color: const Color(0xFFA55EEA),
        icon: Icons.bolt_rounded,
      );
    } else {
      return (
        titleVi: 'Chiến binh vô cực',
        titleEn: 'Elite Beast Mode',
        descVi:
            'Cường độ khắc nghiệt của vận động viên bán chuyên và chuyên nghiệp.',
        descEn:
            'High-volume endurance demands elite discipline and dedication.',
        color: const Color(0xFFFF5252),
        icon: Icons.whatshot_rounded,
      );
    }
  }

  ({
    String landmarkVi,
    String landmarkEn,
    String calorieImpactVi,
    String calorieImpactEn,
    String scheduleVi,
    String scheduleEn,
  })
  _getRealWorldBenchmark(bool useMetricUnits) {
    final isWeekly = _selectedPeriod == GoalPeriod.weekly;

    switch (_selectedType) {
      case GoalType.distance:
        final kmEquiv = useMetricUnits ? _targetValue : _targetValue / 0.621371;
        final unitStr = useMetricUnits ? 'km' : 'mi';

        String landmarkVi;
        String landmarkEn;
        if (kmEquiv <= 15) {
          landmarkVi = '~3 vòng bờ hồ Hoàn Kiếm';
          landmarkEn = '~3 scenic lake loops';
        } else if (kmEquiv <= 35) {
          landmarkVi = '~1 vòng hồ Tây (17 km) + chạy nhẹ';
          landmarkEn = '~1 full West Lake loop + easy runs';
        } else if (kmEquiv <= 60) {
          landmarkVi = '~Full Marathon tiêu chuẩn (42.2 km)';
          landmarkEn = '~Standard Full Marathon (42.2 km)';
        } else if (kmEquiv <= 150) {
          landmarkVi = '~Chạy liên tỉnh Hà Nội – Phủ Lý';
          landmarkEn = '~Cross-city endurance distance';
        } else {
          landmarkVi = '~Cự ly Ultra Marathon bền bỉ';
          landmarkEn = '~Ultra Marathon endurance scale';
        }

        final kcal = (kmEquiv * 68).round();
        final fatKg = (kcal / 7700).toStringAsFixed(2);
        final sessions = isWeekly ? 4 : 16;
        final perSession = (_targetValue / sessions).toStringAsFixed(1);

        return (
          landmarkVi: landmarkVi,
          landmarkEn: landmarkEn,
          calorieImpactVi: '~$kcal kcal · ~$fatKg kg mỡ',
          calorieImpactEn: '~$kcal kcal · ~$fatKg kg fat',
          scheduleVi: '~$sessions buổi · $perSession $unitStr/buổi',
          scheduleEn: '~$sessions sessions · $perSession $unitStr each',
        );

      case GoalType.workouts:
        final sessions = _targetValue.toInt();
        final daysBetween = isWeekly
            ? (7 / math.max(1, sessions)).toStringAsFixed(1)
            : (30 / math.max(1, sessions)).toStringAsFixed(1);

        String landmarkVi;
        String landmarkEn;
        if (sessions <= 3) {
          landmarkVi = 'Nhịp độ nhẹ nhàng để duy trì thói quen';
          landmarkEn = 'Light cadence to build steady habit';
        } else if (sessions <= 5) {
          landmarkVi = 'Đạt tần suất khuyến nghị của WHO';
          landmarkEn = 'Meets WHO recommended frequency';
        } else if (sessions <= 7) {
          landmarkVi = 'Vận động đều đặn mỗi ngày';
          landmarkEn = 'Daily active discipline';
        } else {
          landmarkVi = 'Cường độ kép cho vận động viên';
          landmarkEn = 'Double-session athlete cadence';
        }

        final estKcal = sessions * 360;

        return (
          landmarkVi: landmarkVi,
          landmarkEn: landmarkEn,
          calorieImpactVi: '~$estKcal kcal tiêu hao ước tính',
          calorieImpactEn: '~$estKcal estimated kcal burned',
          scheduleVi: '1 buổi mỗi $daysBetween ngày',
          scheduleEn: '1 workout every $daysBetween days',
        );

      case GoalType.calories:
        final kcal = _targetValue.toInt();
        final fatKg = (kcal / 7700).toStringAsFixed(2);
        final phoBowls = (kcal / 500).toStringAsFixed(1);
        final days = isWeekly ? 7 : 30;
        final perDay = (kcal / days).round();

        return (
          landmarkVi: 'Tương đương ~$phoBowls bữa ăn tiêu chuẩn',
          landmarkEn: 'Equivalent to ~$phoBowls standard meals',
          calorieImpactVi: '~$fatKg kg mỡ tiêu hao ước tính',
          calorieImpactEn: '~$fatKg kg stored fat burned',
          scheduleVi: 'Trung bình ~$perDay kcal/ngày',
          scheduleEn: 'Average ~$perDay kcal/day',
        );
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final useMetricUnits = _useMetricUnits;
    final currentLang = ref.read(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    if (_targetValue <= 0) {
      showAetronNotice(
        context,
        message: isVi
            ? 'Vui lòng chọn hoặc nhập giá trị mục tiêu hợp lệ lớn hơn 0.'
            : 'Please set a valid target value greater than zero.',
        tone: AetronNoticeTone.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    String userId = 'guest-user';
    try {
      userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest-user';
    } catch (_) {
      userId = 'guest-user';
    }

    final existing = ref.read(userGoalProvider).valueOrNull;
    final normalizedTarget =
        _selectedType == GoalType.distance && !useMetricUnits
        ? _targetValue / 0.621371
        : _targetValue;

    final goal = UserGoal(
      id: existing?.id ?? '',
      userId: userId,
      goalType: _selectedType,
      targetValue: normalizedTarget,
      period: _selectedPeriod,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(userGoalProvider.notifier).saveGoal(goal);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAetronNotice(
          context,
          message: isVi
              ? 'Không thể lưu mục tiêu. Vui lòng kiểm tra kết nối mạng và thử lại.'
              : 'Could not save goal. Please check your connection and try again.',
          tone: AetronNoticeTone.error,
        );
      }
    }
  }

  Future<void> _confirmDeleteGoal(AppLanguage currentLang) async {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => KineticGlassDialog(
        borderColor: colors.error.withValues(alpha: 0.4),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.error.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: colors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Hủy bỏ mục tiêu này?' : 'Remove This Goal?',
                style: KineticTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn xóa mục tiêu hiện tại? Dữ liệu tiến độ mục tiêu sẽ được đặt lại.'
              : 'Are you sure you want to delete your active goal? All progress tracking will be reset.',
          style: KineticTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: KineticTypography.label.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isVi ? 'Xóa mục tiêu' : 'Delete Goal',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(userGoalProvider.notifier).deleteGoal();
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        if (mounted) {
          showAetronNotice(
            context,
            message: isVi
                ? 'Không thể xóa mục tiêu.'
                : 'Could not delete goal.',
            tone: AetronNoticeTone.error,
          );
        }
      }
    }
  }

  void _showDirectValueEditor(BuildContext context, AppLanguage currentLang) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;
    final accent = _accentColorFor(_selectedType, colors);
    final accentText = _readableAccentForText(accent, colors);
    final accentIcon = _readableAccentForIcon(accent, colors);
    final textVal = _targetValue % 1 == 0
        ? _targetValue.toInt().toString()
        : _targetValue.toStringAsFixed(1);
    final unitSuffix = _unitLabel(
      _selectedType,
      useMetricUnits: _useMetricUnits,
      isVi: isVi,
    ).toUpperCase();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DirectValueEditorSheet(
        initialValue: textVal,
        unitSuffix: unitSuffix,
        accent: accent,
        accentText: accentText,
        accentIcon: accentIcon,
        isVi: isVi,
        onApply: _updateTarget,
      ),
    );
  }

  // ── Build Widget ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(metricUnitsPreferenceProvider, (
      previous,
      next,
    ) {
      final isMetric = next.valueOrNull;
      if (isMetric != null) {
        _reconcileMetricUnits(isMetric);
      }
    });

    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final hasGoal = ref.watch(userGoalProvider).valueOrNull != null;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final unit = _unitLabel(
      _selectedType,
      useMetricUnits: useMetricUnits,
      isVi: isVi,
    );
    final minVal = _minTargetFor(
      _selectedType,
      _selectedPeriod,
      useMetricUnits,
    );
    final maxVal = _maxTargetFor(
      _selectedType,
      _selectedPeriod,
      useMetricUnits,
    );
    final step = _stepSizeFor(_selectedType);
    final accent = _accentColorFor(_selectedType, colors);

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Column(
          children: [
            // 1. Sleek Motivational Top Bar
            _buildTopBar(context, currentLang, hasGoal),

            // 2. Main Scrollable Playground
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  KineticTokens.spaceXXS,
                  hPad,
                  24,
                ),
                children: [
                  // 2.1 Athletic Discipline Selector (Distance / Sessions / Calories)
                  _buildDisciplineSelector(colors, currentLang),
                  const SizedBox(height: 6),

                  // 2.2 Cadence Selector (Weekly vs Monthly)
                  _buildCadenceSelector(colors, currentLang),
                  const SizedBox(height: KineticTokens.spaceSM),

                  // 2.3 Compact Target Card
                  _buildEnergyReactorCard(
                    context,
                    colors,
                    currentLang,
                    accent,
                    unit,
                    minVal,
                    maxVal,
                    step,
                  ),
                  const SizedBox(height: KineticTokens.spaceSM),

                  // 2.4 Athletic Goal Presets (Starter, Pro, Elite, Beast)
                  _buildAthleticPresets(
                    colors,
                    currentLang,
                    useMetricUnits,
                    accent,
                  ),
                  const SizedBox(height: KineticTokens.spaceSM),

                  // 2.5 Real-World Impact & Benchmark Projection
                  _buildRealWorldImpactCard(
                    colors,
                    currentLang,
                    useMetricUnits,
                    accent,
                  ),
                  const SizedBox(height: KineticTokens.spaceXS),

                  // 2.6 Target Reward / Badge Unlock Spotlight
                  _buildBadgeUnlockPreview(colors, currentLang, accent),
                ],
              ),
            ),
          ],
        ),
      ),

      // 3. Fixed Sticky Bottom Action Dock
      bottomNavigationBar: _buildStickyActionDock(
        colors,
        currentLang,
        isVi,
        hasGoal,
        accent,
        unit,
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    AppLanguage currentLang,
    bool hasGoal,
  ) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        6,
        KineticTokens.page,
        4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KineticGlassIconButton(
            size: 37,
            visualSize: 37,
            label: isVi ? 'Quay lại' : 'Back',
            icon: BladeIcon(
              BladeIconName.chevL,
              size: 18,
              color: colors.textSecondary,
              strokeWidth: 1.7,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: KineticTokens.spaceSM),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isVi ? 'Mục tiêu rèn luyện' : 'Fitness Goals',
                  style: KineticTypography.pageTitleCompact.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          if (hasGoal)
            KineticGlassIconButton(
              size: 37,
              visualSize: 37,
              label: isVi ? 'Xóa mục tiêu' : 'Delete goal',
              icon: BladeIcon(
                BladeIconName.trash,
                size: 18,
                color: colors.error,
                strokeWidth: 1.7,
              ),
              onPressed: () => _confirmDeleteGoal(currentLang),
            ),
        ],
      ),
    );
  }

  // ── 2.1 Athletic Discipline Selector ────────────────────────────────────────

  Widget _buildDisciplineSelector(
    KineticColors colors,
    AppLanguage currentLang,
  ) {
    final isVi = currentLang == AppLanguage.vi;

    final items = [
      (
        GoalType.distance,
        Icons.directions_run_rounded,
        isVi ? 'Cự ly' : 'Distance',
        _unitLabel(
          GoalType.distance,
          useMetricUnits: _useMetricUnits,
          isVi: isVi,
        ).toUpperCase(),
        colors.primary,
      ),
      (
        GoalType.workouts,
        Icons.fitness_center_rounded,
        isVi ? 'Buổi tập' : 'Sessions',
        isVi ? 'BUỔI' : 'SESSIONS',
        colors.secondary,
      ),
      (
        GoalType.calories,
        Icons.local_fire_department_rounded,
        isVi ? 'Calo' : 'Calories',
        'KCAL',
        colors.tertiary,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceXXS),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: colors.isDark ? Border.all(color: colors.borderSubtle) : null,
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: KineticTokens.spaceXXS),
            Expanded(
              child: _buildDisciplineSegment(
                colors: colors,
                type: items[i].$1,
                icon: items[i].$2,
                title: items[i].$3,
                badge: items[i].$4,
                accent: items[i].$5,
                isSelected: _selectedType == items[i].$1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisciplineSegment({
    required KineticColors colors,
    required GoalType type,
    required IconData icon,
    required String title,
    required String badge,
    required Color accent,
    required bool isSelected,
  }) {
    final badgeColor = isSelected
        ? _readableAccentForText(accent, colors)
        : colors.textMuted;
    final iconColor = isSelected
        ? _readableAccentForIcon(accent, colors)
        : colors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $badge',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_selectedType == type) return;
            HapticFeedback.selectionClick();
            setState(() {
              _hasUserEditedTarget = true;
              _selectedType = type;
              _targetValue = _defaultTargetFor(type, _selectedPeriod);
            });
          },
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          child: AnimatedContainer(
            duration: KineticTokens.motionTab,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? (colors.isDark ? colors.surface3 : colors.surface1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: isSelected && colors.isDark
                  ? Border.all(
                      color: accent.withValues(alpha: 0.45),
                      width: 1.0,
                    )
                  : null,
              boxShadow: isSelected && !colors.isDark
                  ? KineticTokens.shadowCardLight()
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: KineticTypography.label.copyWith(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Text(
                    badge,
                    style: KineticTypography.caption.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2.2 Cadence Selector ───────────────────────────────────────────────────

  Widget _buildCadenceSelector(KineticColors colors, AppLanguage currentLang) {
    final isVi = currentLang == AppLanguage.vi;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: colors.isDark ? Border.all(color: colors.borderSubtle) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCadenceTab(
              colors: colors,
              title: isVi ? 'Tuần' : 'Weekly',
              subtitle: isVi ? '7 ngày' : '7 days',
              icon: Icons.flash_on_rounded,
              isSelected: _selectedPeriod == GoalPeriod.weekly,
              onTap: () {
                if (_selectedPeriod == GoalPeriod.weekly) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _hasUserEditedTarget = true;
                  _selectedPeriod = GoalPeriod.weekly;
                  _targetValue = _defaultTargetFor(
                    _selectedType,
                    GoalPeriod.weekly,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildCadenceTab(
              colors: colors,
              title: isVi ? 'Tháng' : 'Monthly',
              subtitle: isVi ? '30 ngày' : '30 days',
              icon: Icons.flag_rounded,
              isSelected: _selectedPeriod == GoalPeriod.monthly,
              onTap: () {
                if (_selectedPeriod == GoalPeriod.monthly) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _hasUserEditedTarget = true;
                  _selectedPeriod = GoalPeriod.monthly;
                  _targetValue = _defaultTargetFor(
                    _selectedType,
                    GoalPeriod.monthly,
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCadenceTab({
    required KineticColors colors,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          child: AnimatedContainer(
            duration: KineticTokens.motionTab,
            constraints: const BoxConstraints(
              minHeight: KineticTokens.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? (colors.isDark ? colors.surface3 : colors.surface1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: isSelected && colors.isDark
                  ? Border.all(color: colors.borderAccent, width: 1.0)
                  : null,
              boxShadow: isSelected && !colors.isDark
                  ? KineticTokens.shadowCardLight()
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected ? colors.primary : colors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KineticTypography.label.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KineticTypography.caption.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? colors.primary : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2.3 HERO: Kinetic Target Goal Card ─────────────────────────────────────

  Widget _buildEnergyReactorCard(
    BuildContext context,
    KineticColors colors,
    AppLanguage currentLang,
    Color accent,
    String unit,
    double minVal,
    double maxVal,
    double step,
  ) {
    final isVi = currentLang == AppLanguage.vi;
    final displayValue = _formatTargetValue(_targetValue, _selectedType);
    final accentText = _readableAccentForText(accent, colors);
    final intensity = _getIntensityInfo(colors);

    return KineticCard(
      useLiquidGlass: true,
      borderRadius: 21,
      borderColor: accent.withValues(alpha: 0.28),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          // 1. Top Bar: Period Label & Quick Direct Input Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedPeriod == GoalPeriod.weekly
                              ? (isVi ? 'MỤC TIÊU TUẦN' : 'WEEKLY TARGET')
                              : (isVi ? 'MỤC TIÊU THÁNG' : 'MONTHLY TARGET'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.unitLabel.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: accentText,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showDirectValueEditor(context, currentLang);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 15,
                              color: accentText,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isVi ? 'Nhập số' : 'Enter value',
                              style: KineticTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Compact Interactive Ergonomic Steppers with Metric Center
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Clean Decrement Button
              _buildStepButton(
                colors: colors,
                accent: accent,
                icon: Icons.remove_rounded,
                enabled: _targetValue > minVal,
                onTap: () => _adjustTarget(-step),
              ),

              // Metric Display (Tap to Edit)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showDirectValueEditor(context, currentLang);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              displayValue,
                              style: KineticTypography.displayLarge.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              unit.toUpperCase(),
                              style: KineticTypography.metricUnit.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: accentText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Clean Increment Button
              _buildStepButton(
                colors: colors,
                accent: accent,
                icon: Icons.add_rounded,
                enabled: _targetValue < maxVal,
                onTap: () => _adjustTarget(step),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // 3. Clean & Compact Athletic Intensity Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: intensity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: Border.all(
                color: intensity.color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(intensity.icon, size: 13, color: intensity.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isVi ? intensity.titleVi : intensity.titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KineticTypography.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: intensity.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required KineticColors colors,
    required Color accent,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final accentIcon = _readableAccentForIcon(accent, colors);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        child: AnimatedContainer(
          duration: KineticTokens.motionPress,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? colors.surface2
                : colors.surface2.withValues(alpha: 0.3),
            border: Border.all(
              color: enabled
                  ? accentIcon.withValues(alpha: 0.35)
                  : colors.borderSubtle.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? accentIcon
                : colors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ── 2.5 Concise Real-World Impact & Benchmark Projection ───────────────────

  Widget _buildRealWorldImpactCard(
    KineticColors colors,
    AppLanguage currentLang,
    bool useMetricUnits,
    Color accent,
  ) {
    final isVi = currentLang == AppLanguage.vi;
    final benchmark = _getRealWorldBenchmark(useMetricUnits);
    final accentText = _readableAccentForText(accent, colors);

    return KineticCard(
      useLiquidGlass: true,
      borderRadius: 21,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: accentText,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isVi
                      ? 'Ý NGHĨA & HIỆU QUẢ THỰC TẾ'
                      : 'REAL-WORLD PERFORMANCE IMPACT',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.unitLabel.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: accentText,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          _buildImpactItem(
            colors: colors,
            icon: Icons.place_rounded,
            description: isVi ? benchmark.landmarkVi : benchmark.landmarkEn,
            accent: accent,
          ),
          const SizedBox(height: 4),
          _buildImpactItem(
            colors: colors,
            icon: Icons.local_fire_department_rounded,
            description: isVi
                ? benchmark.calorieImpactVi
                : benchmark.calorieImpactEn,
            accent: accent,
          ),
          const SizedBox(height: 4),
          _buildImpactItem(
            colors: colors,
            icon: Icons.calendar_month_rounded,
            description: isVi ? benchmark.scheduleVi : benchmark.scheduleEn,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildImpactItem({
    required KineticColors colors,
    required IconData icon,
    required String description,
    required Color accent,
  }) {
    final accentIcon = _readableAccentForIcon(accent, colors);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
          ),
          child: Icon(icon, size: 12, color: accentIcon),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KineticTypography.bodySmall.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  // ── 2.5 Athletic Goal Presets ──────────────────────────────────────────────

  Widget _buildAthleticPresets(
    KineticColors colors,
    AppLanguage currentLang,
    bool useMetricUnits,
    Color accent,
  ) {
    final isVi = currentLang == AppLanguage.vi;
    final isWeekly = _selectedPeriod == GoalPeriod.weekly;

    final presets = switch (_selectedType) {
      GoalType.distance => [
        (
          'Khởi Đầu',
          'Starter',
          useMetricUnits
              ? (isWeekly ? 20.0 : 80.0)
              : WorkoutFormatters.kmToMi(
                  isWeekly ? 20.0 : 80.0,
                ).roundToDouble(),
          Icons.spa_rounded,
          const Color(0xFF4EBE9E),
          isVi ? 'Làm quen' : 'Base',
        ),
        (
          'Tiến Bộ',
          'Pro',
          useMetricUnits
              ? (isWeekly ? 45.0 : 180.0)
              : WorkoutFormatters.kmToMi(
                  isWeekly ? 45.0 : 180.0,
                ).roundToDouble(),
          Icons.trending_up_rounded,
          const Color(0xFF39B5F2),
          isVi ? 'Đều đặn' : 'Steady',
        ),
        (
          'Bứt Phá',
          'Elite',
          useMetricUnits
              ? (isWeekly ? 80.0 : 320.0)
              : WorkoutFormatters.kmToMi(
                  isWeekly ? 80.0 : 320.0,
                ).roundToDouble(),
          Icons.bolt_rounded,
          const Color(0xFFA55EEA),
          isVi ? 'Nâng cao' : 'Challenge',
        ),
        (
          'Vô Cực',
          'Beast',
          useMetricUnits
              ? (isWeekly ? 120.0 : 480.0)
              : WorkoutFormatters.kmToMi(
                  isWeekly ? 120.0 : 480.0,
                ).roundToDouble(),
          Icons.whatshot_rounded,
          const Color(0xFFFF5252),
          isVi ? 'Đỉnh cao' : 'Ultra',
        ),
      ],
      GoalType.workouts => [
        (
          'Khởi Đầu',
          'Starter',
          isWeekly ? 3.0 : 12.0,
          Icons.spa_rounded,
          const Color(0xFF4EBE9E),
          isVi ? 'Làm quen' : 'Base',
        ),
        (
          'Tiến Bộ',
          'Pro',
          isWeekly ? 5.0 : 20.0,
          Icons.trending_up_rounded,
          const Color(0xFF39B5F2),
          isVi ? 'Đều đặn' : 'Steady',
        ),
        (
          'Bứt Phá',
          'Elite',
          isWeekly ? 7.0 : 28.0,
          Icons.bolt_rounded,
          const Color(0xFFA55EEA),
          isVi ? 'Nâng cao' : 'Challenge',
        ),
        (
          'Vô Cực',
          'Beast',
          isWeekly ? 10.0 : 38.0,
          Icons.whatshot_rounded,
          const Color(0xFFFF5252),
          isVi ? 'Đỉnh cao' : 'Ultra',
        ),
      ],
      GoalType.calories => [
        (
          'Khởi Đầu',
          'Starter',
          isWeekly ? 2000.0 : 8000.0,
          Icons.spa_rounded,
          const Color(0xFF4EBE9E),
          isVi ? 'Làm quen' : 'Base',
        ),
        (
          'Tiến Bộ',
          'Pro',
          isWeekly ? 4500.0 : 18000.0,
          Icons.trending_up_rounded,
          const Color(0xFF39B5F2),
          isVi ? 'Đều đặn' : 'Steady',
        ),
        (
          'Bứt Phá',
          'Elite',
          isWeekly ? 8000.0 : 32000.0,
          Icons.bolt_rounded,
          const Color(0xFFA55EEA),
          isVi ? 'Nâng cao' : 'Challenge',
        ),
        (
          'Vô Cực',
          'Beast',
          isWeekly ? 12000.0 : 48000.0,
          Icons.whatshot_rounded,
          const Color(0xFFFF5252),
          isVi ? 'Đỉnh cao' : 'Ultra',
        ),
      ],
    };

    final unitLabel = _unitLabel(
      _selectedType,
      useMetricUnits: useMetricUnits,
      isVi: isVi,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'GÓI MỤC TIÊU ĐỀ XUẤT' : 'RECOMMENDED GOAL PRESETS',
          style: KineticTypography.unitLabel.copyWith(
            fontSize: 10.5,
            color: colors.primary,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < presets.length; i++) ...[
              if (i > 0) const SizedBox(width: KineticTokens.spaceXS),
              Expanded(
                child: _buildPresetCard(
                  colors: colors,
                  title: isVi ? presets[i].$1 : presets[i].$2,
                  tag: presets[i].$6,
                  targetVal: presets[i].$3,
                  icon: presets[i].$4,
                  presetColor: presets[i].$5,
                  unitLabel: unitLabel,
                  isSelected: (_targetValue - presets[i].$3).abs() < 0.5,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _updateTarget(presets[i].$3);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPresetCard({
    required KineticColors colors,
    required String title,
    required String tag,
    required double targetVal,
    required IconData icon,
    required Color presetColor,
    required String unitLabel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final displayVal = _formatTargetValue(targetVal, _selectedType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        child: AnimatedContainer(
          duration: KineticTokens.motionTab,
          padding: const EdgeInsets.symmetric(
            vertical: 5,
            horizontal: KineticTokens.spaceXXS,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? presetColor.withValues(alpha: 0.16)
                : colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            border: Border.all(
              color: isSelected ? presetColor : colors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: !isSelected && !colors.isDark
                ? KineticTokens.shadowCardLight()
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 13, color: presetColor),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: presetColor,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$displayVal $unitLabel',
                  maxLines: 1,
                  style: KineticTypography.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? colors.textPrimary : colors.textMuted,
                    fontFeatures: KineticTypography.tabularFigures,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.caption.copyWith(
                    fontSize: 9.5,
                    color: isSelected ? presetColor : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2.6 Target Reward / Badge Unlock Spotlight ─────────────────────────────

  Widget _buildBadgeUnlockPreview(
    KineticColors colors,
    AppLanguage currentLang,
    Color accent,
  ) {
    final isVi = currentLang == AppLanguage.vi;

    String badgeName;
    String badgeDesc;
    IconData badgeIcon;

    switch (_selectedType) {
      case GoalType.distance:
        if (_targetValue >= 80) {
          badgeName = isVi
              ? 'Huyền Thoại Vi Dã (Ultra 80K)'
              : 'Century Ultra 80K';
          badgeDesc = isVi
              ? 'Mở khóa huy hiệu cự ly đỉnh cao của Aetron.'
              : 'Unlocks top-tier endurance trophy.';
          badgeIcon = Icons.military_tech_rounded;
        } else if (_targetValue >= 42) {
          badgeName = isVi ? 'Bán Kỷ Lục Marathon' : 'Marathon Vanguard';
          badgeDesc = isVi
              ? 'Đạt chuẩn cự ly thi đấu quốc tế.'
              : 'Meets international road race milestone.';
          badgeIcon = Icons.workspace_premium_rounded;
        } else {
          badgeName = isVi ? 'Ngọn Lửa Khởi Sắc' : 'Pacesetter 15K';
          badgeDesc = isVi
              ? 'Xác lập nền tảng thể lực vững bền.'
              : 'Solidifies foundational endurance.';
          badgeIcon = Icons.emoji_events_rounded;
        }
        break;

      case GoalType.workouts:
        if (_targetValue >= 6) {
          badgeName = isVi ? 'Kỷ Luật Sắt Đá' : 'Relentless Orbit';
          badgeDesc = isVi
              ? 'Bảo vệ và thăng hoa chuỗi ngày rèn luyện Streak.'
              : 'Shields and extends your daily streak.';
          badgeIcon = Icons.local_fire_department_rounded;
        } else {
          badgeName = isVi ? 'Nhịp Thể Lực Vàng' : 'Cadence Keeper';
          badgeDesc = isVi
              ? 'Duy trì tần suất vận động cân đối theo tuần.'
              : 'Consistent workout frequency unlocked.';
          badgeIcon = Icons.fitness_center_rounded;
        }
        break;

      case GoalType.calories:
        badgeName = isVi ? 'Chiến Binh Đốt Calo' : 'Metabolic Fusion';
        badgeDesc = isVi
            ? 'Tăng tốc giải phóng calo và chuyển hóa trao đổi chất.'
            : 'Maximizes active metabolic caloric output.';
        badgeIcon = Icons.whatshot_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceSM,
        vertical: KineticTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
            ),
            child: Icon(
              badgeIcon,
              size: 17,
              color: _readableAccentForIcon(accent, colors),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.label.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  badgeDesc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.caption.copyWith(
                    fontSize: 10.5,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Fixed Sticky Bottom Action Dock ──────────────────────────────────────

  Widget _buildStickyActionDock(
    KineticColors colors,
    AppLanguage currentLang,
    bool isVi,
    bool hasGoal,
    Color accent,
    String unit,
  ) {
    final displayValue = _formatTargetValue(_targetValue, _selectedType);
    final accentText = _readableAccentForText(accent, colors);

    final typeLabel = switch (_selectedType) {
      GoalType.distance => isVi ? 'Cự ly' : 'Distance',
      GoalType.workouts => isVi ? 'Buổi tập' : 'Sessions',
      GoalType.calories => isVi ? 'Calo' : 'Calories',
    };

    final periodLabel = _selectedPeriod == GoalPeriod.weekly
        ? (isVi ? 'tuần' : 'wk')
        : (isVi ? 'tháng' : 'mo');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AetronBottomBar.horizontalPagePaddingOf(context),
            10,
            AetronBottomBar.horizontalPagePaddingOf(context),
            10,
          ),
          decoration: BoxDecoration(
            gradient: colors.isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xC81C2E45), Color(0xEC101B2B)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xE0F5F9FF), Color(0xF5EDF4FD)],
                  ),
            border: Border(
              top: BorderSide(
                color: colors.isDark
                    ? const Color(0x4DB6DCFF)
                    : Colors.white.withValues(alpha: 0.9),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
          children: [
            // Quick Recap
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 126),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$typeLabel • $periodLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KineticTypography.caption.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayValue,
                          style: KineticTypography.metricCard.copyWith(
                            fontSize: 20,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accentText,
                            fontFeatures: KineticTypography.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KineticTokens.spaceSM),

            // Main Primary CTA Button
            Expanded(
              child: KineticButton(
                label: hasGoal
                    ? (isVi ? 'LƯU MỤC TIÊU' : 'UPDATE GOAL')
                    : (isVi ? 'KÍCH HOẠT MỤC TIÊU' : 'ACTIVATE GOAL'),
                icon: Icons.bolt_rounded,
                variant: KineticButtonVariant.primary,
                height: KineticTokens.buttonHeight,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  String _unitLabel(
    GoalType type, {
    required bool useMetricUnits,
    bool isVi = true,
  }) {
    return switch (type) {
      GoalType.distance => WorkoutFormatters.distanceUnitLabel(
        useMetric: useMetricUnits,
      ),
      GoalType.workouts => isVi ? 'buổi' : 'sessions',
      GoalType.calories => 'kcal',
    };
  }
}

class _DirectValueEditorSheet extends StatefulWidget {
  final String initialValue;
  final String unitSuffix;
  final Color accent;
  final Color accentText;
  final Color accentIcon;
  final bool isVi;
  final ValueChanged<double> onApply;

  const _DirectValueEditorSheet({
    required this.initialValue,
    required this.unitSuffix,
    required this.accent,
    required this.accentText,
    required this.accentIcon,
    required this.isVi,
    required this.onApply,
  });

  @override
  State<_DirectValueEditorSheet> createState() =>
      _DirectValueEditorSheetState();
}

class _DirectValueEditorSheetState extends State<_DirectValueEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return KineticGlassBottomSheet(
      floating: true,
      borderRadius: 28,
      borderColor: widget.accent.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(KineticTokens.spaceXL),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: widget.accentText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isVi
                          ? 'NHẬP CHÍNH XÁC MỤC TIÊU'
                          : 'ENTER EXACT TARGET',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KineticTypography.unitLabel.copyWith(
                        color: widget.accentText,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KineticTokens.spaceSM),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: KineticTypography.displayLarge.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surface2,
                  suffixText: widget.unitSuffix,
                  suffixStyle: KineticTypography.label.copyWith(
                    color: widget.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    borderSide: BorderSide(
                      color: widget.accentIcon,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),
              KineticButton(
                label: widget.isVi ? 'ÁP DỤNG MỤC TIÊU' : 'APPLY TARGET',
                icon: Icons.check_circle_rounded,
                variant: KineticButtonVariant.primary,
                height: KineticTokens.buttonHeightPrimary,
                onPressed: () {
                  final parsed = double.tryParse(
                    _controller.text.trim().replaceAll(',', ''),
                  );
                  if (parsed != null && parsed > 0) {
                    widget.onApply(parsed);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
    );
  }
}
