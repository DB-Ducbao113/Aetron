import 'package:flutter/material.dart';

enum ProgramPhaseType {
  warmup,
  run,
  walk,
  tempo,
  sprint,
  cooldown,
}

class ProgramStep {
  final String id;
  final String titleEn;
  final String titleVi;
  final int durationSeconds;
  final ProgramPhaseType phaseType;
  final double? targetPaceMinSecKm; // e.g. 300.0 (5:00/km)
  final double? targetPaceMaxSecKm; // e.g. 360.0 (6:00/km)
  final String targetPaceDisplay;
  final String targetHrZone;
  final String targetCadence;
  final String tipEn;
  final String tipVi;

  const ProgramStep({
    required this.id,
    required this.titleEn,
    required this.titleVi,
    required this.durationSeconds,
    required this.phaseType,
    this.targetPaceMinSecKm,
    this.targetPaceMaxSecKm,
    required this.targetPaceDisplay,
    required this.targetHrZone,
    this.targetCadence = '165-175 spm',
    required this.tipEn,
    required this.tipVi,
  });

  Color get phaseColor {
    switch (phaseType) {
      case ProgramPhaseType.warmup:
        return const Color(0xFFB388FF); // Soft Violet Warmup
      case ProgramPhaseType.run:
      case ProgramPhaseType.tempo:
        return const Color(0xFFA8DCE7); // Electric Cyan Run
      case ProgramPhaseType.sprint:
        return const Color(0xFFFF5E1E); // Radiant Orange Sprint
      case ProgramPhaseType.walk:
        return const Color(0xFF00E676); // Mint Green Recovery Walk
      case ProgramPhaseType.cooldown:
        return const Color(0xFF40C4FF); // Cool Blue
    }
  }

  IconData get phaseIcon {
    switch (phaseType) {
      case ProgramPhaseType.warmup:
        return Icons.accessibility_new_rounded;
      case ProgramPhaseType.run:
      case ProgramPhaseType.tempo:
        return Icons.directions_run_rounded;
      case ProgramPhaseType.sprint:
        return Icons.bolt_rounded;
      case ProgramPhaseType.walk:
        return Icons.directions_walk_rounded;
      case ProgramPhaseType.cooldown:
        return Icons.self_improvement_rounded;
    }
  }
}

class StructuredRunningProgram {
  final String id;
  final String titleKey;
  final String badgeEn;
  final String badgeVi;
  final String targetDistance;
  final String targetPace;
  final String targetZone;
  final String cadence;
  final String descriptionEn;
  final String descriptionVi;
  final List<String> instructionsEn;
  final List<String> instructionsVi;
  final List<ProgramStep> steps;

  const StructuredRunningProgram({
    required this.id,
    required this.titleKey,
    required this.badgeEn,
    required this.badgeVi,
    required this.targetDistance,
    required this.targetPace,
    required this.targetZone,
    required this.cadence,
    required this.descriptionEn,
    required this.descriptionVi,
    required this.instructionsEn,
    required this.instructionsVi,
    required this.steps,
  });

  int get totalDurationSeconds =>
      steps.fold<int>(0, (sum, step) => sum + step.durationSeconds);
}
