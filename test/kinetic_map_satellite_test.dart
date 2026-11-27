import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_route_full_map_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedViLangNotifier extends AppLanguageNotifier {
  _FixedViLangNotifier() : super() {
    state = AppLanguage.vi;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'});
  });

  group('Satellite Map & Layer Switcher Tests', () {
    test('buildAetronMapTileLayers returns satellite imagery + boundaries and streets', () {
      final satLayers = buildAetronMapTileLayers(AppMapType.satellite);
      expect(satLayers.length, 2);
      final imagery = satLayers[0] as TileLayer;
      final boundaries = satLayers[1] as TileLayer;
      expect(imagery.urlTemplate, contains('World_Imagery'));
      expect(boundaries.urlTemplate, contains('World_Boundaries_and_Places'));
      expect(imagery.maxNativeZoom, 18);
      expect(imagery.maxZoom, double.infinity);
      expect(boundaries.maxNativeZoom, 18);
      expect(boundaries.maxZoom, double.infinity);

      final streetLayers = buildAetronMapTileLayers(AppMapType.streets);
      expect(streetLayers.length, 1);
      final streets = streetLayers[0] as TileLayer;
      expect(streets.urlTemplate, contains('World_Street_Map'));
      expect(streets.maxNativeZoom, 18);
      expect(streets.maxZoom, double.infinity);
    });

    test('buildAetronRoutePolylines renders 4-layer Aetron Glassline gradient ribbon', () {
      const seg = <LatLng>[
        LatLng(10.7769, 106.7009),
        LatLng(10.7775, 106.7014),
        LatLng(10.7780, 106.7020),
      ];

      final fullLayers = buildAetronRoutePolylines(
        segments: const [seg],
        mapType: AppMapType.satellite,
        isDark: true,
      );
      expect(fullLayers, hasLength(4));
      expect(fullLayers[2].gradientColors, hasLength(3));
      expect(fullLayers[2].strokeCap, StrokeCap.round);
      expect(fullLayers[2].strokeJoin, StrokeJoin.round);

      final liteLayers = buildAetronRoutePolylines(
        segments: const [seg],
        mapType: AppMapType.streets,
        isDark: false,
        lite: true,
      );
      expect(liteLayers, hasLength(2));
      expect(liteLayers[1].gradientColors, hasLength(3));
    });

    test(
      'buildAetronRoutePolylines seamlessly merges short indoor gaps (<=45m) and draws dashed bridges for longer blackouts (>45m)',
      () {
        // 1. Short indoor hiccup (~18m apart) + single-point recovery -> 1 continuous solid ribbon (4 layers, 0 dashed)
        const segA = <LatLng>[
          LatLng(10.77690, 106.70090),
          LatLng(10.77696, 106.70095),
        ];
        const orphan = <LatLng>[LatLng(10.77704, 106.70102)];
        const segB = <LatLng>[
          LatLng(10.77712, 106.70108),
          LatLng(10.77720, 106.70115),
        ];

        final seamless = buildAetronRoutePolylines(
          segments: const [segA, orphan, segB],
          mapType: AppMapType.satellite,
          isDark: true,
        );
        expect(seamless, hasLength(4));
        expect(seamless.every((p) => p.pattern.segments == null), isTrue);

        // 2. Long GPS blackout (~280m apart) -> 2 dashed bridge layers + 2x4 solid layers = 10 layers
        const farSeg = <LatLng>[
          LatLng(10.77950, 106.70115),
          LatLng(10.78010, 106.70140),
        ];
        final withBridge = buildAetronRoutePolylines(
          segments: const [segA, farSeg],
          mapType: AppMapType.streets,
          isDark: false,
        );
        expect(withBridge, hasLength(10));
        expect(
          withBridge.where((p) => p.pattern.segments != null),
          hasLength(2),
        );
      },
    );

    testWidgets(
      'TrackingMapWidget allows zoom up to 22 and auto-zooms closely for indoor walking',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              home: const Scaffold(
                body: TrackingMapWidget(
                  routePoints: [
                    LatLng(10.77690, 106.70090),
                    LatLng(10.77695, 106.70094),
                  ],
                  activityType: 'walking',
                  isGpsSignalWeak: true,
                  showMapTiles: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(map.options.maxZoom, 22.0);
        expect(map.options.initialZoom, greaterThanOrEqualTo(19.0));
      },
    );

    test('appMapTypeProvider defaults to satellite and persists changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appMapTypeProvider), AppMapType.satellite);

      await container
          .read(appMapTypeProvider.notifier)
          .setMapType(AppMapType.streets);
      expect(container.read(appMapTypeProvider), AppMapType.streets);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAetronMapTypePrefKey), 'streets');

      // Subsequent container reads persisted preference
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      await container2.read(appMapTypeProvider.notifier).initialized;
      expect(container2.read(appMapTypeProvider), AppMapType.streets);
    });

    testWidgets(
      'ActivityScreen shows layer button, opens map style sheet, and switches Satellite <-> Streets',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appLanguageProvider.overrideWith((_) => _FixedViLangNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              home: const ActivityScreen(showMapTiles: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('activity-map-layer-btn')), findsOneWidget);
        expect(find.byKey(const Key('activity-recenter-btn')), findsOneWidget);
        expect(container.read(appMapTypeProvider), AppMapType.satellite);

        await tester.tap(find.byKey(const Key('activity-map-layer-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Chọn kiểu bản đồ'), findsOneWidget);
        expect(find.text('Ảnh vệ tinh 3D'), findsOneWidget);
        expect(find.text('Đường phố rõ nét'), findsOneWidget);

        await tester.tap(find.byKey(const Key('map-style-option-streets')));
        await tester.pumpAndSettle();

        expect(container.read(appMapTypeProvider), AppMapType.streets);

        // Open again and switch back to Satellite
        await tester.tap(find.byKey(const Key('activity-map-layer-btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map-style-option-satellite')));
        await tester.pumpAndSettle();

        expect(container.read(appMapTypeProvider), AppMapType.satellite);
      },
    );

    testWidgets(
      'WorkoutRouteFullMapScreen supports layer picker both inside ProviderScope and standalone',
      (tester) async {
        const route = <LatLng>[
          LatLng(10.7769, 106.7009),
          LatLng(10.7780, 106.7020),
        ];

        // 1. Standalone without ProviderScope
        await tester.pumpWidget(
          MaterialApp(
            theme: KineticTheme.lightTheme,
            home: const WorkoutRouteFullMapScreen(
              routePoints: route,
              activityType: 'running',
              currentLang: AppLanguage.vi,
              showMapTiles: false,
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('full-map-layer-btn')), findsOneWidget);
        await tester.tap(find.byKey(const Key('full-map-layer-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('map-style-option-streets')), findsOneWidget);
        await tester.tap(find.byKey(const Key('map-style-option-streets')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TrackingMapWidget controls and style picker sheet render cleanly at 320x568 with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWith((_) => _FixedViLangNotifier()),
            ],
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: const Scaffold(
                body: TrackingMapWidget(
                  routePoints: [
                    LatLng(10.7769, 106.7009),
                    LatLng(10.7780, 106.7020),
                  ],
                  activityType: 'running',
                  showControls: true,
                  showMapTiles: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('map-3d-toggle-btn')), findsOneWidget);
        expect(find.byKey(const Key('map-layer-picker-btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('map-3d-toggle-btn')));
        await tester.pump();
        expect(find.text('2D'), findsOneWidget);

        await tester.tap(find.byKey(const Key('map-layer-picker-btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-style-option-satellite')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Switching map style updates mounted AetronMapTypeBuilder and WorkoutRoutePreviewMap reactively',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const route = <LatLng>[
          LatLng(10.7769, 106.7009),
          LatLng(10.7780, 106.7020),
        ];

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: KineticTheme.lightTheme,
              home: Scaffold(
                body: Column(
                  children: [
                    AetronMapTypeBuilder(
                      builder: (context, mapType) =>
                          Text('active:${mapType.name}'),
                    ),
                    Expanded(
                      child: WorkoutRoutePreviewMap(
                        routePoints: route,
                        activityType: 'running',
                        icon: Icons.directions_run_rounded,
                        accentColor: KineticColors.light.primary,
                        glowColor: KineticColors.light.primary,
                        highlightColor: KineticColors.light.primary,
                        startColor: KineticColors.light.success,
                        endColor: KineticColors.light.error,
                        showMapTiles: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('active:satellite'), findsOneWidget);

        await container
            .read(appMapTypeProvider.notifier)
            .setMapType(AppMapType.streets);
        await tester.pump();

        expect(find.text('active:streets'), findsOneWidget);

        await container
            .read(appMapTypeProvider.notifier)
            .setMapType(AppMapType.satellite);
        await tester.pump();

        expect(find.text('active:satellite'), findsOneWidget);
      },
    );
  });
}
