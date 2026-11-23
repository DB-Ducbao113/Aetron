import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String userId,
    required double weightKg,
    required double heightCm,
    DateTime? dateOfBirth,
    @Default(0) int legacyAge,
    required String gender, // 'male' or 'female'
    required DateTime createdAt,
    required DateTime updatedAt,
    String? avatarUrl, // Supabase Storage public URL, null until uploaded
  }) = _UserProfile;

  const UserProfile._();

  double get heightM => heightCm / 100.0;

  int get age {
    if (dateOfBirth == null) return legacyAge;
    final now = DateTime.now();
    var years = now.year - dateOfBirth!.year;
    final hadBirthdayThisYear =
        now.month > dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day >= dateOfBirth!.day);
    if (!hadBirthdayThisYear) years -= 1;
    return years;
  }

  // Calculate BMI
  double get bmi => weightKg / (heightM * heightM);

  // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
  double get bmr {
    if (gender.toLowerCase() == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  /// Estimates gross kcal from standard MET x body mass (kg) x moving time (h).
  /// 2024 Adult Compendium, Herrmann et al., DOI 10.1016/j.jshs.2023.10.010.
  /// These are population-average estimates, not individual calorimetry.
  double calculateCalories({
    required String activityType,
    required double distanceKm,
    double speedKmh = 0,
    int durationSec = 0,
    int? movingDurationSec,
  }) {
    if (_isDistanceBasedActivity(activityType)) {
      // Existing app contract: zero displacement means zero *reported* workout
      // calories, even if the wall clock advances during a stationary period.
      final activeSeconds = movingDurationSec ?? durationSec;
      if (distanceKm <= 0 ||
          !distanceKm.isFinite ||
          weightKg <= 0 ||
          !weightKg.isFinite ||
          activeSeconds <= 0) {
        return 0.0;
      }
      final entry = compendiumDistanceMet(
        activityType: activityType,
        speedKmh: speedKmh,
      )!;
      return entry.met * weightKg * activeSeconds / 3600.0;
    }

    // Non-GPS / non-distance activities (e.g. yoga, gym, strength, etc.)
    // use MET x active duration.
    final effectiveDurationSec = (movingDurationSec ?? 0) > 0
        ? movingDurationSec!
        : durationSec;
    if (effectiveDurationSec > 0) {
      final met = _getMetForActivity(activityType);
      final durationHours = effectiveDurationSec / 3600.0;
      final genderFactor = gender.toLowerCase() == 'female' ? 0.95 : 1.0;
      return met * weightKg * durationHours * genderFactor;
    }

    return 0.0;
  }

  bool _isDistanceBasedActivity(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
      case 'walking':
      case 'cycling':
        return true;
      default:
        return false;
    }
  }

  double _getMetForActivity(String activityType) {
    // Legacy estimates for non-distance activities. Not yet audited against
    // individual 2024 PACOMPENDIUM entries; do not present as validated.
    final type = activityType.toLowerCase();
    if (type.contains('run')) return 9.8;
    if (type.contains('cycl') || type.contains('bike')) return 7.5;
    if (type.contains('walk')) return 3.8;
    if (type.contains('swim')) return 8.0;
    if (type.contains('yoga')) return 3.0;
    if (type.contains('strength') ||
        type.contains('gym') ||
        type.contains('weight')) {
      return 5.0;
    }
    return 4.5;
  }

  /// Returns the exact 2024 PACOMPENDIUM 5-digit activity code and standard
  /// MET value. Speed bands are in mph in the source; gaps are NOT interpolated.
  /// Without a reliable speed, use an official general/self-selected activity.
  /// https://pacompendium.com/adult-compendium/
  static ({String code, double met})? compendiumDistanceMet({
    required String activityType,
    double speedKmh = 0,
  }) {
    const kmPerMile = 1.609344;
    final mph = speedKmh.isFinite && speedKmh > 0 ? speedKmh / kmPerMile : 0.0;

    switch (activityType.toLowerCase()) {
      case 'walking':
        if (mph > 0 && mph < 2.0) return (code: '17151', met: 2.3);
        if (mph >= 2.0 && mph <= 2.4) return (code: '17152', met: 2.8);
        if (mph == 2.5) return (code: '17170', met: 3.0);
        if (mph >= 2.8 && mph <= 3.4) return (code: '17190', met: 3.8);
        if (mph >= 3.5 && mph <= 3.9) return (code: '17200', met: 4.8);
        if (mph >= 4.0 && mph <= 4.4) return (code: '17220', met: 5.5);
        if (mph >= 4.5 && mph <= 4.9) return (code: '17230', met: 7.0);
        if (mph >= 5.0 && mph <= 5.5) return (code: '17231', met: 8.5);
        return (code: '17255', met: 4.0); // Self-selected walking
      case 'running':
        if (mph >= 4.0 && mph <= 4.2) return (code: '12028', met: 6.5);
        if (mph >= 4.3 && mph <= 4.8) return (code: '12029', met: 7.8);
        if (mph >= 5.0 && mph <= 5.2) return (code: '12030', met: 8.5);
        if (mph >= 5.5 && mph <= 5.8) return (code: '12045', met: 9.0);
        if (mph >= 6.0 && mph <= 6.3) return (code: '12050', met: 9.3);
        if (mph == 6.7) return (code: '12060', met: 10.5);
        if (mph == 7.0) return (code: '12070', met: 11.0);
        if (mph == 7.5) return (code: '12080', met: 11.8);
        if (mph == 8.0) return (code: '12090', met: 12.0);
        if (mph == 8.6) return (code: '12100', met: 12.5);
        if (mph == 9.0) return (code: '12110', met: 13.0);
        if (mph >= 9.3 && mph <= 9.6) return (code: '12115', met: 14.8);
        if (mph == 10.0) return (code: '12120', met: 14.8);
        if (mph == 11.0) return (code: '12130', met: 16.8);
        if (mph == 12.0) return (code: '12132', met: 18.5);
        if (mph == 13.0) return (code: '12134', met: 19.8);
        if (mph == 14.0) return (code: '12135', met: 23.0);
        return (code: '12145', met: 10.5); // Self-selected running
      case 'cycling':
        if (mph > 0 && mph < 10.0) return (code: '01010', met: 4.0);
        if (mph >= 10.0 && mph <= 11.9) return (code: '01020', met: 6.8);
        if (mph >= 12.0 && mph <= 13.9) return (code: '01030', met: 8.0);
        if (mph >= 14.0 && mph <= 15.9) return (code: '01040', met: 10.0);
        if (mph >= 16.0 && mph <= 19.0) return (code: '01050', met: 12.0);
        // 01060 explicitly assumes racing without drafting; the app cannot
        // verify drafting. The published >20 mph intensity is an estimate.
        if (mph > 20.0) return (code: '01060', met: 16.8);
        return (code: '01014', met: 7.0); // General bicycling
      default:
        return null;
    }
  }
}
