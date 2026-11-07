import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'step_sensor_adapter.dart';
import 'step_sensor_types.dart';

/// Fallback adapter using the standard pub `pedometer` plugin.
class PedometerStepSensorAdapter implements StepSensorAdapter {
  final _controller = StreamController<StepSensorSample>.broadcast();
  StreamSubscription<StepCount>? _sub;
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
        message: 'Step sensor not supported on Web',
      );
    }

    try {
      final permission = (!kIsWeb && Platform.isIOS)
          ? Permission.sensors
          : Permission.activityRecognition;

      var status = await permission.status;
      final hasPerm = status.isGranted || status.isLimited;

      return StepSensorStatus(
        isAvailable: true,
        hasPermission: hasPerm,
        isCadenceAvailable: false,
        isHistoricalQueryAvailable: false,
      );
    } catch (e) {
      return StepSensorStatus(
        isAvailable: false,
        hasPermission: false,
        message: 'Permission check error: $e',
      );
    }
  }

  @override
  Future<void> startStream() async {
    if (_isStreaming) return;
    if (kIsWeb) return;

    final permission = (!kIsWeb && Platform.isIOS)
        ? Permission.sensors
        : Permission.activityRecognition;

    var status = await permission.status;
    if (status.isDenied) {
      status = await permission.request();
    }

    if (!status.isGranted && !status.isLimited) {
      if (status.isPermanentlyDenied || status.isRestricted) {
        throw Exception('activity_permission_denied_forever');
      }
      throw Exception('activity_permission_denied');
    }

    await _sub?.cancel();
    _isStreaming = true;

    try {
      _sub = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (!_controller.isClosed) {
            _controller.add(
              StepSensorSample(
                rawSteps: event.steps,
                timestamp: event.timeStamp,
                source: StepSensorSource.pedometerPlugin,
              ),
            );
          }
        },
        onError: (err) {
          debugPrint('[PedometerStepSensorAdapter] Stream error: $err');
          if (!_controller.isClosed) {
            _controller.addError(err);
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isStreaming = false;
      debugPrint('[PedometerStepSensorAdapter] Failed to listen: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopStream() async {
    _isStreaming = false;
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<HistoricalStepInterval?> queryHistoricalSteps(
    DateTime start,
    DateTime end,
  ) async {
    // Pedometer plugin does not support CMPedometer.queryPedometerData
    return null;
  }

  @override
  void dispose() {
    stopStream();
    _controller.close();
  }
}
