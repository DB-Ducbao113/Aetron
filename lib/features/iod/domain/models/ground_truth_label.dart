import 'indoor_outdoor_state.dart';

export 'indoor_outdoor_state.dart' show GroundTruthEnvironment;

/// An explicit manual ground truth event timestamped during a field recording trial.
class GroundTruthEvent {
  final DateTime timestamp;
  final GroundTruthEnvironment environment;
  final String? note;
  final String? transitionDescription;

  const GroundTruthEvent({
    required this.timestamp,
    required this.environment,
    this.note,
    this.transitionDescription,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'environment': environment.code,
      'note': note,
      'transition_description': transitionDescription,
    };
  }

  factory GroundTruthEvent.fromJson(Map<String, dynamic> json) {
    return GroundTruthEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      environment:
          GroundTruthEnvironment.fromCode(json['environment'] as String?),
      note: json['note'] as String?,
      transitionDescription: json['transition_description'] as String?,
    );
  }
}

