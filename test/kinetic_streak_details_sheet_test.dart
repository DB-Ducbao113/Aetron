import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/home/presentation/widgets/kinetic_streak_details_sheet.dart';
import 'package:fitness_exercise_application/features/shell/presentation/providers/main_tab_controller_provider.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_card.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestViLanguageNotifier extends AppLanguageNotifier {
  _TestViLanguageNotifier() : super() {
    state = AppLanguage.vi;
  }
}

void main() {
  group('KineticStreakDetailsSheet Tests', () {
    testWidgets('renders cleanly in dark mode with core metrics and CTA', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const streakData = StreakData(currentStreak: 5, longestStreak: 12);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const KineticStreakDetailsSheet(streak: streakData),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify streak count and hero label
      expect(
        find.descendant(
          of: find.byType(KineticCard).first,
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(find.text('NGÀY LIÊN TIẾP'), findsOneWidget);

      // Verify week strip labels
      expect(find.text('TUẦN NÀY'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);

      // Verify core metrics: Best streak & Next target
      expect(find.text('KỶ LỤC TỐT NHẤT'), findsOneWidget);
      expect(find.text('12 Ngày'), findsOneWidget);
      expect(find.text('MỐC TIẾP THEO'), findsOneWidget);
      expect(
        find.text('7 Ngày'),
        findsOneWidget,
      ); // calculateNextStreakTarget(5) is 7

      // Verify single primary CTA exists
      expect(find.byType(KineticButton), findsOneWidget);
      expect(find.text('BẮT ĐẦU TẬP ĐỂ GIỮ CHUỖI 🔥'), findsOneWidget);
    });

    testWidgets('renders seamlessly in light mode with adaptive tokens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const streakData = StreakData(currentStreak: 15, longestStreak: 15);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: MaterialApp(
            theme: KineticTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const KineticStreakDetailsSheet(streak: streakData),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal sheet in light mode
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify 15 days streak counter via hero fontSize (metricMega)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == '15' &&
              widget.style?.fontSize == KineticTypography.metricMega.fontSize,
        ),
        findsOneWidget,
      );
      expect(find.text('NGÀY LIÊN TIẾP'), findsOneWidget);

      // Verify tier title rendered
      expect(find.text('CHIẾN BINH TITAN'), findsOneWidget);

      // Next target for 15 is 30
      expect(find.text('30 Ngày'), findsOneWidget);
      expect(find.text('Còn 15 ngày'), findsOneWidget);
    });

    testWidgets('CTA closes the sheet and selects Activity in the shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const streakData = StreakData(currentStreak: 3, longestStreak: 5);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const KineticStreakDetailsSheet(streak: streakData),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap CTA
      await tester.tap(find.byType(KineticButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(mainTabControllerProvider), activityTabIndex);
      expect(find.text('Open Sheet'), findsOneWidget);
    });
  });
}
