import 'dart:async';

import 'package:fitness_exercise_application/features/iod/data/datasources/iod_sensor_acquisition_service.dart';
import 'package:fitness_exercise_application/features/iod/data/datasources/native_sensor_platform_channel.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/iod_composite_classifier.dart';
import 'package:fitness_exercise_application/features/iod/domain/services/deepiod_neural_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeLightChannel extends NativeSensorPlatformChannel {
  final light = StreamController<LightSensorData>.broadcast();

  _FakeLightChannel() : super(isAndroidOverride: false);

  @override
  Stream<LightSensorData> get lightSensorStream => light.stream;

  @override
  Future<bool> startBleScan() async => true;

  @override
  Future<bool> stopBleScan() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime.utc(2026, 11, 18);

  IodSensorSnapshot full(int second, {double? lux = 100}) => IodSensorSnapshot(
    timestamp: start.add(Duration(seconds: second)),
    hasLightSensor: lux != null,
    ambientLux: lux,
    hasImuData: true,
    magneticMagnitudeMean: 43.0,
    accelMagnitudeMean: 0.3,
    isNightTime: true,
  );

  test(
    'live adaptation needs ten real epochs and preserves model probability',
    () {
      final live = IodCompositeClassifier.liveMobile();
      final reference = DeepIodNeuralClassifier.mobile();
      for (var i = 0; i < 10; i++) {
        final sample = full(i);
        final actual = live.predict(sample);
        final expected = reference.classify(sample);
        if (i < 9) {
          expect(actual.state, IndoorOutdoorState.unknown);
          expect(actual.deepIodOutdoorProbability, isNull);
        } else {
          expect(actual.state, expected.state);
          expect(
            actual.deepIodOutdoorProbability,
            expected.deepIodOutdoorProbability,
          );
          expect(actual.nativeClass, startsWith('deepiod_c_mobile_adapted:'));
          expect(actual.modelVersion, IodCompositeClassifier.liveModelVersion);
          expect(actual.isObservationalOnly, isTrue);
        }
      }
    },
  );

  test(
    'missing or invalid trained inputs cause unknown and reset the window',
    () {
      final live = IodCompositeClassifier.liveMobile();
      for (var i = 0; i < 10; i++) {
        live.predict(full(i));
      }
      for (final sample in [
        full(10, lux: null),
        full(11, lux: double.nan),
        IodSensorSnapshot(
          timestamp: start.add(const Duration(seconds: 12)),
          hasGpsFix: true,
          horizontalAccuracy: 5.0,
          hasGnssStatus: true,
          top4Cn0DbHz: 40.0,
        ),
      ]) {
        final prediction = live.predict(sample);
        expect(prediction.state, IndoorOutdoorState.unknown);
        expect(prediction.deepIodOutdoorProbability, isNull);
        expect(prediction.reasoningSummary, contains('fallback_required'));
      }
      for (var i = 13; i < 22; i++) {
        expect(live.predict(full(i)).state, IndoorOutdoorState.unknown);
      }
      expect(live.predict(full(22)).state, isNot(IndoorOutdoorState.unknown));
      expect(live.predict(full(40)).state, IndoorOutdoorState.unknown);
      expect(live.predict(full(40)).state, IndoorOutdoorState.unknown);
      live.reset();
      expect(live.predict(full(41)).state, IndoorOutdoorState.unknown);
    },
  );

  test('native missing lux is not interpreted as genuine zero lux', () {
    expect(() => LightSensorData.fromMap({}), throwsFormatException);
    expect(() => LightSensorData.fromMap({'lux': -1}), throwsFormatException);
    expect(LightSensorData.fromMap({'lux': 0}).lux, 0);
  });

  test('missing inputs use the paper GPS rule only as labelled evidence', () {
    final live = IodCompositeClassifier.liveMobile();
    for (final accuracy in [2.0, 25.0]) {
      final prediction = live.predict(
        IodSensorSnapshot(
          timestamp: start,
          hasGpsFix: true,
          horizontalAccuracy: accuracy,
        ),
      );
      final expected = accuracy < 5
          ? IndoorOutdoorState.outdoor
          : IndoorOutdoorState.indoor;
      expect(prediction.state, expected);
      expect(
        prediction.nativeClass,
        'deepiod_gps_table4_adapted:${expected.code}',
      );
      expect(
        prediction.modelVersion,
        IodCompositeClassifier.gpsFallbackModelVersion,
      );
      expect(prediction.deepIodOutdoorProbability, isNull);
      expect(prediction.confidence, 0.0);
      expect(prediction.isObservationalOnly, isTrue);
    }
    for (final accuracy in [0.0, -1.0, 5.0, double.nan, double.infinity]) {
      final prediction = live.predict(
        IodSensorSnapshot(
          timestamp: start,
          hasGpsFix: true,
          horizontalAccuracy: accuracy,
        ),
      );
      expect(prediction.state, IndoorOutdoorState.unknown);
    }
  });

  test(
    'stale GPS is unavailable and stopped session cannot carry GPS cache',
    () {
      final service = IodSensorAcquisitionService(
        nativeChannel: NativeSensorPlatformChannel(isAndroidOverride: false),
      );
      addTearDown(service.dispose);
      service.updatePosition(
        Position(
          longitude: 106.7,
          latitude: 10.8,
          timestamp: start,
          accuracy: 3,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      expect(service.snapshotNow(timestamp: start).hasGpsFix, isTrue);
      expect(
        service
            .snapshotNow(timestamp: start.add(const Duration(seconds: 5)))
            .hasGpsFix,
        isFalse,
      );
      service.stop();
      expect(service.snapshotNow(timestamp: start).hasGpsFix, isFalse);
    },
  );

  testWidgets(
    'on-change lux persists across epochs but never across sessions',
    (tester) async {
      final channel = _FakeLightChannel();
      final service = IodSensorAcquisitionService(nativeChannel: channel);
      service.start();
      try {
        channel.light.add(LightSensorData(lux: 100, timestamp: start));
        await tester.pump();
        expect(service.snapshotNow().ambientLux, 100);
        await tester.pump(const Duration(seconds: 2));
        expect(service.snapshotNow().ambientLux, 100);
        channel.light.addError(StateError('sensor unavailable'));
        await tester.pump();
        expect(service.snapshotNow().hasLightSensor, isFalse);
        channel.light.add(LightSensorData(lux: 75, timestamp: start));
        await tester.pump();
        expect(service.snapshotNow().ambientLux, 75);
        service.stop();
        service.start();
        expect(service.snapshotNow().hasLightSensor, isFalse);
      } finally {
        service.dispose();
        await channel.light.close();
      }
    },
  );
}
