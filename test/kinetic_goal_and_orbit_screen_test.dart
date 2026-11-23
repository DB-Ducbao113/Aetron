import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_home_top_bar.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_your_week_bento.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViLanguageNotifier extends AppLanguageNotifier {
  _TestViLanguageNotifier() : super() {
    state = AppLanguage.vi;
  }
}

Widget buildTestable(Widget child, {ThemeData? theme, bool isVi = false}) {
  return ProviderScope(
    overrides: [
      if (isVi)
        appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
    ],
    child: MaterialApp(
      theme: theme ?? KineticTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('KineticYourWeekBento Goal Entry Point Tests', () {
    testWidgets('renders weekly goal header, progress, and adjusts on tap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticYourWeekBento(
            weeklyDistanceKm: 25.0,
            workoutCount: 3,
            targetDistanceKm: 50.0,
            dateRangeText: '01 Th10 - 07 Th10',
            isVi: true,
            useMetricUnits: true,
            activeWeekdays: const {1, 3, 5},
            onSetGoalTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Mục tiêu tuần'), findsOneWidget);
      expect(find.text('Điều chỉnh'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));

      await tester.tap(find.text('Điều chỉnh'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders English labels and invokes onSetGoalTap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticYourWeekBento(
            weeklyDistanceKm: 10.0,
            workoutCount: 2,
            targetDistanceKm: 40.0,
            dateRangeText: 'Oct 01 - Oct 07',
            isVi: false,
            useMetricUnits: false,
            onSetGoalTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Weekly goal'), findsOneWidget);
      expect(find.text('Adjust'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Adjust'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('KineticHomeTopBar Streak & Avatar Entry Tests', () {
    testWidgets('renders today heading, streak pill, bell, and avatar tap', (
      tester,
    ) async {
      bool streakTapped = false;
      bool notificationTapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticHomeTopBar(
            avatarImage: null,
            initials: 'DB',
            displayName: 'Duc Bao',
            greeting: 'Hôm nay',
            streakCount: 7,
            isVi: true,
            onAvatarTap: () {},
            onStreakTap: () => streakTapped = true,
            onNotificationTap: () => notificationTapped = true,
          ),
        ),
      );

      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('7 ngày'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsOneWidget);

      await tester.tap(find.text('7 ngày'));
      await tester.pump();
      expect(streakTapped, isTrue);

      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(notificationTapped, isTrue);
    });
  });

  group('AetronGlobeOrbitScreen Visualizer Tests', () {
    testWidgets('fits the complete loading HUD on a compact iPhone viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestable(
          const AetronGlobeOrbitScreen(
            customTitle: 'Aetron',
          ),
          theme: KineticTheme.darkTheme,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Aetron'), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);
    });

    testWidgets(
      'completes once without prolonged motion when animations are disabled',
      (tester) async {
        var completionCount = 0;

        await tester.pumpWidget(
          buildTestable(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: AetronGlobeOrbitScreen(
                duration: const Duration(seconds: 10),
                onComplete: () => completionCount += 1,
              ),
            ),
            theme: KineticTheme.darkTheme,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(completionCount, 1);

        await tester.pump(const Duration(seconds: 1));
        expect(completionCount, 1);
      },
    );

    testWidgets(
      'renders 3D orbit telemetry HUD and brand typography in Vietnamese',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            const AetronGlobeOrbitScreen(
              customTitle: 'Aetron Orbit',
              customSubtitle: 'Mạng lưới định vị vệ tinh GPS',
              showSubtitle: true,
              showTelemetryChips: true,
            ),
            theme: KineticTheme.darkTheme,
            isVi: true,
          ),
        );

        expect(find.text('Aetron Orbit'), findsOneWidget);
        expect(find.text('Mạng lưới định vị vệ tinh GPS'), findsOneWidget);
        expect(find.text('12 VỆ TINH GPS'), findsOneWidget);
        expect(find.text('ĐỘ CAO 20,200 KM'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('supports horizontal drag gesture on 3D globe without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AetronGlobeOrbitScreen(
            customTitle: 'Telemetry Test',
          ),
        ),
      );

      final customPaintFinder = find.byType(CustomPaint).first;
      expect(customPaintFinder, findsOneWidget);

      // Drag horizontally to rotate 3D Earth
      await tester.drag(customPaintFinder, const Offset(-100, 0));
      await tester.pump();
      await tester.drag(customPaintFinder, const Offset(60, 0));
      await tester.pump();

      expect(find.text('Telemetry Test'), findsOneWidget);
    });
  });
}
