/// Renaudin et al., Sensors 2012, Eq. (8), DOI: 10.3390/s120708507.
/// Independently fitted on SLEDataset2 walking recordings, not the authors'
/// parameters. See tooling/benchmark/renaudin_step_length_replay.py.
/// Returns metres per individual step (not a two-step gait cycle).
class ResearchWalkingStepLength {
  const ResearchWalkingStepLength._();

  // Full-cohort fit after leave-one-subject-out evaluation.
  static const double a = 0.13276343484996747;
  static const double b = 0.02165970371270505;
  static const double c = 0.27545807799439775;

  /// Return null rather than extrapolate beyond observed session-level input
  /// ranges. OS cadence substitutes for the benchmark's spectral estimate.
  static double? estimateMeters({
    required String activityType,
    required double? heightCm,
    required int? cadenceSpm,
  }) {
    if (activityType.toLowerCase() != 'walking' ||
        heightCm == null ||
        !heightCm.isFinite ||
        heightCm < 160 ||
        heightCm > 188 ||
        cadenceSpm == null ||
        cadenceSpm < 94 ||
        cadenceSpm > 144) {
      return null;
    }
    final heightMeters = heightCm / 100;
    final frequencyHz = cadenceSpm / 60;
    return heightMeters * (a * frequencyHz + b) + c;
  }
}
