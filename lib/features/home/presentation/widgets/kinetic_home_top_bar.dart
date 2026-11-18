import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class KineticHomeTopBar extends StatelessWidget {
  final ImageProvider? avatarImage;
  final String? initials;
  final String displayName;
  final String greeting;
  final int streakCount;
  final bool isVi;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onStreakTap;
  final VoidCallback? onNotificationTap;

  const KineticHomeTopBar({
    super.key,
    this.avatarImage,
    this.initials,
    required this.displayName,
    required this.greeting,
    required this.streakCount,
    this.isVi = true,
    this.onAvatarTap,
    this.onStreakTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final safeInitials = (initials != null && initials!.trim().isNotEmpty)
        ? initials!.trim()
        : (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        KineticTokens.spaceSM,
        KineticTokens.page,
        KineticTokens.spaceSM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              isVi ? 'Hôm nay' : 'Today',
              style: KineticTypography.pageTitle.copyWith(
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: KineticTokens.spaceXS),

          // Streak Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStreakTap,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.flame,
                      color: colors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isVi
                          ? '$streakCount ngày'
                          : '$streakCount ${streakCount == 1 ? "day" : "days"}',
                      style: KineticTypography.label.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KineticTokens.spaceXS),

          // Notification icon
          Semantics(
            button: true,
            label: isVi ? 'Thông báo' : 'Notifications',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNotificationTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle, width: 0.8),
                  ),
                  child: Icon(
                    LucideIcons.bell,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: KineticTokens.spaceXS),

          // User Avatar
          Semantics(
            button: true,
            label: displayName,
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  image: avatarImage != null
                      ? DecorationImage(
                          image: avatarImage!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: avatarImage == null
                    ? Text(
                        safeInitials,
                        style: KineticTypography.label.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
