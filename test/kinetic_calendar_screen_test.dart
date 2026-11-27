import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_empty_state.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_range_tabs.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_sport_filter.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_telemetry_bento.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_top_bar.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_workout_history_card.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLanguageNotifier extends AppLanguageNotifier {
  _MockLanguageNotifier(AppLanguage lang) : super() {
    state = lang;
  }
}

class _MockWorkoutList extends WorkoutList {
  final List<WorkoutSession> _mockWorkouts;
  _MockWorkoutList(this._mockWorkouts);

  @override
  Future<List<WorkoutSession>> build() async => _mockWorkouts;
}

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: KineticTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  final mockWorkoutSession = WorkoutSession(
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

  group('KineticHistoryTopBar Widget Tests', () {
    testWidgets('renders title and total workout count badge', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticHistoryTopBar(
            totalCount: 15,
            currentLang: AppLanguage.vi,
            isOffline: false,
          ),
        ),
      );

      expect(find.text('AETRON ARCHIVE'), findsNothing);
      expect(find.text('Lịch sử tập luyện'), findsOneWidget);
      expect(find.text('15 buổi'), findsOneWidget);
    });

    testWidgets('shows offline indicator when isOffline is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticHistoryTopBar(
            totalCount: 5,
            currentLang: AppLanguage.vi,
            isOffline: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('KineticHistorySportFilter Widget Tests', () {
    testWidgets('renders 4 endurance categories and handles selection', (
      tester,
    ) async {
      String selected = 'all';

      await tester.pumpWidget(
        buildTestable(
          KineticHistorySportFilter(
            selected: selected,
            currentLang: AppLanguage.vi,
            onSelected: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('Đạp xe'), findsOneWidget);
      expect(find.text('Đi bộ'), findsOneWidget);

      await tester.tap(find.text('Chạy bộ'));
      await tester.pump();
      expect(selected, 'running');
    });
  });

  group('KineticHistoryRangeTabs Widget Tests', () {
    testWidgets('renders all periods and triggers change callback', (
      tester,
    ) async {
      HistoryRange selectedRange = HistoryRange.all;

      await tester.pumpWidget(
        buildTestable(
          KineticHistoryRangeTabs(
            selected: selectedRange,
            currentLang: AppLanguage.vi,
            onChanged: (val) => selectedRange = val,
          ),
        ),
      );

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Tuần'), findsOneWidget);
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('Năm'), findsOneWidget);

      await tester.tap(find.text('Tuần'));
      await tester.pump();
      expect(selectedRange, HistoryRange.week);
    });
  });

  group('KineticHistoryTelemetryBento Widget Tests', () {
    testWidgets('renders period matrix distance, duration and calories', (
      tester,
    ) async {
      const summary = HistorySummaryData(
        workouts: 8,
        distanceKm: 64.2,
        durationSec: 18000,
        calories: 3800,
        steps: 45000,
      );

      await tester.pumpWidget(
        buildTestable(
          const KineticHistoryTelemetryBento(
            summary: summary,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Tổng quan giai đoạn'), findsOneWidget);
      expect(find.text('8 hoạt động'), findsOneWidget);
      expect(find.text('64.2'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.text('3800 kcal'), findsOneWidget);
    });
  });

  group('KineticWorkoutHistoryCard Widget Tests', () {
    testWidgets('renders running workout card with formatted metrics', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          KineticWorkoutHistoryCard(
            workout: mockWorkoutSession,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('10.50'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.text('Đã xác minh'), findsNothing);
      expect(find.text('Hiệu chỉnh'), findsNothing);
      expect(find.text('Cảm biến'), findsNothing);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
    });
  });

  group('KineticHistoryEmptyState Widget Tests', () {
    testWidgets('renders empty state with start workout CTA', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticHistoryEmptyState(
            currentLang: AppLanguage.vi,
            isFiltered: false,
          ),
        ),
      );

      expect(find.text('Bắt đầu buổi tập'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets(
      'start workout CTA selects Activity inside the five-tab shell',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: const Scaffold(
                body: KineticHistoryEmptyState(
                  currentLang: AppLanguage.vi,
                  isFiltered: false,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Bắt đầu buổi tập'));
        await tester.pump();

        expect(container.read(mainTabControllerProvider), 1);
        expect(find.byType(ActivityScreen), findsNothing);
      },
    );
  });

  group('Full CalendarScreen Integration Test', () {
    testWidgets('renders full CalendarScreen with mock workouts list', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith(
              (ref) => _MockLanguageNotifier(AppLanguage.vi),
            ),
            metricUnitsPreferenceProvider.overrideWith((ref) async => true),
            appConnectionProvider.overrideWith((ref) => Stream.value(true)),
            workoutListProvider.overrideWith(
              () => _MockWorkoutList([mockWorkoutSession]),
            ),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const CalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AETRON ARCHIVE'), findsNothing);
      expect(find.text('1 buổi'), findsOneWidget);
      expect(find.text('Tất cả'), findsNWidgets(2));
      expect(find.text('Chạy bộ'), findsWidgets);
      expect(find.text('Tổng quan giai đoạn'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsWidgets);
    });
  });
}
