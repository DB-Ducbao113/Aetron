import 'dart:math' as math;
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';

class SingleRecordItem {
  final String id;
  final String titleVi;
  final String titleEn;
  final String category;
  final double? numericValue;
  final int? durationSec;
  final DateTime? achievedAt;
  final String? workoutId;
  final bool isUnlocked;
  final bool isEstimated;
  final String unlockHintVi;
  final String unlockHintEn;

  const SingleRecordItem({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.category,
    this.numericValue,
    this.durationSec,
    this.achievedAt,
    this.workoutId,
    required this.isUnlocked,
    this.isEstimated = false,
    required this.unlockHintVi,
    required this.unlockHintEn,
  });
}

class DetailedPersonalRecords {
  final SingleRecordItem best1k;
  final SingleRecordItem best5k;
  final SingleRecordItem best10k;
  final SingleRecordItem best21k;
  final SingleRecordItem longestDistance;
  final SingleRecordItem fastestPace;
  final SingleRecordItem maxCalories;
  final SingleRecordItem longestDuration;

  const DetailedPersonalRecords({
    required this.best1k,
    required this.best5k,
    required this.best10k,
    required this.best21k,
    required this.longestDistance,
    required this.fastestPace,
    required this.maxCalories,
    required this.longestDuration,
  });

  List<SingleRecordItem> get allRecords => [
    best1k,
    best5k,
    best10k,
    best21k,
    longestDistance,
    fastestPace,
    maxCalories,
    longestDuration,
  ];

  int get unlockedCount => allRecords.where((r) => r.isUnlocked).length;

