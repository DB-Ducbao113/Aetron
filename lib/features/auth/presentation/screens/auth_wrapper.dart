import 'dart:async';

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/app/bootstrap.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/force_password_upgrade_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/startup_globe_gate.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/athlete_setup_flow.dart';
import 'package:fitness_exercise_application/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Root auth gate.

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  late final Stream<AuthState> _authStream;
  bool _isPasswordRecovery = false;
  bool _isRetrying = false; // loading state for retry button
  bool _passwordRecoveryCompleted = false;
  String? _activeUserId;
  bool _showingWelcomeGlobe = false;
  bool? _welcomeSeen;
  final _startupGlobeGate = StartupGlobeGate();

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  void _resetAccountScopedState({String? previousUserId}) {
    // Logout is not deletion. Keep offline workouts until their owner syncs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(workoutListProvider);
      ref.invalidate(userGoalProvider);
      ref.invalidate(avatarUploadProvider);
      if (previousUserId != null) {
        ref.invalidate(userProfileProvider(previousUserId));
        ref.invalidate(hasUserProfileProvider(previousUserId));
      }
      unawaited(NotificationService.instance.cancelAll());
    });
  }

  @override
  void dispose() {
    // No explicit subscription to cancel; StreamBuilder handles stream lifecycle.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = ref.watch(appLanguageProvider) == AppLanguage.vi;

    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (kDebugBypassAuth) {
          return const MainShell();
        }

        if (_startupGlobeGate.shouldShow) {
          return AetronGlobeOrbitScreen(
            duration: const Duration(milliseconds: 1200),
            customTitle: 'Aetron',
            forceDarkPalette: true,
            onComplete: () {
              if (!mounted) return;
              setState(_startupGlobeGate.complete);
            },
          );
        }

        final session =
            snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        if (event == AuthChangeEvent.passwordRecovery &&
            !_passwordRecoveryCompleted) {
          _isPasswordRecovery = true;
        }

        if (session == null) {
          if (_activeUserId != null) {
            _resetAccountScopedState(previousUserId: _activeUserId);
            _activeUserId = null;
            _showingWelcomeGlobe = false;
            _welcomeSeen = null;
          }
          _isPasswordRecovery = false;
          _passwordRecoveryCompleted = false;
          final error = snapshot.error;
          String? loginError;
          if (error != null) {
            final errStr = error.toString().toLowerCase();
            if (errStr.contains('expired') ||
                errStr.contains('invalid token') ||
                errStr.contains('otp')) {
              loginError = isVi
                  ? 'Đường dẫn khôi phục mật khẩu đã hết hạn hoặc không hợp lệ. Vui lòng yêu cầu lại.'
                  : 'Password reset link has expired or is invalid. Please request a new one.';
            }
          }
          return LoginScreen(initialErrorMessage: loginError);
        }

        if (_isPasswordRecovery) {
          return ResetPasswordScreen(
            onPasswordUpdated: () {
              if (mounted) {
                setState(() {
                  _isPasswordRecovery = false;
                  _passwordRecoveryCompleted = true;
                });
              }
            },
          );
        }

        // Check if user has upgraded to strong password policy
        final userMetadata = session.user.userMetadata ?? {};

        final isOAuthUser = _isOAuthUser(session);
        final isPasswordUpgraded =
            isOAuthUser || (userMetadata['password_upgraded_v1'] == true);

        if (!isPasswordUpgraded) {
          return const ForcePasswordUpgradeScreen();
        }

        // Route signed-in users by profile state.
        final userId = session.user.id;
        if (_activeUserId != userId) {
          final previousUserId = _activeUserId;
          _activeUserId = userId;
          _showingWelcomeGlobe = false;
          _welcomeSeen = null;
          _resetAccountScopedState(previousUserId: previousUserId);
          unawaited(() async {
            try {
              await ref.read(appBootstrapServiceProvider).hydrateUser(userId);
            } catch (e) {
              debugPrint('[AuthWrapper] hydrateUser error: $e');
            }
          }());
        }
        final hasProfileAsync = ref.watch(hasUserProfileProvider(userId));

        final colors = context.kinetic;
        return hasProfileAsync.when(
          data: (hasProfile) {
            if (hasProfile) return MainShell();

            // 1. If currently displaying the globe transition after welcome
            if (_showingWelcomeGlobe) {
              return AetronGlobeOrbitScreen(
                duration: const Duration(milliseconds: 2400),
                customTitle: 'Aetron',
                customSubtitle: isVi
                    ? 'Đang thiết lập định vị vệ tinh GPS...'
                    : 'Calibrating GPS satellite positioning...',
                onComplete: () {
                  if (mounted) {
                    setState(() {
                      _showingWelcomeGlobe = false;
                      _welcomeSeen = true;
                    });
                  }
                },
              );
            }

            // 2. If welcome has already been seen in this session, show setup flow
            if (_welcomeSeen == true) {
              return const AthleteSetupFlow();
            }

            // 3. Check persisted welcome seen status
            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, prefsSnap) {
                if (prefsSnap.hasData) {
                  final welcomeSeen =
                      prefsSnap.data!.getBool(kWelcomeSeenPrefKey) ?? false;
                  if (welcomeSeen) {
                    return const AthleteSetupFlow();
                  }
                }
                return WelcomeScreen(
                  onNext: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(kWelcomeSeenPrefKey, true);
                    } catch (_) {}
                    if (mounted) {
                      setState(() {
                        _showingWelcomeGlobe = true;
                      });
                    }
                  },
                );
              },
            );
          },
          loading: () => const AetronGlobeOrbitScreen(customTitle: 'Aetron'),
          error: (error, stackTrace) {
            debugPrint('[AuthWrapper] hasProfile error: $error');
            return Scaffold(
              backgroundColor: colors.background,
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: colors.tertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isVi ? 'LỖI ĐỒNG BỘ HỒ SƠ' : 'PROFILE SYNC ERROR',
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isVi
                              ? 'Không thể tải thông tin tài khoản: $error'
                              : 'Unable to load account profile: $error',
                          textAlign: TextAlign.center,
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Retry button
                        Semantics(
                          button: true,
                          label: isVi
                              ? 'Thử lại – tải lại hồ sơ người dùng'
                              : 'Retry – reload user profile',
                          child: KineticButton(
                            label: isVi ? 'Thử lại' : 'Retry',
                            icon: Icons.refresh_rounded,
                            variant: KineticButtonVariant.primary,
                            isLoading: _isRetrying,
                            onPressed: () async {
                              setState(() => _isRetrying = true);
                              // Invalidate the profile provider to trigger a reload
                              ref.invalidate(hasUserProfileProvider(userId));
                              // Wait for the provider to complete (max 5 s) then hide spinner
                              await Future.any([
                                ref.watch(
                                  hasUserProfileProvider(userId).future,
                                ),
                                Future.delayed(const Duration(seconds: 5)),
                              ]);
                              if (mounted) setState(() => _isRetrying = false);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Logout button
                        Semantics(
                          button: true,
                          label: isVi
                              ? 'Đăng xuất – quay lại màn hình đăng nhập'
                              : 'Sign out – return to login screen',
                          child: KineticButton(
                            label: isVi ? 'Đăng xuất' : 'Sign out',
                            icon: Icons.logout_rounded,
                            variant: KineticButtonVariant.secondary,
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await Supabase.instance.client.auth.signOut();
                              if (!mounted) return;
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to determine if the user signed in via an OAuth provider.
  bool _isOAuthUser(Session session) {
    final appMetadata = session.user.appMetadata;
    final provider = (appMetadata['provider'] ?? '').toString().toLowerCase();
    final providers =
        (appMetadata['providers'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];
    final identities = session.user.identities ?? [];
    return provider == 'google' ||
        provider == 'facebook' ||
        provider == 'apple' ||
        provider == 'oauth' ||
        providers.contains('google') ||
        providers.contains('facebook') ||
        providers.contains('apple') ||
        identities.any((i) => i.provider.toLowerCase() != 'email');
  }
}
