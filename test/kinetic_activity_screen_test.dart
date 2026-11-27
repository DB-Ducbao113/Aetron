import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViLanguageNotifier extends AppLanguageNotifier {
  _TestViLanguageNotifier() : super() {
    state = AppLanguage.vi;
  }
}

void main() {
  group('Map-First ActivityScreen Tests', () {
    testWidgets('renders live map, sport switcher pills, and updates start CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const ActivityScreen(showMapTiles: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrackingMapWidget), findsOneWidget);
      expect(find.byKey(const Key('activity-top-sport-pill')), findsOneWidget);
      expect(find.byKey(const Key('activity-gps-pill')), findsOneWidget);
      expect(find.byKey(const Key('activity-recenter-btn')), findsOneWidget);
      expect(find.text('Bắt đầu chạy bộ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sport-pill-cycling')));
      await tester.pump();
      expect(find.text('Bắt đầu đạp xe'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sport-pill-walking')));
      await tester.pump();
      expect(find.text('Bắt đầu đi bộ'), findsOneWidget);
    });
  });

  group('Map-First ActivityScreen Tests', () {
    testWidgets('renders live map, sport switcher pills, and updates start CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const ActivityScreen(showMapTiles: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrackingMapWidget), findsOneWidget);
      expect(find.byKey(const Key('activity-top-sport-pill')), findsOneWidget);
      expect(find.byKey(const Key('activity-gps-pill')), findsOneWidget);
      expect(find.byKey(const Key('activity-recenter-btn')), findsOneWidget);
      expect(find.text('Bắt đầu chạy bộ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sport-pill-cycling')));
      await tester.pump();
      expect(find.text('Bắt đầu đạp xe'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sport-pill-walking')));
      await tester.pump();
      expect(find.text('Bắt đầu đi bộ'), findsOneWidget);
    });
  });
}
