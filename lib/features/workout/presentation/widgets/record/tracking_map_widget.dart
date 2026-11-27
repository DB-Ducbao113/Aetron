import "dart:math" as math;
import "dart:ui" as ui;
import "package:fitness_exercise_application/core/constants/debug_config.dart";
import "package:fitness_exercise_application/core/localization/app_translations.dart";
import "package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart";
import "package:fitness_exercise_application/features/workout/presentation/utils/route_display_sanitizer.dart";
import "package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart";
import "package:fitness_exercise_application/shared/kinetic/blade_icons.dart";
import "package:fitness_exercise_application/shared/kinetic/kinetic.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kAetronMapTypePrefKey = "aetron_preferred_map_type";

enum AppMapType { satellite, streets }

/// Manages the persisted map basemap style across all Aetron map views.
class AppMapTypeNotifier extends StateNotifier<AppMapType> {
  AppMapTypeNotifier() : super(AppMapType.satellite) {
    _initFuture = _loadPreference();
  }

  late final Future<void> _initFuture;
  bool _hasExplicitSelection = false;

  /// Resolves once the initial saved map preference has finished loading.
  @visibleForTesting
  Future<void> get initialized => _initFuture;

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kAetronMapTypePrefKey);
      if (!mounted || saved == null || _hasExplicitSelection) return;
      state = AppMapType.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppMapType.satellite,
      );
    } catch (_) {}
  }

  Future<void> setMapType(AppMapType type) async {
    _hasExplicitSelection = true;
    state = type;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAetronMapTypePrefKey, type.name);
    } catch (_) {}
  }
}

final appMapTypeProvider =
    StateNotifierProvider<AppMapTypeNotifier, AppMapType>((ref) {
      return AppMapTypeNotifier();
    });

/// Returns whether a Riverpod [ProviderScope] is available in [context].
bool hasAetronProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
    return true;
  } catch (_) {
    return false;
  }
}

/// Reads [appMapTypeProvider] when a [ProviderScope] is present, or falls
/// back to [fallbackType] in standalone widget harnesses.
class AetronMapTypeBuilder extends StatelessWidget {
  const AetronMapTypeBuilder({
    super.key,
    this.fallbackType = AppMapType.satellite,
    required this.builder,
  });

  final AppMapType fallbackType;
  final Widget Function(BuildContext context, AppMapType mapType) builder;

  @override
  Widget build(BuildContext context) {
    if (!hasAetronProviderScope(context)) {
      return builder(context, fallbackType);
    }
    return Consumer(
      builder: (context, ref, _) =>
          builder(context, ref.watch(appMapTypeProvider)),
    );
  }
}

/// Opens the unified Satellite / Clean Street Map style selector sheet.
Future<void> showAetronMapStylePicker({
  required BuildContext context,
  required AppMapType currentType,
  required AppLanguage currentLang,
  ValueChanged<AppMapType>? onFallbackSelect,
}) {
  HapticFeedback.lightImpact();
  final hasScope = hasAetronProviderScope(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _MapStylePickerSheet(
      currentType: currentType,
      currentLang: currentLang,
      onSelectType: (type) async {
        if (hasScope) {
          await ProviderScope.containerOf(
            context,
            listen: false,
          ).read(appMapTypeProvider.notifier).setMapType(type);
        }
        onFallbackSelect?.call(type);
        if (sheetContext.mounted) {
          Navigator.of(sheetContext).pop();
        }
      },
    ),
  );
}

class TrackingMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<List<LatLng>> routeSegments;
  final String activityType;
  final LatLng? initialPosition;
  final LatLng? currentLocation;
  final LatLng? gpsGapMarker;
  final List<GpsGapSegment> gpsGapSegments;
  final bool isGpsSignalWeak;
  final bool followUser;
  final int recenterRequestId;
  final bool showRoute;
  final VoidCallback? onUserGesturePan;
  final ImageProvider? avatarImage;
  final String initials;
  final AppLanguage currentLang;
  final double topControlOffset;
  final bool showControls;
  final bool enableTilt;
  final bool showMapTiles;

  const TrackingMapWidget({
    super.key,
    required this.routePoints,
    this.routeSegments = const [],
    required this.activityType,
    this.initialPosition,
    this.currentLocation,
    this.gpsGapMarker,
    this.gpsGapSegments = const [],
    this.isGpsSignalWeak = false,
    this.followUser = true,
    this.recenterRequestId = 0,
    this.showRoute = true,
    this.onUserGesturePan,
    this.avatarImage,
    this.initials = "A",
    this.currentLang = AppLanguage.vi,
    this.topControlOffset = 72,
    this.showControls = true,
    this.enableTilt = true,
    this.showMapTiles = true,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _tiltController;
  late final Animation<double> _tiltAnimation;

  DateTime? _lastCameraMove;
  bool _initialCameraSet = false;
  bool _userAdjustedZoom = false;
  late bool _is3DMode;
  AppMapType _fallbackMapType = AppMapType.satellite;
  bool _checkedLocalPrefs = false;
  List<LatLng> _cachedDisplayRoute = const <LatLng>[];
  List<List<LatLng>> _cachedDisplaySegments = const <List<LatLng>>[];
  int? _zoomBucket;

  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);
  static const double _minMapZoom = 4.0;
  static const double _maxMapZoom = 22.0;

  static Duration get _cameraThrottle => kDebugLocationMode
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 160);

  double _recommendedTrackingZoom() {
    // Indoor / weak-GPS / short walking spaces automatically zoom close in
    // (like Strava) so room-scale or courtyard paths remain clearly readable.
    final isWalking = widget.activityType.toLowerCase() == 'walking';
    final isCycling = widget.activityType.toLowerCase() == 'cycling';
    final isCompactSpan = _isCompactRouteSpan(widget.routePoints);

    if (widget.isGpsSignalWeak || (isWalking && isCompactSpan)) {
      return 19.4;
    }
    if (isWalking) return 18.6;
    if (isCycling) return 16.6;
    return isCompactSpan ? 18.4 : 17.8;
  }

  bool _isCompactRouteSpan(List<LatLng> points) {
    if (points.length < 2) return true;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // ~55m bounding box across either axis counts as compact/indoor scale.
    return (maxLat - minLat) < 0.0005 && (maxLng - minLng) < 0.0005;
  }

  @override
  void initState() {
    super.initState();
    _is3DMode = widget.enableTilt;
    _mapController = MapController();
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.44).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.easeOutCubic),
    );
    if (_is3DMode) {
      _tiltController.value = 1.0;
    }
    _refreshDisplayRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedLocalPrefs) {
      _checkedLocalPrefs = true;
      if (!hasAetronProviderScope(context)) {
        _loadSavedPreferences();
      }
    }
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kAetronMapTypePrefKey);
      if (saved != null && mounted) {
        setState(() {
          _fallbackMapType = AppMapType.values.firstWhere(
            (e) => e.name == saved,
            orElse: () => AppMapType.satellite,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  void _toggle3DMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _is3DMode = !_is3DMode;
      if (_is3DMode) {
        _tiltController.forward();
      } else {
        _tiltController.reverse();
      }
    });
  }

  void _openMapStylePicker(AppMapType activeMapType) {
    showAetronMapStylePicker(
      context: context,
      currentType: activeMapType,
      currentLang: widget.currentLang,
      onFallbackSelect: (type) async {
        if (!mounted) return;
        setState(() {
          _fallbackMapType = type;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(kAetronMapTypePrefKey, type.name);
        } catch (_) {}
      },
    );
  }

  @override
  void didUpdateWidget(TrackingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showRoute != oldWidget.showRoute ||
        widget.activityType != oldWidget.activityType ||
        !listEquals(widget.routePoints, oldWidget.routePoints) ||
        !_segmentsEqual(widget.routeSegments, oldWidget.routeSegments)) {
      _refreshDisplayRoute();
    }

    final target = widget.currentLocation ?? widget.initialPosition;
    final prevTarget = oldWidget.currentLocation ?? oldWidget.initialPosition;

    if (!_initialCameraSet && target != null) {
      _initialCameraSet = true;
      _recenterToCurrent(force: true);
      return;
    }

    if (widget.recenterRequestId != oldWidget.recenterRequestId) {
      _userAdjustedZoom = false;
      _recenterToCurrent(force: true);
      return;
    }

    if (!widget.followUser) return;

    final signalChanged = widget.isGpsSignalWeak != oldWidget.isGpsSignalWeak;
    if (target == null || (target == prevTarget && !signalChanged)) return;

    final now = DateTime.now();
    final last = _lastCameraMove;
    if (signalChanged || last == null || now.difference(last) >= _cameraThrottle) {
      _lastCameraMove = now;
      final currentZoom = _mapController.camera.zoom;
      final desiredZoom = _userAdjustedZoom
          ? currentZoom
          : (currentZoom + (_recommendedTrackingZoom() - currentZoom) * 0.35)
              .clamp(_minMapZoom, _maxMapZoom);
      final camTarget = _visualCameraTarget(target, desiredZoom);
      _mapController.move(camTarget, desiredZoom);
    }
  }

  LatLng _visualCameraTarget(LatLng rawTarget, double zoom) {
    // When tracking live in Map mode, offset camera center southward
    // so the avatar is positioned at the optical center of the visible
    // map area (between the top bar ~70px and the bottom HUD card ~220px).
    // An upward screen offset of ~72 logical pixels keeps the avatar
    // away from the bottom mini metrics card and dock.
    final latRad = rawTarget.latitude * (math.pi / 180.0);
    final cosLat = math.cos(latRad).abs().clamp(0.1, 1.0);
    final deltaLat = (72.0 * 360.0) / (256.0 * math.pow(2.0, zoom) * cosLat);
    return LatLng(rawTarget.latitude - deltaLat, rawTarget.longitude);
  }

  void _recenterToCurrent({bool force = false}) {
    final target = widget.currentLocation ?? widget.initialPosition;
    if (target == null) return;
    final now = DateTime.now();
    final last = _lastCameraMove;
    if (!force && last != null && now.difference(last) < _cameraThrottle) {
      return;
    }
    _lastCameraMove = now;
    _initialCameraSet = true;
    final currentZoom = _mapController.camera.zoom;
    final recommended = _recommendedTrackingZoom();
    final zoom = (!_userAdjustedZoom || currentZoom < 14.0)
        ? recommended
        : currentZoom;
    final camTarget = _visualCameraTarget(target, zoom);
    _mapController.move(camTarget, zoom);
  }

  void _refreshDisplayRoute() {
    final raw = widget.routePoints;
    final rawSegments = widget.routeSegments;
    if (raw.isEmpty) {
      _cachedDisplayRoute = const <LatLng>[];
      _cachedDisplaySegments = const <List<LatLng>>[];
      return;
    }

    final zoom = _zoomBucket ?? _recommendedTrackingZoom().round();
    final tolerance = _simplificationTolerance(zoom);

    List<LatLng> prepareSegment(List<LatLng> segment) {
      final simplified = _simplifyPoints(segment, tolerance);
      final sanitized = sanitizeRouteForDisplay(
        simplified,
        activityType: widget.activityType,
        applyCurveSmoothing: true,
      );
      return sanitized.length >= 2 ? sanitized : simplified;
    }

    if (rawSegments.isNotEmpty) {
      // Bridge short indoor/signal-hiccup breaks (<= 45m) before curve smoothing
      // so single-point recoveries are preserved and short gaps look seamless.
      final bridgedRaw = bridgeShortDisplayGaps(
        rawSegments,
        maxSeamlessGapMeters: 45.0,
      );
      final outSegments = <List<LatLng>>[];
      for (final segment in bridgedRaw) {
        if (segment.length < 2) continue;
        final curved = prepareSegment(segment);
        if (curved.length >= 2) {
          outSegments.add(curved);
        }
      }
      _cachedDisplaySegments = outSegments;
      _cachedDisplayRoute = outSegments.isNotEmpty
          ? outSegments.expand((element) => element).toList()
          : prepareSegment(raw);
      return;
    }

    _cachedDisplayRoute = prepareSegment(raw);
    _cachedDisplaySegments = _cachedDisplayRoute.isNotEmpty
        ? <List<LatLng>>[_cachedDisplayRoute]
        : const <List<LatLng>>[];
  }

  bool _segmentsEqual(List<List<LatLng>> a, List<List<LatLng>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  double _simplificationTolerance(int zoom) {
    if (zoom >= 18) return 0.000006;
    if (zoom >= 16) return 0.000015;
    if (zoom >= 14) return 0.000035;
    return 0.00008;
  }

  List<LatLng> _simplifyPoints(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;
    final sqTolerance = tolerance * tolerance;
    final result = <LatLng>[points.first];
    _douglasPeucker(points, 0, points.length - 1, sqTolerance, result);
    result.add(points.last);
    return result;
  }

  void _douglasPeucker(
    List<LatLng> points,
    int first,
    int last,
    double sqTolerance,
    List<LatLng> result,
  ) {
    var maxSqDist = 0.0;
    var index = first;

    final p1 = points[first];
    final p2 = points[last];

    for (var i = first + 1; i < last; i++) {
      final sqDist = _pointToSegmentDistanceSq(points[i], p1, p2);
      if (sqDist > maxSqDist) {
        maxSqDist = sqDist;
        index = i;
      }
    }

    if (maxSqDist > sqTolerance) {
      if (index - first > 1) {
        _douglasPeucker(points, first, index, sqTolerance, result);
      }
      result.add(points[index]);
      if (last - index > 1) {
        _douglasPeucker(points, index, last, sqTolerance, result);
      }
    }
  }

  double _pointToSegmentDistanceSq(LatLng p, LatLng p1, LatLng p2) {
    final x = p.longitude;
    final y = p.latitude;
    final x1 = p1.longitude;
    final y1 = p1.latitude;
    final x2 = p2.longitude;
    final y2 = p2.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      final px = x - x1;
      final py = y - y1;
      return px * px + py * py;
    }

    final t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);

    if (t < 0) {
      final px = x - x1;
      final py = y - y1;
      return px * px + py * py;
    }
    if (t > 1) {
      final px = x - x2;
      final py = y - y2;
      return px * px + py * py;
    }

    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final px = x - projX;
    final py = y - projY;
    return px * px + py * py;
  }

  @override
  Widget build(BuildContext context) {
    final center =
        widget.currentLocation ??
        widget.initialPosition ??
        (widget.routePoints.isNotEmpty
            ? widget.routePoints.last
            : _defaultCenter);

    final displayRoute = _cachedDisplayRoute;
    final displaySegments = _cachedDisplaySegments.isNotEmpty
        ? _cachedDisplaySegments
        : (displayRoute.isNotEmpty
              ? <List<LatLng>>[displayRoute]
              : const <List<LatLng>>[]);

    final markerPos = widget.currentLocation ?? widget.initialPosition;
    final useLitePolyline =
        widget.routePoints.length > (kDebugLocationMode ? 250 : 700);

    final colors = context.kinetic;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final initialZoom = _recommendedTrackingZoom();

    return AetronMapTypeBuilder(
      fallbackType: _fallbackMapType,
      builder: (context, activeMapType) {
        return Stack(
          children: [
            AnimatedBuilder(
              animation: _tiltAnimation,
              builder: (context, child) {
                final tilt = widget.enableTilt ? _tiltAnimation.value : 0.0;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(tilt),
                  child: child,
                );
              },
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  backgroundColor: colors.surface2,
                  initialCenter: _visualCameraTarget(center, initialZoom),
                  initialZoom: initialZoom,
                  minZoom: _minMapZoom,
                  maxZoom: _maxMapZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    final nextZoomBucket = camera.zoom.round();
                    if (hasGesture &&
                        (camera.zoom - _recommendedTrackingZoom()).abs() >
                            0.25) {
                      _userAdjustedZoom = true;
                    }
                    if (nextZoomBucket != _zoomBucket) {
                      setState(() {
                        _zoomBucket = nextZoomBucket;
                        _refreshDisplayRoute();
                      });
                    }
                    if (hasGesture) {
                      widget.onUserGesturePan?.call();
                    }
                  },
                ),
                children: [
                  if (widget.showMapTiles)
                    ...buildAetronMapTileLayers(activeMapType),
                  if (widget.showRoute && displaySegments.isNotEmpty)
                    PolylineLayer(
                      simplificationTolerance: 0.25,
                      polylines: buildAetronRoutePolylines(
                        segments: displaySegments,
                        mapType: activeMapType,
                        isDark: !isLight,
                        coreWidth: useLitePolyline ? 4.4 : 5.4,
                        lite: useLitePolyline,
                      ),
                    ),
                  MarkerLayer(
                    markers: [
                      if (widget.showRoute && displayRoute.isNotEmpty)
                        Marker(
                          point: displayRoute.first,
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          child: const _StartAnchorMarker(),
                        ),
                      if (markerPos != null)
                        Marker(
                          point: markerPos,
                          width: 48,
                          height: 56,
                          alignment: Alignment.bottomCenter,
                          child: _Aetron3DUserAvatarMarker(
                            avatarImage: widget.avatarImage,
                            initials: widget.initials,
                            tiltAnimation: _tiltAnimation,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.showControls)
              Positioned(
                top: widget.topControlOffset,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enableTilt) ...[
                      _Map3DPerspectiveOrb(
                        is3D: _is3DMode,
                        isVi: widget.currentLang == AppLanguage.vi,
                        onTap: _toggle3DMode,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _MapLayerPickerOrb(
                      selectedType: activeMapType,
                      isVi: widget.currentLang == AppLanguage.vi,
                      onTap: () => _openMapStylePicker(activeMapType),
                    ),
                    if (widget.isGpsSignalWeak) ...[
                      const SizedBox(height: 10),
                      const _GpsWeakBadge(),
                    ],
                  ],
                ),
              ),
            if (widget.showControls)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.background.withValues(
                            alpha: isLight ? 0.14 : 0.28,
                          ),
                          Colors.transparent,
                          Colors.transparent,
                          colors.background.withValues(
                            alpha: isLight ? 0.20 : 0.36,
                          ),
                        ],
                        stops: const [0.0, 0.14, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

const Distance _routeBridgeDistance = Distance();

/// Builds Aetron's unified Glassline luminous route ribbon polylines for both
/// live tracking and saved workout route previews.
///
/// Segment continuity (display-only, never alters distance metrics):
/// - Short indoor/signal-hiccup gaps (`<= maxSeamlessGapMeters`, default 45m)
///   are seamlessly merged and curve-smoothed so routes never show ragged holes.
/// - Longer GPS blackouts/tunnels (`> 45m` and `<= 2000m`) are bridged with a
///   sleek translucent Glassline dashed connector so continuity stays clear.
///
/// Solid Ribbon Layers:
/// 1. Soft ambient sky-blue halo (stays anchored at every zoom up to 22)
/// 2. Crisp frosted casing for legibility over satellite and street tiles
/// 3. Directional Aetron brand gradient (`#1166DB` Cobalt -> `#2A85FF` -> `#93BFFF` Sky)
/// 4. Subtle frost specular filament along the center ridge
List<Polyline> buildAetronRoutePolylines({
  required List<List<LatLng>> segments,
  required AppMapType mapType,
  required bool isDark,
  double coreWidth = 5.0,
  bool lite = false,
  double maxSeamlessGapMeters = 45.0,
  double maxDashedBridgeMeters = 2000.0,
}) {
  final useLightCasing = !isDark || mapType == AppMapType.satellite;
  final haloColor = isDark
      ? AetronLogoPaths.darkAccentColor.withValues(alpha: 0.24)
      : AetronLogoPaths.lightAccentColor.withValues(alpha: 0.18);
  final casingColor = useLightCasing
      ? Colors.white.withValues(alpha: 0.94)
      : const Color(0xDD0C1420);
  const gradient = <Color>[
    AetronLogoPaths.lightAccentColor, // #1166DB (start)
    Color(0xFF2A85FF), // Electric Kinetic Blue (mid)
    AetronLogoPaths.darkAccentColor, // #93BFFF (current/finish tip)
  ];
  const stops = <double>[0.0, 0.55, 1.0];

  final visualSegments = bridgeShortDisplayGaps(
    segments,
    maxSeamlessGapMeters: maxSeamlessGapMeters,
  );

  final polylines = <Polyline>[];

  // Draw sleek Glassline dashed bridges across longer GPS blackout / tunnel gaps
  // BEFORE solid segments so solid endpoints sit cleanly on top.
  for (var i = 0; i < visualSegments.length - 1; i++) {
    final prevEnd = visualSegments[i].last;
    final nextStart = visualSegments[i + 1].first;
    final gapM = _routeBridgeDistance.distance(prevEnd, nextStart);
    if (gapM > 0.5 && gapM <= maxDashedBridgeMeters) {
      final bridgePoints = <LatLng>[prevEnd, nextStart];
      final dashedPattern = StrokePattern.dashed(segments: const <double>[7, 7]);
      polylines.add(
        Polyline(
          points: bridgePoints,
          strokeWidth: (coreWidth * 0.72) + 2.4,
          color: casingColor.withValues(alpha: 0.75),
          pattern: dashedPattern,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
      polylines.add(
        Polyline(
          points: bridgePoints,
          strokeWidth: coreWidth * 0.72,
          color: (isDark
                  ? AetronLogoPaths.darkAccentColor
                  : AetronLogoPaths.lightAccentColor)
              .withValues(alpha: 0.78),
          pattern: dashedPattern,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }
  }

  for (final segment in visualSegments) {
    if (segment.length < 2) continue;
    final curved = smoothCurveForDisplay(segment, iterations: 1);
    final renderPoints = curved.length >= 2 ? curved : segment;
    if (!lite) {
      polylines.add(
        Polyline(
          points: renderPoints,
          strokeWidth: coreWidth + 8.5,
          color: haloColor,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }
    polylines.add(
      Polyline(
        points: renderPoints,
        strokeWidth: coreWidth + 3.2,
        color: casingColor,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    );
    polylines.add(
      Polyline(
        points: renderPoints,
        strokeWidth: coreWidth,
        gradientColors: gradient,
        colorsStop: stops,
        color: AetronLogoPaths.lightAccentColor,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    );
    if (!lite) {
      polylines.add(
        Polyline(
          points: renderPoints,
          strokeWidth: (coreWidth * 0.26).clamp(1.1, 1.6),
          color: AetronLogoPaths.darkWordmarkColor.withValues(alpha: 0.45),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }
  }
  return polylines;
}

/// Builds the ArcGIS tile layers for the active [AppMapType].
///
/// Uses `maxNativeZoom: 18` with unbounded `maxZoom` (`double.infinity`) so
/// `flutter_map` smoothly overzooms native z18 tiles all the way to zoom 22
/// (indoor/room scale) without ever turning blank white or hitting ArcGIS
/// "Map data not yet available" placeholder tiles.
List<Widget> buildAetronMapTileLayers(AppMapType type) {
  switch (type) {
    case AppMapType.satellite:
      return [
        TileLayer(
          key: const ValueKey('aetron-tile-satellite-imagery'),
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxNativeZoom: 18,
          keepBuffer: 3,
        ),
        TileLayer(
          key: const ValueKey('aetron-tile-satellite-boundaries'),
          urlTemplate:
              "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxNativeZoom: 18,
          keepBuffer: 3,
        ),
      ];
    case AppMapType.streets:
      return [
        TileLayer(
          key: const ValueKey('aetron-tile-streets'),
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxNativeZoom: 18,
          keepBuffer: 3,
        ),
      ];
  }
}

class _Map3DPerspectiveOrb extends StatelessWidget {
  final bool is3D;
  final bool isVi;
  final VoidCallback onTap;

  const _Map3DPerspectiveOrb({
    required this.is3D,
    this.isVi = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final tooltipMsg = isVi
        ? (is3D
              ? "Đang xem 3D (Chạm để về 2D)"
              : "Đang xem 2D (Chạm để bật 3D)")
        : (is3D
              ? "3D perspective on (Tap for 2D)"
              : "2D top-down on (Tap for 3D)");

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('map-3d-toggle-btn'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: KineticTokens.minTouchTarget,
            child: Center(
              child: KineticTouchFinish(
                radius: KineticTokens.iconControlVisualSize / 2,
                emphasis: is3D,
                child: Container(
                  width: KineticTokens.iconControlVisualSize,
                  height: KineticTokens.iconControlVisualSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface1.withValues(alpha: 0.94),
                    border: Border.all(
                      color: is3D ? colors.primary : colors.borderSubtle,
                      width: 1,
                    ),
                    boxShadow: colors.isDark && is3D
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.22),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      is3D ? "3D" : "2D",
                      style: KineticTypography.unitLabel.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: is3D ? colors.primary : colors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLayerPickerOrb extends StatelessWidget {
  final AppMapType selectedType;
  final bool isVi;
  final VoidCallback onTap;

  const _MapLayerPickerOrb({
    required this.selectedType,
    this.isVi = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isSatellite = selectedType == AppMapType.satellite;
    return Tooltip(
      message: isVi ? "Chọn kiểu bản đồ" : "Select map style",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('map-layer-picker-btn'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: KineticTokens.minTouchTarget,
            child: Center(
              child: KineticTouchFinish(
                radius: KineticTokens.iconControlVisualSize / 2,
                emphasis: isSatellite,
                child: Container(
                  width: KineticTokens.iconControlVisualSize,
                  height: KineticTokens.iconControlVisualSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface1.withValues(alpha: 0.94),
                    border: Border.all(
                      color: isSatellite
                          ? colors.primary.withValues(
                              alpha: colors.isDark ? 0.7 : 0.5,
                            )
                          : colors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: BladeIcon(
                      BladeIconName.layers,
                      color: isSatellite ? colors.primary : colors.textPrimary,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStylePickerSheet extends StatelessWidget {
  final AppMapType currentType;
  final AppLanguage currentLang;
  final ValueChanged<AppMapType> onSelectType;

  const _MapStylePickerSheet({
    required this.currentType,
    required this.currentLang,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final hasScope = hasAetronProviderScope(context);

    Widget buildSheet(AppLanguage activeLang, AppMapType activeType) {
      final isVi = activeLang == AppLanguage.vi;
      return KineticGlassBottomSheet(
        floating: true,
        borderRadius: 28,
        maxHeightFactor: 0.80,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                    child: BladeIcon(
                      BladeIconName.layers,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isVi ? "Chọn kiểu bản đồ" : "Select map style",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KineticTypography.pageEyebrow.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isVi
                    ? "Tùy chỉnh góc nhìn bản đồ phù hợp với sở thích của bạn:"
                    : "Customize your map style to match your preference:",
                style: KineticTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _buildMapOption(
                context: context,
                optionKey: const Key('map-style-option-satellite'),
                type: AppMapType.satellite,
                activeType: activeType,
                title: isVi ? "Ảnh vệ tinh 3D" : "3D satellite imagery",
                subtitle: isVi
                    ? "Ảnh chụp thực tế độ phân giải cao"
                    : "Photorealistic aerial satellite imagery",
                iconBuilder: (color, size) =>
                    Icon(Icons.satellite_alt_rounded, color: color, size: size),
                badge: isVi ? "Chân thực" : "Realistic",
              ),
              const SizedBox(height: 12),
              _buildMapOption(
                context: context,
                optionKey: const Key('map-style-option-streets'),
                type: AppMapType.streets,
                activeType: activeType,
                title: isVi ? "Đường phố rõ nét" : "Clean street map",
                subtitle: isVi
                    ? "Bản đồ đường xá, công viên tinh tế"
                    : "Clean minimal street & sports map",
                iconBuilder: (color, size) =>
                    BladeIcon(BladeIconName.map, color: color, size: size),
                badge: isVi ? "Rõ nét" : "Clean",
              ),
            ],
          ),
        ),
      );
    }

    if (!hasScope) {
      return buildSheet(currentLang, currentType);
    }
    return Consumer(
      builder: (context, ref, _) => buildSheet(
        ref.watch(appLanguageProvider),
        ref.watch(appMapTypeProvider),
      ),
    );
  }

  Widget _buildMapOption({
    required BuildContext context,
    required Key optionKey,
    required AppMapType type,
    required AppMapType activeType,
    required String title,
    required String subtitle,
    required Widget Function(Color color, double size) iconBuilder,
    required String badge,
  }) {
    final colors = context.kinetic;
    final isSelected = activeType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: optionKey,
        onTap: () {
          HapticFeedback.selectionClick();
          onSelectType(type);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.14)
                : colors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected && colors.isDark
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.borderSubtle,
                  ),
                ),
                child: Center(
                  child: iconBuilder(
                    isSelected ? colors.primary : colors.textSecondary,
                    22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.bodySmall.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: 0.2)
                                : colors.surface3,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: KineticTypography.unitLabel.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? colors.primary
                                  : colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: KineticTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                BladeIcon(BladeIconName.check, color: colors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aetron3DUserAvatarMarker extends StatefulWidget {
  final ImageProvider? avatarImage;
  final String initials;
  final Animation<double>? tiltAnimation;

  const _Aetron3DUserAvatarMarker({
    this.avatarImage,
    required this.initials,
    this.tiltAnimation,
  });

  @override
  State<_Aetron3DUserAvatarMarker> createState() =>
      _Aetron3DUserAvatarMarkerState();
}

class _Aetron3DUserAvatarMarkerState extends State<_Aetron3DUserAvatarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    Widget standingPin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.65),
                blurRadius: 14,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: widget.avatarImage != null
                ? Image(image: widget.avatarImage!, fit: BoxFit.cover)
                : Container(
                    color: colors.background,
                    child: Center(
                      child: Text(
                        widget.initials,
                        style: KineticTypography.headlineSmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 7),
          painter: _PinTipPainter(color: colors.primary),
        ),
      ],
    );

    if (widget.tiltAnimation != null) {
      standingPin = AnimatedBuilder(
        animation: widget.tiltAnimation!,
        builder: (context, child) {
          final tilt = widget.tiltAnimation!.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..rotateX(-tilt),
            child: child,
          );
        },
        child: standingPin,
      );
    }

    return SizedBox(
      width: 48,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Ground radar pulse ring expanding on asphalt
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final val = _pulseController.value;
              return Positioned(
                bottom: -2,
                child: Container(
                  width: 24 + (val * 24),
                  height: 8 + (val * 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.primary.withValues(
                        alpha: (1.0 - val).clamp(0.0, 1.0) * 0.7,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
          // Upright avatar pin pointing directly down at coordinate
          Positioned(bottom: 0, child: standingPin),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StartAnchorMarker extends StatelessWidget {
  const _StartAnchorMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF10B981).withValues(alpha: 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.42),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
            ),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _GpsWeakBadge extends ConsumerWidget {
  const _GpsWeakBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLang = ref.watch(appLanguageProvider);
    final isVi = activeLang == AppLanguage.vi;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61E2834),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55FFB85C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gps_off_rounded,
              size: 14,
              color: Color(0xFFFFB85C),
            ),
            const SizedBox(width: 6),
            Text(
              isVi ? "Tín hiệu GPS yếu" : "Weak GPS",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
