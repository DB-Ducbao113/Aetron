import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_offline_banner.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTranslations Comprehensive Bilingual Audit', () {
    test('password_mismatch and mandatory_password_upgrade_title exist and differ by language', () {
      final viMismatch = AppTranslations.get('password_mismatch', AppLanguage.vi);
      final enMismatch = AppTranslations.get('password_mismatch', AppLanguage.en);
      expect(viMismatch, 'Mật khẩu xác nhận không khớp');
      expect(enMismatch, 'Passwords do not match');

      final viMandatory = AppTranslations.get('mandatory_password_upgrade_title', AppLanguage.vi);
      final enMandatory = AppTranslations.get('mandatory_password_upgrade_title', AppLanguage.en);
      expect(viMandatory, 'Yêu cầu nâng cấp mật khẩu');
      expect(enMandatory, 'Mandatory password upgrade');

      final viNoUser = AppTranslations.get('password_cannot_contain_username', AppLanguage.vi);
      final enNoUser = AppTranslations.get('password_cannot_contain_username', AppLanguage.en);
      expect(viNoUser, 'Mật khẩu không được trùng hoặc chứa tên đăng nhập');
      expect(enNoUser, 'Password cannot match or contain your username');
    });

    test('All core navigation keys have distinct bilingual versions', () {
      for (final key in ['nav_home', 'nav_activity', 'nav_history', 'nav_analytics', 'nav_profile']) {
        final vi = AppTranslations.get(key, AppLanguage.vi);
        final en = AppTranslations.get(key, AppLanguage.en);
        expect(vi.isNotEmpty, isTrue);
        expect(en.isNotEmpty, isTrue);
        expect(vi, isNot(equals(en)));
      }
    });

    test('WorkoutFormatters formats sport activities into both languages accurately', () {
      expect(WorkoutFormatters.formatActivityType('running', AppLanguage.vi), 'Chạy bộ');
      expect(WorkoutFormatters.formatActivityType('running', AppLanguage.en), 'Running');

      expect(WorkoutFormatters.formatActivityType('cycling', AppLanguage.vi), 'Đạp xe');
      expect(WorkoutFormatters.formatActivityType('cycling', AppLanguage.en), 'Cycling');

      expect(WorkoutFormatters.formatActivityType('walking', AppLanguage.vi), 'Đi bộ');
      expect(WorkoutFormatters.formatActivityType('walking', AppLanguage.en), 'Walking');
    });

    testWidgets('KineticOfflineBanner renders accurately in both languages', (tester) async {
      // Test Vietnamese
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const Scaffold(
              body: KineticOfflineBanner(language: AppLanguage.vi),
            ),
          ),
        ),
      );
      expect(find.text('Chế độ ngoại tuyến — Hiển thị dữ liệu đã lưu'), findsOneWidget);

      // Test English
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: const Scaffold(
              body: KineticOfflineBanner(language: AppLanguage.en),
            ),
          ),
        ),
      );
      expect(find.text('Offline mode — Showing saved data'), findsOneWidget);
    });
  });
}
