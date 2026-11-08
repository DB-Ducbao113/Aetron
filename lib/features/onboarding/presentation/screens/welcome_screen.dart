import 'dart:math' as math;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_globe_orbit_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kWelcomeSeenPrefKey = 'aetron_welcome_seen_v1';

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  late final Future<bool> _shouldShowWelcome = _loadShouldShowWelcome();
  bool _showResourceLoading = false;

  Future<bool> _loadShouldShowWelcome() async {
    if (Supabase.instance.client.auth.currentSession != null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(kWelcomeSeenPrefKey) ?? false);
  }

  Future<void> _completeWelcome() async {
    if (!mounted) return;
    setState(() => _showResourceLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kWelcomeSeenPrefKey, true);
    } catch (error) {
      debugPrint('[WelcomeGate] Could not persist welcome state: $error');
    }
  }

  void _openAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResourceLoading) {
      return ResourceLoadingScreen(onComplete: _openAuth);
    }

    return FutureBuilder<bool>(
      future: _shouldShowWelcome,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AetronGlobeOrbitScreen(
            customTitle: 'Aetron',
          );
        }
        return snapshot.data!
            ? WelcomeScreen(onNext: _completeWelcome)
            : ResourceLoadingScreen(onComplete: _openAuth);
      },
    );
  }
}

