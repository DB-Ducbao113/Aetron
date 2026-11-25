import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_workout_history_card.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_hero_distance.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestViLanguageNotifier extends AppLanguageNotifier {
  _TestViLanguageNotifier() : super() {
    state = AppLanguage.vi;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'});
  });
  Widget wrapInPhoneSE(Widget child) {
    return MaterialApp(
      theme: KineticTheme.darkTheme,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 667), // iPhone SE width
          devicePixelRatio: 2.0,
        ),
        child: Scaffold(
          body: SizedBox(
            width: 375,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('Renders all bumped widgets on 375pt iPhone SE without overflow', (tester) async {
    tester.view.physicalSize = const Size(375 * 2.0, 667 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockSession = WorkoutSession(
      id: 'ws-history-1',
      userId: 'user-1',
      activityType: 'running',
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      endedAt: DateTime.now().subtract(const Duration(hours: 1)),
      durationSec: 3600,
      distanceKm: 10.5,
      steps: 8200,
      avgSpeedKmh: 10.5,
      caloriesKcal: 650,
      mode: 'outdoor',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      gpsAnalysis: const WorkoutGpsAnalysis(
        validityFlag: WorkoutValidityFlag.verified,
      ),
    );

    // 1. History Card
    await tester.pumpWidget(
      wrapInPhoneSE(
        KineticWorkoutHistoryCard(
          workout: mockSession,
          useMetricUnits: true,
          currentLang: AppLanguage.vi,
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 2. Summary Hero Distance
    await tester.pumpWidget(
      wrapInPhoneSE(
        const KineticSummaryHeroDistance(
          distanceKm: 12.45,
          activityType: 'running',
          useMetricUnits: true,
          validityFlag: WorkoutValidityFlag.verified,
          currentLang: AppLanguage.vi,
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // 3. Live Top Bar
    await tester.pumpWidget(
      wrapInPhoneSE(
        KineticLiveTopBar(
          activityType: 'running',
          isOutdoor: true,
          isGpsWeak: false,
          isAutoPaused: false,
          isPaused: false,
          isLargeMetricsMode: false,
          isVi: true,
          onToggleMetricsMode: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RunningProgramsScreen renders on 375pt and 360pt without overflow in Vietnamese', (tester) async {
    // Test on 375pt (iPhone SE)
    tester.view.physicalSize = const Size(375 * 2.0, 667 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
        ],
        child: const MaterialApp(
          home: RunningProgramsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Verify all 4 programs are loaded inside Glassline KineticCard containers
    expect(find.byType(KineticCard), findsWidgets);
    expect(find.text('Hướng dẫn'), findsWidgets);
    expect(find.text('Bắt đầu'), findsWidgets);

    // Tap "Hướng dẫn" on the first card to verify the coaching sheet opens without overflow
    await tester.tap(find.text('Hướng dẫn').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Lộ trình huấn luyện từng bước'), findsOneWidget);
  });

  testWidgets('RunningProgramsScreen renders on 360pt width Android phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
        ],
        child: const MaterialApp(
          home: RunningProgramsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
