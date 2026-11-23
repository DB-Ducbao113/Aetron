import 'indoor_outdoor_state.dart';

/// A reference radio fingerprint point in a surveyed building or transition zone,
/// as defined in Yoo (*Electronics* 2025, 14(13), 2598).
class RadioFingerprintPoint {
  final String id;
  final String name;
  final IndoorOutdoorState state;
  final double? latitude;
  final double? longitude;

  /// Map of Wi-Fi BSSID -> Reference RSSI (dBm).
  final Map<String, double> wifiRssiDbm;

  /// Map of BLE Beacon MAC/UUID -> Reference RSSI (dBm).
  final Map<String, double> bleRssiDbm;

  const RadioFingerprintPoint({
    required this.id,
    required this.name,
    required this.state,
    this.latitude,
    this.longitude,
    this.wifiRssiDbm = const {},
    this.bleRssiDbm = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'state': state.code,
        'latitude': latitude,
        'longitude': longitude,
        'wifiRssiDbm': wifiRssiDbm,
        'bleRssiDbm': bleRssiDbm,
      };

  factory RadioFingerprintPoint.fromJson(Map<String, dynamic> json) {
    return RadioFingerprintPoint(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      state: IndoorOutdoorState.fromCode(json['state'] as String? ?? 'unknown'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      wifiRssiDbm: (json['wifiRssiDbm'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
      bleRssiDbm: (json['bleRssiDbm'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
    );
  }
}

/// A collection of surveyed radio fingerprint points representing a building, campus,
/// or indoor–outdoor transition corridor.
class RadioMap {
  final String id;
  final String buildingName;
  final List<RadioFingerprintPoint> points;

  const RadioMap({
    required this.id,
    required this.buildingName,
    required this.points,
  });

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'buildingName': buildingName,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory RadioMap.fromJson(Map<String, dynamic> json) {
    return RadioMap(
      id: json['id'] as String,
      buildingName: json['buildingName'] as String? ?? '',
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => RadioFingerprintPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
