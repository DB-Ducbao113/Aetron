import 'dart:async';
import 'dart:ui';

import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/widgets/auth_language_toggle.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _kResetCallbackUrl = 'io.supabase.flutter://callback';

/// ════════════════════════════════════════════════════════════════════════════
/// 1. FORGOT PASSWORD SCREEN (CYBER ATHLETIC REDESIGN)
/// ════════════════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  String? _sentEmail;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendResetEmail() async {
    // If we're already on success state, form is no longer mounted in the widget tree.
    // Use the saved email without form validation.
    final targetEmail = _isSent
        ? (_sentEmail ?? _emailController.text.trim())
        : _emailController.text.trim();
    if (!_isSent) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    } else {
      if (targetEmail.isEmpty || !targetEmail.contains('@')) return;
    }

    final lang = ref.read(appLanguageProvider);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        targetEmail,
        redirectTo: kIsWeb ? null : _kResetCallbackUrl,
      );

      if (!mounted) return;
      setState(() {
        _sentEmail = targetEmail;
        _isSent = true;
        _isLoading = false;
      });
      _startResendCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;
      final isVi = lang == AppLanguage.vi;
      final lower = e.message.toLowerCase();
      String msg = e.message;
      if (lower.contains('rate limit') || lower.contains('too many')) {
        msg = isVi
            ? 'Bạn đã gửi yêu cầu quá nhiều lần. Vui lòng đợi trong giây lát.'
            : 'Too many requests. Please wait before trying again.';
      } else if (lower.contains('not found') || lower.contains('user not found')) {
        msg = isVi
            ? 'Không tìm thấy tài khoản với email này.'
            : 'No account found with this email.';
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = lang == AppLanguage.vi
            ? 'Không thể gửi email khôi phục. Vui lòng thử lại.'
            : 'Could not send reset email. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEmailApp() async {
    final uri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final kinetic = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: kinetic.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Column(
          children: [
            // ── Flat header (V5): functional row + brand row ──────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                MediaQuery.of(context).padding.top + 10,
                hPad,
                16,
              ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    KineticGlassIconButton(
                      size: 37,
                      visualSize: 37,
                      label: isVi ? 'Quay lại' : 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: BladeIcon(
                        BladeIconName.chevL,
                        size: 18,
                        color: kinetic.textSecondary,
                        strokeWidth: 1.7,
                      ),
                    ),
                    const AuthLanguageToggle(),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const AetronBrandMark(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVi ? 'Khôi phục mật khẩu' : 'Forgot password',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: kinetic.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isVi
                                ? 'Nhập email đã đăng ký với Aetron để nhận đường dẫn đặt lại mật khẩu an toàn.'
                                : 'Enter your registered email address to receive a secure password reset link.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: kinetic.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 2. Bottom Section: Frosted Glassline Sheet ────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KineticTokens.radiusXXL),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kinetic.surface1.withValues(
                      alpha: kinetic.isDark ? 0.84 : 0.90,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(KineticTokens.radiusXXL),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: kinetic.isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      hPad + 4,
                      20,
                      hPad + 4,
                      bottomInset + 28,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: _isSent
                          ? _buildSuccessState(context, isVi)
                          : _buildInputState(context, isVi),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// ── VIEW A: INPUT EMAIL STATE ─────────────────────────────────────────────
  Widget _buildInputState(BuildContext context, bool isVi) {
    final kinetic = context.kinetic;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('input_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kinetic.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Medallion — flat primary tint circle with mail glyph (board v2/v3)
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kinetic.primary.withValues(alpha: 0.12),
              ),
              child: BladeIcon(
                BladeIconName.mail,
                color: kinetic.primary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Email Input Field
          Text(
            isVi ? 'Địa chỉ email' : 'Email address',
            style: TextStyle(
              color: kinetic.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: kinetic.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: isVi ? 'name@example.com' : 'name@example.com',
              hintStyle: TextStyle(color: kinetic.textMuted, fontSize: 14),
              filled: true,
              fillColor: kinetic.background,
              prefixIcon: BladeIcon(
                BladeIconName.mail,
                color: kinetic.primary,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
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
            ),
            validator: (val) {
              final text = val?.trim() ?? '';
              if (text.isEmpty) {
                return isVi
                    ? 'Vui lòng nhập email của bạn'
                    : 'Please enter your email';
              }
              if (!text.contains('@') || !text.contains('.')) {
                return isVi
                    ? 'Định dạng email không hợp lệ'
                    : 'Invalid email address format';
              }
              return null;
            },
          ),

          // Error Message Alert
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kinetic.error.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kinetic.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: kinetic.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: kinetic.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Primary Send Reset Link Button — V4 KineticButton (flat pill)
          KineticButton(
            label: isVi ? 'Gửi liên kết xác thực' : 'Send reset link',
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            height: KineticTokens.buttonHeightPrimary,
            onPressed: _isLoading ? null : _sendResetEmail,
          ),
          const SizedBox(height: 24),

          // Google Account Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kinetic.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kinetic.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isVi
                        ? 'Đăng nhập bằng Google? Bạn không cần mật khẩu Aetron. Chỉ cần chọn "Đăng nhập với Google" ở màn hình chính.'
                        : 'Using Google Sign-In? You do not need an Aetron password. Simply choose "Continue with Google" on the login screen.',
                    style: TextStyle(
                      color: kinetic.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Back to login button
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: BladeIcon(
                BladeIconName.chevL,
                color: kinetic.primary,
                size: 16,
              ),
              label: Text(
                isVi ? 'Quay lại Đăng nhập' : 'Back to Login',
                style: TextStyle(
                  color: kinetic.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── VIEW B: SUCCESS SENT STATE ────────────────────────────────────────────
  Widget _buildSuccessState(BuildContext context, bool isVi) {
    final kinetic = context.kinetic;
    final email = _emailController.text.trim();

    return Column(
      key: const ValueKey('success_state'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kinetic.secondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Glowing Success Mint Icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [kinetic.surface3, kinetic.surface1],
              ),
              border: Border.all(color: kinetic.secondary, width: 1.8),
            ),
            child: BladeIcon(
              BladeIconName.mail,
              color: kinetic.secondary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          isVi ? 'ĐÃ GỬI LIÊN KẾT XÁC THỰC!' : 'CHECK YOUR INBOX!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: kinetic.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Email highlight badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: kinetic.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kinetic.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BladeIcon(BladeIconName.mail, color: kinetic.primary, size: 14),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: TextStyle(
                    color: kinetic.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Instruction Text
        Text(
          isVi
              ? 'Chúng tôi đã gửi email chứa đường dẫn khôi phục mật khẩu. Vui lòng mở email và nhấn vào liên kết để thiết lập mật khẩu mới (kiểm tra cả mục Thư rác/Spam).'
              : 'We sent a secure password reset link to your email. Click the link in the message to set a new password (please also check your Spam folder).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: kinetic.textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),

        // Open Email App Button — V4 KineticButton (flat pill)
        KineticButton(
          label: isVi ? 'Mở ứng dụng email' : 'Open email app',
          icon: Icons.open_in_new_rounded,
          height: KineticTokens.buttonHeightPrimary,
          onPressed: _openEmailApp,
        ),
        const SizedBox(height: 14),

        // Resend Button with Countdown
        KineticButton(
          label: _resendCountdown > 0
              ? (isVi
                    ? 'Gửi lại sau (${_resendCountdown}s)'
                    : 'Resend in (${_resendCountdown}s)')
              : (isVi ? 'Gửi lại email' : 'Resend email'),
          variant: KineticButtonVariant.secondary,
          height: KineticTokens.buttonHeight,
          onPressed: (_resendCountdown == 0 && !_isLoading)
              ? _sendResetEmail
              : null,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kinetic.error.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kinetic.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: kinetic.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: kinetic.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Back to Login Button
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: BladeIcon(
              BladeIconName.chevL,
              color: kinetic.textMuted,
              size: 16,
            ),
            label: Text(
              isVi ? 'Quay lại Đăng nhập' : 'Back to Login',
              style: TextStyle(
                color: kinetic.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 2. RESET PASSWORD SCREEN (CYBER ATHLETIC REDESIGN WITH LIVE TELEMETRY)
/// ════════════════════════════════════════════════════════════════════════════
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.onPasswordUpdated});

  final VoidCallback? onPasswordUpdated;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final lang = ref.read(appLanguageProvider);
    final isVi = lang == AppLanguage.vi;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
          data: {'password_upgraded_v1': true},
        ),
      );

      if (!mounted) return;
      setState(() {
        _successMessage = isVi
            ? 'Mật khẩu đã được cập nhật thành công!'
            : 'Password updated successfully!';
        _isLoading = false;
      });

      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onPasswordUpdated?.call();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = isVi
            ? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.'
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final kinetic = context.kinetic;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final username = (currentUser?.userMetadata?['username'] as String?) ??
        currentUser?.email?.split('@').first;

    return Scaffold(
      backgroundColor: kinetic.background,
      body: Column(
        children: [
          // ── Flat brand header (V5): real logo + screen title/subtitle ────
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              16,
            ),
            child: Row(
              children: [
                const AetronBrandMark(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Thiết lập mật khẩu mới' : 'Set new password',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: kinetic.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVi
                            ? 'Tạo mật khẩu mạnh để bảo vệ hồ sơ và dữ liệu luyện tập của bạn.'
                            : 'Create a strong password to secure your profile & workouts.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: kinetic.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Bottom Section: V4 flat card ───────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: kinetic.surface1,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KineticTokens.radiusXXL),
                ),
                boxShadow: kinetic.isDark
                    ? null
                    : KineticTokens.shadowCardLight(),
                border: kinetic.isDark
                    ? Border(top: BorderSide(color: kinetic.borderSubtle))
                    : null,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KineticTokens.radiusXXL),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: kinetic.primary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Glowing Shield Icon
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [kinetic.surface3, kinetic.surface1],
                              ),
                              border: Border.all(
                                color: kinetic.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: BladeIcon(
                              BladeIconName.shield,
                              color: kinetic.primary,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // New Password Field
                        Text(
                          isVi ? 'Mật khẩu mới' : 'New password',
                          style: TextStyle(
                            color: kinetic.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: kinetic.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: isVi
                                ? 'Tối thiểu 8 ký tự'
                                : 'At least 8 characters',
                            hintStyle: TextStyle(
                              color: kinetic.textMuted,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: kinetic.background,
                            prefixIcon: BladeIcon(
                              BladeIconName.lock,
                              color: kinetic.primary,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: BladeIcon(
                                BladeIconName.eye,
                                color: kinetic.textMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.primary,
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: kinetic.error),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.error,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (val) =>
                              validatePasswordStrict(val, currentLang, username: username),
                        ),

                        // Interactive Password Security Meter
                        PasswordSecurityMeter(
                          password: _passwordController.text,
                          lang: currentLang,
                          username: username,
                        ),
                        const SizedBox(height: 18),

                        // Confirm Password Field
                        Text(
                          isVi ? 'Xác nhận mật khẩu' : 'Confirm password',
                          style: TextStyle(
                            color: kinetic.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: kinetic.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: isVi
                                ? 'Nhập lại mật khẩu mới'
                                : 'Repeat new password',
                            hintStyle: TextStyle(
                              color: kinetic.textMuted,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: kinetic.background,
                            prefixIcon: BladeIcon(
                              BladeIconName.lock,
                              color: kinetic.primary,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: BladeIcon(
                                BladeIconName.eye,
                                color: kinetic.textMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.primary,
                                width: 1.5,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: kinetic.error),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kinetic.error,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return isVi
                                  ? 'Vui lòng xác nhận mật khẩu'
                                  : 'Please confirm your password';
                            }
                            if (val != _passwordController.text) {
                              return isVi
                                  ? 'Mật khẩu xác nhận không khớp'
                                  : 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        // Error Message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kinetic.error.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kinetic.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: kinetic.error,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: kinetic.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Success Message
                        if (_successMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kinetic.secondary.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kinetic.secondary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: kinetic.secondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: TextStyle(
                                      color: kinetic.secondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit Update Button — V4 KineticButton (flat pill)
                        KineticButton(
                          label: isVi ? 'Cập nhật mật khẩu' : 'Update password',
                          icon: Icons.check_rounded,
                          isLoading: _isLoading,
                          height: KineticTokens.buttonHeightPrimary,
                          onPressed: _isLoading ? null : _updatePassword,
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
    );
  }
}
