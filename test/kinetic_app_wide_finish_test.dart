import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(
    Widget child, {
    TargetPlatform platform = TargetPlatform.iOS,
    bool reduce = false,
    bool contrast = false,
  }) => MaterialApp(
    theme: KineticTheme.buildTheme(Brightness.dark, platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: reduce, highContrast: contrast),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'chip and card finish preserves geometry, gestures, and idle state',
    (tester) async {
      var chips = 0, cards = 0;
      final chip = KineticChip(
        label: 'Walking',
        isSelected: true,
        onTap: () => chips++,
      );
      final card = KineticCard(
        onTap: () => cards++,
        child: const SizedBox(width: 190, height: 60, child: Text('Activity')),
      );
      await tester.pumpWidget(
        host(Column(mainAxisSize: MainAxisSize.min, children: [chip, card])),
      );
      await tester.pumpAndSettle();
      for (final target in [find.byWidget(chip), find.byWidget(card)]) {
        final before = tester.getSize(target);
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getSize(target), before);
        expect(
          find.descendant(
            of: target,
            matching: find.byType(KineticSurfaceFinish),
          ),
          findsOneWidget,
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.getSize(target), before);
        expect(chips, 0);
        expect(cards, 0);
      }
      await tester.tap(find.byWidget(chip));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidget(card));
      await tester.pumpAndSettle();
      expect(chips, 1);
      expect(cards, 1);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic buttons receive full-size finish without changing layout',
    (tester) async {
      Future<Size> measure(TargetPlatform platform) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(ElevatedButton));
      }

      final android = await measure(TargetPlatform.android);
      expect(find.byType(KineticSurfaceFinish), findsNothing);
      final ios = await measure(TargetPlatform.iOS);
      expect(ios, android);
      final finish = find.byType(KineticSurfaceFinish);
      expect(finish, findsOneWidget);
      expect(tester.getSize(finish).width, ios.width);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'selection lens moves between original equal slots (reduce=$reduced)',
      (tester) async {
        var index = 0;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 300,
                child: KineticSlidingSelection(
                  index: index,
                  count: 3,
                  gap: 6,
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => index = i),
                            child: SizedBox(
                              height: 40,
                              child: Center(child: Text('Tab $i')),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            reduce: reduced,
          ),
        );
        await tester.pumpAndSettle();
        final lens = find.byKey(const ValueKey('kinetic-sliding-lens'));
        final start = tester.getCenter(lens).dx;
        final target = tester.getCenter(find.text('Tab 2')).dx;
        final rowSize = tester.getSize(find.byType(KineticSlidingSelection));
        await tester.tap(find.text('Tab 2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.getCenter(lens).dx;
        if (reduced) {
          expect(mid, closeTo(target, .1));
        } else {
          expect(mid, greaterThan(start));
          expect(mid, lessThan(target));
        }
        await tester.pumpAndSettle();
        expect(tester.getCenter(lens).dx, closeTo(target, .1));
        expect(tester.getSize(find.byType(KineticSlidingSelection)), rowSize);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets('high contrast and Android do not paint optical overlays', (
    tester,
  ) async {
    const finish = KineticSurfaceFinish(
      radius: 24,
      child: SizedBox(width: 100, height: 48),
    );
    for (final (platform, contrast) in [
      (TargetPlatform.android, false),
      (TargetPlatform.iOS, true),
    ]) {
      await tester.pumpWidget(
        host(finish, platform: platform, contrast: contrast),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byWidget(finish),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    }
  });
}
