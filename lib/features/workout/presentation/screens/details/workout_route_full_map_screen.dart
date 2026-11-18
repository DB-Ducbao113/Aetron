import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class WorkoutRouteFullMapScreen extends StatefulWidget {
  const WorkoutRouteFullMapScreen({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    required this.currentLang,
    this.showMapTiles = true,
  });

  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final AppLanguage currentLang;
  final bool showMapTiles;

  @override
  State<WorkoutRouteFullMapScreen> createState() =>
      _WorkoutRouteFullMapScreenState();
}

class _WorkoutRouteFullMapScreenState extends State<WorkoutRouteFullMapScreen> {
  AppMapType _fallbackMapType = AppMapType.satellite;

  IconData get _activityIcon => switch (widget.activityType.toLowerCase()) {
    'running' => Icons.directions_run_rounded,
    'cycling' => Icons.directions_bike_rounded,
    'walking' => Icons.directions_walk_rounded,
    _ => Icons.bolt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVietnamese = widget.currentLang == AppLanguage.vi;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: WorkoutRoutePreviewMap(
              routePoints: widget.routePoints,
              routeSegments: widget.routeSegments,
              activityType: widget.activityType,
              icon: _activityIcon,
              accentColor: colors.primary,
              glowColor: colors.primary.withValues(alpha: 0.24),
              highlightColor: colors.textPrimary.withValues(alpha: 0.80),
              startColor: colors.primary,
              endColor: colors.error,
              interactive: true,
              mapPadding: const EdgeInsets.fromLTRB(28, 112, 28, 120),
              showMapTiles: widget.showMapTiles,
              fallbackMapType: _fallbackMapType,
            ),
          ),
          // V4: top scrim for legibility over the full-bleed map.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: KineticGradients.scrimTop(colors),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _MapOverlayButton(
                    tooltip: isVietnamese ? 'Quay lại' : 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: KineticGradients.hudSurface(colors),
                        borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                        border: Border.all(
                          color: colors.borderSubtle.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Text(
                        isVietnamese ? 'Toàn bộ cung đường' : 'Full route map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.label.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AetronMapTypeBuilder(
                    fallbackType: _fallbackMapType,
                    builder: (context, mapType) {
                      final isSatellite = mapType == AppMapType.satellite;
                      return _MapOverlayButton(
                        buttonKey: const Key('full-map-layer-btn'),
                        tooltip: isVietnamese
                            ? 'Chọn kiểu bản đồ'
                            : 'Select map style',
                        icon: Icons.layers_rounded,
                        iconWidget: BladeIcon(
                          BladeIconName.layers,
                          size: 20,
                          color: isSatellite ? colors.primary : colors.textPrimary,
                        ),
                        isHighlighted: isSatellite,
                        onPressed: () => showAetronMapStylePicker(
                          context: context,
                          currentType: mapType,
                          currentLang: widget.currentLang,
                          onFallbackSelect: (selected) {
                            if (mounted) {
                              setState(() => _fallbackMapType = selected);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: KineticGradients.hudSurface(colors),
                      borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                      border: Border.all(
                        color: colors.borderSubtle.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pan_tool_alt_rounded,
                          size: 17,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isVietnamese
                                ? 'Kéo để khám phá • Chụm để thu phóng'
                                : 'Drag to explore • Pinch to zoom',
                            textAlign: TextAlign.center,
                            style: KineticTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapOverlayButton extends StatelessWidget {
  const _MapOverlayButton({
    this.buttonKey,
    required this.tooltip,
    required this.icon,
    this.iconWidget,
    this.isHighlighted = false,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String tooltip;
  final IconData icon;
  final Widget? iconWidget;
  final bool isHighlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
      child: Ink(
        decoration: BoxDecoration(
          gradient: KineticGradients.hudSurface(colors),
          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
          border: Border.all(
            color: isHighlighted
                ? colors.primary.withValues(alpha: 0.7)
                : colors.borderSubtle.withValues(alpha: 0.8),
          ),
        ),
        child: IconButton(
          key: buttonKey,
          tooltip: tooltip,
          onPressed: onPressed,
          icon: iconWidget ?? Icon(icon),
          color: colors.textPrimary,
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ),
    );
  }
}
