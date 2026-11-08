import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_backdrop.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KineticAthleteCard extends ConsumerWidget {
  final User? user;
  final UserProfile? profile;
  final AvatarState avatarState;
  final int currentStreak;
  final VoidCallback onCameraTap;
  final AppLanguage currentLang;

  const KineticAthleteCard({
    super.key,
    required this.user,
    required this.profile,
    required this.avatarState,
    required this.currentStreak,
    required this.onCameraTap,
    required this.currentLang,
  });

  String _getAthleteDisplayName() {
    final userMetadata = user?.userMetadata;
    final metaName = (userMetadata?['display_name'] ??
            userMetadata?['full_name'] ??
            userMetadata?['name'])
        ?.toString()
        .trim();
    if (metaName != null && metaName.isNotEmpty) return metaName;

    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return currentLang == AppLanguage.vi ? 'Thành viên Aetron' : 'Aetron Member';
  }

  String _formatMemberSince() {
    final rawDate = profile?.createdAt ??
        (user?.createdAt != null ? DateTime.tryParse(user!.createdAt) : null);
    if (rawDate == null) return '--';

    final local = rawDate.toLocal();
    return currentLang == AppLanguage.vi
        ? '${local.month.toString().padLeft(2, '0')}/${local.year}'
        : DateFormat('MMM yyyy').format(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final avatarDisplay = ref.watch(currentAvatarDisplayProvider);
    final ImageProvider? imageProvider = avatarDisplay.imageProvider;
    final displayName = _getAthleteDisplayName();
    final memberSince = _formatMemberSince();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        child: Stack(
          children: [
            const Positioned.fill(child: TopographicBackdrop()),
            Padding(
              padding: const EdgeInsets.all(KineticTokens.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Stack (Left-aligned)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface2,
                      border: Border.all(color: colors.primary, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface1,
                          image: imageProvider != null
                              ? DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageProvider == null
                            ? Icon(Icons.person_rounded, size: 36, color: colors.textMuted)
                            : null,
                      ),
                    ),
                  ),

                  // Uploading indicator
                  if (avatarState.isUploading)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Camera action button
                  if (!avatarState.isUploading)
                    Positioned(
                      right: -2,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        label: currentLang == AppLanguage.vi ? 'Đổi ảnh đại diện' : 'Change avatar',
                        child: InkWell(
                          onTap: onCameraTap,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.background, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: colors.onPrimary,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: KineticTokens.spaceMD),

              // Athlete Info (Right-aligned details)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display Name & Edit Button
                    InkWell(
                      onTap: () async {
                        final updated = await showEditDisplayNameSheet(context, currentName: displayName);
                        if (updated == true) {
                          ref.invalidate(currentUserProfileProvider);
                        }
                      },
                        borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: KineticTypography.displayName.copyWith(
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 14, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // Stat row — hairline dividers, existing data only
          Divider(height: 1, thickness: 1, color: colors.borderSubtle),
          const SizedBox(height: KineticTokens.spaceSM),
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: KineticTokens.spaceXS),
                    Text(
                      '$currentStreak',
                      style: KineticTypography.metricSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: KineticTokens.spaceXXS),
                    Flexible(
                      child: Text(
                        currentLang == AppLanguage.vi
                            ? 'NGÀY LIÊN TIẾP'
                            : 'DAY STREAK',
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: colors.borderSubtle,
              ),
              const SizedBox(width: KineticTokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      memberSince,
                      style: KineticTypography.metricSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppTranslations.get('member_since', currentLang),
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (avatarState.errorMessage != null) ...[
            const SizedBox(height: KineticTokens.spaceXS),
            Text(
              avatarState.errorMessage!,
              style: KineticTypography.caption.copyWith(
                color: colors.error,
              ),
            ),
          ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
