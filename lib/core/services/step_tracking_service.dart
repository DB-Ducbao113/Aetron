import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'cadence_calculator_service.dart';
import 'sensor/composite_step_sensor_adapter.dart';
import 'sensor/step_sensor_adapter.dart';
import 'sensor/step_sensor_types.dart';

final stepTrackingServiceProvider = Provider((ref) => StepTrackingService());

/// Max realistic step rate (4.5 steps/sec = 270 spm).
const double _kMaxStepsPerSec = 4.5;

/// Emit throttle for integer step count stream.
const Duration _kEmitThrottle = Duration(milliseconds: 300);

/// Production-grade workout step and cadence tracking service.
///
/// Follows INTERLIVE validation guidelines:
/// - Isolates workout steps from all-day cumulative steps via baseline subtraction.
/// - Handles device reboots and counter resets without step count regressions.
/// - Accurately segregates paused interval steps from active workout steps.
/// - Rejects unrealistic physical spikes (> 4.5 steps/s).
/// - Calculates instantaneous windowed cadence and average active cadence.
///
/// NOTE ON PAUSE UNCERTAINTY:
/// Hardware step counters (e.g. Android Sensor.TYPE_STEP_COUNTER) deliver batched
/// cumulative counts rather than per-step timestamps. When a delayed batch arrives
/// near a pause/resume transition, individual steps within the batch cannot be
/// strictly partitioned between paused and active states with sub-second accuracy.
/// In such cases, the service allocates the steps to the state active when the event
/// is processed and documents this inherent hardware limitation.
class StepTrackingService {
  final StepSensorAdapter _adapter;
  final CadenceCalculatorService _cadenceCalculator;

  // Stream controllers
  final _stepController = StreamController<int>.broadcast();
  final _updateController = StreamController<WorkoutStepUpdate>.broadcast();
  StreamSubscription<StepSensorSample>? _sensorSub;

  // Session state
  bool _isTracking = false;
  bool _isPaused = false;

  /// Baseline raw steps when workout started.
  int _baselineSteps = -1;

  /// Last raw step count seen from sensor.
  int _lastRawSteps = -1;

  /// Total steps taken while paused (offset deducted from session total).
  int _pausedStepsOffset = 0;

  /// Cumulative active steps in current workout.
  int _activeWorkoutSteps = 0;

  /// Total steps (active + paused) since workout baseline.
  int _totalSessionSteps = 0;

  // Cadence state
  int _currentCadenceSpm = 0;
  int _avgCadenceSpm = 0;
  DateTime? _activeTrackingStartTime;
  int _accumulatedActiveDurationMs = 0;
  DateTime? _lastResumeTime;

  // Spike filter & throttle
  DateTime? _lastEventTime;
  DateTime? _lastReceivedTime;
  DateTime? _lastEmit;

  StepTrackingService({
    StepSensorAdapter? adapter,
    CadenceCalculatorService? cadenceCalculator,
  })  : _adapter = adapter ?? CompositeStepSensorAdapter(),
        _cadenceCalculator = cadenceCalculator ?? CadenceCalculatorService();

  /// Stream emitting active workout step counts (backward compatible).
  Stream<int> get stepStream => _stepController.stream;

  /// Stream emitting rich workout step & cadence telemetry.
  Stream<WorkoutStepUpdate> get updateStream => _updateController.stream;

  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  int get currentActiveSteps => _activeWorkoutSteps;
  int get currentCadenceSpm => _currentCadenceSpm;
  int get currentAvgCadenceSpm => _avgCadenceSpm;

  /// Max duration without any sensor events before cadence is considered unavailable/stale.
  static const Duration kSensorStaleThreshold = Duration(seconds: 15);

  /// Whether real-time cadence is currently available (sensor active and not stale).
  bool get isCadenceAvailable {
    if (!_isTracking || _baselineSteps == -1 || _lastReceivedTime == null) {
      return false;
    }
    final now = DateTime.now();
    if (now.difference(_lastReceivedTime!).abs() > kSensorStaleThreshold) {
      return false;
    }
    return true;
  }

  // Permission check

  Future<void> ensurePermissionsOrThrow() async {
    if (kIsWeb) return;

    final permission = (!kIsWeb && Platform.isIOS)
        ? Permission.sensors
        : Permission.activityRecognition;

    var status = await permission.status;
    if (status.isDenied) {
      status = await permission.request();
    }

    if (status.isGranted || status.isLimited) {
      return;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      throw Exception('activity_permission_denied_forever');
    }

    throw Exception('activity_permission_denied');
  }

  // Public Session Lifecycle

