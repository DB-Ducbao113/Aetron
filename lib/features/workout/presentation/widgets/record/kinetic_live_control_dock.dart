import 'package:fitness_exercise_application/shared/kinetic/blade_icons.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// V5 control section of the record screen's flat bottom panel.
/// The panel surface / top radius / top border are provided by
/// RecordScreen; this widget renders only the controls row.
///
/// Layout (V5 board grammar):
/// - Running: round lock button · one wide flat primary "Pause" ·
///   round finish (flag) button. All pre-existing actions stay reachable.
/// - Paused: round lock button · primary "Resume" · secondary "Finish"
///   side by side.
/// Every callback, haptic, semantics label and disabled condition is
/// identical to the previous dock — presentation only.
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            // 1. Sweat-proof Screen Lock Button (round icon button)
            _buildLockButton(colors),
            const SizedBox(width: 10),

            if (!isPaused) ...[
              // 2. One wide flat primary Pause button
              Expanded(child: _buildPauseButton(colors)),
              const SizedBox(width: 10),

              // 3. Finish as a round icon button while running
              _buildFinishIconButton(colors),
            ] else ...[
              // 2'. Primary Resume
              Expanded(flex: 3, child: _buildResumeButton(colors)),
              const SizedBox(width: 10),

              // 3'. Secondary Finish (labeled) while paused
              Expanded(flex: 2, child: _buildFinishButton(colors)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockButton(KineticColors colors) {
    return Semantics(
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
          customBorder: const CircleBorder(),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLocked
                  ? colors.primary.withValues(alpha: 0.2)
                  : colors.surface2,
              border: Border.all(
                color: isLocked ? colors.primary : colors.borderSubtle,
                width: 1.2,
              ),
            ),
            child: Center(
              child: BladeIcon(
                BladeIconName.lock,
                size: 22,
                color: isLocked ? colors.primary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton(KineticColors colors) {
    return SizedBox(
      height: 54,
      child: Semantics(
        label: isVi ? 'Tạm dừng bài tập' : 'Pause workout',
        button: true,
        child: ElevatedButton.icon(
          onPressed: canToggle && !isSaving
              ? () {
                  HapticFeedback.mediumImpact();
                  onPauseResume();
                }
              : null,
          icon: BladeIcon(
            BladeIconName.pause,
            size: 24,
            color: colors.onPrimary,
          ),
          label: Text(
            isVi ? 'TẠM DỪNG' : 'PAUSE',
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
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeButton(KineticColors colors) {
    return SizedBox(
      height: 54,
      child: Semantics(
        label: isVi ? 'Tiếp tục bài tập' : 'Resume workout',
        button: true,
        child: ElevatedButton.icon(
          onPressed: canToggle && !isSaving
              ? () {
                  HapticFeedback.mediumImpact();
                  onPauseResume();
                }
              : null,
          icon: BladeIcon(BladeIconName.play, size: 24, color: colors.onPrimary),
          label: Text(
            isVi ? 'TIẾP TỤC' : 'RESUME',
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
              borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishIconButton(KineticColors colors) {
    return Semantics(
      label: isVi ? 'Kết thúc bài tập' : 'Finish workout',
      button: true,
      excludeSemantics: true,
      child: Tooltip(
        message: isVi ? 'Kết thúc bài tập' : 'Finish workout',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSaving
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    onStop();
                  },
            customBorder: const CircleBorder(),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface2,
                border: Border.all(color: colors.tertiary, width: 1.4),
              ),
              child: Center(
                child: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.tertiary,
                          ),
                        ),
                      )
                    : BladeIcon(
                        BladeIconName.flag,
                        size: 22,
                        color: colors.tertiary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(KineticColors colors) {
    return SizedBox(
      height: 54,
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
            borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
            child: AnimatedContainer(
              duration: KineticTokens.motionTab,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(KineticTokens.radiusPill),
                border: Border.all(color: colors.borderStrong, width: 1.5),
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
                    BladeIcon(
                      BladeIconName.flag,
                      size: 20,
                      color: colors.tertiary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isSaving
                        ? (isVi ? 'ĐANG LƯU' : 'SAVING')
                        : (isVi ? 'KẾT THÚC' : 'FINISH'),
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
    );
  }
}
