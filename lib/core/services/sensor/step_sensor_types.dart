import 'package:flutter/foundation.dart';

/// Provenance of the step data.
enum StepSensorSource {
  /// Android Hardware Step Counter (Sensor.TYPE_STEP_COUNTER).
  androidStepCounter,

  /// Apple Core Motion CMPedometer.
  iosCoreMotion,

  /// Fallback to pedometer pub package.
  pedometerPlugin,

  /// Deterministic mock or test harness.
  mock,

  /// Unknown or unsupported source.
  unknown,
}

/// A raw sample emitted by a hardware or synthetic step sensor.
@immutable
class StepSensorSample {
  /// Cumulative step count reported by the sensor (often since device boot).
  final int rawSteps;

  /// Hardware timestamp of the event if supported, or system receipt time.
  final DateTime timestamp;

  /// Wall-clock timestamp when the sample was received by the application / plugin.
  /// Used in conjunction with hardware [timestamp] to evaluate batch delivery latency.
  final DateTime? receivedTimestamp;

  /// Instantaneous native cadence in steps per second if reported by hardware (e.g. CoreMotion).
  final double? nativeCadenceStepsPerSec;

  /// Provenance of this sample.
  final StepSensorSource source;

  const StepSensorSample({
    required this.rawSteps,
    required this.timestamp,
    this.receivedTimestamp,
    this.nativeCadenceStepsPerSec,
    this.source = StepSensorSource.unknown,
  });

  @override
  String toString() =>
      'StepSensorSample(rawSteps: $rawSteps, time: ${timestamp.toIso8601String()}, '
      'nativeCadence: ${nativeCadenceStepsPerSec?.toStringAsFixed(2)} sps, source: $source)';
}

/// Hardware capabilities and authorization state for step tracking.
@immutable
class StepSensorStatus {
  final bool isAvailable;
  final bool hasPermission;
  final bool isCadenceAvailable;
  final bool isHistoricalQueryAvailable;
  final String? message;

  const StepSensorStatus({
    required this.isAvailable,
    required this.hasPermission,
    this.isCadenceAvailable = false,
    this.isHistoricalQueryAvailable = false,
    this.message,
  });

  @override
  String toString() =>
      'StepSensorStatus(available: $isAvailable, perm: $hasPermission, '
      'cadence: $isCadenceAvailable, history: $isHistoricalQueryAvailable, msg: $message)';
}

/// A historical step interval returned by queries such as CMPedometer.queryPedometerData.
@immutable
class HistoricalStepInterval {
  final DateTime start;
  final DateTime end;
  final int steps;

  const HistoricalStepInterval({
    required this.start,
    required this.end,
    required this.steps,
  });

  Duration get duration => end.difference(start);

  double get cadenceSpm {
    final sec = duration.inMilliseconds / 1000.0;
    if (sec <= 0) return 0.0;
    return (steps * 60.0) / sec;
  }
}

/// High-level workout step update consumed by workout state controllers.
@immutable
class WorkoutStepUpdate {
  /// Total raw steps elapsed since workout start (including paused intervals).
  final int totalSessionSteps;

  /// Steps accumulated exclusively during active (non-paused) workout intervals.
  final int activeSessionSteps;

  /// Delta steps since previous sample during active tracking.
  final int deltaSteps;

  /// Real-time instantaneous cadence in steps per minute (SPM).
  final int currentCadenceSpm;

  /// Average cadence over active moving time in steps per minute (SPM).
  final int avgCadenceSpm;

  /// Timestamp corresponding to this sample.
  final DateTime timestamp;

  /// Whether this update occurred while the workout session was paused.
  final bool isPaused;

  /// Sensor source that generated this update.
  final StepSensorSource source;

  /// Whether real-time cadence is currently available (sensor active and not stale).
  final bool isCadenceAvailable;

  const WorkoutStepUpdate({
    required this.totalSessionSteps,
    required this.activeSessionSteps,
    required this.deltaSteps,
    required this.currentCadenceSpm,
    required this.avgCadenceSpm,
    required this.timestamp,
    required this.isPaused,
    required this.source,
    this.isCadenceAvailable = true,
  });

  @override
  String toString() =>
      'WorkoutStepUpdate(active: $activeSessionSteps, delta: $deltaSteps, '
      'currentCadence: $currentCadenceSpm spm, avgCadence: $avgCadenceSpm spm, '
      'paused: $isPaused, source: $source)';
}

