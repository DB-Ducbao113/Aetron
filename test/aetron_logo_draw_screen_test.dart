import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/startup_globe_gate.dart';
import 'package:fitness_exercise_application/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_share_card.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_draw_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AetronLogoPaths & AetronLogoDrawScreen Tests', () {
    test('builds exact AETRON 02B mark wings and 6 wordmark glyphs', () {
      const markSize = Size(200, 142);
      final primary = AetronLogoPaths.buildPrimaryWingPath(markSize);
      final secondary = AetronLogoPaths.buildSecondaryWingPath(markSize);
      final combined = AetronLogoPaths.buildMarkPath(markSize);

      expect(primary.computeMetrics().toList(), isNotEmpty);
      expect(secondary.computeMetrics().toList(), isNotEmpty);
      expect(combined.computeMetrics().length, 2);

      final glyphs = AetronLogoPaths.buildWordmarkGlyphPaths(
        const Size(200, 35),
      );
      expect(glyphs.length, 6);
      for (final g in glyphs) {
        expect(g.computeMetrics().toList(), isNotEmpty);
      }
    });

    testWidgets(
      'renders AetronLogoDrawScreen on compact viewport and calls onComplete',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: AetronLogoDrawScreen(
              duration: const Duration(milliseconds: 500),
              onComplete: () => completed = true,
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('aetron-logo-draw-mark')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('aetron-logo-draw-wordmark')),
          findsOneWidget,
        );
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, Colors.white);
        expect(completed, isFalse);

        await tester.pump(const Duration(milliseconds: 300));
        expect(completed, isFalse);

        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 300));
        expect(completed, isTrue);
      },
    );

    testWidgets('completes quickly when disableAnimations is true', (
      tester,
    ) async {
      var completionCount = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: AetronLogoDrawScreen(
              duration: const Duration(seconds: 5),
              onComplete: () => completionCount += 1,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(completionCount, 1);
    });

    testWidgets('transitions from AetronLogoDrawScreen to AetronGlobeOrbitScreen', (
      tester,
    ) async {
      final logoGate = StartupGlobeGate();
      final globeGate = StartupGlobeGate();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: logoGate.shouldShow
                      ? AetronLogoDrawScreen(
                          key: const ValueKey('startup-logo-draw'),
                          duration: const Duration(milliseconds: 400),
                          onComplete: () => setState(logoGate.complete),
                        )
                      : globeGate.shouldShow
                      ? AetronGlobeOrbitScreen(
                          key: const ValueKey('startup-globe-orbit'),
                          duration: const Duration(milliseconds: 400),
                          customTitle: 'Aetron',
                          forceDarkPalette: true,
                          onComplete: () => setState(globeGate.complete),
                        )
                      : const SizedBox.shrink(key: ValueKey('startup-done')),
                );
              },
            ),
          ),
        ),
      );

      // Step 1: Logo draw screen appears first
      expect(find.byType(AetronLogoDrawScreen), findsOneWidget);
      expect(find.byType(AetronGlobeOrbitScreen), findsNothing);

      // Finish logo draw + 280ms hold + switcher transition
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 250));

      // Step 2: Globe screen appears right after logo draw
      expect(find.byType(AetronGlobeOrbitScreen), findsOneWidget);
      expect(logoGate.shouldShow, isFalse);
      expect(globeGate.shouldShow, isTrue);

      // Finish globe + 180ms hold + switcher transition
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 250));

      expect(globeGate.shouldShow, isFalse);
      expect(find.byKey(const ValueKey('startup-done')), findsOneWidget);
    });

    testWidgets('AetronBrandMark adapts transparently to light and dark themes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.lightTheme,
          home: const Scaffold(body: AetronBrandMark(size: 44)),
        ),
      );
      expect(find.byType(AetronBrandMark), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: AetronBrandMark(size: 44)),
        ),
      );
      expect(find.byType(AetronBrandMark), findsOneWidget);
    });

    testWidgets(
      'AetronWordmark and AetronBrandLockup match startup light/dark palette',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const Scaffold(
              body: AetronBrandLockup(markSize: 28, wordmarkHeight: 18),
            ),
          ),
        );

        expect(find.byType(AetronBrandLockup), findsOneWidget);
        expect(find.byType(AetronBrandMark), findsOneWidget);
        expect(find.byType(AetronWordmark), findsOneWidget);

        final lightMarkPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AetronBrandMark),
            matching: find.byType(CustomPaint),
          ),
        );
        final lightWordmarkPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AetronWordmark),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          (lightMarkPaint.painter! as AetronBrandMarkPainter).color,
          AetronLogoPaths.lightAccentColor,
        );
        expect(
          (lightWordmarkPaint.painter! as AetronWordmarkPainter).accentColor,
          AetronLogoPaths.lightAccentColor,
        );
        expect(
          (lightWordmarkPaint.painter! as AetronWordmarkPainter).color,
          AetronLogoPaths.lightWordmarkColor,
        );

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('dark-brand-lockup-app'),
            theme: KineticTheme.darkTheme,
            home: const Scaffold(
              body: AetronBrandLockup(markSize: 28, wordmarkHeight: 18),
            ),
          ),
        );

        final darkMarkPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AetronBrandMark),
            matching: find.byType(CustomPaint),
          ),
        );
        final darkWordmarkPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AetronWordmark),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          (darkMarkPaint.painter! as AetronBrandMarkPainter).color,
          AetronLogoPaths.darkAccentColor,
        );
        expect(
          (darkWordmarkPaint.painter! as AetronWordmarkPainter).accentColor,
          AetronLogoPaths.darkAccentColor,
        );
        expect(
          (darkWordmarkPaint.painter! as AetronWordmarkPainter).color,
          AetronLogoPaths.darkWordmarkColor,
        );
      },
    );

    testWidgets(
      'WelcomeScreen renders unified startup AetronBrandLockup without plain AETRON text',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              home: WelcomeScreen(onNext: () async {}),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('welcome-brand-lockup')),
          findsOneWidget,
        );
        expect(find.text('AETRON'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WorkoutShareCardSheet renders unified startup brand lockup and watermark',
      (tester) async {
        tester.view.physicalSize = const Size(480, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: const Scaffold(
                body: WorkoutShareCardSheet(
                  activityType: 'Running',
                  distanceKm: 5.2,
                  durationSeconds: 1800,
                  avgSpeedKmh: 10.4,
                  calories: 320,
                  steps: 5400,
                  useMetricUnits: true,
                  currentLang: AppLanguage.en,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('share-card-brand-lockup')),
          findsOneWidget,
        );
        expect(find.byType(AetronWordmark), findsNWidgets(2));
        expect(find.text('AETRON'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
