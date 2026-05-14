import 'package:flutter/animation.dart';

/// Animation timing constants and custom easing curves for the Arabic
/// Temporal Watch app.
///
/// Design philosophy:
///   * All durations are intentionally slow and deliberate — befitting a luxury
///     timepiece.  Nothing snaps; everything flows.
///   * Easing curves are derived from classical cubic Bézier control points
///     that evoke the weight and inertia of mechanical watch movements.
///   * Constants are grouped by the UI element they govern so it is easy to
///     tune the entire animation feel by editing a single file.
library;

// ── Ring rotation ─────────────────────────────────────────────────────────────

/// Duration for the continuous sweep of the outer period ring's active-arc
/// indicator as time advances.
///
/// This is applied as a slow, continuous animation driven by the real clock —
/// it is not a repeating timer loop.
const Duration kRingRotationDuration = Duration(seconds: 1);

/// Duration for the snap-jump animation when the period ring crosses a period
/// boundary (jumps forward by one period division).
///
/// Longer than a typical UI transition because the ring visually "clicks" into
/// place, like a mechanical escapement.
const Duration kRingBoundarySnapDuration = Duration(milliseconds: 800);

// ── Screen / route transitions ────────────────────────────────────────────────

/// Standard page transition duration — governs the fade + scale effect used
/// by [LuxuryPageRoute].
const Duration kTransitionDuration = Duration(milliseconds: 480);

/// Reverse / pop transition duration — shorter than entry for snappier back
/// navigation.
const Duration kTransitionReverseDuration = Duration(milliseconds: 240);

/// Duration for tab switches within the same screen (e.g. day ↔ night toggle).
const Duration kTabTransitionDuration = Duration(milliseconds: 300);

// ── Pulse (active period highlight) ──────────────────────────────────────────

/// Duration for one complete cycle of the active period glow pulse.
///
/// A 3-second pulse is slow enough to feel "breathe"-like rather than urgent.
const Duration kPulseAnimationDuration = Duration(milliseconds: 3000);

/// Duration for a single emphasis pulse — e.g. when a new period begins.
const Duration kEmphasisPulseDuration = Duration(milliseconds: 600);

// ── Glow / bloom effects ──────────────────────────────────────────────────────

/// Duration for the ambient glow fade-in when the app launches or the period
/// ring gains focus.
const Duration kGlowFadeInDuration = Duration(milliseconds: 800);

/// Duration for the glow fade-out (slightly faster than fade-in to feel
/// more natural).
const Duration kGlowFadeOutDuration = Duration(milliseconds: 500);

/// Duration for the full glow oscillation cycle on the sun / moon indicators.
const Duration kGlowOscillationDuration = Duration(milliseconds: 4000);

// ── Period / sky background transition ────────────────────────────────────────

/// Duration for the background gradient cross-fade when moving between two
/// consecutive Arabic temporal periods.
///
/// Long enough that the sky colour appears to shift naturally as the sun
/// moves, but short enough that it completes well before the next period.
const Duration kPeriodTransitionDuration = Duration(milliseconds: 2000);

/// Duration for the dramatic dawn/dusk sky transition — slower because the
/// colour change is more visually striking.
const Duration kDawnDuskTransitionDuration = Duration(milliseconds: 4000);

// ── Digital clock tick ────────────────────────────────────────────────────────

/// Duration for the subtle opacity fade when the displayed seconds digit
/// changes on the digital readout.
const Duration kDigitFadeDuration = Duration(milliseconds: 120);

/// Duration for the colon separator blink (half of 1-second period).
const Duration kColonBlinkDuration = Duration(milliseconds: 500);

// ── Indicator / dot bounce ────────────────────────────────────────────────────

/// Duration for a prayer-time dot indicator to spring into position when the
/// period ring is first drawn or the location changes.
const Duration kIndicatorSpringDuration = Duration(milliseconds: 600);

/// Delay stagger between consecutive prayer dot animations.
const Duration kIndicatorStaggerDelay = Duration(milliseconds: 80);

// ── Info panel slide ──────────────────────────────────────────────────────────

/// Duration for the period-detail bottom sheet to slide up from the bottom.
const Duration kPanelSlideUpDuration = Duration(milliseconds: 420);

/// Duration for the period-detail panel to dismiss (slide down).
const Duration kPanelSlideDownDuration = Duration(milliseconds: 280);

// ── Loading / skeleton shimmer ────────────────────────────────────────────────

/// Duration for one complete shimmer sweep across a loading skeleton widget.
const Duration kShimmerDuration = Duration(milliseconds: 1500);

