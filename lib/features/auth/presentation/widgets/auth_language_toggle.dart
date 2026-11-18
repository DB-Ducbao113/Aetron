import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthLanguageToggle extends ConsumerWidget {
  const AuthLanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kinetic;
    final current = ref.watch(appLanguageProvider);

    return Semantics(
      container: true,
      label: current == AppLanguage.vi
          ? 'Chọn ngôn ngữ. Hiện tại: Tiếng Việt'
          : 'Choose language. Current: English',
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(KineticTokens.radiusMD),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: 'VI',
              selected: current == AppLanguage.vi,
              onTap: () => _setLanguage(ref, AppLanguage.vi),
            ),
            _LanguageOption(
              label: 'EN',
              selected: current == AppLanguage.en,
              onTap: () => _setLanguage(ref, AppLanguage.en),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLanguage(WidgetRef ref, AppLanguage language) async {
    if (ref.read(appLanguageProvider) == language) return;
    HapticFeedback.selectionClick();
    await ref.read(appLanguageProvider.notifier).setLanguage(language);
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'VI' ? 'Tiếng Việt' : 'English',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: KineticTokens.motionTab,
            curve: Curves.easeOutCubic,
            width: 34,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: selected
                  ? Border.all(
                      color: colors.primary.withValues(
                        alpha: 0.55,
                      ),
                    )
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colors.primary
                    : colors.textMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
