import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

List<LatLng> sanitizeRouteForDisplay(
  List<LatLng> points, {
  required String activityType,
  bool applyCurveSmoothing = true,
}) {
  if (points.length < 3) return List<LatLng>.from(points);

  final normalized = activityType.toLowerCase();
  var cleaned = _removeTinySegments(
    points,
    _minDisplaySegmentMeters(normalized),
  );
  cleaned = _removeSharpSpikes(cleaned, normalized);
  cleaned = _preserveMeaningfulCorners(
    cleaned,
    normalized,
    toleranceMeters: _simplifyToleranceMeters(normalized),
  );
  cleaned = _centeredBearingAwareSmooth(cleaned, normalized);
  if (applyCurveSmoothing) {
    cleaned = smoothCurveForDisplay(cleaned, iterations: 2);
  }
  return cleaned;
}

List<LatLng> refineRouteForSavedDisplay(
  List<LatLng> points, {
  required String activityType,
  bool applyCurveSmoothing = true,
}) {
  if (points.length < 3) return List<LatLng>.from(points);

  final normalized = activityType.toLowerCase();
  var cleaned = _removeTinySegments(
    points,
    _minDisplaySegmentMeters(normalized) * 0.8,
  );
  cleaned = _removeSharpSpikes(cleaned, normalized);
  cleaned = _preserveMeaningfulCorners(
    cleaned,
    normalized,
    toleranceMeters: _simplifyToleranceMeters(normalized) * 0.75,
  );
  cleaned = _centeredBearingAwareSmooth(cleaned, normalized);
  cleaned = _corridorTighten(cleaned, normalized);
  if (applyCurveSmoothing) {
    cleaned = smoothCurveForDisplay(cleaned, iterations: 2);
  }
  return cleaned;
}

/// Display-only helper that merges short GPS-hiccup segment breaks (e.g. indoor
/// roof or 5–15s signal dropouts within [maxSeamlessGapMeters]) into continuous
/// visual polylines so routes don't appear fragmented with empty holes.
///
/// Larger breaks (> [maxSeamlessGapMeters], such as tunnels or pause relocations)
/// stay split so the renderer can draw an explicit dashed bridge instead of a
/// solid measured track. Never mutates persisted GPS data or distance metrics.
List<List<LatLng>> bridgeShortDisplayGaps(
  List<List<LatLng>> segments, {
  double maxSeamlessGapMeters = 45.0,
}) {
  final nonEmpty = segments.where((s) => s.isNotEmpty).toList(growable: false);
  if (nonEmpty.isEmpty) return const <List<LatLng>>[];

  final merged = <List<LatLng>>[List<LatLng>.from(nonEmpty.first)];
  for (var i = 1; i < nonEmpty.length; i++) {
    final next = nonEmpty[i];
    final current = merged.last;
    final gapMeters = _distance.distance(current.last, next.first);
    if (gapMeters <= maxSeamlessGapMeters) {
      if (gapMeters > 0.2) {
        current.addAll(next);
      } else if (next.length > 1) {
        current.addAll(next.sublist(1));
      }
    } else {
      merged.add(List<LatLng>.from(next));
    }
  }

  return merged.where((s) => s.length >= 2).toList(growable: false);
}

/// Display-only Chaikin corner-cutting subdivision (quadratic B-spline).
///
/// Produces silky, organic Strava-like curves strictly inside the convex hull
/// of the GPS polyline (zero overshoot or self-intersecting loops on U-turns),
/// pins exact start/end anchors, and never alters persisted distance/metrics.
List<LatLng> smoothCurveForDisplay(
  List<LatLng> points, {
  int iterations = 2,
}) {
  if (points.length < 3 || iterations <= 0) {
    return List<LatLng>.from(points);
  }

  // Cap subdivision passes on very long traces to keep rendering 60fps.
  final effectiveIterations = points.length > 600
      ? 1
      : iterations.clamp(1, 3);

  var current = points;
  for (var pass = 0; pass < effectiveIterations; pass++) {
    if (current.length < 3 || current.length > 1800) break;
    final next = <LatLng>[current.first];
    for (var i = 0; i < current.length - 1; i++) {
      final p0 = current[i];
      final p1 = current[i + 1];
      final q = LatLng(
        p0.latitude * 0.75 + p1.latitude * 0.25,
        p0.longitude * 0.75 + p1.longitude * 0.25,
      );
      final r = LatLng(
        p0.latitude * 0.25 + p1.latitude * 0.75,
        p0.longitude * 0.25 + p1.longitude * 0.75,
      );
      if (i > 0) {
        next.add(q);
      }
      if (i < current.length - 2) {
        next.add(r);
      }
    }
    next.add(current.last);
    current = next;
  }

  return current;
}

List<List<LatLng>> refineRouteSegmentsForSavedDisplay({
  required List<LatLng> routePoints,
  required List<List<LatLng>> routeSegments,
  required String activityType,
}) {
  if (routeSegments.isEmpty) {
    final displayRoute = refineRouteForSavedDisplay(
      routePoints,
      activityType: activityType,
    );
    return displayRoute.length >= 2
        ? <List<LatLng>>[displayRoute]
        : const <List<LatLng>>[];
  }

  return routeSegments
      .where((segment) => segment.length >= 2)
      .map(
        (segment) =>
            refineRouteForSavedDisplay(segment, activityType: activityType),
      )
      .where((segment) => segment.length >= 2)
      .toList();
}

double _minDisplaySegmentMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 4.5;
    case 'running':
      return 2.5;
    case 'walking':
      return 1.8;
    default:
      return 2.0;
  }
}

