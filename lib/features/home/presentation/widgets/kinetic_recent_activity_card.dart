import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
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
                  style: KineticTypography.sectionTitle.copyWith(
                    color: colors.textPrimary,
                  ),
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
                            style: KineticTypography.label.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),

          if (workouts.isEmpty)
            KineticCard(
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
    final distanceNumber = (useMetricUnits
            ? effectiveDistanceKm
            : WorkoutFormatters.kmToMi(effectiveDistanceKm))
        .toStringAsFixed(2);
    final distanceUnit = useMetricUnits ? 'km' : 'mi';

    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(workout.durationSec);

    final String secondaryValue;
    final String secondaryLabel;
    if (isCycling) {
      final spd = useMetricUnits
          ? workout.avgSpeedKmh
          : workout.avgSpeedKmh * 0.621371;
      secondaryValue = spd > 0 ? '${spd.toStringAsFixed(1)} ' : '--';
      secondaryLabel = useMetricUnits ? 'km/h' : 'mph';
    } else {
      secondaryValue = workout.avgSpeedKmh > 0
          ? WorkoutFormatters.formatPaceFromSpeedKmh(
              workout.avgSpeedKmh,
              useMetric: useMetricUnits,
            )
          : '--';
      secondaryLabel = '/$distanceUnit';
    }

    final IconData activityIcon = switch (workout.activityType.toLowerCase()) {
      'cycling' || 'bike' => Icons.directions_bike_rounded,
      'walking' || 'walk' => Icons.directions_walk_rounded,
      _ => Icons.directions_run_rounded,
    };

    final String title = isVi
        ? switch (workout.activityType.toLowerCase()) {
            'cycling' || 'bike' => 'Buổi đạp xe',
            'running' || 'run' => 'Buổi chạy bộ',
            'walking' || 'walk' => 'Buổi đi bộ',
            _ => 'Buổi tập',
          }
        : '${workout.activityType[0].toUpperCase()}${workout.activityType.substring(1)}';

    final localTime = workout.startedAt.toLocal();
    final now = DateTime.now();
    final isToday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
    final timeFormatted =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final subtitle = isToday
        ? (isVi ? 'Hôm nay · $timeFormatted' : 'Today · $timeFormatted')
        : '${localTime.day.toString().padLeft(2, '0')}/${localTime.month.toString().padLeft(2, '0')} · $timeFormatted';

    final routeAsync = ref.watch(workoutRoutePresentationProvider(workout.id));
    final routePresentation = routeAsync.valueOrNull;
    final routePoints = routePresentation?.routePoints ?? const [];
    final routeSegments = routePresentation?.routeSegments ?? const [];

    return KineticCard(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      borderRadius: KineticTokens.radiusLG,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(activityIcon, color: colors.primary, size: 19),
              ),
              const SizedBox(width: KineticTokens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title · $subtitle',
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevron_right,
                color: colors.textMuted,
                size: 18,
              ),
            ],
          ),

          // 2. Route Map Preview (when GPS points exist)
          if (routePoints.length >= 2) ...[
            const SizedBox(height: KineticTokens.spaceSM),
            ClipRRect(
              borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: WorkoutRoutePreviewMap(
                  routePoints: routePoints,
                  routeSegments: routeSegments,
                  activityType: workout.activityType,
                  icon: activityIcon,
                  accentColor: colors.accentFill,
                  glowColor: colors.accentFill.withValues(alpha: 0.25),
                  highlightColor: colors.primaryTint,
                  startColor: colors.success,
                  endColor: colors.accentFill,
                  interactive: false,
                  showMapTiles: showMapTiles,
                  mapPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
          ],
          const SizedBox(height: KineticTokens.spaceMD),

          // 3. Strava-style 3-Column Metrics Strip
          Row(
            children: [
              Expanded(
                child: _RecentMetricCell(
                  value: distanceNumber,
                  unit: distanceUnit,
                  label: isVi ? 'Quãng đường' : 'Distance',
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: colors.borderSubtle,
              ),
              Expanded(
                child: _RecentMetricCell(
                  value: secondaryValue.trim(),
                  unit: isCycling
                      ? (secondaryValue == '--' ? '' : secondaryLabel)
                      : '',
                  label: isCycling
                      ? (isVi ? 'Tốc độ TB' : 'Avg speed')
                      : (isVi ? 'Pace TB' : 'Avg pace'),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: colors.borderSubtle,
              ),
              Expanded(
                child: _RecentMetricCell(
                  value: durationStr,
                  unit: '',
                  label: isVi ? 'Thời gian' : 'Duration',
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
  final String unit;
  final String label;

  const _RecentMetricCell({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: KineticTypography.metricSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KineticTypography.caption.copyWith(
              color: colors.textMuted,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
