import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logout_dialog.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isDark in [false, true]) {
    testWidgets(
      'Glassline logout dialog and security sheet render cleanly with BackdropFilter (${isDark ? "Dark" : "Light"})',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => AetronLogoutDialog.show(context),
                          child: const Text('Open Logout'),
                        ),
                        ElevatedButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => KineticGlassBottomSheet(
                              floating: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  KineticGlassOptionTile(
                                    icon: Icons.shield_rounded,
                                    title: 'Đổi mật khẩu mới',
                                    subtitle:
                                        'Cập nhật lại mật khẩu đăng nhập.',
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: const Text('Open Security'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open Logout Glassline Sheet
        await tester.tap(find.text('Open Logout'));
        await tester.pumpAndSettle();
        expect(find.byType(KineticGlassBottomSheet), findsOneWidget);
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(
          find.text(AppTranslations.get('logout_title', AppLanguage.en)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Dismiss Logout Sheet
        await tester.tap(
          find.text(AppTranslations.get('cancel', AppLanguage.en)),
        );
        await tester.pumpAndSettle();

        // Open Security Glassline Sheet with KineticGlassOptionTile
        await tester.tap(find.text('Open Security'));
        await tester.pumpAndSettle();
        expect(find.byType(KineticGlassBottomSheet), findsOneWidget);
        expect(find.byType(KineticGlassOptionTile), findsOneWidget);
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
