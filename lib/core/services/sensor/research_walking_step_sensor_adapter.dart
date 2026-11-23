import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'oxford_step_detector.dart';
import 'xu_running_step_detector.dart';
import 'step_sensor_adapter.dart';
import 'step_sensor_types.dart';

/// Single-source research step stream (Oxford Walking or Xu Running). At most one source contributes counts.
/// The fallback's first cumulative counter sample establishes a new baseline;
/// counts during the source handover are unknowable and are not reconstructed.
class ResearchWalkingStepSensorAdapter implements StepSensorAdapter {
  final StepSensorAdapter fallback;
  final Stream<AccelerometerEvent> Function() _rawStream;
  final bool _supported;
  final bool running;
  final _walkingDetector = OxfordStepDetector();
  final _runningDetector = XuRunningStepDetector();
  final _controller = StreamController<StepSensorSample>.broadcast(sync: true);
  StreamSubscription<AccelerometerEvent>? _rawSub;
  StreamSubscription<StepSensorSample>? _osSub;
  Future<void>? _osStart;
  Timer? _watchdog;
  DateTime? _lastReceipt, _lastEmit;
  DateTime? _clockAnchor, _lastOsTimestamp;
  int? _sensorAnchorUs, _lastSensorUs;
  Duration _osTimeShift = Duration.zero;
  int _slowIntervals = 0;
  int? _fallbackOffset;
  int _count = 0, _generation = 0;
  bool _usingRaw = false;

