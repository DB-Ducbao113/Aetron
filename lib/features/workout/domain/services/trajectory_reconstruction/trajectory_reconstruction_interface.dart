import '../trajectory_preprocessing/trajectory_sample.dart';
import 'trajectory_reconstruction_models.dart';

/// Contract for Phase 3 (P03) Trajectory Reconstruction Engines.
///
/// Literature Grounding:
/// - Czerwiński et al. (2026). "A Multi-Stage Framework for GPS Trajectory Reconstruction Using Consumer-Grade Wearable Devices."
///   Applied Sciences (MDPI), 16(18), 8972. DOI: 10.3390/app16188972.
/// - Newson & Krumm (2009). "Hidden Markov Map Matching Through Noise and Sparseness." ACM GIS '09.
abstract class ITrajectoryReconstructionEngine {
  /// Reconstructs a trajectory from preprocessed and filtered points.
  ///
  /// Fills recoverable sampling dropouts (2s < dt <= 15s) using monotonic kinematic
  /// splines constrained by boundary velocities and athletic limits.
  /// Severe outages (dt > 15s) are isolated as indeterminate discontinuities
  /// to avoid fabricating unobserved motion.
  TrajectoryReconstructionResult reconstructTrajectory({
    required List<ProcessedTrajectoryPoint> points,
    required String activityType,
    double samplingStepSec = 1.0,
  });
}

