import 'dart:io';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Global Navigator Key for Deep-Link Navigation from Notification Taps.
final GlobalKey<NavigatorState> aetronNavigatorKey =
    GlobalKey<NavigatorState>();

enum NotificationOsPermissionState { notDetermined, granted, denied }

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _channelIdReminders = 'aetron_reminders';
  static const _channelIdAchievements = 'aetron_achievements';
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.aetron.app/notifications',
  );

  @visibleForTesting
  static MethodChannel get nativeChannel => _nativeChannel;

  bool _forceNativeBridgeInTests = false;

  @visibleForTesting
  set debugForceNativeBridgeInTests(bool value) {
    _forceNativeBridgeInTests = value;
  }

  bool get shouldBypassOsBridgeInTest =>
      Platform.environment.containsKey('FLUTTER_TEST') &&
      !_forceNativeBridgeInTests;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _available = true;
  bool _nativeHandlerRegistered = false;

  bool get isAvailable => _available;

  void _ensureNativeHandlerRegistered() {
    if (_nativeHandlerRegistered || kIsWeb) return;
    try {
      _nativeChannel.setMethodCallHandler(_handleNativeMethodCall);
      _nativeHandlerRegistered = true;
    } catch (_) {}
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'openInAppNotificationSettings') {
      _openInAppNotificationSettings();
    }
  }

  void _openInAppNotificationSettings() {
    final navigator = aetronNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    _ensureNativeHandlerRegistered();
    if (_initialized && !_forceNativeBridgeInTests) return;
    if (shouldBypassOsBridgeInTest) {
      _initialized = true;
      _available = false;
      return;
    }
    if (_forceNativeBridgeInTests) {
      _initialized = true;
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _available = false;
      }
      try {
        final pending = await _nativeChannel.invokeMethod<bool>(
          'consumePendingOpenNotificationSettings',
        );
        if (pending == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openInAppNotificationSettings();
          });
        }
      } catch (_) {}
      return;
    }

    tz.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (error) {
      debugPrint('[NotificationService] Timezone unavailable: $error');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: ios,
          macOS: ios,
        ),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
      if (Platform.isIOS) {
        try {
          final pending = await _nativeChannel.invokeMethod<bool>(
            'consumePendingOpenNotificationSettings',
          );
          if (pending == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _openInAppNotificationSettings();
            });
          }
        } catch (_) {}
      }
    } catch (error) {
      debugPrint('[NotificationService] Initialization error: $error');
      _available = false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    debugPrint(
      '[NotificationService] Notification tapped with payload: $payload',
    );
    final navigator = aetronNavigatorKey.currentState;
    if (navigator == null) return;

    switch (payload) {
      case 'open_activity':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const MainShell(initialIndex: activityTabIndex),
          ),
        );
        break;
      case 'open_goal':
        navigator.push(MaterialPageRoute(builder: (_) => const GoalScreen()));
        break;
      case 'open_analytics':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const MainShell(initialIndex: analyticsTabIndex),
          ),
        );
        break;
      case 'open_notification_settings':
        _openInAppNotificationSettings();
        break;
    }
  }

  Future<NotificationOsPermissionState> getOsPermissionState() async {
    if (kIsWeb) return NotificationOsPermissionState.denied;
    if (shouldBypassOsBridgeInTest) {
      return NotificationOsPermissionState.granted;
    }
    if (!_forceNativeBridgeInTests) {
      await initialize();
    } else {
      _ensureNativeHandlerRegistered();
    }

    if (Platform.isIOS || _forceNativeBridgeInTests) {
      try {
        final raw = await _nativeChannel.invokeMethod<String>(
          'getAuthorizationStatus',
        );
        switch (raw) {
          case 'authorized':
          case 'provisional':
          case 'ephemeral':
            return NotificationOsPermissionState.granted;
          case 'notDetermined':
            return NotificationOsPermissionState.notDetermined;
          case 'denied':
            return NotificationOsPermissionState.denied;
        }
      } catch (_) {
        if (_forceNativeBridgeInTests) {
          return NotificationOsPermissionState.denied;
        }
      }
    }

    if (!_available) return NotificationOsPermissionState.denied;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      if (permissions?.isEnabled == true) {
        return NotificationOsPermissionState.granted;
      }
      try {
        final status = await Permission.notification.status;
        if (status.isGranted || status.isLimited || status.isProvisional) {
          return NotificationOsPermissionState.granted;
        }
        if (status.isPermanentlyDenied) {
          return NotificationOsPermissionState.denied;
        }
        return NotificationOsPermissionState.notDetermined;
      } catch (_) {
        return NotificationOsPermissionState.denied;
      }
    }

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macos != null) {
      final permissions = await macos.checkPermissions();
      return (permissions?.isEnabled ?? false)
          ? NotificationOsPermissionState.granted
          : NotificationOsPermissionState.denied;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) return NotificationOsPermissionState.granted;
      try {
        final status = await Permission.notification.status;
        return status.isPermanentlyDenied
            ? NotificationOsPermissionState.denied
            : NotificationOsPermissionState.notDetermined;
      } catch (_) {
        return NotificationOsPermissionState.denied;
      }
    }

    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited || status.isProvisional) {
        return NotificationOsPermissionState.granted;
      }
      return NotificationOsPermissionState.denied;
    } catch (_) {
      return NotificationOsPermissionState.denied;
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (shouldBypassOsBridgeInTest) {
      return false;
    }
    if (!_forceNativeBridgeInTests) {
      await initialize();
    } else {
      _ensureNativeHandlerRegistered();
    }

    if (Platform.isIOS || _forceNativeBridgeInTests) {
      try {
        final granted = await _nativeChannel.invokeMethod<bool>(
          'requestAuthorization',
        );
        if (granted != null) return granted;
      } catch (_) {
        if (_forceNativeBridgeInTests) return false;
      }
    }

    if (!_available) return false;

    if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosAllowed = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosAllowed != null) return iosAllowed;
    }

    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidAllowed = await android?.requestNotificationsPermission();
      if (androidAllowed == true) return true;
    }

    final pStatus = await Permission.notification.request();
    if (pStatus.isGranted || pStatus.isLimited || pStatus.isProvisional) {
      return true;
    }

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosAllowed = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return macosAllowed ?? false;
  }

  Future<bool> areNotificationsAllowed() async {
    final state = await getOsPermissionState();
    return state == NotificationOsPermissionState.granted;
  }

  /// Opens the app's dedicated OS Notification Settings screen directly
  /// (`UIApplication.openNotificationSettingsURLString` on iOS 16+,
  /// `ACTION_APP_NOTIFICATION_SETTINGS` on Android 8+), requesting initial
  /// notification registration first on iOS if `.notDetermined` so iPhone
  /// Settings displays the Notifications entry for Aetron.
  Future<bool> openNotificationSettings() async {
    if (kIsWeb) return false;
    if (shouldBypassOsBridgeInTest) {
      return false;
    }
    _ensureNativeHandlerRegistered();
    try {
      final opened = await _nativeChannel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      if (opened == true) return true;
    } catch (_) {
      if (_forceNativeBridgeInTests) return false;
    }
    return openAppSettings();
  }

  Future<void> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    bool isAchievement = false,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;

    final channelId = isAchievement
        ? _channelIdAchievements
        : _channelIdReminders;
    final channelName = isAchievement
        ? 'Achievements & Goals'
        : 'Workout Reminders';

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      debugPrint(
        '[NotificationService] Scheduled notif #$id for $scheduledDate',
      );
    } catch (e) {
      debugPrint('[NotificationService] Schedule error for #$id: $e');
    }
  }

  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdAchievements,
          'Achievements & Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    try {
      await _notifications.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await initialize();
    if (!_available) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }
}
