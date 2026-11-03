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

  // Calculate calories burned for distance-based activities or time-based MET fallback.
  double calculateCalories({
    required String activityType,
    required double distanceKm,
    double speedKmh = 0,
    int durationSec = 0,
    int movingDurationSec = 0,
  }) {
    final genderFactor = gender.toLowerCase() == 'female' ? 0.95 : 1.0;
    if (_isDistanceBasedActivity(activityType)) {
      // Distance-based / GPS activities require valid physical displacement.
      // Elapsed time alone must NEVER accumulate active calories while stationary.
      if (distanceKm <= 0) return 0.0;
      final k = _getDistanceCalorieFactor(activityType, speedKmh);
      return weightKg * distanceKm * k * genderFactor;
    }

    // Non-GPS / non-distance activities (e.g. yoga, gym, strength, etc.)
    // use MET x active duration.
    final effectiveDurationSec =
        movingDurationSec > 0 ? movingDurationSec : durationSec;
    if (effectiveDurationSec > 0) {
      final met = _getMetForActivity(activityType);
      final durationHours = effectiveDurationSec / 3600.0;
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
    final type = activityType.toLowerCase();
    if (type.contains('run')) return 9.8;
    if (type.contains('cycl') || type.contains('bike')) return 7.5;
    if (type.contains('walk')) return 3.8;
    if (type.contains('swim')) return 8.0;
    if (type.contains('yoga')) return 3.0;
    if (type.contains('strength') || type.contains('gym') || type.contains('weight')) return 5.0;
    return 4.5;
  }

  double _getDistanceCalorieFactor(String activityType, double speedKmh) {
    final isRunning = activityType.toLowerCase().contains('run');
    double k = isRunning ? 1.05 : 0.92;
    if (speedKmh > 10) k += 0.05;
    if (speedKmh > 15) k += 0.05;
    return k;
  }
}
