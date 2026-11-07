import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'trajectory_sample.dart';

/// Semantic classification of a trajectory sub-sequence.
enum TrajectorySegmentType {
  /// Active locomotion movement (walking, running, cycling).
  move,

  /// Stationary dwell / stay point (Zheng et al., 2009; Li et al., 2025).
  stay,

  /// Signal blackout or loss-of-lock outage (> dt_gap). Must NOT be interpolated.
  outage,
}

/// A segmented continuous partition of a GPS trajectory.
class TrajectorySegment {
  final TrajectorySegmentType type;
  final List<ProcessedTrajectoryPoint> points;
  final DateTime startTime;
  final DateTime endTime;

  /// Spatial centroid (populated for stay points).
  final LatLng? centroid;

  /// Total travel distance in meters (computed for move segments).
  final double distanceMeters;

  const TrajectorySegment({
    required this.type,
    required this.points,
    required this.startTime,
    required this.endTime,
    this.centroid,
    this.distanceMeters = 0.0,
  });

  Duration get duration => endTime.difference(startTime);
  double get durationSeconds => duration.inMilliseconds / 1000.0;
  bool get isStay => type == TrajectorySegmentType.stay;
  bool get isMove => type == TrajectorySegmentType.move;
  bool get isOutage => type == TrajectorySegmentType.outage;

  @override
  String toString() =>
      'TrajectorySegment(${type.name.toUpperCase()}, pts=${points.length}, '
      't=${durationSeconds.toStringAsFixed(1)}s, dist=${distanceMeters.toStringAsFixed(1)}m, '
      'centroid=${centroid != null ? "(${centroid!.latitude.toStringAsFixed(5)}, ${centroid!.longitude.toStringAsFixed(5)})" : "null"})';
}

/// Stay Point Detection and Trajectory Segmentation Engine.
///
/// Faithful reproduction of the seminal algorithm:
/// - Zheng, Zhang, Xie & Ma (2009). "Mining interesting locations and travel sequences
///   from GPS trajectories." In Proceedings of the 18th International Conference on
///   World Wide Web (WWW '09), pp. 791–800. DOI: 10.1145/1526709.1526816.
///
/// Reviewed and synthesized in:
/// - Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///   Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694 (Section 3.3).
class StayPointSegmenter {
  final KinematicLimits limits;
  static const Distance _distance = Distance();

  const StayPointSegmenter({required this.limits});

