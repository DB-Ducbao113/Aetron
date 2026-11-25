import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestViLanguageNotifier extends AppLanguageNotifier {
  _TestViLanguageNotifier() : super() {
    state = AppLanguage.vi;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'});
  });

  group('ProfileSetupScreen Streamline Tests', () {
    testWidgets('Edit Profile renders single clean title + subtitle without duplicate headings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final existingProfile = UserProfile(
        id: 'user_123',
        userId: 'user_123',
        weightKg: 70.0,
        heightCm: 175.0,
        legacyAge: 26,
        gender: 'male',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: MaterialApp(
            theme: KineticTheme.darkTheme,
            home: ProfileSetupScreen(existingProfile: existingProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Unified Top Bar title & subtitle
      expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
      expect(find.text('Cập nhật chỉ số sinh trắc học'), findsOneWidget);

      // Verified: 4 redundant lines are no longer present
      expect(find.text('CẬP NHẬT SINH TRẮC'), findsNothing);
      expect(find.text('DỮ LIỆU SINH TRẮC'), findsNothing);
      expect(find.text('Cập nhật chỉ số sức khỏe của bạn'), findsNothing);

      // Verified: Unit selector rendered
      expect(find.text('Đơn vị đo ưa thích'), findsOneWidget);
      expect(find.text('Hệ mét'), findsOneWidget);
      expect(find.text('Hệ Anh'), findsOneWidget);
    });

    testWidgets('Initial Profile Setup renders clean title + subtitle without duplicate headings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
          ],
          child: const MaterialApp(
            home: ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Clean initial setup title & subtitle
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.text('Thiết lập chỉ số sinh trắc học'), findsOneWidget);

      // Verified: Old duplicated lines are gone
      expect(find.text('KHỞI TẠO CHỈ SỐ'), findsNothing);
      expect(find.text('DỮ LIỆU SINH TRẮC'), findsNothing);
      expect(find.text('Thiết lập chỉ số ban đầu cho ứng dụng'), findsNothing);
    });
  });
}
