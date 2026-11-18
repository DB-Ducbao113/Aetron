import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_skeleton.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Grey Shimmer Skeleton Views Tests', () {
    testWidgets('HomeSkeletonView renders AetronShimmer and skeleton boxes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: HomeSkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsWidgets);
    });

    testWidgets('CalendarSkeletonView renders AetronShimmer and scrollable skeleton cards',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: CalendarSkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('AnalyticsSkeletonView renders AetronShimmer and telemetry skeletons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: AnalyticsSkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('ProfileSkeletonView renders athlete and biometrics skeletons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: ProfileSkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('ActivitySkeletonView renders 3 activity cards skeletons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: ActivitySkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsNWidgets(3));
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('SettingsSkeletonView renders grouped settings skeletons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(body: SettingsSkeletonView()),
        ),
      );

      expect(find.byType(AetronShimmer), findsOneWidget);
      expect(find.byType(AetronSkeletonBox), findsWidgets);
      expect(find.byType(AetronSkeletonCard), findsNWidgets(3));
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('CalendarScreen integrates RefreshIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConnectionProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const CalendarScreen(),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('StatsScreen integrates RefreshIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConnectionProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const StatsScreen(),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('ActivityScreen renders map-first start experience cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConnectionProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const ActivityScreen(showMapTiles: false),
          ),
        ),
      );

      expect(find.byType(TrackingMapWidget), findsOneWidget);
      expect(find.byKey(const Key('activity-top-sport-pill')), findsOneWidget);
      expect(find.byKey(const Key('activity-gps-pill')), findsOneWidget);
      expect(find.byKey(const Key('sport-pill-cycling')), findsOneWidget);
    });
  });
}
