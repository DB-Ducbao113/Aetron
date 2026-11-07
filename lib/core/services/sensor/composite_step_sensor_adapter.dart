import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native_step_sensor_adapter.dart';
import 'pedometer_step_sensor_adapter.dart';
import 'step_sensor_adapter.dart';
import 'step_sensor_types.dart';

/// Composite adapter that prefers native platform channel implementation,
/// falling back to the standard pedometer plugin if native is unavailable.
class CompositeStepSensorAdapter implements StepSensorAdapter {
  final NativeStepSensorAdapter _nativeAdapter;
  final PedometerStepSensorAdapter _fallbackAdapter;

  StepSensorAdapter? _activeAdapter;
  final _controller = StreamController<StepSensorSample>.broadcast();
  StreamSubscription<StepSensorSample>? _activeSub;

  CompositeStepSensorAdapter({
    NativeStepSensorAdapter? nativeAdapter,
    PedometerStepSensorAdapter? fallbackAdapter,
  })  : _nativeAdapter = nativeAdapter ?? NativeStepSensorAdapter(),
        _fallbackAdapter = fallbackAdapter ?? PedometerStepSensorAdapter();

  @override
  Stream<StepSensorSample> get sampleStream => _controller.stream;

  @override
  bool get requiresSystemPermissions => true;

  StepSensorAdapter get activeAdapter => _activeAdapter ?? _fallbackAdapter;

  @override
  Future<StepSensorStatus> checkStatus() async {
    if (kIsWeb) {
      return _fallbackAdapter.checkStatus();
    }

    try {
      final nativeStatus = await _nativeAdapter.checkStatus();
      if (nativeStatus.isAvailable) {
        return nativeStatus;
      }
    } catch (_) {
      // Fall through to fallback
    }

    return _fallbackAdapter.checkStatus();
  }

  @override
  Future<void> startStream() async {
    await stopStream();

    var useNative = false;
    if (!kIsWeb) {
      try {
        final nativeStatus = await _nativeAdapter.checkStatus();
        if (nativeStatus.isAvailable) {
          useNative = true;
        }
      } catch (_) {
        useNative = false;
      }
    }

    if (useNative) {
      try {
        await _nativeAdapter.startStream();
        _activeAdapter = _nativeAdapter;
      } catch (e) {
        debugPrint(
          '[CompositeStepSensorAdapter] Native start failed ($e), falling back',
        );
        await _fallbackAdapter.startStream();
        _activeAdapter = _fallbackAdapter;
      }
    } else {
      await _fallbackAdapter.startStream();
      _activeAdapter = _fallbackAdapter;
    }

    _activeSub = _activeAdapter!.sampleStream.listen(
      (sample) {
        if (!_controller.isClosed) {
          _controller.add(sample);
        }
      },
      onError: (err) {
        if (!_controller.isClosed) {
          _controller.addError(err);
        }
      },
    );
  }

  @override
  Future<void> stopStream() async {
    await _activeSub?.cancel();
    _activeSub = null;
    await _activeAdapter?.stopStream();
    _activeAdapter = null;
  }

  @override
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  ) async {
    if (_activeAdapter != null) {
      return _activeAdapter!.queryHistoricalSteps(start, end);
    }
    return _nativeAdapter.queryHistoricalSteps(start, end);
  }

  @override
  void dispose() {
    stopStream();
    _nativeAdapter.dispose();
    _fallbackAdapter.dispose();
    _controller.close();
  }
}
