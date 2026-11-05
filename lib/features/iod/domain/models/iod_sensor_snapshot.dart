import 'dart:math' as math;

/// A 1-second normalized epoch snapshot of multi-modal smartphone sensor telemetry.
///
/// Implements the input feature specification from:
/// 1. DeepIOD (Sensors 2024, 24(16), 5125): 1 Hz normalized epoch, 9-axis IMU,
///    ambient light sensor (lux), and GPS positioning.
/// 2. Seamless Localization (Electronics 2025, 14(13), 2598): GNSS carrier-to-noise
///    density ratio (C/N0), satellite count, and motion continuity.
class IodSensorSnapshot {
  final DateTime timestamp;

  // GNSS Telemetry (Hardware chipset via native Android GnssStatus)
  final bool hasGnssStatus;
  final int? satelliteCount;
  final int? usedInFixCount;
  final double? meanCn0DbHz;
  final double? maxCn0DbHz;
  final double? top4Cn0DbHz;

  // GPS Fix & Kinematics (Location Manager / Geolocator)
  final bool hasGpsFix;
  final double? latitude;
  final double? longitude;
  final double? horizontalAccuracy;
  final double? speed;
  final double? altitude;
  final double? heading;

  // Optical Telemetry (Photodiode via Sensor.TYPE_LIGHT)
  final bool hasLightSensor;
  final double? ambientLux;

  // Inertial & Geomagnetic Telemetry (Sensors Plus: Accel, Gyro, Mag)
  final bool hasImuData;
  final double? accelMagnitudeMean;
  final double? accelVariance;
  final double? gyroMagnitudeMean;
  final double? magneticMagnitudeMean;
  final double? magneticVariance;

  // Pedometer Telemetry
  final int stepDelta;

  // Contextual flags
  final bool isNightTime;
  final bool isScreenOff;

  const IodSensorSnapshot({
    required this.timestamp,
    this.hasGnssStatus = false,
    this.satelliteCount,
    this.usedInFixCount,
    this.meanCn0DbHz,
    this.maxCn0DbHz,
    this.top4Cn0DbHz,
    this.hasGpsFix = false,
    this.latitude,
    this.longitude,
    this.horizontalAccuracy,
    this.speed,
    this.altitude,
    this.heading,
    this.hasLightSensor = false,
    this.ambientLux,
    this.hasImuData = false,
    this.accelMagnitudeMean,
    this.accelVariance,
    this.gyroMagnitudeMean,
    this.magneticMagnitudeMean,
    this.magneticVariance,
    this.stepDelta = 0,
    this.isNightTime = false,
    this.isScreenOff = false,
  });

  /// Factory for an empty snapshot when warming up or permissions are denied.
  factory IodSensorSnapshot.empty({DateTime? timestamp}) {
    return IodSensorSnapshot(timestamp: timestamp ?? DateTime.now());
  }

  /// Calculates total magnetic field magnitude from 3-axis readings:
  /// B = sqrt(Bx^2 + By^2 + Bz^2) (standard unit: microTesla uT).
  static double computeMagneticMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  /// Calculates 3D acceleration magnitude:
  /// a = sqrt(ax^2 + ay^2 + az^2) (standard unit: m/s^2).
  static double computeVectorMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  /// Checks if ambient light is strongly suggestive of direct or diffuse daylight
  /// (> 1,000 lux typical outdoor daylight on an overcast/sunny day).
  bool get isDaylightStrong => (ambientLux ?? 0.0) >= 1000.0;

  /// Checks if GNSS carrier-to-noise ratio indicates strong direct satellite line-of-sight.
  /// (> 28 dB-Hz typical outdoor threshold in Yoo 2025).
  bool get hasStrongSatelliteSignals => (top4Cn0DbHz ?? 0.0) >= 28.0;

  /// Checks if GPS fix has high uncertainty radius (> 35 meters).
  bool get isGpsWeak =>
      !hasGpsFix ||
      horizontalAccuracy == null ||
      horizontalAccuracy! > 35.0 ||
      (satelliteCount != null && satelliteCount! < 4);

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'has_gnss_status': hasGnssStatus,
      'satellite_count': satelliteCount,
      'used_in_fix_count': usedInFixCount,
      'mean_cn0_dbhz': meanCn0DbHz,
      'max_cn0_dbhz': maxCn0DbHz,
      'top4_cn0_dbhz': top4Cn0DbHz,
      'has_gps_fix': hasGpsFix,
      'latitude': latitude,
      'longitude': longitude,
      'horizontal_accuracy': horizontalAccuracy,
      'speed': speed,
      'altitude': altitude,
      'heading': heading,
      'has_light_sensor': hasLightSensor,
      'ambient_lux': ambientLux,
      'has_imu_data': hasImuData,
      'accel_magnitude_mean': accelMagnitudeMean,
      'accel_variance': accelVariance,
      'gyro_magnitude_mean': gyroMagnitudeMean,
      'magnetic_magnitude_mean': magneticMagnitudeMean,
      'magnetic_variance': magneticVariance,
      'step_delta': stepDelta,
      'is_night_time': isNightTime,
      'is_screen_off': isScreenOff,
    };
  }

  factory IodSensorSnapshot.fromJson(Map<String, dynamic> json) {
    return IodSensorSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),
      hasGnssStatus: json['has_gnss_status'] as bool? ?? false,
      satelliteCount: json['satellite_count'] as int?,
      usedInFixCount: json['used_in_fix_count'] as int?,
      meanCn0DbHz: (json['mean_cn0_dbhz'] as num?)?.toDouble(),
      maxCn0DbHz: (json['max_cn0_dbhz'] as num?)?.toDouble(),
      top4Cn0DbHz: (json['top4_cn0_dbhz'] as num?)?.toDouble(),
      hasGpsFix: json['has_gps_fix'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      horizontalAccuracy: (json['horizontal_accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      hasLightSensor: json['has_light_sensor'] as bool? ?? false,
      ambientLux: (json['ambient_lux'] as num?)?.toDouble(),
      hasImuData: json['has_imu_data'] as bool? ?? false,
      accelMagnitudeMean: (json['accel_magnitude_mean'] as num?)?.toDouble(),
      accelVariance: (json['accel_variance'] as num?)?.toDouble(),
      gyroMagnitudeMean: (json['gyro_magnitude_mean'] as num?)?.toDouble(),
      magneticMagnitudeMean:
          (json['magnetic_magnitude_mean'] as num?)?.toDouble(),
      magneticVariance: (json['magnetic_variance'] as num?)?.toDouble(),
      stepDelta: json['step_delta'] as int? ?? 0,
      isNightTime: json['is_night_time'] as bool? ?? false,
      isScreenOff: json['is_screen_off'] as bool? ?? false,
    );
  }
}
