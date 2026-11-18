import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserGoalNotifier extends UserGoalNotifier {
  FakeUserGoalNotifier([UserGoal? initialGoal]) : super(null) {
    state = AsyncValue.data(initialGoal);
  }

  UserGoal? savedGoal;
  bool deleteCalled = false;

  @override
  Future<void> saveGoal(UserGoal goal) async {
    savedGoal = goal;
    state = AsyncValue.data(goal);
  }

  @override
  Future<void> deleteGoal() async {
    deleteCalled = true;
    state = const AsyncValue.data(null);
  }
}

Widget createGoalScreenTestHarness({
  FakeUserGoalNotifier? goalNotifier,
  AppLanguage language = AppLanguage.vi,
  bool useMetric = true,
  Future<bool>? metricUnitsFuture,
  ThemeData? theme,
  TextScaler? textScaler,
}) {
  final notifier = goalNotifier ?? FakeUserGoalNotifier();
  return ProviderScope(
    overrides: [
      userGoalProvider.overrideWith((ref) => notifier),
      appLanguageProvider.overrideWith((ref) => AppLanguageNotifier()..state = language),
      metricUnitsPreferenceProvider.overrideWith(
        (ref) => metricUnitsFuture ?? Future.value(useMetric),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? KineticTheme.darkTheme,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
      home: const GoalScreen(),
    ),
  );
}

void setLogicalViewport(
  WidgetTester tester,
  Size logicalSize, {
  double dpr = 2.0,
}) {
  tester.view.physicalSize = Size(
    logicalSize.width * dpr,
    logicalSize.height * dpr,
  );
  tester.view.devicePixelRatio = dpr;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kinetic GoalScreen Core UI & Structure Tests', () {
    testWidgets('renders hero header, reactor dial, and sticky CTA dock in Vietnamese', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Top bar
      expect(find.text('Mục tiêu rèn luyện'), findsOneWidget);

      // Disciplines
      expect(find.text('Cự ly'), findsOneWidget);
      expect(find.text('Buổi tập'), findsOneWidget);
      expect(find.text('Calo'), findsOneWidget);

      // Cadence tabs
      expect(find.text('Tuần'), findsOneWidget);
      expect(find.text('7 ngày'), findsOneWidget);
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('30 ngày'), findsOneWidget);

      // Sections
      expect(find.text('Ý NGHĨA & HIỆU QUẢ THỰC TẾ'), findsOneWidget);
      expect(find.text('GÓI MỤC TIÊU ĐỀ XUẤT'), findsOneWidget);

      // Sticky dock button
      expect(find.text('KÍCH HOẠT MỤC TIÊU'), findsOneWidget);
    });

    testWidgets('renders properly in English mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.en));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Top bar & disciplines
      expect(find.text('Fitness Goals'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);

      // Cadence tabs
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);

      // Sections & CTA
      expect(find.text('REAL-WORLD PERFORMANCE IMPACT'), findsOneWidget);
      expect(find.text('RECOMMENDED GOAL PRESETS'), findsOneWidget);
      expect(find.text('ACTIVATE GOAL'), findsOneWidget);
    });
  });

  group('Kinetic GoalScreen Interactivity & Selection Tests', () {
    testWidgets('switches discipline between Distance, Workouts and Calories smoothly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Switch to Workouts (Buổi tập)
      await tester.tap(find.text('Buổi tập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('buổi'), findsWidgets);

      // Switch to Calories (Calo)
      await tester.tap(find.text('Calo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('kcal'), findsWidgets);
    });

    testWidgets('switches cadence from 7-day to 30-day and updates presets', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Tap Monthly pill tab
      await tester.tap(find.text('Tháng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Check cadence selection state
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('30 ngày'), findsOneWidget);
      expect(find.text('MỤC TIÊU THÁNG'), findsOneWidget);
      expect(find.text('150'), findsWidgets);
      expect(find.textContaining('tháng'), findsWidgets);
    });

    testWidgets('preset pills immediately update target value when tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Find preset 'Bứt Phá'
      final butPhaChip = find.text('Bứt Phá');
      expect(butPhaChip, findsOneWidget);

      await tester.tap(butPhaChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Target value should update to 80 (Elite weekly preset)
      expect(find.text('80'), findsWidgets);
    });

    testWidgets('saving goal persists goal entity via notifier', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final ctaButton = find.text('KÍCH HOẠT MỤC TIÊU');
      expect(ctaButton, findsOneWidget);

      await tester.tap(ctaButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(fakeNotifier.savedGoal, isNotNull);
      expect(fakeNotifier.savedGoal!.goalType, equals(GoalType.distance));
      expect(fakeNotifier.savedGoal!.period, equals(GoalPeriod.weekly));
    });

    testWidgets('shows delete action in top bar if active goal exists and triggers confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingGoal = UserGoal(
        id: 'goal-001',
        userId: 'test-user',
        goalType: GoalType.distance,
        targetValue: 30.0,
        period: GoalPeriod.weekly,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now(),
      );

      final fakeNotifier = FakeUserGoalNotifier(existingGoal);

      await tester.pumpWidget(createGoalScreenTestHarness(goalNotifier: fakeNotifier, language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // In top bar, delete icon button should exist
      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteIcon, findsOneWidget);

      // CTA button text is 'LƯU MỤC TIÊU' when goal already exists
      expect(find.text('LƯU MỤC TIÊU'), findsOneWidget);

      // Tap delete icon to open confirmation dialog
      await tester.tap(deleteIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Hủy bỏ mục tiêu này?'), findsOneWidget);
      expect(find.text('Xóa mục tiêu'), findsOneWidget);

      // Tap delete confirmation
      await tester.tap(find.text('Xóa mục tiêu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(fakeNotifier.deleteCalled, isTrue);
    });
  });

  group('Kinetic GoalScreen Non-Dragging Tactile Controls Tests', () {
    testWidgets('contains no draggable Slider widget anywhere on screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('tactile increment and decrement step buttons adjust target without dragging', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Initial default weekly distance is 35
      expect(find.text('35'), findsWidgets);

      // Tap + increment button
      final plusButton = find.byIcon(Icons.add_rounded);
      expect(plusButton, findsOneWidget);
      await tester.tap(plusButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Value should be 37.5
      expect(find.text('37.5'), findsWidgets);

      // Tap - decrement button
      final minusButton = find.byIcon(Icons.remove_rounded);
      expect(minusButton, findsOneWidget);
      await tester.tap(minusButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Back to 35
      expect(find.text('35'), findsWidgets);
    });

    testWidgets('tapping direct input opens numeric sheet and allows entering custom value', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createGoalScreenTestHarness(language: AppLanguage.vi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final directTypeButton = find.text('Nhập số');
      expect(directTypeButton, findsOneWidget);

      await tester.tap(directTypeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('NHẬP CHÍNH XÁC MỤC TIÊU'), findsOneWidget);
      expect(find.text('ÁP DỤNG MỤC TIÊU'), findsOneWidget);

      // Enter 42 km
      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();

      await tester.tap(find.text('ÁP DỤNG MỤC TIÊU'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('42'), findsWidgets);
    });
  });

  group('Kinetic GoalScreen Light & Dark Theme Rendering Tests', () {
    for (final isDark in [false, true]) {
      for (final lang in [AppLanguage.vi, AppLanguage.en]) {
        final themeLabel = isDark ? 'Dark' : 'Light';
        final langLabel = lang == AppLanguage.vi ? 'VI' : 'EN';
        testWidgets(
          'renders cleanly in $themeLabel mode ($langLabel) at 390x844',
          (tester) async {
            setLogicalViewport(tester, const Size(390, 844));
            final theme = isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme;
            final expectedColors = isDark ? KineticColors.dark : KineticColors.light;

            await tester.pumpWidget(
              createGoalScreenTestHarness(
                language: lang,
                theme: theme,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(tester.takeException(), isNull);

            final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
            expect(scaffold.backgroundColor, equals(expectedColors.background));

            if (lang == AppLanguage.vi) {
              expect(find.text('Mục tiêu rèn luyện'), findsOneWidget);
              expect(find.text('Cự ly'), findsOneWidget);
              expect(find.text('Buổi tập'), findsOneWidget);
              expect(find.text('Calo'), findsOneWidget);
              expect(find.text('Tuần'), findsOneWidget);
              expect(find.text('Tháng'), findsOneWidget);
              expect(find.text('KÍCH HOẠT MỤC TIÊU'), findsOneWidget);
            } else {
              expect(find.text('Fitness Goals'), findsOneWidget);
              expect(find.text('Distance'), findsOneWidget);
              expect(find.text('Sessions'), findsOneWidget);
              expect(find.text('Calories'), findsOneWidget);
              expect(find.text('Weekly'), findsOneWidget);
              expect(find.text('Monthly'), findsOneWidget);
              expect(find.text('ACTIVATE GOAL'), findsOneWidget);
            }
          },
        );
      }
    }
  });

  group('Kinetic GoalScreen Responsive 360px & 390px Overflow Matrix Tests', () {
    final now = DateTime(2026, 11, 18);

    for (final viewport in [const Size(360, 640), const Size(390, 844)]) {
      for (final isDark in [false, true]) {
        for (final lang in [AppLanguage.vi, AppLanguage.en]) {
          for (final goalType in GoalType.values) {
            for (final period in GoalPeriod.values) {
              final targetValue = switch ((goalType, period)) {
                (GoalType.distance, GoalPeriod.weekly) => 35.0,
                (GoalType.distance, GoalPeriod.monthly) => 150.0,
                (GoalType.workouts, GoalPeriod.weekly) => 4.0,
                (GoalType.workouts, GoalPeriod.monthly) => 45.0,
                (GoalType.calories, GoalPeriod.weekly) => 3500.0,
                (GoalType.calories, GoalPeriod.monthly) => 60000.0,
              };

              testWidgets(
                'no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()} '
                '${isDark ? "Dark" : "Light"} ${lang.name} ${goalType.name}/${period.name}',
                (tester) async {
                  setLogicalViewport(tester, viewport);
                  final seededGoal = UserGoal(
                    id: 'matrix-${goalType.name}-${period.name}',
                    userId: 'test-user',
                    goalType: goalType,
                    targetValue: targetValue,
                    period: period,
                    createdAt: now,
                    updatedAt: now,
                  );

                  await tester.pumpWidget(
                    createGoalScreenTestHarness(
                      goalNotifier: FakeUserGoalNotifier(seededGoal),
                      language: lang,
                      theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
                    ),
                  );
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 150));

                  expect(tester.takeException(), isNull);
                },
              );
            }
          }
        }
      }
    }

    for (final viewport in [const Size(360, 640), const Size(390, 844)]) {
      for (final isDark in [false, true]) {
        for (final lang in [AppLanguage.vi, AppLanguage.en]) {
          testWidgets(
            '60,000 KCAL max monthly calories does not overflow at '
            '${viewport.width.toInt()}x${viewport.height.toInt()} '
            '${isDark ? "Dark" : "Light"} (${lang.name}) with 1.3x textScaler',
            (tester) async {
              setLogicalViewport(tester, viewport);
              final maxCalGoal = UserGoal(
                id: 'max-kcal',
                userId: 'test-user',
                goalType: GoalType.calories,
                targetValue: 60000.0,
                period: GoalPeriod.monthly,
                createdAt: now,
                updatedAt: now,
              );

              await tester.pumpWidget(
                createGoalScreenTestHarness(
                  goalNotifier: FakeUserGoalNotifier(maxCalGoal),
                  language: lang,
                  theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
                  textScaler: const TextScaler.linear(1.3),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 150));

              expect(find.text('60,000'), findsWidgets);
              expect(find.text('KCAL'), findsWidgets);
              expect(tester.takeException(), isNull);

              // Also verify direct editor sheet and delete confirmation dialog fit cleanly
              await tester.tap(find.text(lang == AppLanguage.vi ? 'Nhập số' : 'Enter value'));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 150));
              expect(tester.takeException(), isNull);

              await tester.tap(
                find.text(lang == AppLanguage.vi ? 'ÁP DỤNG MỤC TIÊU' : 'APPLY TARGET'),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 150));
              expect(tester.takeException(), isNull);

              await tester.tap(find.byIcon(Icons.delete_outline_rounded));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 150));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('Kinetic GoalScreen Segmented Control & Cadence Pill Selection Tests', () {
    for (final isDark in [false, true]) {
      final expectedActiveFill =
          isDark ? KineticColors.dark.surface3 : KineticColors.light.surface1;
      for (final lang in [AppLanguage.vi, AppLanguage.en]) {
        final isVi = lang == AppLanguage.vi;
        testWidgets(
          'segmented control and cadence pill taps update selection state '
          '(${isDark ? "Dark" : "Light"}, ${lang.name})',
          (tester) async {
            setLogicalViewport(tester, const Size(390, 844));
            final fakeNotifier = FakeUserGoalNotifier();

            await tester.pumpWidget(
              createGoalScreenTestHarness(
                goalNotifier: fakeNotifier,
                language: lang,
                theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            AnimatedContainer segmentContainerFor(String label) {
              return tester.widget<AnimatedContainer>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedContainer),
                ).first,
              );
            }

            final distLabel = isVi ? 'Cự ly' : 'Distance';
            final sessionsLabel = isVi ? 'Buổi tập' : 'Sessions';
            final caloriesLabel = isVi ? 'Calo' : 'Calories';
            final weeklyLabel = isVi ? 'Tuần' : 'Weekly';
            final monthlyLabel = isVi ? 'Tháng' : 'Monthly';

            // Initial state: Distance + Weekly selected
            expect(
              (segmentContainerFor(distLabel).decoration as BoxDecoration).color,
              equals(expectedActiveFill),
            );
            expect(
              (segmentContainerFor(sessionsLabel).decoration as BoxDecoration).color,
              equals(Colors.transparent),
            );
            expect(
              (segmentContainerFor(weeklyLabel).decoration as BoxDecoration).color,
              equals(expectedActiveFill),
            );
            expect(
              (segmentContainerFor(monthlyLabel).decoration as BoxDecoration).color,
              equals(Colors.transparent),
            );

            // Tap Sessions segment
            await tester.tap(find.text(sessionsLabel));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(
              (segmentContainerFor(sessionsLabel).decoration as BoxDecoration).color,
              equals(expectedActiveFill),
            );
            expect(
              (segmentContainerFor(distLabel).decoration as BoxDecoration).color,
              equals(Colors.transparent),
            );
            expect(find.text('4'), findsWidgets);
            expect(find.text(isVi ? 'BUỔI' : 'SESSIONS'), findsWidgets);
            expect(
              find.text(isVi ? 'Buổi tập • tuần' : 'Sessions • wk'),
              findsOneWidget,
            );

            // Tap Calories segment
            await tester.tap(find.text(caloriesLabel));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(
              (segmentContainerFor(caloriesLabel).decoration as BoxDecoration).color,
              equals(expectedActiveFill),
            );
            expect(find.text('3,500'), findsWidgets);
            expect(
              find.text(isVi ? 'Calo • tuần' : 'Calories • wk'),
              findsOneWidget,
            );

            // Tap Monthly cadence pill
            await tester.tap(find.text(monthlyLabel));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(
              (segmentContainerFor(monthlyLabel).decoration as BoxDecoration).color,
              equals(expectedActiveFill),
            );
            expect(
              (segmentContainerFor(weeklyLabel).decoration as BoxDecoration).color,
              equals(Colors.transparent),
            );
            expect(find.text('15,000'), findsWidgets);
            expect(
              find.text(isVi ? 'MỤC TIÊU THÁNG' : 'MONTHLY TARGET'),
              findsOneWidget,
            );
            expect(
              find.text(isVi ? 'Calo • tháng' : 'Calories • mo'),
              findsOneWidget,
            );

            // Persist and verify saved GoalType & GoalPeriod
            await tester.tap(
              find.text(isVi ? 'KÍCH HOẠT MỤC TIÊU' : 'ACTIVATE GOAL'),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));

            expect(fakeNotifier.savedGoal, isNotNull);
            expect(fakeNotifier.savedGoal!.goalType, equals(GoalType.calories));
            expect(fakeNotifier.savedGoal!.period, equals(GoalPeriod.monthly));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Kinetic GoalScreen Remediation & Edge Case Tests', () {
    final now = DateTime(2026, 11, 18);

    for (final viewport in [const Size(320, 568), const Size(360, 640)]) {
      for (final scale in [1.5, 2.0]) {
        for (final isDark in [false, true]) {
          for (final lang in [AppLanguage.vi, AppLanguage.en]) {
            final isVi = lang == AppLanguage.vi;
            testWidgets(
              'no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()} '
              'textScaler=${scale}x ${isDark ? "Dark" : "Light"} ${lang.name}',
              (tester) async {
                setLogicalViewport(tester, viewport);
                final seededGoal = UserGoal(
                  id: 'remediation-${viewport.width.toInt()}-$scale',
                  userId: 'test-user',
                  goalType: GoalType.calories,
                  targetValue: 60000.0,
                  period: GoalPeriod.monthly,
                  createdAt: now,
                  updatedAt: now,
                );

                await tester.pumpWidget(
                  createGoalScreenTestHarness(
                    goalNotifier: FakeUserGoalNotifier(seededGoal),
                    language: lang,
                    theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
                    textScaler: TextScaler.linear(scale),
                  ),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 150));

                expect(tester.takeException(), isNull);

                final targetHeaderFinder = find.text(
                  isVi ? 'MỤC TIÊU THÁNG' : 'MONTHLY TARGET',
                );
                final enterValueFinder = find.text(
                  isVi ? 'Nhập số' : 'Enter value',
                );
                expect(targetHeaderFinder, findsOneWidget);
                expect(enterValueFinder, findsOneWidget);
                expect(tester.getSize(targetHeaderFinder).width, greaterThan(0));
                expect(tester.getSize(enterValueFinder).width, greaterThan(0));
              },
            );
          }
        }
      }
    }

    testWidgets('renders Imperial (useMetric: false) units and defaults accurately', (tester) async {
      setLogicalViewport(tester, const Size(390, 844));
      final fakeNotifier = FakeUserGoalNotifier();

      await tester.pumpWidget(
        createGoalScreenTestHarness(
          goalNotifier: fakeNotifier,
          language: AppLanguage.en,
          useMetric: false,
          theme: KineticTheme.lightTheme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);
      expect(find.text('MI'), findsWidgets);
      expect(find.text('mi'), findsWidgets);
      expect(find.text('22'), findsWidgets);

      await tester.tap(find.text('ACTIVATE GOAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(fakeNotifier.savedGoal, isNotNull);
      expect(fakeNotifier.savedGoal!.goalType, equals(GoalType.distance));
      // 22 mi / 0.621371 ~= 35.4 km
      expect(fakeNotifier.savedGoal!.targetValue, closeTo(35.4, 0.2));
    });

    testWidgets(
      'async metricUnitsPreferenceProvider resolving to false (MI) converts existing 50 km goal and saves ~50 km',
      (tester) async {
        setLogicalViewport(tester, const Size(390, 844));
        final completer = Completer<bool>();
        final existingGoal = UserGoal(
          id: 'goal-async-mi',
          userId: 'test-user',
          goalType: GoalType.distance,
          targetValue: 50.0,
          period: GoalPeriod.weekly,
          createdAt: now,
          updatedAt: now,
        );
        final fakeNotifier = FakeUserGoalNotifier(existingGoal);

        await tester.pumpWidget(
          createGoalScreenTestHarness(
            goalNotifier: fakeNotifier,
            language: AppLanguage.en,
            metricUnitsFuture: completer.future,
            theme: KineticTheme.darkTheme,
          ),
        );
        await tester.pump();

        // Before preference resolves, displays metric 50 KM
        expect(find.text('50'), findsWidgets);
        expect(find.text('KM'), findsWidgets);

        // Resolve preference to Imperial (false -> MI)
        completer.complete(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(tester.takeException(), isNull);
        expect(find.text('MI'), findsWidgets);
        expect(find.text('mi'), findsWidgets);
        // 50.0 km * 0.6213711922 = 31.068... -> '31.1'
        expect(find.text('31.1'), findsWidgets);

        await tester.tap(find.text('UPDATE GOAL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(fakeNotifier.savedGoal, isNotNull);
        expect(fakeNotifier.savedGoal!.targetValue, closeTo(50.0, 0.05));
      },
    );

    testWidgets(
      'async metricUnitsPreferenceProvider resolving to false after user edits converts edited km to mi',
      (tester) async {
        setLogicalViewport(tester, const Size(390, 844));
        final completer = Completer<bool>();
        final existingGoal = UserGoal(
          id: 'goal-async-edited-mi',
          userId: 'test-user',
          goalType: GoalType.distance,
          targetValue: 50.0,
          period: GoalPeriod.weekly,
          createdAt: now,
          updatedAt: now,
        );
        final fakeNotifier = FakeUserGoalNotifier(existingGoal);

        await tester.pumpWidget(
          createGoalScreenTestHarness(
            goalNotifier: fakeNotifier,
            language: AppLanguage.en,
            metricUnitsFuture: completer.future,
          ),
        );
        await tester.pump();

        // User increments from 50 -> 52.5 while still loading metric
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
        expect(find.text('52.5'), findsWidgets);

        // Preference resolves to Imperial
        completer.complete(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // 52.5 km -> 32.6 mi
        expect(find.text('32.6'), findsWidgets);
        expect(find.text('MI'), findsWidgets);

        await tester.tap(find.text('UPDATE GOAL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(fakeNotifier.savedGoal, isNotNull);
        expect(fakeNotifier.savedGoal!.targetValue, closeTo(52.5, 0.05));
      },
    );

    testWidgets('re-tapping active discipline or cadence preserves adjusted target value', (tester) async {
      setLogicalViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        createGoalScreenTestHarness(
          language: AppLanguage.vi,
          theme: KineticTheme.lightTheme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Adjust weekly distance from 35 -> 37.5
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('37.5'), findsWidgets);

      // Re-tap active Distance segment and active Weekly cadence pill
      await tester.tap(find.text('Cự ly'));
      await tester.pump();
      expect(find.text('37.5'), findsWidgets);

      await tester.tap(find.text('Tuần'));
      await tester.pump();
      expect(find.text('37.5'), findsWidgets);

      // Tapping a different cadence (Monthly) resets to Monthly default (150)
      await tester.tap(find.text('Tháng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('150'), findsWidgets);

      // Adjust monthly distance 150 -> 152.5, then re-tap Monthly -> preserved
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('152.5'), findsWidgets);

      await tester.tap(find.text('Tháng'));
      await tester.pump();
      expect(find.text('152.5'), findsWidgets);
    });

    testWidgets(
      'direct editor accepts comma-formatted input, formats calorie presets with commas, and disposes controller cleanly',
      (tester) async {
        setLogicalViewport(tester, const Size(390, 844));
        await tester.pumpWidget(
          createGoalScreenTestHarness(
            language: AppLanguage.vi,
            theme: KineticTheme.lightTheme,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        await tester.tap(find.text('Calo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        await tester.tap(find.text('Tháng'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // Preset cards use comma formatting for calories
        expect(find.text('48,000 kcal'), findsOneWidget);

        // Open direct editor and enter comma-formatted number
        await tester.tap(find.text('Nhập số'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.enterText(find.byType(TextField), '25,000');
        await tester.pump();

        await tester.tap(find.text('ÁP DỤNG MỤC TIÊU'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('25,000'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cadence pills meet 44px minimum touch target and Light-mode Calories icons use high-contrast amber',
      (tester) async {
        setLogicalViewport(tester, const Size(390, 844));
        await tester.pumpWidget(
          createGoalScreenTestHarness(
            language: AppLanguage.en,
            theme: KineticTheme.lightTheme,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final weeklyInkWell = find
            .ancestor(
              of: find.text('Weekly'),
              matching: find.byType(InkWell),
            )
            .first;
        expect(
          tester.getSize(weeklyInkWell).height,
          greaterThanOrEqualTo(KineticTokens.minTouchTarget),
        );

        await tester.tap(find.text('Calories'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final addIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
        expect(addIcon.color, equals(const Color(0xFFB45309)));
      },
    );

    for (final viewport in [const Size(320, 568), const Size(360, 640)]) {
      testWidgets(
        'WEEKLY TARGET header and Enter value do not overflow at '
        '${viewport.width.toInt()}x${viewport.height.toInt()} textScaler=2.0x EN (no existing goal)',
        (tester) async {
          setLogicalViewport(tester, viewport);
          await tester.pumpWidget(
            createGoalScreenTestHarness(
              language: AppLanguage.en,
              theme: KineticTheme.lightTheme,
              textScaler: const TextScaler.linear(2.0),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.text('WEEKLY TARGET')).width, greaterThan(0));
          expect(tester.getSize(find.text('Enter value')).width, greaterThan(0));
        },
      );
    }
  });
}
