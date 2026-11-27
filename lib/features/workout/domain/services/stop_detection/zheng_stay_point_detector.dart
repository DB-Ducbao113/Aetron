import 'package:latlong2/latlong.dart';

import 'stop_detector_interface.dart';

/// Causal online stay-point detector adapted from:
/// Zheng, Y., Zhang, L., Xie, X., & Ma, W.-Y. (2009).
/// "Mining interesting locations and travel sequences from GPS trajectories."
/// WWW 2009, pp. 791–800. DOI: 10.1145/1526709.1526816.
///
/// Adaptation disclosure:
/// - Original [Z09] algorithm scans trajectories offline at urban scale
///   (thetaD = 200 m, thetaT = 20 min).
/// - This causal streaming version keeps an anchor `p_i` and emits `isStopped`
///   once consecutive fixes stay within `thetaD` meters for at least `thetaT`
///   seconds (inherent detection latency = `thetaT`).
/// - `thetaD` and `thetaT` must be selected strictly on a validation split.
class ZhengStayPointDetector implements StopDetector {
  static const Distance _dist = Distance(roundResult: false);

  final double thetaDMeters;
  final Duration thetaT;

  LatLng? _anchorPoint;
  DateTime? _anchorTime;
  bool _wasStopped = false;

  ZhengStayPointDetector({
    this.thetaDMeters = 15.0,
    this.thetaT = const Duration(seconds: 20),
  });

  @override
  void reset() {
    _anchorPoint = null;
    _anchorTime = null;
    _wasStopped = false;
  }

  @override
  StopDetectionUpdate update({
    required LatLng point,
    required DateTime timestamp,
    required double accuracyMeters,
    double? speedMs,
  }) {
    if (_anchorPoint == null || _anchorTime == null) {
      _anchorPoint = point;
      _anchorTime = timestamp;
      _wasStopped = false;
      return const StopDetectionUpdate(
        isStopped: false,
        stopProbability: 0.0,
        transitionedToStop: false,
        transitionedToMove: false,
      );
    }

    final dMeters = _dist.as(LengthUnit.Meter, _anchorPoint!, point);
    if (dMeters >= thetaDMeters) {
      final moved = _wasStopped;
      _anchorPoint = point;
      _anchorTime = timestamp;
      _wasStopped = false;
      return StopDetectionUpdate(
        isStopped: false,
        stopProbability: 0.0,
        transitionedToStop: false,
        transitionedToMove: moved,
      );
    }

    final dwell = timestamp.difference(_anchorTime!);
    final stoppedNow = dwell >= thetaT;
    final toStop = stoppedNow && !_wasStopped;
    final ratio = thetaT.inMilliseconds > 0
        ? (dwell.inMilliseconds / thetaT.inMilliseconds).clamp(0.0, 1.0)
        : (stoppedNow ? 1.0 : 0.0);
    _wasStopped = stoppedNow;

    return StopDetectionUpdate(
      isStopped: stoppedNow,
      stopProbability: ratio,
      transitionedToStop: toStop,
      transitionedToMove: false,
      stopOnsetTime: stoppedNow ? _anchorTime : null,
    );
  }
}
