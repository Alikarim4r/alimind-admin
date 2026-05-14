// transition_state.dart
//
// Domain value objects for the day↔night sky transition system.
//
// Design overview
// ───────────────
// The watch face animates the sky background, star field, and celestial body
// glows over a 45-minute window centred on each sunrise and sunset.  The
// animation is divided into discrete [TransitionPhase] values so the UI can
// trigger one-shot effects (e.g. star-field appearance) at exactly the right
// moment.
//
// [TransitionState] is an immutable snapshot produced by [TransitionEngine]
// on every timer tick.  It carries pre-computed colours and opacity scalars
// so the painter layer never needs to recalculate anything.
//
// Phase timeline (sunset example, 45-minute window each side)
// ──────────────────────────────────────────────────────────
//   t-45 min  │  sunsetBegin    — transition starts, blend = 0.0
//   t-22 min  │  sunsetMid      — halfway, blend = 0.5
//   t+00 min  │  (actual sunset)
//   t+22 min  │  sunsetComplete — blend approaching 1.0
//   t+45 min  │  fullNight      — transition finished, blend = 1.0
//
// Sunrise follows the reverse path: fullNight → sunriseBegin → … → fullDay2.

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ── TransitionPhase ───────────────────────────────────────────────────────────

/// Discrete phase labels for the sunrise / sunset transition timeline.
///
/// The eight transitional phases span 45 minutes either side of the solar
/// event.  [fullDay] and [fullNight] represent stable, fully-settled states.
enum TransitionPhase {
  /// Full daylight — sky is at peak blue, no stars, sun fully above horizon.
  fullDay,

  /// Sunset transition beginning — golden-hour light starts (≈ t−45 min).
  sunsetBegin,

  /// Sunset transition at midpoint — warm orange/red sky (≈ t−22 min).
  sunsetMid,

  /// Sunset transition near complete — civil twilight purple (≈ t+22 min).
  sunsetComplete,

  /// Full night — sky is deep navy, stars fully visible, moon lit.
  fullNight,

  /// Sunrise transition beginning — first pre-dawn blue (≈ t−45 min).
  sunriseBegin,

  /// Sunrise transition at midpoint — indigo sky lightening (≈ t−22 min).
  sunriseMid,

  /// Sunrise transition near complete — golden-pink horizon (≈ t+22 min).
  sunriseComplete,

  /// Back to full day — transition finished, sky returned to peak blue.
  ///
  /// Modelled as a separate value from [fullDay] so widgets can fire a
  /// one-shot "day restored" animation exactly once.
  fullDay2,
}

// ── TransitionState ───────────────────────────────────────────────────────────

/// Immutable snapshot of the sky-transition render state at a single instant.
///
/// Produced by [TransitionEngine.calculate] and consumed by the watch-face
/// background painter and the celestial-body overlay.
///
/// All colour and opacity fields are pre-computed by [TransitionEngine] so
/// the painter only needs to use them directly — no math in the render thread.
@immutable
class TransitionState extends Equatable {
  const TransitionState({
    required this.phase,
    required this.progress,
    required this.skyColorTop,
    required this.skyColorBottom,
    required this.starOpacity,
    required this.sunGlowOpacity,
    required this.moonGlowOpacity,
    required this.atmosphericScatter,
    required this.dayNightBlend,
    required this.solarAltitude,
  });

  // ── Phase & progress ──────────────────────────────────────────────────────

  /// The current named phase of the transition timeline.
  final TransitionPhase phase;

  /// How far through the current [phase] this moment is.
  ///
  /// Range: `[0.0, 1.0]`.  Always 0.0 for [TransitionPhase.fullDay] and
  /// [TransitionPhase.fullNight] (stable states with no active transition).
  final double progress;

  // ── Sky colours ───────────────────────────────────────────────────────────

  /// Colour for the top of the sky gradient background.
  ///
  /// Transitions from deep blue (day) → dark indigo (civil twilight)
  /// → near-black navy (night).
  final Color skyColorTop;

  /// Colour for the bottom of the sky gradient background.
  ///
  /// Transitions from the period's own primary colour toward the horizon glow
  /// and eventually to full night.
  final Color skyColorBottom;

  // ── Opacity scalars ───────────────────────────────────────────────────────

  /// Star-field opacity.
  ///
  /// `0.0` = no stars (full daylight).
  /// `1.0` = full star field (deep night).
  ///
  /// Stars begin to appear during civil twilight (solar altitude < −0.8°).
  final double starOpacity;

  /// Sun glow intensity.
  ///
  /// `0.0` = sun disc hidden.
  /// `1.0` = peak brightness (sun near zenith or at exact horizon).
  ///
  /// Peaks at sunrise and sunset; drops during the day as the sun rises.
  final double sunGlowOpacity;

  /// Moon glow intensity.
  ///
  /// `0.0` = no moon glow (full day).
  /// `1.0` = full moon glow (deep night, adjusted by moon phase externally).
  final double moonGlowOpacity;