  factory DetailedPersonalRecords.fromWorkouts(List<WorkoutSession> workouts) {
    if (workouts.isEmpty) {
      return DetailedPersonalRecords._allLocked();
    }

    // 1. Best 1K
    SingleRecordItem best1k = const SingleRecordItem(
      id: 'pr_1k',
      titleVi: '1K Bứt Tốc',
      titleEn: 'Fastest 1K',
      category: 'speed',
      isUnlocked: false,
      unlockHintVi: 'Chạy ≥ 1.0 km để xác lập kỷ lục',
      unlockHintEn: 'Run ≥ 1.0 km to set a record',
    );

    // 2. Best 5K
    SingleRecordItem best5k = const SingleRecordItem(
      id: 'pr_5k',
      titleVi: '5K Chuẩn Mực',
      titleEn: 'Fastest 5K',
      category: 'distance',
      isUnlocked: false,
      unlockHintVi: 'Chạy ≥ 5.0 km để xác lập kỷ lục',
      unlockHintEn: 'Run ≥ 5.0 km to set a record',
    );

    // 3. Best 10K
    SingleRecordItem best10k = const SingleRecordItem(
      id: 'pr_10k',
      titleVi: '10K Đột Phá',
      titleEn: 'Fastest 10K',
      category: 'distance',
      isUnlocked: false,
      unlockHintVi: 'Chạy ≥ 10.0 km để xác lập kỷ lục',
      unlockHintEn: 'Run ≥ 10.0 km to set a record',
    );

    // 4. Best 21.1K Half-Marathon
    SingleRecordItem best21k = const SingleRecordItem(
      id: 'pr_21k',
      titleVi: '21.1K Bán Marathon',
      titleEn: 'Half-Marathon (21.1K)',
      category: 'distance',
      isUnlocked: false,
      unlockHintVi: 'Chạy ≥ 21.1 km để xác lập kỷ lục',
      unlockHintEn: 'Run ≥ 21.1 km to set a record',
    );

    // 5. Longest Distance
    SingleRecordItem longestDist = const SingleRecordItem(
      id: 'pr_longest_dist',
      titleVi: 'Quãng Đường Xa Nhất',
      titleEn: 'Longest Distance',
      category: 'endurance',
      isUnlocked: false,
      unlockHintVi: 'Hoàn thành buổi tập đầu tiên',
      unlockHintEn: 'Complete your first workout',
    );

    // 6. Fastest Pace
    SingleRecordItem fastestPace = const SingleRecordItem(
      id: 'pr_fastest_pace',
      titleVi: 'Pace Nhanh Nhất',
      titleEn: 'Top Pace',
      category: 'speed',
      isUnlocked: false,
      unlockHintVi: 'Hoàn thành buổi tập có tốc độ ghi nhận',
      unlockHintEn: 'Complete a workout with recorded speed',
    );

    // 7. Max Calories
    SingleRecordItem maxCalories = const SingleRecordItem(
      id: 'pr_max_cal',
      titleVi: 'Calo Đốt Kỷ Lục',
      titleEn: 'Max Calorie Burn',
      category: 'energy',
      isUnlocked: false,
      unlockHintVi: 'Tập luyện để đốt cháy calo',
      unlockHintEn: 'Work out to burn calories',
    );

    // 8. Longest Duration
    SingleRecordItem longestDuration = const SingleRecordItem(
      id: 'pr_longest_dur',
      titleVi: 'Thời Lượng Lâu Nhất',
      titleEn: 'Longest Duration',
      category: 'endurance',
      isUnlocked: false,
      unlockHintVi: 'Duy trì buổi tập dài hơn',
      unlockHintEn: 'Sustain a longer workout',
    );

    int? min1kSec;
    int? min5kSec;
    int? min10kSec;
    int? min21kSec;
    double maxDistKm = 0;
    double maxSpeedKmh = 0;
    double maxCal = 0;
    int maxDurSec = 0;

    for (final w in workouts) {
      final dist = w.gpsAnalysis.validDistanceKm > 0
          ? w.gpsAnalysis.validDistanceKm
          : w.distanceKm;

      final isRun =
          w.activityType.toLowerCase() == 'running' ||
          w.activityType.toLowerCase() == 'run';
      final hasTimedDistance = isRun && dist.isFinite && w.durationSec > 0;

      // Ignore partial closing laps; they are not one-kilometre records.
      if (hasTimedDistance && dist >= 1.0) {
        final fullLaps = w.lapSplits.where(
          (s) => (s.distanceKm - 1.0).abs() <= .001 && s.durationSeconds > 0,
        );
        final estimated = fullLaps.isEmpty && (dist - 1.0).abs() > .001;
        final time1k = fullLaps.isEmpty
            ? (w.durationSec / dist).round()
            : fullLaps.map((s) => s.durationSeconds).reduce(math.min);
        if (time1k > 0 && (min1kSec == null || time1k < min1kSec)) {
          min1kSec = time1k;
          best1k = SingleRecordItem(
            id: 'pr_1k',
            titleVi: '1K Bứt Tốc',
            titleEn: 'Fastest 1K',
            category: 'speed',
            durationSec: time1k,
            isEstimated: estimated,
            achievedAt: w.startedAt,
            workoutId: w.id,
            isUnlocked: true,
            unlockHintVi: '',
            unlockHintEn: '',
          );
        }
      }

      // Check 5K
      if (hasTimedDistance && dist >= 5.0) {
        final time5k = (w.durationSec * (5.0 / dist)).round();
        if (time5k > 0 && (min5kSec == null || time5k < min5kSec)) {
          min5kSec = time5k;
          best5k = SingleRecordItem(
            id: 'pr_5k',
            titleVi: '5K Chuẩn Mực',
            titleEn: 'Fastest 5K',
            category: 'distance',
            durationSec: time5k,
            isEstimated: (dist - 5.0).abs() > .001,
            achievedAt: w.startedAt,
            workoutId: w.id,
            isUnlocked: true,
            unlockHintVi: '',
            unlockHintEn: '',
          );
        }
      }

      // Check 10K
      if (hasTimedDistance && dist >= 10.0) {
        final time10k = (w.durationSec * (10.0 / dist)).round();
        if (time10k > 0 && (min10kSec == null || time10k < min10kSec)) {
          min10kSec = time10k;
          best10k = SingleRecordItem(
            id: 'pr_10k',
            titleVi: '10K Đột Phá',
            titleEn: 'Fastest 10K',
            category: 'distance',
            durationSec: time10k,
            isEstimated: (dist - 10.0).abs() > .001,
            achievedAt: w.startedAt,
            workoutId: w.id,
            isUnlocked: true,
            unlockHintVi: '',
            unlockHintEn: '',
          );
        }
      }

      // Check 21.1K
      if (hasTimedDistance && dist >= 21.0975) {
        final time21k = (w.durationSec * (21.0975 / dist)).round();
        if (time21k > 0 && (min21kSec == null || time21k < min21kSec)) {
          min21kSec = time21k;
          best21k = SingleRecordItem(
            id: 'pr_21k',
            titleVi: '21.1K Bán Marathon',
            titleEn: 'Half-Marathon (21.1K)',
            category: 'distance',
            durationSec: time21k,
            isEstimated: (dist - 21.0975).abs() > .001,
            achievedAt: w.startedAt,
            workoutId: w.id,
            isUnlocked: true,
            unlockHintVi: '',
            unlockHintEn: '',
          );
        }
      }

      // Longest Distance
      if (dist > maxDistKm) {
        maxDistKm = dist;
        longestDist = SingleRecordItem(
          id: 'pr_longest_dist',
          titleVi: 'Quãng Đường Xa Nhất',
          titleEn: 'Longest Distance',
          category: 'endurance',
          numericValue: dist,
          achievedAt: w.startedAt,
          workoutId: w.id,
          isUnlocked: true,
          unlockHintVi: '',
          unlockHintEn: '',
        );
      }

      // Fastest Pace (Speed > 0)
      if (w.avgSpeedKmh > maxSpeedKmh) {
        maxSpeedKmh = w.avgSpeedKmh;
        fastestPace = SingleRecordItem(
          id: 'pr_fastest_pace',
          titleVi: 'Pace Nhanh Nhất',
          titleEn: 'Top Pace',
          category: 'speed',
          numericValue: w.avgSpeedKmh,
          achievedAt: w.startedAt,
          workoutId: w.id,
          isUnlocked: true,
          unlockHintVi: '',
          unlockHintEn: '',
        );
      }

      // Max Calories
      if (w.caloriesKcal > maxCal) {
        maxCal = w.caloriesKcal;
        maxCalories = SingleRecordItem(
          id: 'pr_max_cal',
          titleVi: 'Calo Đốt Kỷ Lục',
          titleEn: 'Max Calorie Burn',
          category: 'energy',
          numericValue: w.caloriesKcal,
          achievedAt: w.startedAt,
          workoutId: w.id,
          isUnlocked: true,
          unlockHintVi: '',
          unlockHintEn: '',
        );
      }

      // Longest Duration
      if (w.durationSec > maxDurSec) {
        maxDurSec = w.durationSec;
        longestDuration = SingleRecordItem(
          id: 'pr_longest_dur',
          titleVi: 'Thời Lượng Lâu Nhất',
          titleEn: 'Longest Duration',
          category: 'endurance',
          durationSec: w.durationSec,
          achievedAt: w.startedAt,
          workoutId: w.id,
          isUnlocked: true,
          unlockHintVi: '',
          unlockHintEn: '',
        );
      }
    }

    return DetailedPersonalRecords(
      best1k: best1k,
      best5k: best5k,
      best10k: best10k,
      best21k: best21k,
      longestDistance: longestDist,
      fastestPace: fastestPace,
      maxCalories: maxCalories,
      longestDuration: longestDuration,
    );
  }

