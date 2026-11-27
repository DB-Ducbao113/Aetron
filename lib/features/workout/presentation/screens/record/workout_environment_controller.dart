import 'dart:async';

import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:geolocator/geolocator.dart';

/// Advisory evidence only. No confidence is added to the GPS classifier and
/// no handover or distance decision is made here.
class IodEnvironmentAdvice {
  final String hint;
  final bool usedForHint;
  final bool corroborated;

  const IodEnvironmentAdvice(
    this.hint, {
    this.usedForHint = false,
    this.corroborated = false,
  });
}

class WorkoutEnvironmentController {
  EnvironmentClassifier? _classifier;
  StreamSubscription<ClassifierEvent>? _subscription;

  /// A 1 Hz IOD prediction expires after two nominal epochs. This is a
  /// transport freshness safeguard, not a calibrated model threshold.
  static const iodMaxAge = Duration(seconds: 2);

  static IodEnvironmentAdvice resolveIodAdvice({
    required WorkoutSessionState workout,
    required String legacyHint,
    required IodState iod,
    required DateTime now,
    required DateTime? lastAcceptedGpsAt,
  }) {
    final base = IodEnvironmentAdvice(legacyHint);
    // Activity-selected indoor-only tracking and manual pause are not
    // changed by IOD. Cycling may receive a hint, never step distance.
    if (workout.status != RecordingState.active ||
        !const [
          'running',
          'walking',
          'cycling',
        ].contains(workout.activityType.toLowerCase()) ||
        workout.sessionId == null ||
        workout.startedAt == null ||
        !iod.isRecording ||
        iod.sessionId != workout.sessionId) {
      return base;
    }
    final snapshot = iod.latestSnapshot;
    if (snapshot == null ||
        snapshot.timestamp.isBefore(workout.startedAt!) ||
        iod.totalSamplesCount < 10) {
      return base;
    }
    final age = now.difference(snapshot.timestamp);
    if (age.isNegative || age > iodMaxAge) return base;

    final prediction = iod.currentPrediction;
    final probability = prediction.deepIodOutdoorProbability;
    final predicted = prediction.state;
    final isAndroidLiveModel =
        prediction.modelVersion == IodCompositeClassifier.liveModelVersion &&
        prediction.nativeClass ==
            'deepiod_c_mobile_adapted:${predicted.code}' &&
        [
          'light',
          'mag',
          'acc',
          'daytime',
        ].every((channel) => prediction.sensorAvailability[channel] == true) &&
        snapshot.hasLightSensor &&
        snapshot.hasImuData &&
        [
          snapshot.ambientLux,
          snapshot.magneticMagnitudeMean,
          snapshot.accelMagnitudeMean,
        ].every((value) => value != null && value.isFinite && value >= 0);

    final isIosLiveModel =
        prediction.modelVersion == IodCompositeClassifier.iosLiveModelVersion &&
        prediction.nativeClass == 'ios_magio_hmm:${predicted.code}' &&
        [
          'mag',
          'acc',
          'daytime',
        ].every((channel) => prediction.sensorAvailability[channel] == true) &&
        snapshot.hasImuData &&
        [
          snapshot.magneticMagnitudeMean,
          snapshot.accelMagnitudeMean,
        ].every((value) => value != null && value.isFinite && value >= 0);

    if ((!isAndroidLiveModel && !isIosLiveModel) ||
        (predicted != IndoorOutdoorState.indoor &&
            predicted != IndoorOutdoorState.outdoor) ||
        probability == null ||
        !probability.isFinite ||
        probability < 0 ||
        probability > 1 ||
        (probability >= 0.5) != (predicted == IndoorOutdoorState.outdoor) ||
        !prediction.confidence.isFinite ||
        prediction.confidence < 0 ||
        prediction.confidence > 1) {
      return base;
    }
    final hint = predicted.code;
    if (hint == legacyHint) {
      return IodEnvironmentAdvice(legacyHint, corroborated: true);
    }

    // Never contradict a resolved GPS/step hint. A fresh accepted GPS fix
    // also takes priority over IOD during legacy classifier warm-up.
    final gpsAge = lastAcceptedGpsAt == null
        ? null
        : now.difference(lastAcceptedGpsAt);
    final recentGps =
        gpsAge != null &&
        !gpsAge.isNegative &&
        gpsAge < const Duration(seconds: 5);
    if (legacyHint != 'detecting' ||
        workout.gpsFallbackActive ||
        workout.trackingMode == 'indoor' ||
        workout.recordingSource != 'gps' ||
        recentGps) {
      return base;
    }
    return IodEnvironmentAdvice(hint, usedForHint: true);
  }

  Future<void> start({
    required String activityType,
    required void Function(ClassifierEvent event) onEvent,
  }) async {
    await stop();
    _classifier = EnvironmentClassifier(activityType: activityType);
    _subscription = _classifier!.stateStream.listen(onEvent);
  }

  void addPosition(Position position) {
    _classifier?.addPosition(position);
  }

  void addStepDelta(int delta) {
    _classifier?.addStepDelta(delta);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _classifier?.dispose();
    _classifier = null;
  }
}
