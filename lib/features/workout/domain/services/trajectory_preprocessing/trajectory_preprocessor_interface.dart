import 'batch_trajectory_preprocessor.dart';
import 'kinematic_limits.dart';
import 'streaming_trajectory_preprocessor.dart';
import 'trajectory_sample.dart';

export 'batch_trajectory_preprocessor.dart';
export 'kinematic_limits.dart';
export 'stay_point_segmenter.dart';
export 'streaming_trajectory_preprocessor.dart';
export 'trajectory_outlier_detector.dart';
export 'trajectory_sample.dart';

/// Unified Trajectory Preprocessor interface for Aetron GPS Pipeline.
///
/// Provides both streaming (real-time O(1)) and batch (multi-pass post-hoc)
/// interfaces for research-grounded trajectory data preprocessing.
abstract class ITrajectoryPreprocessor {
  /// Locomotion kinematic limits configuring this preprocessor instance.
  KinematicLimits get limits;

  /// Creates an initialized streaming preprocessor for live GPS tracking.
  StreamingTrajectoryPreprocessor createStreamingSession();

  /// Runs complete multi-pass batch preprocessing on an immutable sequence of raw GPS samples.
  TrajectoryPreprocessingResult processBatch(List<TrajectoryRawSample> samples);
}

/// Standard production implementation of [ITrajectoryPreprocessor].
class TrajectoryPreprocessor implements ITrajectoryPreprocessor {
  @override
  final KinematicLimits limits;

  final BatchTrajectoryPreprocessor _batchPreprocessor;

  TrajectoryPreprocessor({required this.limits})
      : _batchPreprocessor = BatchTrajectoryPreprocessor(limits: limits);

  /// Factory constructor for a specific activity mode ('walking', 'running', 'cycling').
  factory TrajectoryPreprocessor.forActivity(
    String activityType, {
    bool debugLocationMode = false,
  }) {
    return TrajectoryPreprocessor(
      limits: KinematicLimits.forActivity(
        activityType,
        debugLocationMode: debugLocationMode,
      ),
    );
  }

  @override
  StreamingTrajectoryPreprocessor createStreamingSession() {
    return StreamingTrajectoryPreprocessor(limits: limits);
  }

  @override
  TrajectoryPreprocessingResult processBatch(List<TrajectoryRawSample> samples) {
    return _batchPreprocessor.process(samples);
  }
}
