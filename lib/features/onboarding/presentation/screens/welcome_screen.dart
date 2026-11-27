import 'dart:math' as math;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/auth/presentation/screens/auth_wrapper.dart';
import 'package:fitness_exercise_application/shared/aetron/aetron_logo_paths.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_glass_icon_button.dart';
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

  Future<bool> _loadShouldShowWelcome() async {
    if (Supabase.instance.client.auth.currentSession != null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(kWelcomeSeenPrefKey) ?? false);
  }

  Future<void> _completeWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kWelcomeSeenPrefKey, true);
    } catch (error) {
      debugPrint('[WelcomeGate] Could not persist welcome state: $error');
    }
    if (!mounted) return;
    _openAuth();
  }

  void _openAuth() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return FutureBuilder<bool>(
      future: _shouldShowWelcome,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }
        if (snapshot.data!) {
          return WelcomeScreen(onNext: _completeWelcome);
        }
        return ResourceLoadingScreen(onComplete: _openAuth);
      },
    );
  }
}

class ResourceLoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ResourceLoadingScreen({super.key, required this.onComplete});

  @override
  State<ResourceLoadingScreen> createState() => _ResourceLoadingScreenState();
}

class _ResourceLoadingScreenState extends State<ResourceLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(child: CircularProgressIndicator(color: colors.primary)),
    );
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
      body: KineticGlasslineScaffoldBody(
        showBottomScrim: false,
        child: SafeArea(
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
                            ? (isVi ? 'Bắt đầu ngay' : 'Get started')
                            : (isVi ? 'Tiếp tục' : 'Next'),
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
      ),
    );
  }

  List<_OnboardingPageData> _getPages(bool isVi) {
    if (isVi) {
      return const [
        _OnboardingPageData(
          step: '01 / 04',
          eyebrow: 'Aetron Fitness',
          titlePrefix: 'Nâng tầm\nhiệu suất ',
          titleAccent: 'mỗi ngày',
          titleSuffix: '',
          description:
              'Theo dõi từng buổi chạy bộ, đạp xe và đi bộ với giao diện trực quan, nhịp độ rõ ràng và dữ liệu chính xác.',
          primaryPill: 'GPS trực tiếp',
          secondaryPill: 'Sẵn sàng',
          primaryIcon: Icons.sensors_rounded,
          secondaryIcon: Icons.bolt_rounded,
          heroType: _OnboardingHeroType.runner,
        ),
        _OnboardingPageData(
          step: '02 / 04',
          eyebrow: 'Bản đồ & GPS',
          titlePrefix: 'Theo dõi lộ trình\nchính xác ',
          titleAccent: 'thời gian thực',
          titleSuffix: '',
          description:
              'Ghi lại trọn vẹn hành trình ngoài trời với bản đồ đường chạy, pace từng km, quãng đường và calo tiêu hao.',
          primaryPill: 'Lộ trình trực tiếp',
          secondaryPill: 'GPS chính xác',
          primaryIcon: Icons.route_rounded,
          secondaryIcon: Icons.speed_rounded,
          heroType: _OnboardingHeroType.tracking,
        ),
        _OnboardingPageData(
          step: '03 / 04',
          eyebrow: 'Phân tích tiến độ',
          titlePrefix: 'Biểu đồ\n',
          titleAccent: 'chuyên sâu',
          titleSuffix: ' & rõ ràng',
          description:
              'Tổng hợp khối lượng vận động theo tuần, tháng, năm cùng kỷ lục cá nhân giúp bạn kiểm soát mục tiêu dễ dàng.',
          primaryPill: 'Xu hướng tuần',
          secondaryPill: 'Kỷ lục cá nhân',
          primaryIcon: Icons.query_stats_rounded,
          secondaryIcon: Icons.trending_up_rounded,
          heroType: _OnboardingHeroType.analysis,
        ),
        _OnboardingPageData(
          step: '04 / 04',
          eyebrow: 'Mục tiêu & chuỗi ngày',
          titlePrefix: 'Chinh phục mục tiêu\n& ',
          titleAccent: 'huy hiệu',
          titleSuffix: ' mỗi tuần',
          description:
              'Duy trì thói quen luyện tập đều đặn, hoàn thành mục tiêu tuần và mở khóa các cột mốc thành tích mới.',
          primaryPill: 'Chuỗi tập luyện',
          secondaryPill: 'Thành tích cá nhân',
          primaryIcon: Icons.local_fire_department_rounded,
          secondaryIcon: Icons.emoji_events_rounded,
          heroType: _OnboardingHeroType.achievements,
        ),
      ];
    }

    return const [
      _OnboardingPageData(
        step: '01 / 04',
        eyebrow: 'Aetron Fitness',
        titlePrefix: 'Train smarter\nevery ',
        titleAccent: 'mile',
        titleSuffix: '',
        description:
            'Track your runs, rides, and walks with crisp live metrics, intuitive pacing splits, and clean progress views.',
        primaryPill: 'Live tracking',
        secondaryPill: 'Ready to move',
        primaryIcon: Icons.sensors_rounded,
        secondaryIcon: Icons.bolt_rounded,
        heroType: _OnboardingHeroType.runner,
      ),
      _OnboardingPageData(
        step: '02 / 04',
        eyebrow: 'GPS Route Mapping',
        titlePrefix: 'Track every route\nwith ',
        titleAccent: 'precision',
        titleSuffix: '',
        description:
            'Record outdoor runs and rides with live mapping, real-time pace splits, distance, and calories burned.',
        primaryPill: 'Live route trace',
        secondaryPill: 'Accurate GPS',
        primaryIcon: Icons.route_rounded,
        secondaryIcon: Icons.speed_rounded,
        heroType: _OnboardingHeroType.tracking,
      ),
      _OnboardingPageData(
        step: '03 / 04',
        eyebrow: 'Weekly Analytics',
        titlePrefix: 'Clear insights\nfor ',
        titleAccent: 'progress',
        titleSuffix: '',
        description:
            'Turn every workout into weekly distance trends, personal best records, and consistent training insights.',
        primaryPill: 'Weekly trends',
        secondaryPill: 'Personal bests',
        primaryIcon: Icons.query_stats_rounded,
        secondaryIcon: Icons.trending_up_rounded,
        heroType: _OnboardingHeroType.analysis,
      ),
      _OnboardingPageData(
        step: '04 / 04',
        eyebrow: 'Goals & Streaks',
        titlePrefix: 'Stay consistent\nbuild ',
        titleAccent: 'momentum',
        titleSuffix: '',
        description:
            'Build lasting habits with daily workout streaks, weekly distance targets, and milestone badges.',
        primaryPill: 'Daily streaks',
        secondaryPill: 'Milestone badges',
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
          _OnboardingHero(data: data, height: heroHeight, animation: animation),

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
            // Left Back Button (pages 2+)
            if (canGoBack) ...[
              KineticGlassIconButton(
                size: 37,
                visualSize: 37,
                label: currentLang == AppLanguage.vi ? 'Quay lại' : 'Back',
                onPressed: onBack,
                icon: BladeIcon(
                  BladeIconName.chevL,
                  color: colors.textSecondary,
                  size: 18,
                  strokeWidth: 1.7,
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Unified Brand Lockup (startup vector mark + aerodynamic wordmark)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AetronBrandLockup(
                    key: const ValueKey('welcome-brand-lockup'),
                    markSize: canGoBack ? 24 : 30,
                    wordmarkHeight: canGoBack ? 15 : 19,
                    spacing: canGoBack ? 6 : 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

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
              child: KineticTouchFinish(
                radius: KineticTokens.radiusPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    borderRadius: BorderRadius.circular(
                      KineticTokens.radiusPill,
                    ),
                    border: Border.all(color: colors.borderAccent),
                  ),
                  child: Text(
                    currentLang == AppLanguage.vi ? 'VI' : 'EN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
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
                currentLang == AppLanguage.vi ? 'Bỏ qua' : 'Skip',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
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
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return CustomPaint(
                painter: _FeatureHeroPainter(
                  progress: animation.value,
                  heroType: data.heroType,
                  icon: data.heroType == _OnboardingHeroType.runner
                      ? Icons.directions_run_rounded
                      : data.primaryIcon,
                  primaryColor: colors.primary,
                  secondaryColor: colors.secondary,
                  tertiaryColor: colors.tertiary,
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

    return KineticCard(
      useLiquidGlass: true,
      borderRadius: 21,
      padding: const EdgeInsets.all(KineticTokens.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Counter & Category Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
        _drawStrideArc(canvas, center, radius, progress);
    }

    _drawIcon(canvas, center, icon, radius);
  }

  void _drawStrideArc(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = secondaryColor.withValues(alpha: 0.48);

    final pulseShift = math.sin(progress * math.pi * 2) * 0.14;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      -math.pi * 0.78 + pulseShift,
      math.pi * 0.56,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      math.pi * 0.22 + pulseShift,
      math.pi * 0.56,
      false,
      arcPaint..color = primaryColor.withValues(alpha: 0.45),
    );

    final dotPaint = Paint()..color = primaryColor.withValues(alpha: 0.72);
    for (final offsetAngle in [-math.pi * 0.5, math.pi * 0.5]) {
      final angle = offsetAngle + progress * math.pi * 2;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius * 1.28,
          center.dy + math.sin(angle) * radius * 1.28,
        ),
        3.5,
        dotPaint,
      );
    }
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
