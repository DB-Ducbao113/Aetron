import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';

class KineticBiometricsBento extends StatelessWidget {
  final UserProfile? profile;
  final bool useMetricUnits;
  final VoidCallback onEdit;
  final AppLanguage currentLang;

  const KineticBiometricsBento({
    super.key,
    required this.profile,
    required this.useMetricUnits,
    required this.onEdit,
    required this.currentLang,
  });

  String _formatWeight(double kg) {
    if (useMetricUnits) {
      return '${kg.toStringAsFixed(1)} kg';
    }
    final lb = kg * 2.20462;
    return '${lb.toStringAsFixed(1)} lb';
  }

  String _formatHeight(double heightM) {
    if (useMetricUnits) {
      return '${heightM.toStringAsFixed(2)} m';
    }
    final totalInches = (heightM * 39.3701).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  String _formatGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return currentLang == AppLanguage.vi ? 'Nam' : 'Male';
      case 'female':
        return currentLang == AppLanguage.vi ? 'Nữ' : 'Female';
      default:
        return gender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    if (profile == null) {
      return KineticCard(
        padding: const EdgeInsets.all(KineticTokens.spaceLG),
        borderRadius: KineticTokens.radiusLG,
        child: Column(
          children: [
            Icon(Icons.monitor_weight_outlined, size: 36, color: colors.primary),
            const SizedBox(height: KineticTokens.spaceXS),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Chưa thiết lập chỉ số cơ thể'
                  : 'Biometrics not set up',
              style: KineticTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: KineticTokens.spaceXXS),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Thiết lập chiều cao, cân nặng để tính toán chính xác lượng calo tiêu hao.'
                  : 'Add your height and weight for accurate calorie telemetry.',
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KineticTokens.spaceSM),
            KineticButton(
              label: currentLang == AppLanguage.vi
                  ? 'THIẾT LẬP CHỈ SỐ'
                  : 'SET UP BIOMETRICS',
              icon: Icons.add_rounded,
              isFullWidth: false,
              onPressed: onEdit,
            ),
          ],
        ),
      );
    }

    final p = profile!;
    final weightStr = _formatWeight(p.weightKg);
    final heightStr = _formatHeight(p.heightM);
    final genderStr = _formatGender(p.gender);
    final bmiVal = p.bmi;

    final String bmiLabel;
    if (bmiVal < 18.5) {
      bmiLabel = currentLang == AppLanguage.vi ? 'Hơi gầy' : 'Underweight';
    } else if (bmiVal < 24.9) {
      bmiLabel = currentLang == AppLanguage.vi ? 'Chuẩn' : 'Normal';
    } else if (bmiVal < 29.9) {
      bmiLabel = currentLang == AppLanguage.vi ? 'Hơi thừa cân' : 'Overweight';
    } else {
      bmiLabel = currentLang == AppLanguage.vi ? 'Cần cải thiện' : 'High';
    }

    return KineticCard(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      borderRadius: KineticTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    AppTranslations.get('biometric_data', currentLang),
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: currentLang == AppLanguage.vi ? 'Chỉnh sửa chỉ số' : 'Edit biometrics',
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 12, color: colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          currentLang == AppLanguage.vi ? 'Chỉnh sửa' : 'Edit',
                          style: KineticTypography.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceSM),

          // 2x2 Bento Grid
          Row(
            children: [
              // Weight
              Expanded(
                child: _BiometricTile(
                  icon: Icons.monitor_weight_outlined,
                  label: AppTranslations.get('weight', currentLang),
                  value: weightStr,
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
              // Height
              Expanded(
                child: _BiometricTile(
                  icon: Icons.straighten_rounded,
                  label: AppTranslations.get('height', currentLang),
                  value: heightStr,
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          Row(
            children: [
              // Age & Gender
              Expanded(
                child: _BiometricTile(
                  icon: Icons.cake_outlined,
                  label: AppTranslations.get('age', currentLang),
                  value: '${p.age} • $genderStr',
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),
              // BMI
              Expanded(
                child: _BiometricTile(
                  icon: Icons.speed_rounded,
                  label: 'BMI',
                  value: '${bmiVal.toStringAsFixed(1)} ($bmiLabel)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BiometricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BiometricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceSM,
        vertical: KineticTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: colors.textMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: KineticTypography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: KineticTypography.tabularFigures,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
