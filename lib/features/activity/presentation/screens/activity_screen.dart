import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_target.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/tracking_map_widget.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/native_liquid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _ActivityOption {
  const _ActivityOption({
    required this.type,
    required this.nameVi,
    required this.nameEn,
    required this.icon,
    required this.requireGps,
  });

  final String type;
  final String nameVi;
  final String nameEn;
  final BladeIconName icon;
  final bool requireGps;
}

const List<_ActivityOption> _kActivities = [
  _ActivityOption(
    type: 'running',
    nameVi: 'Chạy bộ',
    nameEn: 'Running',
    icon: BladeIconName.run,
    requireGps: true,
  ),
  _ActivityOption(
    type: 'cycling',
    nameVi: 'Đạp xe',
    nameEn: 'Cycling',
    icon: BladeIconName.bike,
    requireGps: true,
  ),
  _ActivityOption(
    type: 'walking',
    nameVi: 'Đi bộ',
    nameEn: 'Walking',
    icon: BladeIconName.walk,
    requireGps: true,
  ),
];

final selectedActivityTypeProvider = StateProvider<String>((ref) => 'running');

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.showMapTiles = true});

  final bool showMapTiles;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with WidgetsBindingObserver {
  String _selectedType = 'running';
  final WorkoutTarget _selectedTarget = WorkoutTarget.free;
  int _recenterCount = 0;

  bool get _isOutdoor => _selectedOption.requireGps;

  bool _gpsEnabled = false;
  bool _checkingLocation = true;
  LocationPermission _permission = LocationPermission.denied;
  LatLng? _currentLocation;
  double? _gpsAccuracyM;

  bool get _hasLocationPermission =>
      _permission == LocationPermission.always ||
      _permission == LocationPermission.whileInUse;

  _ActivityOption get _selectedOption => _kActivities.firstWhere(
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
      if (kDebugBypassAuth) {
        if (!mounted) return;
        setState(() {
          _gpsEnabled = true;
          _permission = LocationPermission.whileInUse;
          _gpsAccuracyM = 4.2;
          _currentLocation = const LatLng(10.7769, 106.7009);
          _checkingLocation = false;
        });
        return;
      }

      final gpsEnabled = kIsWeb
          ? true
          : await Geolocator.isLocationServiceEnabled();
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

  void _selectSport(String type) {
    if (_selectedType == type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = type;
    });
    ref.read(selectedActivityTypeProvider.notifier).state = type;
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

  String _startButtonLabel(bool isVi) {
    switch (_selectedOption.type) {
      case 'cycling':
        return isVi ? 'Bắt đầu đạp xe' : 'Start Cycling';
      case 'walking':
        return isVi ? 'Bắt đầu đi bộ' : 'Start Walking';
      case 'running':
      default:
        return isVi ? 'Bắt đầu chạy bộ' : 'Start Running';
    }
  }

  String _gpsBadgeLabel(bool isVi) {
    if (_checkingLocation) {
      return isVi ? 'Đang dò GPS' : 'Locating GPS';
    }
    if (_gpsEnabled && _hasLocationPermission) {
      final acc = _gpsAccuracyM;
      if (acc != null && acc > 0 && acc < 100) {
        return isVi
            ? 'GPS tốt • ${acc.round()}m'
            : 'GPS ready • ${acc.round()}m';
      }
      return isVi ? 'GPS sẵn sàng' : 'GPS ready';
    }
    return isVi ? 'Bật GPS' : 'Enable GPS';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final isGpsReady = _gpsEnabled && _hasLocationPermission;

    ref.listen<String>(selectedActivityTypeProvider, (previous, next) {
      if (next != _selectedType && mounted) {
        setState(() {
          _selectedType = next;
        });
      }
    });

    final gpsColor = _checkingLocation
        ? colors.primary
        : (isGpsReady ? colors.success : const Color(0xFFF59E0B));
    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);
    final dockFootprint = AetronBottomBar.bottomFootprintOf(context);
    final isCompactHeight = MediaQuery.sizeOf(context).height < 700;
    final sheetBottomGap = dockFootprint + (isCompactHeight ? 8.0 : 10.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Full-bleed live start map
          Positioned.fill(
            child: TrackingMapWidget(
              routePoints: const [],
              activityType: _selectedOption.type,
              initialPosition: _currentLocation,
              currentLocation: _currentLocation,
              followUser: true,
              recenterRequestId: _recenterCount,
              showRoute: false,
              currentLang: currentLang,
              showControls: false,
              enableTilt: false,
              showMapTiles: widget.showMapTiles,
            ),
          ),

          // Subtle top gradient scrim in dark mode so white status bar text stays legible
          if (colors.isDark)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + 54,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x990A1320),
                        Color(0x380A1320),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 2. Top floating pills (Active Sport + GPS Readiness)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  isCompactHeight ? 8 : KineticTokens.spaceSM,
                  hPad,
                  0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusPill,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            key: const Key('activity-top-sport-pill'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: colors.isDark
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0x38344D6D),
                                        Color(0x28183252),
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xD9FFFFFF),
                                        Color(0x4D4EABE7),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(
                                KineticTokens.radiusPill,
                              ),
                              boxShadow: colors.isDark
                                  ? KineticTokens.shadowCardDark()
                                  : KineticTokens.shadowCardLight(),
                              border: Border.all(
                                color: colors.isDark
                                    ? const Color(0x4DB6DCFF)
                                    : Colors.white.withValues(alpha: 0.90),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BladeIcon(
                                  _selectedOption.icon,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isVi
                                        ? _selectedOption.nameVi
                                        : _selectedOption.nameEn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KineticTypography.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          key: const Key('activity-gps-pill'),
                          onTap: isGpsReady
                              ? () => _refreshLocationStatus(requestIfNeeded: true)
                              : _handleGpsAction,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              KineticTokens.radiusPill,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  gradient: colors.isDark
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0x38344D6D),
                                            Color(0x28183252),
                                          ],
                                        )
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xD9FFFFFF),
                                            Color(0x4D4EABE7),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    KineticTokens.radiusPill,
                                  ),
                                  boxShadow: colors.isDark
                                  ? KineticTokens.shadowCardDark()
                                  : KineticTokens.shadowCardLight(),
                              border: Border.all(
                                color: colors.isDark
                                    ? gpsColor.withValues(alpha: 0.55)
                                    : Colors.white.withValues(alpha: 0.90),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: gpsColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _gpsBadgeLabel(isVi),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KineticTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                        const SizedBox(width: 8),
                        KineticGlassIconButton(
                          label: 'GPS',
                          size: 37,
                          visualSize: 37,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _recenterCount++);
                            _refreshLocationStatus(requestIfNeeded: true);
                          },
                          icon: BladeIcon(
                            BladeIconName.pin,
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Glassline Start Sheet (above bottom dock) + Map Controls
          Positioned(
            left: hPad,
            right: hPad,
            bottom: sheetBottomGap,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: isCompactHeight ? 8 : KineticTokens.spaceSM,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AetronMapTypeBuilder(
                            builder: (context, mapType) {
                              final isSatellite = mapType == AppMapType.satellite;
                              return _MapCircleControlButton(
                                buttonKey: const Key('activity-map-layer-btn'),
                                tooltip: isVi
                                    ? (isSatellite
                                          ? 'Kiểu bản đồ: Vệ tinh'
                                          : 'Kiểu bản đồ: Đường phố')
                                    : (isSatellite
                                          ? 'Map style: Satellite'
                                          : 'Map style: Streets'),
                                isHighlighted: isSatellite,
                                onTap: () => showAetronMapStylePicker(
                                  context: context,
                                  currentType: mapType,
                                  currentLang: currentLang,
                                ),
                                child: BladeIcon(
                                  BladeIconName.layers,
                                  size: 18,
                                  color: isSatellite
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: KineticTokens.spaceSM),
                          _MapCircleControlButton(
                            buttonKey: const Key('activity-recenter-btn'),
                            tooltip: isVi
                                ? 'Định vị vị trí hiện tại'
                                : 'Recenter map',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _recenterCount++);
                              _refreshLocationStatus(requestIfNeeded: true);
                            },
                            child: BladeIcon(
                              BladeIconName.locate,
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    KineticCard(
                      useLiquidGlass: true,
                      borderRadius: 24,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        isCompactHeight ? 12 : 14,
                        16,
                        isCompactHeight ? 12 : 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // 3-sport pill segmented bar
                          if (NativeLiquidGlass.enabledOf(context))
                            SizedBox(
                              height: KineticTokens.segmentedControlHeight,
                              child: NativeGlassSegmentedControl(
                                labels: _kActivities
                                    .map(
                                      (option) =>
                                          isVi ? option.nameVi : option.nameEn,
                                    )
                                    .toList(growable: false),
                                symbols: const [],
                                selectedIndex: _kActivities.indexWhere(
                                  (option) =>
                                      option.type == _selectedOption.type,
                                ),
                                onChanged: (index) {
                                  if (index < 0 ||
                                      index >= _kActivities.length) {
                                    return;
                                  }
                                  _selectSport(_kActivities[index].type);
                                },
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(KineticTokens.spaceXXS),
                              decoration: BoxDecoration(
                                color: colors.surface1,
                                borderRadius: BorderRadius.circular(
                                  KineticTokens.radiusPill,
                                ),
                                border: Border.all(
                                  color: colors.borderSubtle,
                                ),
                              ),
                              child: KineticSlidingSelection(
                                index: _kActivities.indexWhere(
                                  (option) =>
                                      option.type == _selectedOption.type,
                                ),
                                count: _kActivities.length,
                                child: Row(
                                  children: _kActivities.map((option) {
                                    final isSelected =
                                        option.type == _selectedOption.type;
                                    final label =
                                        isVi ? option.nameVi : option.nameEn;
                                    final ios = Theme.of(context).platform ==
                                        TargetPlatform.iOS;
                                    return Expanded(
                                      child: GestureDetector(
                                        key: Key('sport-pill-${option.type}'),
                                        onTap: () => _selectSport(option.type),
                                        child: AnimatedContainer(
                                          duration: KineticTokens.respectingReduceMotion(
                                            context,
                                            KineticTokens.motionTab,
                                          ),
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected && !ios
                                                ? colors.primary
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              KineticTokens.radiusPill,
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: KineticTypography
                                                .segmentedLabel
                                                .copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? (ios
                                                            ? colors.primary
                                                            : colors.onPrimary)
                                                      : colors.textMuted,
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),

                          // Compact shortcut to guided running programs
                          InkWell(
                            borderRadius: BorderRadius.circular(
                              KineticTokens.radiusMD,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RunningProgramsScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.compass,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isVi
                                          ? 'Giáo án luyện tập có hướng dẫn'
                                          : 'Guided training programs',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: KineticTypography.caption.copyWith(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.chevron_right,
                                    size: 16,
                                    color: colors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 8 : 10),

                          // Primary Start CTA
                          KineticButton(
                            label: _startButtonLabel(isVi),
                            icon: LucideIcons.play,
                            onPressed: _startWorkout,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCircleControlButton extends StatelessWidget {
  const _MapCircleControlButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.isHighlighted = false,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: buttonKey,
      child: KineticGlassIconButton(
        label: tooltip,
        icon: child,
        active: isHighlighted,
        size: 37,
        visualSize: 37,
        onPressed: onTap,
      ),
    );
  }
}
