import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/kinetic_analytics_header.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_range_tabs.dart';
import 'package:fitness_exercise_application/features/history/presentation/widgets/kinetic_history_sport_filter.dart';
import 'package:fitness_exercise_application/features/home/presentation/providers/streak_providers.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_details_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockWorkoutList extends WorkoutList {
  final List<WorkoutSession> _mockWorkouts;
  _MockWorkoutList(this._mockWorkouts);

  @override
  Future<List<WorkoutSession>> build() async => _mockWorkouts;
}

class _MockLanguageNotifier extends AppLanguageNotifier {
  _MockLanguageNotifier(AppLanguage lang) : super() {
    state = lang;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'settings.language.code': 'vi',
      'settings.notifications.enabled': true,
      'settings.notifications.workout_reminders': true,
      'settings.notifications.morning_time': '08:00',
      'settings.notifications.goal_progress': true,
      'settings.notifications.achievement': true,
      'settings.notifications.streak_reminders': true,
      'settings.notifications.inactivity_reminders': true,
      'settings.notifications.quiet_hours': true,
      'settings.notifications.quiet_hours_start': '22:00',
      'settings.notifications.quiet_hours_end': '07:00',
    });
  });

  final mockProfile = UserProfile(
    id: 'p1',
    userId: 'u1',
    weightKg: 68.0,
    heightCm: 175.0,
    dateOfBirth: DateTime(1995, 5, 20),
    legacyAge: 31,
    gender: 'male',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final mockWorkout = WorkoutSession(
    id: 'w1',
    userId: 'u1',
    activityType: 'running',
    startedAt: DateTime.now().subtract(const Duration(hours: 2)),
    endedAt: DateTime.now().subtract(const Duration(hours: 1)),
    durationSec: 1800,
    distanceKm: 5.25,
    steps: 6200,
    avgSpeedKmh: 10.5,
    caloriesKcal: 380,
    mode: 'outdoor',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
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
        durationSeconds: 320,
        paceMinPerKm: 5.33,
      ),
    ],
  );

  Widget createTestApp(Widget child, {Key? key, List<Override> overrides = const []}) {
    return ProviderScope(
      key: key ?? UniqueKey(),
      overrides: [
        appLanguageProvider.overrideWith((ref) => _MockLanguageNotifier(AppLanguage.vi)),
        metricUnitsPreferenceProvider.overrideWith((ref) async => true),
        currentAvatarDisplayProvider.overrideWithValue(const AvatarDisplayState()),
        appConnectionProvider.overrideWith((ref) => Stream.value(true)),
        goalProgressProvider.overrideWithValue(null),
        streakProvider.overrideWithValue(const StreakData(currentStreak: 5, longestStreak: 10)),
        ...overrides,
      ],
      child: MaterialApp(
        scrollBehavior: const KineticScrollBehavior(),
        theme: KineticTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('User Simulation End-to-End Suite', () {
    testWidgets('Journey 1: Login & Register screen form validation', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(const LoginScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check login form renders
      expect(find.textContaining('Đăng nhập'), findsWidgets);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);

      // Navigate to RegisterScreen
      await tester.pumpWidget(
        createTestApp(const RegisterScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find registration fields: username/email, password, confirm password
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(3));

      // Enter username user1
      await tester.enterText(textFields.at(0), 'user1');
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.enterText(textFields.at(2), 'Password123!');
      await tester.pump();

      // Submit without checking terms checkbox
      final regBtn = find.text('Tạo tài khoản');
      expect(regBtn, findsOneWidget);
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      // Ensure username user1 is accepted without email format error
      expect(find.text('Email không hợp lệ'), findsNothing);
      expect(find.textContaining('Điều khoản'), findsWidgets);
    });

    testWidgets('Journey 2: ActivityScreen map-first start and sport switcher', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const ActivityScreen(showMapTiles: false),
          overrides: [
            workoutListProvider.overrideWith(() => _MockWorkoutList(const [])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify 3 sport pills are rendered
      expect(find.byKey(const Key('sport-pill-running')), findsOneWidget);
      expect(find.byKey(const Key('sport-pill-cycling')), findsOneWidget);
      expect(find.byKey(const Key('sport-pill-walking')), findsOneWidget);

      // User selects Cycling
      await tester.tap(find.byKey(const Key('sport-pill-cycling')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Bắt đầu đạp xe'), findsOneWidget);

      // User selects Walking
      await tester.tap(find.byKey(const Key('sport-pill-walking')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Start button reflects Walking
      expect(find.text('Bắt đầu đi bộ'), findsOneWidget);
    });

    testWidgets('Journey 3: Calendar History filtering and range switching', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const CalendarScreen(),
          overrides: [
            workoutListProvider.overrideWith(() => _MockWorkoutList([mockWorkout])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify range tabs and sport filter
      expect(find.byType(KineticHistoryRangeTabs), findsOneWidget);
      expect(find.byType(KineticHistorySportFilter), findsOneWidget);

      // User switches range to Week
      await tester.tap(find.text('Tuần'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // User switches range to Month
      await tester.tap(find.text('Tháng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // User filters by Cycling (where no workouts exist) -> shows empty state
      await tester.tap(find.text('Đạp xe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Không có buổi tập phù hợp bộ lọc'), findsOneWidget);

      // User switches back to All sports
      await tester.tap(find.text('Tất cả').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('5.25'), findsOneWidget);
    });

    testWidgets('Journey 4: Analytics & Stats screen period switching', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const StatsScreen(),
          overrides: [
            workoutListProvider.overrideWith(() => _MockWorkoutList([mockWorkout])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Analytics Header
      expect(find.byType(KineticAnalyticsHeader), findsOneWidget);

      // Telemetry sections rendered
      expect(find.text('Cơ cấu môn tập'), findsOneWidget);
      expect(find.text('Chỉ dẫn hồi phục'), findsOneWidget);
    });

    testWidgets('Journey 5: ProfileScreen rendering and components', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const ProfileScreen(),
          overrides: [
            userProfileProvider('u1').overrideWith((ref) => mockProfile),
            currentUserProfileProvider.overrideWithValue(AsyncValue.data(mockProfile)),
            workoutListProvider.overrideWith(() => _MockWorkoutList([mockWorkout])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Top bar title
      expect(find.text('AETRON'), findsNothing);
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      // Biometrics bento
      expect(find.text('Dữ liệu sinh trắc'), findsOneWidget);
      expect(find.textContaining('68.0'), findsOneWidget);
    });

    testWidgets('Journey 6: WorkoutSummaryScreen telemetry and lap splits display', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const WorkoutSummaryScreen(
            sessionId: 'w1',
            activityType: 'running',
            trackingMode: 'outdoor',
            durationSeconds: 1800,
            movingTimeSeconds: 1750,
            distanceMeters: 5250,
            avgSpeedKmh: 10.5,
            calories: 380,
            steps: 6200,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Celebration distance
      expect(find.text('5.25'), findsOneWidget);
      expect(find.text('Chạy bộ'), findsOneWidget);

      // Actions
      expect(find.text('Hoàn thành'), findsOneWidget);
      expect(find.text('Chia sẻ buổi tập'), findsOneWidget);
    });

    testWidgets('Journey 7: WorkoutDetailsScreen details, telemetry, and route recap', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const WorkoutDetailsScreen(workoutId: 'w1'),
          overrides: [
            workoutProvider('w1').overrideWith((ref) async => mockWorkout),
            workoutRoutePresentationProvider('w1').overrideWith(
              (ref) async => const WorkoutRoutePresentation(
                routePoints: [],
                routeSegments: [],
                source: 'empty',
                matchStatus: 'none',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Header displays activity
      expect(find.text('Chạy bộ'), findsOneWidget);
      expect(find.text('5.25 km'), findsOneWidget);

      // Telemetry list shows Moving time, Pace (speed omitted for running)
      expect(find.text('Thời gian di chuyển'), findsOneWidget);
      expect(find.text('Tốc độ trung bình'), findsNothing);
      expect(find.text('Nhịp độ TB'), findsOneWidget);

      // Delete action button present in top bar
      expect(find.byTooltip('Xóa buổi tập'), findsOneWidget);
    });

    testWidgets('Journey 8: Settings and NotificationSettings screens', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const SettingsScreen(),
          overrides: [
            currentUserProfileProvider.overrideWithValue(AsyncValue.data(mockProfile)),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Top bar & section headers
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('AETRON SYSTEM'), findsNothing);
      expect(find.text('Quyền riêng tư & truy cập'), findsOneWidget);
      expect(find.text('Cấu hình ứng dụng'), findsOneWidget);

      // Check notification settings screen directly
      await tester.pumpWidget(
        createTestApp(const NotificationSettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Nhắc nhở luyện tập'), findsOneWidget);
      expect(find.text('Luyện tập & Chuỗi ngày'), findsOneWidget);
      expect(find.text('Mục tiêu & Thành tích'), findsOneWidget);
      expect(find.text('Khung giờ yên tĩnh'), findsOneWidget);
      expect(find.text('Chế độ yên tĩnh'), findsOneWidget);
    });

    testWidgets('Journey 9: HomeScreen clean Strava-Runna dashboard without map tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          const HomeScreen(showMapTiles: false),
          overrides: [
            workoutListProvider.overrideWith(() => _MockWorkoutList([mockWorkout])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Top bar heading & clean section structure
      expect(find.text('Mục tiêu tuần'), findsOneWidget);
      expect(find.text('Hoạt động gần đây'), findsOneWidget);
      expect(find.text('Giáo án luyện tập'), findsOneWidget);
    });
  });
}
