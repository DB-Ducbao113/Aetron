import 'package:flutter/cupertino.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticActivityTopBar extends StatelessWidget {
  final bool isVi;
  final bool isOutdoor;
  final bool checkingLocation;
  final bool hasLocationPermission;
  final bool gpsEnabled;
  final VoidCallback? onGpsTap;
  final VoidCallback? onMapPreviewTap;

  const KineticActivityTopBar({
    super.key,
    required this.isVi,
    required this.isOutdoor,
    required this.checkingLocation,
    required this.hasLocationPermission,
    required this.gpsEnabled,
    this.onGpsTap,
    this.onMapPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);
    final isGpsReady = hasLocationPermission && gpsEnabled;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Eyebrow + Page Title (Clear & Prominent)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVi ? 'HOẠT ĐỘNG' : 'ACTIVITY',
                  style: KineticTypography.tabEyebrowOf(colors),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isVi ? 'Bắt đầu.' : 'Start.',
                    style: KineticTypography.tabTitleOf(colors),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: GPS Status Pill / Indoor Badge
          if (isOutdoor)
            _buildGpsStatusBadge(context, colors, isGpsReady)
          else
            _buildIndoorBadge(context, colors),
        ],
      ),
    );
  }

  Widget _buildGpsStatusBadge(
    BuildContext context,
    KineticColors colors,
    bool isGpsReady,
  ) {
    if (checkingLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoActivityIndicator(radius: 5, color: colors.primary)
                  : CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.primary,
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              isVi ? 'DÒ GPS' : 'SEARCHING',
              style: KineticTypography.unitLabel.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (isGpsReady) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onMapPreviewTap,
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          child: KineticTouchFinish(
            radius: KineticTokens.radiusPill,
            enabled: onMapPreviewTap != null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  BladeIcon(BladeIconName.gps, size: 14, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    isVi ? 'GPS SẴN SÀNG' : 'GPS READY',
                    style: KineticTypography.unitLabel.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // GPS Disabled / Permission Denied
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onGpsTap,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        child: KineticTouchFinish(
          radius: KineticTokens.radiusPill,
          enabled: onGpsTap != null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
              border: Border.all(color: colors.tertiary.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Theme.of(context).platform == TargetPlatform.iOS
                      ? CupertinoIcons.location_slash
                      : Icons.location_off_rounded,
                  size: 13,
                  color: colors.tertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  isVi ? 'BẬT GPS' : 'ENABLE GPS',
                  style: KineticTypography.unitLabel.copyWith(
                    color: colors.tertiary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndoorBadge(BuildContext context, KineticColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Theme.of(context).platform == TargetPlatform.iOS
                ? CupertinoIcons.house
                : Icons.fitness_center_rounded,
            size: 13,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            isVi ? 'TRONG NHÀ' : 'INDOOR',
            style: KineticTypography.unitLabel.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
