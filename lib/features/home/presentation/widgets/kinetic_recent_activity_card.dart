import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KineticRecentActivityCard extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final bool useMetricUnits;
  final bool isVi;
  final VoidCallback onSeeAllTap;
  final ValueChanged<String> onWorkoutTap;
  final VoidCallback onStartFirstWorkoutTap;
  final bool showMapTiles;

  const KineticRecentActivityCard({
    super.key,
    required this.workouts,
    required this.useMetricUnits,
    this.isVi = true,
    required this.onSeeAllTap,
    required this.onWorkoutTap,
    required this.onStartFirstWorkoutTap,
    this.showMapTiles = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: KineticTokens.spaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (Sentence case)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Hoạt động gần đây' : 'Recent activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.sectionTitleOf(colors),
                ),
              ),
              if (workouts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSeeAllTap,
                    borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'Xem tất cả' : 'See all',
                            style: KineticTypography.linkActionOf(colors),
                          ),
                          const SizedBox(width: 2),
                          BladeIcon(
                            BladeIconName.chevR,
                            size: 15,
                            color: colors.isDark
                                ? const Color(0xFF9BC5FF)
                                : colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          if (workouts.isEmpty)
            KineticCard(
              useLiquidGlass: true,
              borderRadius: 21,
              padding: const EdgeInsets.all(KineticTokens.spaceXL),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_run_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceSM),
                  Text(
                    isVi ? 'Chưa có buổi tập nào' : 'No recent activities',
                    style: KineticTypography.headlineSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceXXS),
                  Text(
                    isVi
                        ? 'Bắt đầu buổi tập đầu tiên để lưu lộ trình và theo dõi tiến độ mỗi tuần.'
                        : 'Record your first workout to view routes and track your weekly progress.',
                    textAlign: TextAlign.center,
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: KineticTokens.spaceMD),
                  KineticButton(
                    label: isVi ? 'Bắt đầu tập ngay' : 'Start first workout',
                    icon: LucideIcons.play,
                    isFullWidth: false,
                    onPressed: onStartFirstWorkoutTap,
                  ),
                ],
              ),
            )
          else
            _RecentWorkoutItem(
              workout: workouts.first,
              useMetricUnits: useMetricUnits,
              isVi: isVi,
              showMapTiles: showMapTiles,
              onTap: () => onWorkoutTap(workouts.first.id),
            ),
        ],
      ),
    );
  }
}

class _RecentWorkoutItem extends ConsumerWidget {
  final WorkoutSession workout;
  final bool useMetricUnits;
  final bool isVi;
  final bool showMapTiles;
  final VoidCallback onTap;

