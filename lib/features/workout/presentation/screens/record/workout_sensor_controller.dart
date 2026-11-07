import 'dart:async';

import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/step_sensor_types.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';
import 'package:geolocator/geolocator.dart';

class WorkoutSensorController {
  const WorkoutSensorController();

  Future<Position?> getLastKnownPosition(
    LocationTrackingService locationService,
  ) {
    return locationService.getLastKnownPosition();
  }

  Future<StreamSubscription<Position>> startGpsTracking({
    required LocationTrackingService locationService,
    required String activityType,
    required void Function(Position position) onPosition,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) async {
    await locationService.startTracking(activityType);
    return locationService.positionStream.listen(
      onPosition,
      onError: onError,
      onDone: onDone,
      cancelOnError: false,
    );
  }

  Future<void> stopGpsTracking({
    required LocationTrackingService locationService,
    required StreamSubscription<Position>? subscription,
  }) async {
    locationService.stopTracking();
    await subscription?.cancel();
  }

  Future<StreamSubscription<int>> startStepTracking({
    required StepTrackingService stepService,
    required void Function(int sessionSteps) onStep,
  }) async {
    await stepService.startTracking();
    return stepService.stepStream.listen(onStep);
  }

  Future<StreamSubscription<WorkoutStepUpdate>> startWorkoutStepTracking({
    required StepTrackingService stepService,
    required void Function(WorkoutStepUpdate update) onStepUpdate,
  }) async {
    await stepService.startTracking();
    return stepService.updateStream.listen(onStepUpdate);
  }

  void pauseStepTracking(StepTrackingService stepService) {
    stepService.pauseTracking();
  }

  void resumeStepTracking(StepTrackingService stepService) {
    stepService.resumeTracking();
  }

  Future<void> stopStepTracking({
    required StepTrackingService stepService,
    required StreamSubscription<dynamic>? subscription,
  }) async {
    stepService.stopTracking();
    await subscription?.cancel();
  }
}
