import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/program_interactive_timeline.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunningProgramsScreen extends ConsumerWidget {
  static void showProgramGuide(BuildContext context, StructuredRunningProgram program) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProgramGuideSheet(program: program),
    );
  }

  const RunningProgramsScreen({super.key});

  static final List<StructuredRunningProgram> programs = [
    StructuredRunningProgram(
      id: 'couch_to_5k',
      titleKey: 'couch_to_5k',
      badgeEn: 'BEGINNER • 4 WEEKS',
      badgeVi: 'NGƯỜI MỚI • 4 TUẦN',
      targetDistance: '5.0 km',
      targetPace: '6:00 - 7:00 min/km',
      targetZone: 'Zone 2 (125-140 bpm)',
      cadence: '165-170 spm',
      descriptionEn: 'Ideal for beginners building endurance from zero to running 5km continuously without fatigue.',
      descriptionVi: 'Giáo án chuẩn cho người mới bắt đầu luyện tập sức bền từ 0 đến chạy liên tục 5km không mệt mỏi.',
      instructionsEn: [
        '1. Warm Up: 5 minutes walking + dynamic leg swings.',
        '2. Interval Routine: Run 1 minute, walk 1.5 minutes (Repeat 8 times).',
        '3. Form Tip: Maintain upright posture and midfoot landing.',
        '4. Cool Down: 5 minutes slow walk & calf stretching.',
      ],
      instructionsVi: [
        '1. Khởi động: 5 phút đi bộ nhẹ nhàng + xoay khớp gối, cổ chân.',
        '2. Tiến trình: Chạy 1 phút, đi bộ 1.5 phút (Lặp lại 8 hiệp).',
        '3. Kỹ thuật: Giữ tư thế thẳng người, tiếp đất bằng giữa bàn chân.',
        '4. Thả lỏng: 5 phút đi bộ chậm & giãn cơ bắp chân.',
      ],
      steps: [
        // 1. Warm Up Walk (5 mins)
        const ProgramStep(
          id: 'c25k_warmup',
          titleEn: 'WARM UP WALK',
          titleVi: 'KHỞI ĐỘNG ĐI BỘ',
          durationSeconds: 300,
          phaseType: ProgramPhaseType.warmup,
          targetPaceMinSecKm: 600, // 10:00/km
          targetPaceMaxSecKm: 720, // 12:00/km
          targetPaceDisplay: '10:00 - 12:00 min/km',
          targetHrZone: 'Zone 1 (90-115 bpm)',
          tipEn: 'Breathe deeply and rotate joints gently.',
          tipVi: 'Đi bộ bước dài, hít thở sâu và xoay cổ chân.',
        ),
        // 8 x Run 1m + Walk 1.5m
        for (var i = 1; i <= 8; i++) ...[
          ProgramStep(
            id: 'c25k_run_$i',
            titleEn: 'RUN INTERVAL ($i/8)',
            titleVi: 'CHẠY BỨT TỐC ($i/8)',
            durationSeconds: 60,
            phaseType: ProgramPhaseType.run,
            targetPaceMinSecKm: 330, // 5:30/km
            targetPaceMaxSecKm: 420, // 7:00/km
            targetPaceDisplay: '5:30 - 7:00 min/km',
            targetHrZone: 'Zone 2-3 (130-150 bpm)',
            tipEn: 'Maintain smooth rhythm and light midfoot landing.',
            tipVi: 'Giữ lưng thẳng, tiếp đất nhẹ nhàng bằng nửa bàn chân.',
          ),
          ProgramStep(
            id: 'c25k_walk_$i',
            titleEn: 'RECOVERY WALK ($i/8)',
            titleVi: 'ĐI BỘ HỒI SỨC ($i/8)',
            durationSeconds: 90,
            phaseType: ProgramPhaseType.walk,
            targetPaceMinSecKm: 570, // 9:30/km
            targetPaceMaxSecKm: 690, // 11:30/km
            targetPaceDisplay: '9:30 - 11:30 min/km',
            targetHrZone: 'Zone 1 (100-120 bpm)',
            tipEn: 'Lower your heart rate with deep nasal breathing.',
            tipVi: 'Thả lỏng cánh tay, hít thở chậm để hạ nhịp tim.',
          ),
        ],
        // Cooldown (5 mins)
        const ProgramStep(
          id: 'c25k_cooldown',
          titleEn: 'COOL DOWN & STRETCH',
          titleVi: 'THẢ LỎNG & GIÃN CƠ',
          durationSeconds: 300,
          phaseType: ProgramPhaseType.cooldown,
          targetPaceMinSecKm: 600,
          targetPaceMaxSecKm: 780,
          targetPaceDisplay: '10:00 - 13:00 min/km',
          targetHrZone: 'Zone 1 (< 110 bpm)',
          tipEn: 'Slow walking and gentle leg stretches.',
          tipVi: 'Đi bộ rất chậm, thả lỏng toàn bộ cơ bắp.',
        ),
      ],
      imageAsset: 'assets/plan_couch_to_5k.jpg',
    ),
    StructuredRunningProgram(
      id: 'easy_base_run',
      titleKey: 'easy_base_run',
      badgeEn: 'RECOVERY • ZONE 2 BASE',
      badgeVi: 'PHỤC HỒI • ZONE 2 BASE',
      targetDistance: '3.0 - 5.0 km',
      targetPace: '7:00 - 8:00 min/km',
      targetZone: 'Zone 2 Low HR',
      cadence: '160-165 spm',
      descriptionEn: 'Conversational pace recovery run to strengthen aerobic base and burn fat with low joint stress.',
      descriptionVi: 'Bài chạy thả lỏng tốc độ nói chuyện giúp củng cố tim mạch Zone 2, đốt mỡ hiệu quả và giảm áp lực lên khớp.',
      instructionsEn: [
        '1. Warm Up: 3 minutes light jog.',
        '2. Main Run: Maintain steady Zone 2 heart rate (able to speak full sentences).',
        '3. Breathing: Deep 2:2 nasal-diaphragmatic breathing.',
        '4. Cool Down: 3 minutes walk.',
      ],
      instructionsVi: [
        '1. Khởi động: 3 phút chạy chậm thả lỏng.',
        '2. Bài chạy chính: Giữ nhịp tim Zone 2 ổn định (vừa chạy vừa nói chuyện bình thường).',
        '3. Nhịp thở: Hít thở sâu 2 nhịp vào, 2 nhịp ra bằng cơ hoành.',
        '4. Thả lỏng: 3 phút đi bộ.',
      ],
      steps: [
        const ProgramStep(
          id: 'easy_warmup',
          titleEn: 'WARM UP JOG',
          titleVi: 'KHỞI ĐỘNG NHẸ',
          durationSeconds: 180,
          phaseType: ProgramPhaseType.warmup,
          targetPaceMinSecKm: 510,
          targetPaceMaxSecKm: 600,
          targetPaceDisplay: '8:30 - 10:00 min/km',
          targetHrZone: 'Zone 1 (100-115 bpm)',
          tipEn: 'Start slow and get blood flowing.',
          tipVi: 'Chạy chậm rãi làm nóng cơ thể.',
        ),
        const ProgramStep(
          id: 'easy_main_run',
          titleEn: 'STEADY ZONE 2 RUN',
          titleVi: 'CHẠY ĐỀU ZONE 2',
          durationSeconds: 1800, // 30 mins
          phaseType: ProgramPhaseType.run,
          targetPaceMinSecKm: 420, // 7:00/km
          targetPaceMaxSecKm: 480, // 8:00/km
          targetPaceDisplay: '7:00 - 8:00 min/km',
          targetHrZone: 'Zone 2 (120-138 bpm)',
          tipEn: 'Keep conversational pace. Slow down if out of breath.',
          tipVi: 'Giữ tốc độ có thể nói chuyện bình thường.',
        ),
        const ProgramStep(
          id: 'easy_cooldown',
          titleEn: 'COOL DOWN WALK',
          titleVi: 'ĐI BỘ THẢ LỎNG',
          durationSeconds: 180,
          phaseType: ProgramPhaseType.cooldown,
          targetPaceMinSecKm: 600,
          targetPaceMaxSecKm: 720,
          targetPaceDisplay: '10:00 - 12:00 min/km',
          targetHrZone: 'Zone 1 (< 110 bpm)',
          tipEn: 'Deep breathing to return heart rate to normal.',
          tipVi: 'Hít thở sâu để nhịp tim trở lại bình thường.',
        ),
      ],
      imageAsset: 'assets/plan_easy_base_run.jpg',
    ),
    StructuredRunningProgram(
      id: 'pace_builder_10k',
      titleKey: 'pace_builder_10k',
      badgeEn: 'INTERMEDIATE • 6 WEEKS',
      badgeVi: 'TRUNG CẤP • 6 TUẦN',
      targetDistance: '10.0 km',
      targetPace: '5:45 - 6:30 min/km',
      targetZone: 'Zone 3 Tempo Pace',
      cadence: '170-178 spm',
      descriptionEn: 'Build stamina and sustain a faster 10K race pace with structured tempo runs and progressive volume.',
      descriptionVi: 'Rèn luyện khả năng duy trì tốc độ cho cự ly 10km thông qua các bài Tempo run nâng dần khối lượng.',
      instructionsEn: [
        '1. Warm Up: 10 minutes easy jog + 3 strides.',
        '2. Main Workout: 6 km Tempo run at target 10K race pace.',
        '3. Cadence Tip: Keep quick compact steps at ~175 spm.',
        '4. Cool Down: 5 minutes light jog.',
      ],
      instructionsVi: [
        '1. Khởi động: 10 phút chạy nhẹ + 3 nhịp tăng tốc ngắn.',
        '2. Bài chính: 6 km Tempo run ở tốc độ mục tiêu 10km.',
        '3. Mẹo sải chân: Duy trì nhịp chân nhanh guồng ~175 spm.',
        '4. Thả lỏng: 5 phút chạy thả lỏng.',
      ],
      steps: [
        const ProgramStep(
          id: '10k_warmup',
          titleEn: 'WARM UP JOG',
          titleVi: 'KHỞI ĐỘNG CHẠY NHẸ',
          durationSeconds: 600, // 10 mins
          phaseType: ProgramPhaseType.warmup,
          targetPaceMinSecKm: 420,
          targetPaceMaxSecKm: 480,
          targetPaceDisplay: '7:00 - 8:00 min/km',
          targetHrZone: 'Zone 2 (120-135 bpm)',
          tipEn: 'Gradually increase stride speed.',
          tipVi: 'Tăng dần nhịp chân và làm nóng cơ thể.',
        ),
        const ProgramStep(
          id: '10k_tempo_main',
          titleEn: 'TEMPO 10K RACE PACE',
          titleVi: 'CHẠY TEMPO TỐC ĐỘ 10K',
          durationSeconds: 2100, // 35 mins
          phaseType: ProgramPhaseType.tempo,
          targetPaceMinSecKm: 345, // 5:45/km
          targetPaceMaxSecKm: 390, // 6:30/km
          targetPaceDisplay: '5:45 - 6:30 min/km',
          targetHrZone: 'Zone 3-4 (145-165 bpm)',
          tipEn: 'Maintain rhythmic cadence around 175 spm.',
          tipVi: 'Duy trì guồng chân đều đặn ~175 bước/phút.',
        ),
        const ProgramStep(
          id: '10k_cooldown',
          titleEn: 'COOL DOWN JOG',
          titleVi: 'CHẠY CHẬM THẢ LỎNG',
          durationSeconds: 300,
          phaseType: ProgramPhaseType.cooldown,
          targetPaceMinSecKm: 480,
          targetPaceMaxSecKm: 600,
          targetPaceDisplay: '8:00 - 10:00 min/km',
          targetHrZone: 'Zone 1-2 (110-125 bpm)',
          tipEn: 'Gradually bring breathing back down.',
          tipVi: 'Thả lỏng vai và bắp chân.',
        ),
      ],
      imageAsset: 'assets/plan_pace_builder_10k.jpg',
    ),
    StructuredRunningProgram(
      id: 'speed_intervals',
      titleKey: 'speed_intervals',
      badgeEn: 'ADVANCED • SPEEDWORK',
      badgeVi: 'TỐC ĐỘ • NÂNG CAO',
      targetDistance: '6.0 km Total',
      targetPace: '4:30 - 5:15 min/km',
      targetZone: 'Zone 4-5 High HR',
      cadence: '178-185 spm',
      descriptionEn: 'High-intensity interval training (HIIT) to boost VO2 Max, lactate threshold, and maximum stride turnover.',
      descriptionVi: 'Luyện tập biến tốc cường độ cao (HIIT) giúp tăng chỉ số VO2 Max, ngưỡng lactate và sải chân tối đa.',
      instructionsEn: [
        '1. Warm Up: 10 minutes progressive jog + dynamic stretches.',
        '2. Speedwork: 6 sets of 90-sec fast strides at 4:30-5:15 pace with 90-sec recovery walks.',
        '3. Form Focus: Powerful hip drive and forward lean.',
        '4. Cool Down: 5 minutes slow jog.',
      ],
      instructionsVi: [
        '1. Khởi động: 10 phút chạy tăng dần tốc độ + giãn cơ động.',
        '2. Biến tốc: 6 hiệp chạy nhanh 90 giây ở tốc độ 4:30-5:15, xen kẽ 90 giây đi bộ.',
        '3. Kỹ thuật: Đánh tay mạnh mẽ, hướng trọng tâm về phía trước.',
        '4. Thả lỏng: 5 phút chạy chậm.',
      ],
      steps: [
        const ProgramStep(
          id: 'speed_warmup',
          titleEn: 'WARM UP JOG',
          titleVi: 'KHỞI ĐỘNG CHẠY NHẸ',
          durationSeconds: 600,
          phaseType: ProgramPhaseType.warmup,
          targetPaceMinSecKm: 420,
          targetPaceMaxSecKm: 480,
          targetPaceDisplay: '7:00 - 8:00 min/km',
          targetHrZone: 'Zone 2 (125-140 bpm)',
          tipEn: 'Warm up muscles and elevate body temperature.',
          tipVi: 'Khởi động kỹ các khớp gối và cơ đùi.',
        ),
        for (var i = 1; i <= 6; i++) ...[
          ProgramStep(
            id: 'speed_sprint_$i',
            titleEn: 'SPEED STRIDE ($i/6)',
            titleVi: 'BỨT TỐC NHANH ($i/6)',
            durationSeconds: 90,
            phaseType: ProgramPhaseType.sprint,
            targetPaceMinSecKm: 270, // 4:30/km
            targetPaceMaxSecKm: 315, // 5:15/km
            targetPaceDisplay: '4:30 - 5:15 min/km',
            targetHrZone: 'Zone 4-5 (165-185 bpm)',
            tipEn: 'Drive knees up and pump arms forcefully!',
            tipVi: 'Đánh tay mạnh, nâng cao đùi và bứt phá tốc độ!',
          ),
          ProgramStep(
            id: 'speed_walk_$i',
            titleEn: 'RECOVERY WALK ($i/6)',
            titleVi: 'ĐI BỘ PHỤC HỒI ($i/6)',
            durationSeconds: 90,
            phaseType: ProgramPhaseType.walk,
            targetPaceMinSecKm: 540, // 9:00/km
            targetPaceMaxSecKm: 660, // 11:00/km
            targetPaceDisplay: '9:00 - 11:00 min/km',
            targetHrZone: 'Zone 1-2 (115-130 bpm)',
            tipEn: 'Shake out legs and inhale deeply through the nose.',
            tipVi: 'Rũ lỏng hai chân, hít sâu bằng mũi thở chậm bằng miệng.',
          ),
        ],
        const ProgramStep(
          id: 'speed_cooldown',
          titleEn: 'COOL DOWN JOG',
          titleVi: 'CHẠY CHẬM THẢ LỎNG',
          durationSeconds: 300,
          phaseType: ProgramPhaseType.cooldown,
          targetPaceMinSecKm: 480,
          targetPaceMaxSecKm: 600,
          targetPaceDisplay: '8:00 - 10:00 min/km',
          targetHrZone: 'Zone 1 (< 120 bpm)',
          tipEn: 'Gentle jog to flush out lactic acid.',
          tipVi: 'Chạy chậm đều để đào thải axit lactic.',
        ),
      ],
      imageAsset: 'assets/plan_speed_intervals.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTranslations.get('runner_programs', currentLang),
                      style: KineticTypography.headlineSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: programs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final prog = programs[index];
                  final isVi = currentLang == AppLanguage.vi;
                  final title = AppTranslations.get(prog.titleKey, currentLang);
                  final badge = isVi ? prog.badgeVi : prog.badgeEn;
                  final desc = isVi ? prog.descriptionVi : prog.descriptionEn;

                  return Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Image Banner (Unified across all programs)
                        SizedBox(
                          height: 124,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                prog.imageAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SceneBackdrop(tint: colors.secondary),
                                    Center(
                                      child: Icon(Icons.directions_run_rounded, color: colors.primary, size: 36),
                                    ),
                                  ],
                                ),
                              ),
                              // Smooth Gradient Overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.25),
                                      Colors.transparent,
                                      colors.surface1.withValues(alpha: 0.95),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                              // Top-Left: Level Badge Pill
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.background.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    badge,
                                    style: KineticTypography.unitLabel.copyWith(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              // Top-Right: Duration Badge Pill
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.background.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.borderSubtle),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 12, color: colors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(prog.totalDurationSeconds / 60).round()} ${isVi ? "phút" : "min"}',
                                        style: KineticTypography.unitLabel.copyWith(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                title,
                                style: KineticTypography.headlineMedium.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Description
                              Text(
                                desc,
                                style: KineticTypography.bodyMedium.copyWith(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Targets metrics preview — V4: flat, hairline top
                              Container(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 2),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: colors.borderSubtle),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _MetricTile(
                                        label: isVi ? 'KHOẢNG CÁCH' : 'DISTANCE',
                                        value: prog.targetDistance,
                                        icon: Icons.route_rounded,
                                      ),
                                    ),
                                    Container(width: 1, height: 26, color: colors.borderSubtle),
                                    Expanded(
                                      child: _MetricTile(
                                        label: isVi ? 'NHỊP TIM' : 'HR ZONE',
                                        value: prog.targetZone,
                                        icon: Icons.favorite_border_rounded,
                                      ),
                                    ),
                                    Container(width: 1, height: 26, color: colors.borderSubtle),
                                    Expanded(
                                      child: _MetricTile(
                                        label: isVi ? 'PACE' : 'PACE',
                                        value: prog.targetPace,
                                        icon: Icons.speed_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Interval Sequence Strip
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 6,
                                  child: Row(
                                    children: prog.steps.map((st) {
                                      return Expanded(
                                        flex: st.durationSeconds,
                                        child: Container(
                                          color: st.phaseColor,
                                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Action Buttons: Guide Details + Quick Start
                              Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: OutlinedButton(
                                      onPressed: () => showProgramGuide(context, prog),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colors.textPrimary,
                                        side: BorderSide(
                                          color: colors.borderSubtle,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.menu_book_rounded, size: 15, color: colors.textPrimary),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                isVi ? 'Hướng dẫn' : 'Guide',
                                                maxLines: 1,
                                                style: KineticTypography.bodySmall.copyWith(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 6,
                                    child: KineticButton(
                                      label: isVi ? 'Bắt đầu' : 'Start',
                                      icon: Icons.play_arrow_rounded,
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RecordScreen(
                                              activityType: 'running',
                                              requireGps: true,
                                              guidedProgram: prog,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: colors.primary),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: KineticTypography.unitLabel.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: KineticTypography.headlineSmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: colors.primary,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet showing Step-by-Step Coaching Instructions & Start CTA
class _ProgramGuideSheet extends ConsumerWidget {
  const _ProgramGuideSheet({required this.program});

  final StructuredRunningProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final title = AppTranslations.get(program.titleKey, currentLang);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KineticTokens.radiusHero),
        ),
        border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface2,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    Icons.directions_run_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KineticTypography.headlineSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        isVi ? 'LỘ TRÌNH HUẤN LUYỆN TỪNG BƯỚC' : 'STRUCTURED WORKOUT TIMELINE',
                        style: KineticTypography.unitLabel.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target Parameters Summary — V4: flat, hairline frame
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.borderSubtle),
                  bottom: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _GuideParam(
                      label: isVi ? 'PACE MỤC TIÊU' : 'TARGET PACE',
                      val: program.targetPace,
                    ),
                  ),
                  Container(width: 1, height: 26, color: colors.borderSubtle),
                  Expanded(
                    child: _GuideParam(
                      label: isVi ? 'GUỒNG CHÂN' : 'CADENCE',
                      val: program.cadence,
                    ),
                  ),
                  Container(width: 1, height: 26, color: colors.borderSubtle),
                  Expanded(
                    child: _GuideParam(
                      label: isVi ? 'THỜI LƯỢNG' : 'DURATION',
                      val: '${(program.totalDurationSeconds / 60).round()} mins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Interactive Roadmap Timeline Section (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'TIẾN TRÌNH CÁC HIỆP CHẠY' : 'INTERVAL BREAKDOWN',
                      style: KineticTypography.unitLabel.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProgramInteractiveTimeline(
                      program: program,
                      currentLang: currentLang,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // START PROGRAM NOW CTA
            KineticButton(
              label: AppTranslations.get('start_program', currentLang),
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecordScreen(
                      activityType: 'running',
                      requireGps: true,
                      guidedProgram: program,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideParam extends StatelessWidget {
  const _GuideParam({required this.label, required this.val});
  final String label;
  final String val;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: KineticTypography.unitLabel.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: KineticTypography.headlineSmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: colors.primary,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

