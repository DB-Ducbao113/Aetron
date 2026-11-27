import 'package:latlong2/latlong.dart';

/// Output of a causal stop/auto-pause detector at each incoming GNSS epoch.
class StopDetectionUpdate {
  final bool isStopped;
  final double stopProbability;
  final bool transitionedToStop;
  final bool transitionedToMove;
  final DateTime? stopOnsetTime;

  const StopDetectionUpdate({
    required this.isStopped,
    required this.stopProbability,
    required this.transitionedToStop,
    required this.transitionedToMove,
    this.stopOnsetTime,
  });
}

/// Common causal interface for SDD-01 stop/auto-pause detectors.
abstract class StopDetector {
  StopDetectionUpdate update({
    required LatLng point,
    required DateTime timestamp,
    required double accuracyMeters,
    double? speedMs,
  });

  void reset();
}
