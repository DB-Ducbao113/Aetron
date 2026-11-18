import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/formatters/workout_formatters.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareCardTheme {
  aetronBlue,
  cleanWhite,
  obsidian,
  arcticMist,
}

/// Renders a premium Social Share Card with 4 aesthetic themes,
/// dedicated social app targets (Facebook, Zalo, Messenger, Instagram),
/// Save to Gallery, Copy Caption, and Native OS Share.
class WorkoutShareCardSheet extends StatefulWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int calories;
  final int steps;
  final bool useMetricUnits;
  final AppLanguage currentLang;

  const WorkoutShareCardSheet({
    super.key,
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.steps,
    required this.useMetricUnits,
    required this.currentLang,
  });

  @override
  State<WorkoutShareCardSheet> createState() => _WorkoutShareCardSheetState();
}

class _WorkoutShareCardSheetState extends State<WorkoutShareCardSheet>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();
  bool _isProcessing = false;
  ShareCardTheme _selectedTheme = ShareCardTheme.aetronBlue;
  late AnimationController _enterCtrl;
  late Animation<double> _enterAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _enterAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  String _buildCaption() {
    final isVi = widget.currentLang == AppLanguage.vi;
    final distStr = WorkoutFormatters.formatDistance(widget.distanceKm,
        useMetric: widget.useMetricUnits, decimals: 2);
    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(widget.durationSeconds);
    final paceStr = WorkoutFormatters.formatPaceFromSpeedKmh(widget.avgSpeedKmh,
        useMetric: widget.useMetricUnits);

    if (isVi) {
      return '🏃 Vừa hoàn thành $distStr trong $durationStr (Pace: $paceStr) cùng Aetron! 🔥 ${widget.calories} kcal\n\n#Aetron #Fitness #ChayBo #Workout';
    } else {
      return '🏃 Just crushed $distStr in $durationStr (Avg Pace: $paceStr) with Aetron! 🔥 ${widget.calories} kcal\n\n#Aetron #Fitness #Running #Workout';
    }
  }

  Future<Uint8List?> _captureCardBytes() async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[ShareCard] Capture error: $e');
      return null;
    }
  }

  Future<void> _shareToApp({
    required String scheme,
    required String appName,
  }) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(scheme);
    final canOpen = await canLaunchUrl(uri);

    if (canOpen) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final bytes = await _captureCardBytes();
      if (bytes != null && mounted) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/aetron_workout_share.png');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: _buildCaption(),
        );
      }
    }
  }

  Future<void> _shareToNative() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final bytes = await _captureCardBytes();
      if (bytes == null || !mounted) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aetron_workout_share.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : const Rect.fromLTWH(0, 0, 100, 100);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildCaption(),
        sharePositionOrigin: origin,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToPhotos() async {
    HapticFeedback.selectionClick();
    setState(() => _isProcessing = true);
    final isVi = widget.currentLang == AppLanguage.vi;
    final colors = context.kinetic;

    try {
      final bytes = await _captureCardBytes();
      if (bytes == null || !mounted) return;

      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'aetron_workout.png',
            ),
          ],
          text: _buildCaption(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                ),
              ),
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Đã tải ảnh buổi tập thành công!'
                          : 'Workout card image ready to save!',
                      style: KineticTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }

      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        await PhotoManager.editor.saveImage(
          bytes,
          filename: 'aetron_workout_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.6),
                ),
              ),
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Đã lưu ảnh buổi tập vào Thư viện ảnh!'
                          : 'Workout card saved to Photos!',
                      style: KineticTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.surface2,
              content: Text(
                isVi
                    ? 'Vui lòng cấp quyền truy cập ảnh để lưu'
                    : 'Please allow photo access to save',
                style: KineticTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyCaption() async {
    HapticFeedback.lightImpact();
    final isVi = widget.currentLang == AppLanguage.vi;
    final colors = context.kinetic;
    await Clipboard.setData(ClipboardData(text: _buildCaption()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.surface2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
            ),
          ),
          content: Row(
            children: [
              Icon(Icons.copy_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVi
                      ? 'Đã sao chép nội dung buổi tập vào Clipboard!'
                      : 'Workout caption copied to clipboard!',
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final isVi = widget.currentLang == AppLanguage.vi;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: colors.borderSubtle.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'CHIA SẺ BUỔI TẬP' : 'SHARE WORKOUT',
                          style: KineticTypography.pageEyebrow.copyWith(
                            color: colors.primary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isVi ? 'Thẻ Vinh Danh Thành Tích' : 'Achievement Card',
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Theme Selector Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ThemePill(
                      label: 'Aetron Blue',
                      color: const Color(0xFF006EE6),
                      isSelected: _selectedTheme == ShareCardTheme.aetronBlue,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.aetronBlue),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: 'Clean White',
                      color: const Color(0xFFE2E8F0),
                      isSelected: _selectedTheme == ShareCardTheme.cleanWhite,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.cleanWhite),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: 'Obsidian',
                      color: const Color(0xFF38BDF8),
                      isSelected: _selectedTheme == ShareCardTheme.obsidian,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.obsidian),
                    ),
                    const SizedBox(width: 8),
                    _ThemePill(
                      label: 'Arctic Mist',
                      color: const Color(0xFF0284C7),
                      isSelected:
                          _selectedTheme == ShareCardTheme.arcticMist,
                      onTap: () => setState(
                          () => _selectedTheme = ShareCardTheme.arcticMist),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capturable Card View
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ScaleTransition(
                  scale: _enterAnim,
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: _ShareCardContent(
                      activityType: widget.activityType,
                      distanceKm: widget.distanceKm,
                      durationSeconds: widget.durationSeconds,
                      avgSpeedKmh: widget.avgSpeedKmh,
                      calories: widget.calories,
                      steps: widget.steps,
                      useMetricUnits: widget.useMetricUnits,
                      currentLang: widget.currentLang,
                      theme: _selectedTheme,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Social Targets (FB, Zalo, Messenger, Instagram)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'CHỌN MẠNG XÃ HỘI' : 'SHARE TO SOCIALS',
                      style: KineticTypography.unitLabel.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Facebook
                        _SocialAppButton(
                          label: 'Facebook',
                          color: const Color(0xFF1877F2),
                          icon: Icons.facebook_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'fb://',
                            appName: 'Facebook',
                          ),
                        ),
                        // Zalo
                        _SocialAppButton(
                          label: 'Zalo',
                          color: const Color(0xFF0068FF),
                          customText: 'Zalo',
                          onTap: () => _shareToApp(
                            scheme: 'zalo://',
                            appName: 'Zalo',
                          ),
                        ),
                        // Messenger
                        _SocialAppButton(
                          label: 'Messenger',
                          color: const Color(0xFF0084FF),
                          icon: Icons.chat_bubble_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'fb-messenger://',
                            appName: 'Messenger',
                          ),
                        ),
                        // Instagram
                        _SocialAppButton(
                          label: 'Instagram',
                          color: const Color(0xFFE1306C),
                          icon: Icons.camera_alt_rounded,
                          onTap: () => _shareToApp(
                            scheme: 'instagram://',
                            appName: 'Instagram',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Quick Utility Actions (Save, Copy, Native Share)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Save to Photos
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.save_alt_rounded,
                        label: isVi ? 'Lưu ảnh' : 'Save Image',
                        color: const Color(0xFF7DF9A8),
                        onTap: _saveToPhotos,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Copy Caption
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.copy_rounded,
                        label: isVi ? 'Sao chép' : 'Copy Text',
                        color: const Color(0xFFF8C15C),
                        onTap: _copyCaption,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Native Share Sheet
                    Expanded(
                      child: _ActionSquareButton(
                        icon: Icons.share_rounded,
                        label: isVi ? 'Khác...' : 'More...',
                        color: colors.primary,
                        onTap: _shareToNative,
                      ),
                    ),
                  ],
                ),
              ),

              if (_isProcessing) ...[
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KineticTokens.motionTab,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : colors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : colors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: KineticTypography.label.copyWith(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? color : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SocialAppButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? customText;
  final VoidCallback onTap;

  const _SocialAppButton({
    required this.label,
    required this.color,
    this.icon,
    this.customText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: customText != null
                  ? Text(
                      customText!,
                      style: KineticTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionSquareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.borderSubtle.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: KineticTypography.label.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The actual share card visual that gets captured.
class _ShareCardContent extends StatelessWidget {
  final String activityType;
  final double distanceKm;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int calories;
  final int steps;
  final bool useMetricUnits;
  final AppLanguage currentLang;
  final ShareCardTheme theme;

  const _ShareCardContent({
    required this.activityType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.calories,
    required this.steps,
    required this.useMetricUnits,
    required this.currentLang,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = currentLang == AppLanguage.vi;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final distStr = WorkoutFormatters.formatDistance(distanceKm,
        useMetric: useMetricUnits, decimals: 2);
    final paceStr = WorkoutFormatters.formatPaceFromSpeedKmh(avgSpeedKmh,
        useMetric: useMetricUnits);
    final durationStr =
        WorkoutFormatters.formatDurationFromSeconds(durationSeconds);
    final actLabel =
        WorkoutFormatters.formatActivityType(activityType, currentLang)
            .toUpperCase();
    final hasSteps = (activityType.toLowerCase() == 'running' ||
            activityType.toLowerCase() == 'walking') &&
        steps > 0;

    final isLightCard = theme == ShareCardTheme.cleanWhite ||
        theme == ShareCardTheme.arcticMist;
    final Color primaryInk =
        isLightCard ? const Color(0xFF0F172A) : Colors.white;
    final Color secondaryInk = isLightCard
        ? const Color(0xFF475569)
        : Colors.white.withValues(alpha: 0.78);
    final Color dividerInk = isLightCard
        ? const Color(0xFFE2E8F0)
        : Colors.white.withValues(alpha: 0.22);

    final (accentColor, borderColor, bgColors) = switch (theme) {
      ShareCardTheme.aetronBlue => (
          Colors.white,
          const Color(0xFF0058BD),
          const [Color(0xFF006EE6), Color(0xFF0055C4)],
        ),
      ShareCardTheme.cleanWhite => (
          const Color(0xFF006EE6),
          const Color(0xFFE2E8F0),
          const [Color(0xFFFFFFFF), Color(0xFFF7F7FA)],
        ),
      ShareCardTheme.obsidian => (
          const Color(0xFF38BDF8),
          const Color(0xFF27272A),
          const [Color(0xFF0B0B0E), Color(0xFF16161A)],
        ),
      ShareCardTheme.arcticMist => (
          const Color(0xFF006EE6),
          const Color(0xFFBFDBFE),
          const [Color(0xFFEAF3FF), Color(0xFFF7FAFF)],
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            // Clean minimal corner ring accent
            Positioned(
              top: -48,
              right: -48,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: isLightCard ? 0.12 : 0.14),
                    width: 24,
                  ),
                ),
              ),
            ),

            // Card Foreground Content
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Logo + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLightCard
                                  ? const Color(0xFFEAF3FF)
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AETRON',
                            style: KineticTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: primaryInk,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        dateStr,
                        style: KineticTypography.unitLabel.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Activity Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLightCard
                          ? const Color(0xFFEAF3FF)
                          : Colors.white.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(KineticTokens.radiusPill),
                    ),
                    child: Text(
                      actLabel,
                      style: KineticTypography.unitLabel.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Big Hero Distance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        distStr,
                        style: KineticTypography.metricMega.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: primaryInk,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          isVi ? 'KHOẢNG CÁCH' : 'DISTANCE',
                          style: KineticTypography.unitLabel.copyWith(
                            fontWeight: FontWeight.w700,
                            color: secondaryInk,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hairline Divider
                  Container(height: 0.8, color: dividerInk),
                  const SizedBox(height: 14),

                  // Stats Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.timer_rounded,
                          label: isVi ? 'THỜI GIAN' : 'DURATION',
                          value: durationStr,
                          valueColor: primaryInk,
                          labelColor: secondaryInk,
                          iconColor: accentColor,
                        ),
                      ),
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.speed_rounded,
                          label: isVi ? 'PACE TB' : 'AVG PACE',
                          value: paceStr,
                          valueColor: primaryInk,
                          labelColor: secondaryInk,
                          iconColor: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _ShareStat(
                          icon: Icons.local_fire_department_rounded,
                          label: isVi ? 'CALO ĐỐT' : 'CALORIES',
                          value: '$calories kcal',
                          valueColor: primaryInk,
                          labelColor: secondaryInk,
                          iconColor: accentColor,
                        ),
                      ),
                      if (hasSteps)
                        Expanded(
                          child: _ShareStat(
                            icon: Icons.directions_walk_rounded,
                            label: isVi ? 'SỐ BƯỚC' : 'STEPS',
                            value: '$steps',
                            valueColor: primaryInk,
                            labelColor: secondaryInk,
                            iconColor: accentColor,
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bottom Watermark
                  Center(
                    child: Text(
                      isVi
                          ? 'Ghi lại hành trình luyện tập — Aetron'
                          : 'Tracked with Aetron',
                      textAlign: TextAlign.center,
                      style: KineticTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: secondaryInk,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;
  final Color iconColor;

  const _ShareStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: KineticTypography.unitLabel.copyWith(
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: KineticTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  fontFeatures: KineticTypography.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
