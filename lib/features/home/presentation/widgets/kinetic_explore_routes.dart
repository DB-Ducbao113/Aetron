import 'package:fitness_exercise_application/features/shell/presentation/widgets/aetron_bottom_bar.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class KineticExploreRoutes extends StatelessWidget {
  final bool isVi;

  const KineticExploreRoutes({super.key, this.isVi = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final plans = [
      (
        id: 'couch_to_5k',
        title: '5K\nStarter',
        badge: isVi ? '4 TUẦN · NGƯỜI MỚI' : '4 WEEKS · BEGINNER',
        subtitle: isVi ? 'Khám phá giáo án ›' : 'Explore plan ›',
        lightGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA6D8ECFF), Color(0x7AB2DCFF), Color(0x665AACF7)],
        ),
        darkGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB8254B75), Color(0x911D446F), Color(0x9E3271BF)],
        ),
        lightBorder: const Color(0xE6FFFFFF),
        darkBorder: const Color(0x4D6CAAE6),
        icon: LucideIcons.flag,
        tint: colors.primary,
      ),
      (
        id: 'easy_base_run',
        title: isVi ? 'Chạy\nThả lỏng' : 'Easy\nBase Run',
        badge: isVi ? 'ZONE 2 · PHỤC HỒI' : 'ZONE 2 · RECOVERY',
        subtitle: isVi ? 'Khám phá giáo án ›' : 'Explore plan ›',
        lightGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA6D2F5EC), Color(0x7AB4EBDE), Color(0x662CB9A5)],
        ),
        darkGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB81E525D), Color(0x911A4853), Color(0x9E298A84)],
        ),
        lightBorder: const Color(0xE6FFFFFF),
        darkBorder: const Color(0x4768D4C6),
        icon: LucideIcons.heart,
        tint: colors.secondary,
      ),
      (
        id: 'pace_builder_10k',
        title: isVi ? 'Xây tốc độ\n10K' : '10K Pace\nBuilder',
        badge: isVi ? '6 TUẦN · TỐC ĐỘ' : '6 WEEKS · SPEED',
        subtitle: isVi ? 'Khám phá giáo án ›' : 'Explore plan ›',
        lightGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA6FFE7D6), Color(0x7AFBD3BD), Color(0x66F5A36C)],
        ),
        darkGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB83E2B22), Color(0x912E1F18), Color(0x9E613D2C)],
        ),
        lightBorder: const Color(0xE6FFFFFF),
        darkBorder: const Color(0x40E6A06C),
        icon: LucideIcons.route,
        tint: colors.primary,
      ),
      (
        id: 'speed_intervals',
        title: isVi ? 'Biến tốc\n5K' : '5K Speed\nIntervals',
        badge: isVi ? '4 TUẦN · INTERVAL' : '4 WEEKS · INTERVALS',
        subtitle: isVi ? 'Khám phá giáo án ›' : 'Explore plan ›',
        lightGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA6EDE4FC), Color(0x7AD8C6FF), Color(0x669E7CF0)],
        ),
        darkGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB8302446), Color(0x91231936), Color(0x9E4B3475)],
        ),
        lightBorder: const Color(0xE6FFFFFF),
        darkBorder: const Color(0x40B48CF0),
        icon: LucideIcons.zap,
        tint: colors.tertiary,
      ),
    ];

    final hPad = AetronBottomBar.horizontalPagePaddingOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Giáo án luyện tập' : 'Training plans',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.sectionTitleOf(colors),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RunningProgramsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVi ? 'Xem tất cả' : 'View all',
                          style: KineticTypography.linkActionOf(colors),
                        ),
                        const SizedBox(width: 2),
                        BladeIcon(
                          BladeIconName.chevR,
                          size: 15,
                          color: colors.isDark
                              ? const Color(0xFF9BC5FF)
                              : colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return SizedBox(
                width: 185,
                child: KineticCard(
                  useLiquidGlass: false,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  backgroundColor: Colors.transparent,
                  borderColor: colors.isDark
                      ? plan.darkBorder
                      : plan.lightBorder,
                  gradient: colors.isDark
                      ? plan.darkGradient
                      : plan.lightGradient,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RunningProgramsScreen(
                          initialProgramId: plan.id,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.caption.copyWith(
                          color: colors.isDark
                              ? const Color(0xFFAAC6E0)
                              : const Color(0xFF55708F),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          plan.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.isDark
                                ? const Color(0xFFF3F8FF)
                                : const Color(0xFF172436),
                            fontWeight: FontWeight.w800,
                            fontSize: 17.5,
                            height: 1.12,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        plan.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.caption.copyWith(
                          color: colors.isDark
                              ? const Color(0xFFAAC6E0)
                              : const Color(0xFF456385),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
