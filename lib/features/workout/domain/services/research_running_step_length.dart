/// Running-specific adaptation of Renaudin et al. (2012), Eq. 8,
/// DOI 10.3390/s120708507. Coefficients fitted on the original 28 runners
/// of Fukuchi et al. (2017), DOI 10.7717/peerj.3298.
/// See tooling/benchmark/renaudin_running_rbds.py.
/// Returns metres per individual step, not a full gait cycle.
class ResearchRunningStepLength {
  const ResearchRunningStepLength._();

  static const double a = 0.3210564550962659;
  static const double b = 0.7252540911327735;
  static const double c = -1.680950042382748;

  static double? estimateMeters({
    required String activityType,
    required double? heightCm,
    required int? cadenceSpm,
  }) {
    if (activityType.toLowerCase() != 'running' ||
        heightCm == null ||
        !heightCm.isFinite ||
        heightCm < 162.7 ||
        heightCm > 187.2 ||
        cadenceSpm == null ||
        cadenceSpm < 143 ||
        cadenceSpm > 223) {
      return null;
    }
    final length = heightCm / 100 * (a * cadenceSpm / 60 + b) + c;
    return length.isFinite && length > 0 ? length : null;
  }
}