  const _RecentWorkoutItem({
    required this.workout,
    required this.useMetricUnits,
    required this.isVi,
    required this.showMapTiles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final isCycling = workout.activityType.toLowerCase() == 'cycling';

    final effectiveDistanceKm = workout.gpsAnalysis.validDistanceKm > 0
        ? workout.gpsAnalysis.validDistanceKm
        : workout.distanceKm;
    final distanceNumber =
        (useMetricUnits
                ? effectiveDistanceKm
                : WorkoutFormatters.kmToMi(effectiveDistanceKm))
            .toStringAsFixed(2);
    final distanceUnit = useMetricUnits ? 'km' : 'mi';

    final durationStr = WorkoutFormatters.formatElapsedClock(
      workout.durationSec,
    );

    final String secondaryValue;
    if (isCycling) {
      final spd = useMetricUnits
          ? workout.avgSpeedKmh
          : workout.avgSpeedKmh * 0.621371;
      secondaryValue = spd > 0 ? spd.toStringAsFixed(1) : '--';
    } else if (workout.avgSpeedKmh >= 0.1) {
      final effectiveSpeed = useMetricUnits
          ? workout.avgSpeedKmh
          : workout.avgSpeedKmh * 0.6213711922;
      final totalSeconds = (3600 / effectiveSpeed).round();
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      secondaryValue = "$minutes'${seconds.toString().padLeft(2, '0')}”";
    } else {
      secondaryValue = '--';
    }

    final BladeIconName activityBlade = switch (workout.activityType
        .toLowerCase()) {
      'cycling' || 'bike' => BladeIconName.bike,
      'walking' || 'walk' => BladeIconName.walk,
      _ => BladeIconName.run,
    };
    final IconData activityIcon = switch (workout.activityType.toLowerCase()) {
      'cycling' || 'bike' => Icons.directions_bike_rounded,
      'walking' || 'walk' => Icons.directions_walk_rounded,
      _ => Icons.directions_run_rounded,
    };

    final String title = isVi
        ? switch (workout.activityType.toLowerCase()) {
            'cycling' || 'bike' => 'Đạp xe ngoài trời',
            'running' || 'run' => 'Chạy bộ ngoài trời',
            'walking' || 'walk' => 'Đi bộ ngoài trời',
            _ => 'Buổi tập',
          }
        : switch (workout.activityType.toLowerCase()) {
            'cycling' || 'bike' => 'Outdoor cycling',
            'running' || 'run' => 'Outdoor run',
            'walking' || 'walk' => 'Outdoor walk',
            _ =>
              '${workout.activityType[0].toUpperCase()}${workout.activityType.substring(1)}',
          };

    final localTime = workout.startedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDay = DateTime(localTime.year, localTime.month, localTime.day);
    final dayDiff = today.difference(workoutDay).inDays;
    final timeFormatted =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final subtitle = dayDiff == 0
        ? (isVi ? 'Hôm nay, $timeFormatted' : 'Today, $timeFormatted')
        : dayDiff == 1
        ? (isVi ? 'Hôm qua, $timeFormatted' : 'Yesterday, $timeFormatted')
        : '${localTime.day.toString().padLeft(2, '0')}/${localTime.month.toString().padLeft(2, '0')}, $timeFormatted';

    final routeAsync = ref.watch(workoutRoutePresentationProvider(workout.id));
    final routePresentation = routeAsync.valueOrNull;
    final routePoints = routePresentation?.routePoints ?? const [];
    final routeSegments = routePresentation?.routeSegments ?? const [];

    return KineticCard(
      useLiquidGlass: true,
      padding: const EdgeInsets.all(17),
      borderRadius: 21,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: colors.isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x33CAE9FF),
                            Color(0x2E314B6B),
                            Color(0x2E1A4781),
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xB8FFFFFF),
                            Color(0x66FFFFFF),
                            Color(0x334EABE7),
                          ],
                        ),
                  border: Border.all(
                    color: colors.isDark
                        ? const Color(0x47B6DCFF)
                        : Colors.white.withValues(alpha: 0.92),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark
                          ? const Color(0x33000000)
                          : const Color(0x1C1F406E),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: BladeIcon(
                    activityBlade,
                    color: colors.isDark
                        ? const Color(0xFFD5E8FA)
                        : colors.textPrimary,
                    size: 16,
                    strokeWidth: 1.7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KineticTypography.caption.copyWith(
                        color: colors.isDark
                            ? const Color(0xFFA6B6C9)
                            : colors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              BladeIcon(
                BladeIconName.arrow,
                color: colors.textMuted,
                size: 15,
                strokeWidth: 1.7,
              ),
            ],
          ),

          // 2. Route Map Preview (when GPS points exist)
          if (routePoints.length >= 2) ...[
            const SizedBox(height: 12),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.isDark
                      ? const Color(0x5985C4F4)
                      : const Color(0x999ACFF7),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.isDark
                        ? const Color(0x29000000)
                        : const Color(0x142A649D),
                    blurRadius: 13,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    WorkoutRoutePreviewMap(
                      routePoints: routePoints,
                      routeSegments: routeSegments,
                      activityType: workout.activityType,
                      icon: activityIcon,
                      accentColor: colors.isDark
                          ? const Color(0xFF75BBFF)
                          : const Color(0xFF1C7AE8),
                      glowColor: colors.accentFill.withValues(alpha: 0.25),
                      highlightColor: colors.primaryTint,
                      startColor: colors.success,
                      endColor: colors.isDark
                          ? const Color(0xFF77BBFF)
                          : const Color(0xFF1675DE),
                      interactive: false,
                      showMapTiles: showMapTiles,
                      fallbackMapType: AppMapType.streets,
                      mapPadding: const EdgeInsets.all(18),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colors.isDark
                                  ? const Color(0x21BBDFFB)
                                  : Colors.white.withValues(alpha: 0.22),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 13),

          // 3. Left-Aligned 3-Column Metrics Row (No vertical divider lines)
          Row(
            children: [
              Expanded(
                child: _RecentMetricCell(
                  value: distanceNumber,
                  label: distanceUnit.toUpperCase(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecentMetricCell(
                  value: durationStr,
                  label: isVi ? 'THỜI GIAN' : 'DURATION',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecentMetricCell(
                  value: secondaryValue.trim(),
                  label: isCycling
                      ? (useMetricUnits ? 'KM/H' : 'MPH')
                      : 'PACE',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentMetricCell extends StatelessWidget {
  final String value;
  final String label;

  const _RecentMetricCell({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: KineticTypography.metricSmall.copyWith(
              color: colors.isDark
                  ? const Color(0xFFEFF6FF)
                  : colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: KineticTypography.caption.copyWith(
            color: colors.isDark
                ? const Color(0xFF94AAC2)
                : colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