  /// Starts a new step tracking session.
  Future<void> startTracking() async {
    if (_isTracking) {
      debugPrint('[Steps] startTracking ignored — already tracking');
      return;
    }

    _isTracking = true;
    _isPaused = false;
    _baselineSteps = -1;
    _lastRawSteps = -1;
    _pausedStepsOffset = 0;
    _activeWorkoutSteps = 0;
    _totalSessionSteps = 0;
    _currentCadenceSpm = 0;
    _avgCadenceSpm = 0;
    _lastEventTime = null;
    _lastReceivedTime = null;
    _lastEmit = null;
    _activeTrackingStartTime = DateTime.now();
    _lastResumeTime = _activeTrackingStartTime;
    _accumulatedActiveDurationMs = 0;

    _cadenceCalculator.reset();

    if (_adapter.requiresSystemPermissions) {
      if (kIsWeb) {
        debugPrint('[Steps] step tracking hardware skipped on web');
        return;
      }

      try {
        await ensurePermissionsOrThrow();
      } catch (e) {
        _isTracking = false;
        debugPrint('[Steps] permission error on startTracking: $e');
        rethrow;
      }
    }

    await _sensorSub?.cancel();
    _sensorSub = null;

    try {
      await _adapter.startStream();
      _sensorSub = _adapter.sampleStream.listen(
        _onSensorSample,
        onError: (err) => debugPrint('[Steps] sensor stream error: $err'),
        cancelOnError: false,
      );
      debugPrint('[Steps] step sensor subscription active');
    } catch (e) {
      _isTracking = false;
      debugPrint('[Steps] adapter start failed: $e');
      rethrow;
    }
  }

  /// Pauses workout step accumulation. Steps taken while paused will not be
  /// counted as active workout steps.
  void pauseTracking([DateTime? timestamp]) {
    if (!_isTracking || _isPaused) return;

    final now = timestamp ?? _lastEventTime ?? DateTime.now();
    _isPaused = true;
    _currentCadenceSpm = 0;

    if (_lastResumeTime != null) {
      final diff = now.difference(_lastResumeTime!).inMilliseconds;
      if (diff > 0) {
        _accumulatedActiveDurationMs += diff;
      }
      _lastResumeTime = null;
    }

    debugPrint('[Steps] pauseTracking at rawSteps=$_lastRawSteps');
    _emitUpdate(
      delta: 0,
      timestamp: now,
      source: StepSensorSource.unknown,
    );
  }

  /// Resumes workout step accumulation.
  void resumeTracking([DateTime? timestamp]) {
    if (!_isTracking || !_isPaused) return;

    _isPaused = false;
    _lastResumeTime = timestamp;
    _cadenceCalculator.reset();

    debugPrint(
      '[Steps] resumeTracking at rawSteps=$_lastRawSteps (pausedOffset=$_pausedStepsOffset)',
    );
  }

  /// Stops tracking and releases resources.
  void stopTracking() {
    debugPrint(
      '[Steps] stopTracking (final active=$_activeWorkoutSteps, offset=$_pausedStepsOffset)',
    );
    _isTracking = false;
    _isPaused = false;
    _sensorSub?.cancel();
    _sensorSub = null;
    _adapter.stopStream();

    _baselineSteps = -1;
    _lastRawSteps = -1;
    _pausedStepsOffset = 0;
    _activeWorkoutSteps = 0;
    _totalSessionSteps = 0;
    _currentCadenceSpm = 0;
    _avgCadenceSpm = 0;
    _lastEventTime = null;
    _lastReceivedTime = null;
    _lastEmit = null;
    _activeTrackingStartTime = null;
    _lastResumeTime = null;
    _accumulatedActiveDurationMs = 0;
    _cadenceCalculator.reset();
  }

  // Sample Processing

