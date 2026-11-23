import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'step_sensor_adapter.dart';
import 'step_sensor_types.dart';

/// Native platform channel adapter for direct Android TYPE_STEP_COUNTER and iOS CMPedometer.
class NativeStepSensorAdapter implements StepSensorAdapter {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.aetron.app/step_sensor',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.aetron.app/step_sensor_events',
  );

  final _controller = StreamController<StepSensorSample>.broadcast();
  StreamSubscription<dynamic>? _eventSub;
  bool _isStreaming = false;

  @override
  Stream<StepSensorSample> get sampleStream => _controller.stream;

  @override
  bool get requiresSystemPermissions => true;

  @override
  Future<StepSensorStatus> checkStatus() async {
    if (kIsWeb) {
      return const StepSensorStatus(
        isAvailable: false,
        hasPermission: false,
        message: 'Native step sensor is not supported on Web',
      );
    }

    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>(
        'checkStatus',
      );
      if (res == null) {
        return const StepSensorStatus(
          isAvailable: false,
          hasPermission: false,
          message: 'No response from native step sensor platform channel',
        );
      }

      return StepSensorStatus(
        isAvailable: res['isAvailable'] == true,
        hasPermission: res['hasPermission'] == true,
        isCadenceAvailable: res['isCadenceAvailable'] == true,
        isHistoricalQueryAvailable: res['isHistoricalQueryAvailable'] == true,
        message: res['message'] as String?,
      );
    } on MissingPluginException {
      return const StepSensorStatus(
        isAvailable: false,
        hasPermission: false,
        message: 'Native step sensor plugin channel not registered',
      );
    } catch (e) {
      return StepSensorStatus(
        isAvailable: false,
        hasPermission: false,
        message: 'Native status check error: $e',
      );
    }
  }

  @override
  Future<void> startStream() async {
    if (_isStreaming) return;
    if (kIsWeb) return;

    final status = await checkStatus();
    if (!status.isAvailable) {
      throw Exception('sensor_unavailable: ${status.message}');
    }
    if (!status.hasPermission) {
      // Request permission natively
      final granted = await _methodChannel.invokeMethod<bool>('requestPermission');
      if (granted != true) {
        throw Exception('activity_permission_denied');
      }
    }

    await _eventSub?.cancel();
    _isStreaming = true;

    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (err) {
          debugPrint('[NativeStepSensorAdapter] Stream error: $err');
          if (!_controller.isClosed) {
            _controller.addError(err);
          }
        },
        cancelOnError: false,
      );
      await _methodChannel.invokeMethod('startTracking');
    } catch (e) {
      _isStreaming = false;
      debugPrint('[NativeStepSensorAdapter] Start failed: $e');
      rethrow;
    }
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;

    final rawSteps = (event['rawSteps'] as num?)?.toInt() ?? 0;
    final timestampMs = (event['timestampMs'] as num?)?.toInt();
    final timestamp = timestampMs != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true)
        : DateTime.now().toUtc();
    final receivedTimestamp = DateTime.now().toUtc();

    final nativeCadence = (event['nativeCadenceSps'] as num?)?.toDouble();

    final sourceStr = event['source'] as String? ?? '';
    StepSensorSource source = StepSensorSource.unknown;
    if (sourceStr == 'androidStepCounter' || (!kIsWeb && Platform.isAndroid)) {
      source = StepSensorSource.androidStepCounter;
    } else if (sourceStr == 'iosCoreMotion' || (!kIsWeb && Platform.isIOS)) {
      source = StepSensorSource.iosCoreMotion;
    }

    if (!_controller.isClosed) {
      _controller.add(
        StepSensorSample(
          rawSteps: rawSteps,
          timestamp: timestamp,
          receivedTimestamp: receivedTimestamp,
          nativeCadenceStepsPerSec: nativeCadence,
          source: source,
        ),
      );
    }
  }

  @override
  Future<void> stopStream() async {
    _isStreaming = false;
    try {
      await _methodChannel.invokeMethod('stopTracking');
    } catch (_) {}
    await _eventSub?.cancel();
    _eventSub = null;
  }

  @override
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  ) async {
    if (kIsWeb) return null;

    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>(
        'queryHistoricalSteps',
        {
          'startMs': start.toUtc().millisecondsSinceEpoch,
          'endMs': end.toUtc().millisecondsSinceEpoch,
        },
      );

      if (res == null) return null;
      final steps = (res['steps'] as num?)?.toInt() ?? 0;
      final startResMs = (res['startMs'] as num?)?.toInt() ?? start.millisecondsSinceEpoch;
      final endResMs = (res['endMs'] as num?)?.toInt() ?? end.millisecondsSinceEpoch;

      return HistoricalStepInterval(
        start: DateTime.fromMillisecondsSinceEpoch(startResMs, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(endResMs, isUtc: true),
        steps: steps,
      );
    } catch (e) {
      debugPrint('[NativeStepSensorAdapter] Query historical error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    stopStream();
    _controller.close();
  }
}
