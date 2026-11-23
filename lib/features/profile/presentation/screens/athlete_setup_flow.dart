import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logout_dialog.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AthleteSetupFlow extends StatefulWidget {
  const AthleteSetupFlow({super.key});

  @override
  State<AthleteSetupFlow> createState() => _AthleteSetupFlowState();
}

class _AthleteSetupFlowState extends State<AthleteSetupFlow> {
  bool? _hasDisplayName;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final displayName =
        (meta?['display_name'] ?? meta?['full_name'] ?? meta?['name'])
            as String?;
    _hasDisplayName = displayName != null && displayName.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasDisplayName == null) {
      final colors = context.kinetic;
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return _hasDisplayName!
        ? const ProfileSetupScreen()
        : _AthleteNameScreen(
            onComplete: () => setState(() => _hasDisplayName = true),
          );
  }
}

class _AthleteNameScreen extends ConsumerStatefulWidget {
  const _AthleteNameScreen({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_AthleteNameScreen> createState() => _AthleteNameScreenState();
}

class _AthleteNameScreenState extends ConsumerState<_AthleteNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final lang = ref.read(appLanguageProvider);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': _nameController.text.trim()}),
      );
      if (mounted) widget.onComplete();
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = lang == AppLanguage.vi
              ? 'Không thể lưu tên. Vui lòng thử lại.'
              : 'Could not save your name. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final colors = context.kinetic;
    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 24;

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 18, hPad, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (lang == AppLanguage.vi
                                ? 'HIỆU CHỈNH DANH TÍNH'
                                : 'IDENTITY CALIBRATION')
                            .toUpperCase(),
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang == AppLanguage.vi
                            ? 'Thiết lập Vận động viên'
                            : 'Athlete Setup',
                        style: KineticTypography.headlineLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  KineticGlassIconButton(
                    size: 37,
                    visualSize: 37,
                    label: lang == AppLanguage.vi ? 'Đăng xuất' : 'Sign out',
                    icon: BladeIcon(
                      BladeIconName.logout,
                      color: colors.textSecondary,
                      size: 18,
                      strokeWidth: 1.7,
                    ),
                    onPressed: () async {
                      final confirmed = await AetronLogoutDialog.show(context);
                      if (confirmed == true && context.mounted) {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const AuthWrapper(),
                            ),
                            (_) => false,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                    border: Border.all(color: colors.primary),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: colors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                lang == AppLanguage.vi
                    ? 'BẠN TÊN LÀ GÌ?'
                    : 'WHAT SHOULD\nWE CALL YOU?',
                style: KineticTypography.headlineLarge.copyWith(
                  color: colors.textPrimary,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lang == AppLanguage.vi
                    ? 'Đây là tên Aetron sẽ dùng để chào bạn khi tập luyện.'
                    : 'This is how Aetron will greet you during your training.',
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continue(),
                  style: KineticTypography.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.length < 2) {
                      return lang == AppLanguage.vi
                          ? 'Nhập ít nhất 2 ký tự'
                          : 'Enter at least 2 characters';
                    }
                    if (name.length > 24) {
                      return lang == AppLanguage.vi
                          ? 'Nhập tối đa 24 ký tự'
                          : 'Use 24 characters or fewer';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: lang == AppLanguage.vi
                        ? 'HỌ VÀ TÊN'
                        : 'YOUR NAME',
                    hintStyle: KineticTypography.bodyMedium.copyWith(
                      color: colors.textMuted,
                      letterSpacing: 1.0,
                    ),
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: colors.primary,
                    ),
                    filled: true,
                    fillColor: colors.surface1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: KineticTypography.bodySmall.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(flex: 2),
              KineticButton(
                label: lang == AppLanguage.vi ? 'TIẾP TỤC' : 'CONTINUE',
                icon: Icons.arrow_forward_rounded,
                variant: KineticButtonVariant.primary,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _continue,
                height: KineticTokens.buttonHeightPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
