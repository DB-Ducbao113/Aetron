import 'dart:convert';

import 'package:fitness_exercise_application/features/workout/domain/entities/route_match_result.dart';

class RouteMatchQualityService {
  const RouteMatchQualityService();

  RouteMatchResult normalize(RouteMatchResult result) {
    if (result.routeMatchStatus == 'not_requested') {
      return result.copyWith(
        matchedRouteJson: '[]',
        routeDistanceSource: 'filtered',
        matchedDistanceKm: null,
        routeMatchConfidence: null,
      );
    }
    if (!_hasUsableMatchedGeometry(result.matchedRouteJson)) {
      return result.copyWith(
        routeMatchStatus: 'match_failed_fallback_filtered',
        routeDistanceSource: 'filtered',
        matchedDistanceKm: null,
      );
    }

    switch (result.routeMatchStatus) {
      case 'reconstructed_pchip':
      case 'reconstructed_linear':
        return result.copyWith(
          routeDistanceSource: 'filtered',
          matchedDistanceKm: null,
          routeMatchConfidence: null,
        );
      case 'matched_success_high_confidence':
        if ((result.matchedDistanceKm ?? 0) > 0) {
          return result.copyWith(routeDistanceSource: 'matched');
        }
        return result.copyWith(
          routeDistanceSource: 'filtered_display_matched',
          matchedDistanceKm: null,
        );
      case 'matched_success_medium_confidence':
      case 'partial_match':
        return result.copyWith(
          routeDistanceSource: 'filtered_display_matched',
          matchedDistanceKm: _positiveDistanceOrNull(result.matchedDistanceKm),
        );
      case 'match_failed_fallback_filtered':
        return result.copyWith(
          routeDistanceSource: 'filtered',
          matchedDistanceKm: null,
        );
      default:
        final confidence = result.routeMatchConfidence ?? 0;
        if (confidence >= 0.9 && (result.matchedDistanceKm ?? 0) > 0) {
          return result.copyWith(
            routeMatchStatus: 'matched_success_high_confidence',
            routeDistanceSource: 'matched',
          );
        }
        if (confidence >= 0.6) {
          return result.copyWith(
            routeMatchStatus: 'matched_success_medium_confidence',
            routeDistanceSource: 'filtered_display_matched',
            matchedDistanceKm: _positiveDistanceOrNull(
              result.matchedDistanceKm,
            ),
          );
        }
        return result.copyWith(
          routeMatchStatus: 'match_failed_fallback_filtered',
          routeDistanceSource: 'filtered',
          matchedDistanceKm: null,
        );
    }
  }

  double? _positiveDistanceOrNull(double? distanceKm) {
    if (distanceKm == null || !distanceKm.isFinite || distanceKm <= 0) {
      return null;
    }
    return distanceKm;
  }

  bool _hasUsableMatchedGeometry(String raw) {
    if (raw.trim().isEmpty) return false;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return false;

      for (final segment in decoded) {
        if (segment is! List) continue;
        final validPointCount = segment.where(_isValidPoint).length;
        if (validPointCount >= 2) return true;
      }
    } on FormatException {
      return false;
    }
    return false;
  }

  bool _isValidPoint(Object? value) {
    if (value is! Map) return false;
    final lat = value['lat'];
    final lng = value['lng'];
    if (lat is! num || lng is! num) return false;
    final latitude = lat.toDouble();
    final longitude = lng.toDouble();
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
