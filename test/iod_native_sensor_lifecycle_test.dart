import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/iod/data/datasources/native_sensor_platform_channel.dart';
import 'package:fitness_exercise_application/features/iod/data/datasources/iod_sensor_acquisition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.aetron.app/sensors_check');
  late NativeSensorPlatformChannel platformChannel;

  setUp(() {
    platformChannel = NativeSensorPlatformChannel(isAndroidOverride: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NativeSensorPlatformChannel - BLE Lifecycle & Permission Handling', () {
    test('getLatestBleScan parses successful scan with active beacons and fingerprint', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getBleScan') {
          return {
            'hasScan': true,
            'count': 2,
            'meanRssiDbm': -65.5,
            'fingerprint': {
              'AA:BB:CC:DD:EE:01': -60.0,
              'AA:BB:CC:DD:EE:02': -71.0,
            },
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestBleScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isTrue);
      expect(scan.count, equals(2));
      expect(scan.meanRssiDbm, equals(-65.5));
      expect(scan.fingerprint.length, equals(2));
      expect(scan.fingerprint['AA:BB:CC:DD:EE:01'], equals(-60.0));
      expect(scan.reason, isNull);
    });

    test('getLatestBleScan handles PERMISSION_DENIED gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getBleScan') {
          return {
            'hasScan': false,
            'count': 0,
            'reason': 'PERMISSION_DENIED',
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestBleScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isFalse);
      expect(scan.count, equals(0));
      expect(scan.reason, equals('PERMISSION_DENIED'));
      expect(scan.fingerprint.isEmpty, isTrue);
    });

    test('getLatestBleScan handles BLUETOOTH_DISABLED gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getBleScan') {
          return {
            'hasScan': false,
            'count': 0,
            'reason': 'BLUETOOTH_DISABLED',
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestBleScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isFalse);
      expect(scan.reason, equals('BLUETOOTH_DISABLED'));
    });

    test('getLatestBleScan handles NO_BEACONS_DETECTED gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getBleScan') {
          return {
            'hasScan': false,
            'count': 0,
            'reason': 'NO_BEACONS_DETECTED',
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestBleScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isFalse);
      expect(scan.reason, equals('NO_BEACONS_DETECTED'));
    });

    test('startBleScan and stopBleScan invoke platform channel methods correctly', () async {
      final methodCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call.method);
        if (call.method == 'startBleScan') {
          return {'started': true, 'reason': 'OK'};
        } else if (call.method == 'stopBleScan') {
          return true;
        }
        return null;
      });

      final started = await platformChannel.startBleScan();
      expect(started, isTrue);
      expect(methodCalls, contains('startBleScan'));

      final stopped = await platformChannel.stopBleScan();
      expect(stopped, isTrue);
      expect(methodCalls, contains('stopBleScan'));
    });
  });

  group('NativeSensorPlatformChannel - Wi-Fi Lifecycle & Throttling Handling', () {
    test('getLatestWifiScan parses active scan with BSSID fingerprints', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getWifiScan') {
          return {
            'hasScan': true,
            'count': 3,
            'meanRssiDbm': -55.0,
            'fingerprint': {
              '00:11:22:33:44:01': -50.0,
              '00:11:22:33:44:02': -55.0,
              '00:11:22:33:44:03': -60.0,
            },
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestWifiScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isTrue);
      expect(scan.count, equals(3));
      expect(scan.meanRssiDbm, equals(-55.0));
      expect(scan.fingerprint.length, equals(3));
    });

    test('getLatestWifiScan handles NO_FRESH_WIFI_SCANS on background throttling', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getWifiScan') {
          return {
            'hasScan': false,
            'count': 0,
            'reason': 'NO_FRESH_WIFI_SCANS',
            'timestamp': 1700000000000,
          };
        }
        return null;
      });

      final scan = await platformChannel.getLatestWifiScan();
      expect(scan, isNotNull);
      expect(scan!.hasScan, isFalse);
      expect(scan.reason, equals('NO_FRESH_WIFI_SCANS'));
    });
  });

  group('IodSensorAcquisitionService - BLE Lifecycle Integration', () {
    test('stop() invokes stopBleScan to release hardware and clear cache', () async {
      final methodCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call.method);
        if (call.method == 'startBleScan') {
          return {'started': true, 'reason': 'OK'};
        } else if (call.method == 'stopBleScan') {
          return true;
        }
        return null;
      });

      final service = IodSensorAcquisitionService(nativeChannel: platformChannel);
      service.start();
      expect(methodCalls, contains('startBleScan'));

      service.stop();
      expect(methodCalls, contains('stopBleScan'));

      service.dispose();
    });
  });
}
