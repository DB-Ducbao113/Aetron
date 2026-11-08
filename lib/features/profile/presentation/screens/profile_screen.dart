import 'dart:async';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/achievements_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_athlete_card.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_avatar_source_sheet.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_biometrics_bento.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_profile_action_tile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_profile_top_bar.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logout_dialog.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _resetCallbackUrl = 'io.supabase.flutter://callback';

User? _getSafeUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh(String? userId) async {
    setState(() => _isRefreshing = true);
    try {
      if (userId != null) {
        ref.invalidate(userProfileProvider(userId));
        await ref.read(userProfileProvider(userId).future);
      }
      await ref.read(userGoalProvider.notifier).refresh();
      await ref.read(workoutListProvider.notifier).refresh();
    } catch (_) {
      // Ignore network errors during pull-to-refresh
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final user = _getSafeUser();
    final userId = user?.id;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final avatar = ref.watch(avatarUploadProvider);
    final streak = ref.watch(streakProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final activeGoal = ref.watch(userGoalProvider).valueOrNull;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface2,
          onRefresh: () => _handleRefresh(userId),
          child: _isRefreshing
              ? KineticSkeleton.profile()
              : profileAsync.when(
                  loading: () => KineticSkeleton.profile(),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Your profile could not be loaded.\n$error',
                          textAlign: TextAlign.center,
                          style: KineticTypography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  data: (profile) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      KineticTokens.page,
                      12,
                      KineticTokens.page,
                      100,
                    ),
                    children: [
              // 1. Top Bar
              KineticProfileTopBar(currentLang: currentLang),
              const SizedBox(height: KineticTokens.spaceMD),

              // 2. Athlete Card
              KineticAthleteCard(
                user: user,
                profile: profile,
                avatarState: avatar,
                currentStreak: streak.currentStreak,
                currentLang: currentLang,
                onCameraTap: () => _showAvatarSourceSheet(context, ref),
              ),
              const SizedBox(height: KineticTokens.spaceSM),

              // 3. Biometrics Bento
              KineticBiometricsBento(
                profile: profile,
                useMetricUnits: useMetricUnits,
                currentLang: currentLang,
                onEdit: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => profile != null
                            ? ProfileSetupScreen(existingProfile: profile)
                            : const ProfileSetupScreen(),
                      ),
                    )
                    .then((_) {
                      if (userId != null) {
                        ref.invalidate(userProfileProvider(userId));
                      }
                    }),
              ),
              const SizedBox(height: KineticTokens.spaceLG),

              // 4. System Actions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KineticTokens.spaceXXS),
                child: Text(
                  AppTranslations.get('system_actions', currentLang),
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXS),

              // Training Goals Action
              KineticProfileActionTile(
                icon: Icons.track_changes_rounded,
                iconColor: colors.primary,
                label: currentLang == AppLanguage.vi
                    ? 'Mục tiêu rèn luyện'
                    : 'Training Goals',
                badgeText: activeGoal != null
                    ? '${activeGoal.targetValue.toStringAsFixed(0)} ${activeGoal.goalType == GoalType.distance ? (useMetricUnits ? 'km' : 'mi') : (activeGoal.goalType == GoalType.workouts ? (currentLang == AppLanguage.vi ? 'buổi' : 'runs') : 'kcal')}'
                    : (currentLang == AppLanguage.vi ? 'Thiết lập' : 'Set goal'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalScreen()),
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXXS),

              // Achievements Action
              KineticProfileActionTile(
                icon: Icons.emoji_events_outlined,
                iconColor: colors.tertiary,
                label: AppTranslations.get('achievements', currentLang),
                badgeText:
                    '${workoutsAsync.valueOrNull?.length ?? 0} ${currentLang == AppLanguage.vi ? 'buổi' : 'runs'}',
                onTap: () => _openAchievements(
                  context,
                  currentLang: currentLang,
                  totalWorkouts: workoutsAsync.valueOrNull?.length ?? 0,
                  currentStreak: streak.currentStreak,
                  longestStreak: streak.longestStreak,
                  totalDistanceKm:
                      workoutsAsync.valueOrNull?.fold<double>(
                        0,
                        (sum, workout) => sum + workout.distanceKm,
                      ) ??
                      0,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXXS),


              // Security & Password Action
              KineticProfileActionTile(
                icon: Icons.shield_outlined,
                iconColor: colors.secondary,
                label: AppTranslations.get('security', currentLang),
                onTap: () => _showSecuritySheet(
                  context,
                  _accountUsername(user),
                  currentLang,
                  ref,
                ),
              ),
              const SizedBox(height: KineticTokens.spaceXXS),

              // Sign Out Action (Destructive)
              KineticProfileActionTile(
                icon: Icons.logout_rounded,
                isDestructive: true,
                label: AppTranslations.get('logout', currentLang),
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _showAvatarSourceSheet(BuildContext context, WidgetRef ref) {
    final currentLang = ref.read(appLanguageProvider);
    final profileAvatarUrl = ref
        .read(currentUserProfileProvider)
        .valueOrNull
        ?.avatarUrl;
    final avatarUrl = ref
        .read(avatarUploadProvider)
        .resolveAvatarUrl(profileAvatarUrl);
    final hasAvatar =
        avatarUrl != null && avatarUrl.isNotEmpty ||
        ref.read(avatarUploadProvider).localAvatarPathOverride != null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => KineticAvatarSourceSheet(
        hasAvatar: hasAvatar,
        currentLang: currentLang,
      ),
    );
  }

  void _showSecuritySheet(
    BuildContext context,
    String accountUsername,
    AppLanguage currentLang,
    WidgetRef ref,
  ) {
    final colors = context.kinetic;
    final user = Supabase.instance.client.auth.currentUser;
    final userMetadata = user?.userMetadata ?? {};
    final isGoogleUser = user?.appMetadata['provider'] == 'google';
    final isPasswordUpgraded = isGoogleUser || (userMetadata['password_upgraded_v1'] == true);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(KineticTokens.radiusHero)),
            border: Border(top: BorderSide(color: colors.borderSubtle)),
          ),
          padding: const EdgeInsets.fromLTRB(KineticTokens.spaceLG, KineticTokens.spaceMD, KineticTokens.spaceLG, KineticTokens.spaceXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.get('security', currentLang),
                style: KineticTypography.headlineMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@$accountUsername',
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // DYNAMIC KINETIC SECURITY STATUS CARD
              if (!isPasswordUpgraded) ...[
                // Warning Card for accounts requiring upgrade
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.tertiary.withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.tertiary.withValues(alpha: 0.12),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.tertiary.withValues(alpha: 0.15),
                              border: Border.all(color: colors.tertiary.withValues(alpha: 0.4)),
                            ),
                            child: Icon(Icons.security_update_good_rounded, color: colors.tertiary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppTranslations.get('security_upgrade_title', currentLang),
                              style: KineticTypography.label.copyWith(
                                color: colors.tertiary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.get('security_upgrade_desc', currentLang),
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      KineticButton(
                        label: AppTranslations.get('update_password_action', currentLang),
                        icon: Icons.lock_reset_rounded,
                        variant: KineticButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showUpdatePasswordSheet(context, currentLang);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Optimal Security Card when password is up to date
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.secondary.withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.secondary.withValues(alpha: 0.12),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.secondary.withValues(alpha: 0.15),
                          border: Border.all(color: colors.secondary.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.verified_user_rounded, color: colors.secondary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'BẢO MẬT ĐÃ ĐẠT CHUẨN TỐI ƯU'
                                  : 'STRONG SECURITY ACTIVE',
                              style: KineticTypography.label.copyWith(
                                color: colors.secondary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'Tài khoản đã được bảo vệ với mật khẩu đủ tiêu chuẩn mạnh (chữ hoa, thường, số, ký tự đặc biệt).'
                                  : 'Your account is protected with strong password security standards.',
                              style: KineticTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _SecurityOption(
                icon: Icons.shield_rounded,
                title: currentLang == AppLanguage.vi
                    ? 'Đổi mật khẩu mới'
                    : 'Change password',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Cập nhật lại mật khẩu đăng nhập tài khoản.'
                    : 'Update your account login password.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showUpdatePasswordSheet(context, currentLang);
                },
              ),
              const SizedBox(height: 10),
              _SecurityOption(
                icon: Icons.account_circle_outlined,
                title: currentLang == AppLanguage.vi
                    ? 'Khôi phục qua Google Gmail'
                    : 'Google Gmail recovery',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Liên kết tài khoản Google để khôi phục khi quên mật khẩu.'
                    : 'Link a Google account to sign back in if you lose access.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showGoogleGmailRecoverySheet(context, currentLang: currentLang);
                },
              ),
              const SizedBox(height: 10),
              _SecurityOption(
                icon: Icons.person_remove_rounded,
                title: currentLang == AppLanguage.vi
                    ? 'Xóa tài khoản vĩnh viễn'
                    : 'Delete account permanently',
                subtitle: currentLang == AppLanguage.vi
                    ? 'Xóa vĩnh viễn dữ liệu tài khoản và toàn bộ lịch sử tập luyện.'
                    : 'Permanently remove your account and all workout records.',
                iconColor: colors.error,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteAccount(context, currentLang, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppLanguage lang,
    WidgetRef ref,
  ) async {
    final isVi = lang == AppLanguage.vi;
    final colors = context.kinetic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colors.error.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.error.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVi ? 'Xóa tài khoản vĩnh viễn' : 'Delete Account',
                style: KineticTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Hành động này sẽ xóa vĩnh viễn toàn bộ lịch sử tập luyện, huy hiệu, mục tiêu và dữ liệu cá nhân của bạn. Dữ liệu không thể phục hồi sau khi xóa.'
              : 'This action will permanently delete all your workout history, badges, goals, and personal data. This cannot be undone.',
          style: KineticTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Hủy bỏ' : 'Cancel',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isVi ? 'Xác nhận xóa' : 'Confirm Delete',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.error.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.error),
                    const SizedBox(height: 18),
                    Text(
                      isVi ? 'Đang xóa tài khoản...' : 'Deleting account...',
                      style: KineticTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          ref.invalidate(workoutListProvider);
          ref.invalidate(userProfileProvider(user.id));
          ref.invalidate(currentAvatarDisplayProvider);
          ref.invalidate(userGoalProvider);

          await ref.read(userProfileRepositoryProvider).deleteAccount(user.id);

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: colors.surface1,
                content: Text(
                  isVi
                      ? 'Tài khoản và toàn bộ dữ liệu đã được xóa thành công.'
                      : 'Account and all data deleted successfully.',
                  style: KineticTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: colors.error,
                content: Text(
                  isVi
                      ? 'Lỗi khi xóa tài khoản: $e'
                      : 'Error deleting account: $e',
                  style: KineticTypography.bodySmall.copyWith(color: colors.onPrimary),
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _showUpdatePasswordSheet(BuildContext context, AppLanguage currentLang) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdatePasswordSheet(currentLang: currentLang),
    );
  }

  void _showGoogleGmailRecoverySheet(BuildContext context, {required AppLanguage currentLang}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GoogleGmailRecoverySheet(currentLang: currentLang),
    );
  }

  void _openAchievements(
    BuildContext context, {
    required AppLanguage currentLang,
    required int totalWorkouts,
    required int currentStreak,
    required int longestStreak,
    required double totalDistanceKm,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AchievementsScreen(),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AetronLogoutDialog.show(context);
    if (confirmed == true && context.mounted) {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        await LocalDB.clearAllForUser(currentUserId);
      }
      await Supabase.instance.client.auth.signOut();
      ref.invalidate(workoutListProvider);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    }
  }
}

class _GoogleGmailRecoverySheet extends StatefulWidget {
  const _GoogleGmailRecoverySheet({this.currentLang = AppLanguage.en});

  final AppLanguage currentLang;

  @override
  State<_GoogleGmailRecoverySheet> createState() =>
      _GoogleGmailRecoverySheetState();
}

class _GoogleGmailRecoverySheetState extends State<_GoogleGmailRecoverySheet> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLinking = false;
  String? _errorMessage;
  String? _statusMessage;

  User? get _user => _getSafeUser();

  UserIdentity? get _googleIdentity {
    for (final identity in _user?.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') return identity;
    }
    return null;
  }

  bool get _isGoogleLinked => _googleIdentity != null;

  String? get _googleEmail {
    final identityEmail = _googleIdentity?.identityData?['email'] as String?;
    return identityEmail ?? _user?.email;
  }

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        _,
      ) async {
        try {
          await Supabase.instance.client.auth.getUser();
        } catch (_) {}
        if (mounted) setState(() {});
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _linkGoogleGmail() async {
    if (_isLinking || _isGoogleLinked) return;

    setState(() {
      _isLinking = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final opened = await Supabase.instance.client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _resetCallbackUrl,
        scopes: 'email profile',
        queryParams: const {'prompt': 'select_account'},
      );
      if (!mounted) return;
      final isVi = widget.currentLang == AppLanguage.vi;
      setState(() {
        _isLinking = false;
        _statusMessage = opened
            ? (isVi
                ? 'Hoàn tất đăng nhập Google trên trình duyệt, sau đó quay lại Aetron.'
                : 'Complete Google sign-in in your browser, then return to Aetron.')
            : null;
        _errorMessage = opened
            ? null
            : (isVi
                ? 'Không thể mở đăng nhập Google.'
                : 'Could not open Google sign-in.');
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      final isVi = widget.currentLang == AppLanguage.vi;
      setState(() {
        _isLinking = false;
        _errorMessage = isVi
            ? 'Không thể liên kết Google Gmail của bạn.'
            : 'Could not link your Google Gmail.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;
    final linked = _isGoogleLinked;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(KineticTokens.radiusHero)),
          border: Border(top: BorderSide(color: colors.borderSubtle)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset('assets/GoogleLogo.jpg', width: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isVi ? 'Khôi phục qua Google Gmail' : 'Google Gmail recovery',
                    style: KineticTypography.headlineMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: linked
                    ? colors.secondary.withValues(alpha: 0.08)
                    : colors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: linked ? colors.secondary : colors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    linked
                        ? Icons.verified_user_rounded
                        : Icons.account_circle_outlined,
                    color: linked ? colors.secondary : colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      linked
                          ? (isVi
                              ? 'Đã liên kết: ${_googleEmail ?? "Tài khoản Google"}'
                              : 'Linked: ${_googleEmail ?? "Google account"}')
                          : (isVi
                              ? 'Chưa liên kết Google Gmail'
                              : 'No Google Gmail linked'),
                      style: KineticTypography.bodySmall.copyWith(
                        color: linked ? colors.secondary : colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              linked
                  ? (isVi
                      ? 'Bạn có thể khôi phục quyền truy cập bằng cách chọn Tiếp tục với Google ở màn hình đăng nhập Aetron.'
                      : 'You can recover access by choosing Continue with Google on the Aetron sign-in screen.')
                  : (isVi
                      ? 'Chọn tài khoản Gmail bạn muốn dùng để khôi phục tài khoản khi cần.'
                      : 'Choose the Gmail account you want to use for account recovery.'),
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _RecoveryMessageBox.error(_errorMessage!, colors: colors),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              _RecoveryMessageBox.success(_statusMessage!, colors: colors),
            ],
            const SizedBox(height: 20),
            KineticButton(
              label: linked
                  ? (isVi ? 'ĐÃ LIÊN KẾT GOOGLE GMAIL' : 'GOOGLE GMAIL LINKED')
                  : (isVi ? 'LIÊN KẾT GOOGLE GMAIL' : 'LINK GOOGLE GMAIL'),
              variant: linked ? KineticButtonVariant.secondary : KineticButtonVariant.primary,
              isLoading: _isLinking,
              onPressed: linked || _isLinking ? null : _linkGoogleGmail,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryMessageBox extends StatelessWidget {
  const _RecoveryMessageBox({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  factory _RecoveryMessageBox.error(String message, {required KineticColors colors}) {
    return _RecoveryMessageBox(
      message: message,
      backgroundColor: colors.error.withValues(alpha: 0.15),
      borderColor: colors.error.withValues(alpha: 0.45),
      textColor: colors.error,
    );
  }

  factory _RecoveryMessageBox.success(String message, {required KineticColors colors}) {
    return _RecoveryMessageBox(
      message: message,
      backgroundColor: colors.secondary.withValues(alpha: 0.15),
      borderColor: colors.secondary.withValues(alpha: 0.45),
      textColor: colors.secondary,
    );
  }

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: KineticTypography.bodyMedium.copyWith(color: textColor),
      ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final resolvedIconColor = iconColor ?? colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: resolvedIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: resolvedIconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayName(String? email) {
  if (email == null || email.isEmpty) return 'Athlete';
  final raw = email.split('@').first.trim();
  return raw.isEmpty ? 'Athlete' : raw[0].toUpperCase() + raw.substring(1);
}

String _accountUsername(User? user) {
  final username = user?.userMetadata?['username'] as String?;
  return username ?? _displayName(user?.email);
}

class _UpdatePasswordSheet extends StatefulWidget {
  final AppLanguage currentLang;

  const _UpdatePasswordSheet({required this.currentLang});

  @override
  State<_UpdatePasswordSheet> createState() => _UpdatePasswordSheetState();
}

class _UpdatePasswordSheetState extends State<_UpdatePasswordSheet> {
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

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

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

      if (!mounted) return;
      final colors = context.kinetic;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.get('password_updated_success', widget.currentLang),
            style: KineticTypography.bodySmall.copyWith(color: colors.onPrimary),
          ),
          backgroundColor: colors.secondary,
        ),
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
        _errorMessage = widget.currentLang == AppLanguage.vi
            ? 'Không thể cập nhật mật khẩu. Vui lòng thử lại.'
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final lang = widget.currentLang;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(KineticTokens.radiusHero)),
          border: Border(top: BorderSide(color: colors.borderSubtle)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppTranslations.get('security_upgrade_title', lang),
                  style: KineticTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('security_upgrade_desc', lang),
                  style: KineticTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // New Password Field
                Text(
                  AppTranslations.get('new_password', lang).toUpperCase(),
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) => validatePasswordStrict(val, lang),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: colors.textMuted.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: colors.surface2,
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: colors.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
                PasswordSecurityMeter(
                  password: _passwordController.text,
                  lang: lang,
                ),
                const SizedBox(height: 12),

                // Confirm New Password
                Text(
                  AppTranslations.get('confirm_password', lang).toUpperCase(),
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return AppTranslations.get('password_mismatch', lang);
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: colors.textMuted.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: colors.surface2,
                    prefixIcon: Icon(Icons.lock_clock_outlined, color: colors.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                KineticButton(
                  label: AppTranslations.get('update_password_action', lang),
                  icon: Icons.shield_rounded,
                  isLoading: _isLoading,
                  variant: KineticButtonVariant.primary,
                  onPressed: _isLoading ? null : _updatePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
