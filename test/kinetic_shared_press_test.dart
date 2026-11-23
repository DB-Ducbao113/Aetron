import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final reduced in [false, true]) {
      for (final glass in [false, true]) {
        testWidgets('$platform reduced=$reduced glass=$glass press/cancel', (
          tester,
        ) async {
          var taps = 0;
          final button = glass
              ? KineticGlassIconButton(
                  label: 'Action',
                  icon: const BladeIcon(BladeIconName.gps),
                  onPressed: () => taps++,
                )
              : KineticButton(label: 'Action', onPressed: () => taps++);
          await tester.pumpWidget(
            MaterialApp(
              theme: KineticTheme.darkTheme.copyWith(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: child!,
              ),
              home: Scaffold(body: Center(child: button)),
            ),
          );
          final target = find.byWidget(button);
          final scale = find.descendant(
            of: target,
            matching: find.byType(ScaleTransition),
          );
          final originalSize = tester.getSize(target);
          final gesture = await tester.startGesture(tester.getCenter(target));
          await tester.pump(const Duration(milliseconds: 120));
          await tester.pump(const Duration(milliseconds: 60));
          final value = tester.widget<ScaleTransition>(scale).scale.value;
          if (reduced || (glass && platform == TargetPlatform.android)) {
            expect(value, 1);
          } else {
            expect(value, lessThan(1));
            expect(value, greaterThanOrEqualTo(.96));
          }
          expect(tester.getSize(target), originalSize);
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(taps, 0);
          expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(taps, 1);
          expect(tester.getSize(target), originalSize);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('iOS location outline and active fill match native semantics', (
    tester,
  ) async {
    for (final active in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme.copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: KineticGlassIconButton(
              label: 'Location',
              icon: const BladeIcon(BladeIconName.gps, size: 22),
              active: active,
              onPressed: () {},
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(
        icon.icon,
        active ? CupertinoIcons.location_fill : CupertinoIcons.location,
      );
      expect(icon.size, 22);
    }
  });
}
