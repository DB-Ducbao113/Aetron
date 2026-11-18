import 'dart:collection';
import 'dart:math' as math;

/// Streaming adaptation of Salvi et al., EMBC 2018,
/// doi:10.1109/EMBC.2018.8513319.
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
  static final _weights = List<double>.generate(
    13,
    (i) => math.exp(-0.5 * math.pow((i - 6) / (0.35 * 6), 2)),
  );
  static final _weightSum = _weights.reduce((a, b) => a + b);

  final _rawWindow = ListQueue<double>(13);
  final _smoothWindow = ListQueue<double>(35);
  int? _previousTime, _nextTime, _pendingTime;
  double _previousMagnitude = 0, _pendingScore = 0;
  double _mean = 0, _std = 0;
  int _samples = 0;

  /// Drop incomplete windows and pending peaks at a sensor discontinuity or
  /// workout pause/resume. Never carry a delayed peak across a boundary.
  void reset() {
    _rawWindow.clear();
    _smoothWindow.clear();
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
    final pending = _pendingTime;
    if (pending != null && peakTime - pending > _mergeUs) {
      events.add(pending);
      _pendingTime = null;
    }
    // Suppress floating-point roundoff on an exactly constant signal.
    if (n > 15 && score - _mean > math.max(1.2 * _std, 1e-9)) {
      if (_pendingTime == null || score > _pendingScore) {
        _pendingTime = peakTime;
        _pendingScore = score;
      }
    }
  }
}