  void _onSensorSample(StepSensorSample sample) {
    if (!_isTracking) return;

    final rawSteps = sample.rawSteps;
    final now = sample.timestamp;
    _lastReceivedTime = sample.receivedTimestamp ?? DateTime.now();

    // 1. Initial baseline capture
    if (_baselineSteps == -1) {
      _baselineSteps = rawSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      _activeTrackingStartTime = now;
      _lastResumeTime = now;
      debugPrint('[Steps] baseline=$_baselineSteps at $now (source=${sample.source})');
      _emit(0, now);
      _emitUpdate(delta: 0, timestamp: now, source: sample.source);
      return;
    }

    if (!_isPaused && _lastResumeTime == null) {
      _lastResumeTime = now;
    }

    // 2. Out-of-order packet rejection
    if (_lastEventTime != null && now.isBefore(_lastEventTime!)) {
      debugPrint(
        '[Steps] Out-of-order packet rejected: sample time $now is before last event time $_lastEventTime',
      );
      return;
    }

    final rawDelta = rawSteps - _lastRawSteps;

    // 3. Duplicate packet rejection
    if (rawDelta == 0 && _lastEventTime != null && now.isAtSameMomentAs(_lastEventTime!)) {
      debugPrint('[Steps] Duplicate packet ignored: rawSteps=$rawSteps at $now');
      return;
    }

    // 4. Hardware reboot or counter reset detection
    // Valid reboot when rawSteps drops (rawDelta < 0) and event is not out-of-order
    if (rawDelta < 0) {
      debugPrint(
        '[Steps] Counter reset or reboot detected (rawDelta=$rawDelta). '
        'Adjusting baseline to preserve existing session steps.',
      );
      // New baseline ensures _totalSessionSteps remains consistent
      _baselineSteps = rawSteps - _totalSessionSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      return;
    }

    if (rawDelta == 0) {
      _lastEventTime = now;
      // No new steps; compute cadence decay if time has passed
      if (!_isPaused) {
        _currentCadenceSpm = _cadenceCalculator.computeInstantCadence(
          activeSteps: _activeWorkoutSteps,
          timestamp: now,
          nativeCadenceStepsPerSec: sample.nativeCadenceStepsPerSec,
        );
        _updateAverageCadence(now);
      }
      return;
    }

    // 5. Spike filtering with Batch Burst Awareness:
    // Physical human limit is _kMaxStepsPerSec (4.5 st/s = 270 spm).
    // However, hardware sensor hubs (Android HAL / CoreMotion) deliver batched updates.
    // In low-latency bursts, a normal stride burst of <= 5 steps can arrive within a small interval (< 1s).
    // We only reject if rawDelta > 5 (cannot be a single stride/micro-batch burst)
    // AND the rate over elapsed time exceeds _kMaxStepsPerSec.
    if (_lastEventTime != null) {
      final elapsedSec = now.difference(_lastEventTime!).inMilliseconds / 1000.0;
      if (rawDelta > 5 && elapsedSec > 0) {
        final stepsPerSec = rawDelta / elapsedSec;
        if (stepsPerSec > _kMaxStepsPerSec) {
          debugPrint(
            '[Steps] SPIKE REJECTED: rawDelta=$rawDelta in '
            '${elapsedSec.toStringAsFixed(2)}s = ${stepsPerSec.toStringAsFixed(1)} st/s > $_kMaxStepsPerSec',
          );
          return;
        }
      }
    }

    _lastRawSteps = rawSteps;
    _lastEventTime = now;
    _totalSessionSteps = math.max(0, rawSteps - _baselineSteps);

    if (_isPaused) {
      // Accumulate paused steps offset
      _pausedStepsOffset += rawDelta;
      _currentCadenceSpm = 0;
      _emitUpdate(delta: 0, timestamp: now, source: sample.source);
      return;
    }

    // Active session update
    _activeWorkoutSteps = math.max(0, _totalSessionSteps - _pausedStepsOffset);

    // 6. Cadence calculations
    _currentCadenceSpm = _cadenceCalculator.computeInstantCadence(
      activeSteps: _activeWorkoutSteps,
      timestamp: now,
      nativeCadenceStepsPerSec: sample.nativeCadenceStepsPerSec,
    );

    _updateAverageCadence(now);

    debugPrint(
      '[Steps] active=$_activeWorkoutSteps (total=$_totalSessionSteps, '
      'pausedOffset=$_pausedStepsOffset) delta=$rawDelta '
      'cadence=$_currentCadenceSpm spm (avg=$_avgCadenceSpm spm)',
    );

    _emit(_activeWorkoutSteps, now);
    _emitUpdate(delta: rawDelta, timestamp: now, source: sample.source);
  }

  void _updateAverageCadence(DateTime now) {
    var totalActiveMs = _accumulatedActiveDurationMs;
    if (!_isPaused && _lastResumeTime != null) {
      final diff = now.difference(_lastResumeTime!).inMilliseconds;
      if (diff > 0) {
        totalActiveMs += diff;
      }
    }
    final activeSec = totalActiveMs ~/ 1000;
    _avgCadenceSpm = CadenceCalculatorService.computeAverageCadence(
      activeSteps: _activeWorkoutSteps,
      activeMovingDurationSec: activeSec,
    );
  }

  void _emit(int activeSteps, DateTime now) {
    if (_lastEmit != null && now.difference(_lastEmit!) < _kEmitThrottle) {
      return;
    }
    _lastEmit = now;

    if (!_stepController.isClosed) {
      _stepController.add(activeSteps);
    }
  }

  void _emitUpdate({
    required int delta,
    required DateTime timestamp,
    required StepSensorSource source,
    bool? isCadenceAvailable,
  }) {
    if (!_updateController.isClosed) {
      _updateController.add(
        WorkoutStepUpdate(
          totalSessionSteps: _totalSessionSteps,
          activeSessionSteps: _activeWorkoutSteps,
          deltaSteps: delta,
          currentCadenceSpm: _currentCadenceSpm,
          avgCadenceSpm: _avgCadenceSpm,
          timestamp: timestamp,
          isPaused: _isPaused,
          source: source,
          isCadenceAvailable: isCadenceAvailable ?? this.isCadenceAvailable,
        ),
      );
    }
  }

  void dispose() {
    stopTracking();
    _stepController.close();
    _updateController.close();
    _adapter.dispose();
  }
}
