import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const neonBlue = Color(0xFF00D1FF);
    const borderColor = Color(0xFF123A57);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return SizedBox(
      height: KineticTokens.buttonHeightPrimary,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
          backgroundColor: const Color(0xFF101C2C),
          padding: EdgeInsets.symmetric(horizontal: isIOS ? 14 : 16),
          side: BorderSide(
            color: isLoading
                ? borderColor.withValues(alpha: 0.65)
                : borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              isIOS ? KineticTokens.radiusPill : KineticTokens.radiusMD,
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(neonBlue),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isIOS ? 20 : 24,
                    height: isIOS ? 20 : 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/GoogleLogo.jpg',
                        width: isIOS ? 15 : 18,
                        height: isIOS ? 15 : 18,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(width: isIOS ? 7 : 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isIOS ? 13 : 14,
                        fontWeight: isIOS ? FontWeight.w600 : FontWeight.w900,
                        letterSpacing: isIOS ? 0 : 1.1,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
