import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';

/// Scopes whether native iOS 26 UIKit Liquid Glass platform views are allowed
/// in a subtree. Modal sheets and dialogs disable native UiKitViews so iOS 26
/// Impeller never splits/clips Flutter overlay layers inside sheets while still
/// keeping true Apple Liquid Glass on the dock, segmented controls, and screen chrome.
class NativeLiquidGlassScope extends InheritedWidget {
  const NativeLiquidGlassScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool? maybeEnabledOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NativeLiquidGlassScope>()
      ?.enabled;

  @override
  bool updateShouldNotify(NativeLiquidGlassScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Runtime capability: actual UIKit registration and iOS 26+, never inferred
/// from the Flutter theme or from an iPhone-sized widget test.
abstract final class NativeLiquidGlass {
  static const _capabilities = MethodChannel('aetron/liquid_glass');
  static bool _available = false;
  static bool get available => _available;

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      _available =
          await _capabilities
              .invokeMethod<bool>('isAvailable')
              .timeout(const Duration(seconds: 2)) ??
          false;
    } on Exception {
      _available = false;
    }
    debugPrint('[LiquidGlass] UIKit available: $_available');
  }

  static bool enabledOf(BuildContext context) {
    if (NativeLiquidGlassScope.maybeEnabledOf(context) == false) return false;
    return _available &&
        Theme.of(context).platform == TargetPlatform.iOS &&
        !MediaQuery.highContrastOf(context);
  }
}

/// One UIKit platform view per control, or one for the entire five-tab dock.
/// UIKit owns gestures and accessibility; Dart owns navigation and business state.
class NativeGlassControl extends StatefulWidget {
  const NativeGlassControl({
    super.key,
    required this.properties,
    required this.onTap,
  });
  final Map<String, Object?> properties;
  final ValueChanged<int> onTap;

  @override
  State<NativeGlassControl> createState() => _NativeGlassControlState();
}

class _NativeGlassControlState extends State<NativeGlassControl> {
  MethodChannel? _channel;

  void _created(int id) {
    if (!mounted) return;
    final channel = MethodChannel('aetron/liquid_glass/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (mounted && call.method == 'tap' && call.arguments is int) {
        widget.onTap(call.arguments as int);
      }
    });
    unawaited(_update());
  }

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', widget.properties);
    } on PlatformException catch (error) {
      debugPrint('[LiquidGlass] update: ${error.code}');
    } on MissingPluginException {
      // The view can be disposed while a route is transitioning.
    }
  }

  @override
  void didUpdateWidget(covariant NativeGlassControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.properties, widget.properties)) {
      unawaited(_update());
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'aetron/liquid_glass/control',
    creationParams: widget.properties,
    creationParamsCodec: const StandardMessageCodec(),
    layoutDirection: Directionality.of(context),
    onPlatformViewCreated: _created,
  );
}

/// Native iOS 26 segmented glass control. Callers keep their existing Flutter
/// fallback for older iOS versions, Android and high-contrast mode.
class NativeGlassSegmentedControl extends StatelessWidget {
  const NativeGlassSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.symbols = const [],
  });

  final List<String> labels;
  final List<String> symbols;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return NativeGlassControl(
      properties: {
        'kind': 'segmented',
        'labels': labels.join('|'),
        'symbols': symbols.join('|'),
        'selected': selectedIndex,
        'accent': colors.primary.toARGB32(),
        'foreground': colors.textPrimary.toARGB32(),
        'dark': colors.isDark,
        'reduceMotion': KineticTokens.reduceMotionOf(context),
      },
      onTap: onChanged,
    );
  }
}
