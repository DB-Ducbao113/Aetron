// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/ekf/extended_kalman_filter.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_smoothing_service.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gnss_correction/adaptive_gnss_correction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_preprocessing/trajectory_preprocessor_interface.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/kinematic_trajectory_reconstruction_engine.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/trajectory_reconstruction/trajectory_reconstruction_models.dart';

const distance = Distance(roundResult: false);
double d(LatLng a, LatLng b) => distance.as(LengthUnit.Meter, a, b);
typedef Fix = (int, LatLng, double, double, double?);
List<Fix> raw(String path) => File(path).readAsLinesSync().skip(1).map((l) {
  final c = l.split(',');
  return (
    int.parse(c[0]),
    LatLng(double.parse(c[1]), double.parse(c[2])),
    double.parse(c[4]),
    double.parse(c[5]),
    double.tryParse(c[6]),
  );
}).toList();
Map<int, LatLng> reference(String path) => {
  for (final l
      in File(path)
          .readAsLinesSync()
          .skip(1)
          .map((l) => l.split(','))
          .where((c) => c[3] == 'GNSSPhaseMeasuredRTK'))
    int.parse(l[0]): LatLng(double.parse(l[1]), double.parse(l[2])),
};
TrajectoryRawSample sample(Fix r, int i) => TrajectoryRawSample(
  index: i,
  timestamp: DateTime.fromMillisecondsSinceEpoch(r.$1, isUtc: true),
  point: r.$2,
  sensorSpeedMs: r.$3,
  accuracyMeters: r.$4,
  sensorHeadingDeg: r.$5,
);
Map<String, double> stats(List<double> e) => {
  'n': e.length.toDouble(),
  'rmse_m': math.sqrt(e.fold<double>(0, (s, x) => s + x * x) / e.length),
  'mae_m': e.fold<double>(0, (s, x) => s + x) / e.length,
};

