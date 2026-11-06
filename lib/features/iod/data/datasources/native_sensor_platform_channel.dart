import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Structured telemetry from Android hardware GNSS chipset.
class GnssSatelliteData {
  final int satelliteCount;
  final int usedInFixCount;
  final double meanCn0DbHz;
  final double maxCn0DbHz;
  final double top4Cn0DbHz;
  final DateTime timestamp;

  const GnssSatelliteData({
    required this.satelliteCount,
    required this.usedInFixCount,
    required this.meanCn0DbHz,
    required this.maxCn0DbHz,
    required this.top4Cn0DbHz,
    required this.timestamp,
  });

  factory GnssSatelliteData.fromMap(Map<dynamic, dynamic> map) {
    return GnssSatelliteData(
      satelliteCount: (map['satelliteCount'] as num?)?.toInt() ?? 0,
      usedInFixCount: (map['usedInFixCount'] as num?)?.toInt() ?? 0,
      meanCn0DbHz: (map['meanCn0DbHz'] as num?)?.toDouble() ?? 0.0,
      maxCn0DbHz: (map['maxCn0DbHz'] as num?)?.toDouble() ?? 0.0,
      top4Cn0DbHz: (map['top4Cn0DbHz'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Telemetry from ambient light sensor (lux photodiode).
class LightSensorData {
  final double lux;
  final DateTime timestamp;

  const LightSensorData({
    required this.lux,
    required this.timestamp,
  });

  factory LightSensorData.fromMap(Map<dynamic, dynamic> map) {
    return LightSensorData(
      lux: (map['lux'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Telemetry from genuine Android Wi-Fi scan query (Yoo 2025).
class WifiScanData {
  final bool hasScan;
  final int count;
  final double? meanRssiDbm;
  final Map<String, double> fingerprint; // BSSID -> RSSI (dBm)
  final DateTime timestamp;

  const WifiScanData({
    required this.hasScan,
    required this.count,
    this.meanRssiDbm,
    this.fingerprint = const {},
    required this.timestamp,
  });

  factory WifiScanData.fromMap(Map<dynamic, dynamic> map) {
    final rawFp = map['fingerprint'] as Map<dynamic, dynamic>?;
    final fp = <String, double>{};
    if (rawFp != null) {
      for (final entry in rawFp.entries) {
        if (entry.value is num) {
          fp[entry.key.toString()] = (entry.value as num).toDouble();
        }
      }
    }
    return WifiScanData(
      hasScan: map['hasScan'] as bool? ?? false,
      count: (map['count'] as num?)?.toInt() ?? 0,
      meanRssiDbm: (map['meanRssiDbm'] as num?)?.toDouble(),
      fingerprint: fp,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Platform channel bridge interfacing with Android native hardware sensors.
///
/// Gracefully degrades on non-Android platforms, desktop, web, or test environments.
class NativeSensorPlatformChannel {
  static const _gnssChannel = EventChannel('com.aetron.app/gnss_status');
  static const _lightChannel = EventChannel('com.aetron.app/light_sensor');
  static const _checkChannel = MethodChannel('com.aetron.app/sensors_check');

  Stream<GnssSatelliteData>? _gnssStream;
  Stream<LightSensorData>? _lightStream;

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Probes hardware sensor availability via Android native channel.
  Future<Map<String, bool>> checkAvailability() async {
    if (!isAndroid) {
      return {
        'hasLightSensor': false,
        'hasGnssStatus': false,
      };
    }

    try {
      final res = await _checkChannel.invokeMapMethod<String, dynamic>(
        'checkSensorAvailability',
      );
      return {
        'hasLightSensor': res?['hasLightSensor'] as bool? ?? false,
        'hasGnssStatus': res?['hasGnssStatus'] as bool? ?? false,
      };
    } catch (e) {
      debugPrint('[NativeSensorChannel] checkAvailability failed: $e');
      return {
        'hasLightSensor': false,
        'hasGnssStatus': false,
      };
    }
  }

  /// Broadcast stream of real-time GNSS satellite status.
  Stream<GnssSatelliteData> get gnssStatusStream {
    if (!isAndroid) return const Stream.empty();
    _gnssStream ??= _gnssChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => GnssSatelliteData.fromMap(event as Map))
        .handleError((error) {
          debugPrint('[NativeSensorChannel] GNSS stream error: $error');
        });
    return _gnssStream!;
  }

  /// Broadcast stream of real-time ambient illuminance (lux).
  Stream<LightSensorData> get lightSensorStream {
    if (!isAndroid) return const Stream.empty();
    _lightStream ??= _lightChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => LightSensorData.fromMap(event as Map))
        .handleError((error) {
          debugPrint('[NativeSensorChannel] Light sensor error: $error');
        });
    return _lightStream!;
  }

  /// Queries latest genuine Wi-Fi scan results from Android WifiManager (Yoo 2025).
  Future<WifiScanData?> getLatestWifiScan() async {
    if (!isAndroid) return null;
    try {
      final res = await _checkChannel.invokeMapMethod<String, dynamic>('getWifiScan');
      if (res != null) {
        return WifiScanData.fromMap(res);
      }
    } catch (e) {
      debugPrint('[NativeSensorChannel] getLatestWifiScan error: $e');
    }
    return null;
  }
}

