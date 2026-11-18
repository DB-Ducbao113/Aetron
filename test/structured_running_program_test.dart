import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/record/guided_program_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredRunningProgram Tests', () {
    test('All programs have valid structured intervals and total duration > 0', () {
      final programs = RunningProgramsScreen.programs;
      expect(programs.length, 4);

      for (final prog in programs) {
        expect(prog.steps.isNotEmpty, true, reason: '${prog.id} has no steps');
        expect(prog.totalDurationSeconds > 0, true, reason: '${prog.id} duration is 0');
        expect(prog.titleKey.isNotEmpty, true);
        expect(prog.badgeVi.isNotEmpty, true);
        expect(prog.badgeEn.isNotEmpty, true);
        expect(prog.instructionsEn.isNotEmpty, true, reason: '${prog.id} missing EN instructions');
        expect(prog.instructionsVi.isNotEmpty, true, reason: '${prog.id} missing VI instructions');
      }

      // Ensure all programs have distinct IDs covering the 4 structured plans
      final programIds = programs.map((p) => p.id).toSet();
      expect(programIds.length, programs.length, reason: 'Program IDs must not be duplicated');
      expect(
        programIds,
        containsAll(['couch_to_5k', 'easy_base_run', 'pace_builder_10k', 'speed_intervals']),
      );
    });

    test('Couch to 5K contains Warmup, 8 Run/Walk intervals, and Cooldown', () {
      final c25k = RunningProgramsScreen.programs.firstWhere((p) => p.id == 'couch_to_5k');
      expect(c25k.steps.first.phaseType, ProgramPhaseType.warmup);
      expect(c25k.steps.last.phaseType, ProgramPhaseType.cooldown);
      // 1 warmup + 8*(1 run + 1 walk) + 1 cooldown = 1 + 16 + 1 = 18 steps
      expect(c25k.steps.length, 18);
    });

    testWidgets('GuidedProgramHud renders step information correctly', (tester) async {
      final program = RunningProgramsScreen.programs.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuidedProgramHud(
              program: program,
              currentStepIndex: 0,
              stepRemainingSeconds: 280,
              stepElapsedSeconds: 20,
              currentPaceMinSecKm: 660, // 11:00/km (inside 10:00-12:00 target)
              currentLang: AppLanguage.vi,
              onSkipStep: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('HIỆP 1/18'), findsOneWidget);
      expect(find.text('04:40'), findsOneWidget);
      expect(find.text('✅ PACE ĐẠT CHUẨN'), findsOneWidget);
    });
  });
}
