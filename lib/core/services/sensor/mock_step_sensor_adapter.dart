import 'dart:async';

import 'step_sensor_adapter.dart';
import 'step_sensor_types.dart';

/// Configurable mock adapter for testing step and cadence workflows deterministically.
class MockStepSensorAdapter implements StepSensorAdapter {
  final _controller = StreamController<StepSensorSample>.broadcast();

  bool isAvailable;
  bool hasPermission;
  bool isCadenceAvailable;
  bool isHistoricalQueryAvailable;
  bool isStreaming = false;

  int _currentRawSteps = 0;
  final List<HistoricalStepInterval> _historicalIntervals = [];

  MockStepSensorAdapter({
    this.isAvailable = true,
    this.hasPermission = true,
    this.isCadenceAvailable = false,
    this.isHistoricalQueryAvailable = true,
    int initialRawSteps = 1000,
  }) : _currentRawSteps = initialRawSteps;

  @override
  Stream<StepSensorSample> get sampleStream => _controller.stream;

  @override
  bool get requiresSystemPermissions => false;

  int get currentRawSteps => _currentRawSteps;

  @override
  Future<StepSensorStatus> checkStatus() async {
    return StepSensorStatus(
      isAvailable: isAvailable,
      hasPermission: hasPermission,
      isCadenceAvailable: isCadenceAvailable,
      isHistoricalQueryAvailable: isHistoricalQueryAvailable,
      message: hasPermission ? null : 'Permission denied for testing',
    );
  }

  @override
  Future<void> startStream() async {
    if (!hasPermission) {
      throw Exception('activity_permission_denied');
    }
    if (!isAvailable) {
      throw Exception('sensor_unavailable');
    }
    isStreaming = true;
  }

  @override
  Future<void> stopStream() async {
    isStreaming = false;
  }

  /// Manually injects a sensor sample into the stream.
  void emitSample({
    required int rawSteps,
    DateTime? timestamp,
    DateTime? receivedTimestamp,
    double? nativeCadenceStepsPerSec,
  }) {
    _currentRawSteps = rawSteps;
    final time = timestamp ?? DateTime.now();
    if (!_controller.isClosed) {
      _controller.add(
        StepSensorSample(
          rawSteps: rawSteps,
          timestamp: time,
          receivedTimestamp: receivedTimestamp,
          nativeCadenceStepsPerSec: nativeCadenceStepsPerSec,
          source: StepSensorSource.mock,
        ),
      );
    }
  }

  /// Helper to advance step count by [delta] steps.
  void step({
    required int delta,
    DateTime? timestamp,
    double? nativeCadenceStepsPerSec,
  }) {
    emitSample(
      rawSteps: _currentRawSteps + delta,
      timestamp: timestamp,
      nativeCadenceStepsPerSec: nativeCadenceStepsPerSec,
    );
  }

  /// Simulates a device reboot: resets the hardware cumulative counter to 0 or low value.
  void simulateReboot({int rebootInitialSteps = 5, DateTime? timestamp}) {
    _currentRawSteps = rebootInitialSteps;
    emitSample(
      rawSteps: _currentRawSteps,
      timestamp: timestamp,
    );
  }

  /// Injects an error into the stream.
  void emitError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }

  /// Registers a historical interval to be returned by [queryHistoricalSteps].
  void addHistoricalInterval(HistoricalStepInterval interval) {
    _historicalIntervals.add(interval);
  }

  @override
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  ) async {
    if (!isHistoricalQueryAvailable) return null;

    final matching = _historicalIntervals.where(
      (h) => !h.end.isBefore(start) && !h.start.isAfter(end),
    );

    if (matching.isEmpty) {
      return null;
    }

    var totalSteps = 0;
    for (final m in matching) {
      totalSteps += m.steps;
    }
    return HistoricalStepInterval(start: start, end: end, steps: totalSteps);
  }

  @override
  void dispose() {
    isStreaming = false;
    _controller.close();
  }
}
