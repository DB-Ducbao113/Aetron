import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../domain/models/iod_sensor_snapshot.dart';
import 'native_sensor_platform_channel.dart';

/// Aggregates and synchronizes multi-source sensor streams into normalized
/// 1 Hz epoch snapshots as specified by DeepIOD (2024) and Yoo (2025).
class IodSensorAcquisitionService {
  final NativeSensorPlatformChannel _nativeChannel;

  IodSensorAcquisitionService({
    NativeSensorPlatformChannel? nativeChannel,
  }) : _nativeChannel = nativeChannel ?? NativeSensorPlatformChannel();

  // Active subscriptions
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<GnssSatelliteData>? _gnssSub;
  StreamSubscription<LightSensorData>? _lightSub;
  Timer? _epochTimer;

  // Rolling buffers (cleared every 1-second epoch)
  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];
  final List<double> _magMagnitudes = [];
  final List<double> _recentLuxReadings = [];

  // Latest hardware state
  GnssSatelliteData? _latestGnss;
  Position? _latestPosition;
  int _stepDeltaSinceLastEpoch = 0;
  bool _isRunning = false;

  final _snapshotController = StreamController<IodSensorSnapshot>.broadcast();
  Stream<IodSensorSnapshot> get snapshotStream => _snapshotController.stream;

  bool get isRunning => _isRunning;

  /// Starts listening to available hardware sensors and initiates the 1 Hz epoch loop.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _clearBuffers();

    // 1. Subscribe to IMU Magnetometer
    try {
      _magSub = magnetometerEventStream().listen(
        (event) {
          final mag = IodSensorSnapshot.computeMagneticMagnitude(
            event.x,
            event.y,
            event.z,
          );
          _magMagnitudes.add(mag);
        },
        onError: (e) {
          debugPrint('[IodAcquisition] Magnetometer stream unavailable: $e');
        },
      );
    } catch (e) {
      debugPrint('[IodAcquisition] Magnetometer listener failed: $e');
    }

    // 2. Subscribe to IMU Accelerometer
    try {
      _accelSub = userAccelerometerEventStream().listen(
        (event) {
          final mag = IodSensorSnapshot.computeVectorMagnitude(
            event.x,
            event.y,
            event.z,
          );
          _accelMagnitudes.add(mag);
        },
        onError: (e) {
          debugPrint('[IodAcquisition] Accelerometer stream unavailable: $e');
        },
      );
    } catch (e) {
      debugPrint('[IodAcquisition] Accelerometer listener failed: $e');
    }

    // 3. Subscribe to IMU Gyroscope
    try {
      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          final mag = IodSensorSnapshot.computeVectorMagnitude(
            event.x,
            event.y,
            event.z,
          );
          _gyroMagnitudes.add(mag);
        },
        onError: (e) {
          debugPrint('[IodAcquisition] Gyroscope stream unavailable: $e');
        },
      );
    } catch (e) {
      debugPrint('[IodAcquisition] Gyroscope listener failed: $e');
    }

    // 4. Subscribe to Android Native GNSS status (C/N0 & satellites)
    try {
      _gnssSub = _nativeChannel.gnssStatusStream.listen(
        (data) {
          _latestGnss = data;
        },
        onError: (e) {
          debugPrint('[IodAcquisition] GNSS channel unavailable: $e');
        },
      );
    } catch (e) {
      debugPrint('[IodAcquisition] GNSS listener failed: $e');
    }

    // 5. Subscribe to Android Native Light sensor (Lux)
    try {
      _lightSub = _nativeChannel.lightSensorStream.listen(
        (data) {
          _recentLuxReadings.add(data.lux);
        },
        onError: (e) {
          debugPrint('[IodAcquisition] Light sensor channel unavailable: $e');
        },
      );
    } catch (e) {
      debugPrint('[IodAcquisition] Light sensor listener failed: $e');
    }

    // 6. Start 1 Hz Normalized Sampling Timer
    _epochTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitCurrentEpochSnapshot();
    });
  }

  /// Ingests a new GPS Position update from the location provider.
  void updatePosition(Position position) {
    _latestPosition = position;
  }

  /// Ingests step counter delta from the pedometer.
  void addStepDelta(int delta) {
    if (delta > 0) {
      _stepDeltaSinceLastEpoch += delta;
    }
  }

  /// Stops acquisition and releases all sensor listeners.
  void stop() {
    _isRunning = false;
    _epochTimer?.cancel();
    _epochTimer = null;

    _magSub?.cancel();
    _magSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _gnssSub?.cancel();
    _gnssSub = null;
    _lightSub?.cancel();
    _lightSub = null;

    _clearBuffers();
  }

  void dispose() {
    stop();
    _snapshotController.close();
  }

  void _clearBuffers() {
    _accelMagnitudes.clear();
    _gyroMagnitudes.clear();
    _magMagnitudes.clear();
    _recentLuxReadings.clear();
    _stepDeltaSinceLastEpoch = 0;
  }

  /// Aggregates readings over the last 1-second interval into an IodSensorSnapshot.
  IodSensorSnapshot snapshotNow({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();

    // Accelerometer stats
    final double? accelMean =
        _accelMagnitudes.isNotEmpty ? _computeMean(_accelMagnitudes) : null;
    final double? accelVar = _accelMagnitudes.length >= 2
        ? _computeVariance(_accelMagnitudes, accelMean!)
        : null;

    // Gyroscope stats
    final double? gyroMean =
        _gyroMagnitudes.isNotEmpty ? _computeMean(_gyroMagnitudes) : null;

    // Magnetometer stats
    final double? magMean =
        _magMagnitudes.isNotEmpty ? _computeMean(_magMagnitudes) : null;
    final double? magVar = _magMagnitudes.length >= 2
        ? _computeVariance(_magMagnitudes, magMean!)
        : null;

    // Light sensor stats
    final double? ambientLux = _recentLuxReadings.isNotEmpty
        ? _computeMean(_recentLuxReadings)
        : null;

    // Contextual day/night indicator (Hour < 6 or > 18.5)
    final hour = now.hour + (now.minute / 60.0);
    final isNight = hour < 6.0 || hour >= 18.5;

    // GPS fix
    final pos = _latestPosition;
    final hasFix = pos != null;

    return IodSensorSnapshot(
      timestamp: now,
      hasGnssStatus: _latestGnss != null,
      satelliteCount: _latestGnss?.satelliteCount,
      usedInFixCount: _latestGnss?.usedInFixCount,
      meanCn0DbHz: _latestGnss?.meanCn0DbHz,
      maxCn0DbHz: _latestGnss?.maxCn0DbHz,
      top4Cn0DbHz: _latestGnss?.top4Cn0DbHz,
      hasGpsFix: hasFix,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      horizontalAccuracy: pos?.accuracy,
      speed: pos?.speed,
      altitude: pos?.altitude,
      heading: pos?.heading,
      hasLightSensor: ambientLux != null,
      ambientLux: ambientLux,
      hasImuData: accelMean != null || magMean != null,
      accelMagnitudeMean: accelMean,
      accelVariance: accelVar,
      gyroMagnitudeMean: gyroMean,
      magneticMagnitudeMean: magMean,
      magneticVariance: magVar,
      stepDelta: _stepDeltaSinceLastEpoch,
      isNightTime: isNight,
    );
  }

  void _emitCurrentEpochSnapshot() {
    if (!_isRunning || _snapshotController.isClosed) return;
    final snapshot = snapshotNow();
    _snapshotController.add(snapshot);

    // Reset intra-epoch accumulators for next 1s window
    _accelMagnitudes.clear();
    _gyroMagnitudes.clear();
    _magMagnitudes.clear();
    _recentLuxReadings.clear();
    _stepDeltaSinceLastEpoch = 0;
  }

  double _computeMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    double sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  double _computeVariance(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    double sumSquaredDiff = 0.0;
    for (final v in values) {
      final diff = v - mean;
      sumSquaredDiff += diff * diff;
    }
    return sumSquaredDiff / (values.length - 1);
  }
}
