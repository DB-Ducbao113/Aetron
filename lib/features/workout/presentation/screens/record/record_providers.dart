import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:fitness_exercise_application/features/workout/data/local/schema/local_gps_point.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
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
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_metrics_calculator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  if (heightCm == null || heightCm <= 0) {
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
    >((ref) => WorkoutSessionNotifier(ref));

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
  StreamSubscription<int>? _stepSub;

  // Timers
  Timer? _uiTicker;
  Timer? _indoorDistanceTimer;
  Timer? _calorieTimer;
  Timer? _pauseAutoStopTimer;
  Timer? _gpsHealthTimer;
  Timer? _checkpointTimer;

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
  int _pausedStepsOffset = 0;
  // Raw GPS anchor used for distance accumulation only.
  LatLng? _distanceAnchorPoint;
  int _lastSplitElapsedSec = 0;
  double _lastSplitDistanceMeters = 0;
  int _nextLapIndex = 1;
  bool _shouldResetGpsAnchorOnResume = false;
  bool _isStopping = false;
  bool _isRecoveringGpsStream = false;
  DateTime? _lastRecoveryAttemptTime;
  static const Duration _kRecoveryCooldown = Duration(seconds: 15);
  bool _isAwaitingRecoveryEvidence = false;
  String? _pendingRecoveryReason;
  DateTime? _lastGpsEventTime;
  DateTime? _lastModeFlipTime;
  final List<Position> _rawGpsPositions = [];
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

  void startWorkout(String activityType, {Position? startupGpsLock}) {
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

    // 3. Start Indoor-Outdoor Detection (IOD) observational recording
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
    debugPrint('[Workout] pedometer startup begin at ${DateTime.now()}');
    try {
      final stepService = _ref.read(stepTrackingServiceProvider);
      await _stepSub?.cancel();
      _stepSub = await _sensorController.startStepTracking(
        stepService: stepService,
        onStep: _onStep,
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
    _flushRouteBufferToState(force: true);
    _stopwatch.stop();
    _uiTicker?.cancel();
    _indoorDistanceTimer?.cancel();
    _calorieTimer?.cancel();
    _gpsHealthTimer?.cancel();
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    final locationService = _ref.read(locationTrackingServiceProvider);
    await _sensorController.stopGpsTracking(
      locationService: locationService,
      subscription: _locationSub,
    );
    _locationSub = null;
    _stepSub?.pause();
    state = _sessionLifecycle.pause(
      current: state,
      pauseAutoStopRemainingSeconds: _kPauseAutoStopDelay.inSeconds,
    );
    _syncLiveActivityState();
    _startPauseAutoStopCountdown();
  }

  Future<void> resumeWorkout() async {
    _cancelPauseAutoStopCountdown();
    _stopwatch.start();
    _stepSub?.resume();
    _speedSamples.clear();
    _shouldResetGpsAnchorOnResume = true;
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
    _isStopping = true;

    try {
      _flushRouteBufferToState(force: true);
      _cancelPauseAutoStopCountdown();
      state = _sessionLifecycle.stopping(state);

      try {
        await _shutdownTrackingInfrastructure();
      } catch (e) {
        debugPrint('[Workout] Error shutting down tracking: $e');
      }

      // Stop Indoor-Outdoor Detection (IOD) recording
      _ref.read(iodControllerProvider.notifier).stopSession();

      final finishedAt = DateTime.now();
      final finalCalories = _computeCalories(
        distanceMeters: state.distanceMeters,
        durationSec: state.durationSeconds,
      );

      final resolvedUserId =
          _ref.read(currentUserIdProvider) ??
          Supabase.instance.client.auth.currentUser?.id ??
          'local_user';

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

      final finalization = _sessionFinalizer.finalize(
        state: state,
        userId: resolvedUserId,
        finishedAt: finishedAt,
        caloriesBurned: finalCalories,
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
        userProfile: currentProfile,
      );

      // 1. Immediately cache locally with safe error handling
      final repo = _ref.read(workoutRepositoryProvider);
      try {
        await repo.cacheSessionLocal(finalization.session, isSynced: false);
      } catch (e) {
        debugPrint('[Workout] Local session cache error: $e');
      }
      // Show the finished session in History/Analytics right away instead of
      // invalidating (the refetch would race the background remote save and
      // return a list without this session on web).
      _ref
          .read(workoutListProvider.notifier)
          .insertLocalSession(finalization.session);

      // 2. IMMEDIATELY transition state to finished so UI navigates to Summary
      // without waiting on slow network or remote database roundtrips.
      if (mounted) {
        final endedState = _sessionLifecycle.finish(
          current: state,
          caloriesBurned: finalization.caloriesBurned,
          avgSpeedKmh: finalization.avgSpeedKmh,
          sessionId: finalization.sessionId,
          gpsAnalysis: finalization.gpsAnalysis,
        );
        state = endedState;
        try {
          unawaited(_endLiveActivity(endedState));
        } catch (e) {
          debugPrint('[Workout] Live activity end error: $e');
        }
      }

      // 3. Asynchronously synchronize remotely in the background without blocking UI
      unawaited(
        _syncSessionRemoteInBackground(
          finalization: finalization,
          resolvedUserId: resolvedUserId,
          routeSegments: List<List<LatLng>>.unmodifiable(
            state.smoothedRouteSegments.isNotEmpty
                ? state.smoothedRouteSegments
                : state.routeSegments,
          ),
          lastGpsGapDurationSec: state.lastGpsGapDurationSec,
          isGpsSignalWeak: state.isGpsSignalWeak,
        ),
      );
    } catch (e, stack) {
      debugPrint('[Workout] Error stopping workout: $e\n$stack');
      // Emergency recovery: Transition to finished so user is never trapped in stopping state
      if (mounted && state.status != RecordingState.finished) {
        final emergencySessionId =
            state.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
        state = state.copyWith(
          status: RecordingState.finished,
          sessionId: emergencySessionId,
        );
      }
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _syncSessionRemoteInBackground({
    required WorkoutSessionFinalization finalization,
    required String resolvedUserId,
    required List<List<LatLng>> routeSegments,
    required double lastGpsGapDurationSec,
    required bool isGpsSignalWeak,
  }) async {
    final repo = _ref.read(workoutRepositoryProvider);
    bool savedRemotely = false;
    if (resolvedUserId != 'local_user') {
      try {
        await repo
            .saveSessionRemote(finalization.session)
            .timeout(const Duration(seconds: 10));
        savedRemotely = true;
        debugPrint('[Workout] Remote session save succeeded in background');
        // Update local cache sync status
        try {
          await repo.cacheSessionLocal(finalization.session, isSynced: true);
        } catch (_) {}
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

    // Ensure remote shell is flagged ready BEFORE flushing so points can be sent
    _recordingCoordinator.markRemoteWorkoutShellReady();

    // Raw tracking flush is awaited with a 15-second timeout so early screen exit
    // does not discard pending points. Any unsynced points remain safely in LocalDB.
    try {
      await _recordingCoordinator
          .flushPendingRawTracking(
            workoutId: finalization.sessionId,
            force: true,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Workout] RawTracking flush error: $e');
    }

    _recordingCoordinator.queueLiveRouteSnapshot(
      workoutId: finalization.sessionId,
      routeSegments: routeSegments,
      lastGpsGapDurationSec: lastGpsGapDurationSec,
      isGpsSignalWeak: isGpsSignalWeak,
    );
    await _recordingCoordinator.syncLiveRouteSnapshot(force: true);

    if (savedRemotely) {
      try {
        await _recordingCoordinator.enqueueProcessingForSession(
          finalization.session,
        );
        await _recordingCoordinator.enqueueRouteCorrectionForSession(
          finalization.session,
        );
      } catch (e) {
        debugPrint('[Workout] Remote job enqueue error: $e');
      }
      // The row now exists on the server: refresh the shared workout list so
      // History/Analytics/Home show this session without requiring an app
      // reload (the invalidate in stopWorkout runs before the remote save).
      if (mounted) {
        _ref.invalidate(workoutListProvider);
      }
    } else {
      debugPrint(
        '[Workout] Skipping job enqueue — session not saved to Supabase yet',
      );
      // The row is safely in the local cache but not in the cloud. Kick off a
      // sync pass so a transient failure (network blip, 10s timeout) is
      // retried now instead of only on the next app start / sign-in.
      unawaited(_retryRemoteSync());
    }
  }

  /// Best-effort retry of every session still waiting in the local cache.
  /// [WorkoutRepositoryImpl.syncPendingData] skips unauthorised users, so this
  /// is a no-op when nobody is signed in.
  Future<void> _retryRemoteSync() async {
    final repo = _ref.read(workoutRepositoryProvider);
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
    _gpsPipeline.reset();
    _lastRouteSnapshotTime = null;
    _speedSamples.clear();
    _lastAcceptedPositionTime = null;
    _rawSignalContinuity.reset();
    _lastStepTime = null;
    _lastSessionSteps = 0;
    _pausedStepsOffset = 0;
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
    _lastModeFlipTime = null;
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
    // Prevent calories from decreasing unexpectedly due to temporary GPS fluctuations.
    return math.max(state.caloriesBurned, calculated);
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
    unawaited(
      liveActivity.syncWorkout(
        activityType: state.activityType,
        trackingMode: state.trackingMode,
        status: state.status.name,
        durationSeconds: state.durationSeconds,
        distanceMeters: state.distanceMeters,
        avgSpeedKmh: state.avgSpeedKmh,
        caloriesBurned: state.caloriesBurned,
      ),
    );
  }

  Future<void> _endLiveActivity(WorkoutSessionState finalState) {
    final liveActivity = _ref.read(iosLiveActivityServiceProvider);
    return liveActivity.endWorkout(
      activityType: finalState.activityType,
      trackingMode: finalState.trackingMode,
      durationSeconds: finalState.durationSeconds,
      distanceMeters: finalState.distanceMeters,
      avgSpeedKmh: finalState.avgSpeedKmh,
      caloriesBurned: finalState.caloriesBurned,
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

  void _onEnvironmentChanged(ClassifierEvent event) {
    if (!mounted) return;
    final nextHint = switch (event.environment) {
      TrackingEnvironment.outdoor => 'outdoor',
      TrackingEnvironment.indoor => 'indoor',
      TrackingEnvironment.detecting => 'detecting',
    };

    if (_requiresGpsTracking(state.activityType)) {
      state = state.copyWith(environmentHint: nextHint);

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

    // Observational multi-source IOD position update
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

    final decision = _trackingEngine.evaluateGpsUpdate(
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
          gpsGapMarker:
              state.currentLatLng ??
              (state.routePoints.isNotEmpty ? state.routePoints.last : null),
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
    );
  }

  // Step updates
  void _onStep(int sessionSteps) {
    if (state.status == RecordingState.paused) {
      // Collect steps occurred during pause into offset
      if (_lastSessionSteps > 0 && sessionSteps > _lastSessionSteps) {
        _pausedStepsOffset += (sessionSteps - _lastSessionSteps);
      }
      _lastSessionSteps = sessionSteps;
      return;
    }

    if (state.status != RecordingState.active) return;

    if (_lastSessionSteps == 0) {
      _lastSessionSteps = sessionSteps;
    }

    final effectiveSteps = math.max(0, sessionSteps - _pausedStepsOffset);

    final stepDecision = _trackingEngine.evaluateStepUpdate(
      sessionSteps: effectiveSteps,
      currentStepCount: state.stepCount,
      activityType: state.activityType,
      requiresGpsTracking: _requiresGpsTracking(state.activityType),
      gpsFallbackActive: state.gpsFallbackActive,
      recordingSource: state.recordingSource,
      lastAcceptedPositionTime: _lastAcceptedPositionTime,
      now: DateTime.now(),
    );
    _lastSessionSteps = sessionSteps;
    final delta = stepDecision.delta;
    if (delta <= 0) return;

    _recordingCoordinator.bufferRawStepInterval(
      delta,
      startedAt: state.startedAt,
      workoutId: state.sessionId,
    );
    _environmentController.addStepDelta(delta);
    _ref.read(iodControllerProvider.notifier).onStepDelta(delta);
    state = state.copyWith(stepCount: effectiveSteps);

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
      _updateIndoorDistanceFromSteps(delta);
    }
  }

  // Indoor distance

  void _updateIndoorDistanceFromSteps(int newSteps) {
    final now = DateTime.now();
    final contribution = _trackingEngine.computeIndoorStepContribution(
      stepDelta: newSteps,
      strideLengthMeters: state.strideLengthMeters,
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
      speedKmh: newSpeedKmh,
      lapSplits: _captureLapSplits(newDistanceM),
      caloriesBurned: newCalories,
      isAutoPaused: false,
    );
    _appendIndoorSyntheticRoute(
      addedDistanceMeters: contribution.addedDistanceMeters,
      recordedAt: now,
    );
  }

  void _appendIndoorSyntheticRoute({
    required double addedDistanceMeters,
    required DateTime recordedAt,
  }) {
    if (!mounted || addedDistanceMeters <= 0) return;

    final anchor = state.initialPosition ?? state.currentLatLng;
    if (anchor == null) return;

    final updatedRoute = List<LatLng>.from(state.routePoints);
    final updatedFilteredRoute = List<LatLng>.from(state.filteredRoutePoints);
    final updatedRouteSegments = state.routeSegments
        .map((segment) => List<LatLng>.from(segment))
        .toList();
    if (updatedRoute.isEmpty) {
      updatedRoute.add(anchor);
      updatedFilteredRoute.add(anchor);
      updatedRouteSegments.add([anchor]);
      state = state.copyWith(
        smoothedCurrentLatLng: anchor,
        smoothedRoutePoints: [anchor],
        smoothedRouteSegments: [
          [anchor],
        ],
        gpsConfidence: GpsConfidence.high,
        isStationaryByGps: false,
      );
      unawaited(
        _persistSyntheticRoutePoint(
          anchor,
          recordedAt,
          headingDeg: state.indoorSyntheticHeadingDeg,
        ),
      );
    }

    final baseHeading = state.indoorSyntheticHeadingDeg == 0
        ? 20.0
        : state.indoorSyntheticHeadingDeg;
    final displayMeters = (addedDistanceMeters * 0.18).clamp(0.8, 4.5);
    final cadenceTurn = 18.0 + ((state.stepCount % 9) * 2.5);
    final waveTurn = math.sin(state.stepCount / 6) * 9.0;
    final nextHeading = (baseHeading + cadenceTurn + waveTurn) % 360.0;
    final previousPoint = updatedRoute.last;
    final projectedPoint = _offsetLatLng(
      previousPoint,
      distanceMeters: displayMeters,
      headingDeg: nextHeading,
    );
    final constrainedPoint = _constrainSyntheticPoint(
      anchor: anchor,
      candidate: projectedPoint,
      fallback: previousPoint,
    );

    if (_distanceBetween(previousPoint, constrainedPoint) < 0.6) {
      state = state.copyWith(
        currentLatLng: constrainedPoint,
        smoothedCurrentLatLng: constrainedPoint,
        initialPosition: state.initialPosition ?? anchor,
        isIndoorSyntheticRoute: true,
        indoorSyntheticHeadingDeg: (nextHeading + 28.0) % 360.0,
      );
      return;
    }

    updatedRoute.add(constrainedPoint);
    updatedFilteredRoute.add(constrainedPoint);
    if (updatedRouteSegments.isEmpty) {
      updatedRouteSegments.add([constrainedPoint]);
    } else {
      updatedRouteSegments.last.add(constrainedPoint);
    }
    state = state.copyWith(
      filteredRoutePoints: updatedFilteredRoute,
      smoothedRoutePoints: updatedFilteredRoute,
      routePoints: updatedRoute,
      routeSegments: updatedRouteSegments,
      smoothedRouteSegments: updatedRouteSegments,
      currentLatLng: constrainedPoint,
      smoothedCurrentLatLng: constrainedPoint,
      initialPosition: state.initialPosition ?? anchor,
      isIndoorSyntheticRoute: true,
      indoorSyntheticHeadingDeg: nextHeading,
      gpsConfidence: GpsConfidence.high,
      isStationaryByGps: false,
    );
    unawaited(
      _persistSyntheticRoutePoint(
        constrainedPoint,
        recordedAt,
        headingDeg: nextHeading,
      ),
    );
  }

  LatLng _offsetLatLng(
    LatLng origin, {
    required double distanceMeters,
    required double headingDeg,
  }) {
    const metersPerDegreeLat = 111320.0;
    final headingRad = headingDeg * math.pi / 180.0;
    final latDelta = math.cos(headingRad) * distanceMeters / metersPerDegreeLat;
    final lngScale = math.max(
      0.2,
      math.cos(origin.latitude * math.pi / 180.0).abs(),
    );
    final lngDelta =
        math.sin(headingRad) * distanceMeters / (metersPerDegreeLat * lngScale);
    return LatLng(origin.latitude + latDelta, origin.longitude + lngDelta);
  }

  LatLng _constrainSyntheticPoint({
    required LatLng anchor,
    required LatLng candidate,
    required LatLng fallback,
  }) {
    final anchorDistance = _distanceBetween(anchor, candidate);
    if (anchorDistance <= 55) return candidate;

    final fallbackHeading = _bearingDegrees(anchor, fallback);
    final returnHeading = (fallbackHeading + 42.0) % 360.0;
    return _offsetLatLng(
      fallback,
      distanceMeters: 2.6,
      headingDeg: returnHeading,
    );
  }

  double _distanceBetween(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  double _bearingDegrees(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180.0;
    final lat2 = end.latitude * math.pi / 180.0;
    final lngDelta = (end.longitude - start.longitude) * math.pi / 180.0;
    final y = math.sin(lngDelta) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lngDelta);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  Future<void> _persistSyntheticRoutePoint(
    LatLng point,
    DateTime timestamp, {
    required double headingDeg,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final localPoint = LocalGPSPoint()
      ..sessionId = sessionId
      ..localWorkoutId = 0
      ..timestamp = timestamp
      ..latitude = point.latitude
      ..longitude = point.longitude
      ..accuracy = 0
      ..speed = 0
      ..heading = headingDeg
      ..deviceSource = 'indoor_synthetic_route'
      ..confidence = 'synthetic'
      ..isSynced = true;
    await LocalDB.saveRawGpsPoint(localPoint);
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
  }) {
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
    final smoothingUpdate = _gpsSmoothingService.smoothAcceptedPoint(
      activityType: state.activityType,
      acceptedPoint: routeCandidate,
      previousAcceptedPoint: lastRoutePoint,
      previousSmoothedPoint: state.smoothedCurrentLatLng,
      lastSmoothedRoutePoint: lastSmoothedRoutePoint,
      accuracyMeters: position.accuracy,
      speedMs: position.speed,
      timeDeltaSec: timeDeltaSec,
      gpsGapDurationSec: gpsGapDurationSec,
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

    // Update lightweight metrics state (1Hz)
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

      state = state.copyWith(
        durationSeconds: elapsedSec,
        movingTimeSeconds: movingTimeSec,
        speedKmh: liveSpeedKmh,
        avgSpeedKmh: avg,
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
  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _persistCheckpoint();
    });
  }

  void _persistCheckpoint() {
    if (!mounted ||
        (state.status != RecordingState.active &&
            state.status != RecordingState.paused)) {
      return;
    }
    // Only checkpoint meaningful progress
    if (state.durationSeconds < 60 && state.distanceMeters < 100) return;

    final userId =
        _ref.read(currentUserIdProvider) ??
        Supabase.instance.client.auth.currentUser?.id ??
        'local_user';

    try {
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
        userProfile: currentProfile,
      );

      final repo = _ref.read(workoutRepositoryProvider);
      unawaited(repo.cacheSessionLocal(finalization.session, isSynced: false));
    } catch (e) {
      debugPrint('[Workout] Checkpoint persist error: $e');
    }
  }

  // Cleanup

  @override
  void dispose() {
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
