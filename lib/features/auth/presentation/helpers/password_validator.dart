import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class PasswordSecurityResult {
  final bool isMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const PasswordSecurityResult({
    required this.isMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  bool get isValid =>
      isMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

  int get score {
    int count = 0;
    if (isMinLength) count++;
    if (hasUppercase) count++;
    if (hasLowercase) count++;
    if (hasNumber) count++;
    if (hasSpecialChar) count++;
    return count;
  }
}

PasswordSecurityResult evaluatePasswordSecurity(String password) {
  return PasswordSecurityResult(
    isMinLength: password.length >= 8,
    hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
    hasLowercase: RegExp(r'[a-z]').hasMatch(password),
    hasNumber: RegExp(r'[0-9]').hasMatch(password),
    hasSpecialChar:
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\\/\[\]]').hasMatch(password),
  );
}

String? validatePasswordStrict(String? val, AppLanguage lang) {
  if (val == null || val.isEmpty) {
    return lang == AppLanguage.vi ? 'Vui lòng nhập mật khẩu' : 'Please enter password';
  }
  final result = evaluatePasswordSecurity(val);
  if (!result.isMinLength) {
    return lang == AppLanguage.vi
        ? 'Mật khẩu phải có ít nhất 8 ký tự'
        : 'Password must be at least 8 characters';
  }
  if (!result.hasUppercase) {
    return lang == AppLanguage.vi
        ? 'Mật khẩu phải có chữ viết hoa (A-Z)'
        : 'Password must contain an uppercase letter (A-Z)';
  }
  if (!result.hasLowercase) {
    return lang == AppLanguage.vi
        ? 'Mật khẩu phải có chữ thường (a-z)'
        : 'Password must contain a lowercase letter (a-z)';
  }
  if (!result.hasNumber) {
    return lang == AppLanguage.vi
        ? 'Mật khẩu phải có chữ số (0-9)'
        : 'Password must contain a number (0-9)';
  }
  if (!result.hasSpecialChar) {
    return lang == AppLanguage.vi
        ? 'Mật khẩu phải có ký tự đặc biệt (!@#%...)'
        : 'Password must contain a special character (!@#%...)';
  }
  return null;
}

/// 3D INTERACTIVE PASSWORD SECURITY METER WIDGET
class PasswordSecurityMeter extends StatelessWidget {
  final String password;
  final AppLanguage lang;

  const PasswordSecurityMeter({
    super.key,
    required this.password,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final colors = context.kinetic;
    final result = evaluatePasswordSecurity(password);
    final score = result.score;

    Color strengthColor;
    String strengthLabel;
    if (score <= 2) {
      strengthColor = colors.error;
      strengthLabel = lang == AppLanguage.vi ? 'YẾU' : 'WEAK';
    } else if (score <= 4) {
      strengthColor = colors.tertiary;
      strengthLabel = lang == AppLanguage.vi ? 'TRUNG BÌNH' : 'MEDIUM';
    } else {
      strengthColor = colors.secondary;
      strengthLabel = lang == AppLanguage.vi ? 'BẢO MẬT TỐI ƯU' : 'STRONG SECURITY';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strengthColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength Bar & Level Label
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: score / 5,
                    minHeight: 6,
                    color: strengthColor,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: strengthColor,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Security Rule Check Items
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _RuleChip(
                label: lang == AppLanguage.vi ? '≥ 8 ký tự' : '≥ 8 chars',
                isMet: result.isMinLength,
              ),
              _RuleChip(
                label: lang == AppLanguage.vi ? 'Chữ hoa (A-Z)' : 'Uppercase (A-Z)',
                isMet: result.hasUppercase,
              ),
              _RuleChip(
                label: lang == AppLanguage.vi ? 'Chữ thường (a-z)' : 'Lowercase (a-z)',
                isMet: result.hasLowercase,
              ),
              _RuleChip(
                label: lang == AppLanguage.vi ? 'Chữ số (0-9)' : 'Number (0-9)',
                isMet: result.hasNumber,
              ),
              _RuleChip(
                label: lang == AppLanguage.vi ? 'Ký tự đặc biệt (!@#%)' : 'Special (!@#%)',
                isMet: result.hasSpecialChar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RuleChip({
    required this.label,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final color = isMet ? colors.secondary : colors.textSecondary.withValues(alpha: 0.5);

    return AnimatedContainer(
      duration: KineticTokens.motionTab,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? colors.secondary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isMet ? 0.4 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w800 : FontWeight.w500,
              color: isMet ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
