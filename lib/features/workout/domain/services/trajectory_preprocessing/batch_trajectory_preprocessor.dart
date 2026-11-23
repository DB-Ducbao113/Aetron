import 'package:latlong2/latlong.dart';

import 'kinematic_limits.dart';
import 'stay_point_segmenter.dart';
import 'trajectory_outlier_detector.dart';
import 'trajectory_sample.dart';

/// Comprehensive results and evaluation metrics emitted by batch trajectory preprocessing.
class TrajectoryPreprocessingResult {
  /// Unmodified, immutable raw input samples.
  final List<TrajectoryRawSample> rawSamples;

  /// Decorated trajectory points with diagnostic quality flags.
  final List<ProcessedTrajectoryPoint> processedPoints;

  /// Segmented partitions of the trajectory (Move, Stay, Outage).
  final List<TrajectorySegment> segments;

  /// Total count of raw input fixes.
  final int totalRawCount;

  /// Number of points accepted as clean and valid.
  final int acceptedCleanCount;

  /// Number of speed spike outliers detected.
  final int speedSpikeCount;

  /// Number of acceleration spike outliers detected.
  final int accelerationSpikeCount;

  /// Number of acute heading reversal outliers detected.
  final int headingSpikeCount;

  /// Number of statistical sliding-window median outliers detected.
  final int statisticalOutlierCount;

  /// Number of low accuracy points rejected.
  final int lowAccuracyCount;

  /// Number of signal blackout outages detected (> dt_gap).
  final int signalGapCount;

  /// Number of stationary stay points detected (Zheng et al., 2009).
  final int stayPointsCount;

  /// Total duration of stationary stay points in seconds.
  final double totalStayDurationSeconds;

  /// Total valid locomotion distance in meters (excluding outages and stay drift).
  final double cleanDistanceMeters;

  /// Total raw path distance in meters (unfiltered sum of consecutive raw points).
  final double rawTotalDistanceMeters;

  /// Phantom distance accumulated during stationary periods that was eliminated.
  final double stationaryDriftEliminatedMeters;

  /// Execution runtime of the preprocessing pipeline in microseconds.
  final int executionTimeMicroseconds;

  const TrajectoryPreprocessingResult({
    required this.rawSamples,
    required this.processedPoints,
    required this.segments,
    required this.totalRawCount,
    required this.acceptedCleanCount,
    required this.speedSpikeCount,
    required this.accelerationSpikeCount,
    required this.headingSpikeCount,
    required this.statisticalOutlierCount,
    required this.lowAccuracyCount,
    required this.signalGapCount,
    required this.stayPointsCount,
    required this.totalStayDurationSeconds,
    required this.cleanDistanceMeters,
    required this.rawTotalDistanceMeters,
    required this.stationaryDriftEliminatedMeters,
    required this.executionTimeMicroseconds,
  });

  /// Outlier percentage in the dataset.
  double get outlierPercentage =>
      totalRawCount > 0 ? (totalRawCount - acceptedCleanCount) / totalRawCount * 100.0 : 0.0;

  /// Average processing latency in microseconds per sample.
  double get latencyPerSampleUs =>
      totalRawCount > 0 ? executionTimeMicroseconds / totalRawCount : 0.0;
}

/// Offline / post-workout batch trajectory preprocessor.
///
/// Executes multi-stage preprocessing conforming to:
/// - Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///   Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694.
/// - Zheng (2015). "Trajectory Data Mining: An Overview." ACM TIST, 6(3), 29.
/// - Zheng et al. (2009). "Mining Interesting Locations and Travel Sequences from GPS Trajectories." WWW '09.
class BatchTrajectoryPreprocessor {
  final KinematicLimits limits;
  final TrajectoryOutlierDetector _detector;
  final StayPointSegmenter _segmenter;

  BatchTrajectoryPreprocessor({required this.limits})
      : _detector = TrajectoryOutlierDetector(limits: limits),
        _segmenter = StayPointSegmenter(limits: limits);

