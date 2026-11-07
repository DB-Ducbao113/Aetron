import 'step_sensor_types.dart';

/// Abstract adapter interface defining platform-agnostic step sensor integration.
abstract class StepSensorAdapter {
  /// Stream of step sensor samples from hardware or simulation.
  Stream<StepSensorSample> get sampleStream;

  /// Whether this adapter requires checking OS permissions (false for test mocks).
  bool get requiresSystemPermissions => true;

  /// Probes hardware sensor availability and user authorization.
  Future<StepSensorStatus> checkStatus();

  /// Starts listening to step sensor hardware updates.
  Future<void> startStream();

  /// Stops listening to step sensor hardware updates.
  Future<void> stopStream();

  /// Queries historical step counts for a past time window if supported by the OS (e.g. Apple Core Motion).
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  );

  /// Releases resources held by the adapter.
  void dispose();
}
