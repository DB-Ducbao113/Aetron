import 'package:flutter/foundation.dart';

/// Enables relaxed location filtering in debug.
const bool kDebugLocationMode = bool.fromEnvironment(
  'FLOWFIT_DEBUG_LOCATION',
  defaultValue: kDebugMode,
);

/// Bypasses smoothing for mock playback.
const bool kDebugMockPlaybackMode = bool.fromEnvironment(
  'FLOWFIT_DEBUG_MOCK_PLAYBACK',
  defaultValue: false,
);

/// Configures the GPS trajectory smoothing algorithm: 'ekf4State' (default) or 'fixedAlpha'.
const String kGpsFilterAlgoConfig = String.fromEnvironment(
  'FLOWFIT_GPS_FILTER_ALGO',
  defaultValue: 'ekf4State',
);

/// Enables research-based trajectory data preprocessing (Phase 1: Li et al., 2025 & Zheng, 2015).
/// When enabled, incorporates modality-specific kinematic limits, sliding-window median filtering,
/// Zheng (2009) stay point dwell detection, and blackout partitioning into live tracking and finalization.
const bool kEnableTrajectoryPreprocessing = bool.fromEnvironment(
  'FLOWFIT_ENABLE_TRAJECTORY_PREPROCESSING',
  defaultValue: true,
);

/// Enables shadow comparison logging between legacy WorkoutTrackingEngine and research preprocessing.
const bool kEnableTrajectoryPreprocessingShadowMode = bool.fromEnvironment(
  'FLOWFIT_TRAJECTORY_PREPROCESSING_SHADOW',
  defaultValue: false,
);

/// Enables research-based GNSS error correction (Phase 2: Sukhenko et al., 2025; Groves, 2013).
/// When enabled, incorporates Normalized Innovation Squared (Mahalanobis) gating,
/// adaptive measurement covariance inflation, and centripetal turn process noise scaling.
const bool kEnableGnssCorrection = bool.fromEnvironment(
  'FLOWFIT_ENABLE_GNSS_CORRECTION',
  defaultValue: true,
);

/// Enables shadow comparison logging for Phase 2 GNSS error correction diagnostics.
const bool kEnableGnssCorrectionShadowMode = bool.fromEnvironment(
  'FLOWFIT_GNSS_CORRECTION_SHADOW',
  defaultValue: false,
);

/// Enables offline display-only pairwise Hermite reconstruction with the
/// Fritsch–Carlson (1980) monotonicity limiter; not a full reproduction of
/// Czerwiński et al. (2026). Reconstructed points never feed live metrics.
const bool kEnableTrajectoryReconstruction = bool.fromEnvironment(
  'FLOWFIT_ENABLE_TRAJECTORY_RECONSTRUCTION',
  defaultValue: true,
);

/// Selects the research-based pairwise Hermite adaptation by default.
/// Linear chord remains the comparator and had slightly lower masked-gap
/// RMSE on TU Wien. This selection is not a claim of superiority.
const String kTrajectoryReconstructionMethod = String.fromEnvironment(
  'FLOWFIT_TRAJECTORY_RECONSTRUCTION_METHOD',
  defaultValue: 'monotonePchip',
);

/// Enables shadow comparison logging for Phase 3 Trajectory Reconstruction diagnostics.
const bool kEnableTrajectoryReconstructionShadowMode = bool.fromEnvironment(
  'FLOWFIT_TRAJECTORY_RECONSTRUCTION_SHADOW',
  defaultValue: false,
);

/// Enables research-enhanced GPS Input Quality Gate (Phase 1 Enhancement).
/// When enabled, incorporates multi-tier quality evaluation (ACCEPT, DOWNWEIGHT,
/// REJECT, SEGMENT_BREAK) using robust M-estimator weighting and adaptive covariance scaling.
const bool kEnableGpsQualityGate = bool.fromEnvironment(
  'FLOWFIT_ENABLE_GPS_QUALITY_GATE',
  defaultValue: false,
);

/// Enables shadow comparison logging for GPS Input Quality Gate diagnostics.
const bool kEnableGpsQualityGateShadowMode = bool.fromEnvironment(
  'FLOWFIT_GPS_QUALITY_GATE_SHADOW',
  defaultValue: false,
);

/// Compile-time git revision for experiment provenance.
/// Injected dynamically via --dart-define=GIT_COMMIT_SHA=... during build.
const String kGitRevision = String.fromEnvironment(
  'GIT_COMMIT_SHA',
  defaultValue: 'experiment/ekf4-field-recording',
);

/// Reproducible fingerprint representing the exact build / working tree state.
/// Injected dynamically via --dart-define=FLOWFIT_SOURCE_FINGERPRINT=... during build.
const String kSourceFingerprint = String.fromEnvironment(
  'FLOWFIT_SOURCE_FINGERPRINT',
  defaultValue: 'experiment/ekf4-field-recording',
);