class ResourceLoadingScreen extends StatelessWidget {
  final VoidCallback onComplete;
  const ResourceLoadingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return AetronGlobeOrbitScreen(onComplete: onComplete);
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.onNext});

  final Future<void> Function() onNext;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_isCompleting) return;
    HapticFeedback.lightImpact();
    if (_currentPage == 3) {
      await _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _goPrevious() {
    if (_currentPage == 0 || _isCompleting) return;
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onNext();
    } catch (error) {
      debugPrint('[WelcomeScreen] Could not finish onboarding: $error');
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isVi = currentLang == AppLanguage.vi;
    final colors = context.kinetic;
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 720;
    final isLastPage = _currentPage == 3;

    final pages = _getPages(isVi);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Background Ambient Grid & Glow ──
          Positioned.fill(child: _WelcomeGrid(color: colors.primary)),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.secondary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ──
                _WelcomeTopBar(
                  canGoBack: _currentPage > 0,
                  onBack: _goPrevious,
                  onSkip: _completeOnboarding,
                  isProcessing: _isCompleting,
                ),

                // ── Main Page Slider ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemBuilder: (context, index) {
                      final data = pages[index];
                      return _OnboardingPageItem(
                        data: data,
                        animation: _controller,
                        isShort: isShort,
                      );
                    },
                  ),
                ),

                // ── Bottom Action Control Area ──
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, isShort ? 14 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Final-page stat strip (board v2/v3 capability stats)
                      if (isLastPage) ...[
                        const _WelcomeStatStrip(),
                        const SizedBox(height: 18),
                      ],

                      // Next / Get Started Action Button
                      _ModernActionButton(
                        label: isLastPage
                            ? (isVi ? 'BẮT ĐẦU NGAY' : 'GET STARTED')
                            : (isVi ? 'TIẾP TỤC' : 'NEXT'),
                        onPressed: _goNext,
                        isProcessing: _isCompleting,
                        isLastPage: isLastPage,
                      ),
                      const SizedBox(height: 18),

                      // Cyber Glowing Page Indicator Dots
                      _PageDots(count: pages.length, current: _currentPage),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_OnboardingPageData> _getPages(bool isVi) {
    if (isVi) {
      return const [
        _OnboardingPageData(
          step: '01 / 04',
          eyebrow: '⚡ KINETIC PERFORMANCE OS',
          titlePrefix: 'CHÀO MỪNG ĐẾN\nKỶ NGUYÊN ',
          titleAccent: 'THỂ THAO SỐ',
          titleSuffix: '',
          description:
              'Đột phá giới hạn bản thân với công nghệ theo dõi vận động thông minh, tối ưu hóa từng sải bước và chuẩn xác từng nhịp thở.',
          primaryPill: 'ĐỒNG BỘ: SẴN SÀNG',
          secondaryPill: 'HIỆU SUẤT: 100%',
          primaryIcon: Icons.sensors_rounded,
          secondaryIcon: Icons.bolt_rounded,
          heroType: _OnboardingHeroType.runner,
        ),
        _OnboardingPageData(
          step: '02 / 04',
          eyebrow: '🛰️ GPS SATELLITE TELEMETRY',
          titlePrefix: 'THEO DÕI LỘ TRÌNH\nCHÍNH XÁC ',
          titleAccent: 'REALTIME',
          titleSuffix: '',
          description:
              'Ghi lại toàn bộ hành trình chạy bộ, đạp xe ngoài trời với bản đồ vệ tinh trực tiếp, tốc độ từng km, khoảng cách và calo tiêu hao.',
          primaryPill: 'LỘ TRÌNH: TRỰC TIẾP',
          secondaryPill: 'TÍN HIỆU GPS: MẠNH',
          primaryIcon: Icons.route_rounded,
          secondaryIcon: Icons.speed_rounded,
          heroType: _OnboardingHeroType.tracking,
        ),
        _OnboardingPageData(
          step: '03 / 04',
          eyebrow: '📊 DEEP ANALYTICS CORE',
          titlePrefix: 'PHÂN TÍCH TIẾN ĐỘ\n',
          titleAccent: 'CHUYÊN SÂU',
          titleSuffix: ' & RÕ RÀNG',
          description:
              'Chuyển hóa mọi dữ liệu vận động thành biểu đồ xu hướng tuần, tỷ lệ tăng trưởng thể lực và kỷ lục cá nhân đáng tự hào.',
          primaryPill: 'XU HƯỚNG: ĐỒNG BỘ',
          secondaryPill: 'DỮ LIỆU: THỜI GIAN THỰC',
          primaryIcon: Icons.query_stats_rounded,
          secondaryIcon: Icons.trending_up_rounded,
          heroType: _OnboardingHeroType.analysis,
        ),
        _OnboardingPageData(
          step: '04 / 04',
          eyebrow: '🏆 MILESTONES & STREAKS',
          titlePrefix: 'CHINH PHỤC THỬ THÁCH\n& ',
          titleAccent: 'HUY HIỆU',
          titleSuffix: ' DANH GIÁ',
          description:
              'Duy trì chuỗi ngày tập luyện liên tục, mở khóa các thành tích danh giá và biến sự kiên trì thành lối sống đỉnh cao.',
          primaryPill: 'CHUỖI TẬP: SẴN SÀNG',
          secondaryPill: 'HUY HIỆU: ĐÃ MỞ',
          primaryIcon: Icons.local_fire_department_rounded,
          secondaryIcon: Icons.emoji_events_rounded,
          heroType: _OnboardingHeroType.achievements,
        ),
      ];
    }

    return const [
      _OnboardingPageData(
        step: '01 / 04',
        eyebrow: '⚡ KINETIC PERFORMANCE OS',
        titlePrefix: 'WELCOME TO THE\nFUTURE OF ',
        titleAccent: 'FITNESS',
        titleSuffix: '',
        description:
            'Precision tracking meets kinetic intelligence. Your journey to elite athletic performance starts right here.',
        primaryPill: 'BIO-SYNC: ACTIVE',
        secondaryPill: 'KINETIC: 100% READY',
        primaryIcon: Icons.sensors_rounded,
        secondaryIcon: Icons.bolt_rounded,
        heroType: _OnboardingHeroType.runner,
      ),
      _OnboardingPageData(
        step: '02 / 04',
        eyebrow: '🛰️ GPS SATELLITE TELEMETRY',
        titlePrefix: 'TRACK EVERY ROUTE\nWITH ',
        titleAccent: 'PRECISION',
        titleSuffix: '',
        description:
            'Record outdoor runs and rides with live satellite mapping, real-time pace splits, elevation, distance, and burned calories.',
        primaryPill: 'LIVE ROUTE TRACE',
        secondaryPill: 'GPS SIGNAL: STRONG',
        primaryIcon: Icons.route_rounded,
        secondaryIcon: Icons.speed_rounded,
        heroType: _OnboardingHeroType.tracking,
      ),
      _OnboardingPageData(
        step: '03 / 04',
        eyebrow: '📊 DEEP ANALYTICS CORE',
        titlePrefix: 'ADVANCED TELEMETRY\nFOR ',
        titleAccent: 'PROGRESS',
        titleSuffix: '',
        description:
            'Transform every workout into actionable weekly insights, personal records, consistency scores, and telemetry charts.',
        primaryPill: 'TREND ENGINE: ACTIVE',
        secondaryPill: 'METRICS: REAL-TIME',
        primaryIcon: Icons.query_stats_rounded,
        secondaryIcon: Icons.trending_up_rounded,
        heroType: _OnboardingHeroType.analysis,
      ),
      _OnboardingPageData(
        step: '04 / 04',
        eyebrow: '🏆 MILESTONES & STREAKS',
        titlePrefix: 'UNLOCK ACHIEVEMENTS\nAND ',
        titleAccent: 'STREAKS',
        titleSuffix: '',
        description:
            'Stay relentlessly motivated with daily workout streaks, milestone badges, personal records, and habit-forming goals.',
        primaryPill: 'STREAK SHIELD: ARMED',
        secondaryPill: 'BADGES: READY',
        primaryIcon: Icons.local_fire_department_rounded,
        secondaryIcon: Icons.emoji_events_rounded,
        heroType: _OnboardingHeroType.achievements,
      ),
    ];
  }
}