void main() {
  test('component selection on UTC-matched phase RTK; same timestamps', () {
    final base =
        Platform.environment['TU_WIEN_DATA'] ?? '../../tu_wien_scientific';
    final errors = <String, List<double>>{
      for (final k in [
        'raw',
        'ekf',
        'aekf',
        'p01_ekf',
        'p01_aekf',
        'p01_quality_ekf',
        'service_ekf',
        'service_aekf',
      ])
        k: [],
    };
    final distErrors = <String, List<double>>{
      for (final k in errors.keys) k: [],
    };
    final gapErrors = <String, List<double>>{'linear': [], 'pchip': []};
    final details = <Map<String, dynamic>>[];
    var totalRaw = 0, retained = 0, qualityRetained = 0, common = 0;
    for (final device in ['Pixel_7_Pro', 'Pixel_9a']) {
      for (final route in [31, 32, 33, 34, 35]) {
        final root = '$base/$device/dataset_$route';
        final rows = raw('$root/raw_gps.csv');
        final truth = reference('$root/truth.csv');
        final keys = errors.keys.toList();
        final preds = <String, Map<int, LatLng>>{for (final k in keys) k: {}};
        final accepted = <String, int>{};
        for (final k in keys) {
          final useP01 = k.startsWith('p01');
          final quality = k == 'p01_quality_ekf';
          final useP02 = k.endsWith('aekf');
          final pre = TrajectoryPreprocessor.forActivity('walking')
              .createStreamingSession(
                enableQualityGate: quality,
                enableShadowMode: false,
              );
          final ekf = ExtendedKalmanFilter(
            processPosStd: .6,
            processSpeedStd: 1.2,
            processHeadingStd: .5,
            enableGnssCorrection: useP02,
            enableShadowMode: false,
            gnssCorrectionEngine: useP02
                ? AdaptiveGnssCorrectionEngine()
                : null,
          );
          final service = GpsSmoothingService(
            algorithm: GpsFilterAlgorithm.ekf4State,
            enableGnssCorrection: useP02,
            enableShadowMode: false,
          );
          int? last;
          LatLng? prev, previousAccepted, previousRoute;
          var count = 0;
          for (var i = 0; i < rows.length; i++) {
            final r = rows[i];
            if (k == 'raw') {
              preds[k]![r.$1] = r.$2;
              count++;
              continue;
            }
            final p = useP01 ? pre.processSample(sample(r, i)) : null;
            if (p != null && !p.isAccepted) {
              if (prev != null) preds[k]![r.$1] = prev;
              continue;
            }
            final dt = last == null ? 1.0 : (r.$1 - last) / 1000;
            if (k.startsWith('service')) {
              final u = service.smoothAcceptedPoint(
                activityType: 'walking',
                acceptedPoint: r.$2,
                previousAcceptedPoint: previousAccepted,
                previousSmoothedPoint: prev,
                lastSmoothedRoutePoint: previousRoute,
                accuracyMeters: r.$4,
                speedMs: r.$3,
                timeDeltaSec: dt,
                gpsGapDurationSec: dt > 5 ? dt : 0,
              );
              prev = u.smoothedPoint;
              if (u.shouldAppendRoutePoint) previousRoute = prev;
              previousAccepted = r.$2;
            } else {
              prev = ekf
                  .update(
                    measurementPoint: r.$2,
                    accuracyMeters: r.$4 * math.sqrt(p?.covarianceScale ?? 1),
                    timeDeltaSec: dt,
                    speedMs: r.$3,
                    headingDeg: r.$5,
                    activityType: 'walking',
                  )
                  .position;
            }
            preds[k]![r.$1] = prev;
            last = r.$1;
            count++;
          }
          accepted[k] = count;
        }
        totalRaw += rows.length;
        retained += accepted['p01_ekf']!;
        qualityRetained += accepted['p01_quality_ekf']!;
        final times =
            truth.keys
                .where((t) => keys.every((k) => preds[k]!.containsKey(t)))
                .toList()
              ..sort();
        expect(times, isNotEmpty);
        common += times.length;
        final per = <String, dynamic>{};
        for (final k in keys) {
          final es = [for (final t in times) d(preds[k]![t]!, truth[t]!)];
          errors[k]!.addAll(es);
          var td = 0.0, pd = 0.0;
          for (var i = 1; i < times.length; i++) {
            final t = times[i], prev = times[i - 1];
            if (t - prev != 1000) continue;
            td += d(truth[prev]!, truth[t]!);
            pd += d(preds[k]![prev]!, preds[k]![t]!);
          }
          final de = td > 0 ? 100 * (pd - td).abs() / td : 0.0;
          if (td > 0) distErrors[k]!.add(de);
          per[k] = {
            ...stats(es),
            'accepted': accepted[k],
            'distance_error_pct': de,
            'reference_distance_m': td,
          };
        }
        // Simulated 5-second gaps; retain observations, never feed omitted
        // RTK coordinates into the reconstruction engine.
        final sparse = <TrajectoryRawSample>[];
        for (var i = 0; i < rows.length; i += 5) {
          sparse.add(sample(rows[i], i));
        }
        final batch = TrajectoryPreprocessor.forActivity(
          'walking',
        ).processBatch(sparse);
        final results = {
          for (final method in ReconstructionMethod.values)
            method: const KinematicTrajectoryReconstructionEngine()
                .reconstructTrajectory(
                  points: batch.processedPoints,
                  activityType: 'walking',
                  method: method,
                ),
        };
        final lin = {
          for (final p
              in results[ReconstructionMethod.linearChord]!.points.where(
                (p) => p.isInterpolated,
              ))
            p.timestamp.millisecondsSinceEpoch: p.point,
        };
        final pch = {
          for (final p
              in results[ReconstructionMethod.monotonePchip]!.points.where(
                (p) => p.isInterpolated,
              ))
            p.timestamp.millisecondsSinceEpoch: p.point,
        };
        final gapTimes = lin.keys
            .where((t) => pch.containsKey(t) && truth.containsKey(t))
            .toList();
        for (final t in gapTimes) {
          gapErrors['linear']!.add(d(lin[t]!, truth[t]!));
          gapErrors['pchip']!.add(d(pch[t]!, truth[t]!));
        }
        details.add({
          'device': device,
          'route': route,
          'raw': rows.length,
          'matched': times.length,
          'models': per,
          'gap_matched': gapTimes.length,
        });
      }
    }
    final result = {
      'scope':
          'component replay, exact common phase RTK timestamps; P01 skipped samples hold previous output; P03 offline masked raw fixes, not full workout pipeline; accuracy proxy as source manifest',
      'raw_count': totalRaw,
      'common': common,
      'p01_accepted': retained,
      'quality_accepted': qualityRetained,
      'models': {
        for (final k in errors.keys)
          k: {
            ...stats(errors[k]!),
            'mean_distance_error_pct':
                distErrors[k]!.reduce((a, b) => a + b) / distErrors[k]!.length,
          },
      },
      'reconstruction': {
        for (final k in gapErrors.keys) k: stats(gapErrors[k]!),
      },
      'sessions': details,
    };
    final output = File(
      'tooling/benchmark/results/gnss_phase_selection_20261118/manifest.json',
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    print(jsonEncode({...result}..remove('sessions')));
  });
}
