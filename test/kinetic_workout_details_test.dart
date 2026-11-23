import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_route_full_map_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_delete_dialog.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_header.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_hero_distance.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_route_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_secondary_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_splits_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_telemetry_grid.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_telemetry_list_card.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/details/kinetic_details_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_route_recap_components.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: KineticTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  final mockWorkoutSession = WorkoutSession(
    id: 'ws-details-1',
    userId: 'user-1',
    activityType: 'running',
    startedAt: DateTime(2023, 10, 15, 6, 30),
    endedAt: DateTime(2023, 10, 15, 7, 30),
    durationSec: 3600,
    movingTimeSec: 3400,
    distanceKm: 10.5,
    steps: 8500,
    avgSpeedKmh: 10.5,
    caloriesKcal: 680,
    mode: 'outdoor',
    createdAt: DateTime(2023, 10, 15, 7, 31),
    gpsAnalysis: const WorkoutGpsAnalysis(
      validityFlag: WorkoutValidityFlag.verified,
      restDurationSec: 200,
    ),
    lapSplits: const [
      WorkoutLapSplit(
        index: 1,
        distanceKm: 1.0,
        durationSeconds: 340,
        paceMinPerKm: 5.67,
      ),
      WorkoutLapSplit(
        index: 2,
        distanceKm: 1.0,
        durationSeconds: 330,
        paceMinPerKm: 5.50,
      ),
    ],
  );

  group('KineticDetailsTopBar Widget Tests', () {
    testWidgets('renders title, archive label, and responds to actions', (tester) async {
      bool backTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        buildTestable(
          KineticDetailsTopBar(
            currentLang: AppLanguage.vi,
            onBack: () => backTapped = true,
            onDelete: () => deleteTapped = true,
          ),
        ),
      );

      expect(find.text('AETRON ARCHIVE'), findsNothing);
      expect(find.text('Chi tiết buổi tập'), findsOneWidget);
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.byTooltip('Xóa buổi tập'), findsOneWidget);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pump();
      expect(backTapped, isTrue);

      await tester.tap(find.byTooltip('Xóa buổi tập'));
      await tester.pump();
      expect(deleteTapped, isTrue);
    });
  });

  group('KineticDetailsHeader Widget Tests', () {
    testWidgets('renders verified sport header correctly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsHeader(
            workout: mockWorkoutSession,
            dateLabel: 'Chủ Nhật, 15/10/2023',
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('CHẠY BỘ'), findsOneWidget);
      expect(find.text('Chủ Nhật, 15/10/2023'), findsOneWidget);
      expect(find.text('HỢP LỆ'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
    });

    testWidgets('renders warning flag with reason banner', (tester) async {
      final flaggedWorkout = mockWorkoutSession.copyWith(
        gpsAnalysis: WorkoutGpsAnalysis(
          validityFlag: WorkoutValidityFlag.partial,
          flaggedSegments: [
            WorkoutFlaggedSegment(
              startTimestamp: DateTime(2023, 10, 15, 6, 35),
              endTimestamp: DateTime(2023, 10, 15, 6, 36),
              distanceM: 500,
              durationSec: 30,
              paceSecPerKm: 60,
              avgSpeedMs: 16.6,
              avgAccuracy: 5,
              status: WorkoutSegmentStatus.suspicious,
              reason: 'Tốc độ bất thường tương tự phương tiện cơ giới',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        buildTestable(
          KineticDetailsHeader(
            workout: flaggedWorkout,
            dateLabel: 'Chủ Nhật, 15/10/2023',
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('CẢNH BÁO'), findsOneWidget);
      expect(
        find.text('Tốc độ bất thường tương tự phương tiện cơ giới'),
        findsOneWidget,
      );
    });

    testWidgets('renders sport header without dateLabel when dateLabel is null', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsHeader(
            workout: mockWorkoutSession,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('CHẠY BỘ'), findsOneWidget);
      expect(find.text('HỢP LỆ'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
      expect(find.textContaining('Thứ'), findsNothing);
      expect(find.textContaining('Chủ Nhật'), findsNothing);
    });
  });

  group('KineticDetailsHeroDistance Widget Tests', () {
    testWidgets('renders metric distance and KM unit pill', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsHeroDistance(
            workout: mockWorkoutSession,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('QUÃNG ĐƯỜNG ĐÃ LƯU'), findsOneWidget);
      expect(find.text('10.50'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
    });

    testWidgets('converts to miles when useMetricUnits is false', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsHeroDistance(
            workout: mockWorkoutSession,
            useMetricUnits: false,
            currentLang: AppLanguage.en,
          ),
        ),
      );

      expect(find.text('RECORDED DISTANCE'), findsOneWidget);
      expect(find.text('6.52'), findsOneWidget);
      expect(find.text('MI'), findsOneWidget);
    });
  });

  group('KineticDetailsRouteCard Widget Tests', () {
    testWidgets('renders empty state when points < 2', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const KineticDetailsRouteCard(
            routePoints: [],
            activityType: 'running',
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Không có dữ liệu bản đồ'), findsOneWidget);
      expect(find.textContaining('chỉ số hiệu suất telemetry'), findsOneWidget);
    });

    testWidgets(
      'offers a clear full-map action without technical GPS labels',
      (tester) async {
        var openedFullMap = false;
        await tester.pumpWidget(
          buildTestable(
            KineticDetailsRouteCard(
              routePoints: const [
                LatLng(10.7769, 106.7009),
                LatLng(10.7780, 106.7020),
              ],
              activityType: 'running',
              currentLang: AppLanguage.vi,
              onViewFullMap: () => openedFullMap = true,
              showMapTiles: false,
            ),
          ),
        );

        expect(find.text('Xem toàn bản đồ'), findsOneWidget);
        expect(find.text('AETRON GPS'), findsNothing);
        expect(find.textContaining('points'), findsNothing);
        expect(find.textContaining('điểm GPS'), findsNothing);
        expect(find.text('LỘ TRÌNH'), findsNothing);

        await tester.tap(find.text('Xem toàn bản đồ'));
        expect(openedFullMap, isTrue);
      },
    );
  });

  group('WorkoutRouteFullMapScreen Widget Tests', () {
    testWidgets('shows the whole-route controls with an interactive map', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: const WorkoutRouteFullMapScreen(
            routePoints: [
              LatLng(10.7769, 106.7009),
              LatLng(10.7780, 106.7020),
            ],
            activityType: 'running',
            currentLang: AppLanguage.vi,
            showMapTiles: false,
          ),
        ),
      );

      expect(find.text('Toàn bộ cung đường'), findsOneWidget);
      expect(
        find.text('Kéo để khám phá • Chụm để thu phóng'),
        findsOneWidget,
      );
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.text('LỘ TRÌNH ĐÃ GHI'), findsNothing);

      final map = tester.widget<WorkoutRoutePreviewMap>(
        find.byType(WorkoutRoutePreviewMap),
      );
      expect(map.interactive, isTrue);
      expect(map.footerText, isNull);
    });
  });

  group('KineticDetailsTelemetryGrid Widget Tests', () {
    testWidgets('renders duration, avg pace, calories, and steps', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsTelemetryGrid(
            workout: mockWorkoutSession,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('THỜI GIAN'), findsOneWidget);
      expect(find.text('1h 0m'), findsOneWidget);
      expect(find.text('PACE TB'), findsOneWidget);
      expect(find.text('CALO'), findsOneWidget);
      expect(find.text('680'), findsOneWidget);
      expect(find.text('SỐ BƯỚC'), findsOneWidget);
      expect(find.text('8.5k'), findsOneWidget);
    });
  });

  group('KineticDetailsSecondaryCard Widget Tests', () {
    testWidgets('renders moving time, rest time, avg speed, and environment', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsSecondaryCard(
            workout: mockWorkoutSession,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('THÔNG SỐ BỔ SUNG'), findsOneWidget);
      expect(find.text('Thời gian di chuyển'), findsOneWidget);
      expect(find.text('Thời gian nghỉ'), findsOneWidget);
      expect(find.text('Tốc độ trung bình'), findsOneWidget);
      expect(find.text('10.5 km/h'), findsOneWidget);
      expect(find.text('Môi trường'), findsOneWidget);
      expect(find.text('Ngoài trời'), findsOneWidget);
    });
  });

  group('KineticDetailsSplitsCard Widget Tests', () {
    testWidgets('renders splits breakdown table and lap indicators', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsSplitsCard(
            lapSplits: mockWorkoutSession.lapSplits,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('PHÂN TÁCH CỰ LY (SPLITS)'), findsOneWidget);
      expect(find.text('KM 1'), findsOneWidget);
      expect(find.text('KM 2'), findsOneWidget);
      expect(find.text('2 KM'), findsOneWidget);
    });
  });

  group('KineticDetailsDeleteDialog Widget Tests', () {
    testWidgets('renders delete confirmation and invokes onConfirm', (tester) async {
      bool deleteConfirmed = false;

      await tester.pumpWidget(
        buildTestable(
          KineticDetailsDeleteDialog(
            currentLang: AppLanguage.vi,
            onConfirm: () => deleteConfirmed = true,
          ),
        ),
      );

      expect(find.text('Xóa buổi tập'), findsOneWidget);
      expect(find.textContaining('Bạn có chắc chắn muốn xóa'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xác nhận xóa'), findsOneWidget);

      await tester.tap(find.text('Xác nhận xóa'));
      await tester.pump();
      expect(deleteConfirmed, isTrue);
    });
  });

  group('KineticDetailsTelemetryListCard Widget Tests', () {
    testWidgets('renders all telemetry rows and excludes environment field', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticDetailsTelemetryListCard(
            workout: mockWorkoutSession,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('THÔNG SỐ CHI TIẾT'), findsOneWidget);
      expect(find.text('Quãng đường'), findsOneWidget);
      expect(find.text('10.50 km'), findsOneWidget);
      expect(find.text('Thời gian'), findsOneWidget);
      expect(find.text('1h 0m'), findsOneWidget);
      expect(find.text('Pace TB'), findsOneWidget);
      expect(find.text('Calo'), findsOneWidget);
      expect(find.text('680 kcal'), findsOneWidget);
      expect(find.text('Số bước'), findsOneWidget);
      expect(find.text('8,500 bước'), findsOneWidget);
      expect(find.text('Thời gian di chuyển'), findsOneWidget);
      expect(find.text('Thời gian nghỉ'), findsOneWidget);
      expect(find.text('Tốc độ trung bình'), findsOneWidget);

      // Verify that Môi trường (Environment) is strictly omitted
      expect(find.text('Môi trường'), findsNothing);
      expect(find.text('Ngoài trời'), findsNothing);
      expect(find.text('Trong nhà'), findsNothing);
      expect(find.text('Environment'), findsNothing);
    });

    testWidgets('adapts telemetry for cycling (hides steps, shows speed)', (tester) async {
      final cyclingWorkout = mockWorkoutSession.copyWith(
        activityType: 'cycling',
        steps: 0,
      );

      await tester.pumpWidget(
        buildTestable(
          KineticDetailsTelemetryListCard(
            workout: cyclingWorkout,
            useMetricUnits: true,
            currentLang: AppLanguage.vi,
          ),
        ),
      );

      expect(find.text('Số bước'), findsNothing);
      expect(find.text('Tốc độ TB'), findsOneWidget);
      expect(find.text('Môi trường'), findsNothing);
    });
  });

  group('Full WorkoutDetailsScreen Integration Test', () {
    testWidgets('renders all details sections when workout data loads', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLanguageProvider.overrideWith((_) => _TestViLanguageNotifier()),
            workoutProvider('ws-details-1').overrideWith(
              (ref) async => mockWorkoutSession,
            ),
            workoutRoutePresentationProvider('ws-details-1').overrideWith(
              (ref) async => const WorkoutRoutePresentation(
                routePoints: [],
                routeSegments: [],
                source: 'empty',
                matchStatus: 'none',
              ),
            ),
            metricUnitsPreferenceProvider.overrideWith((ref) async => true),
          ],
          child: const MaterialApp(
            home: WorkoutDetailsScreen(
              workoutId: 'ws-details-1',
              showMapTiles: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AETRON ARCHIVE'), findsNothing);
      expect(find.text('Chi tiết buổi tập'), findsOneWidget);
      expect(find.text('CHẠY BỘ'), findsOneWidget);
      // Header has no date label
      expect(find.textContaining('Chủ Nhật'), findsNothing);
      // Route card rendered below header (in empty route state)
      expect(find.text('Không có dữ liệu bản đồ'), findsOneWidget);
      // Combined telemetry list card rendered below route card
      expect(find.text('THÔNG SỐ CHI TIẾT'), findsOneWidget);
      expect(find.text('Quãng đường'), findsOneWidget);
      expect(find.text('10.50 km'), findsOneWidget);
      expect(find.text('Pace TB'), findsOneWidget);
      // Environment is NOT present
      expect(find.text('Môi trường'), findsNothing);
      expect(find.text('PHÂN TÁCH CỰ LY (SPLITS)'), findsOneWidget);
    });
  });
}
