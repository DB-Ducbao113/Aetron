import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_action_dock.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_header.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_hero_distance.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_splits_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/summary/kinetic_summary_telemetry_grid.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _MockLanguageNotifier extends AppLanguageNotifier {
  _MockLanguageNotifier(AppLanguage lang) : super() {
    state = lang;
  }
}

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: KineticTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('KineticSummaryHeader Widget Tests', () {
    testWidgets(
      'renders running activity name and triggers back/share callbacks',
      (tester) async {
        bool backTapped = false;
        bool shareTapped = false;

        await tester.pumpWidget(
          buildTestable(
            KineticSummaryHeader(
              activityType: 'running',
              trackingMode: 'outdoor',
              currentLang: AppLanguage.vi,
              onBackToHome: () => backTapped = true,
              onShare: () => shareTapped = true,
            ),
          ),
        );

        // AETRON TELEMETRY is removed for cleaner title
        expect(find.text('AETRON TELEMETRY'), findsNothing);
        expect(find.text('Tóm tắt buổi tập'), findsOneWidget);
        expect(find.text('Chạy bộ'), findsOneWidget);
        // GPS Ngoài trời is now removed
        expect(find.text('GPS Ngoài trời'), findsNothing);

        await tester.tap(
          find.byIcon(BladeIcon.iconDataFor(BladeIconName.chevL)),
        );
        await tester.pump();
        expect(backTapped, isTrue);

        await tester.tap(
          find.byIcon(BladeIcon.iconDataFor(BladeIconName.share)),
        );
        await tester.pump();
        expect(shareTapped, isTrue);
      },
    );

    testWidgets('renders cycling and omits mode badge', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticSummaryHeader(
            activityType: 'cycling',
            trackingMode: 'indoor',
            currentLang: AppLanguage.en,
            onBackToHome: () {},
            onShare: () {},
          ),
        ),
      );

      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('Indoor Pedometer'), findsNothing);
      expect(find.byIcon(Icons.directions_bike_rounded), findsOneWidget);
    });

    testWidgets('omits share button when onShare is null', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticSummaryHeader(
            activityType: 'walking',
            currentLang: AppLanguage.vi,
            onBackToHome: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    });
  });

  group('KineticSummaryHeroDistance Widget Tests', () {
    testWidgets(
      'renders distance value and verified status without headlines',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            const KineticSummaryHeroDistance(
              distanceKm: 12.45,
              activityType: 'running',
              useMetricUnits: true,
              validityFlag: WorkoutValidityFlag.verified,
              currentLang: AppLanguage.vi,
            ),
          ),
        );

        // Count-up animation runs 450ms — pump through it to the final value.
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.text('12.45'), findsOneWidget);
        expect(find.text('KM'), findsOneWidget);
        expect(find.text('Hoàn thành xuất sắc'), findsOneWidget);
        expect(find.text('GPS đã xác minh'), findsNothing);
        expect(find.text('Cảm biến nội suy'), findsNothing);
        expect(find.text('Bước đi vững chãi và đều đặn!'), findsNothing);
      },
    );

    testWidgets('converts to miles when useMetricUnits is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryHeroDistance(
            distanceKm: 10.0,
            activityType: 'walking',
            useMetricUnits: false,
            validityFlag: WorkoutValidityFlag.unverified,
            currentLang: AppLanguage.en,
          ),
        ),
      );

      // Count-up animation runs 450ms — pump through it to the final value.
      await tester.pump(const Duration(milliseconds: 450));

      // 10 km * 0.621371 = 6.21 mi
      expect(find.text('6.21'), findsOneWidget);
      expect(find.text('MI'), findsOneWidget);
      expect(find.text('GPS calibrated'), findsNothing);
      expect(find.text('Sensor interpolated'), findsNothing);
      expect(find.text('Bước đi vững chãi và đều đặn!'), findsNothing);
    });
  });

  group('KineticSummaryTelemetryGrid Widget Tests', () {
    testWidgets(
      'renders moving time, pace, calories, and cadence for running',
      (tester) async {
        await tester.pumpWidget(
          buildTestable(
            const KineticSummaryTelemetryGrid(
              activityType: 'running',
              durationSeconds: 1800,
              movingTimeSeconds: 1750,
              avgSpeedKmh: 10.0,
              calories: 320,
              steps: 4200,
              useMetricUnits: true,
              currentLang: AppLanguage.vi,
            ),
          ),
        );

        expect(find.text('Thời gian di chuyển'), findsOneWidget);
        expect(find.text('Nhịp độ trung bình'), findsOneWidget);
        expect(find.text('Năng lượng'), findsOneWidget);
        expect(find.text('320'), findsOneWidget);
        expect(find.text('Tổng số bước'), findsOneWidget);
        expect(find.text('4200'), findsOneWidget);
      },
    );

    testWidgets('shows max speed and hides steps for cycling', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticSummaryTelemetryGrid(
            activityType: 'cycling',
            durationSeconds: 3600,
            movingTimeSeconds: 3600,
            avgSpeedKmh: 25.0,
            calories: 600,
            steps: 0,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Tốc độ TB'), findsOneWidget);
      expect(find.text('25.0'), findsOneWidget);
      expect(find.text('km/h'), findsWidgets);
      expect(find.text('Vận tốc tối đa'), findsOneWidget);
      expect(find.text('TỔNG SỐ BƯỚC'), findsNothing);
    });
  });

  group('KineticSummarySplitsCard Widget Tests', () {
    testWidgets('highlights the fastest split lap with badge', (tester) async {
      final splits = [
        const WorkoutLapSplit(
          index: 1,
          distanceKm: 1.0,
          durationSeconds: 340,
          paceMinPerKm: 5.67,
        ),
        const WorkoutLapSplit(
          index: 2,
          distanceKm: 1.0,
          durationSeconds: 300,
          paceMinPerKm: 5.0, // Fastest
        ),
        const WorkoutLapSplit(
          index: 3,
          distanceKm: 1.0,
          durationSeconds: 320,
          paceMinPerKm: 5.33,
        ),
      ];

      await tester.pumpWidget(
        buildTestable(
          KineticSummarySplitsCard(
            lapSplits: splits,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Phân tách cự ly'), findsOneWidget);
      expect(find.text('3 chặng'), findsOneWidget);
      expect(find.text('Km 1'), findsOneWidget);
      expect(find.text('Km 2'), findsOneWidget);
      expect(find.text('Km 3'), findsOneWidget);
      expect(find.text('Nhanh nhất'), findsOneWidget);
    });
  });

  group('KineticSummaryActionDock Widget Tests', () {
    testWidgets('fires action callbacks on press', (tester) async {
      bool sharePressed = false;
      bool donePressed = false;
      bool detailsPressed = false;

      await tester.pumpWidget(
        buildTestable(
          KineticSummaryActionDock(
            currentLang: AppLanguage.vi,
            onShare: () => sharePressed = true,
            onDone: () => donePressed = true,
            onViewDetails: () => detailsPressed = true,
          ),
        ),
      );

      await tester.tap(find.text('Chia sẻ buổi tập'));
      await tester.pump();
      expect(sharePressed, isTrue);

      await tester.tap(find.text('Hoàn thành'));
      await tester.pump();
      expect(donePressed, isTrue);

      await tester.tap(find.text('Xem chi tiết kỹ thuật'));
      await tester.pump();
      expect(detailsPressed, isTrue);
    });
  });

  group('Full WorkoutSummaryScreen Widget Test', () {
    test(
      'uses the complete route when a stale one-point segment is supplied',
      () {
        const start = LatLng(10.7769, 106.7009);
        const middle = LatLng(10.7775, 106.7016);
        const finish = LatLng(10.7782, 106.7024);
        const completeRoute = [start, middle, finish];

        final preview = resolveWorkoutSummaryRoutePreview(
          routePoints: completeRoute,
          // A just-started smoothed segment must not hide the complete route
          // that was flushed when recording stopped.
          routeSegments: const [
            [start],
          ],
        );

        expect(preview.points, completeRoute);
        expect(preview.segments, [completeRoute]);
      },
    );

    testWidgets('renders all summary sections in dark mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith(
              (ref) => _MockLanguageNotifier(AppLanguage.vi),
            ),
            metricUnitsPreferenceProvider.overrideWith((ref) async => true),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const WorkoutSummaryScreen(
              sessionId: 'test-session-123',
              activityType: 'running',
              trackingMode: 'outdoor',
              durationSeconds: 1920,
              movingTimeSeconds: 1800,
              distanceMeters: 5200,
              avgSpeedKmh: 10.4,
              calories: 360,
              steps: 4320,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AETRON TELEMETRY is removed
      expect(find.text('AETRON TELEMETRY'), findsNothing);
      expect(find.text('Tóm tắt buổi tập'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsOneWidget);
      // GPS Ngoài trời is removed
      expect(find.text('GPS Ngoài trời'), findsNothing);
      expect(find.text('5.20'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      // Subtitle headlines are removed
      expect(find.text('Bước đi vững chãi và đều đặn!'), findsNothing);
      expect(find.text('Thời gian di chuyển'), findsOneWidget);
      expect(find.text('360'), findsOneWidget);
      // Exactly 1 share button on the screen (the prominent action dock button)
      expect(find.text('Chia sẻ buổi tập'), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      expect(find.text('Hoàn thành'), findsOneWidget);
      expect(find.text('Xem chi tiết kỹ thuật'), findsOneWidget);
    });
  });
}
