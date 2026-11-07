import 'package:latlong2/latlong.dart';

/// Provenance quality flags for trajectory points according to:
/// - Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///   Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694 (Section 3.1 & 3.3).
/// - Zheng (2015). "Trajectory Data Mining: An Overview." ACM TIST, 6(3), 29.
///   DOI: 10.1145/2743025.
/// - Zheng et al. (2009). "Mining Interesting Locations and Travel Sequences from
///   GPS Trajectories." WWW '09. DOI: 10.1145/1526709.1526816.
enum TrajectoryQualityFlag {
  /// Fix satisfies all kinematic and sensor accuracy criteria.
  clean,

  /// GNSS reported horizontal accuracy exceeds the mode-specific threshold.
  lowAccuracy,

  /// Implied velocity v = dist(p_{i-1}, p_i) / dt exceeds physical limit for mode.
  speedSpike,

  /// Implied acceleration a = |v_i - v_{i-1}| / dt exceeds physiological limit.
  accelerationSpike,

  /// Point exhibits acute angular detour (ping-pong / multipath spike) with high speed.
  headingSpike,

  /// Temporal gap dt > dt_gap representing GNSS blackout or signal loss of lock.
  signalGap,

  /// Point falls within a verified stationary stay point (Zheng et al., 2009).
  stayPoint,

  /// Point is flagged as a spatial outlier by the sliding-window median filter.
  statisticalOutlier,
}

/// Immutable raw GNSS sample as received directly from sensor hardware.
///
/// Under academic trajectory preprocessing principles, raw samples must NEVER
/// be mutated or destroyed. All filtering decisions are represented as annotations.
class TrajectoryRawSample {
  final int index;
  final DateTime timestamp;
  final LatLng point;
  final double? altitudeMeters;
  final double? sensorSpeedMs;
  final double accuracyMeters;
  final double? sensorHeadingDeg;
  final String deviceSource;

  const TrajectoryRawSample({
    required this.index,
    required this.timestamp,
    required this.point,
    this.altitudeMeters,
    this.sensorSpeedMs,
    required this.accuracyMeters,
    this.sensorHeadingDeg,
    this.deviceSource = 'gps',
  });

  double get latitude => point.latitude;
  double get longitude => point.longitude;

  @override
  String toString() =>
      'RawSample(#$index, t=$timestamp, lat=${latitude.toStringAsFixed(6)}, '
      'lng=${longitude.toStringAsFixed(6)}, acc=${accuracyMeters.toStringAsFixed(1)}m, '
      'spd=${sensorSpeedMs?.toStringAsFixed(1) ?? "null"}m/s)';
}

/// A trajectory sample decorated with preprocessing diagnostics and quality flags.
///
/// Preserves the original raw sample reference while providing derived kinematic
/// features and acceptance classification for downstream consumers (e.g. EKF, display).
class ProcessedTrajectoryPoint {
  /// Original immutable raw sample from device hardware.
  final TrajectoryRawSample rawSample;

  /// Quality classifications identified by preprocessing algorithms.
  final Set<TrajectoryQualityFlag> qualityFlags;

  /// Computed inter-point travel distance from previous accepted point in meters.
  final double segmentDistanceMeters;

  /// Computed inter-point time delta in seconds.
  final double timeDeltaSec;

  /// Computed implied speed v = segmentDistance / timeDelta in m/s.
  final double impliedSpeedMs;

  /// Computed implied acceleration a = |v_i - v_{i-1}| / timeDelta in m/s^2.
  final double impliedAccelerationMs2;

  /// Forward azimuth / bearing from previous accepted point in degrees [0, 360).
  final double? forwardBearingDeg;

  /// Whether this point is accepted as valid for trajectory path & distance calculation.
  final bool isAccepted;

  /// Whether this point immediately succeeds a signal gap and starts a new segment.
  final bool isGapRecovery;

  const ProcessedTrajectoryPoint({
    required this.rawSample,
    required this.qualityFlags,
    required this.segmentDistanceMeters,
    required this.timeDeltaSec,
    required this.impliedSpeedMs,
    required this.impliedAccelerationMs2,
    this.forwardBearingDeg,
    required this.isAccepted,
    this.isGapRecovery = false,
  });

  int get index => rawSample.index;
  DateTime get timestamp => rawSample.timestamp;
  LatLng get point => rawSample.point;
  double get latitude => rawSample.latitude;
  double get longitude => rawSample.longitude;
  double get accuracyMeters => rawSample.accuracyMeters;

  bool get isClean => qualityFlags.contains(TrajectoryQualityFlag.clean);
  bool get isStayPoint => qualityFlags.contains(TrajectoryQualityFlag.stayPoint);
  bool get isOutlier =>
      qualityFlags.contains(TrajectoryQualityFlag.speedSpike) ||
      qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike) ||
      qualityFlags.contains(TrajectoryQualityFlag.headingSpike) ||
      qualityFlags.contains(TrajectoryQualityFlag.statisticalOutlier);

  @override
  String toString() =>
      'ProcessedPoint(#$index, accepted=$isAccepted, flags=$qualityFlags, '
      'dist=${segmentDistanceMeters.toStringAsFixed(1)}m, v=${impliedSpeedMs.toStringAsFixed(2)}m/s, '
      'a=${impliedAccelerationMs2.toStringAsFixed(2)}m/s^2)';
}
