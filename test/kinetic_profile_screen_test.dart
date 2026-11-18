import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/edit_display_name_sheet.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_athlete_card.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_avatar_source_sheet.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_biometrics_bento.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_profile_action_tile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/widgets/kinetic_profile_top_bar.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Widget buildTestable(
    Widget child, {
    ThemeData? theme,
    AppLanguage language = AppLanguage.vi,
  }) {
    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          (ref) => AppLanguageNotifier()..state = language,
        ),
        currentAvatarDisplayProvider.overrideWithValue(
          const AvatarDisplayState(),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? KineticTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  final mockProfile = UserProfile(
    id: 'profile-123',
    userId: 'test-user-123',
    weightKg: 70.0,
    heightCm: 175.0,
    legacyAge: 28,
    gender: 'male',
    avatarUrl: 'https://example.com/avatar.jpg',
    createdAt: DateTime(2023, 5, 15),
    updatedAt: DateTime(2023, 5, 15),
  );

  group('KineticProfileTopBar Widget Tests', () {
    testWidgets('renders title without AETRON eyebrow, and settings button', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticProfileTopBar(
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('AETRON'), findsNothing);
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(
        find.byIcon(BladeIcon.iconDataFor(BladeIconName.gear)),
        findsOneWidget,
      );
    });

    testWidgets('renders English localization correctly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticProfileTopBar(
            currentLang: AppLanguage.en,
          ),
        ),
      );

      expect(find.text('AETRON'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('KineticAthleteCard Widget Tests', () {
    testWidgets('renders streak, no athlete badge, and invokes camera callback', (tester) async {
      bool cameraTapped = false;

      final testUser = User(
        id: 'test-user-123',
        appMetadata: const {},
        userMetadata: const {
          'display_name': 'Duc Bao Runner',
          'username': 'ducbaorun',
        },
        aud: 'authenticated',
        email: 'ducbao@example.com',
        createdAt: '2023-05-15T00:00:00Z',
      );

      await tester.pumpWidget(
        buildTestable(
          KineticAthleteCard(
            user: testUser,
            profile: mockProfile,
            avatarState: const AvatarState(),
            currentStreak: 12,
            currentLang: AppLanguage.vi,
            onCameraTap: () => cameraTapped = true,
          ),
        ),
      );

      expect(find.text('Duc Bao Runner'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('NGÀY LIÊN TIẾP'), findsOneWidget);
      // Verify VẬN ĐỘNG VIÊN badge is removed
      expect(find.text('VẬN ĐỘNG VIÊN'), findsNothing);
      expect(find.textContaining('05/2023'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump();
      expect(cameraTapped, isTrue);
    });
  });

  group('KineticBiometricsBento Widget Tests', () {
    testWidgets('renders metric units and BMI correctly', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticBiometricsBento(
            profile: mockProfile,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
            onEdit: () => editTapped = true,
          ),
        ),
      );

      expect(find.text('DỮ LIỆU SINH TRẮC'), findsOneWidget);
      expect(find.text('70.0 kg'), findsOneWidget);
      expect(find.text('1.75 m'), findsOneWidget);
      expect(find.text('28 • Nam'), findsOneWidget);
      expect(find.text('22.9 (Chuẩn)'), findsOneWidget);

      // Tap Edit
      await tester.tap(find.text('Chỉnh sửa'));
      await tester.pump();
      expect(editTapped, isTrue);
    });

    testWidgets('renders imperial conversions correctly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticBiometricsBento(
            profile: mockProfile,
            useMetricUnits: false,
            currentLang: AppLanguage.en,
            onEdit: () {},
          ),
        ),
      );

      expect(find.text('BIOMETRIC DATA'), findsOneWidget);
      expect(find.text('154.3 lb'), findsOneWidget);
      expect(find.text('5\'9"'), findsOneWidget);
      expect(find.text('28 • Male'), findsOneWidget);
      expect(find.text('22.9 (Normal)'), findsOneWidget);
    });
  });

  group('KineticProfileActionTile Widget Tests', () {
    testWidgets('renders title, badge and responds to tap', (tester) async {
      bool tileTapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticProfileActionTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.cyan,
            label: 'Bảo mật tài khoản',
            subtitle: 'Mật khẩu & Đăng nhập',
            badgeText: 'Đã xác thực',
            onTap: () => tileTapped = true,
          ),
        ),
      );

      expect(find.text('Bảo mật tài khoản'), findsOneWidget);
      expect(find.text('Mật khẩu & Đăng nhập'), findsOneWidget);
      expect(find.text('Đã xác thực'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      await tester.tap(find.text('Bảo mật tài khoản'));
      await tester.pump();
      expect(tileTapped, isTrue);
    });

    testWidgets('renders destructive style properly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticProfileActionTile(
            icon: Icons.logout_rounded,
            isDestructive: true,
            label: 'Đăng xuất',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });
  });

  group('KineticAvatarSourceSheet Widget Tests', () {
    testWidgets('renders camera and gallery options', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticAvatarSourceSheet(
            hasAvatar: false,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('ẢNH ĐẠI DIỆN'), findsOneWidget);
      expect(find.text('Chọn từ thư viện ảnh'), findsOneWidget);
      expect(find.text('Chụp ảnh mới'), findsOneWidget);
      expect(find.text('Xóa ảnh hiện tại'), findsNothing);
    });

    testWidgets('renders remove option when hasAvatar is true', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticAvatarSourceSheet(
            hasAvatar: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Xóa ảnh hiện tại'), findsOneWidget);
    });
  });

  group('EditDisplayNameSheet Light Theme Tests', () {
    testWidgets('renders title and input field with high contrast in Light Theme', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const EditDisplayNameSheet(initialName: 'Duc Bao'),
          theme: KineticTheme.lightTheme,
        ),
      );

      expect(find.text('Đổi tên gọi'), findsOneWidget);
      expect(find.text('Duc Bao'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Đổi tên gọi'));
      expect(textWidget.style?.color, isNotNull);
      // Ensure text is not white in light theme
      expect(textWidget.style?.color != Colors.white, isTrue);
    });
  });
}
