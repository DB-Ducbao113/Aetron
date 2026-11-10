import 'dart:async';

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_card.dart';
import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_cockpit.dart';
import 'package:fitness_exercise_application/features/activity/presentation/widgets/kinetic_activity_top_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const List<ActivityOptionItem> _kActivities = [
  ActivityOptionItem(
    type: 'running',
    nameVi: 'Chạy bộ',
    nameEn: 'Running',
    imagePath: 'assets/activity_running_bright.jpg',
    icon: BladeIconName.run,
    accentColor: Color(0xFFA8DCE7),
    requireGps: true,
  ),
  ActivityOptionItem(
    type: 'cycling',
    nameVi: 'Đạp xe',
    nameEn: 'Cycling',
    imagePath: 'assets/activity_cycling_bright.jpg',
    icon: BladeIconName.bike,
    accentColor: Color(0xFF39B5F2),
    requireGps: true,
  ),
  ActivityOptionItem(
    type: 'walking',
    nameVi: 'Đi bộ',
    nameEn: 'Walking',
    imagePath: 'assets/activity_walking_bright.jpg',
    icon: BladeIconName.walk,
    accentColor: Color(0xFF4EBE9E),
    requireGps: true,
  ),
];

final selectedActivityTypeProvider = StateProvider<String>((ref) => 'running');

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with WidgetsBindingObserver {
  String _selectedType = 'running';
  final WorkoutTarget _selectedTarget = WorkoutTarget.free;
  bool _isRefreshing = false;

  bool get _isOutdoor => _selectedOption.requireGps;

  bool _gpsEnabled = false;
  bool _checkingLocation = true;
  LocationPermission _permission = LocationPermission.denied;
  LatLng? _currentLocation;
  double? _gpsAccuracyM;

  bool get _hasLocationPermission =>
      _permission == LocationPermission.always ||
      _permission == LocationPermission.whileInUse;

  ActivityOptionItem get _selectedOption => _kActivities.firstWhere(
        (a) => a.type == _selectedType,
        orElse: () => _kActivities.first,
      );

  @override
  void initState() {
    super.initState();
    _selectedType = ref.read(selectedActivityTypeProvider);
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus(requestIfNeeded: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus(requestIfNeeded: false);
    }
  }

  Future<void> _refreshLocationStatus({bool requestIfNeeded = false}) async {
    if (!mounted) return;
    setState(() => _checkingLocation = true);

    try {
      final gpsEnabled =
          kIsWeb ? true : await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestIfNeeded) {
        permission = await Geolocator.requestPermission();
      }

      double? accuracy;
      LatLng? location = _currentLocation;

      if (gpsEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse)) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          location = LatLng(pos.latitude, pos.longitude);
          accuracy = pos.accuracy;
        }
      }

      if (!mounted) return;
      setState(() {
        _gpsEnabled = gpsEnabled;
        _permission = permission;
        _currentLocation = location;
        _gpsAccuracyM = accuracy;
        _checkingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingLocation = false);
    }
  }

  Future<void> _handleGpsAction() async {
    HapticFeedback.lightImpact();
    if (!_gpsEnabled && !kIsWeb) {
      await Geolocator.openLocationSettings();
      await _refreshLocationStatus();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    } else if (permission == LocationPermission.deniedForever && !kIsWeb) {
      await Geolocator.openAppSettings();
    }

    await _refreshLocationStatus();
  }

  void _showMapPreviewDialog(AppLanguage currentLang) {
    HapticFeedback.lightImpact();
    final colors = context.kinetic;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KineticTokens.radiusXXL),
              ),
              border: Border(
                top: BorderSide(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KineticTokens.page,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          BladeIcon(
                            BladeIconName.gps,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentLang == AppLanguage.vi
                                ? 'VỊ TRÍ GPS XUẤT PHÁT'
                                : 'STARTING GPS PINPOINT',
                            style: KineticTypography.label.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const BladeIcon(BladeIconName.x, size: 24),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(KineticTokens.radiusXL),
                    ),
                    child: TrackingMapWidget(
                      routePoints: const [],
                      activityType: _selectedOption.type,
                      initialPosition: _currentLocation,
                      currentLocation: _currentLocation,
                      followUser: true,
                      recenterRequestId: 1,
                      showRoute: false,
                      currentLang: currentLang,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startWorkout() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordScreen(
          activityType: _selectedOption.type,
          requireGps: _isOutdoor && _selectedOption.requireGps,
          workoutTarget: _selectedTarget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final workoutsAsync = ref.watch(workoutListProvider);
    final workouts = workoutsAsync.valueOrNull ?? const <WorkoutSession>[];

    ref.listen<String>(selectedActivityTypeProvider, (previous, next) {
      if (next != _selectedType && mounted) {
        setState(() {
          _selectedType = next;
        });
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            // 1. Top Header Bar
            KineticActivityTopBar(
              isVi: isVi,
              isOutdoor: _isOutdoor,
              checkingLocation: _checkingLocation,
              hasLocationPermission: _hasLocationPermission,
              gpsEnabled: _gpsEnabled,
              onGpsTap: _handleGpsAction,
              onMapPreviewTap: () => _showMapPreviewDialog(currentLang),
            ),

            // 2. Scrollable Activity Mode Cards with Pull-to-Refresh Grey Skeleton
            Expanded(
              child: RefreshIndicator(
                color: colors.primary,
                backgroundColor: colors.surface2,
                onRefresh: () async {
                  setState(() => _isRefreshing = true);
                  try {
                    await Future.wait([
                      ref.read(workoutListProvider.notifier).refresh(),
                      _refreshLocationStatus(requestIfNeeded: false),
                    ]);
                  } finally {
                    if (mounted) setState(() => _isRefreshing = false);
                  }
                },
                child: _isRefreshing
                    ? KineticSkeleton.activity()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          KineticTokens.page,
                          KineticTokens.spaceXS,
                          KineticTokens.page,
                          KineticTokens.spaceMD,
                        ),
                        itemCount: _kActivities.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: KineticTokens.spaceSM),
                        itemBuilder: (context, index) {
                          final option = _kActivities[index];
                          final isSelected = option.type == _selectedType;

                          return KineticActivityCard(
                            option: option,
                            isSelected: isSelected,
                            workouts: workouts,
                            isVi: isVi,
                            onSelect: () {
                              setState(() {
                                _selectedType = option.type;
                              });
                              ref
                                  .read(selectedActivityTypeProvider.notifier)
                                  .state = option.type;
                            },
                          );
                        },
                      ),
              ),
            ),

            // 4. Cockpit Tray Dock (GPS Diagnostics & Start Button)
            KineticActivityCockpit(
              activityName: isVi ? _selectedOption.nameVi : _selectedOption.nameEn,
              isOutdoor: true,
              gpsEnabled: _gpsEnabled,
              checkingLocation: _checkingLocation,
              hasLocationPermission: _hasLocationPermission,
              gpsAccuracyM: _gpsAccuracyM,
              selectedTarget: _selectedTarget,
              isVi: isVi,
              onRefreshGps: _handleGpsAction,
              onStartTap: _startWorkout,
              onMapPreviewTap: () => _showMapPreviewDialog(currentLang),
            ),
          ],
        ),
      ),
    );
  }
}
