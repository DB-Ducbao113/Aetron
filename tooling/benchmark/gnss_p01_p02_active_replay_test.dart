// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_raw_signal_continuity.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/workout_tracking_engine.dart';
import 'gnss_phase_selection_test.dart' as data;

typedef Replay = ({
  Map<int, LatLng> positions,
  int accepted,
  int p01Rejected,
  int breaks,
  double pathMeters,
});

Replay replay(
  List<data.Fix> rows, {
  required bool p01,
  required bool p02,
  required bool course,
}) {
  const engine = WorkoutTrackingEngine();
  final pre = TrajectoryPreprocessor.forActivity(
    'walking',
  ).createStreamingSession(enableQualityGate: false, enableShadowMode: false);
  final filter = GpsSmoothingService(
    algorithm: GpsFilterAlgorithm.ekf4State,
    enableGnssCorrection: p02,
    enableShadowMode: false,
  );
  final continuity = GpsRawSignalContinuity(gapThresholdSec: 5);
  final route = <LatLng>[];
  final out = <int, LatLng>{};
  LatLng? anchor, smoothed, display, preview;
  DateTime? last;
  var accepted = 0, p01Rejected = 0, breaks = 0;
  var path = 0.0;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final t = DateTime.fromMillisecondsSinceEpoch(r.$1, isUtc: true);
    if (!continuity.observe(t)) continue;
    final p = Position(
      latitude: r.$2.latitude,
      longitude: r.$2.longitude,
      timestamp: t,
      accuracy: r.$4,
      altitude: 0,
      altitudeAccuracy: 0,
      speed: r.$3,
      speedAccuracy: 0,
      heading: r.$5 ?? -1,
      headingAccuracy: 0,
    );
    final legacy = engine.evaluateGpsUpdate(
      position: p,
      activityType: 'walking',
      routePoints: route,
      currentLatLng: preview,
      distanceAnchorPoint: anchor,
      lastAcceptedPositionTime: last,
      rawGpsGapDurationSec: continuity.pendingGapDurationSec,
      shouldResetAnchorOnResume: false,
    );
    final processed = p01 ? pre.processSample(data.sample(r, i)) : null;
    final decision = processed == null
        ? legacy
        : engine.resolveTrajectoryPreprocessingDecision(
            legacyDecision: legacy,
            processedSample: processed,
            livePoint: r.$2,
            pendingGapDurationSec: continuity.pendingGapDurationSec,
          );
    preview = decision.previewPoint;
    if (decision.type == TrackingGpsDecisionType.skip) {
      if (legacy.type != TrackingGpsDecisionType.skip) p01Rejected++;
      if (smoothed != null) out[r.$1] = smoothed;
      continue;
    }
    final seed =
        route.isEmpty || decision.type == TrackingGpsDecisionType.resetAnchor;
    final gap = decision.shouldBreakRouteForDisplay || seed;
    final dt = last == null ? 1.0 : t.difference(last).inMilliseconds / 1000;
    final result = filter.smoothAcceptedPoint(
      activityType: 'walking',
      acceptedPoint: r.$2,
      previousAcceptedPoint: anchor,
      previousSmoothedPoint: smoothed,
      lastSmoothedRoutePoint: display,
      accuracyMeters: r.$4 * math.sqrt(decision.covarianceScale),
      speedMs: r.$3,
      timeDeltaSec: dt,
      gpsGapDurationSec: decision.gpsGapDurationSec,
      sensorHeadingDeg: course ? r.$5 : null,
      resetAnchor: gap,
    );
    if (!seed && decision.shouldBreakRouteForDisplay) breaks++;
    smoothed = gap ? r.$2 : result.smoothedPoint;
    if (gap || result.shouldAppendRoutePoint) {
      if (!gap && display != null) path += data.d(display, smoothed);
      display = smoothed;
    }
    route.add(r.$2);
    anchor = r.$2;
    last = t;
    accepted++;
    continuity.acknowledgeRouteAnchor();
    out[r.$1] = smoothed;
  }
  return (
    positions: out,
    accepted: accepted,
    p01Rejected: p01Rejected,
    breaks: breaks,
    pathMeters: path,
  );
}

void main() {
  test('P01 and P02 active pipeline replay on TU Wien phase RTK', () {
    final base =
        Platform.environment['TU_WIEN_DATA'] ?? '../../tu_wien_scientific';
    final errors = <String, List<double>>{
      for (final k in [
        'raw',
        'legacy_ekf',
        'p01_ekf',
        'p01_p02',
        'p01_p02_course',
      ])
        k: [],
    };
    final distances = <String, List<double>>{
      for (final k in errors.keys) k: [],
    };
    final sessions = <Map<String, dynamic>>[];
    for (final device in ['Pixel_7_Pro', 'Pixel_9a']) {
      for (final route in [31, 32, 33, 34, 35]) {
        final root = '$base/$device/dataset_$route';
        final rows = data.raw('$root/raw_gps.csv'),
            truth = data.reference('$root/truth.csv');
        final results = {
          'legacy_ekf': replay(rows, p01: false, p02: false, course: false),
          'p01_ekf': replay(rows, p01: true, p02: false, course: false),
          'p01_p02': replay(rows, p01: true, p02: true, course: false),
          'p01_p02_course': replay(rows, p01: true, p02: true, course: true),
        };
        final positions = {
          'raw': {for (final r in rows) r.$1: r.$2},
          for (final e in results.entries) e.key: e.value.positions,
        };
        final ts =
            truth.keys
                .where((t) => positions.values.every((p) => p.containsKey(t)))
                .toList()
              ..sort();
        expect(ts, isNotEmpty);
        final report = <String, dynamic>{};
        for (final e in positions.entries) {
          final err = [for (final t in ts) data.d(e.value[t]!, truth[t]!)];
          errors[e.key]!.addAll(err);
          var td = 0.0, pd = 0.0;
          for (var i = 1; i < ts.length; i++) {
            if (ts[i] - ts[i - 1] != 1000) continue;
            td += data.d(truth[ts[i - 1]]!, truth[ts[i]]!);
            pd += data.d(e.value[ts[i - 1]]!, e.value[ts[i]]!);
          }
          if (td > 0) distances[e.key]!.add((pd - td).abs() / td * 100);
          final r = results[e.key];
          report[e.key] = {
            ...data.stats(err),
            'adjacent_distance_error_pct': td > 0
                ? (pd - td).abs() / td * 100
                : null,
            if (r != null) ...{
              'accepted': r.accepted,
              'p01_extra_rejects': r.p01Rejected,
              'route_breaks': r.breaks,
              'display_path_m': r.pathMeters,
            },
          };
        }
        sessions.add({
          'device': device,
          'route': route,
          'raw': rows.length,
          'common': ts.length,
          'models': report,
        });
      }
    }
    final result = {
      'scope':
          'Shared production validation, P01 decision resolver, smoothing service; walking public data; route buffers updated on every accepted sample, no app lifecycle/indoor/backend replay. Held last output on rejects. GPS course branch assumes exported course is usable; native heading accuracy unavailable. Distance only contiguous matched timestamps.',
      'source_doi': '10.48436/y6gxm-6mg51',
      'models': {
        for (final k in errors.keys)
          k: {
            ...data.stats(errors[k]!),
            'mean_adjacent_distance_error_pct':
                distances[k]!.reduce((a, b) => a + b) / distances[k]!.length,
          },
      },
      'sessions': sessions,
    };
    final output = File(
      'tooling/benchmark/results/gnss_p01_p02_active_20261118/manifest.json',
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    print(jsonEncode({...result}..remove('sessions')));
  });
}
