/// Tracks actual raw GPS stream continuity independently of route acceptance.
///
/// A stationary device may emit hundreds of valid raw fixes which are rejected
/// as tiny movements. The time since the last *accepted* route fix is therefore
/// not evidence of a GPS blackout.
///
/// Keep an observed outage pending until the next eligible route anchor, so a
/// low-quality first recovery fix cannot erase the gap.
class GpsRawSignalContinuity {
  final double gapThresholdSec;
  DateTime? _lastRawFixTimestamp;
  double _pendingGapDurationSec = 0.0;

  GpsRawSignalContinuity({required this.gapThresholdSec})
      : assert(gapThresholdSec > 0);

  DateTime? get lastRawFixTimestamp => _lastRawFixTimestamp;
  double get pendingGapDurationSec => _pendingGapDurationSec;

  /// Returns false for duplicate or out-of-order sensor timestamps.
  ///
  /// The caller can still preserve the original raw sample for diagnostics,
  /// but must not feed stale samples into the accepted route.
  bool observe(DateTime timestamp) {
    final previous = _lastRawFixTimestamp;
    if (previous != null && !timestamp.isAfter(previous)) {
      return false;
    }

    if (previous != null) {
      final dtSec = timestamp.difference(previous).inMilliseconds / 1000.0;
      if (dtSec > gapThresholdSec) {
        _pendingGapDurationSec = dtSec;
      }
    }

    _lastRawFixTimestamp = timestamp;
    return true;
  }

  /// Call only after a GPS fix has seeded, re-anchored or appended the route.
  void acknowledgeRouteAnchor() {
    _pendingGapDurationSec = 0.0;
  }

  void reset() {
    _lastRawFixTimestamp = null;
    _pendingGapDurationSec = 0.0;
  }
}
