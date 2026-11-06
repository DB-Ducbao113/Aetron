import 'indoor_outdoor_state.dart';

/// Represents a physical building entrance, doorway, or transition boundary point
/// as formulated in Yoo (Electronics 2025, 14(13), 2598; Section 3.3).
class BuildingTransitionPoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const BuildingTransitionPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 5.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      };

  factory BuildingTransitionPoint.fromJson(Map<String, dynamic> json) =>
      BuildingTransitionPoint(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 5.0,
      );
}

/// Represents an environment handover event as formulated in Yoo (2025, Section 3.4).
///
/// Logged whenever the leading state changes between Indoor, Outdoor, and Transition.
/// Observational only: Does NOT disrupt or rewrite Aetron's production GPS/EKF engine.
class TransitionHandoverEvent {
  final IndoorOutdoorState fromState;
  final IndoorOutdoorState toState;
  final DateTime timestamp;
  final double confidence;
  final double? latitude;
  final double? longitude;
  final String triggerReason;

  const TransitionHandoverEvent({
    required this.fromState,
    required this.toState,
    required this.timestamp,
    required this.confidence,
    this.latitude,
    this.longitude,
    required this.triggerReason,
  });

  Map<String, dynamic> toJson() => {
        'from_state': fromState.code,
        'to_state': toState.code,
        'timestamp': timestamp.toIso8601String(),
        'confidence': confidence,
        'latitude': latitude,
        'longitude': longitude,
        'trigger_reason': triggerReason,
      };

  factory TransitionHandoverEvent.fromJson(Map<String, dynamic> json) =>
      TransitionHandoverEvent(
        fromState: IndoorOutdoorState.fromCode(json['from_state'] as String?),
        toState: IndoorOutdoorState.fromCode(json['to_state'] as String?),
        timestamp: DateTime.parse(json['timestamp'] as String),
        confidence: (json['confidence'] as num).toDouble(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        triggerReason: json['trigger_reason'] as String? ?? '',
      );
}
