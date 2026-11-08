import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KineticLiveControlDock extends StatelessWidget {
  final bool isPaused;
  final bool isLocked;
  final bool isSaving;
  final bool canToggle;
  final bool isVi;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback onToggleLock;
  final bool isLargeMetricsMode;
  final VoidCallback? onToggleMetricsMode;

  const KineticLiveControlDock({
    super.key,
    required this.isPaused,
    required this.isLocked,
    required this.isSaving,
    required this.canToggle,
    required this.isVi,
    required this.onPauseResume,
    required this.onStop,
    required this.onToggleLock,
    this.isLargeMetricsMode = false,
    this.onToggleMetricsMode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      decoration: BoxDecoration(
        gradient: KineticGradients.hudSurface(colors),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KineticTokens.radiusHero),
        ),
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle.withValues(alpha: 0.75),
            width: 1.2,
          ),
        ),
        boxShadow: KineticTokens.shadowPanel(Colors.black),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              // 1. Sweat-proof Screen Lock Button
              Semantics(
                label: isVi
                    ? (isLocked ? 'Mở khóa màn hình' : 'Khóa màn hình')
                    : (isLocked ? 'Unlock screen' : 'Lock screen'),
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      onToggleLock();
                    },
                    borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                    child: Container(
                      width: 48,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isLocked
                            ? colors.primary.withValues(alpha: 0.2)
                            : colors.surface2,
                        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
                        border: Border.all(
                          color: isLocked ? colors.primary : colors.borderSubtle,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 22,
                        color: isLocked ? colors.primary : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Main High-Tactile HERO Pause / Resume Button
              Expanded(
                flex: isPaused ? 1 : 3,
                child: SizedBox(
                  height: 52,
                  child: Semantics(
                    label: isPaused
                        ? (isVi ? 'Tiếp tục bài tập' : 'Resume workout')
                        : (isVi ? 'Tạm dừng bài tập' : 'Pause workout'),
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: canToggle && !isSaving
                          ? () {
                              HapticFeedback.mediumImpact();
                              onPauseResume();
                            }
                          : null,
                      icon: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 26,
                      ),
                      label: Text(
                        isPaused
                            ? (isVi ? 'TIẾP TỤC' : 'RESUME')
                            : (isVi ? 'TẠM DỪNG' : 'PAUSE'),
                        style: KineticTypography.unitLabel.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusPill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 3. Redesigned Premium Finish / Stop Workout Button
              Expanded(
                flex: isPaused ? 1 : 2,
                child: SizedBox(
                  height: 52,
                  child: Semantics(
                    label: isVi ? 'Kết thúc bài tập' : 'Finish workout',
                    button: true,
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isSaving
                            ? null
                            : () {
                                HapticFeedback.heavyImpact();
                                onStop();
                              },
                        borderRadius: BorderRadius.circular(
                          KineticTokens.radiusPill,
                        ),
                        child: AnimatedContainer(
                          duration: KineticTokens.motionTab,
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(
                              KineticTokens.radiusPill,
                            ),
                            border: Border.all(
                              color: colors.tertiary,
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSaving)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.tertiary,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.stop_rounded,
                                  size: 24,
                                  color: colors.tertiary,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                isSaving
                                    ? (isVi ? 'ĐANG LƯU' : 'SAVING')
                                    : (isPaused
                                        ? (isVi ? 'KẾT THÚC' : 'FINISH')
                                        : (isVi ? 'DỪNG' : 'STOP')),
                                style: KineticTypography.unitLabel.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.tertiary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
