import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/helpers/password_validator.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Password Security & Validator Tests', () {
    test('rejects empty or null password in both languages', () {
      expect(
        validatePasswordStrict(null, AppLanguage.vi),
        'Vui lòng nhập mật khẩu',
      );
      expect(
        validatePasswordStrict('', AppLanguage.en),
        'Please enter password',
      );
    });

    test('rejects password shorter than 8 characters', () {
      expect(
        validatePasswordStrict('Ab1!', AppLanguage.vi),
        'Mật khẩu phải có ít nhất 8 ký tự',
      );
      expect(
        validatePasswordStrict('Ab1!', AppLanguage.en),
        'Password must be at least 8 characters',
      );
    });

    test('rejects password without uppercase letter', () {
      expect(
        validatePasswordStrict('password123!', AppLanguage.vi),
        'Mật khẩu phải có chữ viết hoa (A-Z)',
      );
      expect(
        validatePasswordStrict('password123!', AppLanguage.en),
        'Password must contain an uppercase letter (A-Z)',
      );
    });

    test('rejects password without lowercase letter', () {
      expect(
        validatePasswordStrict('PASSWORD123!', AppLanguage.vi),
        'Mật khẩu phải có chữ thường (a-z)',
      );
      expect(
        validatePasswordStrict('PASSWORD123!', AppLanguage.en),
        'Password must contain a lowercase letter (a-z)',
      );
    });

    test('rejects password without digits', () {
      expect(
        validatePasswordStrict('Password!@#', AppLanguage.vi),
        'Mật khẩu phải có chữ số (0-9)',
      );
      expect(
        validatePasswordStrict('Password!@#', AppLanguage.en),
        'Password must contain a number (0-9)',
      );
    });

    test('rejects password without special character', () {
      expect(
        validatePasswordStrict('Password1234', AppLanguage.vi),
        'Mật khẩu phải có ký tự đặc biệt (!@#%...)',
      );
      expect(
        validatePasswordStrict('Password1234', AppLanguage.en),
        'Password must contain a special character (!@#%...)',
      );
    });

    test('strictly rejects password matching username exactly (case-insensitive)', () {
      final viErr = validatePasswordStrict(
        'Runner123!',
        AppLanguage.vi,
        username: 'runner123!',
      );
      expect(viErr, 'Mật khẩu không được trùng hoặc chứa tên đăng nhập');

      final enErr = validatePasswordStrict(
        'Runner123!',
        AppLanguage.en,
        username: 'RUNNER123!',
      );
      expect(enErr, 'Password cannot match or contain your username');
    });

    test('strictly rejects password containing the username substring', () {
      final viErr = validatePasswordStrict(
        'SuperRunner123!@#',
        AppLanguage.vi,
        username: 'runner123',
      );
      expect(viErr, 'Mật khẩu không được trùng hoặc chứa tên đăng nhập');

      final enErr = validatePasswordStrict(
        'AetronAdmin2026#',
        AppLanguage.en,
        username: 'admin2026',
      );
      expect(enErr, 'Password cannot match or contain your username');
    });

    test('accepts strong password that does NOT contain the username', () {
      final viRes = validatePasswordStrict(
        'VeloCity#99XyZ',
        AppLanguage.vi,
        username: 'marathoner',
      );
      expect(viRes, isNull);

      final enRes = validatePasswordStrict(
        'VeloCity#99XyZ',
        AppLanguage.en,
        username: 'marathoner',
      );
      expect(enRes, isNull);
    });

    test('evaluatePasswordSecurity scores and flags accurately with username', () {
      final resultViolating = evaluatePasswordSecurity(
        'Runner2026!Strong',
        username: 'runner2026',
      );
      expect(resultViolating.isMinLength, isTrue);
      expect(resultViolating.hasUppercase, isTrue);
      expect(resultViolating.hasLowercase, isTrue);
      expect(resultViolating.hasNumber, isTrue);
      expect(resultViolating.hasSpecialChar, isTrue);
      expect(resultViolating.notContainsUsername, isFalse);
      expect(resultViolating.isValid, isFalse);

      final resultClean = evaluatePasswordSecurity(
        'VeloCity#99XyZ',
        username: 'marathoner',
      );
      expect(resultClean.notContainsUsername, isTrue);
      expect(resultClean.isValid, isTrue);
      expect(resultClean.score, equals(6));
    });
  });

  group('PasswordSecurityMeter Widget Tests', () {
    testWidgets('renders security meter with username rule chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: PasswordSecurityMeter(
              password: 'Secret#123Password',
              lang: AppLanguage.vi,
              username: 'secret',
            ),
          ),
        ),
      );

      expect(find.text('Không chứa tên user'), findsOneWidget);
      expect(find.text('≥ 8 ký tự'), findsOneWidget);
      expect(find.text('Chữ hoa (A-Z)'), findsOneWidget);
    });

    testWidgets('renders english security meter with username rule chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const Scaffold(
            body: PasswordSecurityMeter(
              password: 'SafePass#9988',
              lang: AppLanguage.en,
              username: 'runner',
            ),
          ),
        ),
      );

      expect(find.text('No username'), findsOneWidget);
      expect(find.text('Strong security'), findsOneWidget);
    });
  });
}