  /// Atmospheric scatter / golden-hour effect.
  ///
  /// `0.0` = no golden-hour effect (sun well above horizon).
  /// `1.0` = peak golden-hour warm tint (sun 0°–10° above horizon).
  ///
  /// This scalar is applied as a warm-tint overlay to the entire watch face
  /// so that the ring and hands all pick up a warm cast during golden hour.
  final double atmosphericScatter;

  // ── Derived blend ─────────────────────────────────────────────────────────

  /// Global day↔night blend factor, mirroring [RingState.dayNightBlend].
  ///
  /// `0.0` = full day.  `1.0` = full night.
  ///
  /// Kept on [TransitionState] so the ring and sky painters can share the
  /// same scalar without each computing it independently.
  final double dayNightBlend;

  // ── Raw solar data ────────────────────────────────────────────────────────

  /// Solar altitude in degrees at the moment this snapshot was calculated.
  ///
  /// Positive = sun above the geometric horizon.
  /// Negative = sun below the horizon.
  ///
  /// Stored here for downstream widgets that need the raw value (e.g. to
  /// render the solar altitude arc indicator).
  final double solarAltitude;

  // ── Convenience getters ───────────────────────────────────────────────────

  /// True when an active transition is in progress (i.e. not fully day or night).
  bool get isTransitioning =>
      phase != TransitionPhase.fullDay &&
      phase != TransitionPhase.fullNight &&
      phase != TransitionPhase.fullDay2;

  /// True when the sun is above the geometric horizon (altitude > −0.833°,
  /// accounting for atmospheric refraction).
  bool get isSunVisible => solarAltitude > -0.833;

  /// True when the phase belongs to the sunset sequence.
  bool get isSunsetSequence =>
      phase == TransitionPhase.sunsetBegin ||
      phase == TransitionPhase.sunsetMid ||
      phase == TransitionPhase.sunsetComplete;

  /// True when the phase belongs to the sunrise sequence.
  bool get isSunriseSequence =>
      phase == TransitionPhase.sunriseBegin ||
      phase == TransitionPhase.sunriseMid ||
      phase == TransitionPhase.sunriseComplete;

  /// True when the dominant mode is night (blend > 0.5).
  bool get isNightDominant => dayNightBlend > 0.5;

  // ── Equatable ─────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        phase,
        progress,
        skyColorTop,
        skyColorBottom,
        starOpacity,
        sunGlowOpacity,
        moonGlowOpacity,
        atmosphericScatter,
        dayNightBlend,
        solarAltitude,
      ];

  // ── copyWith ──────────────────────────────────────────────────────────────

  TransitionState copyWith({
    TransitionPhase? phase,
    double? progress,
    Color? skyColorTop,
    Color? skyColorBottom,
    double? starOpacity,
    double? sunGlowOpacity,
    double? moonGlowOpacity,
    double? atmosphericScatter,
    double? dayNightBlend,
    double? solarAltitude,
  }) {
    return TransitionState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      skyColorTop: skyColorTop ?? this.skyColorTop,
      skyColorBottom: skyColorBottom ?? this.skyColorBottom,
      starOpacity: starOpacity ?? this.starOpacity,
      sunGlowOpacity: sunGlowOpacity ?? this.sunGlowOpacity,
      moonGlowOpacity: moonGlowOpacity ?? this.moonGlowOpacity,
      atmosphericScatter: atmosphericScatter ?? this.atmosphericScatter,
      dayNightBlend: dayNightBlend ?? this.dayNightBlend,
      solarAltitude: solarAltitude ?? this.solarAltitude,
    );
  }

  @override
  String toString() => 'TransitionState('
      'phase: ${phase.name}, '
      'progress: ${(progress * 100).toStringAsFixed(1)}%, '
      'altitude: ${solarAltitude.toStringAsFixed(2)}°, '
      'blend: ${dayNightBlend.toStringAsFixed(2)})';
}

// ── Predefined stable states ──────────────────────────────────────────────────

/// A [TransitionState] representing fully stable daylight with no transition.
///
/// Use as the initial/default value before the first engine calculation.
const TransitionState kFullDayState = TransitionState(
  phase: TransitionPhase.fullDay,
  progress: 0.0,
  skyColorTop: Color(0xFF87CEEB),   // skyMidday
  skyColorBottom: Color(0xFF5BAAD0), // skyMorning
  starOpacity: 0.0,
  sunGlowOpacity: 0.6,
  moonGlowOpacity: 0.0,
  atmosphericScatter: 0.0,
  dayNightBlend: 0.0,
  solarAltitude: 45.0,
);

/// A [TransitionState] representing fully stable night with no transition.
///
/// Use as the initial value when the app launches during night-time.
const TransitionState kFullNightState = TransitionState(
  phase: TransitionPhase.fullNight,
  progress: 0.0,
  skyColorTop: Color(0xFF02040F),   // backgroundDeep
  skyColorBottom: Color(0xFF05081A), // backgroundMid
  starOpacity: 1.0,
  sunGlowOpacity: 0.0,
  moonGlowOpacity: 0.8,
  atmosphericScatter: 0.0,
  dayNightBlend: 1.0,
  solarAltitude: -30.0,
);
