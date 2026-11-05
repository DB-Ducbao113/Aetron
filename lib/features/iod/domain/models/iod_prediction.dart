import 'indoor_outdoor_state.dart';

/// The output of the Indoor-Outdoor detection subsystem.
///
/// Contains:
/// - [state]: The resolved application-level state (indoor, outdoor, transition, unknown).
/// - [confidence]: Metric between 0.0 and 1.0 expressing model certainty.
/// - [deepIodOutdoorProbability]: Continuous probability from the DeepIOD AMV module.
/// - [transitionProbability]: Probability of intermediate boundary transition (Yoo 2025).
/// - [nativeClass]: The raw unmapped classification from the primary model.
/// - [modelVersion]: Version identifier tracking algorithm iterations.
/// - [inferenceLatencyMs]: Latency of the classification cycle in milliseconds.
/// - [sensorAvailability]: Health flags of individual sensor channels.
/// - [reasoningSummary]: Key physical indicators that determined this classification.
/// - [isObservationalOnly]: Always true during the research benchmark phase.
class IodPrediction {
  final IndoorOutdoorState state;
  final double confidence;
  final double? deepIodOutdoorProbability;
  final double? transitionProbability;
  final String nativeClass;
  final String modelVersion;
  final int inferenceLatencyMs;
  final Map<String, bool> sensorAvailability;
  final String reasoningSummary;
  final bool isObservationalOnly;

  const IodPrediction({
    required this.state,
    required this.confidence,
    this.deepIodOutdoorProbability,
    this.transitionProbability,
    required this.nativeClass,
    required this.modelVersion,
    required this.inferenceLatencyMs,
    required this.sensorAvailability,
    required this.reasoningSummary,
    this.isObservationalOnly = true,
  });

  factory IodPrediction.unknown({
    String reason = 'insufficient_sensor_data',
    String modelVersion = 'deepiod-baseline-v1.0',
    int latencyMs = 0,
    Map<String, bool>? sensorAvailability,
  }) {
    return IodPrediction(
      state: IndoorOutdoorState.unknown,
      confidence: 0.0,
      nativeClass: 'unknown',
      modelVersion: modelVersion,
      inferenceLatencyMs: latencyMs,
      sensorAvailability: sensorAvailability ?? const {},
      reasoningSummary: reason,
      isObservationalOnly: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.code,
      'confidence': confidence,
      'deep_iod_outdoor_probability': deepIodOutdoorProbability,
      'transition_probability': transitionProbability,
      'native_class': nativeClass,
      'model_version': modelVersion,
      'inference_latency_ms': inferenceLatencyMs,
      'sensor_availability': sensorAvailability,
      'reasoning_summary': reasoningSummary,
      'is_observational_only': isObservationalOnly,
    };
  }

  factory IodPrediction.fromJson(Map<String, dynamic> json) {
    return IodPrediction(
      state: IndoorOutdoorState.fromCode(json['state'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      deepIodOutdoorProbability:
          (json['deep_iod_outdoor_probability'] as num?)?.toDouble(),
      transitionProbability:
          (json['transition_probability'] as num?)?.toDouble(),
      nativeClass: json['native_class'] as String? ?? 'unknown',
      modelVersion: json['model_version'] as String? ?? 'deepiod-baseline-v1.0',
      inferenceLatencyMs: json['inference_latency_ms'] as int? ?? 0,
      sensorAvailability: (json['sensor_availability'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          const {},
      reasoningSummary: json['reasoning_summary'] as String? ?? '',
      isObservationalOnly: json['is_observational_only'] as bool? ?? true,
    );
  }
}

