import 'package:flutter/material.dart';

/// App-level environment classification states.
///
/// Decoupled from native sub-model probabilities as required by research fidelity:
/// - [indoor]: Confirmed indoor space (e.g., gym, office, residential interior).
/// - [outdoor]: Confirmed open outdoor environment (e.g., park, track, street).
/// - [transition]: Intermediate transition boundary (e.g., building entrance,
///   doorway, covered portico, underpass) as formulated in Yoo (Electronics 2025).
/// - [unknown]: Degraded, conflicting, or warming-up sensor telemetry.
enum IndoorOutdoorState {
  indoor,
  outdoor,
  transition,
  unknown;

  String get code {
    switch (this) {
      case IndoorOutdoorState.indoor:
        return 'indoor';
      case IndoorOutdoorState.outdoor:
        return 'outdoor';
      case IndoorOutdoorState.transition:
        return 'transition';
      case IndoorOutdoorState.unknown:
        return 'unknown';
    }
  }

  static IndoorOutdoorState fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'indoor':
        return IndoorOutdoorState.indoor;
      case 'outdoor':
        return IndoorOutdoorState.outdoor;
      case 'transition':
        return IndoorOutdoorState.transition;
      default:
        return IndoorOutdoorState.unknown;
    }
  }

  String localizedLabel(bool isVi) {
    switch (this) {
      case IndoorOutdoorState.indoor:
        return isVi ? 'Trong nhà' : 'Indoor';
      case IndoorOutdoorState.outdoor:
        return isVi ? 'Ngoài trời' : 'Outdoor';
      case IndoorOutdoorState.transition:
        return isVi ? 'Khu vực chuyển tiếp' : 'Transition Zone';
      case IndoorOutdoorState.unknown:
        return isVi ? 'Đang xác định' : 'Determining';
    }
  }

  IconData get icon {
    switch (this) {
      case IndoorOutdoorState.indoor:
        return Icons.roofing_rounded;
      case IndoorOutdoorState.outdoor:
        return Icons.wb_sunny_rounded;
      case IndoorOutdoorState.transition:
        return Icons.door_sliding_rounded;
      case IndoorOutdoorState.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case IndoorOutdoorState.indoor:
        return const Color(0xFF3B82F6); // Vibrant Blue
      case IndoorOutdoorState.outdoor:
        return const Color(0xFF10B981); // Emerald Green
      case IndoorOutdoorState.transition:
        return const Color(0xFFF59E0B); // Amber / Orange
      case IndoorOutdoorState.unknown:
        return const Color(0xFF9CA3AF); // Muted Gray
    }
  }
}

/// Reference labels for real-world field benchmarks and manual ground-truth marking.
enum GroundTruthEnvironment {
  indoor,
  outdoor,
  transition,
  urbanCanyon,
  nearWindow,
  coveredOutdoor,
  stationary,
  other;

  String get code {
    switch (this) {
      case GroundTruthEnvironment.indoor:
        return 'indoor';
      case GroundTruthEnvironment.outdoor:
        return 'outdoor';
      case GroundTruthEnvironment.transition:
        return 'transition';
      case GroundTruthEnvironment.urbanCanyon:
        return 'urban_canyon';
      case GroundTruthEnvironment.nearWindow:
        return 'near_window';
      case GroundTruthEnvironment.coveredOutdoor:
        return 'covered_outdoor';
      case GroundTruthEnvironment.stationary:
        return 'stationary';
      case GroundTruthEnvironment.other:
        return 'other';
    }
  }

  static GroundTruthEnvironment fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'indoor':
        return GroundTruthEnvironment.indoor;
      case 'outdoor':
        return GroundTruthEnvironment.outdoor;
      case 'transition':
        return GroundTruthEnvironment.transition;
      case 'urban_canyon':
        return GroundTruthEnvironment.urbanCanyon;
      case 'near_window':
        return GroundTruthEnvironment.nearWindow;
      case 'covered_outdoor':
        return GroundTruthEnvironment.coveredOutdoor;
      case 'stationary':
        return GroundTruthEnvironment.stationary;
      default:
        return GroundTruthEnvironment.other;
    }
  }

  String localizedLabel(bool isVi) {
    switch (this) {
      case GroundTruthEnvironment.indoor:
        return isVi ? 'Trong nhà' : 'Indoor';
      case GroundTruthEnvironment.outdoor:
        return isVi ? 'Ngoài trời' : 'Outdoor';
      case GroundTruthEnvironment.transition:
        return isVi ? 'Điểm chuyển tiếp (Cửa/Lối vào)' : 'Transition (Doorway)';
      case GroundTruthEnvironment.urbanCanyon:
        return isVi ? 'Hẻm đô thị / Nhà cao tầng' : 'Urban Canyon';
      case GroundTruthEnvironment.nearWindow:
        return isVi ? 'Gần cửa sổ' : 'Near Window';
      case GroundTruthEnvironment.coveredOutdoor:
        return isVi ? 'Hành lang / Mái che ngoài trời' : 'Covered Outdoor';
      case GroundTruthEnvironment.stationary:
        return isVi ? 'Đứng yên' : 'Stationary';
      case GroundTruthEnvironment.other:
        return isVi ? 'Khác' : 'Other';
    }
  }
}

