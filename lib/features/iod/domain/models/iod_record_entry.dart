import 'ground_truth_label.dart';
import 'indoor_outdoor_state.dart';
import 'iod_prediction.dart';
import 'iod_sensor_snapshot.dart';

/// A complete empirical data point combining synchronized sensor observations,
/// model inference output, and optional ground-truth reference labels.
class IodRecordEntry {
  final String sessionId;
  final int epochIndex;
  final DateTime timestamp;
  final IodSensorSnapshot snapshot;
  final IodPrediction prediction;
  final GroundTruthEnvironment? groundTruth;
  final String? groundTruthNote;

  const IodRecordEntry({
    required this.sessionId,
    required this.epochIndex,
    required this.timestamp,
    required this.snapshot,
    required this.prediction,
    this.groundTruth,
    this.groundTruthNote,
  });

  IodRecordEntry copyWithGroundTruth({
    required GroundTruthEnvironment groundTruth,
    String? note,
  }) {
    return IodRecordEntry(
      sessionId: sessionId,
      epochIndex: epochIndex,
      timestamp: timestamp,
      snapshot: snapshot,
      prediction: prediction,
      groundTruth: groundTruth,
      groundTruthNote: note ?? groundTruthNote,
    );
  }

  static List<String> csvHeaders() {
    return [
      'session_id',
      'epoch_index',
      'timestamp',
      'predicted_state',
      'confidence',
      'deep_iod_p_outdoor',
      'transition_p',
      'inference_latency_ms',
      'has_gnss_status',
      'sat_count',
      'used_sat_count',
      'mean_cn0',
      'top4_cn0',
      'max_cn0',
      'has_gps_fix',
      'gps_lat',
      'gps_lon',
      'gps_acc_m',
      'gps_speed_mps',
      'has_light_sensor',
      'ambient_lux',
      'has_imu_data',
      'accel_mean',
      'accel_var',
      'gyro_mean',
      'mag_mean_ut',
      'mag_var',
      'step_delta',
      'ground_truth_env',
      'ground_truth_note',
      'reasoning',
    ];
  }

  List<String> toCsvRow() {
    return [
      sessionId,
      epochIndex.toString(),
      timestamp.toUtc().toIso8601String(),
      prediction.state.code,
      prediction.confidence.toStringAsFixed(4),
      prediction.deepIodOutdoorProbability?.toStringAsFixed(4) ?? '',
      prediction.transitionProbability?.toStringAsFixed(4) ?? '',
      prediction.inferenceLatencyMs.toString(),
      snapshot.hasGnssStatus ? '1' : '0',
      snapshot.satelliteCount?.toString() ?? '',
      snapshot.usedInFixCount?.toString() ?? '',
      snapshot.meanCn0DbHz?.toStringAsFixed(2) ?? '',
      snapshot.top4Cn0DbHz?.toStringAsFixed(2) ?? '',
      snapshot.maxCn0DbHz?.toStringAsFixed(2) ?? '',
      snapshot.hasGpsFix ? '1' : '0',
      snapshot.latitude?.toStringAsFixed(7) ?? '',
      snapshot.longitude?.toStringAsFixed(7) ?? '',
      snapshot.horizontalAccuracy?.toStringAsFixed(2) ?? '',
      snapshot.speed?.toStringAsFixed(2) ?? '',
      snapshot.hasLightSensor ? '1' : '0',
      snapshot.ambientLux?.toStringAsFixed(1) ?? '',
      snapshot.hasImuData ? '1' : '0',
      snapshot.accelMagnitudeMean?.toStringAsFixed(3) ?? '',
      snapshot.accelVariance?.toStringAsFixed(4) ?? '',
      snapshot.gyroMagnitudeMean?.toStringAsFixed(4) ?? '',
      snapshot.magneticMagnitudeMean?.toStringAsFixed(2) ?? '',
      snapshot.magneticVariance?.toStringAsFixed(3) ?? '',
      snapshot.stepDelta.toString(),
      groundTruth?.code ?? '',
      groundTruthNote ?? '',
      '"${prediction.reasoningSummary.replaceAll('"', '""')}"',
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'epoch_index': epochIndex,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'snapshot': snapshot.toJson(),
      'prediction': prediction.toJson(),
      'ground_truth': groundTruth?.code,
      'ground_truth_note': groundTruthNote,
    };
  }

  factory IodRecordEntry.fromJson(Map<String, dynamic> json) {
    return IodRecordEntry(
      sessionId: json['session_id'] as String,
      epochIndex: json['epoch_index'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      snapshot:
          IodSensorSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
      prediction:
          IodPrediction.fromJson(json['prediction'] as Map<String, dynamic>),
      groundTruth: json['ground_truth'] != null
          ? GroundTruthEnvironment.fromCode(json['ground_truth'] as String)
          : null,
      groundTruthNote: json['ground_truth_note'] as String?,
    );
  }
}
