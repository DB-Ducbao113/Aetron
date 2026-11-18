import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_button.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';
import 'package:flutter/material.dart';

class KineticSummaryActionDock extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onShare;
  final VoidCallback onDone;
  final VoidCallback onViewDetails;

  const KineticSummaryActionDock({
    super.key,
    required this.currentLang,
    required this.onShare,
    required this.onDone,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Share Workout Button
        KineticButton(
          label: currentLang == AppLanguage.vi ? 'CHIA SẺ BUỔI TẬP' : 'SHARE WORKOUT',
          icon: Icons.ios_share_rounded,
          variant: KineticButtonVariant.secondary,
          onPressed: onShare,
        ),
        const SizedBox(height: KineticTokens.spaceSM),

        // Done / Complete Button
        KineticButton(
          label: currentLang == AppLanguage.vi ? 'HOÀN THÀNH' : 'DONE',
          icon: Icons.check_rounded,
          variant: KineticButtonVariant.primary,
          onPressed: onDone,
        ),
        const SizedBox(height: KineticTokens.spaceXS),

        // Deep Dive Details
        KineticButton(
          label: currentLang == AppLanguage.vi ? 'XEM CHI TIẾT KỸ THUẬT' : 'VIEW FULL TELEMETRY',
          icon: Icons.insights_rounded,
          variant: KineticButtonVariant.ghost,
          onPressed: onViewDetails,
        ),
      ],
    );
  }
}
