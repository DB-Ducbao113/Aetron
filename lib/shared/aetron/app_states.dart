import 'package:fitness_exercise_application/shared/aetron/aetron_ui.dart';
import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.isOffline = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final accent = isOffline ? AetronColors.warning : AetronColors.error;
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetronSpacing.lg),
        child: AppCard(
          borderColor: accent.withValues(alpha: 0.4),
          backgroundColor: AetronColors.panel.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(AetronSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AetronRadius.medium),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AetronTypography.headingMedium.copyWith(
                  color: AetronColors.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AetronTypography.bodySmall.copyWith(
                  color: AetronColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Thử lại',
                  onPressed: onRetry,
                  variant: AppButtonVariant.outlined,
                  icon: Icons.refresh_rounded,
                  height: 44,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
