import 'package:flutter/material.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_surface_finish.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic_tokens.dart';

/// A single paint-only moving lens behind the existing equally-sized tabs.
/// The original row remains the sole layout and gesture owner.
class KineticSlidingSelection extends StatelessWidget {
  const KineticSlidingSelection({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.gap = 0,
  });
  final int index;
  final int count;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS || count < 1) {
      return child;
    }
    final colors = context.kinetic;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = (constraints.maxWidth - gap * (count - 1)) / count;
                if (slot <= 0) return const SizedBox.shrink();
                final offset = (slot + gap) * index.clamp(0, count - 1);
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: slot,
                      child: AnimatedSlide(
                        offset: Offset(offset / slot, 0),
                        duration: KineticTokens.respectingReduceMotion(
                          context,
                          const Duration(milliseconds: 260),
                        ),
                        curve: Curves.easeOutCubic,
                        child: KineticSurfaceFinish(
                          radius: KineticTokens.radiusPill,
                          emphasis: true,
                          child: DecoratedBox(
                            key: const ValueKey('kinetic-sliding-lens'),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: colors.isDark
                                    ? const [
                                        Color(0x3D9ACCFF),
                                        Color(0x243B72B1),
                                        Color(0x1C2E5BA1),
                                      ]
                                    : const [
                                        Color(0xADFFFFFF),
                                        Color(0x2EBDE1FF),
                                        Color(0x1C3C90E3),
                                      ],
                              ),
                              border: Border.all(
                                color: colors.isDark
                                    ? const Color(0x5EB6DDFF)
                                    : Colors.white.withValues(alpha: .75),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.isDark
                                      ? const Color(0x33000000)
                                      : const Color(0x241058AB),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(
                                KineticTokens.radiusPill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}
