import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class KineticAvatarSourceSheet extends ConsumerWidget {
  final bool hasAvatar;
  final AppLanguage currentLang;

  const KineticAvatarSourceSheet({
    super.key,
    required this.hasAvatar,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;

    return KineticGlassBottomSheet(
      floating: true,
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.spaceMD,
        KineticTokens.spaceSM,
        KineticTokens.spaceMD,
        KineticTokens.spaceLG,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            currentLang == AppLanguage.vi ? 'Ảnh đại diện' : 'Profile avatar',
            style: KineticTypography.unitLabel.copyWith(
              color: colors.primary,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KineticTokens.spaceSM),

          // Pick from Gallery
          KineticGlassOptionTile(
            icon: Icons.photo_library_outlined,
            title: AppTranslations.get('choose_from_gallery', currentLang),
            accentColor: colors.primary,
            onTap: () {
              Navigator.pop(context);
              ref
                  .read(avatarUploadProvider.notifier)
                  .pickAndUpload(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),

          // Take a Photo
          KineticGlassOptionTile(
            icon: Icons.camera_alt_outlined,
            title: AppTranslations.get('take_a_photo', currentLang),
            accentColor: colors.primary,
            onTap: () {
              Navigator.pop(context);
              ref
                  .read(avatarUploadProvider.notifier)
                  .pickAndUpload(ImageSource.camera);
            },
          ),

          // Remove photo if hasAvatar
          if (hasAvatar) ...[
            const SizedBox(height: 8),
            KineticGlassOptionTile(
              icon: Icons.delete_outline_rounded,
              title: AppTranslations.get('remove_current_photo', currentLang),
              isDestructive: true,
              showChevron: false,
              onTap: () {
                Navigator.pop(context);
                ref.read(avatarUploadProvider.notifier).removeAvatar();
              },
            ),
          ],
        ],
      ),
    );
  }
}
