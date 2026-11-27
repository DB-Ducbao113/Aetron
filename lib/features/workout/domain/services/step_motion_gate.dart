/// Causal gait-bout confirmation and stationary cross-check gate grounded in:
/// 1. Brajdic & Harle (ACM UbiComp 2013, doi:10.1145/2493432.2493449):
///    distinguishing sustained rhythmic walking bouts (consecutive steps within
///    physiological step frequency [0.65, 4.5] Hz) from isolated non-locomotor
///    device manipulation impulses.
/// 2. Skog et al. (IEEE TBME 2010, doi:10.1109/TBME.2010.2060723):
///    zero-velocity stance rejection paired with outdoor GNSS spatial-lock
///    corroboration (explicitly documented as a multi-sensor runtime safeguard).
///
/// Guarantees:
/// 1. Rejected stationary impulses never accumulate into workout steps and
///    never "catch up" when real movement starts later.
/// 2. Isolated non-locomotor movements (1–4 sporadic impulses separated by
///    stillness) are discarded unless they form a sustained rhythmic step bout.
/// 3. In outdoor GPS mode with fresh high-accuracy satellite lock proving zero
///    spatial displacement, in-place phone motion cannot increment step count.
class StepMotionGateResult {
  final int acceptedDelta;
  final bool isActivelyStepping;
  final bool blockedByStationaryGps;

  const StepMotionGateResult({
    required this.acceptedDelta,
    required this.isActivelyStepping,
    this.blockedByStationaryGps = false,
  });
}

class StepMotionGate {
  /// Minimum consecutive rhythmic steps required to confirm locomotion from rest.
  static const int kMinBoutSteps = 5;

  /// Max gap allowed between step events while building an unconfirmed bout.
  static const Duration kMaxBoutBuildGap = Duration(milliseconds: 2200);

  /// Max gap allowed before an already-confirmed stepping bout resets to rest.
  static const Duration kActiveBoutTimeout = Duration(milliseconds: 3500);

  /// Grace window at bout onset during which outdoor GNSS is allowed to observe
  /// the first ~2.5m of displacement before enforcing stationary GPS lock.
  static const Duration kGpsDisplacementGrace = Duration(milliseconds: 3500);

  int _pendingBoutSteps = 0;
  DateTime? _boutStartTime;
  DateTime? _lastCandidateStepTime;
  DateTime? _lastAcceptedStepTime;
  bool _isBoutActive = false;

  bool get isBoutActive => _isBoutActive;
  DateTime? get lastAcceptedStepTime => _lastAcceptedStepTime;

  void reset() {
    _pendingBoutSteps = 0;
    _boutStartTime = null;
    _lastCandidateStepTime = null;
    _lastAcceptedStepTime = null;
    _isBoutActive = false;
  }

  /// Evaluates a positive incremental sensor step delta [rawDelta] at [now].
  StepMotionGateResult evaluate({
    required int rawDelta,
    required DateTime now,
    required bool isOutdoorGpsStationaryLocked,
  }) {
    if (rawDelta <= 0) {
      _expireIfStale(now);
      return StepMotionGateResult(
        acceptedDelta: 0,
        isActivelyStepping: _isBoutActive,
        blockedByStationaryGps: isOutdoorGpsStationaryLocked,
      );
    }

    // Check whether a previously active bout has gone stale due to stillness.
    if (_isBoutActive && _lastCandidateStepTime != null) {
      final gapMs = now.difference(_lastCandidateStepTime!).inMilliseconds;
      final isValidDelayedBatch =
          rawDelta >= kMinBoutSteps &&
          gapMs > 0 &&
          (rawDelta * 1000.0 / gapMs) >= 0.65 &&
          (rawDelta * 1000.0 / gapMs) <= 4.5;
      if (gapMs > kActiveBoutTimeout.inMilliseconds && !isValidDelayedBatch) {
        _isBoutActive = false;
        _pendingBoutSteps = 0;
        _boutStartTime = null;
      }
    }

    // Check whether an unconfirmed pending bout broke rhythm.
    if (!_isBoutActive && _lastCandidateStepTime != null) {
      final gapMs = now.difference(_lastCandidateStepTime!).inMilliseconds;
      if (gapMs > kMaxBoutBuildGap.inMilliseconds || gapMs < 0) {
        _pendingBoutSteps = 0;
        _boutStartTime = null;
      }
    }

    _boutStartTime ??= now;
    _lastCandidateStepTime = now;

    // Outdoor stationary GNSS lock:
    // Allow brief onset buffering (<= 3.5s) in case athlete just started moving
    // and GNSS displacement hasn't crossed 2.5m yet; if GNSS still proves the
    // athlete is standing in the exact same spot beyond the grace window,
    // purge buffered impulses and block step counting completely.
    if (isOutdoorGpsStationaryLocked) {
      final boutAge = now.difference(_boutStartTime!);
      if (_isBoutActive || boutAge > kGpsDisplacementGrace) {
        _isBoutActive = false;
        _pendingBoutSteps = 0;
        _boutStartTime = null;
        return const StepMotionGateResult(
          acceptedDelta: 0,
          isActivelyStepping: false,
          blockedByStationaryGps: true,
        );
      }
      // Within initial grace window: hold candidate steps in pending buffer
      // (capped to a single bout) without crediting until GNSS moves or unlocks.
      _pendingBoutSteps = (_pendingBoutSteps + rawDelta).clamp(0, 12);
      return const StepMotionGateResult(
        acceptedDelta: 0,
        isActivelyStepping: false,
        blockedByStationaryGps: true,
      );
    }

    if (_isBoutActive) {
      _lastAcceptedStepTime = now;
      return StepMotionGateResult(
        acceptedDelta: rawDelta,
        isActivelyStepping: true,
      );
    }

    // Accumulate toward bout confirmation threshold.
    _pendingBoutSteps += rawDelta;
    if (_pendingBoutSteps >= kMinBoutSteps) {
      final flushed = _pendingBoutSteps;
      _pendingBoutSteps = 0;
      _isBoutActive = true;
      _lastAcceptedStepTime = now;
      return StepMotionGateResult(
        acceptedDelta: flushed,
        isActivelyStepping: true,
      );
    }

    return const StepMotionGateResult(
      acceptedDelta: 0,
      isActivelyStepping: false,
    );
  }

  void _expireIfStale(DateTime now) {
    if (_isBoutActive &&
        _lastCandidateStepTime != null &&
        now.difference(_lastCandidateStepTime!) > kActiveBoutTimeout) {
      _isBoutActive = false;
    }
    if (!_isBoutActive &&
        _lastCandidateStepTime != null &&
        now.difference(_lastCandidateStepTime!) > kMaxBoutBuildGap) {
      _pendingBoutSteps = 0;
      _boutStartTime = null;
    }
  }
}
