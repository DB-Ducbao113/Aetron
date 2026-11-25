import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

enum AetronPermissionKind { location, camera, photos, motion }

Future<bool> showAetronPermissionSheet(
  BuildContext context, {
  required AetronPermissionKind kind,
  String? actionLabel,
  String? notNowLabel,
  bool isVietnamese = false,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => _AetronPermissionSheet(
          kind: kind,
          actionLabel: actionLabel ?? (isVietnamese ? 'Tiếp tục' : 'Continue'),
          notNowLabel: notNowLabel ?? (isVietnamese ? 'Để sau' : 'Not now'),
          isVietnamese: isVietnamese,
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onContinue: () => Navigator.of(sheetContext).pop(true),
        ),
      ) ??
      false;
}

class _AetronPermissionSheet extends StatelessWidget {
  const _AetronPermissionSheet({
    required this.kind,
    required this.actionLabel,
    required this.notNowLabel,
    required this.isVietnamese,
    required this.onCancel,
    required this.onContinue,
  });

  final AetronPermissionKind kind;
  final String actionLabel;
  final String notNowLabel;
  final bool isVietnamese;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    final content = switch (kind) {
      AetronPermissionKind.location => (
        Icons.location_on_rounded,
        isVietnamese ? 'BẬT ĐỊNH VỊ GPS' : 'ENABLE LOCATION',
        isVietnamese
            ? 'Định vị giúp ghi lại lộ trình, khoảng cách, tốc độ và tín hiệu GPS chính xác khi tập ngoài trời.'
            : 'Location keeps your route, distance, pace, and GPS signal accurate during outdoor workouts.',
        isVietnamese
            ? 'Chỉ sử dụng khi đang có buổi tập.'
            : 'Used only while a workout is active.',
      ),
      AetronPermissionKind.camera => (
        Icons.photo_camera_rounded,
        isVietnamese ? 'BẬT MÁY ẢNH' : 'ENABLE CAMERA',
        isVietnamese
            ? 'Quyền máy ảnh giúp bạn chụp ảnh đại diện trực tiếp trong Aetron.'
            : 'Camera access lets you take a profile photo directly in Aetron.',
        isVietnamese
            ? 'Chỉ sử dụng khi bạn chọn cập nhật ảnh đại diện.'
            : 'Used only when you choose to update your profile image.',
      ),
      AetronPermissionKind.photos => (
        Icons.photo_library_rounded,
        isVietnamese ? 'BẬT THƯ VIỆN ẢNH' : 'ENABLE PHOTO LIBRARY',
        isVietnamese
            ? 'Quyền thư viện ảnh giúp bạn chọn ảnh đại diện từ thiết bị.'
            : 'Photo access lets you choose a profile image from your library.',
        isVietnamese
            ? 'Chỉ sử dụng cho ảnh bạn đã chọn.'
            : 'Used only for the image you select.',
      ),
      AetronPermissionKind.motion => (
        Icons.directions_run_rounded,
        isVietnamese ? 'BẬT DỮ LIỆU CHUYỂN ĐỘNG' : 'ENABLE MOTION DATA',
        isVietnamese
            ? 'Quyền chuyển động hỗ trợ đếm bước chân khi không có GPS hoặc khi chạy trên máy.'
            : 'Motion access supports step tracking when GPS is unavailable or not needed.',
        isVietnamese
            ? 'Chỉ sử dụng trong suốt buổi tập.'
            : 'Used only during a workout session.',
      ),
    };

    return KineticGlassBottomSheet(
      floating: true,
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
              ),
              child: Icon(content.$1, color: colors.primary, size: 26),
            ),
            const SizedBox(height: 16),
          Text(
            content.$2,
            style: KineticTypography.cardEyebrowOf(colors),
          ),
          const SizedBox(height: 10),
          Text(
            content.$3,
            style: KineticTypography.headlineSmall.copyWith(
              color: colors.textPrimary,
              fontSize: 15.5,
              height: 1.38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.$4,
            style: KineticTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: KineticButton(
                  label: notNowLabel,
                  variant: KineticButtonVariant.secondary,
                  height: 48,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: KineticButton(
                  label: actionLabel,
                  icon: Icons.arrow_forward_rounded,
                  variant: KineticButtonVariant.primary,
                  height: 48,
                  onPressed: onContinue,
                ),
              ),
            ],
          ),
          ],
        ),
    );
  }
}
