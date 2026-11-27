import 'package:latlong2/latlong.dart';

/// A GPS point enriched with temporal information for trajectory clustering
class TimedGpsPoint {
  final LatLng point;
  final DateTime timestamp;
  final double speedMs;
  final double accuracyMeters;

  const TimedGpsPoint({
    required this.point,
    required this.timestamp,
    this.speedMs = 0.0,
    this.accuracyMeters = 5.0,
  });

  double get latitude => point.latitude;
  double get longitude => point.longitude;
}

/// Represents a detected stationary dwell cluster (e.g. red-light, rest stop)
class DwellCluster {
  final int startIndex;
  final int endIndex;
  final DateTime startTime;
  final DateTime endTime;
  final LatLng centroid;
  final int pointCount;

  const DwellCluster({
    required this.startIndex,
    required this.endIndex,
    required this.startTime,
    required this.endTime,
    required this.centroid,
    required this.pointCount,
  });

  Duration get duration => endTime.difference(startTime);
  double get durationSeconds => duration.inMilliseconds / 1000.0;
}

/// Sequential Centroid-Radius Dwell Clustering Service for offline GPS stop analysis.
///
/// NOTE: Despite the legacy class/file name (`GpsDbscanService`), this is a
/// sequential sliding-centroid dwell detector (NOT density-reachable DBSCAN
/// from Ester et al. 1996, and NOT wired into live workout tracking — used
/// strictly for offline stop-detection benchmarks and unit tests):
/// - Centroid radius: ε ≈ 5–8 m (default 6.5 m)
/// - Minimum dwell duration: t ≥ 10 s
/// - MinPts: minimum consecutive low-speed points in cluster
class GpsDbscanService {
  final double epsilonMeters;
  final double minDurationSeconds;
  final int minPts;
  final double stationarySpeedThreshold;

  static const Distance _distance = Distance();

  const GpsDbscanService({
    this.epsilonMeters = 6.5,
    this.minDurationSeconds = 10.0,
    this.minPts = 4,
    this.stationarySpeedThreshold = 1.0,
  });

  /// Identifies all stationary dwell clusters in a time-ordered sequence of [points].
  List<DwellCluster> findDwellClusters(List<TimedGpsPoint> points) {
    if (points.length < minPts) return const [];

    final clusters = <DwellCluster>[];
    var i = 0;

    while (i < points.length) {
      final anchor = points[i];
      // If anchor itself has moving speed, skip
      if (anchor.speedMs > stationarySpeedThreshold) {
        i += 1;
        continue;
      }

      var j = i + 1;
      var sumLat = anchor.latitude;
      var sumLng = anchor.longitude;
      var count = 1;

      // Expand window while subsequent points remain stationary and within epsilon
      while (j < points.length) {
        final candidate = points[j];
        if (candidate.speedMs > stationarySpeedThreshold) {
          break;
        }

        final currentCentroid = LatLng(sumLat / count, sumLng / count);
        final dist = _distance.distance(currentCentroid, candidate.point);

        if (dist <= epsilonMeters) {
          sumLat += candidate.latitude;
          sumLng += candidate.longitude;
          count += 1;
          j += 1;
        } else {
          break;
        }
      }

      final endIndex = j - 1;
      final pointCount = endIndex - i + 1;
      final durationSec = points[endIndex]
              .timestamp
              .difference(points[i].timestamp)
              .inMilliseconds /
          1000.0;

      if (pointCount >= minPts && durationSec >= minDurationSeconds) {
        final centroid = LatLng(sumLat / pointCount, sumLng / pointCount);
        clusters.add(
          DwellCluster(
            startIndex: i,
            endIndex: endIndex,
            startTime: points[i].timestamp,
            endTime: points[endIndex].timestamp,
            centroid: centroid,
            pointCount: pointCount,
          ),
        );
        i = j; // Move past this cluster
      } else {
        i += 1;
      }
    }

    return clusters;
  }
}
