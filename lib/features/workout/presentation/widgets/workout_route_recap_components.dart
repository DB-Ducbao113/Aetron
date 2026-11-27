import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/presentation/utils/route_display_sanitizer.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    // Allow tight ~20m auto-zoom for compact indoor/courtyard walks while
    // keeping comfortable 14% framing on longer outdoor runs/rides.
    final latPad = math.max(latSpan * 0.14, 0.00009);
    final lngPad = math.max(lngSpan * 0.14, 0.00009);

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
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                backgroundColor: colors.surface2,
                minZoom: 4,
                maxZoom: 22,
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: mapPadding,
                  maxZoom: 20.5,
                ),
                interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                if (showMapTiles) ...buildAetronMapTileLayers(mapType),
                PolylineLayer(
                  simplificationTolerance: 0.25,
                  polylines: buildAetronRoutePolylines(
                    segments: displaySegments,
                    mapType: mapType,
                    isDark: !isLight,
                    coreWidth: 4.8,
                  ),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: displayRoute.first,
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: const _RouteAnchorOrb(isFinish: false),
                    ),
                    Marker(
                      point: displayRoute.last,
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: const _RouteAnchorOrb(isFinish: true),
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

/// Minimalist Glassline start/finish route anchor aligned with Aetron's blue palette.
class _RouteAnchorOrb extends StatelessWidget {
  const _RouteAnchorOrb({required this.isFinish});

  final bool isFinish;

  @override
  Widget build(BuildContext context) {
    final outerSize = isFinish ? 26.0 : 20.0;
    final innerSize = isFinish ? 18.0 : 12.0;
    final coreColors = isFinish
        ? const [
            AetronLogoPaths.lightAccentColor,
            AetronLogoPaths.darkAccentColor,
          ]
        : const [Color(0xFF10B981), Color(0xFF34D399)];
    final glowColor = isFinish
        ? AetronLogoPaths.lightAccentColor
        : const Color(0xFF10B981);

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glowColor.withValues(alpha: 0.22),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.38),
            blurRadius: isFinish ? 12 : 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: coreColors,
            ),
            border: Border.all(color: Colors.white, width: isFinish ? 2.2 : 2.0),
          ),
          child: isFinish
              ? const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 10,
                )
              : null,
        ),
      ),
    );
  }
}