double _simplifyToleranceMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 4.0;
    case 'running':
      return 2.0;
    case 'walking':
      return 1.4;
    default:
      return 2.0;
  }
}

double _maxSmoothingShiftMeters(String activityType) {
  switch (activityType) {
    case 'cycling':
      return 2.4;
    case 'running':
      return 1.8;
    case 'walking':
      return 1.4;
    default:
      return 1.8;
  }
}

List<LatLng> _removeTinySegments(
  List<LatLng> points,
  double minDistanceMeters,
) {
  if (points.length < 2) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  for (var i = 1; i < points.length; i++) {
    final previous = result.last;
    final current = points[i];
    if (_distance.distance(previous, current) >= minDistanceMeters ||
        i == points.length - 1) {
      result.add(current);
    }
  }
  return result;
}

List<LatLng> _removeSharpSpikes(List<LatLng> points, String activityType) {
  if (points.length < 3) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxShortSegment = activityType == 'cycling' ? 32.0 : 20.0;
  final minDetour = activityType == 'cycling' ? 7.0 : 4.0;
  final minAngle = activityType == 'cycling' ? 45.0 : 58.0;

  for (var i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];
    final next = points[i + 1];

    final a = _distance.distance(prev, curr);
    final b = _distance.distance(curr, next);
    final c = _distance.distance(prev, next);
    final detour = (a + b) - c;
    final angle = _bearingDelta(
      _computeBearing(prev, curr),
      _computeBearing(curr, next),
    );

    final isSpike =
        a <= maxShortSegment &&
        b <= maxShortSegment &&
        detour >= minDetour &&
        angle >= minAngle;

    if (!isSpike) {
      result.add(curr);
    }
  }

  result.add(points.last);
  return result;
}

List<LatLng> _preserveMeaningfulCorners(
  List<LatLng> points,
  String activityType, {
  required double toleranceMeters,
}) {
  if (points.length < 3) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxKeepDistance = activityType == 'cycling' ? 26.0 : 18.0;
  final minCornerAngle = activityType == 'cycling' ? 22.0 : 28.0;

  for (var i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];
    final next = points[i + 1];
    final prevDistance = _distance.distance(prev, curr);
    final nextDistance = _distance.distance(curr, next);
    final turnAngle = _bearingDelta(
      _computeBearing(prev, curr),
      _computeBearing(curr, next),
    );

    final keepCorner =
        turnAngle >= minCornerAngle &&
        prevDistance <= maxKeepDistance &&
        nextDistance <= maxKeepDistance;
    final keepSpacing =
        prevDistance >= toleranceMeters || i == points.length - 2;

    if (keepCorner || keepSpacing) {
      result.add(curr);
    }
  }

  result.add(points.last);
  return result;
}

List<LatLng> _centeredBearingAwareSmooth(
  List<LatLng> points,
  String activityType,
) {
  if (points.length < 5) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxShift = _maxSmoothingShiftMeters(activityType);
  final protectedTurnAngle = activityType == 'cycling' ? 18.0 : 24.0;
  final maxBlendSegment = activityType == 'cycling' ? 22.0 : 16.0;

  for (var i = 1; i < points.length - 1; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    final next = points[i + 1];
    final prevDistance = _distance.distance(prev, curr);
    final nextDistance = _distance.distance(curr, next);
    final localTurn = _bearingDelta(
      _computeBearing(prev, curr),
      _computeBearing(curr, next),
    );

    if (localTurn >= protectedTurnAngle ||
        prevDistance > maxBlendSegment ||
        nextDistance > maxBlendSegment) {
      result.add(curr);
      continue;
    }

    final prev2 = i - 2 >= 0 ? points[i - 2] : prev;
    final next2 = i + 2 < points.length ? points[i + 2] : next;
    final leftBearing = _computeBearing(prev2, prev);
    final rightBearing = _computeBearing(next, next2);
    final corridorDelta = _bearingDelta(leftBearing, rightBearing);

    if (corridorDelta >= 30.0) {
      result.add(curr);
      continue;
    }

    final blended = LatLng(
      prev.latitude * 0.25 + curr.latitude * 0.5 + next.latitude * 0.25,
      prev.longitude * 0.25 + curr.longitude * 0.5 + next.longitude * 0.25,
    );

    final shift = _distance.distance(curr, blended);
    result.add(shift <= maxShift ? blended : curr);
  }

  result.add(points.last);
  return result;
}

List<LatLng> _corridorTighten(List<LatLng> points, String activityType) {
  if (points.length < 5) return List<LatLng>.from(points);

  final result = <LatLng>[points.first];
  final maxShift = _maxSmoothingShiftMeters(activityType) * 0.8;
  final keepTurnAngle = activityType == 'cycling' ? 16.0 : 20.0;

  for (var i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];
    final next = points[i + 1];
    final turnAngle = _bearingDelta(
      _computeBearing(prev, curr),
      _computeBearing(curr, next),
    );

    if (turnAngle >= keepTurnAngle) {
      result.add(curr);
      continue;
    }

    final midpoint = LatLng(
      (prev.latitude + next.latitude) / 2.0,
      (prev.longitude + next.longitude) / 2.0,
    );
    final shift = _distance.distance(curr, midpoint);
    result.add(shift <= maxShift ? midpoint : curr);
  }

  result.add(points.last);
  return result;
}

double _computeBearing(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180.0;
  final lat2 = to.latitude * math.pi / 180.0;
  final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final bearing = math.atan2(y, x) * 180.0 / math.pi;
  return (bearing + 360.0) % 360.0;
}

double _bearingDelta(double a, double b) {
  final delta = (a - b).abs();
  return delta > 180 ? 360 - delta : delta;
}
