import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';

class WorkoutMetricsCalculator {
  const WorkoutMetricsCalculator._();

  static double distanceMetersToKm(double distanceMeters) {
    if (distanceMeters <= 0) return 0.0;
    return distanceMeters / 1000.0;
  }

  static double computeAverageSpeedKmh({
    required double distanceKm,
    required int durationSec,
  }) {
    if (distanceKm <= 0 || durationSec <= 0) return 0.0;
    return distanceKm / (durationSec / 3600.0);
  }

  static double computePaceMinPerKm({
    required double distanceKm,
    required int durationSec,
  }) {
    if (distanceKm <= 0 || durationSec <= 0) return 0.0;
    return durationSec / 60.0 / distanceKm;
  }

  static int computeCaloriesKcal({
    required UserProfile profile,
    required String activityType,
    required double distanceMeters,
    required int durationSec,
    int? movingDurationSec,
  }) {
    final distanceKm = distanceMetersToKm(distanceMeters);
    final effectiveMovingSec =
        (movingDurationSec != null && movingDurationSec > 0)
            ? movingDurationSec
            : durationSec;
    final avgMovingSpeedKmh = computeAverageSpeedKmh(
      distanceKm: distanceKm,
      durationSec: effectiveMovingSec,
    );

    return profile
        .calculateCalories(
          activityType: activityType,
          distanceKm: distanceKm,
          speedKmh: avgMovingSpeedKmh,
          durationSec: durationSec,
          movingDurationSec: movingDurationSec ?? 0,
        )
        .round();
  }
}
