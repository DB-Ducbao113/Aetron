import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForcePasswordUpgradeScreen extends ConsumerStatefulWidget {
  const ForcePasswordUpgradeScreen({super.key});

  @override
  ConsumerState<ForcePasswordUpgradeScreen> createState() =>
      _ForcePasswordUpgradeScreenState();
}

class _ForcePasswordUpgradeScreenState
    extends ConsumerState<ForcePasswordUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (_) => false,
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentLang = ref.read(appLanguageProvider);
    final colors = context.kinetic;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: {'password_upgraded_v1': true},
        ),
      );

      // Sign out so user logs in with new credentials
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentLang == AppLanguage.vi
                ? 'Đã nâng cấp mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.'
                : 'Password upgraded successfully! Please log in with your new password.',
            style: KineticTypography.bodySmall.copyWith(color: colors.onPrimary),
          ),
          backgroundColor: colors.secondary,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = currentLang == AppLanguage.vi
            ? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.'
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinetic = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: kinetic.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KineticTokens.spaceXL,
            vertical: KineticTokens.spaceLG,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row Header with Logout Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _logout,
                      icon: Icon(
                        Icons.logout_rounded,
                        color: kinetic.error,
                        size: 18,
                      ),
                      label: Text(
                        currentLang == AppLanguage.vi
                            ? 'ĐĂNG XUẤT'
                            : 'LOG OUT',
                        style: KineticTypography.label.copyWith(
                          color: kinetic.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final next = currentLang == AppLanguage.vi
                            ? AppLanguage.en
                            : AppLanguage.vi;
                        ref
                            .read(appLanguageProvider.notifier)
                            .setLanguage(next);
                      },
                      icon: Text(
                        currentLang == AppLanguage.vi ? '🇻🇳' : '🇬🇧',
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: Text(
                        currentLang == AppLanguage.vi ? 'Tiếng Việt' : 'English',
                        style: KineticTypography.label.copyWith(
                          color: kinetic.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tertiary-tint medallion (board v2/v3: shield in a tint circle)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kinetic.tertiary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.security_update_warning_rounded,
                      color: kinetic.tertiary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Security Title
                Text(
                  AppTranslations.get('mandatory_password_upgrade_title', currentLang).isEmpty
                      ? (currentLang == AppLanguage.vi
                          ? 'YÊU CẦU NÂNG CẤP MẬT KHẨU'
                          : 'MANDATORY PASSWORD UPGRADE')
                      : AppTranslations.get('mandatory_password_upgrade_title', currentLang),
                  textAlign: TextAlign.center,
                  style: KineticTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: kinetic.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Security Description Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kinetic.surface1,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: kinetic.tertiary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    currentLang == AppLanguage.vi
                        ? 'Mật khẩu hiện tại của bạn chưa đủ mạnh. Để bảo vệ tài khoản theo quy chuẩn mới, bạn phải tạo mật khẩu mới (chữ hoa, chữ thường, số & ký tự đặc biệt) trước khi truy cập ứng dụng.'
                        : 'Your current password does not meet the new security standards. Please create a new strong password (uppercase, lowercase, number & special char) before proceeding.',
                    textAlign: TextAlign.center,
                    style: KineticTypography.bodySmall.copyWith(
                      color: kinetic.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  decoration: BoxDecoration(
                    color: kinetic.surface1,
                    borderRadius: BorderRadius.circular(
                      KineticTokens.radiusXXL,
                    ),
                    border: Border.all(
                      color: kinetic.borderStrong,
                      width: 1.5,
                    ),
                    boxShadow: KineticTokens.shadowPanel(Colors.black),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // New Password Input
                    _FieldLabel(
                      currentLang == AppLanguage.vi ? 'MẬT KHẨU MỚI' : 'NEW PASSWORD',
                      color: kinetic.primary,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      style: KineticTypography.bodyMedium.copyWith(
                        color: kinetic.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (val) => validatePasswordStrict(val, currentLang),
                      decoration: _inputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        kinetic: kinetic,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kinetic.primary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kinetic.surface2,
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusLG,
                        ),
                        border: Border.all(color: kinetic.borderSubtle),
                      ),
                      child: PasswordSecurityMeter(
                        password: _passwordController.text,
                        lang: currentLang,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password Input
                    _FieldLabel(
                      currentLang == AppLanguage.vi
                          ? 'XÁC NHẬN MẬT KHẨU MỚI'
                          : 'CONFIRM NEW PASSWORD',
                      color: kinetic.primary,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: KineticTypography.bodyMedium.copyWith(
                        color: kinetic.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) {
                          return AppTranslations.get('password_mismatch', currentLang);
                        }
                        return null;
                      },
                      decoration: _inputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_clock_outlined,
                        kinetic: kinetic,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: kinetic.primary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kinetic.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kinetic.error.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: KineticTypography.bodySmall.copyWith(
                            color: kinetic.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Submit Button
                    KineticButton(
                      label: currentLang == AppLanguage.vi
                          ? 'CẬP NHẬT & ĐĂNG NHẬP LẠI →'
                          : 'UPDATE & LOG IN AGAIN →',
                      icon: Icons.shield_rounded,
                      isLoading: _isLoading,
                      variant: KineticButtonVariant.primary,
                      onPressed: _isLoading ? null : _updatePassword,
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required KineticColors kinetic,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: kinetic.textMuted.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      filled: true,
      fillColor: kinetic.background,
      prefixIcon: Icon(prefixIcon, color: kinetic.primary, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kinetic.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kinetic.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kinetic.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kinetic.error, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: KineticTypography.unitLabel.copyWith(
        color: color,
        letterSpacing: 1.5,
      ),
    );
  }
}
