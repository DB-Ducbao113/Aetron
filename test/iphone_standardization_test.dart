import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/core/providers/connectivity_providers.dart';
import 'package:fitness_exercise_application/features/activity/presentation/screens/activity_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/models/personal_records.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:fitness_exercise_application/features/analytics/presentation/widgets/personal_records_trophy_wall.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/register_screen.dart';
import 'package:fitness_exercise_application/features/history/presentation/screens/calendar_screen.dart';
import 'package:fitness_exercise_application/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_exercise_application/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_goal.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/goal_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/achievements_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/goal_screen.dart';
import 'package:fitness_exercise_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fitness_exercise_application/features/settings/presentation/screens/settings_screen.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _StaticLanguageNotifier extends AppLanguageNotifier {
  _StaticLanguageNotifier(AppLanguage lang) : super() {
    state = lang;
  }
}

class _StaticWorkoutList extends WorkoutList {
  final List<WorkoutSession> items;
  _StaticWorkoutList(this.items);

  @override
  Future<List<WorkoutSession>> build() async => items;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(items);
  }
}

class _StaticGoalNotifier extends UserGoalNotifier {
  _StaticGoalNotifier(UserGoal? goal) : super(null) {
    state = AsyncValue.data(goal);
  }
}

Future<void> _loadAppFonts() async {
  const beVietnamPaths = [
    'fonts/BeVietnamPro-Regular.ttf',
    'fonts/BeVietnamPro-Medium.ttf',
    'fonts/BeVietnamPro-SemiBold.ttf',
    'fonts/BeVietnamPro-Bold.ttf',
    'fonts/BeVietnamPro-ExtraBold.ttf',
  ];
  final beLoader = FontLoader('BeVietnamPro');
  var loadedBe = false;
  for (final path in beVietnamPaths) {
    final f = File(path);
    if (f.existsSync()) {
      beLoader.addFont(Future.value(ByteData.sublistView(await f.readAsBytes())));
      loadedBe = true;
    }
  }
  if (loadedBe) await beLoader.load();

  final home = Platform.environment['HOME'] ?? '';
  final lucidePaths = [
    '$home/.pub-cache/hosted/pub.dev/flutter_lucide-1.72.0/lib/fonts/lucide.ttf',
  ];
  for (final path in lucidePaths) {
    final f = File(path);
    if (f.existsSync()) {
      final loader = FontLoader('packages/flutter_lucide/lucide');
      loader.addFont(Future.value(ByteData.sublistView(await f.readAsBytes())));
      await loader.load();
      break;
    }
  }

  final materialPaths = [
    '$home/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in materialPaths) {
    final f = File(path);
    if (f.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(Future.value(ByteData.sublistView(await f.readAsBytes())));
      await loader.load();
      break;
    }
  }
}

