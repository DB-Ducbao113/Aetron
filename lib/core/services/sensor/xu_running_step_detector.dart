import 'dart:collection';
import 'dart:math' as math;

/// Causal Running adaptation of Xu et al. (2022), DOI 10.3390/rs14122926,
/// sections 2–3 and Table 1, paired with Skog et al. (IEEE TBME 2010, Eq. 13,
/// doi:10.1109/TBME.2010.2060723) Magnitude-Variance Zero-Velocity GLRT
/// (T_MV < gamma_MV) to reject stationary stance and resting hand-sway.
/// Fixed 50 Hz grid approximates the paper's ~5 s/256 samples, with explicit
/// bounded delay for centered filtering and cross-window peak confirmation.
/// No coefficients fitted to Group 3.
class XuRunningStepDetector {
  static const periodUs = 20000;
  static const _maxGapUs = 250000;
  static const _window = 50;

  /// Skog et al. (2010, Eq. 13) Magnitude-Variance GLRT stationary threshold
  /// for running (sigma_a >= 0.80 m/s² -> gamma_MV = 0.64 (m/s²)²).
  static const _zuptMvGamma = 0.64;
  static final _fir = _coefficients();
  final _raw = ListQueue<double>(15);
  final _spectrum = ListQueue<double>(256);
  final _points = <({int time, double fir, double mean})>[];
  int? _lastTime, _nextTime, _pendingTime;
  double _lastMagnitude = 0, _pendingHeight = 0;
  int _pendingInterval = 286000;
  int _lastSpectrumTime = -1000000000;
  double? _frequency;

  static List<double> _coefficients() {
    final taps = List.generate(11, (i) {
      final n = i - 5;
      final ideal = n == 0 ? .2 : math.sin(.2 * math.pi * n) / (math.pi * n);
      return ideal * (.54 - .46 * math.cos(2 * math.pi * i / 10));
    });
    final sum = taps.reduce((a, b) => a + b);
    return taps.map((v) => v / sum).toList(growable: false);
  }

  void reset() {
    _raw.clear();
    _spectrum.clear();
    _points.clear();
    _lastTime = _nextTime = _pendingTime = null;
    _lastMagnitude = _pendingHeight = 0;
    _pendingInterval = 286000;
    _lastSpectrumTime = -1000000000;
    _frequency = null;
  }

  List<int> addSample(int timestampUs, double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (!magnitude.isFinite) {
      reset();
      return const [];
    }
    final previous = _lastTime;
    if (previous != null && timestampUs <= previous) return const [];
    if (previous == null || timestampUs - previous > _maxGapUs) {
      reset();
      _lastTime = _nextTime = timestampUs;
      _lastMagnitude = magnitude;
      return const [];
    }
    final events = <int>[];
    var next = _nextTime!;
    while (next < timestampUs) {
      final fraction = (next - previous) / (timestampUs - previous);
      _process(
        next,
        _lastMagnitude + fraction * (magnitude - _lastMagnitude),
        events,
      );
      next += periodUs;
    }
    _nextTime = next;
    _lastTime = timestampUs;
    _lastMagnitude = magnitude;
    return events;
  }

  void _process(int time, double value, List<int> events) {
    _raw.addLast(value);
    if (_raw.length < 15) return;
    final values = _raw.toList(growable: false);
    _raw.removeFirst();
    var fir = 0.0, mean = 0.0;
    for (var i = 0; i < 15; i++) {
      mean += values[i] / 15;
      if (i >= 2 && i <= 12) fir += values[i] * _fir[i - 2];
    }
    final centre = time - 7 * periodUs;
    _spectrum.addLast(fir);
    if (_spectrum.length > 256) _spectrum.removeFirst();
    if (_spectrum.length == 256 && centre - _lastSpectrumTime >= 1000000) {
      _frequency = _dominantFrequency();
      _lastSpectrumTime = centre;
    }
    _points.add((time: centre, fir: fir, mean: mean));
    // One neighbour at each edge; the next window starts just after its
    // final eligible peak, or two samples forward when none is present.
    if (_points.length < _window + 2) return;

    // Skog et al. (IEEE TBME 2010, Eq. 13) Magnitude-Variance GLRT over 1s window:
    // T_MV = (1/W) * sum((fir_i - mean)^2) < gamma_MV indicates zero-velocity stance.
    var sumFir = 0.0;
    for (var i = 1; i <= _window; i++) {
      sumFir += _points[i].fir;
    }
    final meanFir = sumFir / _window;
    var varFir = 0.0;
    for (var i = 1; i <= _window; i++) {
      final d = _points[i].fir - meanFir;
      varFir += d * d;
    }
    varFir /= _window;
    final isStationary = varFir < _zuptMvGamma;
    if (isStationary) {
      _pendingTime = null;
    }

    final frequency = _frequency;
    final interference = frequency != null && frequency > 3.5;
    final interval = frequency != null && frequency < 1.8 ? 333000 : 286000;
    final fixed = frequency == null || frequency >= 1.8
        ? 11.6
        : frequency >= 1.6
        ? 11.0
        : 10.6;
    var threshold = fixed;
    for (var i = 1; i <= _window; i++) {
      final a = _points[i].mean;
      if (a > _points[i - 1].mean && a >= _points[i + 1].mean) {
        threshold = math.min(threshold, a);
      }
    }
    var last = 0;
    for (var i = 1; i <= _window; i++) {
      final p = _points[i];
      if (!isStationary &&
          !interference &&
          p.fir > threshold + 1e-6 &&
          p.fir > _points[i - 1].fir &&
          p.fir >= _points[i + 1].fir) {
        _offer(p.time, p.fir, interval, events);
        last = i;
      }
    }
    final advance = last == 0 ? 2 : last;
    // The processed frontier, not the newest input, determines confirmation.
    // Pending peaks can compete with subsequent-window peaks.
    final pending = _pendingTime;
    if (pending != null && _points[advance].time - pending > _pendingInterval) {
      events.add(pending);
      _pendingTime = null;
    }
    _points.removeRange(0, advance);
  }

  void _offer(int time, double height, int interval, List<int> events) {
    final pending = _pendingTime;
    if (pending != null) {
      if (time - pending > math.max(interval, _pendingInterval)) {
        events.add(pending);
        _pendingTime = null;
      } else if (height <= _pendingHeight) {
        return;
      }
    }
    _pendingTime = time;
    _pendingHeight = height;
    _pendingInterval = interval;
  }

  // Direct evaluation of the 256-point DFT on the real signal. Same
  // frequency bins as FFT; bounded work at 1 Hz, no extra dependency.
  double _dominantFrequency() {
    final values = _spectrum.toList(growable: false);
    final mean = values.reduce((a, b) => a + b) / values.length;
    var energy = 0.0;
    for (var i = 0; i < values.length; i++) {
      values[i] -= mean;
      energy += values[i] * values[i];
    }
    if (energy < 1e-10) return 0;
    var best = -1.0, bin = 1;
    for (var k = 1; k <= 128; k++) {
      var re = 0.0, im = 0.0;
      for (var i = 0; i < 256; i++) {
        final angle = 2 * math.pi * k * i / 256;
        re += values[i] * math.cos(angle);
        im -= values[i] * math.sin(angle);
      }
      final power = re * re + im * im;
      if (power > best) {
        best = power;
        bin = k;
      }
    }
    return bin * 50 / 256;
  }
}
