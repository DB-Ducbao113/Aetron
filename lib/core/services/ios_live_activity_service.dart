import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iosLiveActivityServiceProvider = Provider(
  (ref) => const IosLiveActivityService(),
);

class IosLiveActivityService {
  const IosLiveActivityService();

  static const MethodChannel _channel = MethodChannel('aetron/live_activity');

  Future<void> syncWorkout({
    required String activityType,
    required String trackingMode,
    required String status,
    required int durationSeconds,
    required double distanceMeters,
    required double avgSpeedKmh,
    required int caloriesBurned,
    bool useMetricUnits = true,
    String languageCode = 'vi',
  }) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod('syncWorkout', {
        'activityType': activityType,
        'trackingMode': trackingMode,
        'status': status,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'avgSpeedKmh': avgSpeedKmh,
        'caloriesBurned': caloriesBurned,
        'useMetricUnits': useMetricUnits,
        'languageCode': languageCode,
      });
    } catch (error) {
      debugPrint('[LiveActivity] sync failed: $error');
    }
  }

  Future<void> endWorkout({
    required String activityType,
    required String trackingMode,
    required int durationSeconds,
    required double distanceMeters,
    required double avgSpeedKmh,
    required int caloriesBurned,
    bool useMetricUnits = true,
    String languageCode = 'vi',
  }) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod('endWorkout', {
        'activityType': activityType,
        'trackingMode': trackingMode,
        'status': 'ended',
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'avgSpeedKmh': avgSpeedKmh,
        'caloriesBurned': caloriesBurned,
        'useMetricUnits': useMetricUnits,
        'languageCode': languageCode,
      });
    } catch (error) {
      debugPrint('[LiveActivity] end failed: $error');
    }
  }

  bool get _isSupportedPlatform => !kIsWeb && Platform.isIOS;
}
