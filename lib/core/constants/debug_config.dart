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
  defaultValue: false,
);

/// Enables shadow comparison logging between legacy WorkoutTrackingEngine and research preprocessing.
const bool kEnableTrajectoryPreprocessingShadowMode = bool.fromEnvironment(
  'FLOWFIT_TRAJECTORY_PREPROCESSING_SHADOW',
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
