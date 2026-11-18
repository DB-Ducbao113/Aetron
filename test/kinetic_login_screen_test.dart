import 'dart:io';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadBeVietnamProFonts() async {
  const weights = [
    'fonts/BeVietnamPro-Regular.ttf',
    'fonts/BeVietnamPro-Medium.ttf',
    'fonts/BeVietnamPro-SemiBold.ttf',
    'fonts/BeVietnamPro-Bold.ttf',
    'fonts/BeVietnamPro-ExtraBold.ttf',
  ];
  final loader = FontLoader('BeVietnamPro');
  var loadedAny = false;
  for (final path in weights) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      loadedAny = true;
    }
  }
  if (loadedAny) {
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await _loadBeVietnamProFonts();
  });

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

  group('Kinetic LoginScreen Widget Tests', () {
    testWidgets('renders login header artwork, title and form fields', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      expect(find.textContaining('Đăng Nhập'), findsWidgets);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text('TÊN ĐĂNG NHẬP'), findsOneWidget);
      expect(find.text('Nhập tên đăng nhập'), findsOneWidget);
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.textContaining('EMAIL'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
    });

    testWidgets(
      'switches the public login screen between Vietnamese and English',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const LoginScreen()));
        await tester.pump();

        await tester.tap(find.text('EN'));
        await tester.pump();

        expect(find.text('Sign In'), findsWidgets);
        expect(find.text('USERNAME'), findsOneWidget);
        expect(find.text('Enter your username'), findsOneWidget);
      },
    );

    testWidgets('validates empty inputs on login button tap', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      final loginBtn = find.text('Đăng Nhập').last;
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên tài khoản'), findsOneWidget);
    });

    testWidgets('rejects email input because login is username-only', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'runner@gmail.com');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.tap(find.text('Đăng Nhập').last);
      await tester.pump();

      expect(
        find.text('Dùng 3-24 chữ cái thường, số, dấu chấm (.) hoặc (_)'),
        findsOneWidget,
      );
    });

    testWidgets('wraps GoogleLogo.jpg in circular white badge with ClipOval in Dark Mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pump();

      final googleImageFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/GoogleLogo.jpg',
      );
      expect(googleImageFinder, findsOneWidget);

      final clipOvalAncestor = find.ancestor(
        of: googleImageFinder,
        matching: find.byType(ClipOval),
      );
      expect(clipOvalAncestor, findsOneWidget);

      final badgeContainerFinder = find.ancestor(
        of: clipOvalAncestor,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final dec = w.decoration;
          return dec is BoxDecoration &&
              dec.color == Colors.white &&
              dec.shape == BoxShape.circle;
        }),
      );
      expect(badgeContainerFinder, findsOneWidget);
    });

    testWidgets(
      'LoginScreen renders without horizontal overflow at 360x640 and 320x568 with 1.3x textScaler in vi and en',
      (WidgetTester tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final size in [const Size(360, 640), const Size(320, 568)]) {
          tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
          tester.view.devicePixelRatio = 2.0;

          for (final lang in [AppLanguage.vi, AppLanguage.en]) {
            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [
                  appLanguageProvider.overrideWith(
                    (ref) => AppLanguageNotifier()..state = lang,
                  ),
                ],
                child: MaterialApp(
                  theme: KineticTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: const LoginScreen(),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));

            expect(
              tester.takeException(),
              isNull,
              reason: 'Overflow detected at $size (${lang.name}) with 1.3x textScaler',
            );
          }
        }
      },
    );
  });
}
