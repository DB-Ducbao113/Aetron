import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/personal_records_trophy_wall.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/achievements_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_badge_item.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_detail_sheet.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Language extends AppLanguageNotifier {
  _Language() {
    state = AppLanguage.vi;
  }
}

class _Workouts extends WorkoutList {
  @override
  Future<List<WorkoutSession>> build() async => [
    for (final (id, type, distance, speed) in [
      ('run', 'running', 8.0, 10.0),
      ('bike', 'cycling', 16.0, 22.0),
      ('walk', 'walking', 3.0, 5.0),
    ])
      WorkoutSession(
        id: id,
        userId: 'fixture',
        activityType: type,
        startedAt: DateTime(2025, 1, 1, 12),
        endedAt: DateTime(2025, 1, 1, 13),
        createdAt: DateTime(2025, 1, 1, 13),
        durationSec: 3600,
        movingTimeSec: 3600,
        distanceKm: distance,
        steps: 0,
        avgSpeedKmh: speed,
        caloriesKcal: 200,
        mode: 'outdoor',
        gpsAnalysis: WorkoutGpsAnalysis(
          validDistanceKm: distance,
          validityFlag: WorkoutValidityFlag.verified,
        ),
      ),
  ];
}

Widget _app(Widget child, {bool reduceMotion = false}) => ProviderScope(
  overrides: [
    appLanguageProvider.overrideWith((_) => _Language()),
    workoutListProvider.overrideWith(_Workouts.new),
    streakProvider.overrideWithValue(
      const StreakData(currentStreak: 2, longestStreak: 3),
    ),
    metricUnitsPreferenceProvider.overrideWith((_) async => true),
  ],
  child: MaterialApp(
    theme: KineticTheme.darkTheme.copyWith(platform: TargetPlatform.iOS),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: child,
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _badge(String id) => find.byWidgetPredicate(
  (w) => w is AchievementBadgeItem && w.badge.id == id,
);

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'}),
  );

  testWidgets(
    'distance filter exposes exact badges and selected details can close',
    (tester) async {
      await tester.pumpWidget(_app(const AchievementsScreen()));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Cự ly'));
      expect(
        tester
            .widgetList<AchievementBadgeItem>(find.byType(AchievementBadgeItem))
            .map((w) => w.badge.id),
        unorderedEquals([
          'distance_25k',
          '10k_breakthrough',
          'century_100k',
          'half_marathon_21k',
          'quantum_500k',
        ]),
      );
      final sheet = find.byType(AchievementDetailSheet);
      await _tap(tester, _badge('distance_25k'));
      expect(
        tester.widget<AchievementDetailSheet>(sheet).badge.id,
        'distance_25k',
      );
      expect(
        find.descendant(of: sheet, matching: find.text('100% HOÀN THÀNH')),
        findsOneWidget,
      );
      await _tap(
        tester,
        find.descendant(of: sheet, matching: find.text('ĐÓNG')),
      );
      expect(sheet, findsNothing);
      await _tap(tester, _badge('century_100k'));
      expect(
        tester.widget<AchievementDetailSheet>(sheet).badge.id,
        'century_100k',
      );
      expect(
        find.descendant(of: sheet, matching: find.text('27%')),
        findsOneWidget,
      );
      await _tap(
        tester,
        find.descendant(of: sheet, matching: find.text('ĐÓNG')),
      );
      expect(sheet, findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 650));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Tất cả'));
      expect(_badge('first_signal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'records isolate running, cycling and walking and return to badges',
    (tester) async {
      await tester.pumpWidget(_app(const AchievementsScreen()));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Kỷ lục'));
      final wall = find.byType(PersonalRecordsTrophyWall);
      for (final (label, activity, distance) in [
        ('Chạy bộ', 'running', 8.0),
        ('Đạp xe', 'cycling', 16.0),
        ('Đi bộ', 'walking', 3.0),
      ]) {
        await _tap(tester, find.text(label));
        final widget = tester.widget<PersonalRecordsTrophyWall>(wall);
        expect(widget.activityType, activity);
        expect(widget.records.longestDistance.numericValue, distance);
        expect(find.byType(AchievementBadgeItem), findsNothing);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, 650));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Huy hiệu'));
      expect(wall, findsNothing);
      expect(_badge('first_signal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'badge press has a real intermediate frame and modal respects Reduce Motion: $reduced',
      (tester) async {
        await tester.pumpWidget(
          _app(const AchievementsScreen(), reduceMotion: reduced),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Cự ly'));
        final badge = _badge('distance_25k');
        await tester.ensureVisible(badge);
        await tester.pumpAndSettle();
        final scale = find.descendant(
          of: badge,
          matching: find.byType(ScaleTransition),
        );
        final gesture = await tester.startGesture(tester.getCenter(badge));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 60));
        final intermediate = tester.widget<ScaleTransition>(scale).scale.value;
        if (reduced) {
          expect(intermediate, 1);
        } else {
          expect(intermediate, lessThan(1));
          expect(intermediate, greaterThanOrEqualTo(.95));
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
        expect(find.byType(AchievementDetailSheet), findsNothing);
        await tester.tap(badge);
        await tester.pumpAndSettle();
        final sheet = find.byType(AchievementDetailSheet);
        expect(sheet, findsOneWidget);
        final route = ModalRoute.of(tester.element(sheet))!;
        if (reduced) {
          expect(route.transitionDuration, Duration.zero);
          expect(route.reverseTransitionDuration, Duration.zero);
        } else {
          expect(route.transitionDuration, greaterThan(Duration.zero));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('glass indicator moves correctly (Reduce Motion: $reduced)', (
      tester,
    ) async {
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: AetronBottomBar(
                currentIndex: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
          reduceMotion: reduced,
        ),
      );
      await tester.pumpAndSettle();
      final indicator = find.byKey(const ValueKey('glass-tab-indicator'));
      final start = tester.getCenter(indicator).dx;
      final target = tester.getCenter(find.text('Phân tích')).dx;
      await tester.tap(find.text('Phân tích'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = tester.getCenter(indicator).dx;
      if (reduced) {
        expect(intermediate, closeTo(target, 1));
      } else {
        expect(intermediate, greaterThan(start));
        expect(intermediate, lessThan(target));
      }
      await tester.pumpAndSettle();
      expect(selected, 3);
      expect(tester.getCenter(indicator).dx, closeTo(target, 1));
      expect(tester.takeException(), isNull);
    });
  }
}