enum _OnboardingHeroType { runner, tracking, analysis, achievements }

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.step,
    required this.eyebrow,
    required this.titlePrefix,
    required this.titleAccent,
    required this.titleSuffix,
    required this.description,
    required this.primaryPill,
    required this.secondaryPill,
    required this.primaryIcon,
    required this.secondaryIcon,
    required this.heroType,
  });

  final String step;
  final String eyebrow;
  final String titlePrefix;
  final String titleAccent;
  final String titleSuffix;
  final String description;
  final String primaryPill;
  final String secondaryPill;
  final IconData primaryIcon;
  final IconData secondaryIcon;
  final _OnboardingHeroType heroType;
}

class _OnboardingPageItem extends StatelessWidget {
  const _OnboardingPageItem({
    required this.data,
    required this.animation,
    required this.isShort,
  });

  final _OnboardingPageData data;
  final Animation<double> animation;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroHeight = isShort ? size.height * 0.32 : size.height * 0.38;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Graphic Area ──
          _OnboardingHero(
            data: data,
            height: heroHeight,
            animation: animation,
          ),

          // ── Glassmorphic Cyber Content Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _WelcomeCopyCard(data: data),
          ),
          const SizedBox(height: 12),

          // ── Telemetry Pills ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TelemetryPills(data: data),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WelcomeTopBar extends ConsumerWidget {
  const _WelcomeTopBar({
    required this.canGoBack,
    required this.onBack,
    required this.onSkip,
    required this.isProcessing,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final bool isProcessing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final currentLang = ref.watch(appLanguageProvider);

    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Left Action / Back Button
            SizedBox(
              width: 44,
              height: 44,
              child: canGoBack
                  ? InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface1,
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusMD,
                          ),
                          border: Border.all(color: colors.borderAccent),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: colors.primary,
                          size: 16,
                        ),
                      ),
                    )
                  : Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),

            // Center Brand Badge
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [colors.primary, colors.secondary],
              ).createShader(bounds),
              child: const Text(
                'AETRON',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),

            // Language Switcher Capsule
            InkWell(
              onTap: () {
                final next = currentLang == AppLanguage.vi
                    ? AppLanguage.en
                    : AppLanguage.vi;
                ref.read(appLanguageProvider.notifier).setLanguage(next);
                HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                  border: Border.all(color: colors.borderAccent),
                ),
                child: Text(
                  currentLang == AppLanguage.vi ? '🇻🇳 VI' : '🇬🇧 EN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Skip Button
            TextButton(
              onPressed: isProcessing ? null : onSkip,
              style: TextButton.styleFrom(
                foregroundColor: colors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                currentLang == AppLanguage.vi ? 'BỎ QUA' : 'SKIP',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.data,
    required this.height,
    required this.animation,
  });

  final _OnboardingPageData data;
  final double height;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final tint = switch (data.heroType) {
      _OnboardingHeroType.runner => colors.secondary,
      _OnboardingHeroType.tracking => colors.primary,
      _OnboardingHeroType.analysis => colors.tertiary,
      _OnboardingHeroType.achievements => colors.primary,
    };

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // V4 scene backdrop (duotone wash + contours) tinted per page
          Positioned.fill(child: SceneBackdrop(tint: tint)),
          if (data.heroType == _OnboardingHeroType.runner)
            Image.asset(
              'assets/welcome_runner.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FeatureHeroPainter(
                    progress: animation.value,
                    heroType: data.heroType,
                    icon: data.primaryIcon,
                    primaryColor: colors.primary,
                    secondaryColor: colors.secondary,
                    tertiaryColor: colors.tertiary,
                  ),
                );
              },
            ),

          // Cyber Gradient Fades (Top and Bottom)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0.6),
                    Colors.transparent,
                    colors.background.withValues(alpha: 0.85),
                    colors.background,
                  ],
                  stops: const [0, 0.4, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // Cyber Laser Scanline Effect
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return CustomPaint(
                painter: _HeroScanPainter(
                  progress: animation.value,
                  color: colors.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WelcomeCopyCard extends StatelessWidget {
  const _WelcomeCopyCard({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(KineticTokens.radiusHero),
        border: Border.all(
          color: colors.borderAccent,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Counter & Category Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KineticTokens.radiusSM),
                  border: Border.all(color: colors.borderAccent),
                ),
                child: Text(
                  data.eyebrow,
                  style: KineticTypography.sectionEyebrow.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
              Text(
                data.step,
                style: KineticTypography.caption.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title with Neon Accent
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: KineticTypography.displayXL.copyWith(
                color: colors.textPrimary,
                fontSize: 26,
                height: 1.15,
              ),
              children: [
                TextSpan(text: data.titlePrefix),
                TextSpan(
                  text: data.titleAccent,
                  style: TextStyle(color: colors.primary),
                ),
                TextSpan(text: data.titleSuffix),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            data.description,
            style: KineticTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPills extends StatelessWidget {
  const _TelemetryPills({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TelemetryPill(
            icon: data.primaryIcon,
            label: data.primaryPill,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TelemetryPill(
            icon: data.secondaryIcon,
            label: data.secondaryPill,
          ),
        ),
      ],
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colors.primary, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KineticTypography.label.copyWith(
                color: colors.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernActionButton extends StatelessWidget {
  const _ModernActionButton({
    required this.label,
    required this.onPressed,
    required this.isProcessing,
    required this.isLastPage,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isProcessing;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    // V4: DS KineticButton — flat pill at buttonHeightLarge.
    return KineticButton(
      label: label,
      icon: isLastPage
          ? Icons.check_circle_rounded
          : Icons.arrow_forward_rounded,
      isLoading: isProcessing,
      height: KineticTokens.buttonHeightLarge,
      onPressed: isProcessing ? null : onPressed,
    );
  }
}

/// Divided mini stat strip shown above the CTA on the final onboarding
/// page (GPS accuracy / pace unit / route export — capability stats).
class _WelcomeStatStrip extends StatelessWidget {
  const _WelcomeStatStrip();

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    Widget item(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: KineticTypography.unitLabel.copyWith(
                color: colors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() {
      return Container(width: 1, height: 30, color: colors.borderSubtle);
    }

    return Row(
      children: [
        item('±8 m', 'GPS'),
        divider(),
        item('min/km', 'Live pace'),
        divider(),
        item('GPX', 'Routes'),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 32 : 8,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            color: selected ? colors.primary : colors.surface3,
          ),
        );
      }),
    );
  }
}

class _WelcomeGrid extends StatelessWidget {
  const _WelcomeGrid({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _WelcomeGridPainter(color: color)),
    );
  }
}

class _WelcomeGridPainter extends CustomPainter {
  const _WelcomeGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HeroScanPainter extends CustomPainter {
  const _HeroScanPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.72),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 12, size.width, 24))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final particlePaint = Paint()..color = color.withValues(alpha: 0.36);
    for (var i = 0; i < 16; i++) {
      final seed = i * 38.0;
      final x = (math.sin(progress * math.pi * 2 + i) * 0.5 + 0.5) * size.width;
      final py = (y + seed) % size.height;
      canvas.drawCircle(Offset(x, py), i.isEven ? 1.5 : 1, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroScanPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _FeatureHeroPainter extends CustomPainter {
  const _FeatureHeroPainter({
    required this.progress,
    required this.heroType,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  final double progress;
  final _OnboardingHeroType heroType;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = math.min(size.width, size.height) * 0.26;

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = primaryColor.withValues(alpha: 0.36);
    for (final scale in [0.72, 1.0, 1.28]) {
      canvas.drawCircle(center, radius * scale, ringPaint);
    }

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0),
          primaryColor,
          secondaryColor,
          primaryColor.withValues(alpha: 0),
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.16));
    canvas.drawCircle(center, radius * 1.16, sweepPaint);

    switch (heroType) {
      case _OnboardingHeroType.tracking:
        _drawRoute(canvas, center, radius, progress);
      case _OnboardingHeroType.analysis:
        _drawChart(canvas, center, radius, progress);
      case _OnboardingHeroType.achievements:
        _drawAchievement(canvas, center, radius, progress);
      case _OnboardingHeroType.runner:
        break;
    }

    _drawIcon(canvas, center, icon, radius);
  }

  void _drawRoute(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final path = Path()
      ..moveTo(center.dx - radius * 1.15, center.dy + radius * 0.45)
      ..cubicTo(
        center.dx - radius * 0.7,
        center.dy - radius * 0.8,
        center.dx + radius * 0.35,
        center.dy + radius * 0.85,
        center.dx + radius * 1.12,
        center.dy - radius * 0.35,
      );
    final routeGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = primaryColor.withValues(alpha: 0.32);
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = primaryColor;
    canvas.drawPath(path, routeGlow);
    canvas.drawPath(path, routePaint);

    final markerPaint = Paint()..color = primaryColor;
    for (final t in [0.0, 0.42, 0.78]) {
      final angle = (t + progress) * math.pi * 2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius * 0.55,
        ),
        4.5,
        markerPaint,
      );
    }
  }

  void _drawChart(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final baseY = center.dy + radius * 0.55;
    final barPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.76)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    for (var i = 0; i < 6; i++) {
      final x = center.dx - radius * 0.75 + i * radius * 0.3;
      final h =
          radius *
          (0.28 + 0.5 * ((math.sin(progress * math.pi * 2 + i) + 1) / 2));
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - h), barPaint);
    }

    final line = Path()..moveTo(center.dx - radius, center.dy + radius * 0.25);
    for (var i = 1; i <= 5; i++) {
      final x = center.dx - radius + i * radius * 0.4;
      final y =
          center.dy + math.sin(progress * math.pi * 2 + i) * radius * 0.25;
      line.lineTo(x, y);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = tertiaryColor,
    );
  }

  void _drawAchievement(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final medalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tertiaryColor;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius * 0.52 : radius * 0.24;
      final a = -math.pi / 2 + i * math.pi / 5 + progress * 0.25;
      final p = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      );
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, medalPaint);
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = primaryColor.withValues(alpha: 0.8),
    );
  }

  void _drawIcon(Canvas canvas, Offset center, IconData icon, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 0.44,
          color: primaryColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _FeatureHeroPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.heroType != heroType ||
        oldDelegate.icon != icon ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.tertiaryColor != tertiaryColor;
  }
}
