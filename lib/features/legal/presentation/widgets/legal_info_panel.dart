import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

/// A restrained, document-appropriate information panel for Health & Fitness Disclaimers.
/// Styled with Kinetic surface tokens and subtle accent borders.
class LegalInfoPanel extends StatelessWidget {
  const LegalInfoPanel({
    super.key,
    this.title,
    this.message,
    this.lang = AppLanguage.en,
  });

  final String? title;
  final String? message;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final displayTitle = title ??
        (lang == AppLanguage.vi
            ? 'Cảnh báo Sức khỏe & Thể thao'
            : 'Fitness & Health Disclaimer');
    final displayMessage = message ??
        (lang == AppLanguage.vi
            ? 'Aetron được thiết kế để hỗ trợ theo dõi và phân tích các hoạt động thể thao cá nhân. Ứng dụng không phải là thiết bị y tế và không đưa ra lời khuyên, chẩn đoán hay phác đồ điều trị y khoa. Bạn nên tham khảo ý kiến bác sĩ trước khi bắt đầu hoặc thay đổi bất kỳ chương trình tập luyện cường độ cao nào.'
            : 'Aetron is designed to help you track and understand your fitness activities. It is not a medical device and does not provide medical advice, diagnosis, or treatment. Always consult a physician before starting any vigorous exercise program.');

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: colors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: KineticTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayMessage,
                  style: KineticTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
