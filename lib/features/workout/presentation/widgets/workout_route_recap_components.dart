import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/activity_consistency_feedback.dart';
import 'package:fitness_exercise_application/features/workout/presentation/utils/route_display_sanitizer.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WorkoutValidityBadge extends StatelessWidget {
  const WorkoutValidityBadge({
    super.key,
    required this.flag,
    required this.verifiedColor,
    required this.warningColor,
    required this.dangerColor,
  });

  final WorkoutValidityFlag flag;
  final Color verifiedColor;
  final Color warningColor;
  final Color dangerColor;

  @override
  Widget build(BuildContext context) {
    final color = switch (flag) {
      WorkoutValidityFlag.verified => verifiedColor,
      WorkoutValidityFlag.partial => warningColor,
      WorkoutValidityFlag.unverified => dangerColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        workoutValidityLabel(flag),
        style: KineticTypography.unitLabel.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class WorkoutHeroMetricChip extends StatelessWidget {
  const WorkoutHeroMetricChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: KineticTypography.unitLabel.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: KineticTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontFeatures: KineticTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGlassBadge extends StatelessWidget {
  const _MapGlassBadge({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Brightness-aware glass: dark theme keeps the dark glass badge;
    // light ("Morning") switches to white glass, with callers picking ink
    // text from the same brightness branch.
    final colors = context.kinetic;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.88)
            : KineticColors.dark.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(
          color: isLight
              ? colors.borderSubtle
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class WorkoutRoutePreviewMap extends StatelessWidget {
  const WorkoutRoutePreviewMap({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    required this.icon,
    required this.accentColor,
    required this.glowColor,
    required this.highlightColor,
    required this.startColor,
    required this.endColor,
    this.badgeText,
    this.footerText,
    this.interactive = false,
    this.mapPadding = const EdgeInsets.fromLTRB(6, 10, 6, 16),
    this.showMapTiles = true,
    this.fallbackMapType = AppMapType.satellite,
  });

  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final IconData icon;
  final Color accentColor;
  final Color glowColor;
  final Color highlightColor;
  final Color startColor;
  final Color endColor;
  final String? badgeText;
  final String? footerText;
  final bool interactive;
  final EdgeInsets mapPadding;
  final bool showMapTiles;
  final AppMapType fallbackMapType;

  LatLngBounds _computeBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final latPad = math.max(latSpan * 0.12, 0.00028);
    final lngPad = math.max(lngSpan * 0.12, 0.00028);

    return LatLngBounds(
      LatLng(minLat - latPad, minLng - lngPad),
      LatLng(maxLat + latPad, maxLng + lngPad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final badgeTextColor = isLight ? colors.textPrimary : Colors.white;
    final displayRoute = refineRouteForSavedDisplay(
      routePoints,
      activityType: activityType,
    );
    final displaySegments = refineRouteSegmentsForSavedDisplay(
      routePoints: routePoints,
      routeSegments: routeSegments,
      activityType: activityType,
    );
    final bounds = _computeBounds(displayRoute);

    return AetronMapTypeBuilder(
      fallbackType: fallbackMapType,
      builder: (context, mapType) {
        final routeCasing = (isLight || mapType == AppMapType.satellite)
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.55);

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                backgroundColor: colors.surface2,
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: mapPadding,
                ),
                interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                if (showMapTiles) ...buildAetronMapTileLayers(mapType),
                PolygonLayer(
                  polygons: [
                    for (final segment in displaySegments)
                      if (segment.length >= 3)
                        Polygon(
                          points: segment,
                          color: accentColor.withValues(alpha: 0.08),
                          borderColor: Colors.transparent,
                        ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    for (final segment in displaySegments) ...[
                      Polyline(
                        points: segment,
                        strokeWidth: 8.0,
                        color: routeCasing,
                      ),
                      Polyline(
                        points: segment,
                        strokeWidth: 4.5,
                        color: colors.accentFill,
                      ),
                    ],
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: displayRoute.first,
                      width: 30,
                      height: 30,
                      child: _RouteOrb(
                        color: colors.success,
                        icon: Icons.flag_rounded,
                      ),
                    ),
                    Marker(
                      point: displayRoute.last,
                      width: 34,
                      height: 34,
                      child: _RouteOrb(
                        color: colors.accentFill,
                        icon: Icons.sports_score_rounded,
                        large: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (badgeText != null && badgeText!.trim().isNotEmpty)
              Positioned(
                left: 12,
                top: 12,
                child: _MapGlassBadge(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: colors.accentFill, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        badgeText!,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (footerText != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: _MapGlassBadge(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    footerText!,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RouteOrb extends StatelessWidget {
  const _RouteOrb({
    required this.color,
    required this.icon,
    this.large = false,
  });

  final Color color;
  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.42),
            blurRadius: large ? 24 : 18,
            spreadRadius: large ? 4 : 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: large ? 27 : 23,
          height: large ? 27 : 23,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: large ? 13 : 11),
        ),
      ),
    );
  }
}
