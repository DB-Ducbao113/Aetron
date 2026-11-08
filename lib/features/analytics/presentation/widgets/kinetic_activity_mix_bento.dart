import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticActivityMixBento extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final bool useMetricUnits;
  final bool isVi;

  const KineticActivityMixBento({
    super.key,
    required this.workouts,
    required this.useMetricUnits,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    // Aggregate by the 3 core disciplines
    double cyclingKm = 0.0;
    double runningKm = 0.0;
    double walkingKm = 0.0;
    int totalActiveSeconds = 0;

    int cyclingSessions = 0;
    int runningSessions = 0;
    int walkingSessions = 0;

    for (final w in workouts) {
      totalActiveSeconds += w.durationSec;
      switch (w.activityType.toLowerCase()) {
        case 'cycling':
          cyclingKm += w.distanceKm;
          cyclingSessions++;
          break;
        case 'running':
          runningKm += w.distanceKm;
          runningSessions++;
          break;
        case 'walking':
          walkingKm += w.distanceKm;
          walkingSessions++;
          break;
        default:
          runningKm += w.distanceKm;
          runningSessions++;
          break;
      }
    }

    final double totalKm = cyclingKm + runningKm + walkingKm;
    final double cyclingPct =
        totalKm > 0 ? (cyclingKm / totalKm) * 100 : 0.0;
    final double runningPct =
        totalKm > 0 ? (runningKm / totalKm) * 100 : 0.0;
    final double walkingPct =
        totalKm > 0 ? (walkingKm / totalKm) * 100 : 0.0;

    final unit = WorkoutFormatters.distanceUnitLabel(useMetric: useMetricUnits);
    final cyclingDist = useMetricUnits
        ? cyclingKm
        : WorkoutFormatters.kmToMi(cyclingKm);
    final runningDist = useMetricUnits
        ? runningKm
        : WorkoutFormatters.kmToMi(runningKm);
    final walkingDist = useMetricUnits
        ? walkingKm
        : WorkoutFormatters.kmToMi(walkingKm);

    final durationFormatted = totalActiveSeconds > 0
        ? WorkoutFormatters.formatDurationFromSeconds(totalActiveSeconds)
        : '00:00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'CƠ CẤU MÔN TẬP' : 'DISCIPLINE BREAKDOWN',
                    style: KineticTypography.headlineSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVi
                        ? 'Phân bổ thể thao sức bền đa môn'
                        : 'Endurance multi-sport volume share',
                    style: KineticTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  durationFormatted,
                  style: KineticTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                    fontFeatures: KineticTypography.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // Continuous Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
            child: Container(
              height: 10,
              width: double.infinity,
              color: colors.surface3,
              child: Row(
                children: [
                  if (cyclingPct > 0)
                    Expanded(
                      flex: cyclingPct.round().clamp(1, 100),
                      child: Container(
                        color: colors.primary,
                      ),
                    ),
                  if (runningPct > 0)
                    Expanded(
                      flex: runningPct.round().clamp(1, 100),
                      child: Container(
                        color: colors.secondary,
                      ),
                    ),
                  if (walkingPct > 0)
                    Expanded(
                      flex: walkingPct.round().clamp(1, 100),
                      child: Container(
                        color: colors.tertiary,
                      ),
                    ),
                  if (totalKm <= 0)
                    Expanded(
                      child: Container(color: colors.surface3),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KineticTokens.spaceMD),

          // 3 Sport Cards Grid
          Row(
            children: [
              // Cycling
              Expanded(
                child: _SportTile(
                  name: isVi ? 'Đạp xe' : 'Cycling',
                  pct: '${cyclingPct.round()}%',
                  distance: '${cyclingDist.toStringAsFixed(1)} $unit',
                  dotColor: colors.primary,
                  icon: Icons.directions_bike_rounded,
                  sessions: cyclingSessions,
                  isVi: isVi,
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),

              // Running
              Expanded(
                child: _SportTile(
                  name: isVi ? 'Chạy bộ' : 'Running',
                  pct: '${runningPct.round()}%',
                  distance: '${runningDist.toStringAsFixed(1)} $unit',
                  dotColor: colors.secondary,
                  icon: Icons.directions_run_rounded,
                  sessions: runningSessions,
                  isVi: isVi,
                ),
              ),
              const SizedBox(width: KineticTokens.spaceXS),

              // Walking
              Expanded(
                child: _SportTile(
                  name: isVi ? 'Đi bộ' : 'Walking',
                  pct: '${walkingPct.round()}%',
                  distance: '${walkingDist.toStringAsFixed(1)} $unit',
                  dotColor: colors.tertiary,
                  icon: Icons.directions_walk_rounded,
                  sessions: walkingSessions,
                  isVi: isVi,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  final String name;
  final String pct;
  final String distance;
  final Color dotColor;
  final IconData icon;
  final int sessions;
  final bool isVi;

  const _SportTile({
    required this.name,
    required this.pct,
    required this.distance,
    required this.dotColor,
    required this.icon,
    required this.sessions,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceSM),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: KineticTokens.spaceXXS),
                  Text(
                    name,
                    style: KineticTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Icon(icon, size: 14, color: dotColor),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          Text(
            pct,
            style: KineticTypography.pageTitleCompact.copyWith(
              color: dotColor,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            distance,
            style: KineticTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
