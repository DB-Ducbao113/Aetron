import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PersonalRecordsTrophyWall extends StatelessWidget {
  final DetailedPersonalRecords records;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const PersonalRecordsTrophyWall({
    super.key,
    required this.records,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final all = records.allRecords;
    final unlockedCount = records.unlockedCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.tertiary.withValues(alpha: 0.18),
                      border: Border.all(color: colors.tertiary.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: colors.tertiary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: KineticTokens.spaceXS),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentLang == AppLanguage.vi ? 'ĐỀN THỜ KỶ LỤC' : 'PR HALL OF FAME',
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.tertiary.withValues(alpha: 0.9),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        currentLang == AppLanguage.vi ? 'Kỷ Lục Cá Nhân (PRs)' : 'Personal Bests',
                        style: KineticTypography.headlineSmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Unlocked Counter Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceXS, vertical: KineticTokens.spaceXXS),
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                  border: Border.all(color: colors.tertiary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$unlockedCount / ${all.length} ${currentLang == AppLanguage.vi ? 'KỶ LỤC' : 'RECORDS'}',
                  style: KineticTypography.unitLabel.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.tertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // 2-Column Bento Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: KineticTokens.spaceXS,
              mainAxisSpacing: KineticTokens.spaceXS,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final record = all[index];
              return _TrophyCardItem(
                record: record,
                useMetricUnits: useMetricUnits,
                currentLang: currentLang,
                onTap: () => _showRecordDetailSheet(context, record),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRecordDetailSheet(BuildContext context, SingleRecordItem record) {
    HapticFeedback.lightImpact();
    final colors = context.kinetic;
    final isUnlocked = record.isUnlocked;
    final isVi = currentLang == AppLanguage.vi;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            KineticTokens.spaceSM,
            0,
            KineticTokens.spaceSM,
            KineticTokens.spaceSM,
          ),
          padding: const EdgeInsets.all(KineticTokens.spaceXL),
          decoration: BoxDecoration(
            color: colors.surface1.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(KineticTokens.radiusXXL),
            border: Border.all(
              color: isUnlocked ? colors.tertiary : colors.borderSubtle,
              width: 1,
            ),
            boxShadow: KineticTokens.shadowPanel(colors.background),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusXS),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              // Emblem
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? colors.tertiary.withValues(alpha: 0.2)
                      : colors.surface2,
                  border: Border.all(
                    color: isUnlocked ? colors.tertiary : colors.borderSubtle,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                  size: 32,
                  color: isUnlocked ? colors.tertiary : colors.textSecondary,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceSM),

              Text(
                isVi ? record.titleVi : record.titleEn,
                style: KineticTypography.cardTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                isUnlocked
                    ? (isVi ? 'KỶ LỤC CÁ NHÂN ĐÃ XÁC LẬP' : 'PERSONAL BEST ESTABLISHED')
                    : (isVi ? 'CHƯA MỞ KHÓA' : 'NOT YET UNLOCKED'),
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? colors.tertiary : colors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceMD),

              // Detail box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KineticTokens.spaceMD),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  children: [
                    if (isUnlocked) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isVi ? 'THÀNH TÍCH ĐỈNH CAO' : 'PEAK RECORD',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatRecordValue(record, useMetricUnits),
                            style: KineticTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      if (record.achievedAt != null) ...[
                        const SizedBox(height: KineticTokens.spaceXS),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi ? 'NGÀY XÁC LẬP' : 'DATE ACHIEVED',
                              style: KineticTypography.unitLabel.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              '${record.achievedAt!.toLocal().day.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().month.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().year}',
                              style: KineticTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      Text(
                        isVi ? record.unlockHintVi : record.unlockHintEn,
                        textAlign: TextAlign.center,
                        style: KineticTypography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              KineticButton(
                label: isVi ? 'ĐÓNG' : 'CLOSE',
                icon: Icons.check_circle_outline_rounded,
                variant: KineticButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatRecordValue(SingleRecordItem record, bool useMetricUnits) {
    if (record.durationSec != null) {
      return WorkoutFormatters.formatDurationFromSeconds(record.durationSec!);
    }
    if (record.id == 'pr_longest_dist' && record.numericValue != null) {
      return WorkoutFormatters.formatDistance(record.numericValue!, useMetric: useMetricUnits, decimals: 1);
    }
    if (record.id == 'pr_fastest_pace' && record.numericValue != null) {
      return WorkoutFormatters.formatPaceFromSpeedKmh(record.numericValue!, useMetric: useMetricUnits);
    }
    if (record.id == 'pr_max_cal' && record.numericValue != null) {
      return '${record.numericValue!.round()} kcal';
    }
    return '—';
  }
}

class _TrophyCardItem extends StatelessWidget {
  final SingleRecordItem record;
  final bool useMetricUnits;
  final AppLanguage currentLang;
  final VoidCallback onTap;

  const _TrophyCardItem({
    required this.record,
    required this.useMetricUnits,
    required this.currentLang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isUnlocked = record.isUnlocked;
    final isVi = currentLang == AppLanguage.vi;
    final title = isVi ? record.titleVi : record.titleEn;

    final accentColor = switch (record.category) {
      'speed' => colors.primary,
      'distance' => colors.tertiary,
      'energy' => colors.secondary,
      _ => colors.textMuted,
    };

    final icon = switch (record.id) {
      'pr_1k' => Icons.electric_bolt_rounded,
      'pr_5k' => Icons.directions_run_rounded,
      'pr_10k' => Icons.military_tech_rounded,
      'pr_21k' => Icons.emoji_events_rounded,
      'pr_longest_dist' => Icons.explore_rounded,
      'pr_fastest_pace' => Icons.speed_rounded,
      'pr_max_cal' => Icons.local_fire_department_rounded,
      _ => Icons.timer_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(KineticTokens.spaceSM),
          decoration: BoxDecoration(
            color: isUnlocked ? colors.surface1 : colors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
            border: Border.all(
              color: isUnlocked ? accentColor.withValues(alpha: 0.45) : colors.borderSubtle,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon & Category Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    isUnlocked ? icon : Icons.lock_outline_rounded,
                    size: 18,
                    color: isUnlocked ? accentColor : colors.textMuted,
                  ),
                  if (isUnlocked && record.achievedAt != null)
                    Text(
                      '${record.achievedAt!.toLocal().day.toString().padLeft(2, '0')}/${record.achievedAt!.toLocal().month.toString().padLeft(2, '0')}',
                      style: KineticTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),

              // Middle: Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KineticTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isUnlocked ? colors.textPrimary : colors.textSecondary,
                ),
              ),

              // Bottom: Value or Locked hint
              Text(
                isUnlocked
                    ? PersonalRecordsTrophyWall._formatRecordValue(record, useMetricUnits)
                    : (isVi ? 'Chưa mở khóa' : 'Locked'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isUnlocked
                    ? KineticTypography.label.copyWith(
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      )
                    : KineticTypography.caption.copyWith(
                        color: colors.textMuted,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
