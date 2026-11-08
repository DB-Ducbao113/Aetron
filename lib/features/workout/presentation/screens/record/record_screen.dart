import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/guided_program_hud.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/live_lap_hud_toast.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/workout_3d_countdown_overlay.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/workout_target_progress_hud.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/avatar_providers.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/summary/workout_summary_screen.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:fitness_exercise_application/features/settings/presentation/providers/settings_preferences_providers.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/locate_button.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/core/services/location_tracking_service.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_permission_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_metrics_hud.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_control_dock.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_workout_stop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class RecordScreen extends ConsumerStatefulWidget {
  final String activityType;
  final bool requireGps;
  final StructuredRunningProgram? guidedProgram;
  final WorkoutTarget? workoutTarget;

  const RecordScreen({
    super.key,
    required this.activityType,
    this.requireGps = true,
    this.guidedProgram,
    this.workoutTarget,
  });

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  String? _navigatedSessionId;
  static const int _kStartupCountdownSeconds = 3;
  bool _isLargeMetricsMode = false;
  bool _isScreenLocked = false;
  Timer? _startupCountdownTimer;
  int _startupCountdown = _kStartupCountdownSeconds;
  bool _isPreparingWorkout = true;
  bool _isLockingStartupGps = false;
  bool _hasStartedWorkout = false;
  bool _hasSkippedGpsLock = false;
  Completer<Position?>? _skipGpsLockCompleter;
  Future<Position?>? _startupGpsLockFuture;

  int _guidedStepIndex = 0;
  int _stepElapsedSeconds = 0;
  int _lastHandledDuration = 0;
  bool _isGuidedProgramCompleted = false;

  WorkoutLapSplit? _activeToastSplit;
  WorkoutLapSplit? _activeToastPrevSplit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWorkout());
  }

  @override
  void dispose() {
    _startupCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startWorkout() async {
    _startupCountdownTimer?.cancel();
    _startupGpsLockFuture = null;
    _hasSkippedGpsLock = false;
    _skipGpsLockCompleter = Completer<Position?>();
    if (mounted) {
      setState(() {
        _isPreparingWorkout = true;
        _isLockingStartupGps = false;
        _hasStartedWorkout = false;
        _startupCountdown = _kStartupCountdownSeconds;
      });
    }

    final notifier = ref.read(workoutSessionProvider.notifier);
    try {
      if (widget.requireGps) {
        final locationService = ref.read(locationTrackingServiceProvider);
        await locationService.ensurePermissionsOrThrow();
        _startupGpsLockFuture = locationService.acquireStartupLock(
          activityType: widget.activityType,
          maxWait: const Duration(seconds: 6),
        );
      }
      // Motion permission is required for both indoor workouts and
      // GPS activities that may fall back to step tracking.
      await _ensureMotionPermissionOrThrow();
    } catch (e) {
      if (mounted) {
        _showStartError(e.toString().replaceAll('Exception: ', ''));
      }
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      final profileAsync = ref.read(userProfileProvider(userId));
      if (profileAsync.hasValue && profileAsync.value != null) {
        final profile = profileAsync.value!;
        notifier.setUserProfile(
          weightKg: profile.weightKg,
          heightCm: profile.heightCm,
          gender: profile.gender,
        );
      } else {
        // Fetch asynchronously in background without blocking the countdown timer
        ref
            .read(userProfileProvider(userId).future)
            .then((profile) {
              if (profile != null) {
                notifier.setUserProfile(
                  weightKg: profile.weightKg,
                  heightCm: profile.heightCm,
                  gender: profile.gender,
                );
              }
            })
            .catchError((_) {});
      }
    }

    _startupCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_startupCountdown <= 1) {
        timer.cancel();
        unawaited(_startAfterCountdown(notifier));
        return;
      }

      setState(() {
        _startupCountdown -= 1;
      });
    });
  }

  Future<void> _startAfterCountdown(WorkoutSessionNotifier notifier) async {
    if (!mounted || _hasStartedWorkout) return;
    setState(() {
      _startupCountdown = 0;
      _isPreparingWorkout = false;
      _isLockingStartupGps = false;
      _hasStartedWorkout = true;
    });

    Position? startupGpsLock;
    if (widget.requireGps) {
      if (_hasSkippedGpsLock) {
        try {
          startupGpsLock = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      } else {
        final gpsFuture = _startupGpsLockFuture;
        if (gpsFuture != null) {
          try {
            startupGpsLock = await gpsFuture.timeout(
              const Duration(milliseconds: 600),
              onTimeout: () => null,
            );
          } catch (_) {}
        }
      }
    }

    if (!mounted) return;
    notifier.startWorkout(widget.activityType, startupGpsLock: startupGpsLock);
  }

  void _skipCountdown() {
    _hasSkippedGpsLock = true;
    _startupCountdownTimer?.cancel();
    if (_skipGpsLockCompleter != null && !_skipGpsLockCompleter!.isCompleted) {
      _skipGpsLockCompleter!.complete(null);
    }
    final notifier = ref.read(workoutSessionProvider.notifier);
    unawaited(_startAfterCountdown(notifier));
  }

  Future<void> _ensureMotionPermissionOrThrow() async {
    if (kIsWeb) return;

    final permission = Theme.of(context).platform == TargetPlatform.iOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return;

    final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
    if (!mounted ||
        !await showAetronPermissionSheet(
          context,
          kind: AetronPermissionKind.motion,
          isVietnamese: isVi,
        )) {
      throw Exception('activity_permission_denied');
    }

    final requested = await permission.request();
    if (requested.isGranted || requested.isLimited) return;
    if (requested.isPermanentlyDenied || requested.isRestricted) {
      throw Exception('activity_permission_denied_forever');
    }
    throw Exception('activity_permission_denied');
  }

  void _showStartError(String code) {
    final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
    String title;
    String message;
    String actionLabel;
    Future<void> Function() onAction;
    Widget? secondaryAction;

    switch (code) {
      case 'location_disabled':
        title = isVi ? 'GPS Đang Tắt' : 'GPS is Off';
        message = isVi
            ? 'Dịch vụ định vị đang bị tắt. Vui lòng bật GPS trên máy để ghi nhận lộ trình buổi tập.'
            : (kIsWeb
                  ? 'Location services are disabled in your browser. Please allow location access for this site.'
                  : 'Location services are disabled. Please enable GPS and try again.');
        actionLabel = isVi
            ? (kIsWeb ? 'Thử Lại' : 'Mở Cài Đặt')
            : (kIsWeb ? 'Try Again' : 'Open Settings');
        onAction = () async {
          if (!kIsWeb) {
            await Geolocator.openLocationSettings();
          }
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'permission_denied':
        title = isVi ? 'Cần Quyền Vị Trí' : 'Location Permission Needed';
        message = isVi
            ? 'Ứng dụng cần quyền vị trí để vẽ bản đồ và đo quãng đường chạy. Vui lòng cấp quyền truy cập vị trí.'
            : 'Location permission is required to track your workout. Open Settings and allow location access.';
        actionLabel = isVi
            ? (kIsWeb ? 'Thử Lại' : 'Mở Cài Đặt')
            : (kIsWeb ? 'Try Again' : 'Open Settings');
        onAction = () async {
          if (!kIsWeb) {
            await Geolocator.openAppSettings();
          }
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'permission_denied_forever':
        title = isVi ? 'Quyền Vị Trí Bị Chặn' : 'Permission Blocked';
        message = isVi
            ? 'Quyền truy cập vị trí đang bị chặn vĩnh viễn. Vui lòng mở Cài đặt ứng dụng > Quyền > Vị trí để bật lại.'
            : 'Location is permanently blocked. Open App Settings > Permissions > Location.';
        actionLabel = isVi ? 'Mở Cài Đặt' : 'Open Settings';
        onAction = () async {
          if (!kIsWeb) {
            await Geolocator.openAppSettings();
          }
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'activity_permission_denied':
      case 'activity_permission_denied_forever':
        title = isVi ? 'Cần Quyền Cảm Biến Bước' : 'Motion Permission Needed';
        message = isVi
            ? 'Ứng dụng cần quyền nhận diện chuyển động để đếm bước chân và ước tính calo khi GPS yếu.'
            : 'Motion access is needed so indoor fallback can count your steps when GPS is weak.';
        actionLabel = isVi ? 'Mở Cài Đặt' : 'Open Settings';
        onAction = () async {
          await openAppSettings();
          if (!mounted) return;
          await _startWorkout();
        };
        break;
      case 'gps_startup_lock_failed':
        title = isVi ? 'Chưa Bắt Được Tín Hiệu GPS' : 'GPS Signal Needed';
        message = isVi
            ? 'Không thể kết nối vệ tinh GPS lúc này. Bạn có thể di chuyển ra nơi thoáng hơn để thử lại, hoặc bắt đầu tập ngay bằng cảm biến bước chân.'
            : 'Could not connect to GPS satellites. Move to an open area to try again, or start tracking now using step sensors.';
        actionLabel = isVi ? 'Thử Lại' : 'Try Again';
        onAction = () async {
          if (!mounted) return;
          await _startWorkout();
        };
        secondaryAction = TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            setState(() {
              _isPreparingWorkout = false;
              _isLockingStartupGps = false;
            });
            _hasStartedWorkout = true;
            ref
                .read(workoutSessionProvider.notifier)
                .startWorkout(widget.activityType, startupGpsLock: null);
          },
          child: Text(
            isVi ? 'Tập bằng bước chân' : 'Start with Steps',
            style: TextStyle(
              color: context.kinetic.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        break;
      default:
        title = isVi ? 'Không Thể Bắt Đầu' : 'Could Not Start';
        message = isVi
            ? 'Đã xảy ra sự cố khi chuẩn bị thiết bị cảm biến. Vui lòng kiểm tra lại quyền và thử lại.'
            : 'An issue occurred while initializing motion and GPS sensors. Please check permissions and try again.';
        actionLabel = isVi ? 'Đóng' : 'Back';
        onAction = () async {
          Navigator.of(context).pop();
        };
        break;
    }

    final colors = context.kinetic;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticTokens.radiusXL),
          side: BorderSide(color: colors.borderSubtle),
        ),
        title: Text(
          title,
          style: KineticTypography.headlineSmall.copyWith(
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: KineticTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              isVi ? 'Hủy bỏ' : 'Cancel',
              style: TextStyle(color: colors.textMuted),
            ),
          ),
          ?secondaryAction,
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _onLocatePressed() {
    final didRequest = ref
        .read(workoutSessionProvider.notifier)
        .requestRecenter();
    if (didRequest) return;

    final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi ? 'Đang đợi tín hiệu GPS...' : 'Waiting for GPS fix...',
        ),
      ),
    );
  }

  Future<void> _confirmStop() async {
    final isVi = ref.read(appLanguageProvider) == AppLanguage.vi;
    final useMetricUnits =
        ref.read(metricUnitsPreferenceProvider).value ?? true;
    final state = ref.read(workoutSessionProvider);

    final confirmed = await showKineticWorkoutStopConfirmation(
      context,
      distanceMeters: state.distanceMeters,
      durationSeconds: state.durationSeconds,
      caloriesBurned: state.caloriesBurned,
      speedKmh: state.speedKmh,
      activityType: widget.activityType,
      useMetricUnits: useMetricUnits,
      isVi: isVi,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(workoutSessionProvider.notifier).stopWorkout();
        if (mounted) {
          final currentState = ref.read(workoutSessionProvider);
          if (currentState.status == RecordingState.finished) {
            _openSummary(currentState);
          }
        }
      } catch (e) {
        debugPrint('[RecordScreen] Error stopping workout: $e');
      }
    }
  }

  void _handlePauseResume(RecordingState status) {
    final notifier = ref.read(workoutSessionProvider.notifier);
    if (status == RecordingState.paused) {
      notifier.resumeWorkout();
      return;
    }
    if (status == RecordingState.active) {
      notifier.pauseWorkout();
    }
  }

  void _showProgramCompletedModal(
    BuildContext context,
    AppLanguage currentLang,
  ) {
    final colors = context.kinetic;
    final isVi = currentLang == AppLanguage.vi;
    final programTitle = widget.guidedProgram != null
        ? AppTranslations.get(widget.guidedProgram!.titleKey, currentLang)
        : "";

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KineticTokens.radiusXXL),
            ),
            border: Border(
              top: BorderSide(color: colors.primary, width: 2.0),
            ),
            boxShadow: KineticTokens.shadowPanel(Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2AF598),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isVi ? "HOÀN THÀNH GIÁO ÁN! 🎉" : "PROGRAM COMPLETED! 🎉",
                style: KineticTypography.pageTitle.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVi
                    ? "Bạn đã xuất sắc hoàn thành tất cả các hiệp của giáo án \"$programTitle\". Bạn muốn làm gì tiếp theo?"
                    : "You have successfully completed all steps of \"$programTitle\". What would you like to do next?",
                textAlign: TextAlign.center,
                style: KineticTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              KineticButton(
                label: isVi ? "🏃 TIẾP TỤC CHẠY TỰ DO" : "🏃 CONTINUE FREE RUN",
                variant: KineticButtonVariant.primary,
                onPressed: () {
                  Navigator.of(modalContext).pop();
                },
              ),
              const SizedBox(height: 12),
              KineticButton(
                label: isVi
                    ? "🏁 KẾT THÚC & XEM KẾT QUẢ"
                    : "🏁 FINISH & VIEW SUMMARY",
                variant: KineticButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(modalContext).pop();
                  _confirmStop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSummary(WorkoutSessionState finalState) {
    final sessionId = finalState.sessionId;
    if (!mounted || sessionId == null || sessionId.isEmpty) return;
    if (_navigatedSessionId == sessionId) return;
    _navigatedSessionId = sessionId;

    final effectiveDistanceMeters = finalState.gpsAnalysis.validDistanceKm > 0
        ? finalState.gpsAnalysis.validDistanceKm * 1000.0
        : (finalState.gpsAnalysis.totalDistanceKm > 0
              ? finalState.gpsAnalysis.totalDistanceKm * 1000.0
              : finalState.distanceMeters);

    final routePointCandidates = <List<LatLng>>[
      finalState.filteredRoutePoints,
      finalState.smoothedRoutePoints,
      finalState.routePoints,
    ];
    final summaryRoutePoints = routePointCandidates.firstWhere(
      (points) => points.length >= 2,
      orElse: () => const <LatLng>[],
    );
    final routeSegmentCandidates = <List<List<LatLng>>>[
      finalState.smoothedRouteSegments,
      finalState.routeSegments,
    ];
    final summaryRouteSegments = routeSegmentCandidates
        .map(
          (segments) => segments
              .where((segment) => segment.length >= 2)
              .toList(growable: false),
        )
        .firstWhere(
          (segments) => segments.isNotEmpty,
          orElse: () => const <List<LatLng>>[],
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          sessionId: sessionId,
          activityType: finalState.activityType,
          trackingMode: finalState.trackingMode,
          durationSeconds: finalState.durationSeconds,
          movingTimeSeconds: finalState.movingTimeSeconds,
          distanceMeters: effectiveDistanceMeters,
          avgSpeedKmh: finalState.avgSpeedKmh,
          calories: finalState.caloriesBurned,
          steps: finalState.stepCount,
          gpsAnalysis: finalState.gpsAnalysis,
          routePoints: summaryRoutePoints,
          routeSegments: summaryRouteSegments,
          lapSplits: finalState.lapSplits,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final state = ref.watch(workoutSessionProvider);
    final useMetricUnits =
        ref.watch(metricUnitsPreferenceProvider).value ?? true;

    ref.listen<WorkoutSessionState>(workoutSessionProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _showStartError(next.errorMessage!);
      }
      final didFinishSession =
          next.status == RecordingState.finished &&
          (next.sessionId ?? '').isNotEmpty &&
          prev?.status != RecordingState.finished;
      if (didFinishSession) {
        _openSummary(next);
      }

      // Check for new lap split alert
      if (next.status == RecordingState.active &&
          next.lapSplits.length > (prev?.lapSplits.length ?? 0) &&
          next.lapSplits.isNotEmpty) {
        setState(() {
          _activeToastSplit = next.lapSplits.last;
          _activeToastPrevSplit = next.lapSplits.length >= 2
              ? next.lapSplits[next.lapSplits.length - 2]
              : null;
        });
      }
    });

    final avatar = ref.watch(currentAvatarDisplayProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final ImageProvider? avatarImage = avatar.imageProvider;
    final initials = user?.email?.isNotEmpty == true
        ? user!.email!.substring(0, 1).toUpperCase()
        : 'A';

    final hasGuidedProgram =
        widget.guidedProgram != null && !_isGuidedProgramCompleted;
    final hasTargetHud =
        widget.workoutTarget != null &&
        widget.workoutTarget!.type != WorkoutTargetType.none;
    final double mapTopControlOffset =
        (hasGuidedProgram || _activeToastSplit != null)
        ? (MediaQuery.of(context).padding.top + 225.0)
        : hasTargetHud
        ? (MediaQuery.of(context).padding.top + 130.0)
        : (MediaQuery.of(context).padding.top + 72.0);

    // Guided Running Program Step Progression
    final program = widget.guidedProgram;
    if (program != null &&
        !_isGuidedProgramCompleted &&
        state.status == RecordingState.active &&
        !_isPreparingWorkout) {
      if (state.durationSeconds > _lastHandledDuration) {
        final diff = state.durationSeconds - _lastHandledDuration;
        _lastHandledDuration = state.durationSeconds;
        _stepElapsedSeconds += diff;

        while (_guidedStepIndex < program.steps.length &&
            _stepElapsedSeconds >=
                program.steps[_guidedStepIndex].durationSeconds) {
          final stepDur = program.steps[_guidedStepIndex].durationSeconds;
          if (_guidedStepIndex < program.steps.length - 1) {
            _stepElapsedSeconds -= stepDur;
            _guidedStepIndex++;
            HapticFeedback.heavyImpact();
          } else {
            _stepElapsedSeconds = stepDur;
            _isGuidedProgramCompleted = true;
            HapticFeedback.vibrate();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showProgramCompletedModal(context, currentLang);
            });
            break;
          }
        }
      }
    } else if (state.durationSeconds > _lastHandledDuration) {
      _lastHandledDuration = state.durationSeconds;
    }

    final shouldShowGpsRoute =
        state.routePoints.length >= 2 || state.trackingMode != kIndoorMode;
    final isRecording =
        state.status == RecordingState.active ||
        state.status == RecordingState.paused;
    final canToggle = isRecording;
    final isPaused = state.status == RecordingState.paused;
    final isSaving = state.status == RecordingState.stopping;
    final bottomDockHeight = 74.0 + MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmStop();
        }
      },
      child: Scaffold(
        backgroundColor: context.kinetic.background,
        body: Stack(
          children: [
            // 1. Full-screen Tracking Map View
            Positioned.fill(
              child: TrackingMapWidget(
                routePoints: state.smoothedRoutePoints.isNotEmpty
                    ? state.smoothedRoutePoints
                    : state.routePoints,
                routeSegments: state.smoothedRouteSegments.isNotEmpty
                    ? state.smoothedRouteSegments
                    : state.routeSegments,
                activityType: widget.activityType,
                initialPosition: state.initialPosition,
                currentLocation:
                    state.smoothedCurrentLatLng ?? state.currentLatLng,
                gpsGapMarker: state.gpsGapMarker,
                gpsGapSegments: state.gpsGapSegments,
                isGpsSignalWeak: state.isGpsSignalWeak,
                followUser: state.followUser,
                recenterRequestId: state.recenterRequestId,
                showRoute: shouldShowGpsRoute,
                avatarImage: avatarImage,
                initials: initials,
                currentLang: currentLang,
                topControlOffset: mapTopControlOffset,
                onUserGesturePan: () {
                  ref.read(workoutSessionProvider.notifier).onUserDraggedMap();
                },
              ),
            ),

            // 1b. Map legibility scrims — decoration only, never hit-tested.
            // HUD content (top bar, mini card, dock) sits on these.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KineticGradients.scrimTop(context.kinetic),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KineticGradients.scrimBottom(context.kinetic),
                  ),
                ),
              ),
            ),

            // 2. Full-screen Big Metrics View (Animated smooth crossfade)
            if (!_isPreparingWorkout)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isLargeMetricsMode ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !_isLargeMetricsMode,
                    child: Container(
                      color: context.kinetic.background,
                      child: SafeArea(
                        bottom: false,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            64, // Space below top bar
                            16,
                            bottomDockHeight +
                                16, // Space above fixed bottom dock
                          ),
                          children: [
                            _CompactRecordingHud(
                              state: state,
                              activityType: widget.activityType,
                              useMetricUnits: useMetricUnits,
                              isLargeMetricsMode: _isLargeMetricsMode,
                              guidedProgram: widget.guidedProgram,
                              guidedStepIndex: _guidedStepIndex,
                              stepRemainingSeconds:
                                  (widget.guidedProgram != null &&
                                      _guidedStepIndex <
                                          widget.guidedProgram!.steps.length)
                                  ? (widget
                                                .guidedProgram!
                                                .steps[_guidedStepIndex]
                                                .durationSeconds -
                                            _stepElapsedSeconds)
                                        .clamp(0, 999999)
                                  : 0,
                              isGuidedProgramCompleted:
                                  _isGuidedProgramCompleted,
                              workoutTarget: widget.workoutTarget,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Kinetic Live Top Bar
            if (!_isPreparingWorkout)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: KineticLiveTopBar(
                  activityType: widget.activityType,
                  isOutdoor: state.trackingMode != kIndoorMode,
                  isGpsWeak: state.isGpsSignalWeak,
                  isAutoPaused: state.isAutoPaused,
                  isPaused: state.status == RecordingState.paused,
                  pausedCountdownSeconds: state.pausedAutoStopRemainingSeconds,
                  isLargeMetricsMode: _isLargeMetricsMode,
                  isVi: currentLang == AppLanguage.vi,
                  onToggleMetricsMode: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isLargeMetricsMode = !_isLargeMetricsMode;
                    });
                  },
                ),
              ),

            // 4. Top Floating HUDs (Guided Program, Target Progress, Live Lap Split)
            // Visible in Map Mode when not in large metrics view
            if (!_isPreparingWorkout && !_isLargeMetricsMode)
              Positioned(
                top: MediaQuery.of(context).padding.top + 68,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Builder(
                    builder: (context) {
                      // 1. Live Lap Toast takes highest top-banner priority
                      if (_activeToastSplit != null) {
                        return LiveLapHudToast(
                          split: _activeToastSplit!,
                          previousSplit: _activeToastPrevSplit,
                          useMetricUnits: useMetricUnits,
                          currentLang: currentLang,
                          onDismiss: () {
                            if (mounted) {
                              setState(() => _activeToastSplit = null);
                            }
                          },
                        );
                      }

                      // 2. Guided Program Coach HUD
                      if (widget.guidedProgram != null &&
                          !_isGuidedProgramCompleted) {
                        return GuidedProgramHud(
                          program: widget.guidedProgram!,
                          currentStepIndex: _guidedStepIndex,
                          stepRemainingSeconds:
                              (_guidedStepIndex <
                                  widget.guidedProgram!.steps.length)
                              ? (widget
                                            .guidedProgram!
                                            .steps[_guidedStepIndex]
                                            .durationSeconds -
                                        _stepElapsedSeconds)
                                    .clamp(0, 999999)
                              : 0,
                          stepElapsedSeconds: _stepElapsedSeconds,
                          currentPaceMinSecKm: state.speedKmh > 0.5
                              ? (3600.0 / state.speedKmh)
                              : 0.0,
                          currentLang: currentLang,
                          onSkipStep: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (_guidedStepIndex <
                                  widget.guidedProgram!.steps.length - 1) {
                                _guidedStepIndex++;
                                _stepElapsedSeconds = 0;
                              } else {
                                _isGuidedProgramCompleted = true;
                                _showProgramCompletedModal(
                                  context,
                                  currentLang,
                                );
                              }
                            });
                          },
                        );
                      }

                      // 3. Live Workout Target Progress HUD
                      if (widget.workoutTarget != null &&
                          widget.workoutTarget!.type !=
                              WorkoutTargetType.none) {
                        return WorkoutTargetProgressHud(
                          target: widget.workoutTarget!,
                          distanceMeters: state.distanceMeters,
                          durationSeconds: state.durationSeconds,
                          calories: state.caloriesBurned,
                          currentLang: currentLang,
                          accentColor: _activityAccent(widget.activityType),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

            // 5. Locate Button (Map Mode only)
            if (!_isPreparingWorkout && !_isLargeMetricsMode)
              Positioned(
                right: 16,
                bottom: bottomDockHeight + 82,
                child: LocateButton(
                  isFollowEnabled: state.followUser,
                  onPressed: _onLocatePressed,
                  isVi: currentLang == AppLanguage.vi,
                ),
              ),

            // 6. Floating Mini Telemetry Card (Map Mode only - Shows live distance, clock, pace, calories!)
            if (!_isPreparingWorkout && !_isLargeMetricsMode)
              Positioned(
                left: 14,
                right: 14,
                bottom: bottomDockHeight + 8,
                child: KineticMiniMetricsCard(
                  distanceMeters: state.distanceMeters,
                  durationSeconds: state.durationSeconds,
                  speedKmh: state.speedKmh,
                  avgSpeedKmh: state.avgSpeedKmh,
                  calories: state.caloriesBurned,
                  activityType: widget.activityType,
                  useMetricUnits: useMetricUnits,
                  isVi: currentLang == AppLanguage.vi,
                  onExpand: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isLargeMetricsMode = true;
                    });
                  },
                ),
              ),

            // 7. FIXED FLOATING CONTROL DOCK (Always visible at bottom!)
            if (!_isPreparingWorkout)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KineticLiveControlDock(
                  isPaused: isPaused,
                  isLocked: _isScreenLocked,
                  isSaving: isSaving,
                  canToggle: canToggle,
                  isVi: currentLang == AppLanguage.vi,
                  onPauseResume: () => _handlePauseResume(state.status),
                  onStop: _confirmStop,
                  onToggleLock: () =>
                      setState(() => _isScreenLocked = !_isScreenLocked),
                ),
              ),
            if (_isScreenLocked)
              Positioned.fill(
                child: Container(
                  color: context.kinetic.background.withValues(alpha: 0.92),
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.kinetic.surface1,
                                border: Border.all(
                                  color: context.kinetic.tertiary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 48,
                                color: context.kinetic.tertiary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'MÀN HÌNH ĐÃ KHÓA'
                                  : 'SCREEN LOCKED',
                              style: KineticTypography.headlineSmall.copyWith(
                                color: context.kinetic.textPrimary,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentLang == AppLanguage.vi
                                  ? 'Chống chạm cảm ứng khi ra mồ hôi hoặc bỏ túi'
                                  : 'Touch-protected against sweat and accidental taps',
                              textAlign: TextAlign.center,
                              style: KineticTypography.bodySmall.copyWith(
                                color: context.kinetic.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),
                            KineticButton(
                              label: currentLang == AppLanguage.vi
                                  ? 'Chạm để mở khóa'
                                  : 'Tap to unlock',
                              icon: Icons.lock_open_rounded,
                              variant: KineticButtonVariant.secondary,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                setState(() => _isScreenLocked = false);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isPreparingWorkout)
              Positioned.fill(
                child: Workout3DCountdownOverlay(
                  countdown: _startupCountdown,
                  isLockingGps: _isLockingStartupGps,
                  activityType: widget.activityType,
                  currentLang: currentLang,
                  onSkip: _skipCountdown,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _activityAccent(String type) {
    final colors = context.kinetic;
    switch (type.toLowerCase()) {
      case 'running':
        return colors.secondary;
      default:
        return colors.tertiary;
    }
  }
}

class _CompactRecordingHud extends ConsumerWidget {
  const _CompactRecordingHud({
    required this.state,
    required this.activityType,
    required this.useMetricUnits,
    required this.isLargeMetricsMode,
    this.guidedProgram,
    this.guidedStepIndex = 0,
    this.stepRemainingSeconds = 0,
    this.isGuidedProgramCompleted = false,
    this.workoutTarget,
  });

  final WorkoutSessionState state;
  final String activityType;
  final bool useMetricUnits;
  final bool isLargeMetricsMode;
  final StructuredRunningProgram? guidedProgram;
  final int guidedStepIndex;
  final int stepRemainingSeconds;
  final bool isGuidedProgramCompleted;
  final WorkoutTarget? workoutTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Integrated Guided Program Step Pill when in Large Metrics Mode
        if (guidedProgram != null &&
            !isGuidedProgramCompleted &&
            isLargeMetricsMode &&
            guidedStepIndex < guidedProgram!.steps.length) ...[
          _IntegratedProgramPill(
            step: guidedProgram!.steps[guidedStepIndex],
            stepIndex: guidedStepIndex,
            totalSteps: guidedProgram!.steps.length,
            stepRemainingSeconds: stepRemainingSeconds,
            isVi: isVi,
          ),
          const SizedBox(height: 10),
        ],

        // Integrated Workout Target Pill when in Large Metrics Mode
        if (workoutTarget != null &&
            workoutTarget!.type != WorkoutTargetType.none &&
            guidedProgram == null &&
            isLargeMetricsMode) ...[
          _IntegratedTargetPill(
            target: workoutTarget!,
            distanceMeters: state.distanceMeters,
            durationSeconds: state.durationSeconds,
            calories: state.caloriesBurned,
            isVi: isVi,
          ),
          const SizedBox(height: 10),
        ],

        KineticLiveMetricsHud(
          distanceMeters: state.distanceMeters,
          durationSeconds: state.durationSeconds,
          movingTimeSeconds: state.movingTimeSeconds,
          speedKmh: state.speedKmh,
          avgSpeedKmh: state.avgSpeedKmh,
          calories: state.caloriesBurned,
          stepCount: state.stepCount,
          activityType: activityType,
          useMetricUnits: useMetricUnits,
          isVi: isVi,
          isLargeMetricsMode: isLargeMetricsMode,
        ),
      ],
    );
  }
}

class _IntegratedProgramPill extends StatelessWidget {
  final ProgramStep step;
  final int stepIndex;
  final int totalSteps;
  final int stepRemainingSeconds;
  final bool isVi;

  const _IntegratedProgramPill({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.stepRemainingSeconds,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (stepRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (stepRemainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: step.phaseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: step.phaseColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(step.phaseIcon, size: 16, color: step.phaseColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${isVi ? "Hiệp" : "Step"} ${stepIndex + 1}/$totalSteps: ${isVi ? step.titleVi : step.titleEn}',
              style: KineticTypography.unitLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: step.phaseColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
            ),
            child: Text(
              '$minutes:$seconds',
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: KineticTypography.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegratedTargetPill extends StatelessWidget {
  final WorkoutTarget target;
  final double distanceMeters;
  final int durationSeconds;
  final int calories;
  final bool isVi;

  const _IntegratedTargetPill({
    required this.target,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.calories,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    String targetLabel = '';
    String remainingLabel = '';

    switch (target.type) {
      case WorkoutTargetType.distance:
        final currentKm = distanceMeters / 1000.0;
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toStringAsFixed(1)} km'
            : 'Target: ${target.value.toStringAsFixed(1)} km';
        final remainingKm = (target.value - currentKm).clamp(0.0, target.value);
        remainingLabel = isVi
            ? (remainingKm <= 0
                  ? 'Hoàn thành!'
                  : 'Còn ${remainingKm.toStringAsFixed(1)} km')
            : (remainingKm <= 0
                  ? 'Done!'
                  : '${remainingKm.toStringAsFixed(1)} km left');
        break;
      case WorkoutTargetType.duration:
        final targetSec = (target.value * 60).round();
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toInt()} phút'
            : 'Target: ${target.value.toInt()} mins';
        final remainingSec = (targetSec - durationSeconds).clamp(0, targetSec);
        final remMins = (remainingSec / 60).ceil();
        remainingLabel = isVi
            ? (remainingSec <= 0 ? 'Hoàn thành!' : 'Còn $remMins phút')
            : (remainingSec <= 0 ? 'Done!' : '$remMins mins left');
        break;
      case WorkoutTargetType.calories:
        targetLabel = isVi
            ? 'Mục tiêu: ${target.value.toInt()} kcal'
            : 'Target: ${target.value.toInt()} kcal';
        final remKcal = (target.value - calories).clamp(
          0,
          target.value.toInt(),
        );
        remainingLabel = isVi
            ? (remKcal <= 0 ? 'Hoàn thành!' : 'Còn $remKcal kcal')
            : (remKcal <= 0 ? 'Done!' : '$remKcal kcal left');
        break;
      case WorkoutTargetType.none:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.track_changes_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              targetLabel,
              style: KineticTypography.label.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            remainingLabel,
            style: KineticTypography.label.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
