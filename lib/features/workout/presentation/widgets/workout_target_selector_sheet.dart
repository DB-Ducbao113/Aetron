import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 3D Bento Target Selector Sheet for setting workout goals before launching.
class WorkoutTargetSelectorSheet extends StatefulWidget {
  final WorkoutTarget initialTarget;
  final AppLanguage currentLang;
  final Color accentColor;

  const WorkoutTargetSelectorSheet({
    super.key,
    required this.initialTarget,
    required this.currentLang,
    required this.accentColor,
  });

  static Future<WorkoutTarget?> show(
    BuildContext context, {
    required WorkoutTarget initialTarget,
    required AppLanguage currentLang,
    required Color accentColor,
  }) {
    return showModalBottomSheet<WorkoutTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WorkoutTargetSelectorSheet(
        initialTarget: initialTarget,
        currentLang: currentLang,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<WorkoutTargetSelectorSheet> createState() =>
      _WorkoutTargetSelectorSheetState();
}

class _WorkoutTargetSelectorSheetState
    extends State<WorkoutTargetSelectorSheet> {
  late WorkoutTargetType _selectedType;
  late double _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialTarget.type;
    _selectedValue = widget.initialTarget.value;
    if (_selectedValue <= 0) {
      if (_selectedType == WorkoutTargetType.distance) _selectedValue = 5.0;
      if (_selectedType == WorkoutTargetType.duration) _selectedValue = 30.0;
      if (_selectedType == WorkoutTargetType.calories) _selectedValue = 300.0;
    }
  }

  void _selectPreset(WorkoutTargetType type, double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = type;
      _selectedValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;
    final accent = widget.accentColor;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
          border: Border.all(
            color: colors.borderSubtle,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Indicator Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.18),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.track_changes_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'THIẾT LẬP MỤC TIÊU' : 'SET WORKOUT TARGET',
                          style: KineticTypography.pageEyebrow.copyWith(
                            color: accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          isVi ? 'Chọn mục tiêu buổi tập' : 'Select Session Goal',
                          style: KineticTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      color: colors.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode Selector Segment Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildTab(
                    type: WorkoutTargetType.none,
                    label: isVi ? 'Tự do' : 'Free',
                    icon: Icons.all_inclusive_rounded,
                    accent: accent,
                    colors: colors,
                  ),
                  _buildTab(
                    type: WorkoutTargetType.distance,
                    label: isVi ? 'Cự ly' : 'Distance',
                    icon: Icons.place_rounded,
                    accent: accent,
                    colors: colors,
                  ),
                  _buildTab(
                    type: WorkoutTargetType.duration,
                    label: isVi ? 'Thời gian' : 'Time',
                    icon: Icons.timer_rounded,
                    accent: accent,
                    colors: colors,
                  ),
                  _buildTab(
                    type: WorkoutTargetType.calories,
                    label: isVi ? 'Calo' : 'Calories',
                    icon: Icons.local_fire_department_rounded,
                    accent: accent,
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content Area based on Selected Mode
            if (_selectedType == WorkoutTargetType.none)
              _buildFreeRunView(isVi, accent, colors)
            else if (_selectedType == WorkoutTargetType.distance)
              _buildDistancePresets(isVi, accent, colors)
            else if (_selectedType == WorkoutTargetType.duration)
              _buildDurationPresets(isVi, accent, colors)
            else
              _buildCaloriePresets(isVi, accent, colors),

            const SizedBox(height: 24),

            // Apply Target Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(
                    WorkoutTarget(
                      type: _selectedType,
                      value: _selectedType == WorkoutTargetType.none
                          ? 0.0
                          : _selectedValue,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  ),
                ),
                child: Text(
                  isVi ? 'XÁC NHẬN MỤC TIÊU' : 'CONFIRM TARGET',
                  style: KineticTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required WorkoutTargetType type,
    required String label,
    required IconData icon,
    required Color accent,
    required KineticColors colors,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = type;
            if (type == WorkoutTargetType.distance && _selectedValue <= 0) {
              _selectedValue = 5.0;
            } else if (type == WorkoutTargetType.duration &&
                _selectedValue <= 0) {
              _selectedValue = 30.0;
            } else if (type == WorkoutTargetType.calories &&
                _selectedValue <= 0) {
              _selectedValue = 300.0;
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            border: Border.all(
              color: isSelected ? accent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? accent : colors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeRunView(bool isVi, Color accent, KineticColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.all_inclusive_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Chạy Tự Do (Free Workout)' : 'Free Workout',
                  style: KineticTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVi
                      ? 'Luyện tập thoải mái không giới hạn cự ly hay thời lượng.'
                      : 'Run or walk freely without constraints or timers.',
                  style: KineticTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistancePresets(bool isVi, Color accent, KineticColors colors) {
    const presets = [1.0, 3.0, 5.0, 10.0, 15.0, 21.1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((km) {
            final isSel = _selectedValue == km;
            final label = km == 21.1 ? '21.1 km (Half)' : '${km.toInt()} km';
            return _buildChip(
              label: label,
              isSelected: isSel,
              accent: accent,
              colors: colors,
              onTap: () => _selectPreset(WorkoutTargetType.distance, km),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationPresets(bool isVi, Color accent, KineticColors colors) {
    const presets = [15.0, 30.0, 45.0, 60.0, 90.0, 120.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((mins) {
            final isSel = _selectedValue == mins;
            final label = isVi ? '${mins.toInt()} phút' : '${mins.toInt()} min';
            return _buildChip(
              label: label,
              isSelected: isSel,
              accent: accent,
              colors: colors,
              onTap: () => _selectPreset(WorkoutTargetType.duration, mins),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCaloriePresets(bool isVi, Color accent, KineticColors colors) {
    const presets = [150.0, 300.0, 500.0, 750.0, 1000.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((kcal) {
            final isSel = _selectedValue == kcal;
            return _buildChip(
              label: '${kcal.toInt()} kcal',
              isSelected: isSel,
              accent: accent,
              colors: colors,
              onTap: () => _selectPreset(WorkoutTargetType.calories, kcal),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required Color accent,
    required KineticColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.22) : colors.background,
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          border: Border.all(
            color: isSelected ? accent : colors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: KineticTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? accent : colors.textPrimary,
            fontFeatures: KineticTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}
