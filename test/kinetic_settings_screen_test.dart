import 'dart:io';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_section.dart';
import 'package:fitness_exercise_application/features/settings/presentation/widgets/kinetic_settings_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadBeVietnamProFonts() async {
  const weights = [
    'fonts/BeVietnamPro-Regular.ttf',
    'fonts/BeVietnamPro-Medium.ttf',
    'fonts/BeVietnamPro-SemiBold.ttf',
    'fonts/BeVietnamPro-Bold.ttf',
    'fonts/BeVietnamPro-ExtraBold.ttf',
  ];
  final loader = FontLoader('BeVietnamPro');
  var loadedAny = false;
  for (final path in weights) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      loadedAny = true;
    }
  }
  if (loadedAny) {
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await _loadBeVietnamProFonts();
  });

  group('Kinetic Settings Widgets Tests', () {
    testWidgets('KineticSettingsTopBar displays system tag and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticSettingsTopBar(
              currentLang: AppLanguage.vi,
            ),
          ),
        ),
      );

      expect(find.text('AETRON SYSTEM'), findsNothing);
      expect(find.text('Cài đặt'), findsOneWidget);
    });

    testWidgets('KineticSettingsSectionGroup renders title and tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticSettingsSectionGroup(
              title: 'CẤU HÌNH ỨNG DỤNG',
              children: [
                KineticSettingsTile(
                  icon: Icons.language_rounded,
                  title: 'Ngôn ngữ ứng dụng',
                  subtitle: '🇻🇳 Tiếng Việt',
                  onTap: () {},
                ),
                KineticSettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Giao diện',
                  subtitle: 'Tối • Kinetic Telemetry',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CẤU HÌNH ỨNG DỤNG'), findsOneWidget);
      expect(find.text('Ngôn ngữ ứng dụng'), findsOneWidget);
      expect(find.text('Giao diện'), findsOneWidget);
    });

    testWidgets('KineticSettingsTile triggers onTap when clicked', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticSettingsTile(
              icon: Icons.straighten_rounded,
              title: 'Đơn vị đo',
              subtitle: 'Hệ mét (km, m, km/h)',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Đơn vị đo'));
      expect(tapped, isTrue);
    });

    testWidgets('SettingsScreen permissions switches are OFF when permissions are not granted', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const ProviderScope(
            child: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      final switches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(switches.length, equals(4));
      for (final s in switches) {
        expect(s.value, isFalse, reason: 'Permission switch must be OFF when not granted');
        expect(s.activeTrackColor, equals(const Color(0xFF34C759)));
        expect(s.inactiveTrackColor, equals(KineticColors.dark.surface3));
      }
    });

    testWidgets('SettingsScreen permission CupertinoSwitches use Option A light inactiveTrackColor in light mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.lightTheme,
          home: const ProviderScope(
            child: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      final switches = tester.widgetList<CupertinoSwitch>(find.byType(CupertinoSwitch)).toList();
      expect(switches.length, equals(4));
      for (final s in switches) {
        expect(s.activeTrackColor, equals(const Color(0xFF34C759)));
        expect(s.inactiveTrackColor, equals(KineticColors.light.surface3));
      }
    });

    testWidgets('SettingsScreen permission switch taps open management dialog cleanly without plugin crashes', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.lightTheme,
          home: const ProviderScope(
            child: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        final sw = find.byType(CupertinoSwitch).at(i);
        await tester.ensureVisible(sw);
        await tester.pumpAndSettle();
        await tester.tap(sw);
        await tester.pumpAndSettle();
        expect(find.byType(KineticGlassDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'SettingsScreen theme selector sheet opens without overflow at 360x640 (1.0x and 1.3x) and toggles Light/Dark/System',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final scale in [1.0, 1.3]) {
          SharedPreferences.setMockInitialValues({
            kAppLanguagePrefKey: 'vi',
            kThemeModePrefKey: 'light',
          });

          late WidgetRef capturedRef;
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              child: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  final mode = ref.watch(themeModeProvider);
                  return MediaQuery(
                    data: MediaQueryData(
                      size: const Size(360, 640),
                      devicePixelRatio: 2.0,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: MaterialApp(
                      theme: KineticTheme.lightTheme,
                      darkTheme: KineticTheme.darkTheme,
                      themeMode: mode,
                      home: const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(capturedRef.read(themeModeProvider), ThemeMode.light);

          // Light -> Dark
          await tester.ensureVisible(find.text('Giao diện'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Giao diện'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Chọn giao diện hiển thị'), findsOneWidget);

          await tester.tap(find.text('Tối (Nền tối)'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(capturedRef.read(themeModeProvider), ThemeMode.dark);

          // Dark -> System
          await tester.ensureVisible(find.text('Giao diện'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Giao diện'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Tự động theo hệ thống'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(capturedRef.read(themeModeProvider), ThemeMode.system);

          // System -> Light
          await tester.ensureVisible(find.text('Giao diện'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Giao diện'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Sáng (Trắng xanh)'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(capturedRef.read(themeModeProvider), ThemeMode.light);
        }
      },
    );
  });
}


