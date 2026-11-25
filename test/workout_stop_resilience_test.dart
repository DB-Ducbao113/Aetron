import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_live_control_dock.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/kinetic_workout_stop_sheet.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: KineticTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Stop Workout Resilience & UX Tests', () {
    testWidgets('KineticLiveControlDock shows saving spinner and label when isSaving is true', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticLiveControlDock(
            isPaused: false,
            isLocked: false,
            isSaving: true,
            canToggle: true,
            isVi: true,
            onPauseResume: () {},
            onStop: () {},
            onToggleLock: () {},
          ),
        ),
      );

      // Verify the saving text and progress spinner are visible
      expect(find.text('Đang lưu'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Main stop icon should not be rendered while saving
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });

    testWidgets('KineticLiveControlDock shows SAVING in English when isSaving is true', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          KineticLiveControlDock(
            isPaused: false,
            isLocked: false,
            isSaving: true,
            canToggle: true,
            isVi: false,
            onPauseResume: () {},
            onStop: () {},
            onToggleLock: () {},
          ),
        ),
      );

      expect(find.text('Saving'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('KineticWorkoutStopSheet confirms stop when primary button is tapped', (tester) async {
      bool? confirmedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    confirmedResult = await showKineticWorkoutStopConfirmation(
                      context,
                      distanceMeters: 4200,
                      durationSeconds: 1200,
                      caloriesBurned: 300,
                      speedKmh: 12.6,
                      activityType: 'running',
                      useMetricUnits: true,
                      isVi: true,
                    );
                  },
                  child: const Text('Open Stop Sheet'),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open Stop Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Kết thúc & lưu bài tập'), findsOneWidget);
      expect(find.text('Tiếp tục tập luyện'), findsOneWidget);

      // Tapping the primary button confirms stop
      await tester.tap(find.text('Kết thúc & lưu bài tập'));
      await tester.pumpAndSettle();

      expect(confirmedResult, isTrue);
    });

    testWidgets('KineticWorkoutStopSheet cancels stop when secondary button is tapped', (tester) async {
      bool? confirmedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: KineticTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    confirmedResult = await showKineticWorkoutStopConfirmation(
                      context,
                      distanceMeters: 4200,
                      durationSeconds: 1200,
                      caloriesBurned: 300,
                      speedKmh: 12.6,
                      activityType: 'running',
                      useMetricUnits: true,
                      isVi: true,
                    );
                  },
                  child: const Text('Open Stop Sheet'),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open Stop Sheet'));
      await tester.pumpAndSettle();

      // Tapping the secondary button cancels stop
      await tester.tap(find.text('Tiếp tục tập luyện'));
      await tester.pumpAndSettle();

      expect(confirmedResult, isFalse);
    });
  });
}
