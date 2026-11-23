import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/structured_running_program.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/record/record_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/program_interactive_timeline.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunningProgramsScreen extends ConsumerWidget {
  static void showProgramGuide(
    BuildContext context,
    StructuredRunningProgram program,
  ) {
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
      descriptionEn:
          'Ideal for beginners building endurance from zero to running 5km continuously without fatigue.',
      descriptionVi:
          'Giáo án chuẩn cho người mới bắt đầu luyện tập sức bền từ 0 đến chạy liên tục 5km không mệt mỏi.',
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
      descriptionEn:
          'Conversational pace recovery run to strengthen aerobic base and burn fat with low joint stress.',
      descriptionVi:
          'Bài chạy thả lỏng tốc độ nói chuyện giúp củng cố tim mạch Zone 2, đốt mỡ hiệu quả và giảm áp lực lên khớp.',
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
      descriptionEn:
          'Build stamina and sustain a faster 10K race pace with structured tempo runs and progressive volume.',
      descriptionVi:
          'Rèn luyện khả năng duy trì tốc độ cho cự ly 10km thông qua các bài Tempo run nâng dần khối lượng.',
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
      descriptionEn:
          'High-intensity interval training (HIIT) to boost VO2 Max, lactate threshold, and maximum stride turnover.',
      descriptionVi:
          'Luyện tập biến tốc cường độ cao (HIIT) giúp tăng chỉ số VO2 Max, ngưỡng lactate và sải chân tối đa.',
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
    ),
  ];

  String _shortLevelLabel(StructuredRunningProgram prog, bool isVi) {
    return switch (prog.id) {
      'couch_to_5k' => isVi ? 'Người mới' : 'Beginner',
      'easy_base_run' => isVi ? 'Phục hồi' : 'Recovery',
      'pace_builder_10k' => isVi ? 'Trung cấp' : 'Intermediate',
      'speed_intervals' => isVi ? 'Tốc độ' : 'Speedwork',
      _ => isVi ? 'Chạy bộ' : 'Running',
    };
  }

  String _shortDistanceLabel(StructuredRunningProgram prog) =>
      prog.targetDistance.replaceAll(' Total', '');

  String _shortPaceLabel(StructuredRunningProgram prog) =>
      prog.targetPace.replaceAll(' min/km', ' /km').replaceAll(' - ', '–');

  String _shortZoneLabel(StructuredRunningProgram prog) {
    return switch (prog.id) {
      'couch_to_5k' || 'easy_base_run' => 'Zone 2',
      'pace_builder_10k' => 'Zone 3',
      'speed_intervals' => 'Zone 4–5',
      _ => prog.targetZone,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 8),
              child: Row(
                children: [
                  KineticGlassIconButton(
                    size: 37,
                    visualSize: 37,
                    label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: BladeIcon(
                      BladeIconName.chevL,
                      color: colors.textSecondary,
                      size: 18,
                      strokeWidth: 1.7,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppTranslations.get('runner_programs', currentLang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KineticTypography.pageTitleCompact.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  6,
                  hPad,
                  MediaQuery.viewPaddingOf(context).bottom + 24,
                ),
                itemCount: programs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final prog = programs[index];
                  final title = AppTranslations.get(prog.titleKey, currentLang);
                  final level = _shortLevelLabel(prog, isVi);
                  final durationMin = (prog.totalDurationSeconds / 60).round();
                  final (
                    bannerIcon,
                    bannerTint,
                    bannerIconColor,
                  ) = switch (prog.id) {
                    'couch_to_5k' => (
                      Icons.directions_run_rounded,
                      colors.primary,
                      colors.primary,
                    ),
                    'easy_base_run' => (
                      Icons.favorite_rounded,
                      colors.secondary,
                      colors.isDark
                          ? colors.secondary
                          : const Color(0xFF0369A1),
                    ),
                    'pace_builder_10k' => (
                      Icons.speed_rounded,
                      colors.primary,
                      colors.primary,
                    ),
                    'speed_intervals' => (
                      Icons.bolt_rounded,
                      colors.tertiary,
                      colors.isDark ? colors.tertiary : const Color(0xFFB45309),
                    ),
                    _ => (
                      Icons.directions_run_rounded,
                      colors.primary,
                      colors.primary,
                    ),
                  };

                  final innerStatFill = colors.isDark
                      ? const Color(0x28314B6B)
                      : const Color(0x66FFFFFF);
                  final innerStatBorder = colors.isDark
                      ? const Color(0x38B6DCFF)
                      : Colors.white.withValues(alpha: 0.85);

                  return KineticCard(
                    useLiquidGlass: true,
                    borderRadius: 21,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clean Glassline Header Row (no heavy opaque banner)
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bannerTint.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: bannerTint.withValues(alpha: 0.30),
                                ),
                              ),
                              child: Icon(
                                bannerIcon,
                                color: bannerIconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$level · $durationMin ${isVi ? "phút" : "min"}'
                                        .toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KineticTypography.unitLabel.copyWith(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: bannerIconColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KineticTypography.headlineSmall
                                        .copyWith(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Concise Single-Line Metrics Strip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: innerStatFill,
                            borderRadius: BorderRadius.circular(
                              KineticTokens.radiusMD,
                            ),
                            border: Border.all(color: innerStatBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _CompactProgramStat(
                                  icon: Icons.route_rounded,
                                  value: _shortDistanceLabel(prog),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 14,
                                color: colors.borderSubtle,
                              ),
                              Expanded(
                                child: _CompactProgramStat(
                                  icon: Icons.speed_rounded,
                                  value: _shortPaceLabel(prog),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 14,
                                color: colors.borderSubtle,
                              ),
                              Expanded(
                                child: _CompactProgramStat(
                                  icon: Icons.favorite_border_rounded,
                                  value: _shortZoneLabel(prog),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),

                        // Slim Interval Sequence Strip
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 4,
                            child: Row(
                              children: prog.steps.map((st) {
                                return Expanded(
                                  flex: st.durationSeconds,
                                  child: Container(
                                    color: st.phaseColor,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 0.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons: Guide + Start
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: KineticButton(
                                label: isVi ? 'Hướng dẫn' : 'Guide',
                                icon: Icons.menu_book_rounded,
                                variant: KineticButtonVariant.secondary,
                                height: 40,
                                onPressed: () =>
                                    showProgramGuide(context, prog),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: KineticButton(
                                label: isVi ? 'Bắt đầu' : 'Start',
                                icon: Icons.play_arrow_rounded,
                                height: 40,
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

class _CompactProgramStat extends StatelessWidget {
  const _CompactProgramStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              value,
              maxLines: 1,
              style: KineticTypography.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                fontFeatures: KineticTypography.tabularFigures,
              ),
            ),
          ],
        ),
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

    return KineticGlassBottomSheet(
      floating: false,
      borderRadius: 28,
      maxHeightFactor: 0.88,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface2,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
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
                        isVi
                            ? 'LỘ TRÌNH HUẤN LUYỆN TỪNG BƯỚC'
                            : 'STRUCTURED WORKOUT TIMELINE',
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
                KineticGlassIconButton(
                  size: 37,
                  visualSize: 37,
                  label: isVi ? 'Đóng' : 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: BladeIcon(
                    BladeIconName.x,
                    color: colors.textSecondary,
                    size: 18,
                    strokeWidth: 1.7,
                  ),
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
                      val:
                          '${(program.totalDurationSeconds / 60).round()} mins',
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
