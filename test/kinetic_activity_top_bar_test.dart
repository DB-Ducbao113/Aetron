import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KineticActivityTopBar Widget Tests', () {
    testWidgets('renders title and GPS ready status in outdoor mode', (tester) async {
      bool mapTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticActivityTopBar(
              isVi: true,
              isOutdoor: true,
              checkingLocation: false,
              hasLocationPermission: true,
              gpsEnabled: true,
              onMapPreviewTap: () => mapTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('KHỞI ĐỘNG LUYỆN TẬP'), findsNothing);
      expect(find.text('Bắt đầu.'), findsOneWidget);
      expect(find.text('GPS SẴN SÀNG'), findsOneWidget);
      expect(
        find.byIcon(BladeIcon.iconDataFor(BladeIconName.gps)),
        findsOneWidget,
      );

      await tester.tap(find.text('GPS SẴN SÀNG'));
      await tester.pump();
      expect(mapTapped, isTrue);
    });

    testWidgets('renders enable GPS action when GPS permission is denied', (tester) async {
      bool gpsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: KineticActivityTopBar(
              isVi: true,
              isOutdoor: true,
              checkingLocation: false,
              hasLocationPermission: false,
              gpsEnabled: false,
              onGpsTap: () => gpsTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('BẬT GPS'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);

      await tester.tap(find.text('BẬT GPS'));
      await tester.pump();
      expect(gpsTapped, isTrue);
    });

    testWidgets('renders indoor badge when isOutdoor is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticActivityTopBar(
              isVi: true,
              isOutdoor: false,
              checkingLocation: false,
              hasLocationPermission: false,
              gpsEnabled: false,
            ),
          ),
        ),
      );

      expect(find.text('TRONG NHÀ'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    });

    testWidgets('renders English translations correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: KineticActivityTopBar(
              isVi: false,
              isOutdoor: true,
              checkingLocation: false,
              hasLocationPermission: true,
              gpsEnabled: true,
            ),
          ),
        ),
      );

      expect(find.text('START WORKOUT'), findsNothing);
      expect(find.text('Start.'), findsOneWidget);
      expect(find.text('GPS READY'), findsOneWidget);
    });
  });
}
