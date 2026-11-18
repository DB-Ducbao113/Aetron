import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_feedback.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows the Cyber Display Name edit modal bottom sheet
Future<bool?> showEditDisplayNameSheet(
  BuildContext context, {
  String? currentName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => EditDisplayNameSheet(initialName: currentName),
  );
}

class EditDisplayNameSheet extends ConsumerStatefulWidget {
  final String? initialName;

  const EditDisplayNameSheet({super.key, this.initialName});

  @override
  ConsumerState<EditDisplayNameSheet> createState() =>
      _EditDisplayNameSheetState();
}

class _EditDisplayNameSheetState extends ConsumerState<EditDisplayNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String fallbackName = '';
    try {
      final user = Supabase.instance.client.auth.currentUser;
      fallbackName = user?.userMetadata?['display_name'] as String? ??
          user?.userMetadata?['full_name'] as String? ??
          user?.userMetadata?['name'] as String? ??
          '';
    } catch (_) {
      // Supabase instance might not be initialized in test environments
    }
    _nameController = TextEditingController(
      text: widget.initialName?.trim() ?? fallbackName.trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    final lang = ref.read(appLanguageProvider);
    final newName = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        showAetronNotice(
          context,
          message: AppTranslations.get('name_updated_success', lang),
          tone: AetronNoticeTone.success,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = lang == AppLanguage.vi
              ? 'Không thể lưu tên gọi. Vui lòng thử lại.'
              : 'Could not update display name. Try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceXS,
        vertical: KineticTokens.spaceSM,
      ),
      padding: EdgeInsets.fromLTRB(
        KineticTokens.spaceLG,
        KineticTokens.spaceMD,
        KineticTokens.spaceLG,
        KineticTokens.spaceXL + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Grab Handle
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: KineticTokens.spaceLG),

            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: KineticTokens.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('edit_display_name', currentLang),
                        style: KineticTypography.pageTitleCompact.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi
                            ? 'Tên này sẽ hiển thị trên trang chủ và bảng xếp hạng'
                            : 'This name will appear on home and leaderboards',
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KineticTokens.spaceLG),

            // Input Field
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              style: KineticTypography.bodyLarge.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: AppTranslations.get('display_name', currentLang),
                labelStyle: KineticTypography.label.copyWith(
                  color: colors.primary,
                ),
                hintText: AppTranslations.get('display_name_hint', currentLang),
                hintStyle: KineticTypography.bodyMedium.copyWith(
                  color: colors.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: colors.textSecondary,
                        onPressed: () {
                          setState(() {
                            _nameController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surface2,
                counterStyle: KineticTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceMD,
                  vertical: KineticTokens.spaceSM,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  borderSide: BorderSide(
                    color: colors.borderSubtle,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  borderSide: BorderSide(
                    color: colors.error,
                    width: 1.2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                  borderSide: BorderSide(
                    color: colors.error,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return AppTranslations.get(
                    'display_name_empty',
                    currentLang,
                  );
                }
                if (trimmed.length < 2) {
                  return isVi
                      ? 'Tên hiển thị phải có ít nhất 2 ký tự'
                      : 'Display name must have at least 2 characters';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: KineticTokens.spaceXS),
              Container(
                padding: const EdgeInsets.all(KineticTokens.spaceXS),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: KineticTokens.spaceLG),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: KineticButton(
                    label: AppTranslations.get('cancel', currentLang),
                    variant: KineticButtonVariant.secondary,
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: KineticTokens.spaceSM),
                Expanded(
                  flex: 2,
                  child: KineticButton(
                    label: AppTranslations.get('save_changes', currentLang),
                    icon: Icons.check_rounded,
                    variant: KineticButtonVariant.primary,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveName,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
