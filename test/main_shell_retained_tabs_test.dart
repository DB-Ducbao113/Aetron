import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/features/shell/presentation/screens/main_shell.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Language extends AppLanguageNotifier {
  _Language() {
    state = AppLanguage.vi;
  }
}

class _Workouts extends WorkoutList {
  int refreshes = 0;

  @override
  Future<List<WorkoutSession>> build() async => [];

  @override
  Future<void> refresh() async {
    refreshes++;
    state = const AsyncData([]);
  }
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'}),
  );

  testWidgets(
    'mount only visited tabs, preserve state and refresh on activation',
    (tester) async {
      final workouts = _Workouts();
      final container = ProviderContainer(
        overrides: [
          appLanguageProvider.overrideWith((_) => _Language()),
          appConnectionProvider.overrideWith((_) => Stream.value(true)),
          metricUnitsPreferenceProvider.overrideWith((_) async => true),
          currentUserIdProvider.overrideWithValue('fixture'),
          workoutListProvider.overrideWith(() => workouts),
          recoverableInterruptedSessionProvider.overrideWith((_) async => null),
          userGoalProvider.overrideWith((_) => UserGoalNotifier(null)),
          currentAvatarDisplayProvider.overrideWithValue(
            const AvatarDisplayState(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: KineticTheme.darkTheme.copyWith(
              platform: TargetPlatform.iOS,
            ),
            home: const MainShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final home = find.byType(HomeScreen, skipOffstage: false);
      final analytics = find.byType(StatsScreen, skipOffstage: false);
      final history = find.byType(CalendarScreen, skipOffstage: false);
      expect(home, findsOneWidget);
      expect(analytics, findsNothing);
      expect(history, findsNothing);
      expect(find.byType(ActivityScreen, skipOffstage: false), findsNothing);
      expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);
      final homeState = tester.state(home);
      expect(TickerMode.valuesOf(tester.element(home)).enabled, isTrue);

      final tab = container.read(mainTabControllerProvider.notifier);
      tab.state = analyticsTabIndex;
      await tester.pumpAndSettle();
      expect(analytics, findsOneWidget);
      final analyticsState = tester.state(analytics);
      expect(tester.state(home), same(homeState));
      expect(TickerMode.valuesOf(tester.element(home)).enabled, isFalse);
      expect(TickerMode.valuesOf(tester.element(analytics)).enabled, isTrue);
      expect(workouts.refreshes, 1);

      tab.state = homeTabIndex;
      await tester.pumpAndSettle();
      expect(TickerMode.valuesOf(tester.element(analytics)).enabled, isFalse);
      expect(TickerMode.valuesOf(tester.element(home)).enabled, isTrue);
      tab.state = analyticsTabIndex;
      await tester.pumpAndSettle();
      expect(tester.state(analytics), same(analyticsState));
      expect(workouts.refreshes, 2);
      expect(history, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'five original slots retain exact center action and navigation order',
    (tester) async {
      for (final width in [375.0, 430.0]) {
        tester.view.physicalSize = Size(width * 3, 932 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <int>[];
        var selected = 0;
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(width),
            overrides: [appLanguageProvider.overrideWith((_) => _Language())],
            child: MaterialApp(
              theme: KineticTheme.buildTheme(
                Brightness.light,
                platform: TargetPlatform.iOS,
              ),
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  bottomNavigationBar: AetronBottomBar(
                    currentIndex: selected,
                    onChanged: (index) => setState(() {
                      calls.add(index);
                      selected = index;
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final items = [
          find.text('Trang chủ'),
          find.text('Lịch sử'),
          find.byIcon(CupertinoIcons.plus),
          find.text('Phân tích'),
          find.text('Hồ sơ'),
        ];
        final centers = items.map((item) => tester.getCenter(item).dx).toList();
        expect(centers, orderedEquals(centers.toList()..sort()));
        expect(centers[2], closeTo(width / 2, .01));
        for (var i = 1; i < centers.length; i++) {
          expect(
            centers[i] - centers[i - 1],
            closeTo(centers[1] - centers[0], .01),
          );
        }
        final recordSurface = find.ancestor(
          of: items[2],
          matching: find.byWidgetPredicate(
            (w) =>
                w is AnimatedContainer &&
                w.constraints?.minWidth == 44 &&
                w.constraints?.minHeight == 44,
          ),
        );
        expect(recordSurface, findsOneWidget);
        expect(tester.getSize(recordSurface), const Size(44, 44));
        for (final item in items) {
          await tester.tap(item);
          await tester.pumpAndSettle();
        }
        expect(calls, orderedEquals([0, 2, 1, 3, 4]));
        expect(tester.getSize(recordSurface), const Size(44, 44));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('high contrast dock removes backdrop blur', (tester) async {
    for (final highContrast in [false, true]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(highContrast),
          overrides: [appLanguageProvider.overrideWith((_) => _Language())],
          child: MaterialApp(
            theme: KineticTheme.darkTheme.copyWith(
              platform: TargetPlatform.iOS,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: child!,
            ),
            home: Scaffold(
              bottomNavigationBar: AetronBottomBar(
                currentIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AetronBottomBar),
          matching: find.byType(BackdropFilter),
        ),
        highContrast ? findsNothing : findsOneWidget,
      );
      expect(find.byKey(const ValueKey('glass-tab-indicator')), findsOneWidget);
    }
  });
}
