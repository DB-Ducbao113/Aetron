import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
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

  String _formatDateEyebrow(DateTime date, bool isVi) {
    const weekdaysVi = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    const weekdaysEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekdayName = isVi
        ? weekdaysVi[date.weekday - 1]
        : weekdaysEn[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$weekdayName · $day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bool isSmallPhone = screenWidth < 375;

    final double titleFontSize = isSmallPhone ? 26.0 : 28.0;
    final double eyebrowFontSize = isSmallPhone ? 10.8 : 11.5;
    final double actionButtonSize = isSmallPhone ? 38.0 : 40.0;
    final double actionIconSize = isSmallPhone ? 18.0 : 19.0;
    final double avatarRadius = isSmallPhone ? 19.0 : 20.0;
    final double topPad = isSmallPhone ? 10.0 : 12.0;
    final double bottomPad = isSmallPhone ? 11.0 : 13.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDateEyebrow(DateTime.now(), isVi),
                  style: KineticTypography.tabEyebrowOf(colors).copyWith(
                    fontSize: eyebrowFontSize,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    greeting.isNotEmpty
                        ? greeting
                        : (isVi ? 'Chào buổi sáng.' : 'Good morning.'),
                    style: KineticTypography.tabTitleOf(colors).copyWith(
                      fontSize: titleFontSize,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Streak Pill (Liquid Glass Pill)
          if (streakCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onStreakTap,
                      borderRadius: BorderRadius.circular(
                        KineticTokens.radiusPill,
                      ),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: colors.isDark
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0x33CAE9FF),
                                    Color(0x24314B6B),
                                    Color(0x2B1A4781),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xCCFFFFFF),
                                    Color(0x80FFFFFF),
                                    Color(0x384EABE7),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusPill,
                          ),
                          border: Border.all(
                            color: colors.isDark
                                ? const Color(0x4DB6DCFF)
                                : Colors.white.withValues(alpha: .85),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.isDark
                                  ? Colors.black.withValues(alpha: 0.20)
                                  : const Color(
                                      0xFF1F406E,
                                    ).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseFlameIcon(
                              color: colors.primary,
                              size: 13.5,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVi
                                  ? '$streakCount ngày'
                                  : '$streakCount ${streakCount == 1 ? "day" : "days"}',
                              style: KineticTypography.caption.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Actions: Bell Orb + User Orb matching HTML prototype
          KineticGlassIconButton(
            label: isVi ? 'Thông báo' : 'Notifications',
            size: actionButtonSize,
            visualSize: actionButtonSize,
            onPressed: onNotificationTap ?? () {},
            icon: BladeIcon(
              BladeIconName.bell,
              size: actionIconSize,
              color: colors.isDark
                  ? const Color(0xFFD5E8FA)
                  : colors.textPrimary,
              strokeWidth: 1.7,
            ),
          ),
          const SizedBox(width: 7),

          // User Avatar / Profile Action
          if (avatarImage != null)
            Semantics(
              button: true,
              label: displayName,
              child: GestureDetector(
                onTap: onAvatarTap,
                child: KineticTouchFinish(
                  radius: avatarRadius,
                  enabled: onAvatarTap != null,
                  child: Container(
                    width: avatarRadius * 2,
                    height: avatarRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      image: DecorationImage(
                        image: avatarImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            KineticGlassIconButton(
              label: displayName,
              size: actionButtonSize,
              visualSize: actionButtonSize,
              onPressed: onAvatarTap ?? () {},
              icon: BladeIcon(
                BladeIconName.user,
                size: actionIconSize,
                color: colors.isDark
                    ? const Color(0xFFD5E8FA)
                    : colors.textPrimary,
                strokeWidth: 1.7,
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseFlameIcon extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseFlameIcon({required this.color, required this.size});

  @override
  State<_PulseFlameIcon> createState() => _PulseFlameIconState();
}

class _PulseFlameIconState extends State<_PulseFlameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (KineticTokens.reduceMotionOf(context) ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return BladeIcon(
        BladeIconName.flame,
        color: widget.color,
        size: widget.size,
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: BladeIcon(
        BladeIconName.flame,
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}
