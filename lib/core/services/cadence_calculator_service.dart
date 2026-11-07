import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Timestamped step sample for sliding-window cadence calculation.
class _StepTimestampEntry {
  final DateTime timestamp;
  final int cumulativeSteps;

  const _StepTimestampEntry({
    required this.timestamp,
    required this.cumulativeSteps,
  });
}

/// Service that computes instantaneous and average cadence according to
/// biomechanical research standards (steps/min = steps in interval * 60 / duration in seconds).
class CadenceCalculatorService {
  /// Window duration for instantaneous cadence calculation (default 6 seconds).
  final Duration windowDuration;

  /// Inactivity timeout after which instantaneous cadence drops to zero.
  final Duration inactivityTimeout;

  /// Max realistic human cadence in steps per minute (270 spm = 4.5 steps/sec).
  static const double kMaxCadenceSpm = 270.0;

  /// Min duration (seconds) needed to compute a reliable window rate.
  static const double kMinWindowDurationSec = 1.5;

  final Queue<_StepTimestampEntry> _windowQueue = Queue<_StepTimestampEntry>();
  DateTime? _lastStepTime;
  int _lastActiveSteps = 0;

  CadenceCalculatorService({
    this.windowDuration = const Duration(seconds: 6),
    this.inactivityTimeout = const Duration(seconds: 4),
  });

  /// Resets all internal window and cadence state.
  void reset() {
    _windowQueue.clear();
    _lastStepTime = null;
    _lastActiveSteps = 0;
  }

  /// Evaluates real-time cadence given a new sample.
  ///
  /// If [nativeCadenceStepsPerSec] is supplied by hardware (e.g. iOS CoreMotion),
  /// it is verified and converted to steps per minute ($spm = sps \times 60$).
  /// Otherwise, windowed interval calculation is applied:
  /// Cadence (spm) = (steps in window * 60) / (window duration in seconds).
  int computeInstantCadence({
    required int activeSteps,
    required DateTime timestamp,
    double? nativeCadenceStepsPerSec,
  }) {
    // 1. If native cadence is available, verify and prioritize it.
    if (nativeCadenceStepsPerSec != null && nativeCadenceStepsPerSec >= 0) {
      final nativeSpm = nativeCadenceStepsPerSec * 60.0;
      if (nativeSpm <= kMaxCadenceSpm) {
        _lastStepTime = timestamp;
        _lastActiveSteps = activeSteps;
        return nativeSpm.round();
      }
    }

    // 2. Add current sample to window queue.
    _windowQueue.addLast(
      _StepTimestampEntry(
        timestamp: timestamp,
        cumulativeSteps: activeSteps,
      ),
    );

    // 3. Prune entries older than windowDuration.
    final cutoff = timestamp.subtract(windowDuration);
    while (_windowQueue.length > 2 && _windowQueue.first.timestamp.isBefore(cutoff)) {
      _windowQueue.removeFirst();
    }

    // Check if new steps occurred
    if (activeSteps > _lastActiveSteps) {
      _lastStepTime = timestamp;
      _lastActiveSteps = activeSteps;
    } else if (_lastStepTime != null &&
        timestamp.difference(_lastStepTime!) > inactivityTimeout) {
      // Inactivity timeout reached: user has stopped moving.
      return 0;
    }

    if (_windowQueue.length < 2) {
      return 0;
    }

    final oldest = _windowQueue.first;
    final newest = _windowQueue.last;

    final durationSec =
        newest.timestamp.difference(oldest.timestamp).inMilliseconds / 1000.0;
    final stepDelta = newest.cumulativeSteps - oldest.cumulativeSteps;

    if (durationSec < kMinWindowDurationSec || stepDelta <= 0) {
      return 0;
    }

    final rawCadenceSpm = (stepDelta * 60.0) / durationSec;

    // Filter out physically impossible spikes (e.g. phone shaking > 270 spm)
    if (rawCadenceSpm > kMaxCadenceSpm) {
      debugPrint(
        '[CadenceCalculator] Spike rejected: ${rawCadenceSpm.toStringAsFixed(1)} spm '
        '(delta=$stepDelta steps in ${durationSec.toStringAsFixed(2)}s)',
      );
      return 0;
    }

    return rawCadenceSpm.round();
  }

  /// Computes overall average cadence for the active moving duration.
  ///
  /// Average Cadence (spm) = (Active Steps * 60) / (Active Moving Duration in seconds).
  static int computeAverageCadence({
    required int activeSteps,
    required int activeMovingDurationSec,
  }) {
    if (activeSteps <= 0 || activeMovingDurationSec <= 0) {
      return 0;
    }
    final avg = (activeSteps * 60.0) / activeMovingDurationSec;
    return math.min(kMaxCadenceSpm.round(), avg.round());
  }

  /// Computes interval cadence between two timestamps and step delta.
  static int computeIntervalCadence({
    required int stepDelta,
    required Duration intervalDuration,
  }) {
    final sec = intervalDuration.inMilliseconds / 1000.0;
    if (stepDelta <= 0 || sec <= 0) {
      return 0;
    }
    final rawSpm = (stepDelta * 60.0) / sec;
    return math.min(kMaxCadenceSpm.round(), rawSpm.round());
  }
}

