import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class KineticExploreRoutes extends StatelessWidget {
  final bool isVi;

  const KineticExploreRoutes({
    super.key,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final plans = [
      (
        title: 'Couch to 5K',
        badge: isVi ? '8 tuần' : '8 weeks',
        subtitle: isVi ? 'Cho người mới bắt đầu' : 'For beginners',
        icon: LucideIcons.flag,
        tint: colors.primary,
      ),
      (
        title: isVi ? 'Chạy nền tảng Zone 2' : 'Easy Base Run',
        badge: isVi ? '45 phút' : '45 min',
        subtitle: isVi ? 'Xây dựng sức bền' : 'Build endurance',
        icon: LucideIcons.heart,
        tint: colors.secondary,
      ),
      (
        title: isVi ? 'Xây dựng tốc độ 10K' : '10K Pace Builder',
        badge: '10 km',
        subtitle: isVi ? 'Nâng ngưỡng tốc độ' : 'Threshold pacing',
        icon: LucideIcons.route,
        tint: colors.primary,
      ),
      (
        title: isVi ? 'Biến tốc 5K Interval' : '5K Speed Intervals',
        badge: isVi ? '30 phút' : '30 min',
        subtitle: isVi ? 'Tăng tốc độ tối đa' : 'Speed sessions',
        icon: LucideIcons.zap,
        tint: colors.tertiary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KineticTokens.page),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Giáo án luyện tập' : 'Training plans',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KineticTypography.sectionTitle.copyWith(
                    color: colors.textPrimary,
                  ),
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
                          style: KineticTypography.label.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevron_right,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KineticTokens.spaceXS),
        SizedBox(
          height: 146,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KineticTokens.page),
            itemCount: plans.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: KineticTokens.spaceSM),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return SizedBox(
                width: 212,
                child: KineticCard(
                  padding: EdgeInsets.zero,
                  borderRadius: KineticTokens.radiusLG,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RunningProgramsScreen(),
                      ),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(KineticTokens.radiusLG),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SceneBackdrop(tint: plan.tint),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.surface1.withValues(alpha: 0.0),
                                    colors.surface1.withValues(alpha: 0.90),
                                  ],
                                  stops: const [0.28, 1.0],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 14,
                              child: Icon(
                                plan.icon,
                                size: 42,
                                color: plan.tint.withValues(
                                  alpha: colors.isDark ? 0.28 : 0.20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface1.withValues(alpha: 0.92),
                            borderRadius:
                                BorderRadius.circular(KineticTokens.radiusPill),
                            border: Border.all(
                              color: colors.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            plan.badge,
                            style: KineticTypography.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              plan.title,
                              style: KineticTypography.headlineSmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.subtitle,
                              style: KineticTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
