import 'dart:math' as math;
import 'package:fitness_exercise_application/features/profile/domain/entities/achievement_badge.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:flutter/material.dart';

class AchievementEvaluator {
  const AchievementEvaluator._();

  static List<AchievementBadge> evaluateAchievements({
    required List<WorkoutSession> workouts,
    required int currentStreak,
    required int longestStreak,
    required double totalDistanceKm,
  }) {
    final effectiveStreak = math.max(currentStreak, longestStreak);
    final totalWorkouts = workouts.length;

    // Helper calculations from workouts list
    final hasGpsWorkout = workouts.any(
      (w) =>
          w.mode.toLowerCase() == 'gps' ||
          w.gpsAnalysis.validDistanceKm > 0 ||
          (w.filteredRouteJson.isNotEmpty && w.filteredRouteJson != '[]'),
    );

    final maxSingleDistance = workouts.isEmpty
        ? 0.0
        : workouts.map((w) => w.distanceKm).reduce(math.max);

    final runningWorkouts = workouts.where((w) {
      final type = w.activityType.toLowerCase();
      return type == 'running' || type == 'run';
    });
    final maxRunningDistance = runningWorkouts.fold<double>(
      0.0,
      (maximum, w) => math.max(maximum, w.distanceKm),
    );

    final maxSingleCalories = workouts.isEmpty
        ? 0.0
        : workouts.map((w) => w.caloriesKcal).reduce(math.max);

    final maxSingleDurationSec = workouts.isEmpty
        ? 0
        : workouts.map((w) => w.durationSec).reduce(math.max);

    // Fast pace check: Pace <= 5:00 min/km (300s/km) or speed >= 12.0 km/h on at least 3km
    final hasPaceBreaker = runningWorkouts.any((w) {
      if (w.distanceKm < 3.0) return false;
      if (w.gpsAnalysis.effectivePaceSecPerKm != null &&
          w.gpsAnalysis.effectivePaceSecPerKm! <= 300) {
        return true;
      }
      return w.avgSpeedKmh >= 12.0;
    });

    final hasDawnWorkout = workouts.any((w) => w.startedAt.toLocal().hour < 6);
    final hasNightWorkout = workouts.any(
      (w) => w.startedAt.toLocal().hour >= 20,
    );
    final hasAiSync = workouts.any(
      (w) => w.lapSplits.isNotEmpty || w.gpsAnalysis.validDistanceKm > 0,
    );

    return [
      // 1. NHÓM CỘT MỐC ĐẦU TIÊN
      AchievementBadge(
        id: 'first_signal',
        tier: BadgeTier.bronze,
        category: BadgeCategory.milestone,
        titleVi: 'Tín Hiệu Khởi Nguyên',
        titleEn: 'First Signal',
        descriptionVi: 'Hoàn thành buổi tập đầu tiên của bạn.',
        descriptionEn: 'Complete your first recorded workout session.',
        quoteVi: 'Hành trình vạn dặm bắt đầu từ bước chạy đầu tiên.',
        quoteEn: 'A thousand-mile journey begins with a single stride.',
        icon: Icons.bolt_rounded,
        currentValue: totalWorkouts.toDouble(),
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: totalWorkouts >= 1,
      ),
      AchievementBadge(
        id: 'gps_locked',
        tier: BadgeTier.bronze,
        category: BadgeCategory.milestone,
        titleVi: 'Khóa Tọa Độ GPS',
        titleEn: 'GPS Locked',
        descriptionVi:
            'Ghi nhận buổi tập ngoài trời đầu tiên có dữ liệu vệ tinh GPS.',
        descriptionEn:
            'Record your first outdoor activity with GPS satellite tracking.',
        quoteVi: 'Vẽ nên những lộ trình rực sáng đầu tiên trên bản đồ Aetron.',
        quoteEn: 'Carving your first glowing telemetry route on the map.',
        icon: Icons.gps_fixed_rounded,
        currentValue: hasGpsWorkout ? 1 : 0,
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: hasGpsWorkout,
      ),
      AchievementBadge(
        id: 'pioneer_5k',
        tier: BadgeTier.silver,
        category: BadgeCategory.milestone,
        titleVi: 'Bứt Phá 5K',
        titleEn: '5K Pioneer',
        descriptionVi: 'Chinh phục cự ly 5.0 km trong một buổi tập duy nhất.',
        descriptionEn: 'Conquer a 5.0 km distance in a single workout.',
        quoteVi:
            'Cột mốc 5.000 mét chính thức mở ra tiềm năng thể lực không giới hạn.',
        quoteEn:
            '5,000 meters unlocked. Your limitless endurance journey begins.',
        icon: Icons.directions_run_rounded,
        currentValue: math.min(maxSingleDistance, 5.0),
        targetValue: 5.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: maxSingleDistance >= 5.0,
      ),

      // 2. NHÓM CHUỖI KIÊN TRÌ (STREAK)
      AchievementBadge(
        id: '3day_spark',
        tier: BadgeTier.bronze,
        category: BadgeCategory.streak,
        titleVi: 'Tia Lửa 3 Ngày',
        titleEn: '3-Day Spark',
        descriptionVi: 'Duy trì chuỗi tập luyện liên tục trong 3 ngày.',
        descriptionEn: 'Build and sustain a 3-day consecutive workout streak.',
        quoteVi: 'Tia lửa rèn luyện đầu tiên đã được thắp sáng trong kỷ luật.',
        quoteEn: 'The first spark of discipline is ignited.',
        icon: Icons.local_fire_department_rounded,
        currentValue: math.min(effectiveStreak.toDouble(), 3.0),
        targetValue: 3.0,
        unitVi: 'ngày',
        unitEn: 'days',
        isUnlocked: effectiveStreak >= 3,
      ),
      AchievementBadge(
        id: 'weekly_ignite',
        tier: BadgeTier.silver,
        category: BadgeCategory.streak,
        titleVi: 'Chiến Binh Tuần Lễ',
        titleEn: 'Weekly Ignite',
        descriptionVi:
            'Giữ vững chuỗi tập luyện 7 ngày liên tiếp không ngắt quãng.',
        descriptionEn: 'Maintain an unbroken 7-day training streak.',
        quoteVi: '1 tuần kiên định — Bạn đã biến tập luyện thành nhịp thở.',
        quoteEn: '7 days of relentless focus — Training is now your rhythm.',
        icon: Icons.workspace_premium_rounded,
        currentValue: math.min(effectiveStreak.toDouble(), 7.0),
        targetValue: 7.0,
        unitVi: 'ngày',
        unitEn: 'days',
        isUnlocked: effectiveStreak >= 7,
      ),
      AchievementBadge(
        id: '14day_orbit',
        tier: BadgeTier.gold,
        category: BadgeCategory.streak,
        titleVi: 'Vòng Xoáy Kiên Định',
        titleEn: '14-Day Orbit',
        descriptionVi: 'Chinh phục chuỗi 14 ngày rèn luyện liên tục.',
        descriptionEn: 'Hold a 14-day training streak alive.',
        quoteVi:
            'Thói quen đã chuyển hóa thành sức mạnh ý chí không thể lay chuyển.',
        quoteEn: 'Habit has transformed into unbreakable willpower.',
        icon: Icons.military_tech_rounded,
        currentValue: math.min(effectiveStreak.toDouble(), 14.0),
        targetValue: 14.0,
        unitVi: 'ngày',
        unitEn: 'days',
        isUnlocked: effectiveStreak >= 14,
      ),
      AchievementBadge(
        id: 'unstoppable_month',
        tier: BadgeTier.quantum,
        category: BadgeCategory.streak,
        titleVi: 'Lửa Bất Diệt',
        titleEn: 'Unstoppable Month',
        descriptionVi: 'Chinh phục chuỗi 30 ngày tập luyện không ngừng nghỉ.',
        descriptionEn: 'Achieve a phenomenal 30-day continuous streak.',
        quoteVi:
            'Kỷ luật tối thượng — Bạn là biểu tượng của tinh thần bất khả chiến bại.',
        quoteEn:
            'Supreme discipline — You are the embodiment of pure resilience.',
        icon: Icons.whatshot_rounded,
        currentValue: math.min(effectiveStreak.toDouble(), 30.0),
        targetValue: 30.0,
        unitVi: 'ngày',
        unitEn: 'days',
        isUnlocked: effectiveStreak >= 30,
      ),

      // 3. NHÓM TÍCH LŨY CỰ LY
      AchievementBadge(
        id: 'distance_25k',
        tier: BadgeTier.bronze,
        category: BadgeCategory.distance,
        titleVi: 'Tích Lũy 25K',
        titleEn: 'Distance Builder',
        descriptionVi: 'Tích lũy tổng cộng 25 km qua các buổi tập.',
        descriptionEn: 'Accumulate 25 km total across your workouts.',
        quoteVi:
            'Mỗi kilômét tích lũy là một bước tiến gần hơn đến phiên bản mạnh nhất.',
        quoteEn: 'Every kilometer logged is a step closer to your peak self.',
        icon: Icons.route_rounded,
        currentValue: math.min(totalDistanceKm, 25.0),
        targetValue: 25.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: totalDistanceKm >= 25.0,
      ),
      AchievementBadge(
        id: '10k_breakthrough',
        tier: BadgeTier.silver,
        category: BadgeCategory.distance,
        titleVi: 'Chinh Phục 10K',
        titleEn: '10K Breakthrough',
        descriptionVi: 'Hoàn thành cự ly 10.0 km trong một buổi tập.',
        descriptionEn: 'Complete a single workout of 10.0 km or more.',
        quoteVi: 'Vượt ngưỡng 10.000m — Cột mốc chứng minh thể lực vượt trội.',
        quoteEn: 'Past the 10,000m threshold — Proof of elite stamina.',
        icon: Icons.speed_rounded,
        currentValue: math.min(maxSingleDistance, 10.0),
        targetValue: 10.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: maxSingleDistance >= 10.0,
      ),
      AchievementBadge(
        id: 'century_100k',
        tier: BadgeTier.gold,
        category: BadgeCategory.distance,
        titleVi: 'Thám Hiểm 100K',
        titleEn: 'Century Explorer',
        descriptionVi: 'Chinh phục tổng quãng đường tích lũy đạt mốc 100 km.',
        descriptionEn: 'Conquer a total accumulated distance of 100 km.',
        quoteVi:
            'Gia nhập câu lạc bộ 100km — Dấu ấn của những chiến binh thực thụ.',
        quoteEn: 'Joined the 100km club — The hallmark of a dedicated athlete.',
        icon: Icons.explore_rounded,
        currentValue: math.min(totalDistanceKm, 100.0),
        targetValue: 100.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: totalDistanceKm >= 100.0,
      ),
      AchievementBadge(
        id: 'half_marathon_21k',
        tier: BadgeTier.gold,
        category: BadgeCategory.distance,
        titleVi: 'Bán Marathon 21K',
        titleEn: 'Half-Marathon Pilot',
        descriptionVi: 'Chạy cự ly bán marathon 21,1 km trong một buổi.',
        descriptionEn: 'Run a half-marathon distance (21.1 km) in one session.',
        quoteVi:
            '21.0975 km kiên cường — Đỉnh cao của sự bền bỉ cơ thể và tâm trí.',
        quoteEn:
            '21.0975 km conquered — The triumph of endurance and willpower.',
        icon: Icons.emoji_events_rounded,
        currentValue: math.min(maxRunningDistance, 21.0975),
        targetValue: 21.0975,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: maxRunningDistance >= 21.0975,
      ),
      AchievementBadge(
        id: 'quantum_500k',
        tier: BadgeTier.quantum,
        category: BadgeCategory.distance,
        titleVi: 'Hành Trình Xuyên Không',
        titleEn: 'Quantum 500K',
        descriptionVi: 'Chinh phục tổng tích lũy phi thường 500 km.',
        descriptionEn: 'Accumulate a monumental 500 km total distance.',
        quoteVi:
            'Quãng đường đủ để băng qua nhiều thành phố — Đẳng cấp Cyber Athlete.',
        quoteEn: 'A journey spanning cities — True Cyber Athlete supremacy.',
        icon: Icons.public_rounded,
        currentValue: math.min(totalDistanceKm, 500.0),
        targetValue: 500.0,
        unitVi: 'km',
        unitEn: 'km',
        isUnlocked: totalDistanceKm >= 500.0,
      ),

      // 4. NHÓM HIỆU SUẤT & TỐC ĐỘ
      AchievementBadge(
        id: 'pace_breaker',
        tier: BadgeTier.silver,
        category: BadgeCategory.speed,
        titleVi: 'Phá Vỡ Tốc Độ',
        titleEn: 'Pace Breaker',
        descriptionVi:
            'Chạy với pace tối đa 5:00 phút/km (ít nhất 12 km/h) trên cự ly tối thiểu 3 km.',
        descriptionEn: 'Run at 5:00 min/km pace or faster over at least 3 km.',
        quoteVi: 'Tốc độ thần tốc xé gió bứt phá khỏi mọi giới hạn an toàn.',
        quoteEn: 'Lightning speed surging beyond comfort zones.',
        icon: Icons.electric_bolt_rounded,
        currentValue: hasPaceBreaker ? 1 : 0,
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: hasPaceBreaker,
      ),
      AchievementBadge(
        id: 'calorie_reactor',
        tier: BadgeTier.silver,
        category: BadgeCategory.speed,
        titleVi: 'Lò Phản Ứng Calo',
        titleEn: 'Calorie Reactor',
        descriptionVi: 'Đốt cháy trên 500 kcal trong một buổi tập.',
        descriptionEn: 'Burn over 500 kcal in a single workout.',
        quoteVi: 'Giải phóng nguồn năng lượng nhiệt hạch dũng mãnh.',
        quoteEn: 'Unleashing immense metabolic power in one session.',
        icon: Icons.local_fire_department_outlined,
        currentValue: math.min(maxSingleCalories, 500.0),
        targetValue: 500.0,
        unitVi: 'kcal',
        unitEn: 'kcal',
        isUnlocked: maxSingleCalories >= 500,
      ),
      AchievementBadge(
        id: 'iron_endurance',
        tier: BadgeTier.gold,
        category: BadgeCategory.speed,
        titleVi: 'Sức Bền Thiết Giáp',
        titleEn: 'Iron Endurance',
        descriptionVi: 'Duy trì hoạt động thể thao liên tục trên 60 phút.',
        descriptionEn:
            'Sustain active exercise for over 60 continuous minutes.',
        quoteVi: 'Ý chí kiên định chiến thắng sự mệt mỏi theo từng nhịp tim.',
        quoteEn:
            'Unwavering stamina prevailing over fatigue with every heartbeat.',
        icon: Icons.timer_rounded,
        currentValue: math.min((maxSingleDurationSec / 60).toDouble(), 60.0),
        targetValue: 60.0,
        unitVi: 'phút',
        unitEn: 'min',
        isUnlocked: maxSingleDurationSec >= 3600,
      ),

      // 5. NHÓM ĐẶC BIỆT & THÓI QUEN
      AchievementBadge(
        id: 'dawn_runner',
        tier: BadgeTier.bronze,
        category: BadgeCategory.special,
        titleVi: 'Chiến Binh Bình Minh',
        titleEn: 'Dawn Runner',
        descriptionVi: 'Bắt đầu và hoàn thành buổi tập trước 06:00 sáng.',
        descriptionEn: 'Start and complete a session before 6:00 AM.',
        quoteVi:
            'Thức dậy trước bình minh để kiến tạo chiến thắng cho ngày mới.',
        quoteEn: 'Awakening before the sun to conquer the day ahead.',
        icon: Icons.wb_sunny_rounded,
        currentValue: hasDawnWorkout ? 1 : 0,
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: hasDawnWorkout,
      ),
      AchievementBadge(
        id: 'night_strider',
        tier: BadgeTier.bronze,
        category: BadgeCategory.special,
        titleVi: 'Thợ Săn Hoàng Hôn',
        titleEn: 'Night Strider',
        descriptionVi: 'Hoàn thành buổi tập sau 20:00 tối.',
        descriptionEn: 'Complete a workout session after 8:00 PM.',
        quoteVi: 'Màn đêm tĩnh lặng là sàn đấu của những sải chân kiên cường.',
        quoteEn: 'The quiet night is the arena for relentless strides.',
        icon: Icons.nightlight_round,
        currentValue: hasNightWorkout ? 1 : 0,
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: hasNightWorkout,
      ),
      AchievementBadge(
        id: 'program_master',
        tier: BadgeTier.silver,
        category: BadgeCategory.special,
        titleVi: 'Chiến Binh Giáo Án',
        titleEn: 'Program Master',
        descriptionVi: 'Hoàn thành buổi tập theo giáo án bài bản.',
        descriptionEn: 'Complete a structured training program.',
        quoteVi:
            'Rèn luyện kỷ luật theo giáo trình để chinh phục đỉnh cao phong độ.',
        quoteEn:
            'Disciplined training structure to reach peak athletic performance.',
        icon: Icons.military_tech_rounded,
        currentValue: hasAiSync ? 1 : 0,
        targetValue: 1,
        unitVi: 'buổi',
        unitEn: 'session',
        isUnlocked: hasAiSync,
      ),
    ];
  }
}
