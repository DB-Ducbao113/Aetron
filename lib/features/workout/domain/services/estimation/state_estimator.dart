import 'package:latlong2/latlong.dart';

class GnssObs {
  final LatLng point;
  final DateTime timestamp;
  final double accuracyMeters;
  final double? speedMs;

  const GnssObs({
    required this.point,
    required this.timestamp,
    required this.accuracyMeters,
    this.speedMs,
  });
}

class PdrObs {
  final DateTime timestamp;
  final double stepLengthMeters;
  final double cadenceSpm;
  final double? headingRad;

  const PdrObs({
    required this.timestamp,
    required this.stepLengthMeters,
    required this.cadenceSpm,
    this.headingRad,
  });

  double get speedMs => stepLengthMeters * (cadenceSpm / 60.0);
}

class IodContextHint {
  final DateTime timestamp;
  final bool isIndoor;
  final double outdoorProbability;

  const IodContextHint({
    required this.timestamp,
    required this.isIndoor,
    required this.outdoorProbability,
  });
}

class ModeProbabilities {
  final double stationary;
  final double moving;

  const ModeProbabilities({required this.stationary, required this.moving});

  bool get isMapStationary => stationary >= moving;
}

class StateEstimate {
  final LatLng position;
  final double velocityEastMs;
  final double velocityNorthMs;
  final double speedMs;
  final double nis;
  final double igg3Weight;
  final bool gnssRejected;
  final DateTime timestamp;

  const StateEstimate({
    required this.position,
    required this.velocityEastMs,
    required this.velocityNorthMs,
    required this.speedMs,
    required this.nis,
    required this.igg3Weight,
    required this.gnssRejected,
    required this.timestamp,
  });
}

/// SDD-08 unified causal state-estimation contract.
abstract class StateEstimator {
  void predict(DateTime t);
  void updateGnss(GnssObs obs);
  void updatePdr(PdrObs obs);
  void updateEnvironment(IodContextHint hint);
  StateEstimate? get estimate;
  ModeProbabilities get modes;
  void reset();
}
