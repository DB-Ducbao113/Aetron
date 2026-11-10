import 'package:fitness_exercise_application/features/workout/presentation/screens/running_programs_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticExploreRoutes extends StatelessWidget {
  final bool isVi;
  
  const KineticExploreRoutes({
    super.key, 
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final routes = [
      {
        'title': 'Couch to 5K',
        'distance': isVi ? '8 tuần' : '8 weeks',
        'subtitle': isVi ? 'Cho người mới' : 'For beginners',
        'icon': BladeIconName.run,
        'image': 'assets/plan_couch_to_5k.jpg',
      },
      {
        'title': 'Easy Base Run',
        'distance': '45 min',
        'subtitle': isVi ? 'Xây dựng sức bền' : 'Build endurance',
        'icon': BladeIconName.clock,
        'image': 'assets/plan_easy_base_run.jpg',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.page,
        vertical: KineticTokens.spaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'GIÁO ÁN LUYỆN TẬP' : 'TRAINING PLANS',
                style: KineticTypography.sectionEyebrow.copyWith(
                  color: colors.textMuted,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RunningProgramsScreen(),
                    ),
                  );
                },
                child: Text(
                  isVi ? 'Xem tất cả' : 'View all',
                  style: KineticTypography.bodySmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticTokens.spaceXS),
          Row(
            children: routes.map((route) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: route == routes.first ? KineticTokens.spaceXXS : 0,
                    left: route == routes.last ? KineticTokens.spaceXXS : 0,
                  ),
                  child: KineticCard(
                    padding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RunningProgramsScreen(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Thumbnail with badge
                        SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SceneBackdrop(tint: colors.secondary),
                              Image.asset(
                                route['image'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    SceneBackdrop(tint: colors.secondary),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      colors.surface1.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: KineticTokens.spaceXS,
                                left: KineticTokens.spaceXS,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KineticTokens.spaceXS,
                                    vertical: KineticTokens.spaceXXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.background.withValues(
                                      alpha: 0.85,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      KineticTokens.radiusPill,
                                    ),
                                    border: Border.all(
                                      color: colors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    route['distance'] as String,
                                    style: KineticTypography.unitLabel.copyWith(
                                      color: colors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Title & Subtitle
                        Padding(
                          padding: const EdgeInsets.all(KineticTokens.spaceSM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route['title'] as String,
                                style: KineticTypography.label.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: KineticTokens.spaceXXS),
                              Row(
                                children: [
                                  BladeIcon(
                                    route['icon'] as BladeIconName,
                                    size: 11,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: KineticTokens.spaceXXS),
                                  Expanded(
                                    child: Text(
                                      route['subtitle'] as String,
                                      style:
                                          KineticTypography.bodySmall.copyWith(
                                        color: colors.textMuted,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
