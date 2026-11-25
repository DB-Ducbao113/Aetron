import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          (ref) => AppLanguageNotifier()..state = AppLanguage.vi,
        ),
      ],
      child: MaterialApp(theme: KineticTheme.darkTheme, home: child),
    );
  }

  group('Kinetic RegisterScreen Widget Tests', () {
    testWidgets('renders register screen header and form fields', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      expect(find.text('Theo dõi hành trình fitness'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);
      expect(find.text('Tên đăng nhập'), findsOneWidget);
      expect(find.text('Nhập tên đăng nhập'), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Tạo mật khẩu'), findsOneWidget);
      expect(
        find.text(
          'Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Tối thiểu 8 ký tự (hoa, thường, số, ký tự)'),
        findsNothing,
      );
      expect(find.textContaining('EMAIL'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
    });

    testWidgets(
      'shows terms validation error when tapping register without checking terms',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const RegisterScreen()));
        await tester.pump();

        // Enter a valid username and matching passwords
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'runner01');
        await tester.enterText(textFields.at(1), 'Password123!');
        await tester.enterText(textFields.at(2), 'Password123!');
        await tester.pump();

        // Do NOT check terms checkbox
        final regBtn = find.text('Tạo tài khoản');
        expect(regBtn, findsOneWidget);
        await tester.tap(regBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Điều khoản'), findsWidgets);
      },
    );

    testWidgets('accepts username format such as user1', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const RegisterScreen()));
      await tester.pump();

      // Enter username "user1" and matching passwords
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'user1');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.enterText(textFields.at(2), 'Password123!');
      await tester.pump();

      // Tap submit without terms checked to verify validator passes on username
      final regBtn = find.text('Tạo tài khoản');
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      // It should proceed past username field validation to terms check
      expect(find.textContaining('Điều khoản'), findsWidgets);
    });

    testWidgets(
      'rejects an email address because registration is username-only',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const RegisterScreen()));
        await tester.pump();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'runner@gmail.com');
        await tester.enterText(textFields.at(1), 'Password123!');
        await tester.enterText(textFields.at(2), 'Password123!');
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pump();

        expect(
          find.text('Dùng 3-24 chữ cái thường, số, dấu chấm (.) hoặc (_)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rejects password that contains the username during registration',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const RegisterScreen()));
        await tester.pump();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'runner99');
        await tester.enterText(textFields.at(1), 'Runner99!Pass');
        await tester.enterText(textFields.at(2), 'Runner99!Pass');
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pump();

        expect(
          find.text('Mật khẩu không được trùng hoặc chứa tên đăng nhập'),
          findsOneWidget,
        );
      },
    );
  });
}
