import 'dart:math' as math;
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
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
    if (existing != null) {
      _selectedType = existing.goalType;
      _selectedPeriod = existing.period;
      _targetValue = existing.goalType == GoalType.distance && !useMetricUnits
          ? WorkoutFormatters.kmToMi(existing.targetValue)
          : existing.targetValue;
    } else {
      _targetValue = _defaultTargetFor(_selectedType, _selectedPeriod, useMetricUnits);
    }
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
        return useMetricUnits ? km : WorkoutFormatters.kmToMi(km).roundToDouble();
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
        return useMetricUnits ? km : WorkoutFormatters.kmToMi(km).roundToDouble();
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
        return useMetricUnits ? km : WorkoutFormatters.kmToMi(km).roundToDouble();
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

  // ── Intensity & Benchmark Calculation ──────────────────────────────────────

  ({String titleVi, String titleEn, String descVi, String descEn, Color color, IconData icon})
      _getIntensityInfo(KineticColors colors) {
    final minVal = _minTargetFor(_selectedType, _selectedPeriod);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod);
    final ratio = ((_targetValue - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    if (ratio < 0.28) {
      return (
        titleVi: 'Khởi động nhẹ nhàng',
        titleEn: 'Base & Recovery',
        descVi: 'Mục tiêu duy trì thể lực nền tảng, phù hợp để phục hồi và bắt đầu.',
        descEn: 'Focus on active recovery, light aerobic conditioning and habit forming.',
        color: const Color(0xFF4EBE9E),
        icon: Icons.spa_rounded,
      );
    } else if (ratio < 0.60) {
      return (
        titleVi: 'Vừa sức & Đều đặn',
        titleEn: 'Steady Progression',
        descVi: 'Tần suất tối ưu cho sức khỏe tim mạch và nâng cao độ bền vững chắc.',
        descEn: 'Optimal cadence for cardiovascular health and sustainable fitness gains.',
        color: const Color(0xFF39B5F2),
        icon: Icons.trending_up_rounded,
      );
    } else if (ratio < 0.85) {
      return (
        titleVi: 'Thử thách bứt phá',
        titleEn: 'Challenger Tier',
        descVi: 'Đốt mỡ tăng tốc, đòi hỏi ý chí kiên định và lộ trình dinh dưỡng tốt.',
        descEn: 'Accelerated metabolic burn and aerobic capacity enhancement.',
        color: const Color(0xFFA55EEA),
        icon: Icons.bolt_rounded,
      );
    } else {
      return (
        titleVi: 'Chiến binh vô cực',
        titleEn: 'Elite Beast Mode',
        descVi: 'Cường độ khắc nghiệt của vận động viên bán chuyên và chuyên nghiệp.',
        descEn: 'High-volume endurance demands elite discipline and dedication.',
        color: const Color(0xFFFF5252),
        icon: Icons.whatshot_rounded,
      );
    }
  }

  ({String landmarkVi, String landmarkEn, String calorieImpactVi, String calorieImpactEn, String scheduleVi, String scheduleEn})
      _getRealWorldBenchmark(bool useMetricUnits) {
    final isWeekly = _selectedPeriod == GoalPeriod.weekly;

    switch (_selectedType) {
      case GoalType.distance:
        final kmEquiv = useMetricUnits ? _targetValue : _targetValue / 0.621371;
        final unitStr = useMetricUnits ? 'km' : 'mi';

        String landmarkVi;
        String landmarkEn;
        if (kmEquiv <= 15) {
          landmarkVi = 'Tương đương ~3 vòng chạy bờ hồ Hoàn Kiếm';
          landmarkEn = 'Equivalent to ~3 scenic lake loops';
        } else if (kmEquiv <= 35) {
          landmarkVi = 'Chinh phục trọn vẹn 1 vòng hồ Tây (17km) + các buổi chạy ngắn';
          landmarkEn = 'Equivalent to a full West Lake perimeter tour + recovery runs';
        } else if (kmEquiv <= 60) {
          landmarkVi = 'Vượt xa cự ly một trận Full Marathon tiêu chuẩn (42.195 km)';
          landmarkEn = 'Surpasses the iconic Full Marathon distance (42.2 km)';
        } else if (kmEquiv <= 150) {
          landmarkVi = 'Tương đương chạy bộ từ Hà Nội tới Phủ Lý (Hà Nam)';
          landmarkEn = 'Equivalent to an epic cross-provincial endurance trek';
        } else {
          landmarkVi = 'Cự ly Ultra Marathon cự phách dành cho chiến binh thép';
          landmarkEn = 'Ultra Marathon endurance scale reserved for relentless runners';
        }

        final kcal = (kmEquiv * 68).round();
        final fatKg = (kcal / 7700).toStringAsFixed(2);
        final sessions = isWeekly ? 4 : 16;
        final perSession = (_targetValue / sessions).toStringAsFixed(1);

        return (
          landmarkVi: landmarkVi,
          landmarkEn: landmarkEn,
          calorieImpactVi: 'Giải phóng ~$kcal kcal (tương đương ~$fatKg kg mỡ thuần khiết)',
          calorieImpactEn: 'Burn ~$kcal kcal (equiv. ~$fatKg kg metabolic fat loss)',
          scheduleVi: 'Chia đều ~$sessions buổi/chu kỳ (khoảng $perSession $unitStr mỗi buổi)',
          scheduleEn: 'Split across ~$sessions sessions (~$perSession $unitStr each)',
        );

      case GoalType.workouts:
        final sessions = _targetValue.toInt();
        final daysBetween = isWeekly
            ? (7 / math.max(1, sessions)).toStringAsFixed(1)
            : (30 / math.max(1, sessions)).toStringAsFixed(1);

        String landmarkVi;
        String landmarkEn;
        if (sessions <= 3) {
          landmarkVi = 'Khởi đầu thông minh, tạo đà xây dựng phản xạ vận động';
          landmarkEn = 'Smart adaptive cadence for consistent recovery & habits';
        } else if (sessions <= 5) {
          landmarkVi = 'Tần suất vàng theo tiêu chuẩn của Tổ chức Y tế Thế giới (WHO)';
          landmarkEn = 'Gold standard activity frequency recommended by WHO';
        } else if (sessions <= 7) {
          landmarkVi = 'Kỷ luật thép — Duy trì ngọn lửa vận động đều đặn mỗi ngày';
          landmarkEn = 'Ironclad discipline — Daily athletic activation without break';
        } else {
          landmarkVi = 'Cường độ kép — Hai buổi rèn luyện mỗi ngày của vận động viên';
          landmarkEn = 'Double-session athlete regimen pushing physical boundaries';
        }

        final estKcal = sessions * 360;

        return (
          landmarkVi: landmarkVi,
          landmarkEn: landmarkEn,
          calorieImpactVi: 'Ước tính tiêu hao ~$estKcal kcal qua các buổi tập',
          calorieImpactEn: 'Estimated ~$estKcal active calories across workouts',
          scheduleVi: 'Trung bình cứ mỗi $daysBetween ngày hoàn thành 1 buổi tập',
          scheduleEn: '1 workout completed every $daysBetween days',
        );

      case GoalType.calories:
        final kcal = _targetValue.toInt();
        final fatKg = (kcal / 7700).toStringAsFixed(2);
        final phoBowls = (kcal / 500).toStringAsFixed(1);
        final days = isWeekly ? 7 : 30;
        final perDay = (kcal / days).round();

        return (
          landmarkVi: 'Giải phóng năng lượng tương đương tiêu hao $phoBowls bữa ăn tiêu chuẩn',
          landmarkEn: 'Metabolic deficit equivalent to burning $phoBowls standard meals',
          calorieImpactVi: 'Đốt cháy ~$fatKg kg mô mỡ tích lũy khỏi cơ thể',
          calorieImpactEn: 'Oxidizes ~$fatKg kg of pure stored body fat',
          scheduleVi: 'Cần đốt cháy trung bình ~$perDay kcal mỗi ngày',
          scheduleEn: 'Requires an average burn of ~$perDay kcal daily',
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
    final normalizedTarget = _selectedType == GoalType.distance && !useMetricUnits
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
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
          side: BorderSide(color: colors.borderAccent, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.error.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.delete_outline_rounded, color: colors.error, size: 20),
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
          style: KineticTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: KineticTypography.label.copyWith(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isVi ? 'Xóa mục tiêu' : 'Delete Goal',
              style: KineticTypography.label.copyWith(fontWeight: FontWeight.w700),
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
            message: isVi ? 'Không thể xóa mục tiêu.' : 'Could not delete goal.',
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
    final textVal = _targetValue % 1 == 0
        ? _targetValue.toInt().toString()
        : _targetValue.toStringAsFixed(1);
    final controller = TextEditingController(text: textVal)
      ..selection = TextSelection(baseOffset: 0, extentOffset: textVal.length);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(KineticTokens.spaceMD),
          padding: const EdgeInsets.all(KineticTokens.spaceXL),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
            border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_note_rounded, size: 16, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVi ? 'NHẬP CHÍNH XÁC MỤC TIÊU' : 'ENTER EXACT TARGET',
                    style: KineticTypography.unitLabel.copyWith(
                      color: accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KineticTokens.spaceSM),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: KineticTypography.displayLarge.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surface1,
                  suffixText: _unitLabel(
                    _selectedType,
                    useMetricUnits: _useMetricUnits,
                    isVi: isVi,
                  ).toUpperCase(),
                  suffixStyle: KineticTypography.label.copyWith(
                    color: accent,
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
                    borderSide: BorderSide(color: accent, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),
              KineticButton(
                label: isVi ? 'ÁP DỤNG MỤC TIÊU' : 'APPLY TARGET',
                icon: Icons.check_circle_rounded,
                variant: KineticButtonVariant.primary,
                height: KineticTokens.buttonHeightPrimary,
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim());
                  if (parsed != null && parsed > 0) {
                    _updateTarget(parsed);
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build Widget ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final hasGoal = ref.watch(userGoalProvider).valueOrNull != null;
    final useMetricUnits = ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final unit = _unitLabel(_selectedType, useMetricUnits: useMetricUnits, isVi: isVi);
    final minVal = _minTargetFor(_selectedType, _selectedPeriod, useMetricUnits);
    final maxVal = _maxTargetFor(_selectedType, _selectedPeriod, useMetricUnits);
    final step = _stepSizeFor(_selectedType);
    final accent = _accentColorFor(_selectedType, colors);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Sleek Motivational Top Bar
            _buildTopBar(context, currentLang, hasGoal),

            // 2. Main Scrollable Playground
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KineticTokens.page,
                  KineticTokens.spaceXS,
                  KineticTokens.page,
                  120,
                ),
                children: [
                  // 2.1 Athletic Discipline Selector (Distance / Sessions / Calories)
                  _buildDisciplineSelector(colors, currentLang),
                  const SizedBox(height: KineticTokens.spaceSM),

                  // 2.2 Cadence Selector (Weekly Sprint vs Monthly Campaign)
                  _buildCadenceSelector(colors, currentLang),
                  const SizedBox(height: KineticTokens.spaceLG),

                  // 2.3 HERO: Kinetic Target Energy Reactor Dial
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
                  const SizedBox(height: KineticTokens.spaceLG),

                  // 2.4 Real-World Impact & Benchmark Projection
                  _buildRealWorldImpactCard(colors, currentLang, useMetricUnits, accent),
                  const SizedBox(height: KineticTokens.spaceLG),

                  // 2.5 Athletic Goal Presets (Starter, Pro, Elite, Beast)
                  _buildAthleticPresets(colors, currentLang, useMetricUnits, accent),
                  const SizedBox(height: KineticTokens.spaceLG),

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

  Widget _buildTopBar(BuildContext context, AppLanguage currentLang, bool hasGoal) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        KineticTokens.spaceSM,
        KineticTokens.page,
        KineticTokens.spaceXS,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              child: Container(
                padding: const EdgeInsets.all(KineticTokens.spaceXS),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: KineticTokens.spaceSM),
          Expanded(
            child: Text(
              isVi ? 'Mục tiêu rèn luyện' : 'Fitness Goals',
              style: KineticTypography.pageTitle.copyWith(
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasGoal)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmDeleteGoal(currentLang),
                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                child: Container(
                  padding: const EdgeInsets.all(KineticTokens.spaceXS),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                    border: Border.all(color: colors.error.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 2.1 Athletic Discipline Selector ────────────────────────────────────────

  Widget _buildDisciplineSelector(KineticColors colors, AppLanguage currentLang) {
    final isVi = currentLang == AppLanguage.vi;

    final items = [
      (
        GoalType.distance,
        Icons.directions_run_rounded,
        isVi ? 'Cự ly' : 'Distance',
        _unitLabel(GoalType.distance, useMetricUnits: _useMetricUnits, isVi: isVi).toUpperCase(),
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

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: KineticTokens.spaceXS),
          Expanded(
            child: _buildDisciplineCard(
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
    );
  }

  Widget _buildDisciplineCard({
    required KineticColors colors,
    required GoalType type,
    required IconData icon,
    required String title,
    required String badge,
    required Color accent,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = type;
            _targetValue = _defaultTargetFor(type, _selectedPeriod);
          });
        },
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        child: AnimatedContainer(
          duration: KineticTokens.motionTab,
          padding: const EdgeInsets.symmetric(
            vertical: KineticTokens.spaceSM,
            horizontal: KineticTokens.spaceXS,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.14) : colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
            border: Border.all(
              color: isSelected ? accent : colors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(KineticTokens.spaceXS),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accent : colors.surface2,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? colors.onPrimary : colors.textSecondary,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXS),
              Text(
                title,
                style: KineticTypography.label.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                badge,
                style: KineticTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? accent : colors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2.2 Cadence Selector ───────────────────────────────────────────────────

  Widget _buildCadenceSelector(KineticColors colors, AppLanguage currentLang) {
    final isVi = currentLang == AppLanguage.vi;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceXXS),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCadenceTab(
              colors: colors,
              title: isVi ? 'Sprint Tuần Này' : 'Weekly Sprint',
              subtitle: isVi ? 'Chu kỳ 7 ngày' : '7-Day Rolling',
              icon: Icons.flash_on_rounded,
              isSelected: _selectedPeriod == GoalPeriod.weekly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPeriod = GoalPeriod.weekly;
                  _targetValue = _defaultTargetFor(_selectedType, GoalPeriod.weekly);
                });
              },
            ),
          ),
          Expanded(
            child: _buildCadenceTab(
              colors: colors,
              title: isVi ? 'Chiến Dịch Tháng' : 'Monthly Campaign',
              subtitle: isVi ? 'Mục tiêu 30 ngày' : '30-Day Milestone',
              icon: Icons.flag_rounded,
              isSelected: _selectedPeriod == GoalPeriod.monthly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedPeriod = GoalPeriod.monthly;
                  _targetValue = _defaultTargetFor(_selectedType, GoalPeriod.monthly);
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        child: AnimatedContainer(
          duration: KineticTokens.motionTab,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            border: isSelected
                ? Border.all(color: colors.borderAccent, width: 1.2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? colors.primary : colors.textMuted,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: KineticTypography.bodySmall.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: KineticTypography.caption.copyWith(
                      color: isSelected ? colors.primary : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2.3 HERO: Kinetic Target Energy Reactor Dial ───────────────────────────

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
    final displayValue = _selectedType == GoalType.calories
        ? _targetValue.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )
        : (_targetValue % 1 == 0
            ? _targetValue.toInt().toString()
            : _targetValue.toStringAsFixed(1));

    final intensity = _getIntensityInfo(colors);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.spaceLG,
        KineticTokens.spaceLG,
        KineticTokens.spaceLG,
        KineticTokens.spaceLG,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // 1. Top Bar: Period Label & Quick Direct Input Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Text(
                    _selectedPeriod == GoalPeriod.weekly
                        ? (isVi ? 'MỤC TIÊU TUẦN' : 'WEEKLY TARGET')
                        : (isVi ? 'MỤC TIÊU THÁNG' : 'MONTHLY TARGET'),
                    style: KineticTypography.unitLabel.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showDirectValueEditor(context, currentLang);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 16, color: accent),
                        const SizedBox(width: 4),
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
            ],
          ),
          const SizedBox(height: KineticTokens.spaceLG),

          // 2. Interactive Ergonomic Steppers with Hero Metric Center
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

              // Hero Metric Display (Tap to Edit)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showDirectValueEditor(context, currentLang);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                displayValue,
                                style: KineticTypography.metricHero.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                unit.toUpperCase(),
                                style: KineticTypography.metricUnit.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isVi ? 'Chạm để gõ số' : 'Tap to edit',
                            style: KineticTypography.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
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
          const SizedBox(height: KineticTokens.spaceMD),

          // 3. Clean & Subtle Athletic Intensity Tag
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KineticTokens.spaceSM,
              vertical: KineticTokens.spaceXS,
            ),
            decoration: BoxDecoration(
              color: intensity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              border: Border.all(color: intensity.color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(intensity.icon, size: 14, color: intensity.color),
                const SizedBox(width: 8),
                Text(
                  isVi ? intensity.titleVi : intensity.titleEn,
                  style: KineticTypography.unitLabel.copyWith(
                    fontWeight: FontWeight.w700,
                    color: intensity.color,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        child: AnimatedContainer(
          duration: KineticTokens.motionPress,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? colors.surface2 : colors.surface2.withValues(alpha: 0.3),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.35) : colors.borderSubtle.withValues(alpha: 0.2),
              width: 1.4,
            ),
          ),
          child: Icon(
            icon,
            size: 26,
            color: enabled ? accent : colors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ── 2.4 Real-World Impact & Benchmark Projection ───────────────────────────

  Widget _buildRealWorldImpactCard(
    KineticColors colors,
    AppLanguage currentLang,
    bool useMetricUnits,
    Color accent,
  ) {
    final isVi = currentLang == AppLanguage.vi;
    final benchmark = _getRealWorldBenchmark(useMetricUnits);

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
        border: Border.all(color: colors.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                isVi ? 'Ý NGHĨA & HIỆU QUẢ THỰC TẾ' : 'REAL-WORLD PERFORMANCE IMPACT',
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),

          _buildImpactItem(
            colors: colors,
            icon: Icons.place_rounded,
            title: isVi ? 'Cột mốc tương đương:' : 'Equivalent landmark:',
            description: isVi ? benchmark.landmarkVi : benchmark.landmarkEn,
            accent: accent,
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          _buildImpactItem(
            colors: colors,
            icon: Icons.local_fire_department_rounded,
            title: isVi ? 'Chuyển hóa năng lượng:' : 'Metabolic energy burn:',
            description: isVi ? benchmark.calorieImpactVi : benchmark.calorieImpactEn,
            accent: accent,
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          _buildImpactItem(
            colors: colors,
            icon: Icons.calendar_month_rounded,
            title: isVi ? 'Phân rã lộ trình thực hiện:' : 'Recommended execution pace:',
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
    required String title,
    required String description,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(KineticTokens.spaceXXS),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: KineticTokens.spaceXS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KineticTypography.caption.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: KineticTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
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
                : WorkoutFormatters.kmToMi(isWeekly ? 20.0 : 80.0).roundToDouble(),
            Icons.spa_rounded,
            const Color(0xFF4EBE9E),
            isVi ? 'Làm quen' : 'Base',
          ),
          (
            'Tiến Bộ',
            'Pro',
            useMetricUnits
                ? (isWeekly ? 45.0 : 180.0)
                : WorkoutFormatters.kmToMi(isWeekly ? 45.0 : 180.0).roundToDouble(),
            Icons.trending_up_rounded,
            const Color(0xFF39B5F2),
            isVi ? 'Đều đặn' : 'Steady',
          ),
          (
            'Bứt Phá',
            'Elite',
            useMetricUnits
                ? (isWeekly ? 80.0 : 320.0)
                : WorkoutFormatters.kmToMi(isWeekly ? 80.0 : 320.0).roundToDouble(),
            Icons.bolt_rounded,
            const Color(0xFFA55EEA),
            isVi ? 'Nâng cao' : 'Challenge',
          ),
          (
            'Vô Cực',
            'Beast',
            useMetricUnits
                ? (isWeekly ? 120.0 : 480.0)
                : WorkoutFormatters.kmToMi(isWeekly ? 120.0 : 480.0).roundToDouble(),
            Icons.whatshot_rounded,
            const Color(0xFFFF5252),
            isVi ? 'Đỉnh cao' : 'Ultra',
          ),
        ],
      GoalType.workouts => [
          ('Khởi Đầu', 'Starter', isWeekly ? 3.0 : 12.0, Icons.spa_rounded, const Color(0xFF4EBE9E), isVi ? 'Làm quen' : 'Base'),
          ('Tiến Bộ', 'Pro', isWeekly ? 5.0 : 20.0, Icons.trending_up_rounded, const Color(0xFF39B5F2), isVi ? 'Đều đặn' : 'Steady'),
          ('Bứt Phá', 'Elite', isWeekly ? 7.0 : 28.0, Icons.bolt_rounded, const Color(0xFFA55EEA), isVi ? 'Nâng cao' : 'Challenge'),
          ('Vô Cực', 'Beast', isWeekly ? 10.0 : 38.0, Icons.whatshot_rounded, const Color(0xFFFF5252), isVi ? 'Đỉnh cao' : 'Ultra'),
        ],
      GoalType.calories => [
          ('Khởi Đầu', 'Starter', isWeekly ? 2000.0 : 8000.0, Icons.spa_rounded, const Color(0xFF4EBE9E), isVi ? 'Làm quen' : 'Base'),
          ('Tiến Bộ', 'Pro', isWeekly ? 4500.0 : 18000.0, Icons.trending_up_rounded, const Color(0xFF39B5F2), isVi ? 'Đều đặn' : 'Steady'),
          ('Bứt Phá', 'Elite', isWeekly ? 8000.0 : 32000.0, Icons.bolt_rounded, const Color(0xFFA55EEA), isVi ? 'Nâng cao' : 'Challenge'),
          ('Vô Cực', 'Beast', isWeekly ? 12000.0 : 48000.0, Icons.whatshot_rounded, const Color(0xFFFF5252), isVi ? 'Đỉnh cao' : 'Ultra'),
        ],
    };

    final unitLabel = _unitLabel(_selectedType, useMetricUnits: useMetricUnits, isVi: isVi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'GÓI MỤC TIÊU ĐỀ XUẤT' : 'RECOMMENDED GOAL PRESETS',
          style: KineticTypography.unitLabel.copyWith(
            color: colors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: KineticTokens.spaceXS),
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
    final displayVal = targetVal % 1 == 0
        ? targetVal.toInt().toString()
        : targetVal.toStringAsFixed(0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        child: AnimatedContainer(
          duration: KineticTokens.motionTab,
          padding: const EdgeInsets.symmetric(
            vertical: KineticTokens.spaceXS,
            horizontal: KineticTokens.spaceXXS,
          ),
          decoration: BoxDecoration(
            color: isSelected ? presetColor.withValues(alpha: 0.16) : colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            border: Border.all(
              color: isSelected ? presetColor : colors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: presetColor),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: presetColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$displayVal $unitLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? colors.textPrimary : colors.textMuted,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tag,
                style: KineticTypography.caption.copyWith(
                  color: isSelected ? presetColor : colors.textMuted,
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
          badgeName = isVi ? '🥇 Huyền Thoại Vi Dã (Ultra 80K)' : '🥇 Century Ultra 80K';
          badgeDesc = isVi ? 'Mở khóa huy hiệu cự ly đỉnh cao của Aetron.' : 'Unlocks top-tier endurance trophy.';
          badgeIcon = Icons.military_tech_rounded;
        } else if (_targetValue >= 42) {
          badgeName = isVi ? '🥈 Bán Kỷ Lục Marathon' : '🥈 Marathon Vanguard';
          badgeDesc = isVi ? 'Đạt chuẩn cự ly thi đấu quốc tế.' : 'Meets international road race milestone.';
          badgeIcon = Icons.workspace_premium_rounded;
        } else {
          badgeName = isVi ? '🥉 Ngọn Lửa Khởi Sắc' : '🥉 Pacesetter 15K';
          badgeDesc = isVi ? 'Xác lập nền tảng thể lực vững bền.' : 'Solidifies foundational endurance.';
          badgeIcon = Icons.emoji_events_rounded;
        }
        break;

      case GoalType.workouts:
        if (_targetValue >= 6) {
          badgeName = isVi ? '🥇 Kỷ Luật Sắt Đá' : '🥇 Relentless Orbit';
          badgeDesc = isVi ? 'Bảo vệ và thăng hoa chuỗi ngày rèn luyện Streak.' : 'Shields and extends your daily streak.';
          badgeIcon = Icons.local_fire_department_rounded;
        } else {
          badgeName = isVi ? '🥈 Nhịp Thể Lực Vàng' : '🥈 Cadence Keeper';
          badgeDesc = isVi ? 'Duy trì tần suất vận động cân đối theo tuần.' : 'Consistent workout frequency unlocked.';
          badgeIcon = Icons.fitness_center_rounded;
        }
        break;

      case GoalType.calories:
        badgeName = isVi ? '🔥 Lò Phản Ứng Calo' : '🔥 Metabolic Fusion';
        badgeDesc = isVi ? 'Tăng tốc giải phóng calo và chuyển hóa trao đổi chất.' : 'Maximizes active metabolic caloric output.';
        badgeIcon = Icons.whatshot_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceMD,
        vertical: KineticTokens.spaceSM,
      ),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(KineticTokens.spaceXS),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            ),
            child: Icon(badgeIcon, size: 20, color: accent),
          ),
          const SizedBox(width: KineticTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeName,
                  style: KineticTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  badgeDesc,
                  style: KineticTypography.caption.copyWith(
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
    final displayValue = _targetValue % 1 == 0
        ? _targetValue.toInt().toString()
        : _targetValue.toStringAsFixed(1);

    final typeLabel = switch (_selectedType) {
      GoalType.distance => isVi ? 'Cự ly' : 'Distance',
      GoalType.workouts => isVi ? 'Buổi tập' : 'Sessions',
      GoalType.calories => isVi ? 'Calo' : 'Calories',
    };

    final periodLabel = _selectedPeriod == GoalPeriod.weekly
        ? (isVi ? 'tuần' : 'wk')
        : (isVi ? 'tháng' : 'mo');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        KineticTokens.spaceSM,
        KineticTokens.page,
        KineticTokens.spaceLG,
      ),
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: colors.borderSubtle, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quick Recap
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$typeLabel • $periodLabel',
                    style: KineticTypography.caption.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayValue,
                        style: KineticTypography.metricCard.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: KineticTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                          fontFeatures: KineticTypography.tabularFigures,
                        ),
                      ),
                    ],
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
                height: KineticTokens.buttonHeightPrimary,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(GoalType type, {required bool useMetricUnits, bool isVi = true}) {
    return switch (type) {
      GoalType.distance => WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits),
      GoalType.workouts => isVi ? 'buổi' : 'sessions',
      GoalType.calories => 'kcal',
    };
  }
}
