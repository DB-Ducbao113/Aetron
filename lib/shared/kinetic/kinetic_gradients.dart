import 'package:fitness_exercise_application/shared/kinetic/kinetic_colors.dart';
import 'package:flutter/material.dart';

/// Kinetic Gradients — V4 (2026-11-08).
///
/// Gradients live in BACKGROUNDS only (hero zones, duotone scenes, scrims,
/// map overlays). Foreground controls stay flat — see KineticButton.
/// Every gradient derives from [KineticColors] at call time: no hard hex.
class KineticGradients {
  const KineticGradients._();

  /// Hero background mesh — an [accentFill] wash lifting the top-right,
  /// melting into the page background. In dark it reads as a night-teal
  /// lift; in the light "Morning" identity the same math yields the pale
  /// dawn wash. Pair with [TopographicBackdrop] for the full treatment.
  static LinearGradient heroMesh(KineticColors c) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color.lerp(c.accentFill, c.background, 0.45)!,
          c.surface1,
          c.background,
        ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// Primary button gradient (board v3) — lit cyan: pale top, brand cyan
  /// mid, deeper base. Identical in both themes (the button is a brand
  /// object); pair with a bright 1.5px edge and a soft cyan shadow.
  static LinearGradient buttonPrimary(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(c.accentFill, Colors.white, 0.38)!,
          c.accentFill,
          Color.lerp(c.accentFill, Colors.black, 0.16)!,
        ],
        stops: const [0.0, 0.52, 1.0],
      );

  /// Duotone scene wash for sport/feature cards — tint [base] toward the
  /// background so imagery reads as one designed surface.
  static LinearGradient sceneWash(KineticColors c, Color base) =>
      LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          base.withValues(alpha: 0.55),
          c.background.withValues(alpha: 0.15),
        ],
        stops: const [0.0, 1.0],
      );

  /// Legibility scrim under text on a scene/photo (transparent → bg).
  static LinearGradient scrimBottom(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.background.withValues(alpha: 0.0),
          c.background.withValues(alpha: 0.92),
        ],
        stops: const [0.35, 1.0],
      );

  /// Top scrim for status-bar legibility over maps/imagery.
  static LinearGradient scrimTop(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.background.withValues(alpha: 0.85),
          c.background.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6],
      );

  /// HUD surface over the live map — near-opaque background, no blur cost.
  static LinearGradient hudSurface(KineticColors c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.background.withValues(alpha: 0.94),
          c.background.withValues(alpha: 0.88),
        ],
      );
}