Future<void> _maybeCaptureScreenshot(
  WidgetTester tester,
  GlobalKey repaintKey,
  String filename,
) async {
  final outDir = Platform.environment['AETRON_CAPTURE_DIR'];
  if (outDir == null || outDir.isEmpty) return;

  final boundary =
      repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return;

    final dir = Directory(outDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(byteData.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    await _loadAppFonts();
  });

  final now = DateTime.now();
  final mockWorkouts = [
    WorkoutSession(
      id: 'w-1',
      userId: 'user-1',
      activityType: 'running',
      startedAt: now.subtract(const Duration(hours: 3)),
      endedAt: now.subtract(const Duration(hours: 2, minutes: 13)),
      durationSec: 2820,
      movingTimeSec: 2740,
      distanceKm: 8.42,
      steps: 9420,
      avgSpeedKmh: 10.75,
      caloriesKcal: 580,
      mode: 'outdoor',
      createdAt: now.subtract(const Duration(hours: 2)),
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 8.42,
        validityFlag: WorkoutValidityFlag.verified,
      ),
      lapSplits: const [
        WorkoutLapSplit(index: 1, distanceKm: 1.0, durationSeconds: 318, paceMinPerKm: 5.30),
        WorkoutLapSplit(index: 2, distanceKm: 1.0, durationSeconds: 325, paceMinPerKm: 5.42),
      ],
    ),
    WorkoutSession(
      id: 'w-2',
      userId: 'user-1',
      activityType: 'cycling',
      startedAt: now.subtract(const Duration(days: 1, hours: 2)),
      endedAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 15)),
      durationSec: 2700,
      movingTimeSec: 2700,
      distanceKm: 16.50,
      steps: 0,
      avgSpeedKmh: 22.0,
      caloriesKcal: 425,
      mode: 'outdoor',
      createdAt: now.subtract(const Duration(days: 1)),
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 16.50,
        validityFlag: WorkoutValidityFlag.verified,
      ),
    ),
    WorkoutSession(
      id: 'w-3',
      userId: 'user-1',
      activityType: 'walking',
      startedAt: now.subtract(const Duration(days: 2, hours: 1)),
      endedAt: now.subtract(const Duration(days: 2)),
      durationSec: 2280,
      movingTimeSec: 2200,
      distanceKm: 3.85,
      steps: 4920,
      avgSpeedKmh: 6.08,
      caloriesKcal: 200,
      mode: 'outdoor',
      createdAt: now.subtract(const Duration(days: 2)),
      gpsAnalysis: const WorkoutGpsAnalysis(
        validDistanceKm: 3.85,
        validityFlag: WorkoutValidityFlag.verified,
      ),
    ),
  ];

  final mockGoal = UserGoal(
    id: 'goal-1',
    userId: 'user-1',
    goalType: GoalType.distance,
    targetValue: 40.0,
    period: GoalPeriod.weekly,
    createdAt: now.subtract(const Duration(days: 7)),
    updatedAt: now,
  );

  final mockProfile = UserProfile(
    id: 'profile-1',
    userId: 'user-1',
    weightKg: 66.5,
    heightCm: 174.0,
    legacyAge: 28,
    gender: 'male',
    createdAt: DateTime(2025, 1, 10),
    updatedAt: now,
  );

  ProviderScope wrapScreen({
    required Widget child,
    required GlobalKey repaintKey,
    required ThemeData theme,
    AppLanguage lang = AppLanguage.vi,
    double textScale = 1.0,
    bool useMetric = true,
  }) {
    SharedPreferences.setMockInitialValues({
      kAppLanguagePrefKey: lang == AppLanguage.vi ? 'vi' : 'en',
      kThemeModePrefKey: theme.brightness == Brightness.dark ? 'dark' : 'light',
      kMetricUnitsPrefKey: useMetric,
      kNotificationsPrefKey: true,
    });

    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        appLanguageProvider.overrideWith((_) => _StaticLanguageNotifier(lang)),
        appConnectionProvider.overrideWith((_) => Stream.value(true)),
        metricUnitsPreferenceProvider.overrideWith((_) async => useMetric),
        currentUserIdProvider.overrideWithValue('user-1'),
        workoutListProvider.overrideWith(() => _StaticWorkoutList(mockWorkouts)),
        recoverableInterruptedSessionProvider.overrideWith((_) async => null),
        userGoalProvider.overrideWith((_) => _StaticGoalNotifier(mockGoal)),
        currentUserProfileProvider.overrideWithValue(AsyncValue.data(mockProfile)),
        currentAvatarDisplayProvider.overrideWithValue(const AvatarDisplayState()),
        workoutRoutePresentationProvider.overrideWith(
          (_, _) async => const WorkoutRoutePresentation(
            routePoints: [
              LatLng(10.7755, 106.7005),
              LatLng(10.7775, 106.6992),
              LatLng(10.7794, 106.7016),
              LatLng(10.7755, 106.7005),
            ],
            routeSegments: <List<LatLng>>[],
            source: 'filtered',
            matchStatus: 'matched',
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: inner!,
        ),
        home: RepaintBoundary(
          key: repaintKey,
          child: child,
        ),
      ),
    );
  }

  Future<void> pumpIphoneViewport(
    WidgetTester tester,
    Size logicalSize, {
    double dpr = 3.0,
  }) async {
    tester.view.physicalSize = logicalSize * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('iPhone UI Standardization Audit', () {
    testWidgets('PersonalRecordsTrophyWall renders compact tiles and passes 375x667 & 390x844 (1.0x & 1.3x)', (tester) async {
      final prs = DetailedPersonalRecords.fromWorkouts(mockWorkouts);

      for (final viewport in [
        (size: const Size(390, 844), dpr: 3.0, tag: 'iphone15'),
        (size: const Size(375, 667), dpr: 2.0, tag: 'iphonese'),
      ]) {
        for (final isDark in [false, true]) {
          for (final scale in [1.0, 1.3]) {
            await pumpIphoneViewport(tester, viewport.size, dpr: viewport.dpr);
            final key = GlobalKey();
            final theme = isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme;

            await tester.pumpWidget(
              wrapScreen(
                repaintKey: key,
                theme: theme,
                textScale: scale,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(KineticTokens.page),
                    child: PersonalRecordsTrophyWall(
                      records: prs,
                      useMetricUnits: true,
                      currentLang: AppLanguage.vi,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            final dynamic err = tester.takeException();
            expect(err, isNull, reason: 'Overflow in PersonalRecordsTrophyWall (${viewport.tag}, dark=$isDark, scale=$scale)');

            if (scale == 1.0 && viewport.tag == 'iphone15') {
              await _maybeCaptureScreenshot(
                tester,
                key,
                'personal_bests_${isDark ? 'dark' : 'light'}_${viewport.tag}.png',
              );
            }
          }
        }
      }
    });

    testWidgets('StatsScreen (scrolled to Personal Bests) renders cleanly on iPhone 390x844 & 375x667', (tester) async {
      for (final viewport in [
        (size: const Size(390, 844), dpr: 3.0, tag: 'iphone15'),
        (size: const Size(375, 667), dpr: 2.0, tag: 'iphonese'),
      ]) {
        for (final scale in [1.0, 1.3]) {
          for (final isDark in [false, true]) {
            await pumpIphoneViewport(tester, viewport.size, dpr: viewport.dpr);
            final key = GlobalKey();

            await tester.pumpWidget(
              wrapScreen(
                repaintKey: key,
                theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
                textScale: scale,
                child: const StatsScreen(),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            expect(tester.takeException(), isNull, reason: 'StatsScreen initial (${viewport.tag}, dark=$isDark, scale=$scale)');

            // Scroll down until PersonalRecordsTrophyWall is visible
            await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            expect(tester.takeException(), isNull, reason: 'StatsScreen scrolled (${viewport.tag}, dark=$isDark, scale=$scale)');

            if (scale == 1.0 && viewport.tag == 'iphone15') {
              await _maybeCaptureScreenshot(
                tester,
                key,
                'analytics_bottom_${isDark ? 'dark' : 'light'}_${viewport.tag}.png',
              );
            }
          }
        }
      }
    });

    testWidgets('All core screens pass zero-overflow check on iPhone SE (375x667 @ 1.0x & 1.15x) and iPhone 15 (390x844)', (tester) async {
      final screens = <(String name, Widget Function() builder, bool capture)>[
        ('home', () => const HomeScreen(showMapTiles: false), true),
        ('activity', () => const ActivityScreen(showMapTiles: false), false),
        ('history', () => const CalendarScreen(), true),
        ('profile', () => const ProfileScreen(), true),
        ('goal', () => const GoalScreen(), true),
        ('achievements', () => const AchievementsScreen(), true),
        ('settings', () => const SettingsScreen(), true),
        ('notification_settings', () => const NotificationSettingsScreen(), true),
        ('running_programs', () => const RunningProgramsScreen(), true),
        ('globe_loading', () => const AetronGlobeOrbitScreen(
          customTitle: 'Aetron',
        ), true),
        ('summary', () => WorkoutSummaryScreen(
          sessionId: 'w-1',
          activityType: 'running',
          trackingMode: 'outdoor',
          durationSeconds: 2820,
          movingTimeSeconds: 2740,
          distanceMeters: 8420,
          avgSpeedKmh: 10.75,
          calories: 580,
          steps: 9420,
          gpsAnalysis: const WorkoutGpsAnalysis(
            validDistanceKm: 8.42,
            validityFlag: WorkoutValidityFlag.verified,
          ),
        ), true),
        ('login', () => const LoginScreen(), false),
        ('register', () => const RegisterScreen(), false),
        ('forgot_password', () => const ForgotPasswordScreen(), false),
        ('welcome', () => WelcomeScreen(onNext: () async {}), false),
      ];

      final failures = <String>[];
      for (final screen in screens) {
        for (final viewport in [
          (size: const Size(390, 844), dpr: 3.0, tag: 'iphone15'),
          (size: const Size(375, 667), dpr: 2.0, tag: 'iphonese'),
        ]) {
          for (final isDark in [false, true]) {
            await pumpIphoneViewport(tester, viewport.size, dpr: viewport.dpr);
            final key = GlobalKey();
            await tester.pumpWidget(
              wrapScreen(
                repaintKey: key,
                theme: isDark ? KineticTheme.darkTheme : KineticTheme.lightTheme,
                textScale: viewport.tag == 'iphonese' ? 1.15 : 1.0,
                child: screen.$2(),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            final err = tester.takeException();
            if (err != null) {
              failures.add('${screen.$1} (${viewport.tag}, dark=$isDark): $err');
            }

            if (screen.$3 && viewport.tag == 'iphone15') {
              await _maybeCaptureScreenshot(
                tester,
                key,
                '${screen.$1}_${isDark ? 'dark' : 'light'}_${viewport.tag}.png',
              );
            }
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}