  /// Segments an accepted time-ordered sequence of trajectory points into
  /// alternating Move segments, Stay segments, and Outage segments.
  ///
  /// Points falling within a detected Stay Point are annotated with [TrajectoryQualityFlag.stayPoint].
  List<TrajectorySegment> segmentTrajectory(
    List<ProcessedTrajectoryPoint> points,
  ) {
    if (points.isEmpty) return const [];
    if (points.length == 1) {
      return [
        TrajectorySegment(
          type: TrajectorySegmentType.move,
          points: points,
          startTime: points.first.timestamp,
          endTime: points.first.timestamp,
          distanceMeters: 0.0,
        ),
      ];
    }

    final dMax = limits.stayPointMaxDistanceMeters;
    final tMinSec = limits.stayPointMinDurationSeconds;
    final gapSec = limits.outageGapThresholdSeconds;

    final n = points.length;
    final isPointInStay = List<bool>.filled(n, false);
    final stayCentroids = <int, LatLng>{}; // startIndex -> centroid
    final stayEndIndices = <int, int>{}; // startIndex -> endIndex

    // 1. Seminal Zheng (2009) Stay Point Detection Loop
    var i = 0;
    while (i < n) {
      var j = i + 1;
      var tokenHandled = false;

      while (j < n) {
        // If an outage gap occurs between j-1 and j, stay point cannot span across the blackout
        final dtConsecutive = points[j]
                .timestamp
                .difference(points[j - 1].timestamp)
                .inMilliseconds /
            1000.0;

        if (dtConsecutive > gapSec) {
          final dtTotal = points[j - 1]
                  .timestamp
                  .difference(points[i].timestamp)
                  .inMilliseconds /
              1000.0;
          if (dtTotal >= tMinSec && (j - i) >= 3) {
            final centroid = _computeCentroid(points.sublist(i, j));
            stayCentroids[i] = centroid;
            stayEndIndices[i] = j - 1;
            for (var k = i; k < j; k++) {
              isPointInStay[k] = true;
            }
            i = j;
          } else {
            i = j;
          }
          tokenHandled = true;
          break;
        }

        final dist = _distance.distance(points[i].point, points[j].point);
        if (dist > dMax) {
          final dtTotal = points[j]
                  .timestamp
                  .difference(points[i].timestamp)
                  .inMilliseconds /
              1000.0;
          if (dtTotal >= tMinSec && (j - i) >= 3) {
            // Stay point confirmed between [i .. j - 1]
            final centroid = _computeCentroid(points.sublist(i, j));
            stayCentroids[i] = centroid;
            stayEndIndices[i] = j - 1;
            for (var k = i; k < j; k++) {
              isPointInStay[k] = true;
            }
            i = j;
          } else {
            i++;
          }
          tokenHandled = true;
          break;
        }
        j++;
      }

      if (!tokenHandled) {
        if (j >= n) {
          // Reached end of trajectory
          final dtTotal = points[n - 1]
                  .timestamp
                  .difference(points[i].timestamp)
                  .inMilliseconds /
              1000.0;
          if (dtTotal >= tMinSec && (n - i) >= 3) {
            final centroid = _computeCentroid(points.sublist(i, n));
            stayCentroids[i] = centroid;
            stayEndIndices[i] = n - 1;
            for (var k = i; k < n; k++) {
              isPointInStay[k] = true;
            }
          }
          break;
        } else {
          i++;
        }
      }
    }

    // 2. Partition trajectory into Move, Stay, and Outage segments
    final segments = <TrajectorySegment>[];
    var cursor = 0;

    while (cursor < n) {
      // Check for stay point starting at cursor
      if (stayEndIndices.containsKey(cursor)) {
        final endIndex = stayEndIndices[cursor]!;
        final sub = points.sublist(cursor, endIndex + 1);
        final centroid = stayCentroids[cursor]!;

        // Decorate points with stayPoint flag
        final stayPoints = sub.map((p) {
          final flags = Set<TrajectoryQualityFlag>.from(p.qualityFlags)
            ..add(TrajectoryQualityFlag.stayPoint);
          return ProcessedTrajectoryPoint(
            rawSample: p.rawSample,
            qualityFlags: flags,
            segmentDistanceMeters: p.segmentDistanceMeters,
            timeDeltaSec: p.timeDeltaSec,
            impliedSpeedMs: p.impliedSpeedMs,
            impliedAccelerationMs2: p.impliedAccelerationMs2,
            forwardBearingDeg: p.forwardBearingDeg,
            isAccepted: p.isAccepted,
            isGapRecovery: p.isGapRecovery,
          );
        }).toList();

        segments.add(TrajectorySegment(
          type: TrajectorySegmentType.stay,
          points: stayPoints,
          startTime: stayPoints.first.timestamp,
          endTime: stayPoints.last.timestamp,
          centroid: centroid,
          distanceMeters: 0.0, // Stationary dwell has 0 true movement distance
        ));

        cursor = endIndex + 1;
        continue;
      }

      // Check for outage gap at cursor
      if (cursor > 0 && points[cursor].isGapRecovery) {
        segments.add(TrajectorySegment(
          type: TrajectorySegmentType.outage,
          points: [points[cursor - 1], points[cursor]],
          startTime: points[cursor - 1].timestamp,
          endTime: points[cursor].timestamp,
          distanceMeters: 0.0, // Never interpolate or accumulate distance across outages!
        ));
      }

      // Accumulate move segment until next stay point or outage gap
      final movePoints = <ProcessedTrajectoryPoint>[];
      var moveDistM = 0.0;
      final moveStart = cursor;

      while (cursor < n && !stayEndIndices.containsKey(cursor)) {
        // If this point is a gap recovery (and not the very first point of move segment), break
        if (cursor > moveStart && points[cursor].isGapRecovery) {
          break;
        }

        final p = points[cursor];
        movePoints.add(p);
        if (p.isAccepted && !p.isGapRecovery && movePoints.length > 1) {
          moveDistM += p.segmentDistanceMeters;
        }
        cursor++;
      }

      if (movePoints.isNotEmpty) {
        segments.add(TrajectorySegment(
          type: TrajectorySegmentType.move,
          points: movePoints,
          startTime: movePoints.first.timestamp,
          endTime: movePoints.last.timestamp,
          distanceMeters: moveDistM,
        ));
      }
    }

    return segments;
  }

  /// Calculates geographic centroid of coordinates in a sub-trajectory.
  static LatLng _computeCentroid(List<ProcessedTrajectoryPoint> pts) {
    if (pts.isEmpty) return const LatLng(0, 0);
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in pts) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / pts.length, sumLng / pts.length);
  }
}
