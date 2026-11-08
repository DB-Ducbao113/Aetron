import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class KineticSummaryRouteRecap extends StatelessWidget {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final AppLanguage currentLang;

  const KineticSummaryRouteRecap({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    if (routePoints.length < 2) {
      return const SizedBox.shrink();
    }

    final effectiveRouteSegments = routeSegments.isNotEmpty
        ? routeSegments
        : <List<LatLng>>[routePoints];

    return KineticCard(
      padding: EdgeInsets.zero,
      borderRadius: KineticTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header inside card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.map_rounded,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentLang == AppLanguage.vi ? 'BẢN ĐỒ CUNG ĐƯỜNG' : 'ROUTE MAP',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        currentLang == AppLanguage.vi ? 'ĐÃ LÀM MỊN' : 'SMOOTHED',
                        style: KineticTypography.unitLabel.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map Container
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(KineticTokens.radiusLG),
            ),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: WorkoutRoutePreviewMap(
                routePoints: routePoints,
                routeSegments: effectiveRouteSegments,
                activityType: activityType,
                icon: Icons.directions_run_rounded,
                accentColor: colors.primary,
                glowColor: colors.primary.withValues(alpha: 0.3),
                highlightColor: colors.secondary,
                startColor: colors.primary,
                endColor: colors.error,
                badgeText: activityType.toUpperCase(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
