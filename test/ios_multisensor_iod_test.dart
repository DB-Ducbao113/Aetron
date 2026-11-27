import 'package:fitness_exercise_application/core/services/environment_detector.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/ios_multisensor_iod_classifier.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_environment_controller.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('iOS-First Multi-Sensor IOD & Causal HMM Tests', () {
    test(
      'IodCompositeClassifier.liveMobile produces active outdoor prediction on iPhone without ambient light sensor',
      () {
        final classifier = IodCompositeClassifier.liveMobile();
        final start = DateTime.utc(2026, 6, 15, 9, 0, 0);

        for (int s = 0; s < 6; s++) {
          final snap = IodSensorSnapshot(
            timestamp: start.add(Duration(seconds: s)),
            hasLightSensor: false, // iPhone has no public ambient light API
            hasGnssStatus: false, // iPhone has no raw C/N0 API
            hasImuData: true,
            magneticMagnitudeMean: 44.5 + (s.isEven ? 1.8 : -1.6),
            accelMagnitudeMean: 2.1,
            hasGpsFix: true,
            horizontalAccuracy: 7.5,
            speed: 2.6,
            stepDelta: 3,
            isNightTime: false,
          );
          final pred = classifier.predict(snap);
          if (s >= IosMultiSensorIodClassifier.minLiveWarmupEpochs - 1) {
            expect(pred.state, IndoorOutdoorState.outdoor);
            expect(
              pred.modelVersion,
              IodCompositeClassifier.iosLiveModelVersion,
            );
            expect(pred.nativeClass, 'ios_magio_hmm:outdoor');
            expect(pred.confidence, greaterThan(0.40));
          }
        }
      },
    );

    test(
      'Causal HMM prevents false indoor flip during brief 2-second urban-canyon GPS dip on iPhone',
      () {
        final classifier = IosMultiSensorIodClassifier(
          mode: IosIodEvaluationMode.liveMultiSensorFusion,
        );
        final start = DateTime.utc(2026, 6, 15, 10, 0, 0);

        // Establish 8 seconds of outdoor running
        for (int s = 0; s < 8; s++) {
          final pred = classifier.classify(
            IodSensorSnapshot(
              timestamp: start.add(Duration(seconds: s)),
              hasLightSensor: false,
              hasImuData: true,
              magneticMagnitudeMean: 45.0 + (s % 3) * 1.9,
              accelMagnitudeMean: 2.4,
              hasGpsFix: true,
              horizontalAccuracy: 8.0,
              speed: 2.8,
              stepDelta: 3,
            ),
          );
          expect(pred.state, IndoorOutdoorState.outdoor);
        }

        // 2-second overpass / urban canyon dip (acc = 36m)
        for (int s = 8; s < 10; s++) {
          final pred = classifier.classify(
            IodSensorSnapshot(
              timestamp: start.add(Duration(seconds: s)),
              hasLightSensor: false,
              hasImuData: true,
              magneticMagnitudeMean: 45.5,
              accelMagnitudeMean: 2.3,
              hasGpsFix: true,
              horizontalAccuracy: 36.0,
              speed: 2.5,
              stepDelta: 3,
            ),
          );
          expect(
            pred.state,
            IndoorOutdoorState.outdoor,
            reason: 'Brief 2s canyon multipath must not flip outdoor state',
          );
        }
      },
    );

    test(
      'Sustained GPS blackout + active steps + CMAltimeter floor shift transitions iPhone to indoor and resolves WorkoutEnvironmentController advice',
      () {
        final classifier = IodCompositeClassifier.liveMobile();
        final start = DateTime.utc(2026, 6, 15, 14, 0, 0);

        late IodSensorSnapshot lastSnap;
        var lastPred = classifier.predict(
          IodSensorSnapshot.empty(timestamp: start),
        );

        for (int s = 1; s <= 12; s++) {
          lastSnap = IodSensorSnapshot(
            timestamp: start.add(Duration(seconds: s)),
            hasLightSensor: false,
            hasGnssStatus: false,
            hasImuData: true,
            magneticMagnitudeMean: 44.6 + (s.isEven ? 0.2 : -0.2),
            accelMagnitudeMean: 0.75,
            hasGpsFix: false,
            gpsFixAgeSeconds: 10 + s,
            stepDelta: 2,
            hasBarometer: true,
            pressureHpa: 1012.0 - (s * 0.06),
            pressureDelta10sHpa: -0.52, // ~4.3m stair/floor ascent
            isNightTime: false,
          );
          lastPred = classifier.predict(lastSnap);
        }

        expect(lastPred.state, IndoorOutdoorState.indoor);
        expect(
          lastPred.modelVersion,
          IodCompositeClassifier.iosLiveModelVersion,
        );
        expect(lastPred.nativeClass, 'ios_magio_hmm:indoor');

        final workoutState = WorkoutSessionState(
          status: RecordingState.active,
          sessionId: 'sess-ios-1',
          activityType: 'Running',
          trackingMode: 'outdoor',
          recordingSource: 'gps',
          startedAt: start,
        );
        final iodState = IodState(
          isRecording: true,
          sessionId: 'sess-ios-1',
          currentPrediction: lastPred,
          latestSnapshot: lastSnap,
          totalSamplesCount: 12,
        );

        final advice = WorkoutEnvironmentController.resolveIodAdvice(
          workout: workoutState,
          legacyHint: 'detecting',
          iod: iodState,
          now: lastSnap.timestamp.add(const Duration(milliseconds: 500)),
          lastAcceptedGpsAt: null,
        );
        expect(advice.hint, 'indoor');
        expect(advice.usedForHint, isTrue);
      },
    );

    test(
      'CIOD Sensor-Only and MagIO-Only modes run deterministically without light or GPS',
      () {
        final ciodModel = IosMultiSensorIodClassifier(
          mode: IosIodEvaluationMode.ciodSensorOnly,
        );
        final magIoModel = IosMultiSensorIodClassifier(
          mode: IosIodEvaluationMode.magIoOnly,
        );
        final t0 = DateTime.utc(2026, 6, 15, 11, 0, 0);

        for (int i = 0; i < 10; i++) {
          final snap = IodSensorSnapshot(
            timestamp: t0.add(Duration(seconds: i)),
            hasImuData: true,
            magneticMagnitudeMean: 44.7 + (i.isEven ? 0.15 : -0.15),
            accelMagnitudeMean: 0.22,
            isNightTime: true,
          );
          final p1 = ciodModel.classify(snap);
          final p2 = magIoModel.classify(snap);
          expect(p1.state, isNot(IndoorOutdoorState.unknown));
          expect(p2.state, isNot(IndoorOutdoorState.unknown));
          expect(p1.inferenceLatencyMs, lessThanOrEqualTo(10));
        }
      },
    );
  });

  group('EnvironmentClassifier iOS GPS-Blackout Gate', () {
    test(
      'emits indoor with fallbackSuggested when GPS fixes stall >= 8s while steps accumulate',
      () async {
        final classifier = EnvironmentClassifier(activityType: 'running');
        addTearDown(classifier.dispose);

        final t0 = DateTime.utc(2026, 6, 15, 8, 0, 0);
        final events = <ClassifierEvent>[];
        final sub = classifier.stateStream.listen(events.add);
        addTearDown(sub.cancel);

        // Single initial outdoor fix before runner enters concrete gym (fewer than 3 fixes!)
        classifier.addPosition(
          Position(
            latitude: 10.77,
            longitude: 106.70,
            timestamp: t0,
            accuracy: 9.0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 2.2,
            speedAccuracy: 0,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(classifier.currentState, TrackingEnvironment.detecting);

        // GPS goes silent for 9s-12s while pedometer reports active running steps
        classifier.addStepDelta(4, now: t0.add(const Duration(seconds: 9)));
        classifier.addStepDelta(4, now: t0.add(const Duration(seconds: 10)));
        classifier.addStepDelta(4, now: t0.add(const Duration(seconds: 11)));
        await Future<void>.delayed(Duration.zero);

        expect(classifier.currentState, TrackingEnvironment.indoor);
        expect(events.last.environment, TrackingEnvironment.indoor);
        expect(events.last.fallbackSuggested, isTrue);
        expect(events.last.reason, contains('gps_blackout_active_steps'));
      },
    );
  });
}
