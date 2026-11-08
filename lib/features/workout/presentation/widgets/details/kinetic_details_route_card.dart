import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class KineticDetailsRouteCard extends StatelessWidget {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final AppLanguage currentLang;
  final VoidCallback? onViewFullMap;
  final bool showMapTiles;

  const KineticDetailsRouteCard({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    required this.currentLang,
    this.onViewFullMap,
    this.showMapTiles = true,
  });

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'walking':
        return Icons.directions_walk_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    if (routePoints.length < 2) {
      return KineticCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                _activityIcon(activityType),
                color: colors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Không có dữ liệu bản đồ'
                  : 'Route unavailable',
              style: KineticTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              currentLang == AppLanguage.vi
                  ? 'Buổi tập vẫn lưu trữ đầy đủ chỉ số hiệu suất telemetry.'
                  : 'Full telemetry stats are preserved for this workout session.',
              style: KineticTypography.bodySmall.copyWith(
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return KineticCard(
      padding: EdgeInsets.zero,
      borderRadius: KineticTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: colors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          currentLang == AppLanguage.vi
                              ? 'BẢN ĐỒ CUNG ĐƯỜNG'
                              : 'ROUTE MAP',
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.unitLabel.copyWith(
                            color: colors.textPrimary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewFullMap != null)
                  TextButton.icon(
                    onPressed: onViewFullMap,
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: Text(
                      currentLang == AppLanguage.vi
                          ? 'Xem toàn bản đồ'
                          : 'View full map',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: KineticTypography.label.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(KineticTokens.radiusLG),
            ),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Semantics(
                button: onViewFullMap != null,
                label: currentLang == AppLanguage.vi
                    ? 'Mở bản đồ toàn màn hình'
                    : 'Open full-screen map',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onViewFullMap,
                  child: WorkoutRoutePreviewMap(
                    routePoints: routePoints,
                    routeSegments: routeSegments,
                    activityType: activityType,
                    icon: _activityIcon(activityType),
                    accentColor: colors.primary,
                    glowColor: colors.primary.withValues(alpha: 0.20),
                    highlightColor: colors.textPrimary.withValues(alpha: 0.75),
                    startColor: colors.primary,
                    endColor: colors.error,
                    showMapTiles: showMapTiles,
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
