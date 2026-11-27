import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/indoor_outdoor_state.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_prediction.dart';
import 'package:fitness_exercise_application/features/iod/domain/models/iod_sensor_snapshot.dart';
import 'package:fitness_exercise_application/features/iod/presentation/providers/iod_controller.dart';
import 'package:fitness_exercise_application/features/iod/presentation/widgets/iod_debug_pill.dart';
import 'package:fitness_exercise_application/features/iod/presentation/widgets/iod_ground_truth_sheet.dart';

void main() {
  group('IOD UI and Lifecycle Integration Tests', () {
    testWidgets('IodDebugPill renders outdoor state and sensor status badges', (tester) async {
      final container = ProviderContainer(
        overrides: [
          iodControllerProvider.overrideWith((ref) {
            final controller = IodController(
              acquisitionService: ref.watch(iodAcquisitionServiceProvider),
              storage: ref.watch(iodStorageProvider),
              classifier: ref.watch(iodClassifierProvider),
            );
            // Seed state with high confidence outdoor
            controller.state = IodState(
              isRecording: true,
              sessionId: 'test-session',
              currentPrediction: const IodPrediction(
                state: IndoorOutdoorState.outdoor,
                confidence: 0.92,
                deepIodOutdoorProbability: 0.92,
                transitionProbability: 0.05,
                nativeClass: 'outdoor',
                modelVersion: 'test-v1',
                inferenceLatencyMs: 3,
                sensorAvailability: {'gps': true, 'light': true},
                reasoningSummary: 'Test outdoor reason',
              ),
              latestSnapshot: IodSensorSnapshot(
                timestamp: DateTime.now(),
                hasGnssStatus: true,
                top4Cn0DbHz: 33.0,
                hasLightSensor: true,
                ambientLux: 15000.0,
              ),
              totalSamplesCount: 42,
            );
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: IodDebugPill(isVi: true),
              ),
            ),
          ),
        ),
      );

      // Verify UI text and chips
      expect(find.textContaining('Ngoài trời 92%'), findsOneWidget);
      expect(find.text('33dB'), findsOneWidget); // GNSS C/N0
      expect(find.text('15000lx'), findsOneWidget); // Lux
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    });

    testWidgets('Tapping IodDebugPill opens IodGroundTruthSheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: IodDebugPill(isVi: true),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IodDebugPill));
      await tester.pumpAndSettle();

      expect(find.byType(IodGroundTruthSheet), findsOneWidget);
      expect(find.text('Đánh dấu Môi trường (Ground Truth)'), findsOneWidget);
      expect(find.text('Trong nhà'), findsOneWidget);
      expect(find.text('Ngoài trời'), findsOneWidget);
      expect(find.text('Điểm chuyển tiếp (Cửa/Lối vào)'), findsOneWidget);
      expect(find.text('Hẻm đô thị / Nhà cao tầng'), findsOneWidget);
      expect(find.text('Gần cửa sổ'), findsOneWidget);
    });

    testWidgets('Tapping Ground Truth Chip updates activeGroundTruth', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: IodGroundTruthSheet(isVi: true),
            ),
          ),
        ),
      );

      // Tap on 'Điểm chuyển tiếp (Cửa/Lối vào)' chip
      await tester.tap(find.text('Điểm chuyển tiếp (Cửa/Lối vào)'));
      await tester.pump();

      final state = container.read(iodControllerProvider);
      expect(state.activeGroundTruth, equals(GroundTruthEnvironment.transition));
    });
  });
}

