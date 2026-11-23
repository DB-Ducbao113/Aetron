import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const capability = MethodChannel('aetron/liquid_glass');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  tearDown(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(capability, (_) async => false);
    await NativeLiquidGlass.initialize();
    messenger.setMockMethodCallHandler(capability, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'requires native runtime capability, including unsupported OS',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(capability, (call) async {
        expect(call.method, 'isAvailable');
        return true;
      });
      await NativeLiquidGlass.initialize();
      expect(NativeLiquidGlass.available, isTrue);
      messenger.setMockMethodCallHandler(capability, (_) async => false);
      await NativeLiquidGlass.initialize();
      expect(NativeLiquidGlass.available, isFalse);
    },
  );

  test('missing iOS registration falls back without startup failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(capability, null);
    await NativeLiquidGlass.initialize();
    expect(NativeLiquidGlass.available, isFalse);
  });

  testWidgets('native glass capability is gated by theme and high contrast', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(capability, (_) async => true);
    await NativeLiquidGlass.initialize();
    bool? enabled;
    for (final (platform, contrast, expected) in [
      (TargetPlatform.iOS, false, true),
      (TargetPlatform.iOS, true, false),
      (TargetPlatform.android, false, false),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey((platform, contrast)),
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: contrast),
              child: Builder(
                builder: (context) {
                  enabled = NativeLiquidGlass.enabledOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(enabled, expected, reason: "$platform contrast=$contrast");
    }
    await tester.pumpWidget(const SizedBox());
    // Reset override inside the test because Flutter checks it at test exit.
    debugDefaultTargetPlatformOverride = null;
  });
}
