import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/repositories/workout_repository.dart';
import 'package:fitness_exercise_application/features/workout/domain/constants/workout_processing_contract.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_pipeline.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/services/ios_live_activity_service.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_environment_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_recording_coordinator.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_sensor_bootstrapper.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_sensor_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_finalizer.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_lifecycle.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_starter.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/step_sensor_types.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_walking_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_running_step_length.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/research_step_length_fallback.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/step_motion_gate.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:fitness_exercise_application/features/workout/providers/workout_providers_infra.dart';

// Constants

const String kOutdoorMode = 'outdoor';
const String kIndoorMode = 'indoor';
const String kAutoTrackingMode = 'auto'; // temporary mode before lock

bool _requiresGpsTracking(String activityType) {
  switch (activityType.toLowerCase()) {
    case 'running':
    case 'walking':
    case 'cycling':
      return true;
    default:
      return false;
  }
}

String _defaultRecordingSource(String activityType) {
  return _requiresGpsTracking(activityType) ? 'gps' : 'step_fallback';
}

// Stride

String? _normalizeGender(String? gender) {
  final normalized = gender?.trim().toLowerCase();
  if (normalized == 'female') return 'female';
  if (normalized == 'male') return 'male';
  return null;
}

double _defaultStrideLength(String activityType, String? gender) {
  final research = ResearchStepLengthFallback.estimateMeters(
    activityType: activityType,
    heightCm: null,
  );
  if (research != null) return research;
  final isRunning = activityType.toLowerCase().contains('run');
  final normalizedGender = _normalizeGender(gender);
  if (isRunning) {
    return normalizedGender == 'female' ? 0.85 : 0.93;
  }
  return normalizedGender == 'female' ? 0.68 : 0.73;
}

double computeStrideLength({
  required String activityType,
  double? heightCm,
  String? gender,
}) {
  final research = ResearchStepLengthFallback.estimateMeters(
    activityType: activityType,
    heightCm: heightCm,
  );
  if (research != null) return research;
  if (heightCm == null || !heightCm.isFinite || heightCm <= 0) {
    return _defaultStrideLength(activityType, gender);
  }
  final isRunning = activityType.toLowerCase().contains('run');
  final normalizedGender = _normalizeGender(gender);
  final factor = isRunning
      ? (normalizedGender == 'female' ? 0.62 : 0.67)
      : (normalizedGender == 'female' ? 0.40 : 0.43);
  final raw = heightCm * factor / 100;
  return raw.clamp(0.50, 1.50);
}

// Providers

final workoutSessionProvider =
    StateNotifierProvider.autoDispose<
      WorkoutSessionNotifier,
      WorkoutSessionState
    >((ref) {
      final notifier = WorkoutSessionNotifier(ref);
      ref.listen<IodState>(iodControllerProvider, (previous, next) {
        if (previous?.latestSnapshot != next.latestSnapshot ||
            previous?.currentPrediction != next.currentPrediction ||
            previous?.sessionId != next.sessionId ||
            previous?.isRecording != next.isRecording) {
          notifier._refreshIodEnvironmentHint(next);
        }
      });
      return notifier;
    });

