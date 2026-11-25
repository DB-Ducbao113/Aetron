import 'package:fitness_exercise_application/core/services/notification_service.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> invokedMethods;
  late String mockAuthStatus;
  late bool mockRequestAuthResult;
  late bool mockPendingOpenSettings;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  setUp(() {
    invokedMethods = <String>[];
    mockAuthStatus = 'authorized';
    mockRequestAuthResult = true;
    mockPendingOpenSettings = false;

    SharedPreferences.setMockInitialValues({
      'settings.language.code': 'vi',
      'settings.notifications.enabled': true,
      'settings.notifications.workout_reminders': true,
      'settings.notifications.morning_time': '08:00',
      'settings.notifications.goal_progress': true,
      'settings.notifications.achievement': true,
      'settings.notifications.streak_reminders': true,
      'settings.notifications.inactivity_reminders': true,
      'settings.notifications.quiet_hours': true,
      'settings.notifications.quiet_hours_start': '22:00',
      'settings.notifications.quiet_hours_end': '07:00',
    });

    NotificationService.instance.debugForceNativeBridgeInTests = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationService.nativeChannel, (
          MethodCall call,
        ) async {
          invokedMethods.add(call.method);
          switch (call.method) {
            case 'getAuthorizationStatus':
              return mockAuthStatus;
            case 'requestAuthorization':
              if (mockRequestAuthResult) {
                mockAuthStatus = 'authorized';
              } else {
                mockAuthStatus = 'denied';
              }
              return mockRequestAuthResult;
            case 'openNotificationSettings':
              return true;
            case 'consumePendingOpenNotificationSettings':
              final pending = mockPendingOpenSettings;
              mockPendingOpenSettings = false;
              return pending;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    NotificationService.instance.debugForceNativeBridgeInTests = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationService.nativeChannel, null);
  });

  group('iOS & OS Notification Settings Deep-Link Integration', () {
    testWidgets(
      'NotificationSettingsScreen handles notDetermined by prompting native authorization before jumping to OS Settings',
      (tester) async {
        mockAuthStatus = 'notDetermined';
        mockRequestAuthResult = true;

        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: const NotificationSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chưa cấp quyền thông báo trên thiết bị'),
          findsOneWidget,
        );
        expect(find.text('Bật'), findsOneWidget);

        await tester.tap(find.text('Bật'));
        await tester.pumpAndSettle();

        expect(invokedMethods, contains('requestAuthorization'));
        expect(invokedMethods, isNot(contains('openNotificationSettings')));
        expect(
          find.text('Chưa cấp quyền thông báo trên thiết bị'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'NotificationSettingsScreen opens OS Notification Settings directly when OS permission is denied or system link card is tapped',
      (tester) async {
        mockAuthStatus = 'denied';

        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: const NotificationSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thông báo bị tắt trong hệ thống'), findsOneWidget);
        await tester.tap(find.text('Mở'));
        await tester.pumpAndSettle();

        expect(
          invokedMethods.where((m) => m == 'openNotificationSettings').length,
          1,
        );

        // Tapping System Notification Settings footer card also opens OS Notification Settings
        await tester.ensureVisible(find.text('Cài đặt thông báo hệ thống'));
        await tester.tap(find.text('Cài đặt thông báo hệ thống'));
        await tester.pumpAndSettle();

        expect(
          invokedMethods.where((m) => m == 'openNotificationSettings').length,
          2,
        );
      },
    );

    testWidgets(
      'SettingsScreen links Notification permission switch to OS Notification Settings and navigates to NotificationSettingsScreen',
      (tester) async {
        mockAuthStatus = 'authorized';

        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigating via 'Lịch nhắc tập luyện' in Section 1 opens NotificationSettingsScreen
        await tester.ensureVisible(find.text('Lịch nhắc tập luyện'));
        await tester.tap(find.text('Lịch nhắc tập luyện'));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationSettingsScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // First CupertinoSwitch in Privacy & Access is Notifications (reflecting OS authorized = true)
        final notifSwitchFinder = find.byType(CupertinoSwitch).first;
        await tester.ensureVisible(notifSwitchFinder);
        await tester.pumpAndSettle();
        expect(tester.widget<CupertinoSwitch>(notifSwitchFinder).value, isTrue);

        // Toggling OFF an OS-granted permission opens iPhone/OS Notification Settings directly
        await tester.tap(notifSwitchFinder);
        await tester.pumpAndSettle();

        expect(invokedMethods, contains('openNotificationSettings'));
      },
    );

    testWidgets(
      'Cold-start or runtime iOS Settings "Configure in App" callback navigates to NotificationSettingsScreen',
      (tester) async {
        mockPendingOpenSettings = true;

        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: aetronNavigatorKey,
              theme: KineticTheme.darkTheme,
              home: const Scaffold(body: Text('Home Root')),
            ),
          ),
        );
        await NotificationService.instance.initialize();
        await tester.pumpAndSettle();

        expect(
          invokedMethods,
          contains('consumePendingOpenNotificationSettings'),
        );
        expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      },
    );
  });
}
