import 'package:fitness_exercise_application/features/workout/domain/services/estimation/state_estimator.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/estimation/unified_bayesian_estimator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SDD-08 UnifiedBayesianEstimator', () {
    test('Maintains IMM probability invariant and bridges GNSS outage with PDR', () {
      final est = UnifiedBayesianEstimator(
        enableIgg3: true,
        enableIae: true,
        enableImm: true,
        enablePdrFusion: true,
      );
      final t0 = DateTime.utc(2026, 11, 27, 9, 0, 0);
      const origin = LatLng(48.2082, 16.3738);
      const dist = Distance(roundResult: false);

      // 15s walking north at 1.5 m/s with GNSS
      for (int s = 0; s < 15; s++) {
        est.updateGnss(
          GnssObs(
            point: LatLng(origin.latitude + (s * 1.5) / 111320.0, origin.longitude),
            timestamp: t0.add(Duration(seconds: s)),
            accuracyMeters: 3.0,
          ),
        );
        expect(est.modes.stationary + est.modes.moving, closeTo(1.0, 1e-9));
      }
      expect(est.modes.isMapStationary, isFalse);

      // 10s GNSS outage bridged by PDR (1.5 m/s = 0.75 m step * 120 spm)
      for (int s = 15; s < 25; s++) {
        est.updatePdr(
          PdrObs(
            timestamp: t0.add(Duration(seconds: s)),
            stepLengthMeters: 0.75,
            cadenceSpm: 120.0,
          ),
        );
      }

      final trueEnd = LatLng(origin.latitude + (24 * 1.5) / 111320.0, origin.longitude);
      final errM = dist.as(LengthUnit.Meter, est.estimate!.position, trueEnd);
      expect(errM, lessThan(3.0));
    });
  });
}
