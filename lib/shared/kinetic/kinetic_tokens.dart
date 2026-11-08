import 'package:flutter/material.dart';

/// Kinetic Design Tokens — unified spacing, radius, and animation constants.
/// Used by all Kinetic widgets and themes for visual consistency.
class KineticTokens {
  const KineticTokens._();

  // ── Spacing Scale ─────────────────────────────────────────────────────────
  /// 4px — tight gaps, icon-to-label
  static const double spaceXXS = 4;

  /// 8px — compact padding, chip inner padding
  static const double spaceXS = 8;

  /// 12px — card padding, small section gaps
  static const double spaceSM = 12;

  /// 16px — page padding, default card padding
  static const double spaceMD = 16;

  /// 20px — section spacing (medium)
  static const double spaceLG = 20;

  /// 24px — large section spacing
  static const double spaceXL = 24;

  /// 32px — hero/major section spacing
  static const double spaceXXL = 32;

  /// 20px — standard page horizontal padding (used across all screens)
  static const double page = 20;

  // ── Border Radius ─────────────────────────────────────────────────────────
  /// 4px — tight chips, badges
  static const double radiusXS = 4;

  /// 8px — compact controls, inputs, small cards
  static const double radiusSM = 8;

  /// 12px — buttons, medium cards
  static const double radiusMD = 12;

  /// 16px — large cards, bottom sheets
  static const double radiusLG = 16;

  /// 20px — extra-large containers, dock navigation
  static const double radiusXL = 20;

  /// 28px — pill-shaped containers, dock
  static const double radiusXXL = 28;

  /// Full round — pills, avatars, FABs
  static const double radiusPill = 999;

  // ── Component Sizes ────────────────────────────────────────────────────────
  /// 44px — minimum touch target (Material accessibility)
  static const double minTouchTarget = 44;

  /// 48px — standard button height
  static const double buttonHeight = 48;

  /// 52px — primary screen CTA (Activity start tray, live record controls)
  static const double buttonHeightPrimary = 52;

  /// 56px — large button height
  static const double buttonHeightLarge = 56;

  /// 64px — hero CTA button height
  static const double buttonHeightHero = 64;

  // ── Animation ─────────────────────────────────────────────────────────────
  /// 150ms — micro-interactions (hover, press feedback)
  static const Duration animFast = Duration(milliseconds: 150);

  /// 200ms — standard transitions (tab switch, toggle)
  static const Duration animNormal = Duration(milliseconds: 200);

  /// 300ms — page transitions, complex animations
  static const Duration animSlow = Duration(milliseconds: 300);

  /// 500ms — elaborate animations (loaders, page enters)
  static const Duration animSlowest = Duration(milliseconds: 500);

  /// Standard easing curve for most transitions
  static const Curve animCurve = Curves.easeOutCubic;

  /// Spring-like curve for bouncy interactions
  static const Curve animCurveSpring = Curves.easeOutBack;

  // ── Motion System (Phase 2) ─────────────────────────────────────
  /// 120ms — button press feedback (spec: 100–140ms, easeOut)
  static const Duration motionPress = Duration(milliseconds: 120);

  /// 200ms — tab indicator (spec: 180–240ms, easeOutCubic)
  static const Duration motionTab = Duration(milliseconds: 200);

  /// 320ms — card entrance (spec: 280–380ms, easeOutCubic)
  static const Duration motionCardEntrance = Duration(milliseconds: 320);

  /// 450ms — number counter (spec: 400–550ms, easeOutCubic)
  static const Duration motionCounter = Duration(milliseconds: 450);

  /// 550ms — success feedback (spec: 450–650ms, easeOutBack)
  static const Duration motionSuccess = Duration(milliseconds: 550);

  /// easeInOutCubic for page transitions (250–320ms window)
  static const Curve motionPageCurve = Curves.easeInOutCubic;

  /// easeOutCubic for the number counter (400–550ms window)
  static const Curve motionCounterCurve = Curves.easeOutCubic;

  /// easeOutBack for success feedback (450–650ms window)
  static const Curve motionSuccessCurve = Curves.easeOutBack;

  /// easeOut for press feedback (100–140ms window)
  static const Curve motionPressCurve = Curves.easeOut;

  /// easeOutCubic for card entrances (280–380ms window)
  static const Curve motionEntranceCurve = Curves.easeOutCubic;

  /// Whether the OS-level Reduce Motion / disable-animations setting is on.
  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Collapses [duration] to zero when Reduce Motion is enabled,
  /// so motion-sensitive users get instant state changes.
  static Duration respectingReduceMotion(
    BuildContext context,
    Duration duration,
  ) =>
      reduceMotionOf(context) ? Duration.zero : duration;

  // ── V4 Additions (2026-11-08) ───────────────────────────────────────────
  /// 48px — hero band / major page rhythm spacing
  static const double spaceXXXL = 48;

  /// 24px — hero panels, feature cards, bottom sheets
  static const double radiusHero = 24;

  /// Soft elevation for raised panels floating over maps/scenes.
  static List<BoxShadow> shadowPanel(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.45),
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -10,
        ),
      ];
}
