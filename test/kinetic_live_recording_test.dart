import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_control_dock.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_metrics_hud.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_workout_stop_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? KineticTheme.darkTheme,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('KineticLiveTopBar Widget Tests', () {
    testWidgets('renders running label and handles view mode toggle', (tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        buildTestable(
          KineticLiveTopBar(
            activityType: 'running',
            isOutdoor: true,
            isGpsWeak: false,
            isAutoPaused: false,
            isPaused: false,
            isLargeMetricsMode: false,
            isVi: true,
            onToggleMetricsMode: () => toggled = true,
          ),
        ),
      );

      expect(find.text('Đang chạy bộ'), findsOneWidget);
      expect(find.bySemanticsLabel('GPS Mạnh'), findsOneWidget);
      expect(find.text('Số liệu lớn'), findsOneWidget);

      await tester.tap(find.text('Số liệu lớn'));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('renders auto-paused indicator when paused by algorithm', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticLiveTopBar(
            activityType: 'cycling',
            isOutdoor: true,
            isGpsWeak: false,
            isAutoPaused: true,
            isPaused: false,
            isLargeMetricsMode: true,
            isVi: true,
            onToggleMetricsMode: () {},
          ),
        ),
      );

      expect(find.text('Tự động dừng'), findsOneWidget);
      expect(find.text('Xem bản đồ'), findsOneWidget);
    });
  });

  group('KineticLiveMetricsHud Widget Tests', () {
    testWidgets('renders hero distance, speed, pace, and time correctly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const SingleChildScrollView(
            child: KineticLiveMetricsHud(
              distanceMeters: 5240,
              durationSeconds: 1540,
              movingTimeSeconds: 1500,
              speedKmh: 12.5,
              avgSpeedKmh: 12.2,
              calories: 340,
              stepCount: 4200,
              activityType: 'running',
              useMetricUnits: true,
              isVi: true,
              isLargeMetricsMode: false,
            ),
          ),
        ),
      );

      // 5240m = 5.24 km
      expect(find.text('5.24'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Qu.*')), findsOneWidget);

      // Running secondary row shows Pace
      expect(find.text('PACE TỨC THÌ'), findsOneWidget);
      expect(find.text('THỜI GIAN'), findsOneWidget);
      expect(find.text('CALO'), findsOneWidget);
      expect(find.text('BƯỚC CHÂN'), findsOneWidget);
    });

    testWidgets('renders cycling cadence/speed correctly without step count', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const SingleChildScrollView(
            child: KineticLiveMetricsHud(
              distanceMeters: 15800,
              durationSeconds: 2400,
              movingTimeSeconds: 2350,
              speedKmh: 24.8,
              avgSpeedKmh: 23.5,
              calories: 450,
              stepCount: 0,
              activityType: 'cycling',
              useMetricUnits: true,
              isVi: true,
              isLargeMetricsMode: false,
            ),
          ),
        ),
      );

      expect(find.text('15.80'), findsOneWidget);
      expect(find.text('TỐC ĐỘ TỨC THÌ'), findsOneWidget);
      // Cycling does not render step count
      expect(find.text('SỐ BƯỚC CHÂN'), findsNothing);
    });
  });

  group('KineticLiveControlDock Widget Tests', () {
    testWidgets('renders pause/resume and triggers callbacks', (tester) async {
      bool pauseResumed = false;
      bool stopped = false;
      bool lockToggled = false;

      await tester.pumpWidget(
        buildTestable(
          KineticLiveControlDock(
            isPaused: false,
            isLocked: false,
            isSaving: false,
            canToggle: true,
            isVi: true,
            onPauseResume: () => pauseResumed = true,
            onStop: () => stopped = true,
            onToggleLock: () => lockToggled = true,
          ),
        ),
      );

      expect(find.text('TẠM DỪNG'), findsOneWidget);

      await tester.tap(find.text('TẠM DỪNG'));
      await tester.pump();
      expect(pauseResumed, isTrue);

      await tester.tap(
        find.byIcon(BladeIcon.iconDataFor(BladeIconName.flag)),
      );
      await tester.pump();
      expect(stopped, isTrue);

      await tester.tap(
        find.byIcon(BladeIcon.iconDataFor(BladeIconName.lock)),
      );
      await tester.pump();
      expect(lockToggled, isTrue);
    });

    testWidgets('renders streamlined dock in paused state with correct semantics and labels', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticLiveControlDock(
            isPaused: true,
            isLocked: true,
            isSaving: false,
            canToggle: true,
            isVi: true,
            onPauseResume: () {},
            onStop: () {},
            onToggleLock: () {},
          ),
        ),
      );

      // In paused state, hero button label is TIẾP TỤC
      expect(find.text('TIẾP TỤC'), findsOneWidget);
      expect(
        find.byIcon(BladeIcon.iconDataFor(BladeIconName.lock)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Tiếp tục bài tập'), findsOneWidget);
      expect(find.bySemanticsLabel('Mở khóa màn hình'), findsOneWidget);
      expect(find.bySemanticsLabel('Kết thúc bài tập'), findsOneWidget);
    });
  });

  group('KineticMiniMetricsCard Widget Tests', () {
    testWidgets('renders 4 core telemetry metrics and responds to tap', (tester) async {
      bool expanded = false;

      await tester.pumpWidget(
        buildTestable(
          KineticMiniMetricsCard(
            distanceMeters: 2540,
            durationSeconds: 754,
            speedKmh: 12.5,
            avgSpeedKmh: 11.8,
            calories: 182,
            activityType: 'running',
            useMetricUnits: true,
            isVi: true,
            statusText: 'ĐANG CHẠY BỘ',
            gpsLabel: 'GPS Tốt',
            gpsColor: const Color(0xFF16A34A),
            onExpand: () => expanded = true,
          ),
        ),
      );

      // Distance (2.54 KM)
      expect(find.text('2.54'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Qu.*')), findsOneWidget);

      // Time (12:34)
      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('THỜI GIAN'), findsOneWidget);

      // Calories (182 kcal)
      expect(find.text('182'), findsOneWidget);
      expect(find.text('CALO'), findsOneWidget);

      // Tap card triggers onExpand
      await tester.tap(find.text('2.54'));
      await tester.pump();
      expect(expanded, isTrue);
    });
  });

  group('KineticWorkoutStopSheet Widget Tests', () {
    testWidgets('renders confirmation title, quick telemetry bento and actions in Vietnamese', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticWorkoutStopSheet(
            distanceMeters: 3450,
            durationSeconds: 1245,
            caloriesBurned: 240,
            speedKmh: 10.0,
            activityType: 'running',
            useMetricUnits: true,
            isVi: true,
          ),
        ),
      );

      expect(find.text('BẠN CÓ CHẮC CHẮN MUỐN DỪNG?'), findsOneWidget);
      expect(find.text('QUÃNG ĐƯỜNG'), findsOneWidget);
      expect(find.text('3.45'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.text('THỜI GIAN'), findsOneWidget);
      expect(find.text('20:45'), findsOneWidget);
      expect(find.text('TIẾP TỤC TẬP LUYỆN'), findsOneWidget);
      expect(find.text('KẾT THÚC & LƯU BÀI TẬP'), findsOneWidget);
    });

    testWidgets('renders in English and works with light theme', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticWorkoutStopSheet(
            distanceMeters: 5000,
            durationSeconds: 1800,
            caloriesBurned: 350,
            speedKmh: 12.0,
            activityType: 'cycling',
            useMetricUnits: false,
            isVi: false,
          ),
          theme: KineticTheme.lightTheme,
        ),
      );

      expect(find.text('FINISH THIS WORKOUT?'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('MI'), findsOneWidget);
      expect(find.text('CONTINUE WORKOUT'), findsOneWidget);
      expect(find.text('FINISH & SAVE SESSION'), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('FINISH THIS WORKOUT?'));
      expect(titleWidget.style?.color != Colors.white, isTrue);
    });
  });
}

