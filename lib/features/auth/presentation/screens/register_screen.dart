import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/widgets/auth_language_toggle.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:fitness_exercise_application/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccessSent = false;
  String? _registeredUsername;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      setState(() {
        _errorMessage = isVi
            ? 'Vui lòng đồng ý với Điều khoản & Chính sách bảo mật.'
            : 'Please accept Terms of Service & Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Supabase.instance.client.auth;

      if (auth.currentSession != null) {
        throw const AuthException(
          'Sign out of the current account before creating a new one.',
        );
      }

      final username = normalizeUsername(_usernameController.text);
      // Supabase Auth requires an email-shaped identifier. Keep that
      // implementation detail internal; the product account is username-only.
      final internalEmail = internalEmailForUsername(username);

      final response = await auth.signUp(
        email: internalEmail,
        password: _passwordController.text,
        data: {'password_upgraded_v1': true, 'username': username},
      );

      if (response.user != null && mounted) {
        // If session is already created (auto-confirm turned on in dev/supabase), route to AuthWrapper
        if (response.session != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (_) => false,
          );
        } else {
          // Attempt immediate sign-in for auto-confirm environments.
          try {
            final signInResp = await auth.signInWithPassword(
              email: internalEmail,
              password: _passwordController.text,
            );
            if (signInResp.session != null && mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (_) => false,
              );
              return;
            }
          } catch (_) {
            // Fall through to the username-only success confirmation.
          }

          // Show confirmation screen
          setState(() {
            _isSuccessSent = true;
            _registeredUsername = username;
            _isLoading = false;
          });
        }
      }
    } on AuthException catch (e) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      String msg = e.message;
      final lower = msg.toLowerCase();
      if (lower.contains('user already registered') ||
          lower.contains('already exists') ||
          lower.contains('already registered')) {
        msg = isVi
            ? 'Tên đăng nhập này đã được sử dụng.'
            : 'This username is already registered.';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
      final errStr = e.toString().toLowerCase();
      String msg;
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('connection failed') ||
          errStr.contains('network')) {
        msg = isVi
            ? 'Lỗi kết nối mạng: Không thể kết nối tới máy chủ. Vui lòng kiểm tra mạng.'
            : 'Network error: Unable to reach the server. Please check your connection.';
      } else {
        msg = isVi
            ? 'Không thể hoàn tất đăng ký. Vui lòng thử lại.'
            : 'Registration could not be completed. Please try again.';
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted && !_isSuccessSent) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final topPad = MediaQuery.of(context).padding.top;
    final colors = context.kinetic;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── Flat header (V5): back + language row, then brand row ───────
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AppBarIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const AuthLanguageToggle(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Bắt đầu ngay hôm nay' : 'Start today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                          letterSpacing: 0.05 * 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi
                            ? 'Theo dõi hành trình fitness'
                            : 'Track your fitness journey',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.015 * 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.borderSubtle),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: _isSuccessSent
                ? _buildSuccessVerification(context, isVi)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                              decoration: BoxDecoration(
                                color: colors.surface1,
                                borderRadius: BorderRadius.circular(
                                  KineticTokens.radiusXXL,
                                ),
                                border: Border.all(
                                  color: colors.borderStrong,
                                  width: 1.5,
                                ),
                                boxShadow: KineticTokens.shadowPanel(Colors.black),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                // ── Username field ──────────────────────────────────────
                                _SectionLabel(isVi ? 'TÊN ĐĂNG NHẬP' : 'USERNAME'),
                                const SizedBox(height: 6),
                                _StitchTextField(
                                  controller: _usernameController,
                                  hintText: isVi
                                      ? 'Nhập tên đăng nhập'
                                      : 'Enter username',
                                  prefixIcon: BladeIconName.user,
                                  keyboardType: TextInputType.text,
                                  validator: (value) =>
                                      validateUsername(value, isVi: isVi),
                                ),
                                const SizedBox(height: 16),

                                // ── Password field ──────────────────────────────────────
                                _SectionLabel(isVi ? 'MẬT KHẨU' : 'PASSWORD'),
                                const SizedBox(height: 6),
                                _StitchTextField(
                                  controller: _passwordController,
                                  hintText: isVi ? 'Tạo mật khẩu' : 'Create password',
                                  prefixIcon: BladeIconName.lock,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: BladeIcon(
                                      BladeIconName.eye,
                                      color: colors.primary.withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) =>
                                      validatePasswordStrict(value, currentLang),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isVi
                                      ? 'Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.'
                                      : 'At least 8 characters with uppercase, lowercase, a number, and a special character.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: colors.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ── Confirm password field ──────────────────────────────
                                _SectionLabel(
                                  isVi ? 'XÁC NHẬN MẬT KHẨU' : 'CONFIRM PASSWORD',
                                ),
                                const SizedBox(height: 6),
                                _StitchTextField(
                                  controller: _confirmPasswordController,
                                  hintText: isVi
                                      ? 'Xác nhận lại mật khẩu'
                                      : 'Confirm password',
                                  prefixIcon: BladeIconName.lock,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                    icon: BladeIcon(
                                      BladeIconName.eye,
                                      color: colors.primary.withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return isVi
                                          ? 'Mật khẩu không khớp'
                                          : 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // ── Terms & Privacy checkbox ────────────────────────────
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: colors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _acceptedTerms
                                          ? colors.primary.withValues(alpha: 0.4)
                                          : colors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: _acceptedTerms,
                                          activeColor: colors.primary,
                                          checkColor: colors.onPrimary,
                                          side: BorderSide(
                                            color: colors.borderSubtle,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          onChanged: (val) => setState(
                                            () => _acceptedTerms = val ?? false,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              isVi
                                                  ? 'Tôi đồng ý với '
                                                  : 'I agree to the ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.textMuted,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const TermsOfServiceScreen(),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                isVi ? 'Điều khoản' : 'Terms',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.primary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              isVi ? ' & ' : ' & ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.textMuted,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const PrivacyPolicyScreen(),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                isVi
                                                    ? 'Chính sách bảo mật'
                                                    : 'Privacy Policy',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Error message ───────────────────────────────────────
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  _ErrorMessage(_errorMessage!),
                                ],
                                const SizedBox(height: 20),

                                // ── Primary CTA ─────────────────────────────────────────
                                _PrimaryButton(
                                  label: isVi ? 'Tạo Tài Khoản' : 'Create Account',
                                  isLoading: _isLoading,
                                  onPressed: _register,
                                ),
                                const SizedBox(height: 24),

                                // ── Login link ──────────────────────────────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isVi
                                          ? 'Đã có tài khoản? '
                                          : 'Already have an account? ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Text(
                                        isVi ? 'Đăng nhập ngay' : 'Sign in',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessVerification(BuildContext context, bool isVi) {
    final colors = context.kinetic;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.15),
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: colors.primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isVi ? 'ĐĂNG KÝ THÀNH CÔNG' : 'REGISTRATION SUCCESSFUL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isVi
                          ? 'Tài khoản của bạn đã được tạo với tên đăng nhập:'
                          : 'Your account was created with username:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface1,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Text(
                        _registeredUsername ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVi
                          ? 'Bạn có thể đăng nhập bằng tên đăng nhập và mật khẩu vừa tạo.'
                          : 'You can sign in with the username and password you just created.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _PrimaryButton(
                      label: isVi ? 'Đăng nhập ngay' : 'Sign In Now',
                      isLoading: false,
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets (same stitch token set) ──────────────────────────────────

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Icon(icon, color: colors.textMuted, size: 20),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: colors.textMuted,
        letterSpacing: 0.03 * 10,
      ),
    );
  }
}

class _StitchTextField extends StatelessWidget {
  const _StitchTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final BladeIconName prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textMuted,
        ),
        filled: true,
        fillColor: colors.background,
        prefixIcon: BladeIcon(prefixIcon, color: colors.textMuted, size: 18),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
    );
  }
}

/// Primary action button — V4: delegates to the DS KineticButton
/// (flat pill, buttonHeightPrimary).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return KineticButton(
      label: label,
      isLoading: isLoading,
      height: KineticTokens.buttonHeightPrimary,
      onPressed: isLoading ? null : onPressed,
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: colors.error.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
