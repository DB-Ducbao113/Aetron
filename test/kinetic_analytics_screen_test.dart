import 'package:fitness_exercise_application/features/analytics/presentation/models/time_period.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_activity_mix_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_analytics_header.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_key_telemetry_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_performance_story_bento.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_recovery_guidance_card.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: KineticTheme.darkTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  final mockWorkouts = [
    WorkoutSession(
      id: 'ws-1',
      userId: 'user-1',
      activityType: 'cycling',
      startedAt: DateTime.now().subtract(const Duration(days: 1)),
      endedAt: DateTime.now().subtract(const Duration(days: 1)),
      durationSec: 3600,
      distanceKm: 25.5,
      steps: 0,
      avgSpeedKmh: 25.5,
      caloriesKcal: 520,
      mode: 'outdoor',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WorkoutSession(
      id: 'ws-2',
      userId: 'user-1',
      activityType: 'running',
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
      endedAt: DateTime.now().subtract(const Duration(days: 2)),
      durationSec: 1800,
      distanceKm: 5.2,
      steps: 4200,
      avgSpeedKmh: 10.4,
      caloriesKcal: 310,
      mode: 'outdoor',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    WorkoutSession(
      id: 'ws-3',
      userId: 'user-1',
      activityType: 'walking',
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      endedAt: DateTime.now().subtract(const Duration(days: 3)),
      durationSec: 2400,
      distanceKm: 3.1,
      steps: 3800,
      avgSpeedKmh: 4.6,
      caloriesKcal: 140,
      mode: 'indoor',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  group('Kinetic Analytics Header Tests', () {
    testWidgets('renders title and handles period switching', (tester) async {
      TimePeriod? selected;

      await tester.pumpWidget(
        buildTestable(
          KineticAnalyticsHeader(
            selectedPeriod: TimePeriod.week,
            onPeriodChanged: (p) => selected = p,
            isOffline: false,
            isVi: true,
          ),
        ),
      );

      expect(find.text('Phân tích'), findsOneWidget);
      expect(find.text('NHỊP ĐIỆU VẬN ĐỘNG'), findsNothing);
      expect(find.text('HIỆU SUẤT'), findsOneWidget);
      expect(find.text('Tuần này'), findsOneWidget);
      expect(find.text('Tháng này'), findsOneWidget);
      expect(find.text('Năm nay'), findsOneWidget);

      await tester.tap(find.text('Tháng này'));
      await tester.pump();

      expect(selected, equals(TimePeriod.month));
    });
  });

  group('Kinetic Performance Story Bento Tests', () {
    testWidgets(
      'renders dynamic narrative and 7-day slender bars with peak day',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            KineticPerformanceStoryBento(
              workouts: mockWorkouts,
              period: TimePeriod.week,
              currentDistanceKm: 33.8,
              previousDistanceKm: 26.0,
              useMetricUnits: true,
              isVi: true,
            ),
          ),
        );

        // Hero distance: 33.8 km
        expect(find.text('33.8'), findsOneWidget);
        expect(find.text('km'), findsOneWidget);
        // Percentage comparison: (33.8 - 26) / 26 = +30%
        expect(find.text('+30% so với trước'), findsOneWidget);
        // Week day indicators
        expect(find.text('T2'), findsOneWidget);
        expect(find.text('CN'), findsOneWidget);
      },
    );
  });

  group('Kinetic Key Telemetry Bento Tests', () {
    testWidgets('renders 4 endurance telemetry cards correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          KineticKeyTelemetryBento(
            workouts: mockWorkouts,
            useMetricUnits: true,
            isVi: true,
          ),
        ),
      );

      // Distance: 25.5 + 5.2 + 3.1 = 33.8
      expect(find.text('33.8'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      // Calories: 520 + 310 + 140 = 970
      expect(find.text('970'), findsOneWidget);
      // Sessions: 3
      expect(find.text('3'), findsOneWidget);
      expect(find.text('BUỔI'), findsOneWidget);
    });
  });

  group('Kinetic Activity Mix Bento Tests', () {
    testWidgets(
      'renders 3 core disciplines (Cycling, Running, Walking) without gym',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            KineticActivityMixBento(
              workouts: mockWorkouts,
              useMetricUnits: true,
              isVi: true,
            ),
          ),
        );

        expect(find.text('CƠ CẤU MÔN TẬP'), findsOneWidget);
        expect(find.text('Đạp xe'), findsOneWidget);
        expect(find.text('Chạy bộ'), findsOneWidget);
        expect(find.text('Đi bộ'), findsOneWidget);

        // Verify Gym / Bodybuilding is absent
        expect(find.text('Gym'), findsNothing);
        expect(find.text('Thể hình'), findsNothing);
      },
    );
  });

  group('Kinetic Recovery Guidance Card Tests', () {
    testWidgets('renders adaptive strain evaluation and CTA button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          KineticRecoveryGuidanceCard(workouts: mockWorkouts, isVi: true),
        ),
      );

      expect(find.text('CHỈ DẪN HỒI PHỤC'), findsOneWidget);
      expect(find.text('Lên lịch đi bộ nhẹ'), findsOneWidget);
    });

    testWidgets('CTA selects Activity without pushing a standalone screen', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: Scaffold(
              body: KineticRecoveryGuidanceCard(
                workouts: mockWorkouts,
                isVi: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Lên lịch đi bộ nhẹ'));
      await tester.pump();

      expect(container.read(mainTabControllerProvider), activityTabIndex);
      expect(find.byType(KineticRecoveryGuidanceCard), findsOneWidget);
    });
  });
}