  ResearchWalkingStepSensorAdapter({
    required this.fallback,
    this.running = false,
    Stream<AccelerometerEvent> Function()? rawStream,
  }) : _rawStream =
           rawStream ??
           (() => accelerometerEventStream(
             samplingPeriod: Duration(milliseconds: running ? 20 : 10),
           )),
       _supported =
           rawStream != null ||
           (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  @override
  bool get requiresSystemPermissions => fallback.requiresSystemPermissions;

  @override
  Stream<StepSensorSample> get sampleStream => _controller.stream;

  @override
  Future<StepSensorStatus> checkStatus() => fallback.checkStatus();

  @override
  Future<void> startStream() async {
    await stopStream();
    final generation = _generation;
    _count = 0;
    _lastReceipt = _lastEmit = null;
    _clockAnchor = null;
    _sensorAnchorUs = _lastSensorUs = null;
    _slowIntervals = 0;
    if (!_supported) {
      await _startFallback(generation, propagateError: true);
      return;
    }
    final ready = Completer<void>();
    _usingRaw = true;
    try {
      _rawSub = _rawStream().listen(
        (event) {
          if (!_usingRaw || generation != _generation) return;
          if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) {
            resetSegment();
            return;
          }
          final now = DateTime.now();
          final sensorUs = event.timestamp.microsecondsSinceEpoch;
          final previous = _lastSensorUs;
          if (previous != null && sensorUs <= previous) return;
          _lastSensorUs = sensorUs;
          // Interpolation cannot restore motion lost by a very sparse
          // accelerometer. Repeated intervals below the 15 Hz benchmark
          // rate (with a 5 ms tolerance) select the OS counter instead.
          // Running requires a denser stream (~25 Hz with 5 ms tolerance)
          // for the 5 Hz FIR and 50 Hz interpolation; engineering guard.
          if (previous != null &&
              sensorUs - previous > (running ? 45000 : 72000)) {
            _slowIntervals++;
            if (_slowIntervals >= 15) {
              unawaited(_startFallback(generation));
              return;
            }
          } else {
            _slowIntervals = 0;
          }
          _sensorAnchorUs ??= sensorUs;
          _clockAnchor ??= now;
          final sampleTime = _clockAnchor!.add(
            Duration(microseconds: sensorUs - _sensorAnchorUs!),
          );
          _lastReceipt = now;
          final events = running
              ? _runningDetector.addSample(sensorUs, event.x, event.y, event.z)
              : _walkingDetector.addSample(sensorUs, event.x, event.y, event.z);
          if (!ready.isCompleted) {
            ready.complete();
          }
          _count += events.length;
          if (events.isNotEmpty ||
              _lastEmit == null ||
              sampleTime.difference(_lastEmit!) >= const Duration(seconds: 1)) {
            _emit(
              StepSensorSample(
                rawSteps: _count,
                timestamp: sampleTime,
                receivedTimestamp: now,
                source: running
                    ? StepSensorSource.xuRunning
                    : StepSensorSource.oxfordWpd,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!ready.isCompleted) {
            ready.completeError(error);
          } else {
            unawaited(_startFallback(generation));
          }
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(StateError('Raw accelerometer unavailable'));
          } else {
            unawaited(_startFallback(generation));
          }
        },
      );
      await ready.future.timeout(const Duration(seconds: 2));
      if (generation != _generation || !_usingRaw) return;
      _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        final receipt = _lastReceipt;
        if (receipt != null &&
            DateTime.now().difference(receipt) > const Duration(seconds: 2)) {
          unawaited(_startFallback(generation));
        }
      });
    } catch (_) {
      await _startFallback(generation, propagateError: true);
    }
  }

  Future<void> _startFallback(
    int generation, {
    bool propagateError = false,
  }) async {
    if (generation != _generation || _osSub != null) return;
    _usingRaw = false;
    _watchdog?.cancel();
    await _rawSub?.cancel();
    _rawSub = null;
    resetSegment();
    if (generation != _generation || _osSub != null) return;
    _fallbackOffset = null;
    _lastOsTimestamp = null;
    _osTimeShift = Duration.zero;
    _osSub = fallback.sampleStream.listen((sample) {
      if (generation != _generation) return;
      if (_lastOsTimestamp != null &&
          sample.timestamp.isBefore(_lastOsTimestamp!)) {
        return;
      }
      _lastOsTimestamp = sample.timestamp;
      if (_fallbackOffset == null) {
        _fallbackOffset = _count - sample.rawSteps;
        final previous = _lastEmit;
        if (previous != null && !sample.timestamp.isAfter(previous)) {
          _osTimeShift =
              previous.difference(sample.timestamp) +
              const Duration(microseconds: 1);
        }
      }
      _count = sample.rawSteps + _fallbackOffset!;
      _emit(
        StepSensorSample(
          rawSteps: _count,
          timestamp: sample.timestamp.add(_osTimeShift),
          receivedTimestamp: sample.receivedTimestamp,
          nativeCadenceStepsPerSec: sample.nativeCadenceStepsPerSec,
          source: sample.source,
        ),
      );
    }, onError: _controller.addError);
    try {
      final start = fallback.startStream();
      _osStart = start;
      await start;
    } catch (error, stack) {
      if (generation != _generation) return;
      await _osSub?.cancel();
      _osSub = null;
      _osStart = null;
      if (generation == _generation && !_controller.isClosed) {
        if (propagateError) rethrow;
        _controller.addError(error, stack);
      }
    }
  }

  void _emit(StepSensorSample sample) {
    if (_controller.isClosed) return;
    _lastEmit = sample.timestamp;
    _controller.add(sample);
  }

  /// Discard delayed evidence across explicit pause/resume; preserve count.
  void resetSegment() {
    _walkingDetector.reset();
    _runningDetector.reset();
  }

  @override
  Future<void> stopStream() async {
    _generation++;
    _usingRaw = false;
    _watchdog?.cancel();
    _watchdog = null;
    final raw = _rawSub;
    final os = _osSub;
    final startingOs = _osStart;
    _rawSub = _osSub = null;
    _osStart = null;
    resetSegment();
    await raw?.cancel();
    await os?.cancel();
    if (startingOs != null) {
      try {
        await startingOs;
      } catch (_) {
        // Startup already failed; still release platform resources.
      }
    }
    if (os != null || startingOs != null) await fallback.stopStream();
  }

  @override
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  ) async => null; // Raw-IMU counts have no OS historical equivalence.

  @override
  void dispose() {
    unawaited(stopStream());
    unawaited(_controller.close());
    // The parent service owns the fallback adapter.
  }
}