// ── Custom easing curves ──────────────────────────────────────────────────────
//
// All cubic Bézier curves are expressed as Cubic(x1, y1, x2, y2) where
// (x1, y1) is the first control point and (x2, y2) the second, with the
// start point implicitly at (0, 0) and the end point at (1, 1).

/// Luxury ease-out — starts fast, settles gently.  Used for ring rotations
/// and indicator movements.  Evokes the deceleration of a rotating bezel.
///
/// Control points approximate: fast start, very gradual finish.
const Curve kLuxuryEaseOut = Cubic(0.16, 1.0, 0.3, 1.0);

/// Luxury ease-in — builds momentum slowly then accelerates.  Used for
/// elements leaving the screen (panel dismiss, old period fade-out).
const Curve kLuxuryEaseIn = Cubic(0.7, 0.0, 0.84, 0.0);

/// Luxury ease-in-out — smooth, symmetrical S-curve for transitions where
/// both start and end should feel weighted (e.g. sky background cross-fade).
const Curve kLuxuryEaseInOut = Cubic(0.45, 0.0, 0.55, 1.0);

/// Horological ease — mimics the Gaussian acceleration profile of a
/// high-quality Swiss lever escapement.  Fastest at the midpoint.
const Curve kHorologicalEase = Cubic(0.25, 0.46, 0.45, 0.94);

/// Mechanical spring — slight overshoot then settle; models the inertia of
/// a heavy bezel ring finding its resting position.
///
/// Comparable to [Curves.elasticOut] but far more subtle (no ringing).
const Curve kMechanicalSpring = Cubic(0.34, 1.56, 0.64, 1.0);

/// Celestial glide — very slow ease-in, very slow ease-out; appropriate
/// for the sun/moon indicator orbiting around the watch face.  The middle
/// 80 % of the motion is almost linear.
const Curve kCelestialGlide = Cubic(0.4, 0.0, 0.6, 1.0);

/// Golden fade — asymmetric: quick initial movement then long, languorous
/// settle.  Used for the gold glow pulsing effect.
const Curve kGoldenFade = Cubic(0.0, 0.0, 0.2, 1.0);

/// Dusk descent — starts very slowly (like the sky darkening imperceptibly),
/// then accelerates into darkness.  Mirrors the perceptual non-linearity of
/// light fading at sunset.
const Curve kDuskDescent = Cubic(0.0, 0.0, 0.6, 1.0);

/// Dawn rise — the inverse: begins rapidly (aurora bursting) then smoothly
/// brightens.  Used for the sky transition from Al-Fajr to Al-Shurooq.
const Curve kDawnRise = Cubic(0.4, 0.0, 1.0, 1.0);

// ── Animation value mappings ─────────────────────────────────────────────────

/// The minimum scale factor used in scale-up entrance animations.
const double kEntranceScaleStart = 0.92;

/// The minimum opacity used in fade-in entrance animations.
const double kEntranceOpacityStart = 0.0;

/// The maximum glow opacity for the active period ring pulse.
const double kGlowMaxOpacity = 0.85;

/// The minimum glow opacity at the nadir of the pulse cycle.
const double kGlowMinOpacity = 0.30;

/// The maximum scale for the centre-cap spring animation.
const double kCentreCapMaxScale = 1.08;

/// Scale of the shimmer gradient width relative to the shimmer target width.
const double kShimmerGradientWidthFactor = 2.0;

// ── Stagger helpers ───────────────────────────────────────────────────────────

/// Returns the staggered animation [begin] / [end] interval for item [index]
/// out of [total] items, fitting within [0, 1] with [overlap] controlling how
/// much adjacent animations overlap.
///
/// [overlap] of 0.0 means sequential (no overlap); 0.5 means each item starts
/// halfway through the previous item's animation.
///
/// ```dart
/// // 3 items, 50 % overlap:
/// staggerInterval(0, 3); // Interval(0.0,  0.667)
/// staggerInterval(1, 3); // Interval(0.333, 1.0 )  ← overlapping at 0.333
/// staggerInterval(2, 3); // Interval(0.667, 1.0 )
/// ```
({double begin, double end}) staggerInterval(
  int index,
  int total, {
  double overlap = 0.5,
}) {
  assert(total > 0, 'total must be > 0');
  assert(overlap >= 0.0 && overlap < 1.0, 'overlap must be in [0, 1)');

  if (total == 1) return (begin: 0.0, end: 1.0);

  // Width of each item's portion of [0,1] when there is no overlap.
  final slotWidth = 1.0 / total;
  // With overlap the effective start of each item is earlier.
  final effectiveStart = index * slotWidth * (1.0 - overlap);
  final effectiveEnd =
      (effectiveStart + slotWidth).clamp(0.0, 1.0);

  return (begin: effectiveStart, end: effectiveEnd);
}
