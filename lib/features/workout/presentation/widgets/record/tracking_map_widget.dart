import "dart:math" as math;
import "dart:ui" as ui;
import "package:fitness_exercise_application/core/constants/debug_config.dart";
import "package:fitness_exercise_application/core/localization/app_translations.dart";
import "package:fitness_exercise_application/features/workout/presentation/screens/record/workout_session_state.dart";
import "package:fitness_exercise_application/shared/kinetic/kinetic.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kAetronMapTypePrefKey = "aetron_preferred_map_type";

enum AppMapType {
  satellite,
  streets,
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
  bool _is3DMode = true;
  AppMapType _selectedMapType = AppMapType.satellite;
  List<LatLng> _cachedDisplayRoute = const <LatLng>[];
  List<List<LatLng>> _cachedDisplaySegments = const <List<LatLng>>[];
  int? _zoomBucket;

  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);

  static const _routeGlow = Color(0x66A8DCE7);
  static const _routeCore = Color(0xFFA8DCE7);
  static const _routeHighlight = Color(0xFFE2F8FC);
  static const _routeShadow = Color(0x40000000);

  static Duration get _cameraThrottle => kDebugLocationMode
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
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
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kAetronMapTypePrefKey);
      if (saved != null && mounted) {
        setState(() {
          _selectedMapType = AppMapType.values.firstWhere(
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

  void _openMapStylePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MapStylePickerSheet(
        currentType: _selectedMapType,
        currentLang: widget.currentLang,
        onSelectType: (type) async {
          setState(() {
            _selectedMapType = type;
          });
          Navigator.of(sheetContext).pop();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(kAetronMapTypePrefKey, type.name);
          } catch (_) {}
        },
      ),
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
      _recenterToCurrent(force: true);
      return;
    }

    if (!widget.followUser) return;

    if (target == null || target == prevTarget) return;

    final now = DateTime.now();
    final last = _lastCameraMove;
    if (last == null || now.difference(last) >= _cameraThrottle) {
      _lastCameraMove = now;
      final currentZoom = _mapController.camera.zoom;
      final camTarget = _visualCameraTarget(target, currentZoom);
      _mapController.move(camTarget, currentZoom);
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
    final zoom = currentZoom < 14.0 ? 17.2 : currentZoom;
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

    final zoom = _zoomBucket ?? 17;
    final tolerance = _simplificationTolerance(zoom);

    if (rawSegments.isNotEmpty) {
      final outSegments = <List<LatLng>>[];
      for (final segment in rawSegments) {
        if (segment.length < 2) continue;
        final simplified = _simplifyPoints(segment, tolerance);
        if (simplified.length >= 2) {
          outSegments.add(simplified);
        }
      }
      _cachedDisplaySegments = outSegments;
      _cachedDisplayRoute = outSegments.isNotEmpty
          ? outSegments.expand((element) => element).toList()
          : _simplifyPoints(raw, tolerance);
      return;
    }

    _cachedDisplayRoute = _simplifyPoints(raw, tolerance);
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
    _douglasPeucker(
      points,
      0,
      points.length - 1,
      sqTolerance,
      result,
    );
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

  List<LatLng> _offsetShadowPoints(List<LatLng> pts) {
    return pts
        .map((p) => LatLng(p.latitude - 0.000035, p.longitude + 0.000025))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentLocation ??
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

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _tiltAnimation,
          builder: (context, child) {
            final tilt = _tiltAnimation.value;
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
              initialCenter: _visualCameraTarget(center, 17.2),
              initialZoom: 17.2,
              minZoom: 4,
              maxZoom: 20,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                final nextZoomBucket = camera.zoom.round();
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
              ..._buildMapTileLayers(_selectedMapType),
              if (widget.showRoute && displaySegments.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final segment in displaySegments) ...[
                      if (!useLitePolyline)
                        Polyline(
                          points: _offsetShadowPoints(segment),
                          strokeWidth: 9,
                          color: _routeShadow,
                        ),
                      if (!useLitePolyline)
                        Polyline(
                          points: segment,
                          strokeWidth: 16,
                          color: _routeGlow,
                        ),
                      Polyline(
                        points: segment,
                        strokeWidth: useLitePolyline ? 5.5 : 7.5,
                        gradientColors: useLitePolyline
                            ? null
                            : const [
                                Color(0xFFA8DCE7),
                                Color(0xFF2BD9A5),
                                Color(0xFFA8DCE7),
                              ],
                        color: _routeCore,
                      ),
                      if (!useLitePolyline)
                        Polyline(
                          points: segment,
                          strokeWidth: 2.2,
                          color: _routeHighlight,
                        ),
                    ],
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.showRoute && displayRoute.isNotEmpty)
                    Marker(
                      point: displayRoute.first,
                      width: 32,
                      height: 44,
                      alignment: Alignment.bottomCenter,
                      child: _Start3DPinMarker(
                        tiltAnimation: _tiltAnimation,
                      ),
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
                  if (widget.gpsGapMarker != null)
                    Marker(
                      point: widget.gpsGapMarker!,
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      child: const _GpsGapMarker(),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: widget.topControlOffset,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Map3DPerspectiveOrb(
                is3D: _is3DMode,
                isVi: widget.currentLang == AppLanguage.vi,
                onTap: _toggle3DMode,
              ),
              const SizedBox(height: 10),
              _MapLayerPickerOrb(
                selectedType: _selectedMapType,
                isVi: widget.currentLang == AppLanguage.vi,
                onTap: _openMapStylePicker,
              ),
              if (widget.isGpsSignalWeak) ...[
                const SizedBox(height: 10),
                const _GpsWeakBadge(),
              ],
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.40),
                  ],
                  stops: const [0.0, 0.14, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<Widget> _buildMapTileLayers(AppMapType type) {
  switch (type) {
    case AppMapType.satellite:
      return [
        TileLayer(
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
        ),
        TileLayer(
          urlTemplate:
              "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
        ),
      ];
    case AppMapType.streets:
      return [
        TileLayer(
          urlTemplate:
              "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
          userAgentPackageName: "com.aetron.app",
          maxZoom: 20,
          maxNativeZoom: 19,
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
        ? (is3D ? "Đang xem 3D (Chạm để về 2D)" : "Đang xem 2D (Chạm để bật 3D)")
        : (is3D ? "3D perspective on (Tap for 2D)" : "2D top-down on (Tap for 3D)");

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface1.withValues(alpha: 0.94),
              border: Border.all(
                color: is3D
                    ? colors.primary
                    : Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                if (is3D)
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                is3D ? "3D" : "2D",
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w900,
                  color: is3D ? colors.primary : Colors.white70,
                  letterSpacing: 0.8,
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
    return Tooltip(
      message: isVi ? "Chọn kiểu bản đồ" : "Select map style",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface1.withValues(alpha: 0.94),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.layers_rounded,
                color: colors.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStylePickerSheet extends ConsumerWidget {
  final AppMapType currentType;
  final AppLanguage currentLang;
  final ValueChanged<AppMapType> onSelectType;

  const _MapStylePickerSheet({
    required this.currentType,
    required this.currentLang,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final activeLang = ref.watch(appLanguageProvider);
    final isVi = activeLang == AppLanguage.vi;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.borderAccent, width: 1.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.layers_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isVi ? "CHỌN KIỂU BẢN ĐỒ" : "SELECT MAP STYLE",
                style: KineticTypography.pageEyebrow.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: 1.1,
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
            type: AppMapType.satellite,
            title: isVi ? "Ảnh Vệ Tinh 3D" : "3D Satellite Imagery",
            subtitle: isVi
                ? "Ảnh chụp thực tế độ phân giải cao"
                : "Photorealistic aerial satellite imagery",
            icon: Icons.satellite_alt_rounded,
            badge: isVi ? "CHÂN THỰC" : "REALISTIC",
          ),
          const SizedBox(height: 12),
          _buildMapOption(
            context: context,
            type: AppMapType.streets,
            title: isVi ? "Đường Phố Rõ Nét" : "Clean Street Map",
            subtitle: isVi
                ? "Bản đồ đường xá, công viên tinh tế"
                : "Clean minimal street & sports map",
            icon: Icons.map_rounded,
            badge: isVi ? "RÕ NÉT" : "CLEAN",
          ),
        ],
      ),
    );
  }

  Widget _buildMapOption({
    required BuildContext context,
    required AppMapType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
  }) {
    final colors = context.kinetic;
    final isSelected = currentType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelectType(type);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.18)
                : colors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.borderSubtle,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
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
                    color: isSelected
                        ? colors.primary
                        : Colors.white24,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected
                        ? colors.primary
                        : colors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
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
                        const SizedBox(width: 8),
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
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 22,
                ),
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
            border: Border.all(
              color: Colors.white,
              width: 2.5,
            ),
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
          Positioned(
            bottom: 0,
            child: standingPin,
          ),
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

class _Start3DPinMarker extends StatelessWidget {
  final Animation<double>? tiltAnimation;

  const _Start3DPinMarker({this.tiltAnimation});

  @override
  Widget build(BuildContext context) {
    Widget pin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2AF598), Color(0xFF00B86B)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2AF598).withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTipPainter(color: const Color(0xFF00B86B)),
        ),
      ],
    );

    if (tiltAnimation != null) {
      pin = AnimatedBuilder(
        animation: tiltAnimation!,
        builder: (context, child) {
          final tilt = tiltAnimation!.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..rotateX(-tilt),
            child: child,
          );
        },
        child: pin,
      );
    }

    return SizedBox(
      width: 32,
      height: 44,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: -2,
            child: Container(
              width: 14,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: pin,
          ),
        ],
      ),
    );
  }
}

class _GpsGapMarker extends StatelessWidget {
  const _GpsGapMarker();

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: colors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.sensors_rounded,
        color: colors.primary,
        size: 18,
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
            const Icon(Icons.gps_off_rounded, size: 14, color: Color(0xFFFFB85C)),
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
