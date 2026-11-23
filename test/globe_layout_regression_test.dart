import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final globe = find.byKey(const ValueKey('aetron-globe-canvas'));

  setUp(
    () => SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'en'}),
  );

  Future<void> show(
    WidgetTester tester,
    Size size,
    EdgeInsets padding, {
    bool telemetry = false,
    bool reduced = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: KineticTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: padding,
              viewPadding: padding,
              disableAnimations: reduced,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: AetronGlobeOrbitScreen(
            showTelemetryChips: telemetry,
            customTitle: 'Aetron',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final (size, padding, telemetry, scale) in [
    (
      const Size(390, 844),
      const EdgeInsets.only(top: 59, bottom: 34),
      false,
      1.0,
    ),
    (const Size(320, 568), const EdgeInsets.only(top: 20), true, 1.3),
    (const Size(844, 390), const EdgeInsets.fromLTRB(59, 0, 34, 21), true, 1.3),
  ]) {
    testWidgets('globe centered within safe viewport $size', (tester) async {
      await show(tester, size, padding, telemetry: telemetry, scale: scale);
      final rect = tester.getRect(globe);
      final safeRect = Rect.fromLTRB(
        padding.left,
        padding.top,
        size.width - padding.right,
        size.height - padding.bottom,
      );
      expect(rect.center.dx, closeTo(safeRect.center.dx, 0.5));
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.width, greaterThan(0));
      expect(safeRect.contains(rect.topLeft), isTrue);
      expect(rect.bottom, lessThan(tester.getTopLeft(find.text('Aetron')).dy));
      expect(
        tester.getRect(find.textContaining('%')).bottom,
        lessThanOrEqualTo(safeRect.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'animation and drag keep painter instances instead of rebuilding globe',
    (tester) async {
      await show(
        tester,
        const Size(390, 844),
        const EdgeInsets.only(top: 59, bottom: 34),
      );
      final paints = find.descendant(
        of: globe,
        matching: find.byType(CustomPaint),
      );
      final initial = tester.widgetList<CustomPaint>(paints).toList();
      expect(initial.length, 4);
      expect(initial.where((p) => p.willChange).length, 2);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widgetList<CustomPaint>(paints), orderedEquals(initial));
      await tester.drag(globe, const Offset(70, 0));
      await tester.pump();
      expect(tester.widgetList<CustomPaint>(paints), orderedEquals(initial));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion idle globe settles', (tester) async {
    await show(tester, const Size(390, 844), EdgeInsets.zero, reduced: true);
    await tester.pumpAndSettle();
    expect(find.text('18%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('18%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timed startup can transition into indefinite loading', (
    tester,
  ) async {
    var completed = 0;
    var loading = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: KineticTheme.darkTheme,
          home: StatefulBuilder(
            builder: (context, setState) => AetronGlobeOrbitScreen(
              duration: const Duration(seconds: 1),
              onComplete: loading
                  ? null
                  : () {
                      completed++;
                      setState(() => loading = true);
                    },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(completed, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('100%'), findsNothing);
    final first = tester.widget<Text>(find.textContaining('%')).data;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Text>(find.textContaining('%')).data, isNot(first));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });
}
