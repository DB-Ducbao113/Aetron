import 'dart:io';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Global Navigator Key for Deep-Link Navigation from Notification Taps.
final GlobalKey<NavigatorState> aetronNavigatorKey =
    GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _channelIdReminders = 'aetron_reminders';
  static const _channelIdAchievements = 'aetron_achievements';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _available = true;

  bool get isAvailable => _available;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      _available = false;
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
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_available) return false;

    final pStatus = await Permission.notification.request();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidAllowed = await android?.requestNotificationsPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosAllowed = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosAllowed = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return pStatus.isGranted ||
        (androidAllowed ?? false) ||
        (iosAllowed ?? false) ||
        (macosAllowed ?? false);
  }

  Future<bool> areNotificationsAllowed() async {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    await initialize();
    if (!_available) return false;

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      if (permissions?.isEnabled == true) return true;
      try {
        final status = await Permission.notification.status;
        return status.isGranted || status.isLimited;
      } catch (_) {
        return false;
      }
    }

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macos != null) {
      final permissions = await macos.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? false;
    }

    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
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
