import 'dart:collection';
import 'dart:math' as math;

/// Streaming adaptation of Salvi et al., EMBC 2018,
/// doi:10.1109/EMBC.2018.8513319, paired with a causal Magnitude-Variance
/// Zero-Velocity GLRT (Skog et al., IEEE TBME 2010, Eq. 13,
/// doi:10.1109/TBME.2010.2060723; Brajdic & Harle, ACM UbiComp 2013,
/// doi:10.1145/2493432.2493449) to reject stationary noise and single-tap spikes.
/// Reference: Oxford-step-counter/Java-Step-Counter, MIT,
/// dfd079a2678c8d29adbba08de840367f4d4fcd41.
///
/// Input is raw acceleration INCLUDING gravity (m/s²) and monotonic
/// microseconds. Output is the timestamp of each confirmed peak, only after
/// the supporting samples arrive. No end-of-recording lookahead or flush.
class OxfordStepDetector {
  static const _periodUs = 10000;
  static const _mergeUs = 200000;
  static const _maxGapUs = 250000;

  /// Minimum peak score floor (m/s²) for Salvi et al. (2018) WPD prominence.
  static const _minPeakThreshold = 0.35;

  /// Skog et al. (2010, Eq. 13) Magnitude-Variance GLRT stationary threshold
  /// T_MV = (1/W) * sum((||a_k|| - mean)^2) >= gamma_MV.
  /// Brajdic & Harle (ACM UbiComp 2013, Section 4.1) identify walk-detection
  /// accelerometer SD floor sigma >= 0.60 m/s² -> gamma_MV = 0.36 (m/s²)².
  static const _zuptMvGamma = 0.36;
  static const _zuptWindowSize = 100;
  static final _weights = List<double>.generate(
    13,
    (i) => math.exp(-0.5 * math.pow((i - 6) / (0.35 * 6), 2)),
  );
  static final _weightSum = _weights.reduce((a, b) => a + b);

  final _rawWindow = ListQueue<double>(13);
  final _smoothWindow = ListQueue<double>(35);
  final _zuptWindow = ListQueue<double>(_zuptWindowSize);
  double _zuptSum = 0.0;
  double _zuptSqSum = 0.0;
  int? _previousTime, _nextTime, _pendingTime;
  double _previousMagnitude = 0, _pendingScore = 0;
  double _mean = 0, _std = 0;
  int _samples = 0;

  /// Drop incomplete windows and pending peaks at a sensor discontinuity or
  /// workout pause/resume. Never carry a delayed peak across a boundary.
  void reset() {
    _rawWindow.clear();
    _smoothWindow.clear();
    _zuptWindow.clear();
    _zuptSum = 0.0;
    _zuptSqSum = 0.0;
    _previousTime = _nextTime = _pendingTime = null;
    _previousMagnitude = _pendingScore = _mean = _std = 0;
    _samples = 0;
  }

  List<int> addSample(int timestampUs, double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      reset();
      return const [];
    }
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (!magnitude.isFinite) {
      reset();
      return const [];
    }
    final previous = _previousTime;
    if (previous != null && timestampUs <= previous) return const [];
    if (previous == null || timestampUs - previous > _maxGapUs) {
      reset();
      _previousTime = _nextTime = timestampUs;
      _previousMagnitude = magnitude;
      return const [];
    }
    final events = <int>[];
    var next = _nextTime!;
    // Match reference linear interpolation to a 100 Hz grid.
    while (next < timestampUs) {
      final fraction = (next - previous) / (timestampUs - previous);
      final interpolated =
          _previousMagnitude + fraction * (magnitude - _previousMagnitude);
      _process(next, interpolated, events);
      next += _periodUs;
    }
    _nextTime = next;
    _previousTime = timestampUs;
    _previousMagnitude = magnitude;
    return events;
  }

  void _process(int time, double magnitude, List<int> events) {
    _zuptWindow.addLast(magnitude);
    _zuptSum += magnitude;
    _zuptSqSum += magnitude * magnitude;
    if (_zuptWindow.length > _zuptWindowSize) {
      final evicted = _zuptWindow.removeFirst();
      _zuptSum -= evicted;
      _zuptSqSum -= evicted * evicted;
    }
    _rawWindow.addLast(magnitude);
    if (_rawWindow.length < 13) return;
    var weighted = 0.0;
    var i = 0;
    for (final value in _rawWindow) {
      weighted += value * _weights[i++];
    }
    _rawWindow.removeFirst();
    _smoothWindow.addLast(weighted / _weightSum);
    if (_smoothWindow.length < 35) return;
    final middle = _smoothWindow.elementAt(17);
    var score = 0.0;
    for (final value in _smoothWindow) {
      score += middle - value;
    }
    score /= 34;
    _smoothWindow.removeFirst();
    final peakTime = time - (6 + 17) * _periodUs;

    // The reference DetectionStage's online mean/SD recurrence (including
    // its n=2 initialization), not a fitted threshold on benchmark labels.
    final oldMean = _mean;
    _samples++;
    final n = _samples;
    _mean = (score + (n - 1) * _mean) / n;
    if (n == 1) {
      _std = 0;
    } else if (n == 2) {
      _std =
          math.sqrt(math.pow(score - _mean, 2) + math.pow(oldMean - _mean, 2)) /
          2;
    } else {
      _std = math.sqrt(
        (n - 2) * _std * _std / (n - 1) +
            math.pow(oldMean - _mean, 2) +
            math.pow(score - _mean, 2) / n,
      );
    }

    // The Java reference increments on arrival of the NEXT separated peak,
    // losing a terminal peak and delaying a step indefinitely at rest.
    // Confirm the strongest candidate after its 200ms refractory interval
    // instead. This is an explicit live adaptation of its PostProcessStage.
    // Skog et al. (IEEE TBME 2010, Eq. 13) Magnitude-Variance GLRT:
    // T_MV = E[||a||^2] - (E[||a||])^2 >= gamma_MV rejects stationary stance
    // while remaining immune to isolated single-tap accelerometer impulses.
    final zwLen = _zuptWindow.length;
    double mvStat = 0.0;
    if (zwLen >= 35) {
      final zwMean = _zuptSum / zwLen;
      mvStat = math.max(0.0, (_zuptSqSum / zwLen) - (zwMean * zwMean));
    }
    final isDynamicMotion = zwLen >= 35 && mvStat >= _zuptMvGamma;

    final pending = _pendingTime;
    if (!isDynamicMotion) {
      _pendingTime = null;
      return;
    }
    if (pending != null && peakTime - pending > _mergeUs) {
      events.add(pending);
      _pendingTime = null;
    }
    // Suppress sensor noise and resting hand tremor when stationary.
    if (n > 15 && score - _mean > math.max(1.2 * _std, _minPeakThreshold)) {
      if (_pendingTime == null || score > _pendingScore) {
        _pendingTime = peakTime;
        _pendingScore = score;
      }
    }
  }
}