// Notifier

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final Ref _ref;
  final WorkoutRecordingCoordinator _recordingCoordinator;
  final WorkoutTrackingEngine _trackingEngine = const WorkoutTrackingEngine();
  final GpsSmoothingService _gpsSmoothingService = GpsSmoothingService();
  final WorkoutSessionFinalizer _sessionFinalizer =
      const WorkoutSessionFinalizer();
  final WorkoutSessionLifecycle _sessionLifecycle =
      const WorkoutSessionLifecycle();
  final WorkoutSensorBootstrapper _sensorBootstrapper =
      const WorkoutSensorBootstrapper();
  final WorkoutSensorController _sensorController =
      const WorkoutSensorController();
  final WorkoutEnvironmentController _environmentController =
      WorkoutEnvironmentController();
  final WorkoutSessionStarter _sessionStarter = const WorkoutSessionStarter();

  // Subscriptions
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<dynamic>? _stepSub;

  // Timers
  Timer? _uiTicker;
  Timer? _indoorDistanceTimer;
  Timer? _calorieTimer;
  Timer? _pauseAutoStopTimer;
  Timer? _gpsHealthTimer;
  Timer? _checkpointTimer;
  RecordingPersistence<WorkoutSessionFinalization> _persistence =
      RecordingPersistence<WorkoutSessionFinalization>();
  DateTime? _stopRequestedAt;
  WorkoutSessionState? _frozenStopState;
  String? _recordingOwnerId;
  bool _pauseCheckpointSaved = false;
  Future<void>? _pauseOperation;
  KeepAliveLink? _recordingKeepAlive;

  final Stopwatch _stopwatch = Stopwatch();

  final _speedSamples = Queue<double>();
  static const int _speedWindowSize = 12;

  double _weightKg = 60.0;
  double? _heightCm;
  String? _gender;
  DateTime? _lastAcceptedPositionTime;
  final GpsRawSignalContinuity _rawSignalContinuity = GpsRawSignalContinuity(
    gapThresholdSec: WorkoutTrackingEngine.kStaleSignalGapThresholdSec,
  );
  DateTime? _lastStepTime;
  int _lastSessionSteps = 0;
  int _lastObservedActiveSensorSteps = 0;
  int _pausedStepsOffset = 0;
  final StepMotionGate _stepMotionGate = StepMotionGate();
  Position? _lastRawGpsPosition;
  DateTime? _lastMovingGpsAcceptedAt;
  // Raw GPS anchor used for distance accumulation only.
  LatLng? _distanceAnchorPoint;
  int _lastSplitElapsedSec = 0;
  double _lastSplitDistanceMeters = 0;
  int _nextLapIndex = 1;
  bool _shouldResetGpsAnchorOnResume = false;
  bool _allowOfflineReconstruction = true;
  bool _isStopping = false;
  bool _isRecoveringGpsStream = false;
  DateTime? _lastRecoveryAttemptTime;
  static const Duration _kRecoveryCooldown = Duration(seconds: 15);
  bool _isAwaitingRecoveryEvidence = false;
  String? _pendingRecoveryReason;
  DateTime? _lastGpsEventTime;
  DateTime? _lastModeFlipTime;
  // Retain the pre-IOD hint separately so expired advice cannot persist.
  String _legacyEnvironmentHint = 'detecting';
  final List<Position> _rawGpsPositions = [];
  StreamingTrajectoryPreprocessor? _streamingPreprocessor;
  int _rawPositionSequence = 0;
  static const Duration _kPauseAutoStopDelay = Duration(minutes: 15);
  static const Duration _kIndoorWatchdogTick = Duration(seconds: 2);
  static const Duration _kIndoorStepGrace = Duration(seconds: 4);
  static const Duration _kIndoorStallAutoPause = Duration(seconds: 8);
  static const Duration _kRecoveredGpsWindow = Duration(seconds: 3);
  static const Duration _kGpsHealthCheckTick = Duration(seconds: 5);
  static const Duration _kGpsStreamStaleThreshold = Duration(seconds: 5);
  static const Duration _kModeFlipCooldown = Duration(seconds: 30);
  static const double _kModeFlipHighConfidence = 0.95;
  static const int _kPauseCountdownUiThrottleSec = 10;
  final GpsPipeline _gpsPipeline = GpsPipeline();
  DateTime? _lastRouteSnapshotTime;
  static const Duration _kRouteStateSnapshotInterval = Duration(seconds: 5);
  static const int _kMaxGpsDebugEntries = 80;

  WorkoutSessionNotifier(this._ref)
    : _recordingCoordinator = _ref.read(workoutRecordingCoordinatorProvider),
      super(
        WorkoutSessionState(
          status: RecordingState.idle,
          activityType: 'Running',
          trackingMode: kAutoTrackingMode,
          environmentHint: 'detecting',
          recordingSource: 'gps',
        ),
      );

  // State Flush
  void _flushRouteBufferToState({bool force = false}) {
    if (!_gpsPipeline.hasPendingChanges && !force) return;
    final snapshot = _gpsPipeline.createSnapshot();
    _lastRouteSnapshotTime = DateTime.now();
    state = state.copyWith(
      filteredRoutePoints: snapshot.filteredRoutePoints,
      smoothedRoutePoints: snapshot.smoothedRoutePoints,
      routePoints: snapshot.routePoints,
      routeSegments: snapshot.routeSegments,
      smoothedRouteSegments: snapshot.smoothedRouteSegments,
      gpsGapSegments: snapshot.gpsGapSegments,
      gpsDebugEntries: snapshot.gpsDebugEntries,
    );
  }

  // Profile

  void setUserProfile({double? weightKg, double? heightCm, String? gender}) {
    if (weightKg != null && weightKg > 0) _weightKg = weightKg;
    if (heightCm != null && heightCm > 0) _heightCm = heightCm;
    final normalizedGender = _normalizeGender(gender);
    if (normalizedGender != null) _gender = normalizedGender;

    if ((_heightCm ?? 0) > 0) {
      final stride = computeStrideLength(
        activityType: state.activityType,
        heightCm: _heightCm,
        gender: _gender,
      );
      state = state.copyWith(strideLengthMeters: stride);
    }
  }

  // Public API

  bool hasUnfinishedRecordingForOtherUser(String? userId) =>
      _recordingOwnerId != null &&
      _recordingOwnerId != (userId ?? 'local_user') &&
      state.status != RecordingState.finished &&
      state.status != RecordingState.idle;

  void startWorkout(String activityType, {Position? startupGpsLock}) {
    if (state.status == RecordingState.active ||
        state.status == RecordingState.paused ||
        state.status == RecordingState.stopping ||
        state.status == RecordingState.error ||
        state.status == RecordingState.initializing) {
      return; // Never replace an unfinished or unsaved recording.
    }
    final sessionId = const Uuid().v4();
    final stride = computeStrideLength(
      activityType: activityType,
      heightCm: _heightCm,
      gender: _gender,
    );
    final startPlan = _sessionStarter.createPlan(
      sessionId: sessionId,
      activityType: activityType,
      requiresGps: _requiresGpsTracking(activityType),
      strideLengthMeters: stride,
      startedAt: DateTime.now(),
      outdoorMode: kOutdoorMode,
      indoorMode: kIndoorMode,
      recordingSource: _defaultRecordingSource(activityType),
    );
    _resetRuntimeTrackingState();
    _recordingOwnerId = _ref.read(currentUserIdProvider) ?? 'local_user';
    LocalDB.registerRecording(sessionId);
    _legacyEnvironmentHint = startPlan.environmentHint;
    if (kEnableTrajectoryPreprocessing ||
        kEnableTrajectoryPreprocessingShadowMode) {
      _streamingPreprocessor =
          TrajectoryPreprocessor.forActivity(
            activityType,
            debugLocationMode: kDebugLocationMode,
          ).createStreamingSession(
            enableQualityGate: kEnableGpsQualityGate,
            enableShadowMode: kEnableGpsQualityGateShadowMode,
          );
    }
    final startupLockPoint = startupGpsLock == null
        ? null
        : LatLng(startupGpsLock.latitude, startupGpsLock.longitude);

    state = _sessionLifecycle.createInitializingState(
      sessionId: startPlan.sessionId,
      activityType: startPlan.activityType,
      trackingMode: startPlan.trackingMode,
      environmentHint: startPlan.environmentHint,
      recordingSource: startPlan.recordingSource,
      modeDecisionLocked: startPlan.modeDecisionLocked,
      strideLengthMeters: startPlan.strideLengthMeters,
      startedAt: startPlan.startedAt,
    );
    if (startupLockPoint != null) {
      _distanceAnchorPoint = startupLockPoint;
      _lastAcceptedPositionTime = startupGpsLock?.timestamp;
      state = state.copyWith(
        initialPosition: startupLockPoint,
        currentLatLng: startupLockPoint,
        smoothedCurrentLatLng: startupLockPoint,
        filteredRoutePoints: [startupLockPoint],
        smoothedRoutePoints: [startupLockPoint],
        routePoints: [startupLockPoint],
        routeSegments: [
          [startupLockPoint],
        ],
        smoothedRouteSegments: [
          [startupLockPoint],
        ],
        gpsConfidence: GpsConfidence.high,
      );
    }
    // 1. Immediately start stopwatch, UI ticker, calorie and checkpoint timers synchronously
    // so the duration and HUD live metrics are guaranteed to run right away from second 0.
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    _startCalorieTimer();
    _startCheckpointTimer();

    state = _sessionLifecycle.activate(
      current: state,
      recordingSource: startPlan.recordingSource,
    );
    _syncLiveActivityState();

    debugPrint(
      '[Workout] startWorkout $activityType — stride=${stride.toStringAsFixed(2)}m startupLock=${startupLockPoint != null}',
    );

    // 2. Initialize background GPS and step tracking asynchronously without blocking UI timers
    unawaited(_initServicesInBackground(startPlan));
    unawaited(
      _recordingCoordinator.createRemoteWorkoutShell(
        sessionId: startPlan.sessionId,
        startedAt: startPlan.startedAt,
        activityType: startPlan.activityType,
        mode: startPlan.trackingMode,
      ),
    );

    // 3. Start IOD recording; fresh independent estimates may advise the
    // environment hint, never drive the distance source directly.
    _ref.read(iodControllerProvider.notifier).startSession(startPlan.sessionId);
  }

  void onUserDraggedMap() {
    if (!state.followUser) return;
    state = state.copyWith(followUser: false);
  }

  bool requestRecenter() {
    if (state.currentLatLng == null && state.initialPosition == null) {
      return false;
    }
    state = state.copyWith(
      followUser: true,
      recenterRequestId: state.recenterRequestId + 1,
    );
    return true;
  }

  Future<void> _initServicesInBackground(
    WorkoutSessionStartPlan startPlan,
  ) async {
    try {
      if (startPlan.requiresGps) {
        try {
          await _environmentController.start(
            activityType: startPlan.activityType,
            onEvent: _onEnvironmentChanged,
          );
        } catch (e) {
          debugPrint('[Workout] environment controller init error: $e');
        }
        if (mounted) {
          state = _sessionStarter.applyGpsBootstrap(state);
        }
        unawaited(_startGpsBackground(startPlan.activityType));
      } else if (mounted) {
        try {
          await _environmentController.stop();
        } catch (_) {}
        final locationService = _ref.read(locationTrackingServiceProvider);
        final lastKnown = await _sensorController.getLastKnownPosition(
          locationService,
        );
        final seededState = lastKnown == null
            ? state
            : _sensorBootstrapper.applyLastKnownPosition(
                current: state,
                latitude: lastKnown.latitude,
                longitude: lastKnown.longitude,
              );
        state = _sessionStarter.applyIndoorBootstrap(seededState);
        _refreshIndoorWatchdog();
      }
      unawaited(_startStepCounterBackground());
      _refreshIndoorWatchdog();
      debugPrint(
        '[Workout] sensors and tracking successfully initiated in background',
      );
    } catch (e, stack) {
      debugPrint(
        '[Workout] Error initializing sensors in background: $e\n$stack',
      );
    }
  }

  // GPS

  Future<void> _startGpsBackground(String activityType) async {
    debugPrint('[Workout] GPS startup begin at ${DateTime.now()}');
    final locationService = _ref.read(locationTrackingServiceProvider);

    final lastKnown = await _sensorController.getLastKnownPosition(
      locationService,
    );
    if (lastKnown != null &&
        mounted &&
        state.initialPosition == null &&
        state.routePoints.isEmpty) {
      state = _sensorBootstrapper.applyLastKnownPosition(
        current: state,
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
      );
    }

    try {
      await _locationSub?.cancel();
      _locationSub = await _sensorController.startGpsTracking(
        locationService: locationService,
        activityType: activityType,
        onPosition: _onPosition,
        onError: (error, stackTrace) {
          debugPrint('[Workout] GPS stream error: $error');
          _logGpsHealthEvent(
            eventType: kGpsStreamErrorEvent,
            message: kGpsStreamErrorMessage,
            reason: 'stream_error',
            logLevel: 'error',
            error: error,
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_error'));
        },
        onDone: () {
          debugPrint('[Workout] GPS stream done unexpectedly');
          _logGpsHealthEvent(
            eventType: kGpsStreamDoneEvent,
            message: kGpsStreamDoneMessage,
            reason: 'stream_done',
            logLevel: 'warning',
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_done'));
        },
      );
      _lastRecoveryAttemptTime = null;
      _isAwaitingRecoveryEvidence = false;
      _pendingRecoveryReason = null;
      _lastGpsEventTime = DateTime.now();
      _startGpsHealthWatchdog(activityType);
      debugPrint(
        '[Workout] GPS position subscription started (Algorithm: ${_gpsSmoothingService.algorithmName})',
      );
    } catch (e) {
      debugPrint('[Workout] GPS error: $e');
      if (mounted) {
        state = _sensorBootstrapper.applyGpsStartupFailure(
          state,
          e.toString().replaceAll('Exception: ', ''),
          supportsStepFallback: _trackingEngine.supportsStepFallback(
            state.activityType,
          ),
        );
        _refreshIndoorWatchdog();
        _startCalorieTimer();
      }
    }
  }

  void _startGpsHealthWatchdog(String activityType) {
    _gpsHealthTimer?.cancel();
    _gpsHealthTimer = Timer.periodic(_kGpsHealthCheckTick, (_) {
      if (!mounted || state.status != RecordingState.active) return;
      if (!_requiresGpsTracking(state.activityType)) return;

      final lastGpsEventTime = _lastGpsEventTime;
      if (lastGpsEventTime == null) return;
      final silence = DateTime.now().difference(lastGpsEventTime);
      if (silence < _kGpsStreamStaleThreshold) return;

      if (!state.isGpsSignalWeak) {
        final fallbackGapMarker =
            state.currentLatLng ??
            (state.routePoints.isNotEmpty ? state.routePoints.last : null);
        state = state.copyWith(
          isGpsSignalWeak: true,
          gpsGapMarker: fallbackGapMarker,
        );
      }

      debugPrint(
        '[Workout] GPS watchdog detected stalled stream after ${silence.inSeconds}s',
      );
      _logGpsHealthEvent(
        eventType: kGpsStreamStalledEvent,
        message: kGpsStreamStalledMessage,
        reason: 'stale_stream',
        logLevel: 'warning',
        silence: silence,
      );

      final lastAttempt = _lastRecoveryAttemptTime;
      if (lastAttempt != null &&
          DateTime.now().difference(lastAttempt) < _kRecoveryCooldown) {
        debugPrint(
          '[Workout] GPS recovery on cooldown (${silence.inSeconds}s stalled, '
          'cooldown ${_kRecoveryCooldown.inSeconds}s)',
        );
        return;
      }

      unawaited(_recoverGpsStream(activityType, reason: 'stale_stream'));
    });
  }

  Future<void> _recoverGpsStream(
    String activityType, {
    required String reason,
  }) async {
    if (_isRecoveringGpsStream || _isStopping || !mounted) return;
    if (state.status != RecordingState.active) return;

    final now = DateTime.now();
    final lastAttempt = _lastRecoveryAttemptTime;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _kRecoveryCooldown) {
      debugPrint('[Workout] GPS recovery skipped (cooldown active)');
      return;
    }

    _isRecoveringGpsStream = true;
    _lastRecoveryAttemptTime = now;
    final locationService = _ref.read(locationTrackingServiceProvider);

    try {
      debugPrint('[Workout] attempting GPS recovery reason=$reason');
      _logGpsHealthEvent(
        eventType: kGpsRecoveryStartedEvent,
        message: kGpsRecoveryStartedMessage,
        reason: reason,
      );

      // Do NOT pass stale cached fallback (e.g. getLastKnownPosition).
      // Only accept fresh direct sensor readings with verified timestamp.
      final rescuePosition = await locationService
          .getCurrentPositionWithTimeout(timeout: const Duration(seconds: 4));
      if (rescuePosition != null && mounted) {
        final fixTime = rescuePosition.timestamp;
        final age = DateTime.now().difference(fixTime).abs();
        final isRecent = age <= const Duration(seconds: 5);
        final isAfterWorkoutStart =
            state.startedAt == null || !fixTime.isBefore(state.startedAt!);
        final isChronological =
            _rawSignalContinuity.lastRawFixTimestamp == null ||
            fixTime.isAfter(_rawSignalContinuity.lastRawFixTimestamp!);

        if (isRecent && isAfterWorkoutStart && isChronological) {
          _lastGpsEventTime = DateTime.now();
          _onPosition(rescuePosition);
        } else {
          debugPrint(
            '[Workout] ignored stale rescue position: timestamp=$fixTime, age=${age.inSeconds}s',
          );
        }
      }

      await _locationSub?.cancel();
      _locationSub = null;
      if (!mounted || state.status != RecordingState.active || _isStopping) {
        return;
      }

      _locationSub = await _sensorController.startGpsTracking(
        locationService: locationService,
        activityType: activityType,
        onPosition: _onPosition,
        onError: (error, stackTrace) {
          debugPrint('[Workout] GPS stream error during recovery: $error');
          _logGpsHealthEvent(
            eventType: kGpsStreamErrorEvent,
            message: kGpsStreamErrorMessage,
            reason: 'stream_error_during_recovery',
            logLevel: 'error',
            error: error,
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_error'));
        },
        onDone: () {
          debugPrint('[Workout] GPS stream done during recovery');
          _logGpsHealthEvent(
            eventType: kGpsStreamDoneEvent,
            message: kGpsStreamDoneMessage,
            reason: 'stream_done_during_recovery',
            logLevel: 'warning',
          );
          unawaited(_recoverGpsStream(activityType, reason: 'stream_done'));
        },
      );

      // Set awaiting recovery evidence: recovery is only declared succeeded
      // once an actual fresh fix arrives from the restarted stream.
      _isAwaitingRecoveryEvidence = true;
      _pendingRecoveryReason = reason;
      debugPrint(
        '[Workout] GPS stream restarted, awaiting fresh fix evidence...',
      );
    } catch (e) {
      debugPrint('[Workout] GPS recovery failed: $e');
      _logGpsHealthEvent(
        eventType: kGpsRecoveryFailedEvent,
        message: kGpsRecoveryFailedMessage,
        reason: reason,
        logLevel: 'error',
        error: e,
      );
    } finally {
      _isRecoveringGpsStream = false;
    }
  }

  // Steps

  Future<void> _startStepCounterBackground() async {
    if (state.activityType.toLowerCase() == 'cycling') return;
    debugPrint('[Workout] pedometer startup begin at ${DateTime.now()}');
    try {
      final stepService = _ref.read(stepTrackingServiceProvider);
      await _stepSub?.cancel();
      _stepSub = await _sensorController.startWorkoutStepTracking(
        stepService: stepService,
        activityType: state.activityType,
        onStepUpdate: _onStepUpdate,
      );
      debugPrint('[Workout] pedometer subscription active');
    } catch (e) {
      debugPrint('[Workout] pedometer error: $e');
      if (mounted) {
        state = _sensorBootstrapper.applyStepStartupFailure(
          state,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // Session control

  Future<void> pauseWorkout() async {
    if (state.status != RecordingState.active || _isStopping) return;
    _allowOfflineReconstruction = false;
    _flushRouteBufferToState(force: true);
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _gpsHealthTimer?.cancel();
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    state = _sessionLifecycle
        .pause(
          current: state.copyWith(
            durationSeconds: math.max(
              state.durationSeconds,
              _stopwatch.elapsed.inSeconds,
            ),
          ),
          pauseAutoStopRemainingSeconds: _kPauseAutoStopDelay.inSeconds,
        )
        .copyWith(currentCadenceSpm: 0);
    // Capture the pause boundary before any asynchronous sensor shutdown.
    _pauseCheckpointSaved = false;
    final checkpoint = _persistCheckpoint(force: true);
    _startCheckpointTimer(); // Retry a failed pause checkpoint while paused.
    final pause = () async {
      try {
        final locationService = _ref.read(locationTrackingServiceProvider);
        await _sensorController.stopGpsTracking(
          locationService: locationService,
          subscription: _locationSub,
        );
        _locationSub = null;
        final stepService = _ref.read(stepTrackingServiceProvider);
        _sensorController.pauseStepTracking(stepService);
        _stepMotionGate.reset();
      } catch (error, stack) {
        debugPrint('[Workout] Pause sensor shutdown failed: $error\n$stack');
      }
      await checkpoint;
    }();
    _pauseOperation = pause;
    try {
      await pause;
    } finally {
      _pauseOperation = null;
      if (mounted && state.status == RecordingState.paused) {
        _syncLiveActivityState();
        _startPauseAutoStopCountdown();
      }
    }
  }

  Future<void> resumeWorkout() async {
    if (state.status != RecordingState.paused || _isStopping) return;
    await _pauseOperation;
    if (!mounted || state.status != RecordingState.paused || _isStopping) {
      return;
    }
    _cancelPauseAutoStopCountdown();
    _stopwatch.start();
    final stepService = _ref.read(stepTrackingServiceProvider);
    _sensorController.resumeStepTracking(stepService);
    _stepMotionGate.reset();
    _speedSamples.clear();
    _shouldResetGpsAnchorOnResume = true;
    _streamingPreprocessor?.reset();
    _gpsSmoothingService.reset();
    _lastGpsEventTime = DateTime.now();
    _startTicker();
    _startCalorieTimer();
    _startCheckpointTimer();
    if (_requiresGpsTracking(state.activityType)) {
      unawaited(_startGpsBackground(state.activityType));
    }
    state = _sessionLifecycle.resume(state);
    _refreshIndoorWatchdog();
    _syncLiveActivityState();
  }

  Future<void> stopWorkout() async {
    if (_isStopping) {
      debugPrint('[Workout] stopWorkout ignored — stop already in progress');
      return;
    }
    if (state.status != RecordingState.active &&
        state.status != RecordingState.paused &&
        state.status != RecordingState.error) {
      return;
    }
    _isStopping = true;
    // Keep a terminal attempt (and failed retry data) alive even if the route
    // rebuilds. Active tracking itself must not be pinned across sign-out.
    _recordingKeepAlive ??= _ref.keepAlive();

    try {
      _persistence.seal();
      if (_frozenStopState == null) {
        _stopwatch.stop();
        _checkpointTimer?.cancel();
        _uiTicker?.cancel();
        _flushRouteBufferToState(force: true);
        _cancelPauseAutoStopCountdown();
        state = _sessionLifecycle.stopping(
          state.copyWith(
            durationSeconds: math.max(
              state.durationSeconds,
              _stopwatch.elapsed.inSeconds,
            ),
          ),
        );
        _stopRequestedAt = DateTime.now();
        _frozenStopState = state;
        // Pause shutdown may still be running; do not race sensor operations.
        await _pauseOperation;
        try {
          await _shutdownTrackingInfrastructure();
        } catch (error, stack) {
          debugPrint('[Workout] Error shutting down tracking: $error\n$stack');
        }
        try {
          _ref.read(iodControllerProvider.notifier).stopSession();
        } catch (error, stack) {
          debugPrint('[Workout] Error stopping IOD: $error\n$stack');
        }
      } else {
        state = _sessionLifecycle.stopping(_frozenStopState!);
      }

      final currentOwnerId = _ref.read(currentUserIdProvider) ?? 'local_user';
      final resolvedUserId = _recordingOwnerId ??= currentOwnerId;
      if (resolvedUserId != currentOwnerId) {
        throw StateError('Recording owner changed before save');
      }

      final currentProfile = UserProfile(
        id: 'active-session',
        userId: resolvedUserId,
        weightKg: _weightKg,
        heightCm: (_heightCm ?? 170).clamp(50.0, 250.0),
        legacyAge: 0,
        gender: _gender ?? 'male',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      final frozen = _frozenStopState!;
      final finalization = _persistence.freezeFinalization(
        () => _sessionFinalizer.finalize(
          state: frozen,
          userId: resolvedUserId,
          finishedAt: _stopRequestedAt!,
          caloriesBurned: _computeCalories(
            distanceMeters: frozen.distanceMeters,
            durationSec: frozen.durationSeconds,
          ),
          fallbackStrideLengthMeters: _defaultStrideLength(
            frozen.activityType,
            _gender,
          ),
          trackingEngine: _trackingEngine,
          rawGpsPositions: List<Position>.unmodifiable(_rawGpsPositions),
          filteredRouteSegments: List<List<LatLng>>.unmodifiable(
            (frozen.smoothedRouteSegments.isNotEmpty
                    ? frozen.smoothedRouteSegments
                    : frozen.routeSegments)
                .where((segment) => segment.isNotEmpty)
                .map((segment) => List<LatLng>.unmodifiable(segment)),
          ),
          gpsAlgorithm: _gpsSmoothingService.algorithmName,
          enableTrajectoryReconstruction:
              kEnableTrajectoryReconstruction && _allowOfflineReconstruction,
          userProfile: currentProfile,
        ),
      );

      // 1. Wait for every accepted checkpoint to settle before writing the
      // immutable final session. A write failure must not mean "finished".
      final repo = _ref.read(workoutRepositoryProvider);
      await _recordingCoordinator.drainLocalWrites();
      await _persistence.saveFinal(
        (pending) => repo.cacheSessionLocal(pending.session, isSynced: false),
      );
      LocalDB.unregisterRecording(finalization.sessionId);

      try {
        _ref
            .read(workoutListProvider.notifier)
            .insertLocalSession(finalization.session);
      } catch (error, stack) {
        // History presentation is not the durability acknowledgement.
        debugPrint('[Workout] History refresh failed: $error\n$stack');
      }

      // 2. IMMEDIATELY transition state to finished so UI navigates to Summary
      // without waiting on slow network or remote database roundtrips.
      if (mounted) {
        final endedState = _sessionLifecycle
            .finish(
              current: frozen,
              caloriesBurned: finalization.caloriesBurned,
              avgSpeedKmh: finalization.avgSpeedKmh,
              sessionId: finalization.sessionId,
              gpsAnalysis: finalization.gpsAnalysis,
            )
            .copyWith(
              distanceMeters: finalization.session.distanceKm * 1000,
              stepCount: finalization.session.steps,
              lapSplits: finalization.session.lapSplits,
            );
        state = endedState;
        try {
          unawaited(
            _endLiveActivity(endedState).catchError((
              Object error,
              StackTrace stack,
            ) {
              debugPrint('[Workout] Live activity end error: $error\n$stack');
            }),
          );
        } catch (e) {
          debugPrint('[Workout] Live activity end error: $e');
        }
      }

      // 3. Asynchronously synchronize remotely in the background without blocking UI
      unawaited(
        _syncSessionRemoteInBackground(
          finalization: finalization,
          resolvedUserId: finalization.session.userId,
          repo: repo,
        ).catchError((Object error, StackTrace stack) {
          debugPrint('[Workout] Background sync failed: $error\n$stack');
        }),
      );
      _recordingKeepAlive?.close();
      _recordingKeepAlive = null;
    } catch (e, stack) {
      debugPrint('[Workout] Error stopping workout: $e\n$stack');
      // The frozen finalization stays in memory for an idempotent retry. It
      // is not a durable save and must never trigger summary navigation.
      if (mounted && state.status != RecordingState.finished) {
        state = state.copyWith(
          status: RecordingState.error,
          errorMessage: 'recording_save_failed',
        );
      }
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _syncSessionRemoteInBackground({
    required WorkoutSessionFinalization finalization,
    required String resolvedUserId,
    required WorkoutRepository repo,
  }) async {
    bool savedRemotely = false;
    if (resolvedUserId != 'local_user') {
      try {
        await repo
            .saveSessionRemote(finalization.session)
            .timeout(const Duration(seconds: 10));
        savedRemotely = true;
        debugPrint('[Workout] Remote session save succeeded in background');
      } catch (e) {
        // Common real causes worth grepping for in the log:
        //  - 'invalid input syntax for type uuid'  -> bad session id
        //  - 'row-level security policy'           -> user_id != auth.uid()
        //  - TimeoutException                      -> slow network (retried by
        //                                             syncPendingData later)
        debugPrint(
          '[Workout] Remote session save failed or timed out for '
          '${finalization.sessionId}: $e',
        );
      }
    } else {
      // No authenticated user (or a session id that the server would reject):
      // the row stays in the local cache and will be pushed by syncPendingData()
      // once a real user signs in. Without a real auth uid Postgres RLS would
      // reject the insert anyway (auth.uid() must equal user_id).
      debugPrint(
        '[Workout] Session kept local only — no authenticated user '
        '(userId=$resolvedUserId, session=${finalization.sessionId}). '
        'It is NOT in Supabase yet and will sync on next sign-in.',
      );
    }

    if (savedRemotely) {
      try {
        _recordingCoordinator.markRemoteWorkoutShellReady();
        final drained = await _recordingCoordinator
            .flushForFinalization(finalization.sessionId)
            .timeout(const Duration(seconds: 15));
        if (!drained) {
          throw StateError('Raw workout upload still pending');
        }
        // saveSession already persisted the final filtered route and client
        // artifact. Don't send a live snapshot after finalization.
        await _recordingCoordinator.enqueueProcessingForSession(
          finalization.session,
        );
        await _recordingCoordinator.enqueueRouteCorrectionForSession(
          finalization.session,
        );
        await repo.cacheSessionLocal(finalization.session, isSynced: true);
        if (mounted) _ref.invalidate(workoutListProvider);
        return;
      } catch (e) {
        debugPrint('[Workout] Finalization upload/queue pending: $e');
      }
    }

    // Leave local session unsynced until raw upload and job enqueue succeed.
    // The normal sync pass retries the same UUID and idempotent raw records.
    if (resolvedUserId != 'local_user') unawaited(_retryRemoteSync(repo));
  }

  /// Best-effort retry of every session still waiting in the local cache.
  /// [WorkoutRepositoryImpl.syncPendingData] skips unauthorised users, so this
  /// is a no-op when nobody is signed in.
  Future<void> _retryRemoteSync(WorkoutRepository repo) async {
    try {
      await repo.syncPendingData();
      debugPrint('[Workout] Pending-session retry sync finished');
      if (mounted) _ref.invalidate(workoutListProvider);
    } catch (e) {
      debugPrint('[Workout] Pending-session retry sync failed: $e');
    }
  }

  Future<void> _shutdownTrackingInfrastructure() async {
    final locationService = _ref.read(locationTrackingServiceProvider);
    final stepService = _ref.read(stepTrackingServiceProvider);

    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _gpsHealthTimer?.cancel();
    _checkpointTimer?.cancel();
    _uiTicker = null;
    _indoorDistanceTimer = null;
    _calorieTimer = null;
    _gpsHealthTimer = null;
    _checkpointTimer = null;
    _lastModeFlipTime = null;

    await _sensorController.stopGpsTracking(
      locationService: locationService,
      subscription: _locationSub,
    );
    _locationSub = null;

    await _sensorController.stopStepTracking(
      stepService: stepService,
      subscription: _stepSub,
    );
    _stepSub = null;

    await _environmentController.stop();
  }

  void _resetRuntimeTrackingState() {
    _persistence = RecordingPersistence<WorkoutSessionFinalization>();
    _stopRequestedAt = null;
    _frozenStopState = null;
    _recordingOwnerId = null;
    _pauseCheckpointSaved = false;
    _pauseOperation = null;
    _allowOfflineReconstruction = true;
    _gpsPipeline.reset();
    _lastRouteSnapshotTime = null;
    _speedSamples.clear();
    _lastAcceptedPositionTime = null;
    _rawSignalContinuity.reset();
    _lastStepTime = null;
    _lastSessionSteps = 0;
    _lastObservedActiveSensorSteps = 0;
    _pausedStepsOffset = 0;
    _stepMotionGate.reset();
    _lastRawGpsPosition = null;
    _lastMovingGpsAcceptedAt = null;
    _lastGpsEventTime = null;
    _distanceAnchorPoint = null;
    _recordingCoordinator.reset();
    _rawGpsPositions.clear();
    _lastSplitElapsedSec = 0;
    _lastSplitDistanceMeters = 0;
    _nextLapIndex = 1;
    _shouldResetGpsAnchorOnResume = false;
    _isStopping = false;
    _isRecoveringGpsStream = false;
    _isAwaitingRecoveryEvidence = false;
    _pendingRecoveryReason = null;
    _lastRecoveryAttemptTime = null;
    _gpsSmoothingService.reset();
    _streamingPreprocessor?.reset();
    _streamingPreprocessor = null;
    _rawPositionSequence = 0;
    _lastModeFlipTime = null;
    _legacyEnvironmentHint = 'detecting';
  }

  // Calories

  int _computeCalories({double? distanceMeters, int? durationSec}) {
    final profile = UserProfile(
      id: 'active-session',
      userId: _ref.read(currentUserIdProvider) ?? 'active-session',
      weightKg: _weightKg,
      heightCm: (_heightCm ?? 170).clamp(50.0, 250.0),
      legacyAge: 0,
      gender: _gender ?? 'male',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final calculated = WorkoutMetricsCalculator.computeCaloriesKcal(
      profile: profile,
      activityType: state.activityType,
      distanceMeters: distanceMeters ?? state.distanceMeters,
      durationSec: durationSec ?? state.durationSeconds,
      movingDurationSec: state.movingTimeSeconds,
    );
    // Recompute consistently from the current MET estimate.
    return _requiresGpsTracking(state.activityType)
        ? calculated
        : math.max(state.caloriesBurned, calculated);
  }

  void _startCalorieTimer() {
    _calorieTimer?.cancel();
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (state.status != RecordingState.active) return;
      final kcal = _computeCalories();
      state = state.copyWith(caloriesBurned: kcal);
      debugPrint(
        '[Calories] ${kcal}kcal — dist=${(state.distanceMeters / 1000).toStringAsFixed(2)}km weight=${_weightKg}kg',
      );
    });
  }

  void _syncLiveActivityState() {
    final liveActivity = _ref.read(iosLiveActivityServiceProvider);
    final useMetricUnits =
        _ref.read(metricUnitsPreferenceProvider).value ?? true;
    final lang = _ref.read(appLanguageProvider);
    final effectiveStatus = state.isAutoPaused ? 'paused' : state.status.name;
    unawaited(
      liveActivity.syncWorkout(
        activityType: state.activityType,
        trackingMode: state.trackingMode,
        status: effectiveStatus,
        durationSeconds: state.durationSeconds,
        distanceMeters: state.distanceMeters,
        avgSpeedKmh: state.avgSpeedKmh,
        caloriesBurned: state.caloriesBurned,
        useMetricUnits: useMetricUnits,
        languageCode: lang.name,
      ),
    );
  }

  Future<void> _endLiveActivity(WorkoutSessionState finalState) {
    final liveActivity = _ref.read(iosLiveActivityServiceProvider);
    final useMetricUnits =
        _ref.read(metricUnitsPreferenceProvider).value ?? true;
    final lang = _ref.read(appLanguageProvider);
    return liveActivity.endWorkout(
      activityType: finalState.activityType,
      trackingMode: finalState.trackingMode,
      durationSeconds: finalState.durationSeconds,
      distanceMeters: finalState.distanceMeters,
      avgSpeedKmh: finalState.avgSpeedKmh,
      caloriesBurned: finalState.caloriesBurned,
      useMetricUnits: useMetricUnits,
      languageCode: lang.name,
    );
  }

  void _startPauseAutoStopCountdown() {
    _cancelPauseAutoStopCountdown();
    final deadline = DateTime.now().add(_kPauseAutoStopDelay);
    _pauseAutoStopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.status != RecordingState.paused) {
        timer.cancel();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(pausedAutoStopRemainingSeconds: 0);
        debugPrint('[Workout] pause timeout reached, auto-finishing workout');
        unawaited(stopWorkout());
        return;
      }

      if (remaining % _kPauseCountdownUiThrottleSec == 0 || remaining <= 10) {
        state = state.copyWith(pausedAutoStopRemainingSeconds: remaining);
      }
    });
  }

  void _cancelPauseAutoStopCountdown() {
    _pauseAutoStopTimer?.cancel();
    _pauseAutoStopTimer = null;
  }

  // Mode changes

  void _refreshIodEnvironmentHint(IodState iod) {
    if (!mounted ||
        state.status != RecordingState.active ||
        !_requiresGpsTracking(state.activityType) ||
        (state.trackingMode == kIndoorMode && !state.gpsFallbackActive)) {
      return;
    }
    final advice = WorkoutEnvironmentController.resolveIodAdvice(
      workout: state,
      legacyHint: _legacyEnvironmentHint,
      iod: iod,
      now: DateTime.now(),
      lastAcceptedGpsAt: _lastAcceptedPositionTime,
    );
    if (state.environmentHint != advice.hint) {
      state = state.copyWith(environmentHint: advice.hint);
      debugPrint(
        '[Workout][IOD] hint=${advice.hint} '
        'source=${advice.usedForHint ? "deepiod_c_mobile_adapted" : "gps_step_legacy"}',
      );
    }
  }

  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    final nextHint = switch (event.environment) {
      TrackingEnvironment.outdoor => 'outdoor',
      TrackingEnvironment.indoor => 'indoor',
      TrackingEnvironment.detecting => 'detecting',
    };

    if (_requiresGpsTracking(state.activityType)) {
      _legacyEnvironmentHint = nextHint;
      final advice = WorkoutEnvironmentController.resolveIodAdvice(
        workout: state,
        legacyHint: nextHint,
        iod: _ref.read(iodControllerProvider),
        now: DateTime.now(),
        lastAcceptedGpsAt: _lastAcceptedPositionTime,
      );
      state = state.copyWith(environmentHint: advice.hint);
      if (advice.corroborated) {
        debugPrint('[Workout][IOD] independent C-Mobile agrees with $nextHint');
      }

      // Classifier phát hiện indoor + GPS thực sự yếu → kích hoạt step-fallback.
      // Điều kiện kép: environment == indoor VÀ fallbackSuggested (accuracy cao +
      // displacement thấp + steps đang tăng) để tránh false positive.
      // GPS stream không bị tắt — luôn có quyền override về kOutdoorMode ngay
      // khi tín hiệu phục hồi (xem _applyAcceptedGpsSegment).
      final shouldActivateFallback =
          event.environment == TrackingEnvironment.indoor &&
          event.fallbackSuggested &&
          _trackingEngine.supportsStepFallback(state.activityType) &&
          !state.gpsFallbackActive &&
          state.status == RecordingState.active;

      if (shouldActivateFallback) {
        final now = DateTime.now();
        final lastFlip = _lastModeFlipTime;
        final cooldownActive =
            lastFlip != null && now.difference(lastFlip) < _kModeFlipCooldown;
        if (cooldownActive && event.confidence < _kModeFlipHighConfidence) {
          debugPrint(
            '[Workout][HYSTERESIS] outdoor→indoor flip blocked '
            '(cooldown ${now.difference(lastFlip).inSeconds}s < 30s, '
            'confidence=${event.confidence.toStringAsFixed(2)} < 0.95)',
          );
          return;
        }
        _lastModeFlipTime = now;
        state = state.copyWith(
          trackingMode: kIndoorMode,
          recordingSource: 'step_fallback',
          gpsFallbackActive: true,
          // modeDecisionLocked: false → GPS không bị block, luôn có thể
          // override về Outdoor khi tín hiệu phục hồi.
          modeDecisionLocked: false,
        );
        _refreshIndoorWatchdog();
        debugPrint(
          '[Workout][ENV→FALLBACK] Classifier triggered step-fallback '
          'confidence=${event.confidence.toStringAsFixed(2)} reason=${event.reason}',
        );
      } else {
        debugPrint(
          '[Workout][ENV] hint=$nextHint fallbackSuggested=${event.fallbackSuggested} '
          'confidence=${event.confidence.toStringAsFixed(2)} reason=${event.reason}',
        );
      }
      return;
    }

    final newMode = event.environment == TrackingEnvironment.outdoor
        ? kOutdoorMode
        : event.environment == TrackingEnvironment.indoor
        ? kIndoorMode
        : state.trackingMode;
    state = state.copyWith(
      trackingMode: newMode,
      environmentHint: nextHint,
      recordingSource: newMode == kOutdoorMode ? 'gps' : 'step_fallback',
      gpsFallbackActive: newMode == kIndoorMode,
      modeDecisionLocked: true,
      isAutoPaused: false,
    );
    _refreshIndoorWatchdog();
    debugPrint(
      '[Workout][ENV] mode=$newMode recordingSource=${state.recordingSource} '
      'confidence=${event.confidence.toStringAsFixed(2)} reason=${event.reason}',
    );
  }

  // GPS updates

  void _onPosition(Position position) {
    final isGpsPrimary = _requiresGpsTracking(state.activityType);
    final livePoint = LatLng(position.latitude, position.longitude);
    _lastGpsEventTime = DateTime.now();
    if (_isAwaitingRecoveryEvidence) {
      _isAwaitingRecoveryEvidence = false;
      debugPrint('[Workout] GPS recovery succeeded with verified fix');
      _logGpsHealthEvent(
        eventType: kGpsRecoverySucceededEvent,
        message: kGpsRecoverySucceededMessage,
        reason: _pendingRecoveryReason ?? 'stream_restored',
      );
      _pendingRecoveryReason = null;
    }
    final rawGpsDeviceSource =
        state.isGpsSignalWeak || _shouldResetGpsAnchorOnResume
        ? 'geolocator_position_stream_recovery'
        : 'geolocator_position_stream';

    // Multi-source IOD acquisition; neural advice is handled separately.
    _ref.read(iodControllerProvider.notifier).onPositionUpdate(position);

    if (kDebugMode) {
      debugPrint(
        '[Workout][GPS] lat=${position.latitude}, lng=${position.longitude}, '
        'acc=${position.accuracy}, speed=${position.speed} '
        '| mode=${state.trackingMode} env=${state.environmentHint} '
        'source=${state.recordingSource} fallback=${state.gpsFallbackActive}',
      );
    }

    if (state.status == RecordingState.paused) {
      _rawSignalContinuity.reset();
      _rawSignalContinuity.observe(position.timestamp);
      _distanceAnchorPoint = livePoint;
      _lastAcceptedPositionTime = position.timestamp;
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: 0,
        isAutoPaused: false,
      );
      if (kDebugMode) {
        debugPrint('[GPS] paused live update only');
      }
      return;
    }

    if (state.status != RecordingState.active) {
      if (kDebugMode) {
        debugPrint('[Workout][GPS] ignore reason=status_${state.status.name}');
      }
      return;
    }

    _recordingCoordinator.bufferRawGpsPoint(
      position,
      workoutId: state.sessionId,
      deviceSource: rawGpsDeviceSource,
    );
    _rawGpsPositions.add(position);
    _environmentController.addPosition(position);

    // Compare consecutive raw timestamps; rejected stationary fixes still
    // prove the GPS stream is healthy. Ignore stale samples for route updates.
    if (!_rawSignalContinuity.observe(position.timestamp)) {
      if (kDebugMode) {
        debugPrint('[Workout][GPS] ignored out-of-order/duplicate raw fix');
      }
      return;
    }
    _lastRawGpsPosition = position;

    if (!isGpsPrimary && state.trackingMode == kIndoorMode) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      if (kDebugMode) {
        debugPrint('[Workout][GPS] indoor-only activity marker update');
      }
      return;
    }

    if (state.trackingMode == kAutoTrackingMode && !state.modeDecisionLocked) {
      state = state.copyWith(
        currentLatLng: livePoint,
        speedKmh: _computeSmoothedSpeed(),
      );
      if (kDebugMode) {
        debugPrint('[Workout][GPS] ignore reason=auto_detecting_without_lock');
      }
      return;
    }

    final rawSample = TrajectoryRawSample(
      index: _rawPositionSequence++,
      timestamp: position.timestamp,
      point: livePoint,
      altitudeMeters: position.altitude,
      sensorSpeedMs: position.speed,
      accuracyMeters: position.accuracy,
      sensorHeadingDeg: position.heading,
      deviceSource: rawGpsDeviceSource,
    );

    final legacyDecision = _trackingEngine.evaluateGpsUpdate(
      position: position,
      activityType: state.activityType,
      routePoints: state.routePoints,
      currentLatLng: state.currentLatLng,
      distanceAnchorPoint: _distanceAnchorPoint,
      lastAcceptedPositionTime: _lastAcceptedPositionTime,
      rawGpsGapDurationSec: _rawSignalContinuity.pendingGapDurationSec,
      shouldResetAnchorOnResume: _shouldResetGpsAnchorOnResume,
      wasGpsSignalWeak: state.isGpsSignalWeak,
      debugLocationMode: kDebugLocationMode,
    );

    ProcessedTrajectoryPoint? processedSample;
    if (_streamingPreprocessor != null) {
      processedSample = _streamingPreprocessor!.processSample(rawSample);
    }

    if (kEnableTrajectoryPreprocessingShadowMode && processedSample != null) {
      _logTrajectoryPreprocessingShadow(
        index: rawSample.index,
        legacyDecision: legacyDecision,
        processed: processedSample,
      );
    }

    final TrackingGpsDecision decision;
    if (kEnableTrajectoryPreprocessing && processedSample != null) {
      decision = _trackingEngine.resolveTrajectoryPreprocessingDecision(
        legacyDecision: legacyDecision,
        processedSample: processedSample,
        livePoint: livePoint,
        pendingGapDurationSec: _rawSignalContinuity.pendingGapDurationSec,
      );
    } else {
      decision = legacyDecision;
    }

    state = state.copyWith(currentLatLng: decision.previewPoint);
    _recordGpsDecision(
      position: position,
      decision: decision,
      detail: decision.skipReason ?? 'accepted',
    );

    if (decision.type == TrackingGpsDecisionType.skip) {
      if (decision.reason == GpsRejectReason.lowAccuracy) {
        state = state.copyWith(
          isGpsSignalWeak: true,
          isStationaryByGps: false,
          gpsGapMarker:
              state.currentLatLng ??
              (state.routePoints.isNotEmpty ? state.routePoints.last : null),
        );
      } else if (decision.reason == GpsRejectReason.tinySegment) {
        state = state.copyWith(
          isGpsSignalWeak: false,
          isStationaryByGps: true,
        );
      }
      if (kDebugMode) {
        debugPrint('[GPS-SKIP] ${decision.skipReason}');
      }
      return;
    }

    if (decision.type == TrackingGpsDecisionType.seedRoute) {
      _rawSignalContinuity.acknowledgeRouteAnchor();
      _lastAcceptedPositionTime = position.timestamp;
      _distanceAnchorPoint = decision.livePoint;
      _gpsPipeline.seedRoute(decision.livePoint);
      _flushRouteBufferToState(force: true);
      _legacyEnvironmentHint = 'outdoor';
      state = state.copyWith(
        initialPosition: state.initialPosition ?? decision.livePoint,
        currentLatLng: decision.livePoint,
        smoothedCurrentLatLng: decision.livePoint,
        trackingMode: kOutdoorMode,
        environmentHint: 'outdoor',
        recordingSource: 'gps',
        gpsFallbackActive: false,
        isIndoorSyntheticRoute: false,
        gpsConfidence: GpsConfidence.high,
        isStationaryByGps: false,
        speedKmh: 0,
      );
      if (kDebugMode) {
        debugPrint(
          '[Workout][GPS-ACCEPT] first route point seeded; gps pipeline active',
        );
      }
      _recordingCoordinator.queueLiveRouteSnapshot(
        workoutId: state.sessionId,
        routeSegments: _gpsPipeline.routeSegments,
        lastGpsGapDurationSec: state.lastGpsGapDurationSec,
        isGpsSignalWeak: state.isGpsSignalWeak,
      );
      return;
    }

    if (decision.type == TrackingGpsDecisionType.resetAnchor) {
      _rawSignalContinuity.acknowledgeRouteAnchor();
      _shouldResetGpsAnchorOnResume = false;
      _distanceAnchorPoint = decision.livePoint;
      _lastAcceptedPositionTime = position.timestamp;
      if (_gpsPipeline.routePoints.isNotEmpty) {
        _gpsPipeline.appendAcceptedSegment(
          routeCandidate: decision.livePoint,
          displayRoutePoint: decision.livePoint,
          shouldBreakRouteForDisplay: true,
          gpsGapDurationSec: 0,
          shouldAppendSmoothedPoint: true,
        );
        _flushRouteBufferToState(force: true);
      }
      state = state.copyWith(
        currentLatLng: decision.livePoint,
        smoothedCurrentLatLng: decision.livePoint,
        speedKmh: 0,
        isAutoPaused: false,
      );
      if (kDebugMode) {
        debugPrint('[GPS] resume anchor reset');
      }
      _recordingCoordinator.queueLiveRouteSnapshot(
        workoutId: state.sessionId,
        routeSegments: state.routeSegments,
        lastGpsGapDurationSec: state.lastGpsGapDurationSec,
        isGpsSignalWeak: state.isGpsSignalWeak,
      );
      return;
    }

    _applyAcceptedGpsSegment(
      position: position,
      livePoint: decision.livePoint,
      segmentMeters: decision.segmentMeters,
      rawSegmentMeters: decision.rawSegmentMeters,
      routeSegmentMeters: decision.routeSegmentMeters,
      candidateSpeedKmh: decision.candidateSpeedKmh,
      routeCandidate: decision.livePoint,
      shouldAddDistance: decision.shouldAddDistance,
      shouldBreakRouteForDisplay: decision.shouldBreakRouteForDisplay,
      gpsGapDurationSec: decision.gpsGapDurationSec,
      covarianceScale: decision.covarianceScale,
    );
  }

  bool _isOutdoorGpsStationaryLocked(DateTime now) {
    if (!_requiresGpsTracking(state.activityType) ||
        state.recordingSource != 'gps' ||
        state.gpsFallbackActive ||
        state.isGpsSignalWeak) {
      return false;
    }
    final pos = _lastRawGpsPosition;
    if (pos == null || !pos.accuracy.isFinite || pos.accuracy > 15.0) {
      return false;
    }
    final fixRefTime =
        (now.difference(pos.timestamp).inSeconds).abs() <= 120
            ? pos.timestamp
            : _lastGpsEventTime;
    if (fixRefTime == null ||
        now.difference(fixRefTime) > const Duration(seconds: 4)) {
      return false;
    }
    final sensorSpeedMs =
        pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0.0;
    if (sensorSpeedMs >= 0.45 || _isMoving(state.speedKmh, state.activityType)) {
      return false;
    }
    if (_lastMovingGpsAcceptedAt != null &&
        now.difference(_lastMovingGpsAcceptedAt!) <
            const Duration(seconds: 4)) {
      return false;
    }
    final anchor =
        _distanceAnchorPoint ?? state.initialPosition ?? state.currentLatLng;
    if (anchor == null) {
      return false;
    }
    final driftMeters = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      pos.latitude,
      pos.longitude,
    );
    return driftMeters < 2.5;
  }

  // Step updates
  void _onStepUpdate(WorkoutStepUpdate update) {
    if (state.activityType.toLowerCase() == 'cycling') return;
    if (state.status == RecordingState.paused) {
      _lastObservedActiveSensorSteps = update.activeSessionSteps;
      state = state.copyWith(currentCadenceSpm: 0);
      return;
    }

    if (state.status != RecordingState.active) return;

    final rawDelta =
        update.activeSessionSteps >= _lastObservedActiveSensorSteps
            ? update.activeSessionSteps - _lastObservedActiveSensorSteps
            : math.max(0, update.deltaSteps);
    _lastObservedActiveSensorSteps = update.activeSessionSteps;
    _lastSessionSteps = update.totalSessionSteps;

    final gateResult = _stepMotionGate.evaluate(
      rawDelta: rawDelta,
      now: update.timestamp,
      isOutdoorGpsStationaryLocked: _isOutdoorGpsStationaryLocked(
        update.timestamp,
      ),
    );

    final acceptedSteps = state.stepCount + gateResult.acceptedDelta;
    final stepDecision = _trackingEngine.evaluateStepUpdate(
      sessionSteps: acceptedSteps,
      currentStepCount: state.stepCount,
      activityType: state.activityType,
      requiresGpsTracking: _requiresGpsTracking(state.activityType),
      gpsFallbackActive: state.gpsFallbackActive,
      recordingSource: state.recordingSource,
      lastAcceptedPositionTime: _lastAcceptedPositionTime,
      now: update.timestamp,
    );

    final delta = stepDecision.delta;
    final effectiveCadenceSpm = gateResult.isActivelyStepping
        ? update.currentCadenceSpm
        : 0;
    final effectiveAvgCadenceSpm =
        acceptedSteps > 0 && state.movingTimeSeconds > 0
            ? ((acceptedSteps * 60.0) / state.movingTimeSeconds)
                  .round()
                  .clamp(0, 270)
            : (acceptedSteps > 0 ? update.avgCadenceSpm : 0);

    state = state.copyWith(
      stepCount: acceptedSteps,
      researchDetectedSteps:
          state.researchDetectedSteps +
          (update.source == StepSensorSource.oxfordWpd
              ? math.max(0, delta)
              : 0),
      xuDetectedSteps:
          state.xuDetectedSteps +
          (update.source == StepSensorSource.xuRunning
              ? math.max(0, delta)
              : 0),
      currentCadenceSpm: effectiveCadenceSpm,
      avgCadenceSpm: effectiveAvgCadenceSpm,
    );

    if (delta <= 0) return;

    _recordingCoordinator.bufferRawStepInterval(
      delta,
      startedAt: state.startedAt,
      workoutId: state.sessionId,
      observationTime: update.timestamp,
      deviceSource: update.source.name,
    );
    _environmentController.addStepDelta(delta);
    _ref.read(iodControllerProvider.notifier).onStepDelta(delta);

    if (stepDecision.shouldActivateGpsFallback) {
      state = state.copyWith(
        trackingMode: kIndoorMode,
        recordingSource: 'step_fallback',
        gpsFallbackActive: true,
        modeDecisionLocked: false,
      );
      _refreshIndoorWatchdog();
      debugPrint('[Workout][FALLBACK] gps weak -> step_fallback active');
    }

    if (!_requiresGpsTracking(state.activityType) || state.gpsFallbackActive) {
      _updateIndoorDistanceFromSteps(
        delta,
        cadenceSpm: update.isCadenceAvailable ? update.currentCadenceSpm : null,
      );
    }
  }

  @visibleForTesting
  void onStep(int sessionSteps) {
    if (state.status == RecordingState.paused) {
      // Collect steps occurred during pause into offset
      if (_lastSessionSteps > 0 && sessionSteps > _lastSessionSteps) {
        _pausedStepsOffset += (sessionSteps - _lastSessionSteps);
      }
      _lastSessionSteps = sessionSteps;
      state = state.copyWith(currentCadenceSpm: 0);
      return;
    }

    if (state.status != RecordingState.active) return;

    if (_lastSessionSteps == 0) {
      _lastSessionSteps = sessionSteps;
    }

    final effectiveSteps = math.max(0, sessionSteps - _pausedStepsOffset);
    final delta = effectiveSteps - _lastObservedActiveSensorSteps;

    _onStepUpdate(
      WorkoutStepUpdate(
        totalSessionSteps: sessionSteps,
        activeSessionSteps: effectiveSteps,
        deltaSteps: math.max(0, delta),
        currentCadenceSpm: state.currentCadenceSpm,
        avgCadenceSpm: state.avgCadenceSpm,
        timestamp: DateTime.now(),
        isPaused: false,
        source: StepSensorSource.unknown,
      ),
    );
  }

  // Indoor distance

  void _updateIndoorDistanceFromSteps(int newSteps, {int? cadenceSpm}) {
    _allowOfflineReconstruction = false;
    final researchLength =
        ResearchWalkingStepLength.estimateMeters(
          activityType: state.activityType,
          heightCm: _heightCm,
          cadenceSpm: cadenceSpm,
        ) ??
        ResearchRunningStepLength.estimateMeters(
          activityType: state.activityType,
          heightCm: _heightCm,
          cadenceSpm: cadenceSpm,
        );
    final now = DateTime.now();
    final contribution = _trackingEngine.computeIndoorStepContribution(
      stepDelta: newSteps,
      strideLengthMeters: researchLength ?? state.strideLengthMeters,
      now: now,
      lastStepTime: _lastStepTime,
    );

    if (contribution.instantSpeedKmh != null) {
      _addSpeedSample(contribution.instantSpeedKmh!);
    }

    _lastStepTime = now;
    final newDistanceM =
        state.distanceMeters + contribution.addedDistanceMeters;
    final newSpeedKmh = _computeSmoothedSpeed();
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      durationSec: state.durationSeconds,
    );

    state = state.copyWith(
      distanceMeters: newDistanceM,
      stepDistanceMeters:
          state.stepDistanceMeters + contribution.addedDistanceMeters,
      adaptiveStepCount:
          state.adaptiveStepCount + (researchLength != null ? newSteps : 0),
      speedKmh: newSpeedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
    );
    // A step length has no measured geographic direction. Keep the last
    // genuine GNSS route and do not invent a geographic indoor path.
  }

  void _applyAcceptedGpsSegment({
    required Position position,
    required LatLng livePoint,
    required double segmentMeters,
    required double rawSegmentMeters,
    required double routeSegmentMeters,
    required double candidateSpeedKmh,
    required LatLng routeCandidate,
    required bool shouldAddDistance,
    required bool shouldBreakRouteForDisplay,
    required double gpsGapDurationSec,
    double covarianceScale = 1.0,
  }) {
    final recoveringFromSteps =
        state.gpsFallbackActive && state.stepDistanceMeters > 0;
    if (recoveringFromSteps) {
      shouldAddDistance = false;
      shouldBreakRouteForDisplay = true;
    }
    if (shouldAddDistance && candidateSpeedKmh > 0) {
      _addSpeedSample(candidateSpeedKmh);
    }
    final smoothedKmh = _computeSmoothedSpeed();

    final lastRoutePoint = _gpsPipeline.filteredRoutePoints.isNotEmpty
        ? _gpsPipeline.filteredRoutePoints.last
        : null;
    final lastSmoothedRoutePoint = _gpsPipeline.smoothedRoutePoints.isNotEmpty
        ? _gpsPipeline.smoothedRoutePoints.last
        : null;
    final timeDeltaSec = gpsGapDurationSec > 0
        ? gpsGapDurationSec
        : (_lastAcceptedPositionTime == null
              ? 0.0
              : position.timestamp
                        .difference(_lastAcceptedPositionTime!)
                        .inMilliseconds /
                    1000.0);
    final effectiveAccuracy = covarianceScale > 1.0
        ? position.accuracy * math.sqrt(covarianceScale)
        : position.accuracy;
    final smoothingUpdate = _gpsSmoothingService.smoothAcceptedPoint(
      activityType: state.activityType,
      acceptedPoint: routeCandidate,
      previousAcceptedPoint: lastRoutePoint,
      previousSmoothedPoint: state.smoothedCurrentLatLng,
      lastSmoothedRoutePoint: lastSmoothedRoutePoint,
      accuracyMeters: effectiveAccuracy,
      speedMs: position.speed,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
      sensorHeadingDeg:
          position.headingAccuracy.isFinite &&
              position.headingAccuracy > 0 &&
              position.headingAccuracy <= 45
          ? position.heading
          : null,
      resetAnchor: shouldBreakRouteForDisplay,
    );
    final displayRoutePoint = shouldBreakRouteForDisplay
        ? routeCandidate
        : smoothingUpdate.smoothedPoint;

    // Append to mutable GpsPipeline buffer O(1)
    _gpsPipeline.appendAcceptedSegment(
      routeCandidate: routeCandidate,
      displayRoutePoint: displayRoutePoint,
      shouldBreakRouteForDisplay: shouldBreakRouteForDisplay,
      gpsGapDurationSec: gpsGapDurationSec,
      shouldAppendSmoothedPoint: smoothingUpdate.shouldAppendRoutePoint,
    );

    final distanceDelta = shouldAddDistance ? segmentMeters : 0.0;
    final newDistanceM = state.distanceMeters + distanceDelta;
    final newCalories = _computeCalories(
      distanceMeters: newDistanceM,
      durationSec: state.durationSeconds,
    );
    if (state.gpsFallbackActive) {
      _lastModeFlipTime = DateTime.now();
    }
    _lastAcceptedPositionTime = position.timestamp;
    _rawSignalContinuity.acknowledgeRouteAnchor();
    _distanceAnchorPoint = livePoint;

    if (shouldAddDistance && segmentMeters > 0) {
      _lastMovingGpsAcceptedAt = position.timestamp;
    }

    // Update lightweight metrics state (1Hz)
    _legacyEnvironmentHint = 'outdoor';
    state = state.copyWith(
      trackingMode: kOutdoorMode,
      environmentHint: 'outdoor',
      recordingSource: 'gps',
      gpsFallbackActive: false,
      currentLatLng: livePoint,
      smoothedCurrentLatLng: displayRoutePoint,
      gpsGapMarker: shouldBreakRouteForDisplay
          ? routeCandidate
          : state.gpsGapMarker,
      isIndoorSyntheticRoute: false,
      gpsConfidence: smoothingUpdate.confidence,
      isStationaryByGps: smoothingUpdate.isStationary,
      distanceMeters: newDistanceM,
      gpsDistanceMeters: state.gpsDistanceMeters + distanceDelta,
      speedKmh: shouldAddDistance ? smoothedKmh : 0,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
      isGpsSignalWeak: false,
      lastGpsGapDurationSec: gpsGapDurationSec,
    );

    // Periodic snapshot to state every 5s or on route break
    final now = DateTime.now();
    final lastSnap = _lastRouteSnapshotTime;
    final shouldSnapshot =
        shouldBreakRouteForDisplay ||
        lastSnap == null ||
        now.difference(lastSnap) >= _kRouteStateSnapshotInterval;
    if (shouldSnapshot) {
      _flushRouteBufferToState(force: true);
    }

    if (kDebugMode) {
      debugPrint(
        '[Workout][GPS-ACCEPT] segment=${segmentMeters.toStringAsFixed(2)}m '
        'raw=${rawSegmentMeters.toStringAsFixed(2)}m '
        'route=${routeSegmentMeters.toStringAsFixed(2)}m '
        'total=${newDistanceM.toStringAsFixed(2)}m routePoints=${_gpsPipeline.totalRoutePointsCount} '
        'source=gps addDistance=$shouldAddDistance breakDisplay=$shouldBreakRouteForDisplay '
        'gap=${gpsGapDurationSec.toStringAsFixed(1)}s',
      );
    }
    _recordingCoordinator.queueLiveRouteSnapshot(
      workoutId: state.sessionId,
      routeSegments: _gpsPipeline.routeSegments,
      lastGpsGapDurationSec: gpsGapDurationSec,
      isGpsSignalWeak: state.isGpsSignalWeak,
    );
  }

  void _recordGpsDecision({
    required Position position,
    required TrackingGpsDecision decision,
    required String detail,
  }) {
    final previousAcceptedTime = _lastAcceptedPositionTime;
    final timeDeltaSec = previousAcceptedTime == null
        ? 0.0
        : position.timestamp.difference(previousAcceptedTime).inMilliseconds /
              1000.0;
    final debugEntry = GpsValidationDebugEntry.fromPosition(
      position: position,
      outcome: decision.outcome,
      reason: decision.reason,
      segmentMeters: decision.segmentMeters,
      routeSegmentMeters: decision.routeSegmentMeters,
      timeDeltaSec: timeDeltaSec,
      detail: detail,
    );
    _gpsPipeline.addDebugEntry(debugEntry, maxEntries: _kMaxGpsDebugEntries);

    if (kDebugMode) {
      debugPrint(
        '[GPS-VALIDATION] outcome=${decision.outcome.name} reason=${decision.reason.name} '
        'lat=${position.latitude.toStringAsFixed(6)} lng=${position.longitude.toStringAsFixed(6)} '
        'acc=${position.accuracy.toStringAsFixed(1)} speed=${position.speed.toStringAsFixed(2)} '
        'segment=${decision.segmentMeters.toStringAsFixed(2)} route=${decision.routeSegmentMeters.toStringAsFixed(2)} '
        'detail=$detail',
      );
    }
  }

  void _logTrajectoryPreprocessingShadow({
    required int index,
    required TrackingGpsDecision legacyDecision,
    required ProcessedTrajectoryPoint processed,
  }) {
    final legacyAccepted =
        legacyDecision.type == TrackingGpsDecisionType.acceptRoute ||
        legacyDecision.type == TrackingGpsDecisionType.seedRoute ||
        legacyDecision.type == TrackingGpsDecisionType.resetAnchor;
    final preprocessorAccepted = processed.isAccepted;

    if (legacyAccepted != preprocessorAccepted) {
      debugPrint(
        '[GPS-SHADOW-DIVERGENCE] #$index '
        'legacy=${legacyDecision.type.name}(${legacyDecision.reason.name}) vs '
        'preprocessor=${preprocessorAccepted ? "accept" : "reject"}(${processed.qualityFlags})',
      );
    }
  }

  void _refreshIndoorWatchdog() {
    _indoorDistanceTimer?.cancel();
    _indoorDistanceTimer = null;

    final isIndoorFallbackActive = !_requiresGpsTracking(state.activityType)
        ? state.trackingMode == kIndoorMode
        : state.gpsFallbackActive;
    if (state.status != RecordingState.active || !isIndoorFallbackActive) {
      return;
    }

    _indoorDistanceTimer = Timer.periodic(_kIndoorWatchdogTick, (_) {
      if (!mounted) return;
      final stillIndoorFallbackActive =
          !_requiresGpsTracking(state.activityType)
          ? state.trackingMode == kIndoorMode
          : state.gpsFallbackActive;
      if (state.status != RecordingState.active || !stillIndoorFallbackActive) {
        _indoorDistanceTimer?.cancel();
        _indoorDistanceTimer = null;
        return;
      }

      final now = DateTime.now();
      final secondsSinceStep = _lastStepTime == null
          ? 999
          : now.difference(_lastStepTime!).inSeconds;
      final secondsSinceGps = _lastAcceptedPositionTime == null
          ? 999
          : now.difference(_lastAcceptedPositionTime!).inSeconds;

      if (secondsSinceStep <= _kIndoorStepGrace.inSeconds) {
        return;
      }

      if (secondsSinceGps <= _kRecoveredGpsWindow.inSeconds) {
        final now = DateTime.now();
        final lastFlip = _lastModeFlipTime;
        final cooldownActive =
            lastFlip != null && now.difference(lastFlip) < _kModeFlipCooldown;
        if (cooldownActive) {
          debugPrint(
            '[Workout][HYSTERESIS] indoor→outdoor flip blocked '
            '(cooldown ${now.difference(lastFlip).inSeconds}s < 30s)',
          );
          return;
        }
        _lastModeFlipTime = now;
        _shouldResetGpsAnchorOnResume = true;
        _speedSamples.clear();
        state = state.copyWith(
          trackingMode: kOutdoorMode,
          recordingSource: 'gps',
          gpsFallbackActive: false,
          modeDecisionLocked: true,
          isAutoPaused: false,
          speedKmh: 0,
        );
        _refreshIndoorWatchdog();
        debugPrint(
          '[Workout][FALLBACK] gps recovered after fallback '
          '(step stall ${secondsSinceStep}s)',
        );
        return;
      }

      if (secondsSinceStep >= _kIndoorStallAutoPause.inSeconds) {
        state = state.copyWith(speedKmh: 0, isAutoPaused: true);
        debugPrint(
          '[Workout][FALLBACK] indoor watchdog stall '
          '(steps=${secondsSinceStep}s gps=${secondsSinceGps}s)',
        );
      }
    });
  }

  // UI ticker

  void _startTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Recheck freshness when the IOD stream stops delivering epochs.
      _refreshIodEnvironmentHint(_ref.read(iodControllerProvider));

      final elapsedSec = _stopwatch.elapsed.inSeconds;
      var liveSpeedKmh = state.speedKmh;
      var movingTimeSec = state.movingTimeSeconds;
      var isAutoPaused = state.isAutoPaused;

      if (state.recordingSource == 'step_fallback' &&
          _lastStepTime != null &&
          DateTime.now().difference(_lastStepTime!).inSeconds >= 3) {
        liveSpeedKmh = 0;
        isAutoPaused = true;
      }

      if (state.recordingSource == 'gps') {
        final lastRawTime = _rawSignalContinuity.lastRawFixTimestamp;
        final hasRawGpsOutage =
            lastRawTime != null &&
            DateTime.now().difference(lastRawTime).inSeconds >= 5;

        if (hasRawGpsOutage) {
          state = _sessionLifecycle.markGpsSignalWeak(current: state);
          // Grace period: for the first 5 seconds of signal loss, hold motion.
          // Beyond 5 seconds without sensor evidence, do not assume continuous
          // movement indefinitely until GPS or steps recover.
          final outageSec = DateTime.now().difference(lastRawTime).inSeconds;
          if (outageSec > 5) {
            liveSpeedKmh = 0;
          } else {
            liveSpeedKmh = state.speedKmh;
          }
          isAutoPaused = false;
        } else if (_lastAcceptedPositionTime != null &&
            DateTime.now().difference(_lastAcceptedPositionTime!).inSeconds >=
                5) {
          // Raw stream is healthy, but fixes are filtered (stationary).
          // Do NOT mark GPS signal weak; user is stationary.
          liveSpeedKmh = 0;
          isAutoPaused = false;
        }
      }

      if (_isMoving(liveSpeedKmh, state.activityType)) {
        movingTimeSec += 1;
        isAutoPaused = false;
      }

      final distKm = state.distanceMeters / 1000.0;
      final elapsedHours = elapsedSec / 3600.0;
      final avg = elapsedHours > 0 && distKm > 0.001
          ? (distKm / elapsedHours)
          : 0.0;

      final lastStepAccepted = _stepMotionGate.lastAcceptedStepTime;
      final cadenceExpired =
          lastStepAccepted == null ||
          DateTime.now().difference(lastStepAccepted) >
              StepMotionGate.kActiveBoutTimeout;

      state = state.copyWith(
        durationSeconds: elapsedSec,
        movingTimeSeconds: movingTimeSec,
        speedKmh: liveSpeedKmh,
        avgSpeedKmh: avg,
        currentCadenceSpm: cadenceExpired ? 0 : state.currentCadenceSpm,
        isAutoPaused: isAutoPaused,
      );
      _syncLiveActivityState();
    });
  }

  double _computeSmoothedSpeed() {
    if (_speedSamples.isEmpty) return 0;
    final samples = _speedSamples.toList();
    double weightedSum = 0;
    double weightSum = 0;
    for (var i = 0; i < samples.length; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += samples[i] * weight;
      weightSum += weight;
    }
    return weightSum > 0 ? weightedSum / weightSum : 0;
  }

  void _addSpeedSample(double speedKmh) {
    _speedSamples.addLast(speedKmh.clamp(0.0, 60.0));
    if (_speedSamples.length > _speedWindowSize) {
      _speedSamples.removeFirst();
    }
  }

  void _logGpsHealthEvent({
    required String eventType,
    required String message,
    required String reason,
    String logLevel = 'info',
    Object? error,
    Duration? silence,
    Map<String, dynamic>? payloadOverrides,
  }) {
    final workoutId = state.sessionId;
    if (workoutId == null || workoutId.isEmpty) return;

    final lastGpsAgeSeconds = _lastGpsEventTime == null
        ? null
        : DateTime.now().difference(_lastGpsEventTime!).inSeconds;

    final payload = <String, dynamic>{
      'reason': reason,
      'activity_type': state.activityType,
      'tracking_mode': state.trackingMode,
      'recording_source': state.recordingSource,
      'gps_fallback_active': state.gpsFallbackActive,
      'mode_decision_locked': state.modeDecisionLocked,
      'recording_status': state.status.name,
      'duration_seconds': state.durationSeconds,
      'distance_meters': state.distanceMeters,
      'avg_speed_kmh': state.avgSpeedKmh,
      'route_point_count': state.routePoints.length,
      'last_gps_event_age_sec': lastGpsAgeSeconds,
      if (silence != null) 'stream_silence_sec': silence.inSeconds,
      if (error != null) 'error': error.toString(),
      ...?payloadOverrides,
    };

    unawaited(
      _recordingCoordinator.logProcessingEvent(
        workoutId: workoutId,
        eventType: eventType,
        message: message,
        payload: payload,
        logLevel: logLevel,
      ),
    );
  }

  bool _isMoving(double speedKmh, String activityType) {
    return _trackingEngine.isMoving(speedKmh, activityType);
  }

  List<WorkoutLapSplit> _captureLapSplits(double totalDistanceMeters) {
    var splits = state.lapSplits;
    while (totalDistanceMeters >= _nextLapIndex * 1000.0) {
      final lapDistanceMeters =
          (_nextLapIndex * 1000.0) - _lastSplitDistanceMeters;
      final elapsedSec = _stopwatch.elapsed.inSeconds;
      final lapDurationSec = math.max(1, elapsedSec - _lastSplitElapsedSec);
      final lapDistanceKm = lapDistanceMeters / 1000.0;
      final lapPace = lapDistanceKm > 0
          ? lapDurationSec / 60.0 / lapDistanceKm
          : 0.0;

      splits = [
        ...splits,
        WorkoutLapSplit(
          index: _nextLapIndex,
          distanceKm: lapDistanceKm,
          durationSeconds: lapDurationSec,
          paceMinPerKm: lapPace,
        ),
      ];
      _lastSplitElapsedSec = elapsedSec;
      _lastSplitDistanceMeters = _nextLapIndex * 1000.0;
      _nextLapIndex += 1;
    }
    return splits;
  }

  // Crash-recovery checkpointing (H4)
  // Summary writes do not make raw GPS/step records atomic or flush the
  // coordinator's outstanding async writes. A process kill or disk error
  // can lose the most recent summary and any raw samples not yet durable.
  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_persistCheckpoint());
    });
  }

  Future<void> _persistCheckpoint({bool force = false}) async {
    if (!mounted ||
        _persistence.isSealed ||
        (!force && _persistence.hasPendingCheckpoint) ||
        (!force &&
            state.status == RecordingState.paused &&
            _pauseCheckpointSaved) ||
        (state.status != RecordingState.active &&
            state.status != RecordingState.paused)) {
      return;
    }
    // Save early, not only after a long run; an empty session is not a workout.
    if (state.durationSeconds <= 0 &&
        state.distanceMeters <= 0 &&
        state.stepCount <= 0) {
      return;
    }

    try {
      final isPauseSnapshot = state.status == RecordingState.paused;
      final userId = _recordingOwnerId ??=
          _ref.read(currentUserIdProvider) ?? 'local_user';
      _flushRouteBufferToState(force: true);
      final currentProfile = UserProfile(
        id: 'active-session',
        userId: userId,
        weightKg: _weightKg,
        heightCm: (_heightCm ?? 170).clamp(50.0, 250.0),
        legacyAge: 0,
        gender: _gender ?? 'male',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final finalization = _sessionFinalizer.finalize(
        state: state,
        userId: userId,
        finishedAt: DateTime.now(),
        caloriesBurned: state.caloriesBurned,
        fallbackStrideLengthMeters: _defaultStrideLength(
          state.activityType,
          _gender,
        ),
        trackingEngine: _trackingEngine,
        rawGpsPositions: List<Position>.unmodifiable(_rawGpsPositions),
        filteredRouteSegments: List<List<LatLng>>.unmodifiable(
          (state.smoothedRouteSegments.isNotEmpty
                  ? state.smoothedRouteSegments
                  : state.routeSegments)
              .where((segment) => segment.isNotEmpty)
              .map((segment) => List<LatLng>.unmodifiable(segment)),
        ),
        gpsAlgorithm: _gpsSmoothingService.algorithmName,
        enableTrajectoryReconstruction: false,
        userProfile: currentProfile,
      );

      final repo = _ref.read(workoutRepositoryProvider);
      // A checkpoint is a recoverable partial summary, not a final artifact.
      // Repository sync must preserve this distinction.
      final checkpointMetrics =
          jsonDecode(finalization.session.routeMatchMetricsJson)
              as Map<String, dynamic>;
      final checkpointSession = finalization.session.copyWith(
        routeMatchMetricsJson: jsonEncode({
          ...checkpointMetrics,
          'recording_checkpoint': true,
        }),
      );
      await _persistence.checkpoint(
        () async {
          await repo.cacheSessionLocal(checkpointSession, isSynced: false);
          if (isPauseSnapshot) _pauseCheckpointSaved = true;
        },
        force: force,
        onError: (error, stack) {
          debugPrint(
            '[Workout] Checkpoint write failed; next tick/pause retries: $error\n$stack',
          );
        },
      );
    } catch (e) {
      debugPrint('[Workout] Checkpoint persist error: $e');
    }
  }

  // Cleanup

  @override
  void dispose() {
    _persistence.seal();
    final sessionId = state.sessionId;
    if (sessionId != null) {
      unawaited(
        _persistence.drained.whenComplete(
          () => LocalDB.unregisterRecording(sessionId),
        ),
      );
    }
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _pauseAutoStopTimer?.cancel();
    _gpsHealthTimer?.cancel();
    _checkpointTimer?.cancel();
    _locationSub?.cancel();
    _stepSub?.cancel();
    unawaited(_environmentController.stop());
    _recordingCoordinator.dispose();
    super.dispose();
  }
}