  factory DetailedPersonalRecords._allLocked() {
    return const DetailedPersonalRecords(
      best1k: SingleRecordItem(
        id: 'pr_1k',
        titleVi: '1K Bứt Tốc',
        titleEn: 'Fastest 1K',
        category: 'speed',
        isUnlocked: false,
        unlockHintVi: 'Chạy ≥ 1.0 km để xác lập kỷ lục',
        unlockHintEn: 'Run ≥ 1.0 km to set a record',
      ),
      best5k: SingleRecordItem(
        id: 'pr_5k',
        titleVi: '5K Chuẩn Mực',
        titleEn: 'Fastest 5K',
        category: 'distance',
        isUnlocked: false,
        unlockHintVi: 'Chạy ≥ 5.0 km để xác lập kỷ lục',
        unlockHintEn: 'Run ≥ 5.0 km to set a record',
      ),
      best10k: SingleRecordItem(
        id: 'pr_10k',
        titleVi: '10K Đột Phá',
        titleEn: 'Fastest 10K',
        category: 'distance',
        isUnlocked: false,
        unlockHintVi: 'Chạy ≥ 10.0 km để xác lập kỷ lục',
        unlockHintEn: 'Run ≥ 10.0 km to set a record',
      ),
      best21k: SingleRecordItem(
        id: 'pr_21k',
        titleVi: '21.1K Bán Marathon',
        titleEn: 'Half-Marathon (21.1K)',
        category: 'distance',
        isUnlocked: false,
        unlockHintVi: 'Chạy ≥ 21.1 km để xác lập kỷ lục',
        unlockHintEn: 'Run ≥ 21.1 km to set a record',
      ),
      longestDistance: SingleRecordItem(
        id: 'pr_longest_dist',
        titleVi: 'Quãng Đường Xa Nhất',
        titleEn: 'Longest Distance',
        category: 'endurance',
        isUnlocked: false,
        unlockHintVi: 'Hoàn thành buổi tập đầu tiên',
        unlockHintEn: 'Complete your first workout',
      ),
      fastestPace: SingleRecordItem(
        id: 'pr_fastest_pace',
        titleVi: 'Pace Nhanh Nhất',
        titleEn: 'Top Pace',
        category: 'speed',
        isUnlocked: false,
        unlockHintVi: 'Hoàn thành buổi tập có tốc độ ghi nhận',
        unlockHintEn: 'Complete a workout with recorded speed',
      ),
      maxCalories: SingleRecordItem(
        id: 'pr_max_cal',
        titleVi: 'Calo Đốt Kỷ Lục',
        titleEn: 'Max Calorie Burn',
        category: 'energy',
        isUnlocked: false,
        unlockHintVi: 'Tập luyện để đốt cháy calo',
        unlockHintEn: 'Work out to burn calories',
      ),
      longestDuration: SingleRecordItem(
        id: 'pr_longest_dur',
        titleVi: 'Thời Lượng Lâu Nhất',
        titleEn: 'Longest Duration',
        category: 'endurance',
        isUnlocked: false,
        unlockHintVi: 'Duy trì buổi tập dài hơn',
        unlockHintEn: 'Sustain a longer workout',
      ),
    );
  }
}
