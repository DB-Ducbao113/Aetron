import 'gps_input_quality_gate.dart';
import 'kinematic_limits.dart';
import 'trajectory_sample.dart';

/// Real-time streaming trajectory preprocessor operating with O(1) amortized latency per sample.
///
/// Designed for live mobile GPS recording pipelines. Maintains an immutable stream of raw GPS
/// samples, evaluating kinematic bounds, temporal outages, and acute multipath spikes in real-time.
///
/// Literature Grounding:
/// - Li, Tian, Yang & Lin (2025). "Trajectory Data Preprocessing: Methods and Models."
///   Electronics, 14(23), 4694. DOI: 10.3390/electronics14234694 (Section 3.1 & 3.5).
/// - Zheng (2015). "Trajectory Data Mining: An Overview." ACM TIST, 6(3), 29.
class StreamingTrajectoryPreprocessor {
  final KinematicLimits limits;
  final GpsInputQualityGate _qualityGate;

  TrajectoryRawSample? _lastRawSample;
  ProcessedTrajectoryPoint? _lastAcceptedPoint;
  ProcessedTrajectoryPoint? _twoPointsAgoAccepted;
  DateTime? _lastRawSampleTime;

  // Real-time metrics
  int _totalRawCount = 0;
  int _acceptedCount = 0;
  int _outlierCount = 0;
  int _signalGapCount = 0;
  double _accumulatedCleanDistanceMeters = 0.0;

  StreamingTrajectoryPreprocessor({
    required this.limits,
    bool? enableQualityGate,
    bool? enableShadowMode,
  }) : _qualityGate = GpsInputQualityGate(
         limits: limits,
         enableQualityGate: enableQualityGate,
         enableShadowMode: enableShadowMode,
       );

  ProcessedTrajectoryPoint? get lastAcceptedPoint => _lastAcceptedPoint;
  int get totalRawCount => _totalRawCount;
  int get acceptedCount => _acceptedCount;
  int get outlierCount => _outlierCount;
  int get signalGapCount => _signalGapCount;
  double get accumulatedCleanDistanceMeters => _accumulatedCleanDistanceMeters;

  /// Resets preprocessor state (e.g. at workout initiation or mode change).
  void reset() {
    _lastRawSample = null;
    _lastAcceptedPoint = null;
    _twoPointsAgoAccepted = null;
    _lastRawSampleTime = null;
    _totalRawCount = 0;
    _acceptedCount = 0;
    _outlierCount = 0;
    _signalGapCount = 0;
    _accumulatedCleanDistanceMeters = 0.0;
  }

  /// Processes a single raw GPS sample strictly preserving immutability.
  ProcessedTrajectoryPoint processSample(TrajectoryRawSample rawSample) {
    _totalRawCount++;

    double? rawDtSec;
    if (_lastRawSampleTime != null) {
      rawDtSec =
          rawSample.timestamp.difference(_lastRawSampleTime!).inMilliseconds /
          1000.0;
    }
    _lastRawSampleTime = rawSample.timestamp;

    final decision = _qualityGate.evaluateSample(
      candidate: rawSample,
      previousRawSample: _lastRawSample,
      previousAcceptedPoint: _lastAcceptedPoint,
      twoPointsAgoAccepted: _twoPointsAgoAccepted,
      kinematicPredictedPoint: null,
      previousSpeedMs: _lastAcceptedPoint?.impliedSpeedMs,
      rawTimeSincePreviousSampleSec: rawDtSec,
    );
    _lastRawSample = rawSample;

    final processed = ProcessedTrajectoryPoint(
      rawSample: rawSample,
      qualityFlags: decision.qualityFlags,
      segmentDistanceMeters: decision.segmentDistanceMeters,
      timeDeltaSec: decision.timeDeltaSec,
      impliedSpeedMs: decision.impliedSpeedMs,
      impliedAccelerationMs2: decision.impliedAccelerationMs2,
      forwardBearingDeg: decision.forwardBearingDeg,
      isAccepted: decision.isAcceptedForPath,
      isGapRecovery: decision.isGapRecovery,
      covarianceScale: decision.covarianceScale,
    );

    if (processed.qualityFlags.contains(TrajectoryQualityFlag.signalGap)) {
      _signalGapCount++;
    }

    if (processed.isOutlier) {
      _outlierCount++;
    }

    if (processed.isAccepted) {
      _acceptedCount++;
      // Only accumulate distance if this point does not bridge an outage gap
      if (!processed.isGapRecovery && _lastAcceptedPoint != null) {
        _accumulatedCleanDistanceMeters += processed.segmentDistanceMeters;
      }

      _twoPointsAgoAccepted = _lastAcceptedPoint;
      _lastAcceptedPoint = processed;
    }

    return processed;
  }
}
