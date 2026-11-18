import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logout_dialog.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final UserProfile? existingProfile;

  const ProfileSetupScreen({super.key, this.existingProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _heightFeetController;
  late final TextEditingController _heightInchesController;
  late final TextEditingController _ageController;
  late String _selectedGender;
  bool _isLoading = false;

  bool _hasInitializedUnits = false;

  void _populateControllers(bool useMetricUnits) {
    final profile = widget.existingProfile;
    final weight = profile?.weightKg;
    final totalInches = (profile?.heightCm ?? 0) / 2.54;
    var feet = totalInches ~/ 12;
    var inches = (totalInches - (feet * 12)).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    _weightController.text = weight == null
        ? ''
        : _formatValue(useMetricUnits ? weight : weight * 2.2046226218);
    _heightController.text = profile != null ? profile.heightCm.toString() : '';
    _heightFeetController.text = profile == null ? '' : '$feet';
    _heightInchesController.text = profile == null ? '' : '$inches';
    _ageController.text = profile != null ? profile.age.toString() : '';
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.existingProfile;
    final metricPrefAsync = ref.read(metricUnitsPreferenceProvider);
    final useMetricUnits = metricPrefAsync.valueOrNull ?? true;
    _hasInitializedUnits = metricPrefAsync.hasValue;

    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _heightFeetController = TextEditingController();
    _heightInchesController = TextEditingController();
    _ageController = TextEditingController();

    _populateControllers(useMetricUnits);

    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (_) {}
    final initialName = (user?.userMetadata?['display_name'] ??
            user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name']) as String? ??
        '';
    _displayNameController = TextEditingController(text: initialName);
    _selectedGender = profile?.gender ?? 'male';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final profileId = widget.existingProfile?.id ?? const Uuid().v4();
      final createdAt = widget.existingProfile?.createdAt ?? DateTime.now();
      final useMetricUnits =
          ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
      final cleanWeight = _weightController.text.trim().replaceAll(',', '.');
      final cleanHeight = _heightController.text.trim().replaceAll(',', '.');
      final cleanFeet = _heightFeetController.text.trim();
      final cleanInches = _heightInchesController.text.trim().replaceAll(',', '.');
      final cleanAge = _ageController.text.trim();

      final enteredWeight = double.parse(cleanWeight);
      final heightCm = useMetricUnits
          ? double.parse(cleanHeight)
          : (int.parse(cleanFeet) * 12 + double.parse(cleanInches)) * 2.54;
      final weightKg = useMetricUnits
          ? enteredWeight
          : enteredWeight / 2.2046226218;

      final profile = UserProfile(
        id: profileId,
        userId: user.id,
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: _approximateDateOfBirth(int.parse(cleanAge)),
        legacyAge: int.parse(cleanAge),
        gender: _selectedGender,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        avatarUrl: widget.existingProfile?.avatarUrl,
      );

      final repository = ref.read(userProfileRepositoryProvider);

      if (widget.existingProfile != null) {
        await repository.updateProfile(profile);
      } else {
        await repository.createProfile(profile);
      }

      final cleanDisplayName = _displayNameController.text.trim();
      if (cleanDisplayName.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'display_name': cleanDisplayName}),
          );
        } catch (e) {
          debugPrint('[ProfileSetupScreen] Could not update display name in auth metadata: $e');
        }
      }

      ref.invalidate(hasUserProfileProvider(user.id));
      ref.invalidate(userProfileProvider(user.id));

      if (mounted) {
        showAetronNotice(
          context,
          message: widget.existingProfile != null
              ? 'Profile updated successfully'
              : 'Profile created successfully',
          tone: AetronNoticeTone.success,
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (_) => false,
          );
        }
      }
    } catch (e, st) {
      debugPrint('❌ [ProfileSetupScreen] Error saving profile: $e\n$st');
      if (mounted) {
        String errorMessage = 'Could not save profile ($e)';
        if (e is PostgrestException) {
          errorMessage = 'Database error: ${e.message}';
        }
        showAetronNotice(
          context,
          message: errorMessage,
          tone: AetronNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setUseMetricUnits(bool useMetricUnits) async {
    final currentlyMetric =
        ref.read(metricUnitsPreferenceProvider).valueOrNull ?? true;
    if (currentlyMetric == useMetricUnits) return;

    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      _weightController.text = _formatValue(
        useMetricUnits ? weight / 2.2046226218 : weight * 2.2046226218,
      );
    }

    if (useMetricUnits) {
      final feet = int.tryParse(_heightFeetController.text) ?? 0;
      final inches = double.tryParse(_heightInchesController.text) ?? 0;
      if (feet > 0 || inches > 0) {
        _heightController.text = _formatValue((feet * 12 + inches) * 2.54);
      }
    } else {
      final heightCm = double.tryParse(_heightController.text);
      if (heightCm != null && heightCm > 0) {
        final totalInches = heightCm / 2.54;
        var feet = totalInches ~/ 12;
        var inches = (totalInches - feet * 12).round();
        if (inches == 12) {
          feet += 1;
          inches = 0;
        }
        _heightFeetController.text = '$feet';
        _heightInchesController.text = '$inches';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMetricUnitsPrefKey, useMetricUnits);
    ref.invalidate(metricUnitsPreferenceProvider);
  }

  DateTime _approximateDateOfBirth(int age) {
    final now = DateTime.now();
    final targetYear = now.year - age;
    if (now.month == 2 && now.day == 29) {
      final isLeapYear = (targetYear % 4 == 0 && targetYear % 100 != 0) ||
          (targetYear % 400 == 0);
      return DateTime(targetYear, 2, isLeapYear ? 29 : 28);
    }
    return DateTime(targetYear, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(metricUnitsPreferenceProvider, (previous, next) {
      if (next.hasValue && !_hasInitializedUnits) {
        _hasInitializedUnits = true;
        _populateControllers(next.value!);
      }
    });
    final currentLang = ref.watch(appLanguageProvider);
    final isEditing = widget.existingProfile != null;
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;
    final colors = context.kinetic;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KineticTokens.page, vertical: KineticTokens.spaceSM),
              child: Row(
                children: [
                  if (isEditing) ...[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? AppTranslations.get('edit_profile', currentLang)
                              : AppTranslations.get('profile', currentLang),
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentLang == AppLanguage.vi
                              ? (isEditing
                                  ? 'Cập nhật chỉ số sinh trắc học'
                                  : 'Thiết lập chỉ số sinh trắc học')
                              : (isEditing
                                  ? 'Update biometric metrics'
                                  : 'Initial biometric calibration'),
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isEditing)
                    IconButton(
                      tooltip: currentLang == AppLanguage.vi ? 'Đăng xuất' : 'Sign out',
                      icon: Icon(Icons.logout_rounded, color: colors.textSecondary),
                      onPressed: () async {
                        final confirmed = await AetronLogoutDialog.show(context);
                        if (confirmed == true && context.mounted) {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthWrapper()),
                              (_) => false,
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(KineticTokens.page, KineticTokens.spaceSM, KineticTokens.page, KineticTokens.spaceXXL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UnitSelector(
                        useMetricUnits: useMetricUnits,
                        onChanged: _setUseMetricUnits,
                        currentLang: currentLang,
                      ),
                      const SizedBox(height: KineticTokens.spaceMD),
                      _GlassCard(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.4),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: colors.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: KineticTokens.spaceLG),
                            _InputField(
                              controller: _displayNameController,
                              label: AppTranslations.get('display_name', currentLang),
                              hint: AppTranslations.get('display_name_hint', currentLang),
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return AppTranslations.get('display_name_empty', currentLang);
                                }
                                if (trimmed.length < 2) {
                                  return currentLang == AppLanguage.vi
                                      ? 'Tên hiển thị phải có ít nhất 2 ký tự'
                                      : 'Display name must have at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: KineticTokens.spaceSM),
                            _InputField(
                              controller: _weightController,
                              label: AppTranslations.get('weight', currentLang),
                              hint: useMetricUnits ? 'kg' : 'lb',
                              icon: Icons.monitor_weight_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return currentLang == AppLanguage.vi ? 'Vui lòng nhập cân nặng' : 'Please enter your weight';
                                }
                                final weight = double.tryParse(
                                  value.trim().replaceAll(',', '.'),
                                );
                                final minWeight = useMetricUnits ? 30.0 : 66.0;
                                final maxWeight = useMetricUnits
                                    ? 300.0
                                    : 661.0;
                                if (weight == null ||
                                    weight < minWeight ||
                                    weight > maxWeight) {
                                  return useMetricUnits
                                      ? (currentLang == AppLanguage.vi ? 'Cân nặng phải từ 30-300 kg' : 'Weight must be between 30-300 kg')
                                      : (currentLang == AppLanguage.vi ? 'Cân nặng phải từ 66-661 lb' : 'Weight must be between 66-661 lb');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: KineticTokens.spaceSM),
                            if (useMetricUnits)
                              _InputField(
                                controller: _heightController,
                                label: AppTranslations.get('height', currentLang),
                                hint: 'cm',
                                icon: Icons.straighten_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return currentLang == AppLanguage.vi ? 'Vui lòng nhập chiều cao' : 'Please enter your height';
                                  }
                                  final height = double.tryParse(
                                    value.trim().replaceAll(',', '.'),
                                  );
                                  if (height == null ||
                                      height < 100 ||
                                      height > 250) {
                                    return currentLang == AppLanguage.vi ? 'Chiều cao phải từ 100-250 cm' : 'Height must be between 100-250 cm';
                                  }
                                  return null;
                                },
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _InputField(
                                      controller: _heightFeetController,
                                      label: 'Feet',
                                      hint: 'ft',
                                      icon: Icons.height_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        final feet = int.tryParse(value?.trim() ?? '');
                                        if (feet == null ||
                                            feet < 3 ||
                                            feet > 8) {
                                          return '3-8 ft';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InputField(
                                      controller: _heightInchesController,
                                      label: 'Inches',
                                      hint: 'in',
                                      icon: Icons.straighten_rounded,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      validator: (value) {
                                        final inches = double.tryParse(
                                          (value ?? '').trim().replaceAll(',', '.'),
                                        );
                                        if (inches == null ||
                                            inches < 0 ||
                                            inches >= 12) {
                                          return '0-11.9 in';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: KineticTokens.spaceSM),
                            _InputField(
                              controller: _ageController,
                              label: AppTranslations.get('age', currentLang),
                              hint: AppTranslations.get('years_old', currentLang),
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return currentLang == AppLanguage.vi ? 'Vui lòng nhập tuổi' : 'Please enter your age';
                                }
                                final age = int.tryParse(value);
                                if (age == null || age < 10 || age > 120) {
                                  return currentLang == AppLanguage.vi ? 'Tuổi phải từ 10-120' : 'Age must be between 10-120 years';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: KineticTokens.spaceLG),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppTranslations.get('gender', currentLang),
                                style: KineticTypography.bodyMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: KineticTokens.spaceXS),
                            Row(
                              children: [
                                Expanded(
                                  child: _GenderOption(
                                    label: AppTranslations.get('male', currentLang),
                                    value: 'male',
                                    groupValue: _selectedGender,
                                    onTap: () => setState(
                                      () => _selectedGender = 'male',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GenderOption(
                                    label: AppTranslations.get('female', currentLang),
                                    value: 'female',
                                    groupValue: _selectedGender,
                                    onTap: () => setState(
                                      () => _selectedGender = 'female',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KineticTokens.spaceXL),
                      KineticButton(
                        label: currentLang == AppLanguage.vi
                            ? (isEditing ? 'CẬP NHẬT HỒ SƠ' : 'LƯU HỒ SƠ')
                            : (isEditing ? 'UPDATE PROFILE' : 'SAVE PROFILE'),
                        icon: Icons.arrow_forward_rounded,
                        variant: KineticButtonVariant.primary,
                        height: KineticTokens.buttonHeightPrimary,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.useMetricUnits,
    required this.onChanged,
    this.currentLang,
  });

  final bool useMetricUnits;
  final ValueChanged<bool> onChanged;
  final AppLanguage? currentLang;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            isVi ? 'ĐƠN VỊ ĐO ƯA THÍCH' : 'PREFERRED UNITS',
            style: KineticTypography.unitLabel.copyWith(
              color: colors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.all(KineticTokens.spaceXXS),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
            border: Border.all(
              color: colors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _UnitOption(
                  label: isVi ? 'HỆ MÉT' : 'METRIC',
                  detail: 'kg / cm',
                  selected: useMetricUnits,
                  onTap: () => onChanged(true),
                ),
              ),
              Expanded(
                child: _UnitOption(
                  label: isVi ? 'HỆ ANH' : 'IMPERIAL',
                  detail: 'lb / ft',
                  selected: !useMetricUnits,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitOption extends StatelessWidget {
  const _UnitOption({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KineticTokens.motionTab,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: KineticTypography.unitLabel.copyWith(
                color: selected ? colors.primary : colors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              detail,
              style: KineticTypography.caption.copyWith(
                color: selected ? colors.textPrimary : colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: KineticTypography.bodyMedium.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textMuted,
        ),
        hintStyle: KineticTypography.bodyMedium.copyWith(
          color: colors.textMuted.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(icon, color: colors.primary, size: 20),
        filled: true,
        fillColor: colors.surface1,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          borderSide: BorderSide(color: colors.error, width: 1.4),
        ),
      ),
      validator: validator,
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final selected = value == groupValue;
    final activeColor = value == 'male' ? colors.primary : colors.secondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KineticTokens.motionTab,
        padding: const EdgeInsets.symmetric(
          horizontal: KineticTokens.spaceSM,
          vertical: KineticTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : colors.surface2,
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          border: Border.all(
            color: selected ? activeColor : colors.borderSubtle,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value == 'male' ? Icons.male_rounded : Icons.female_rounded,
              color: selected ? activeColor : colors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: KineticTypography.bodyMedium.copyWith(
                color: selected ? colors.textPrimary : colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}
