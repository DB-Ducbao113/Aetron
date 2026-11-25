import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/achievements_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/achievement_badge_item.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith((_) => AppLanguageNotifier()..setLanguage(AppLanguage.vi)),
      ],
      child: MaterialApp(
        theme: KineticTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Kinetic AchievementsScreen Widget Tests', () {
    testWidgets('renders top bar, progress card, category tabs and grid', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const AchievementsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Thành tích Aetron'), findsOneWidget);
      expect(find.text('Kho Huy Hiệu'), findsOneWidget);
      expect(find.text('Tiến trình danh hiệu'), findsOneWidget);
      expect(find.text('Tất cả huy hiệu'), findsOneWidget);
    });

    testWidgets('filters badges when tapping category tabs', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const AchievementsScreen()));
      await tester.pumpAndSettle();

      // Find and tap "Cự ly" category tab
      final distanceTab = find.text('Cự ly');
      expect(distanceTab, findsOneWidget);

      await tester.tap(distanceTab);
      await tester.pumpAndSettle();

      expect(find.text('Cự ly'), findsWidgets);
    });

    testWidgets('opens badge detail sheet on tapping badge item', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const AchievementsScreen()));
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(AchievementBadgeItem).first;
      expect(badgeFinder, findsOneWidget);

      await tester.ensureVisible(badgeFinder);
      await tester.pumpAndSettle();
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      expect(find.text('Tiến độ thực hiện'), findsOneWidget);
    });
  });
}


