import 'dart:io';

import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_explore_routes.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_home_top_bar.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_recent_activity_card.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_your_week_bento.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Future<void> _loadBeVietnamProFonts() async {
  const weights = [
    'fonts/BeVietnamPro-Regular.ttf',
    'fonts/BeVietnamPro-Medium.ttf',
    'fonts/BeVietnamPro-SemiBold.ttf',
    'fonts/BeVietnamPro-Bold.ttf',
    'fonts/BeVietnamPro-ExtraBold.ttf',
  ];
  final loader = FontLoader('BeVietnamPro');
  var loadedAny = false;
  for (final path in weights) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      loadedAny = true;
    }
  }
  if (loadedAny) {
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await _loadBeVietnamProFonts();
  });

  group('Kinetic HomeScreen Refinements Widget Tests', () {
    testWidgets(
      'KineticHomeTopBar renders clean greeting, streak pill, bell, and no AETRON chrome',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KineticTheme.lightTheme,
            home: Scaffold(
              body: KineticHomeTopBar(
                avatarImage: null,
                initials: 'DB',
                displayName: 'Duc Bao',
                greeting: 'Hôm nay',
                streakCount: 5,
                isVi: true,
                onAvatarTap: () {},
                onStreakTap: () {},
                onNotificationTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('AETRON'), findsNothing);
        expect(find.text('Hôm nay'), findsOneWidget);
        expect(find.text('5 ngày'), findsOneWidget);
        expect(find.byIcon(LucideIcons.bell), findsOneWidget);
      },
    );

    testWidgets(
      'KineticYourWeekBento renders clean weekly goal card and 7-day strip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KineticTheme.lightTheme,
            home: Scaffold(
              body: KineticYourWeekBento(
                weeklyDistanceKm: 18.4,
                workoutCount: 3,
                targetDistanceKm: 40.0,
                dateRangeText: 'Tuần này',
                isVi: true,
                activeWeekdays: const {1, 2, 4},
                onSetGoalTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Mục tiêu tuần'), findsOneWidget);
        expect(find.text('Điều chỉnh'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
      },
    );

    testWidgets(
      'KineticRecentActivityCard renders header, empty CTA, and workout summary row without map tiles',
      (tester) async {
        bool startTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              home: Scaffold(
                body: KineticRecentActivityCard(
                  workouts: const <WorkoutSession>[],
                  useMetricUnits: true,
                  isVi: true,
                  showMapTiles: false,
                  onSeeAllTap: () {},
                  onWorkoutTap: (_) {},
                  onStartFirstWorkoutTap: () => startTapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Hoạt động gần đây'), findsOneWidget);
        await tester.tap(find.byIcon(LucideIcons.play));
        await tester.pump();
        expect(startTapped, isTrue);
      },
    );

    testWidgets(
      'KineticExploreRoutes renders guided training carousel cards',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KineticTheme.lightTheme,
            home: Scaffold(
              body: KineticExploreRoutes(
                isVi: true,
              ),
            ),
          ),
        );

        expect(find.text('Giáo án luyện tập'), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
      },
    );

    testWidgets(
      'WorkoutRoutePreviewMap sets FlutterMap backgroundColor to KineticColors.dark.surface2 in Dark Mode',
      (tester) async {
        const route = <LatLng>[
          LatLng(10.7755, 106.7005),
          LatLng(10.7775, 106.6992),
          LatLng(10.7794, 106.7016),
          LatLng(10.7755, 106.7005),
        ];
        final session = WorkoutSession(
          id: 'w-dark-map-1',
          userId: 'u1',
          activityType: 'running',
          startedAt: DateTime(2026, 11, 18, 6, 15),
          endedAt: DateTime(2026, 11, 18, 7, 2),
          durationSec: 2820,
          movingTimeSec: 2820,
          distanceKm: 8.42,
          steps: 9800,
          avgSpeedKmh: 10.75,
          caloriesKcal: 560,
          mode: 'outdoor',
          createdAt: DateTime(2026, 11, 18, 7, 2),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutRoutePresentationProvider('w-dark-map-1').overrideWith(
                (_) async => const WorkoutRoutePresentation(
                  routePoints: route,
                  routeSegments: [route],
                  source: 'filtered',
                  matchStatus: 'matched',
                ),
              ),
            ],
            child: MaterialApp(
              theme: KineticTheme.darkTheme,
              home: Scaffold(
                body: KineticRecentActivityCard(
                  workouts: [session],
                  useMetricUnits: true,
                  isVi: true,
                  showMapTiles: false,
                  onSeeAllTap: () {},
                  onWorkoutTap: (_) {},
                  onStartFirstWorkoutTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(map.options.backgroundColor, KineticColors.dark.surface2);
      },
    );

    testWidgets(
      'KineticRecentActivityCard renders without overflow at 360x640 with 1.3x textScaler in vi',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const route = <LatLng>[
          LatLng(10.7755, 106.7005),
          LatLng(10.7775, 106.6992),
          LatLng(10.7794, 106.7016),
          LatLng(10.7755, 106.7005),
        ];
        final session = WorkoutSession(
          id: 'w-overflow-1',
          userId: 'u1',
          activityType: 'running',
          startedAt: DateTime(2026, 11, 18, 6, 15),
          endedAt: DateTime(2026, 11, 18, 7, 2),
          durationSec: 2820,
          movingTimeSec: 2820,
          distanceKm: 8.42,
          steps: 9800,
          avgSpeedKmh: 10.75,
          caloriesKcal: 560,
          mode: 'outdoor',
          createdAt: DateTime(2026, 11, 18, 7, 2),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutRoutePresentationProvider('w-overflow-1').overrideWith(
                (_) async => const WorkoutRoutePresentation(
                  routePoints: route,
                  routeSegments: [route],
                  source: 'filtered',
                  matchStatus: 'matched',
                ),
              ),
            ],
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: KineticRecentActivityCard(
                    workouts: [session],
                    useMetricUnits: true,
                    isVi: true,
                    showMapTiles: false,
                    onSeeAllTap: () {},
                    onWorkoutTap: (_) {},
                    onStartFirstWorkoutTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Hoạt động gần đây'), findsOneWidget);
        expect(find.text('Xem tất cả'), findsOneWidget);
      },
    );
  });
}
