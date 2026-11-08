import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticActivityCockpit extends StatelessWidget {
  final String activityName;
  final bool isOutdoor;
  final bool gpsEnabled;
  final bool checkingLocation;
  final bool hasLocationPermission;
  final double? gpsAccuracyM;
  final WorkoutTarget? selectedTarget;
  final bool isVi;
  final VoidCallback onRefreshGps;
  final VoidCallback? onTargetCustomizeTap;
  final ValueChanged<WorkoutTarget>? onTargetChanged;
  final VoidCallback onStartTap;
  final VoidCallback? onMapPreviewTap;

  const KineticActivityCockpit({
    super.key,
    required this.activityName,
    this.isOutdoor = true,
    required this.gpsEnabled,
    required this.checkingLocation,
    required this.hasLocationPermission,
    this.gpsAccuracyM,
    this.selectedTarget,
    required this.isVi,
    required this.onRefreshGps,
    this.onTargetCustomizeTap,
    this.onTargetChanged,
    required this.onStartTap,
    this.onMapPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isGpsReady = gpsEnabled && hasLocationPermission;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderSubtle,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Telemetry Sensor Status Row (Always GPS outdoor ready)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius:
                            BorderRadius.circular(KineticTokens.radiusSM),
                        border: Border.all(
                          color: colors.borderSubtle.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.satellite_alt_rounded,
                        size: 17,
                        color: isGpsReady ? colors.primary : colors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isGpsReady
                                  ? (isVi ? 'GPS sẵn sàng' : 'GPS Ready')
                                  : (isVi
                                      ? 'Chờ tín hiệu GPS'
                                      : 'Waiting for GPS'),
                              style: KineticTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Refresh / Map peek actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMapPreviewTap != null) ...[
                    IconButton(
                      tooltip: isVi ? 'Xem bản đồ' : 'Map Preview',
                      icon: Icon(
                        Icons.map_outlined,
                        size: 19,
                        color: colors.textSecondary,
                      ),
                      onPressed: onMapPreviewTap,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: isVi ? 'Làm mới tín hiệu' : 'Refresh signal',
                    icon: checkingLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 19,
                            color: colors.textSecondary,
                          ),
                    onPressed: checkingLocation ? null : onRefreshGps,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Primary CTA Start Button
          KineticButton(
            label: isVi
                ? 'BẮT ĐẦU ${activityName.toUpperCase()}'
                : 'START ${activityName.toUpperCase()}',
            icon: Icons.play_arrow_rounded,
            height: KineticTokens.buttonHeightPrimary,
            onPressed: onStartTap,
          ),
        ],
      ),
    );
  }
}
