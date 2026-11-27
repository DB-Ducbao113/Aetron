import 'package:fitness_exercise_application/features/workout/domain/services/stop_detection/imm_stop_detector.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/stop_detection/zheng_stay_point_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SDD-01 ZhengStayPointDetector (Causal Adaptation)', () {
    test('Detects stationary stay after thetaT and resets on movement >= thetaD', () {
      final det = ZhengStayPointDetector(
        thetaDMeters: 10.0,
        thetaT: const Duration(seconds: 15),
      );
      final t0 = DateTime.utc(2026, 11, 27, 8, 0, 0);
      const origin = LatLng(48.2082, 16.3738);

      // Stand still for 20s
      var stopped = false;
      for (int s = 0; s <= 20; s++) {
        final u = det.update(
          point: origin,
          timestamp: t0.add(Duration(seconds: s)),
          accuracyMeters: 3.0,
        );
        if (s < 15) expect(u.isStopped, isFalse);
        if (s >= 15) {
          expect(u.isStopped, isTrue);
          stopped = true;
        }
      }
      expect(stopped, isTrue);

      // Move 25m north -> immediately leaves stop
      final moveUpdate = det.update(
        point: LatLng(origin.latitude + 25.0 / 111320.0, origin.longitude),
        timestamp: t0.add(const Duration(seconds: 21)),
        accuracyMeters: 3.0,
      );
      expect(moveUpdate.isStopped, isFalse);
      expect(moveUpdate.transitionedToMove, isTrue);
    });
  });

  group('SDD-01 ImmStopDetector (Blom & Bar-Shalom 1988)', () {
    test('Mode probabilities sum to 1 and switch between moving and stationary', () {
      final imm = ImmStopDetector();
      final t0 = DateTime.utc(2026, 11, 27, 8, 0, 0);
      const origin = LatLng(48.2082, 16.3738);

      // Move 3 m/s north for 30s
      var last = imm.update(point: origin, timestamp: t0, accuracyMeters: 3.0);
      for (int s = 1; s <= 30; s++) {
        last = imm.update(
          point: LatLng(origin.latitude + (s * 3.0) / 111320.0, origin.longitude),
          timestamp: t0.add(Duration(seconds: s)),
          accuracyMeters: 3.0,
        );
        expect(imm.stationaryProbability + imm.movingProbability, closeTo(1.0, 1e-9));
      }
      expect(last.isStopped, isFalse);

      // Now stay completely still at s=30 position for 30s
      final stopPt = LatLng(origin.latitude + 90.0 / 111320.0, origin.longitude);
      for (int s = 31; s <= 60; s++) {
        last = imm.update(
          point: stopPt,
          timestamp: t0.add(Duration(seconds: s)),
          accuracyMeters: 3.0,
        );
        expect(imm.stationaryProbability + imm.movingProbability, closeTo(1.0, 1e-9));
      }
      expect(last.isStopped, isTrue);
      expect(imm.stationaryProbability, greaterThan(0.5));
    });
  });
}
