import 'dart:async';

import 'package:fitness_exercise_application/app/bootstrap.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/google_oauth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/username_auth.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/widgets/auth_language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialErrorMessage;
  const LoginScreen({super.key, this.initialErrorMessage});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
    WidgetsBinding.instance.addObserver(this);

    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            final session =
                data.session ?? Supabase.instance.client.auth.currentSession;
            if (session != null && mounted) {
              setState(() {
                _isGoogleLoading = false;
                _isLoading = false;
              });
              unawaited(
                ref
                    .read(appBootstrapServiceProvider)
                    .hydrateUser(session.user.id),
              );
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                );
              }
            }
          });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        try {
          if (Supabase.instance.client.auth.currentSession == null &&
              _isGoogleLoading) {
            setState(() {
              _isGoogleLoading = false;
            });
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authClient = Supabase.instance.client.auth;
      final username = normalizeUsername(_usernameController.text);
      final internalEmail = internalEmailForUsername(username);

      final response = await authClient.signInWithPassword(
        email: internalEmail,
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        unawaited(
          ref.read(appBootstrapServiceProvider).hydrateUser(response.user!.id),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage =
            'Could not sign in right now. Please check your credentials.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final success = await startGoogleOAuthSignIn();
      if (!success && mounted) {
        setState(() => _isGoogleLoading = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isGoogleLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Google Sign-In could not be completed. Please try again.';
          _isGoogleLoading = false;
        });
      }
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
          // ── Top App Bar on the V4 topographic backdrop ────────────────────
          Stack(
            children: [
              const Positioned.fill(child: TopographicBackdrop()),
              Container(
                padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
                child: SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    isVi ? 'Đăng nhập' : 'Sign In',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.01 * 18,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: const AuthLanguageToggle(),
                  ),
                ],
              ),
            ),
              ),
            ],
          ),
          // Divider matching stitch border-b border-[#23323a]
          Divider(height: 1, thickness: 1, color: colors.borderSubtle),

          // ── Scrollable Body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero image area (editorial athletic photo) ──────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/login_header.png',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 180,
                                  color: colors.surface2,
                                  child: Center(
                                    child: Icon(
                                      Icons.fitness_center_rounded,
                                      color: colors.primary,
                                      size: 48,
                                    ),
                                  ),
                                ),
                          ),
                          // Gradient scrim — DS scrimBottom
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: KineticGradients.scrimBottom(colors),
                              ),
                            ),
                          ),
                          // Bottom overlay text
                          Positioned(
                            bottom: 36,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVi ? 'Hành trình của bạn' : 'Your journey',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                    letterSpacing: 0.05 * 10,
                                  ),
                                ),
                                Text(
                                  isVi
                                      ? 'Sẵn sàng tiếp tục?'
                                      : 'Ready to continue?',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                    letterSpacing: -0.015 * 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
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
                                : 'Enter your username',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (value) => validateUsername(value, isVi: isVi),
                          ),
                          const SizedBox(height: 16),

                          // ── Password field ──────────────────────────────────────
                          _SectionLabel(isVi ? 'MẬT KHẨU' : 'PASSWORD'),
                          const SizedBox(height: 6),
                          _StitchTextField(
                            controller: _passwordController,
                            hintText: isVi
                                ? 'Nhập mật khẩu của bạn'
                                : 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.primary.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return isVi
                                    ? 'Vui lòng nhập mật khẩu'
                                    : 'Enter your password';
                              }
                              if (value.length < 6) {
                                return isVi
                                    ? 'Tối thiểu 6 ký tự'
                                    : 'Minimum 6 characters';
                              }
                              return null;
                            },
                          ),

                          // ── Forgot password ─────────────────────────────────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                isVi ? 'Quên mật khẩu?' : 'Forgot password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ),

                          // ── Error message ───────────────────────────────────────
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            _ErrorMessage(_errorMessage!),
                          ],
                          const SizedBox(height: 20),

                          // ── Primary CTA (stitch: bg-[#A8DCE7] text-[#09181c] pill) ─
                          _PrimaryButton(
                            label: isVi ? 'Đăng Nhập' : 'Sign In',
                            isLoading: _isLoading,
                            disabled: _isGoogleLoading,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 20),

                          // ── Divider ─────────────────────────────────────────────
                          Row(
                            children: [
                              Expanded(child: Divider(color: colors.borderSubtle)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  isVi ? 'Hoặc tiếp tục với' : 'Or continue with',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: colors.borderSubtle)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Google button ───────────────────────────────────────
                          _GoogleButton(
                            label: isVi
                                ? 'Tiếp tục với Google'
                                : 'Continue with Google',
                            isLoading: _isGoogleLoading,
                            disabled: _isLoading,
                            onPressed: _loginWithGoogle,
                          ),
                          const SizedBox(height: 28),

                          // ── Sign up link ────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isVi
                                    ? 'Chưa có tài khoản? '
                                    : "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textMuted,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  isVi ? 'Tạo tài khoản' : 'Create account',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared design components (stitch-aligned)
// ─────────────────────────────────────────────────────────────────────────────

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
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
        prefixIcon: Icon(prefixIcon, color: colors.textMuted, size: 18),
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
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return KineticButton(
      label: label,
      isLoading: isLoading,
      height: KineticTokens.buttonHeightPrimary,
      onPressed: (isLoading || disabled) ? null : onPressed,
    );
  }
}

/// Google sign-in button — dark surface, border outline-variant
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.label,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: (isLoading || disabled) ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.borderStrong, width: 1.5),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: colors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/GoogleLogo.jpg',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.g_mobiledata,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
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