  /// Executes full batch preprocessing on an immutable sequence of raw GPS samples.
  TrajectoryPreprocessingResult process(List<TrajectoryRawSample> samples) {
    final stopwatch = Stopwatch()..start();

    if (samples.isEmpty) {
      return TrajectoryPreprocessingResult(
        rawSamples: const [],
        processedPoints: const [],
        segments: const [],
        totalRawCount: 0,
        acceptedCleanCount: 0,
        speedSpikeCount: 0,
        accelerationSpikeCount: 0,
        headingSpikeCount: 0,
        statisticalOutlierCount: 0,
        lowAccuracyCount: 0,
        signalGapCount: 0,
        stayPointsCount: 0,
        totalStayDurationSeconds: 0.0,
        cleanDistanceMeters: 0.0,
        rawTotalDistanceMeters: 0.0,
        stationaryDriftEliminatedMeters: 0.0,
        executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
      );
    }

    // Pass 1: Streaming kinematic outlier detection
    final pass1Points = <ProcessedTrajectoryPoint>[];
    ProcessedTrajectoryPoint? prevAccepted;
    ProcessedTrajectoryPoint? twoAgoAccepted;
    DateTime? prevRawTime;

    var speedSpikes = 0;
    var accSpikes = 0;
    var headingSpikes = 0;
    var lowAccCount = 0;
    var signalGaps = 0;

    for (final sample in samples) {
      double? rawDtSec;
      if (prevRawTime != null) {
        rawDtSec = sample.timestamp.difference(prevRawTime).inMilliseconds / 1000.0;
      }
      prevRawTime = sample.timestamp;

      final pt = _detector.evaluateStreamingPoint(
        candidate: sample,
        previousAcceptedPoint: prevAccepted,
        twoPointsAgoAccepted: twoAgoAccepted,
        rawTimeSincePreviousSampleSec: rawDtSec,
      );

      pass1Points.add(pt);

      if (pt.qualityFlags.contains(TrajectoryQualityFlag.speedSpike)) speedSpikes++;
      if (pt.qualityFlags.contains(TrajectoryQualityFlag.accelerationSpike)) accSpikes++;
      if (pt.qualityFlags.contains(TrajectoryQualityFlag.headingSpike)) headingSpikes++;
      if (pt.qualityFlags.contains(TrajectoryQualityFlag.lowAccuracy)) lowAccCount++;
      if (pt.qualityFlags.contains(TrajectoryQualityFlag.signalGap)) signalGaps++;

      if (pt.isAccepted) {
        twoAgoAccepted = prevAccepted;
        prevAccepted = pt;
      }
    }

    // Pass 2: Symmetric sliding-window median filtering
    final pass2Points = _detector.applyBatchMedianFilter(pass1Points);
    var statOutliers = 0;
    for (final pt in pass2Points) {
      if (pt.qualityFlags.contains(TrajectoryQualityFlag.statisticalOutlier)) {
        statOutliers++;
      }
    }

    // Filter to accepted points for stay point segmentation
    final acceptedPoints = pass2Points.where((p) => p.isAccepted).toList();

    // Pass 3: Zheng (2009) Stay Point Segmentation
    final segments = _segmenter.segmentTrajectory(acceptedPoints);

    // Compute metrics
    var stayPointsCount = 0;
    var totalStayDurationSec = 0.0;
    var cleanDistM = 0.0;
    var stationaryDriftEliminatedM = 0.0;

    for (final seg in segments) {
      if (seg.isStay) {
        stayPointsCount++;
        totalStayDurationSec += seg.durationSeconds;
        // Raw drift inside stay segment = sum of raw jumps within this stay cluster
        for (var i = 1; i < seg.points.length; i++) {
          stationaryDriftEliminatedM += seg.points[i].segmentDistanceMeters;
        }
      } else if (seg.isMove) {
        cleanDistM += seg.distanceMeters;
      }
    }

    // Calculate raw total distance (sum of all consecutive raw sample displacements)
    var rawDistM = 0.0;
    const distanceCalc = Distance();
    for (var i = 1; i < samples.length; i++) {
      rawDistM += distanceCalc.distance(samples[i - 1].point, samples[i].point);
    }

    final acceptedCleanCount = pass2Points.where((p) => p.isAccepted && !p.isOutlier).length;

    stopwatch.stop();

    return TrajectoryPreprocessingResult(
      rawSamples: List<TrajectoryRawSample>.unmodifiable(samples),
      processedPoints: List<ProcessedTrajectoryPoint>.unmodifiable(pass2Points),
      segments: List<TrajectorySegment>.unmodifiable(segments),
      totalRawCount: samples.length,
      acceptedCleanCount: acceptedCleanCount,
      speedSpikeCount: speedSpikes,
      accelerationSpikeCount: accSpikes,
      headingSpikeCount: headingSpikes,
      statisticalOutlierCount: statOutliers,
      lowAccuracyCount: lowAccCount,
      signalGapCount: signalGaps,
      stayPointsCount: stayPointsCount,
      totalStayDurationSeconds: totalStayDurationSec,
      cleanDistanceMeters: cleanDistM,
      rawTotalDistanceMeters: rawDistM,
      stationaryDriftEliminatedMeters: stationaryDriftEliminatedM,
      executionTimeMicroseconds: stopwatch.elapsedMicroseconds,
    );
  }
}
