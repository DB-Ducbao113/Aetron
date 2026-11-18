import 'research_running_step_length.dart';
import 'research_walking_step_length.dart';

/// Missing-cadence adaptation of Renaudin et al. (2012), Eq. 8.
/// E[f] and mean reference step length come from the independent walking
/// SLEDataset2 and running RBDS fits. These are population assumptions,
/// NOT measured cadence or measured individual step length.
/// See tooling/benchmark/renaudin_fallback_replay.py (LOSO).
class ResearchStepLengthFallback {
  const ResearchStepLengthFallback._();

  static const walkingMeanFrequencyHz = 1.8835808833567846;
  static const walkingMeanStepMeters = 0.754066389702336;
  static const runningMeanFrequencyHz = 2.868713395240551;
  static const runningMeanStepMeters = 1.213448418900747;

  static double? estimateMeters({
    required String activityType,
    required double? heightCm,
  }) {
    final height = heightCm;
    final validHeight = height != null && height.isFinite;
    switch (activityType.toLowerCase()) {
      case 'walking':
        if (validHeight && height >= 160 && height <= 188) {
          return height /
                  100 *
                  (ResearchWalkingStepLength.a * walkingMeanFrequencyHz +
                      ResearchWalkingStepLength.b) +
              ResearchWalkingStepLength.c;
        }
        return walkingMeanStepMeters;
      case 'running':
        if (validHeight && height >= 162.7 && height <= 187.2) {
          final length =
              height /
                  100 *
                  (ResearchRunningStepLength.a * runningMeanFrequencyHz +
                      ResearchRunningStepLength.b) +
              ResearchRunningStepLength.c;
          if (length.isFinite && length > 0) return length;
        }
        return runningMeanStepMeters;
      case 'cycling':
        return 0;
      default:
        return null; // Other activities retain their separate legacy policy.
    }
  }
}
