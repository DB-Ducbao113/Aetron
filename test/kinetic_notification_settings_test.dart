import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  group('NotificationSettingsScreen Streamlined Widget Tests', () {
    setUp(() {
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
    });

    testWidgets('renders streamlined 3 consolidated groups in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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

      // Header uses KineticSettingsTopBar without version pill
      expect(find.byType(KineticSettingsTopBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Nhắc nhở luyện tập'), findsOneWidget);
      expect(find.text('THÔNG BÁO'), findsNothing);
      expect(find.text('NHẮC NHỞ LUYỆN TẬP'), findsNothing);
      expect(find.text('v1.0.0'), findsNothing);

      // Glassline V3 Liquid Glass surface cards
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(KineticColors.dark.background));
      final sectionCards = tester
          .widgetList<KineticCard>(
            find.descendant(
              of: find.byType(KineticSettingsSectionGroup),
              matching: find.byType(KineticCard),
            ),
          )
          .where((c) => c.useLiquidGlass)
          .toList();
      expect(sectionCards.length, greaterThanOrEqualTo(2));

      // Master switch card
      expect(find.text('Nhận thông báo'), findsOneWidget);

      // Section structure using KineticSettingsSectionGroup + KineticSettingsTile
      expect(find.byType(KineticSettingsSectionGroup), findsNWidgets(2));
      expect(find.byType(KineticSettingsTile), findsNWidgets(4));
      expect(find.text('Tùy chọn nhắc nhở'), findsOneWidget);
      expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);

      // Consolidated groups & tiles
      expect(find.text('Luyện tập & Chuỗi ngày'), findsOneWidget);
      expect(find.text('Mục tiêu & Thành tích'), findsOneWidget);
      expect(find.text('Chế độ yên tĩnh'), findsOneWidget);

      // Time configurations
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsOneWidget);
      expect(find.text('Thời gian nghỉ ngơi'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);

      // Verify the removed noisy items are NOT present
      expect(find.text('XEM TRƯỚC THÔNG BÁO'), findsNothing);
      expect(find.text('Ready to move? 🏃'), findsNothing);
      expect(find.text('DANH MỤC NHẮC NHỞ'), findsNothing);
      expect(find.text('Cảnh báo bảo vệ chuỗi (Streak)'), findsNothing);
      expect(find.text('Nhắc nhở khi ngưng luyện tập'), findsNothing);

      // iOS-style CupertinoSwitch verification (Dark mode)
      expect(find.byType(Switch), findsNothing);
      final switches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(switches.length, equals(4));
      for (final s in switches) {
        expect(s.activeTrackColor, equals(const Color(0xFF34C759)));
        expect(s.inactiveTrackColor, equals(KineticColors.dark.surface3));
      }
    });

    testWidgets('renders cleanly in light mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Nhắc nhở luyện tập'), findsOneWidget);
      expect(find.text('v1.0.0'), findsNothing);
      expect(find.text('Nhận thông báo'), findsOneWidget);
      expect(find.text('Tùy chọn nhắc nhở'), findsOneWidget);
      expect(find.text('Luyện tập & Chuỗi ngày'), findsOneWidget);
      expect(find.text('Mục tiêu & Thành tích'), findsOneWidget);
      expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);
      expect(find.text('Chế độ yên tĩnh'), findsOneWidget);

      // Glassline V3 Liquid Glass surface cards
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(KineticColors.light.background));
      final sectionCards = tester
          .widgetList<KineticCard>(
            find.descendant(
              of: find.byType(KineticSettingsSectionGroup),
              matching: find.byType(KineticCard),
            ),
          )
          .where((c) => c.useLiquidGlass)
          .toList();
      expect(sectionCards.length, greaterThanOrEqualTo(2));

      expect(find.byType(Switch), findsNothing);
      final switches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(switches.length, equals(4));
      for (final s in switches) {
        expect(s.activeTrackColor, equals(const Color(0xFF34C759)));
        expect(s.inactiveTrackColor, equals(KineticColors.light.surface3));
      }
    });

    testWidgets('master toggle disables all notification options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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

      final initialSwitches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(initialSwitches.length, equals(4));
      for (final s in initialSwitches) {
        expect(s.value, isTrue);
        expect(s.onChanged, isNotNull);
      }
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsOneWidget);
      expect(find.text('Thời gian nghỉ ngơi'), findsOneWidget);

      final masterSwitch = find.byType(CupertinoSwitch).first;
      await tester.tap(masterSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SharedPreferences should reflect disabled
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.notifications.enabled'), false);

      // Master switch turns OFF (still interactive); all 3 sub-switches become OFF and disabled
      final disabledSwitches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(disabledSwitches.length, equals(4));
      expect(disabledSwitches[0].value, isFalse);
      expect(disabledSwitches[0].onChanged, isNotNull);
      for (final subSwitch in disabledSwitches.skip(1)) {
        expect(subSwitch.value, isFalse);
        expect(subSwitch.onChanged, isNull);
      }
      // Time pickers hide when master is OFF
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsNothing);
      expect(find.text('Thời gian nghỉ ngơi'), findsNothing);

      // Tapping a disabled sub-tile does not mutate its preference
      await tester.tap(find.text('Luyện tập & Chuỗi ngày'), warnIfMissed: false);
      await tester.pump();
      expect(prefs.getBool('settings.notifications.workout_reminders'), isTrue);

      // Toggling master switch back ON re-enables sub-switches & restores time rows
      await tester.tap(masterSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(prefs.getBool('settings.notifications.enabled'), true);
      final reenabledSwitches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      for (final s in reenabledSwitches) {
        expect(s.value, isTrue);
        expect(s.onChanged, isNotNull);
      }
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsOneWidget);
      expect(find.text('Thời gian nghỉ ngơi'), findsOneWidget);
    });

    testWidgets('back button navigates back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsScreen), findsNothing);
    });
  });

  group('KineticSettingsTopBar Compatibility & Layout Tests', () {
    testWidgets('default KineticSettingsTopBar preserves SettingsScreen title and version pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.lightTheme,
          home: const Scaffold(
            body: KineticSettingsTopBar(currentLang: AppLanguage.vi),
          ),
        ),
      );
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticSettingsTopBar(currentLang: AppLanguage.en),
          ),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    });

    testWidgets('custom title, subtitle, and showVersionPill: false fit cleanly at 360px', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.lightTheme,
          home: const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: KineticSettingsTopBar(
                  currentLang: AppLanguage.en,
                  title: 'Notifications',
                  subtitle: 'Smart Reminders',
                  showVersionPill: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Smart Reminders'), findsOneWidget);
      expect(find.text('v1.0.0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('NotificationSettingsScreen Viewport, Time Picker & OS Banner Tests', () {
    Future<void> pumpViewport(
      WidgetTester tester, {
      required Size logicalSize,
      required ThemeData theme,
      required String lang,
      double textScale = 1.0,
      bool? osPermissionOverride,
    }) async {
      SharedPreferences.setMockInitialValues({
        'settings.language.code': lang,
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

      tester.view.physicalSize = logicalSize * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: NotificationSettingsScreen(
              osPermissionOverride: osPermissionOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders without overflow at 360x640 and 390x844 across Light/Dark and vi/en (including 1.3x textScaler)', (tester) async {
      final matrix = [
        (size: const Size(360, 640), theme: KineticTheme.lightTheme, lang: 'vi', scale: 1.0),
        (size: const Size(360, 640), theme: KineticTheme.darkTheme, lang: 'en', scale: 1.0),
        (size: const Size(360, 640), theme: KineticTheme.lightTheme, lang: 'vi', scale: 1.3),
        (size: const Size(360, 640), theme: KineticTheme.darkTheme, lang: 'en', scale: 1.3),
        (size: const Size(390, 844), theme: KineticTheme.lightTheme, lang: 'en', scale: 1.0),
        (size: const Size(390, 844), theme: KineticTheme.darkTheme, lang: 'vi', scale: 1.0),
      ];

      for (final item in matrix) {
        await pumpViewport(
          tester,
          logicalSize: item.size,
          theme: item.theme,
          lang: item.lang,
          textScale: item.scale,
        );
        expect(tester.takeException(), isNull);

        if (item.lang == 'en') {
          expect(find.text('Notifications'), findsOneWidget);
          expect(find.text('Smart Reminders'), findsNWidgets(2));
          expect(find.text('Push Notifications'), findsOneWidget);
          expect(find.text('Workouts & Streak'), findsOneWidget);
          expect(find.text('Daily Reminder Time'), findsOneWidget);
          expect(find.text('Goals & Achievements'), findsOneWidget);
          expect(find.text('Quiet hours'), findsOneWidget);
          expect(find.text('Quiet Mode'), findsOneWidget);
          expect(find.text('Quiet Window'), findsOneWidget);
        } else {
          expect(find.text('Thông báo'), findsOneWidget);
          expect(find.text('Nhắc nhở luyện tập'), findsOneWidget);
          expect(find.text('Nhận thông báo'), findsOneWidget);
          expect(find.text('Tùy chọn nhắc nhở'), findsOneWidget);
          expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);
          expect(find.text('Chế độ yên tĩnh'), findsOneWidget);
        }
      }
    });

    testWidgets('updates morning reminder and quiet window times via KineticTimeInputSheet and hides rows when sub-switches turn OFF', (tester) async {
      await pumpViewport(
        tester,
        logicalSize: const Size(390, 844),
        theme: KineticTheme.lightTheme,
        lang: 'vi',
      );

      // Update morning time: 08:00 -> 18:00
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('18:00'));
      await tester.tap(find.text('18:00'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('18:00'), findsOneWidget);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.notifications.morning_time'), '18:00');

      // Update quiet start: 22:00 -> 20:00
      await tester.ensureVisible(find.text('22:00'));
      await tester.tap(find.text('22:00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('20:00'));
      await tester.tap(find.text('20:00'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('20:00'), findsOneWidget);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.notifications.quiet_hours_start'), '20:00');

      // Update quiet end: 07:00 -> 06:00
      await tester.ensureVisible(find.text('07:00'));
      await tester.tap(find.text('07:00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('06:00'));
      await tester.tap(find.text('06:00'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('06:00'), findsOneWidget);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.notifications.quiet_hours_end'), '06:00');

      // Sub-switches hide/show their corresponding time rows
      final switches = find.byType(CupertinoSwitch);
      // Switch 1 is Workouts & Streak
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsNothing);

      // Switch 3 (still index 3 since Quiet Mode has its own switch) is Quiet Mode
      await tester.ensureVisible(switches.at(3));
      await tester.tap(switches.at(3));
      await tester.pumpAndSettle();
      expect(find.text('Thời gian nghỉ ngơi'), findsNothing);

      // Re-enable Workouts & Streak -> Morning row returns
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Giờ nhắc tập mỗi ngày'), findsOneWidget);
    });

    testWidgets('displays OS permission banner only when osPermissionOverride is false without 360px overflow', (tester) async {
      // Hidden by default (null -> FLUTTER_TEST returns true)
      await pumpViewport(
        tester,
        logicalSize: const Size(360, 640),
        theme: KineticTheme.lightTheme,
        lang: 'vi',
        osPermissionOverride: null,
      );
      expect(find.text('Thông báo bị tắt trong hệ thống'), findsNothing);

      // Shown in Vietnamese at 360x640 with 1.3x textScaler
      await pumpViewport(
        tester,
        logicalSize: const Size(360, 640),
        theme: KineticTheme.lightTheme,
        lang: 'vi',
        textScale: 1.3,
        osPermissionOverride: false,
      );
      expect(find.text('Thông báo bị tắt trong hệ thống'), findsOneWidget);
      expect(find.text('Mở'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Shown in English at 360x640 Dark mode
      await pumpViewport(
        tester,
        logicalSize: const Size(360, 640),
        theme: KineticTheme.darkTheme,
        lang: 'en',
        textScale: 1.3,
        osPermissionOverride: false,
      );
      expect(find.text('Notifications disabled in OS Settings'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
