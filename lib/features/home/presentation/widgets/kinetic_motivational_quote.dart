import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

class KineticMotivationalQuote extends StatelessWidget {
  final String? quote;
  final bool isVi;

  const KineticMotivationalQuote({
    super.key,
    this.quote,
    this.isVi = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final defaultQuote = isVi
        ? '"Không có cự ly nào quá dài khi từng bước chân đều hướng về phía trước."'
        : '"No distance is too far when every stride moves forward."';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KineticTokens.spaceXXL,
        vertical: KineticTokens.spaceMD,
      ),
      child: Text(
        quote ?? defaultQuote,
        textAlign: TextAlign.center,
        style: KineticTypography.bodySmall.copyWith(
          color: colors.textMuted.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      ),
    );
  }
}
