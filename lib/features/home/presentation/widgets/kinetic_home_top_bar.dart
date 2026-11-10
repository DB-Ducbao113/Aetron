import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KineticTokens.page,
        KineticTokens.spaceSM,
        KineticTokens.page,
        KineticTokens.spaceXS,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Streamlined Greeting & Full User Name
          Expanded(
            child: InkWell(
              onTap: onAvatarTap,
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting.endsWith(',') ? greeting : '$greeting,',
                    style: KineticTypography.greeting.copyWith(
                      color: colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: KineticTokens.spaceXXS),
                  Text(
                    displayName,
                    style: KineticTypography.displayName.copyWith(
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KineticTokens.spaceXS),

          // 3. Streak Indicator Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onStreakTap,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KineticTokens.spaceSM,
                  vertical: KineticTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BladeIcon(
                      BladeIconName.flame,
                      color: colors.tertiary,
                      size: 16,
                    ),
                    const SizedBox(width: KineticTokens.spaceXXS),
                    Text(
                      isVi
                          ? '$streakCount ngày'
                          : '$streakCount ${streakCount == 1 ? "day" : "days"}',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KineticTokens.spaceXS),

          // 4. Notification Icon Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface1,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    BladeIcon(
                      BladeIconName.bell,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
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
