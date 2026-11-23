/// Kinematic parameters and physical limits for trajectory outlier detection
/// and segmentation, differentiated by locomotion mode.
///
/// Grounded in:
/// 1. Zheng (2015). "Trajectory Data Mining: An Overview." ACM TIST, 6(3), 29:1–41.
///    DOI: 10.1145/2743025 (Section 3.1: Noise Filtering & Kinematic Thresholds).
/// 2. Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///    Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694 (Section 3.1 & Table 1).
/// 3. Zheng et al. (2009). "Mining Interesting Locations and Travel Sequences from
///    GPS Trajectories." WWW '09, pp. 791–800. DOI: 10.1145/1526709.1526816.
class KinematicLimits {
  /// Maximum plausible movement speed in m/s (v_max).
  final double maxSpeedMs;

  /// Maximum plausible acceleration/deceleration in m/s^2 (a_max).
  final double maxAccelerationMs2;

  /// Maximum acceptable GNSS horizontal accuracy in meters (acc_max).
  final double maxAccuracyMeters;

  /// Minimum segment displacement required to avoid stationary GPS jitter in meters.
  final double minSegmentMeters;

  /// Maximum spatial radius for Zheng (2009) stay point detection in meters (D_max).
  final double stayPointMaxDistanceMeters;

  /// Minimum duration for Zheng (2009) stay point detection in seconds (T_min).
  final double stayPointMinDurationSeconds;

  /// Threshold duration after which missing GPS points represent a signal blackout (dt_gap).
  final double outageGapThresholdSeconds;

  /// Acute heading rebound threshold in degrees for ping-pong spike detection.
  final double acuteHeadingReversalThresholdDeg;

  /// Window size for sliding-window median outlier filter (W = 2k + 1).
  final int medianWindowSize;

  const KinematicLimits({
    required this.maxSpeedMs,
    required this.maxAccelerationMs2,
    required this.maxAccuracyMeters,
    required this.minSegmentMeters,
    required this.stayPointMaxDistanceMeters,
    required this.stayPointMinDurationSeconds,
    this.outageGapThresholdSeconds = 5.0,
    this.acuteHeadingReversalThresholdDeg = 140.0,
    this.medianWindowSize = 5,
  })  : assert(maxSpeedMs > 0),
        assert(maxAccelerationMs2 > 0),
        assert(maxAccuracyMeters > 0),
        assert(stayPointMaxDistanceMeters > 0),
        assert(stayPointMinDurationSeconds > 0),
        assert(outageGapThresholdSeconds > 0),
        assert(medianWindowSize % 2 == 1, 'Window size must be odd');

  /// Walking mode thresholds:
  /// - Max speed: 3.5 m/s (~12.6 km/h; competitive race walking world record ~15 km/h).
  /// - Max acceleration: 2.5 m/s^2 (human walking physical boundary).
  /// - Max accuracy: 25.0 m.
  /// - Min segment: 0.8 m.
  /// - Stay point: D_max = 8.0 m, T_min = 10.0 s.
  factory KinematicLimits.walking() => const KinematicLimits(
        maxSpeedMs: 3.5,
        maxAccelerationMs2: 2.5,
        maxAccuracyMeters: 25.0,
        minSegmentMeters: 0.8,
        stayPointMaxDistanceMeters: 8.0,
        stayPointMinDurationSeconds: 10.0,
        outageGapThresholdSeconds: 5.0,
        acuteHeadingReversalThresholdDeg: 140.0,
        medianWindowSize: 5,
      );

  /// Running mode thresholds:
  /// - Max speed: 8.0 m/s (~28.8 km/h; world-record sprint/distance hybrid pace).
  /// - Max acceleration: 4.5 m/s^2.
  /// - Max accuracy: 25.0 m.
  /// - Min segment: 1.2 m.
  /// - Stay point: D_max = 10.0 m, T_min = 10.0 s.
  factory KinematicLimits.running() => const KinematicLimits(
        maxSpeedMs: 8.0,
        maxAccelerationMs2: 4.5,
        maxAccuracyMeters: 25.0,
        minSegmentMeters: 1.2,
        stayPointMaxDistanceMeters: 10.0,
        stayPointMinDurationSeconds: 10.0,
        outageGapThresholdSeconds: 5.0,
        acuteHeadingReversalThresholdDeg: 140.0,
        medianWindowSize: 5,
      );

  /// Cycling mode thresholds:
  /// - Max speed: 22.0 m/s (~79.2 km/h; covers fast descents and peloton sprints).
  /// - Max acceleration: 6.0 m/s^2.
  /// - Max accuracy: 30.0 m.
  /// - Min segment: 2.5 m.
  /// - Stay point: D_max = 12.0 m, T_min = 10.0 s.
  factory KinematicLimits.cycling() => const KinematicLimits(
        maxSpeedMs: 22.0,
        maxAccelerationMs2: 6.0,
        maxAccuracyMeters: 30.0,
        minSegmentMeters: 2.5,
        stayPointMaxDistanceMeters: 12.0,
        stayPointMinDurationSeconds: 10.0,
        outageGapThresholdSeconds: 5.0,
        acuteHeadingReversalThresholdDeg: 130.0,
        medianWindowSize: 5,
      );

  KinematicLimits copyWith({
    double? maxSpeedMs,
    double? maxAccelerationMs2,
    double? maxAccuracyMeters,
    double? minSegmentMeters,
    double? stayPointMaxDistanceMeters,
    double? stayPointMinDurationSeconds,
    double? outageGapThresholdSeconds,
    double? acuteHeadingReversalThresholdDeg,
    int? medianWindowSize,
  }) {
    return KinematicLimits(
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      maxAccelerationMs2: maxAccelerationMs2 ?? this.maxAccelerationMs2,
      maxAccuracyMeters: maxAccuracyMeters ?? this.maxAccuracyMeters,
      minSegmentMeters: minSegmentMeters ?? this.minSegmentMeters,
      stayPointMaxDistanceMeters:
          stayPointMaxDistanceMeters ?? this.stayPointMaxDistanceMeters,
      stayPointMinDurationSeconds:
          stayPointMinDurationSeconds ?? this.stayPointMinDurationSeconds,
      outageGapThresholdSeconds:
          outageGapThresholdSeconds ?? this.outageGapThresholdSeconds,
      acuteHeadingReversalThresholdDeg:
          acuteHeadingReversalThresholdDeg ??
              this.acuteHeadingReversalThresholdDeg,
      medianWindowSize: medianWindowSize ?? this.medianWindowSize,
    );
  }

  /// Mode factory mapping standard activity strings safely.
  factory KinematicLimits.forActivity(
    String activityType, {
    bool debugLocationMode = false,
  }) {
    KinematicLimits base;
    switch (activityType.toLowerCase().trim()) {
      case 'running':
      case 'run':
        base = KinematicLimits.running();
        break;
      case 'cycling':
      case 'bike':
      case 'bicycle':
      case 'ride':
        base = KinematicLimits.cycling();
        break;
      case 'walking':
      case 'walk':
      case 'hiking':
      case 'hike':
      default:
        base = KinematicLimits.walking();
        break;
    }
    if (debugLocationMode) {
      return base.copyWith(
        maxAccuracyMeters: 100.0,
        minSegmentMeters: 0.25,
      );
    }
    return base;
  }
}
