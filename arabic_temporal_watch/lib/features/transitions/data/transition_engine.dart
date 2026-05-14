// transition_engine.dart
//
// Stateless engine that computes [TransitionState] from solar parameters.
//
// Solar altitude → colour mapping
// ────────────────────────────────
//   altitude > 15°          full day blue sky
//   altitude  5° – 15°      golden hour: warm amber tint builds
//   altitude -0.8° –  5°    sunset / sunrise: orange-red horizon
//   altitude -6° – -0.8°    civil twilight: purple-pink sky
//   altitude -12° – -6°     nautical twilight: dark blue
//   altitude < -12°         astronomical twilight / night: deep navy
//
// Transition window
// ─────────────────
// [transitionWindowMinutes] = 45 minutes either side of sunrise/sunset.
// Inside the window, [TransitionPhase] advances through three sub-phases:
//   - Begin:    window start → event time        (0 → 0.5 progress)
//   - Mid:      event time                       (progress = 0.5)
//   - Complete: event time → window end          (0.5 → 1.0 progress)
//
// The engine also handles the solar altitude gracefully for edge cases:
//   • Polar day  (sun never sets):  pinned at fullDay
//   • Polar night (sun never rises): pinned at fullNight

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../domain/transition_state.dart';

// ── TransitionEngine ──────────────────────────────────────────────────────────

/// Stateless calculator that converts solar and lunar parameters into a
/// complete [TransitionState] for the current moment.
///
/// Instantiate once and reuse — all methods are pure functions.
///
/// ```dart
/// const engine = TransitionEngine();
/// final state = engine.calculate(
///   now: DateTime.now(),
///   sunrise: todaySunrise,
///   sunset: todaySunset,
///   moonPhase: 0.75,
///   solarAltitude: currentAlt,
/// );
/// ```
class TransitionEngine {
  const TransitionEngine();

  // ── Public constants ───────────────────────────────────────────────────────

  /// Half-width of the transition window in minutes.
  ///
  /// The engine begins the transition animation 45 minutes before sunset /
  /// sunrise and finishes 45 minutes after.  Total window = 90 minutes.
  static const int transitionWindowMinutes = 45;

  // ── Private altitude thresholds (degrees) ─────────────────────────────────

  static const double _altFullDay = 15.0;
  static const double _altGoldenHourTop = 15.0;
  static const double _altGoldenHourBottom = 5.0;
  static const double _altSunsetOrangeTop = 5.0;
  static const double _altSunsetOrangeBottom = -0.833; // refraction-adjusted
  static const double _altCivilTop = -0.833;
  static const double _altCivilBottom = -6.0;
  static const double _altNauticalTop = -6.0;
  static const double _altNauticalBottom = -12.0;
  // Below -12° = full night.

  // ── calculate ─────────────────────────────────────────────────────────────

  /// Compute the complete [TransitionState] for [now].
  ///
  /// Parameters:
  ///   * [now]           — the current local [DateTime].
  ///   * [sunrise]       — today's sunrise [DateTime] (local).
  ///   * [sunset]        — today's sunset [DateTime] (local).
  ///   * [moonPhase]     — moon illumination fraction [0.0, 1.0].
  ///                       0 = new moon, 0.5 = half, 1.0 = full moon.
  ///   * [solarAltitude] — sun's altitude above/below horizon in degrees.
  TransitionState calculate({
    required DateTime now,
    required DateTime sunrise,
    required DateTime sunset,
    required double moonPhase,
    required double solarAltitude,
  }) {
    // ── Determine phase and raw progress ──────────────────────────────────────
    final (phase, rawProgress) = _resolvePhase(now, sunrise, sunset);

    // ── Day/night blend (0 = day, 1 = night) ─────────────────────────────────
    final blend = _dayNightBlend(phase, rawProgress);

    // ── Sky colours ───────────────────────────────────────────────────────────
    final topColor = skyColor(solarAltitude: solarAltitude, isTop: true);
    final bottomColor = skyColor(solarAltitude: solarAltitude, isTop: false);

    // ── Opacity scalars ───────────────────────────────────────────────────────
    final starOp = starOpacity(solarAltitude);
    final sunGlow = sunGlowIntensity(solarAltitude);
    final moonGlow = _moonGlowIntensity(solarAltitude, moonPhase);
    final scatter = _atmosphericScatter(solarAltitude);

    return TransitionState(
      phase: phase,
      progress: rawProgress,
      skyColorTop: topColor,
      skyColorBottom: bottomColor,
      starOpacity: starOp,
      sunGlowOpacity: sunGlow,
      moonGlowOpacity: moonGlow,
      atmosphericScatter: scatter,
      dayNightBlend: blend,
      solarAltitude: solarAltitude,
    );
  }

  // ── skyColor ───────────────────────────────────────────────────────────────

  /// Compute the sky gradient colour for either the top or bottom of the
  /// background gradient at a given [solarAltitude].
  ///
  /// [isTop] = true  → zenith / upper-sky colour.
  /// [isTop] = false → horizon / lower-sky colour.
  Color skyColor({
    required double solarAltitude,
    required bool isTop,
  }) {
    if (isTop) {
      return _skyTopColor(solarAltitude);
    } else {
      return _skyBottomColor(solarAltitude);
    }
  }

  // ── starOpacity ───────────────────────────────────────────────────────────

  /// Compute the star-field opacity for a given [solarAltitude].
  ///
  /// Stars are invisible in full daylight and become fully visible by the
  /// time civil twilight ends (altitude ≈ −6°).
  ///
  /// Returns a value in `[0.0, 1.0]`.
  double starOpacity(double solarAltitude) {
    // No stars above the civil twilight threshold.
    if (solarAltitude >= _altCivilTop) return 0.0;
    // Full stars below nautical twilight.
    if (solarAltitude <= _altNauticalBottom) return 1.0;

    // Linear interpolation across civil + nautical twilight bands.
    // altitude: _altCivilTop (−0.833°) → _altNauticalBottom (−12°)
    //   maps to 0.0 → 1.0
    return _inverseLerp(solarAltitude, _altCivilTop, _altNauticalBottom)
        .clamp(0.0, 1.0);
  }

  // ── sunGlowIntensity ──────────────────────────────────────────────────────

  /// Compute the sun glow intensity for a given [solarAltitude].
  ///
  /// The glow is strongest when the sun is near the horizon (sunrise/sunset)
  /// and fades both as the sun rises high into the sky and as it drops below
  /// the horizon into civil twilight.
  ///
  /// Returns a value in `[0.0, 1.0]`.
  double sunGlowIntensity(double solarAltitude) {
    // Below civil twilight — no sun visible.
    if (solarAltitude < _altCivilBottom) return 0.0;

    if (solarAltitude >= _altFullDay) {
      // High sun: minimal glow (just the disc halo).
      return 0.25;
    }

    if (solarAltitude >= _altGoldenHourBottom) {
      // Golden hour (5°–15°): builds to peak.
      final t = _inverseLerp(
          solarAltitude, _altGoldenHourBottom, _altGoldenHourTop);
      return _lerp(1.0, 0.25, t); // 1.0 at 5°, 0.25 at 15°
    }

    if (solarAltitude >= _altSunsetOrangeBottom) {
      // Sunset/sunrise band (−0.833°–5°): peak glow.
      return 1.0;
    }

    // Civil twilight (−6°–−0.833°): fading sun below horizon.
    return _inverseLerp(solarAltitude, _altCivilBottom, _altCivilTop)
        .clamp(0.0, 1.0);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Resolve [TransitionPhase] and progress fraction within that phase for
  /// the given [now] relative to [sunrise] and [sunset].
  (TransitionPhase, double) _resolvePhase(
    DateTime now,
    DateTime sunrise,
    DateTime sunset,
  ) {
    final window = Duration(minutes: transitionWindowMinutes);

    final sunriseWindowStart = sunrise.subtract(window);
    final sunriseWindowEnd = sunrise.add(window);
    final sunsetWindowStart = sunset.subtract(window);
    final sunsetWindowEnd = sunset.add(window);

    // ── Sunset window ──────────────────────────────────────────────────────
    if (!now.isBefore(sunsetWindowStart) && now.isBefore(sunsetWindowEnd)) {
      final totalMs =
          sunsetWindowEnd.difference(sunsetWindowStart).inMilliseconds;
      final elapsedMs = now.difference(sunsetWindowStart).inMilliseconds;
      final p = totalMs > 0 ? (elapsedMs / totalMs).clamp(0.0, 1.0) : 0.0;

      final TransitionPhase phase;
      if (p < 0.33) {
        phase = TransitionPhase.sunsetBegin;
      } else if (p < 0.67) {
        phase = TransitionPhase.sunsetMid;
      } else {
        phase = TransitionPhase.sunsetComplete;
      }
      return (phase, p);
    }

    // ── Sunrise window ─────────────────────────────────────────────────────
    if (!now.isBefore(sunriseWindowStart) && now.isBefore(sunriseWindowEnd)) {
      final totalMs =
          sunriseWindowEnd.difference(sunriseWindowStart).inMilliseconds;
      final elapsedMs = now.difference(sunriseWindowStart).inMilliseconds;
      final p = totalMs > 0 ? (elapsedMs / totalMs).clamp(0.0, 1.0) : 0.0;

      final TransitionPhase phase;
      if (p < 0.33) {
        phase = TransitionPhase.sunriseBegin;
      } else if (p < 0.67) {
        phase = TransitionPhase.sunriseMid;
      } else {
        phase = TransitionPhase.sunriseComplete;
      }
      return (phase, p);
    }

    // ── Stable states ──────────────────────────────────────────────────────
    // After sunrise window end but before sunset window start → full day.
    if (!now.isBefore(sunriseWindowEnd) && now.isBefore(sunsetWindowStart)) {
      return (TransitionPhase.fullDay, 0.0);
    }
    // After sunset window end → full night until next sunrise window.
    if (!now.isBefore(sunsetWindowEnd) && now.isBefore(sunriseWindowStart)) {
      return (TransitionPhase.fullNight, 0.0);
    }

    // Fallback for edge cases (polar day/night, invalid times, etc.).
    final isApparentlyDay = !now.isBefore(sunrise) && now.isBefore(sunset);
    return isApparentlyDay
        ? (TransitionPhase.fullDay, 0.0)
        : (TransitionPhase.fullNight, 0.0);
  }

  /// Map phase + progress to the global day↔night blend scalar.
  double _dayNightBlend(TransitionPhase phase, double progress) {
    switch (phase) {
      case TransitionPhase.fullDay:
      case TransitionPhase.fullDay2:
        return 0.0;
      case TransitionPhase.fullNight:
        return 1.0;
      case TransitionPhase.sunsetBegin:
      case TransitionPhase.sunsetMid:
      case TransitionPhase.sunsetComplete:
        // Day → Night: blend progresses 0 → 1.
        return _smoothStep(progress);
      case TransitionPhase.sunriseBegin:
      case TransitionPhase.sunriseMid:
      case TransitionPhase.sunriseComplete:
        // Night → Day: blend progresses 1 → 0.
        return 1.0 - _smoothStep(progress);
    }
  }

  /// Zenith / upper sky colour derived from solar altitude.
  Color _skyTopColor(double solarAltitude) {
    if (solarAltitude >= _altFullDay) {
      return AppColors.skyMidday;
    }
    if (solarAltitude >= _altGoldenHourBottom) {
      // Golden hour: deep blue → warm blue.
      final t = _inverseLerp(
          solarAltitude, _altGoldenHourBottom, _altGoldenHourTop);
      return Color.lerp(AppColors.skyPreSunrise, AppColors.skyMidday, t)!;
    }
    if (solarAltitude >= _altSunsetOrangeBottom) {
      // Sunset / sunrise band.
      final t = _inverseLerp(
          solarAltitude, _altSunsetOrangeBottom, _altSunsetOrangeTop);
      return Color.lerp(
          AppColors.skyDusk, AppColors.skyPreSunrise, t)!;
    }
    if (solarAltitude >= _altCivilBottom) {
      // Civil twilight: deep purple fading to dark navy.
      final t = _inverseLerp(solarAltitude, _altCivilBottom, _altCivilTop);
      return Color.lerp(AppColors.skyDawnCivil, AppColors.skyTwilight, t)!;
    }
    if (solarAltitude >= _altNauticalBottom) {
      // Nautical twilight.
      final t = _inverseLerp(
          solarAltitude, _altNauticalBottom, _altNauticalTop);
      return Color.lerp(AppColors.backgroundSurface, AppColors.skyDawnCivil, t)!;
    }
    // Full night.
    return AppColors.backgroundDeep;
  }

  /// Horizon / lower sky colour derived from solar altitude.
  Color _skyBottomColor(double solarAltitude) {
    if (solarAltitude >= _altFullDay) {
      return AppColors.skyMorning;
    }
    if (solarAltitude >= _altGoldenHourBottom) {
      final t = _inverseLerp(
          solarAltitude, _altGoldenHourBottom, _altGoldenHourTop);
      return Color.lerp(AppColors.skyPreSunset, AppColors.skyMorning, t)!;
    }
    if (solarAltitude >= _altSunsetOrangeBottom) {
      final t = _inverseLerp(
          solarAltitude, _altSunsetOrangeBottom, _altSunsetOrangeTop);
      return Color.lerp(AppColors.skySunset, AppColors.skyPreSunset, t)!;
    }
    if (solarAltitude >= _altCivilBottom) {
      final t = _inverseLerp(solarAltitude, _altCivilBottom, _altCivilTop);
      return Color.lerp(AppColors.skyDawnCivil, AppColors.skySunset, t)!;
    }
    if (solarAltitude >= _altNauticalBottom) {
      final t = _inverseLerp(
          solarAltitude, _altNauticalBottom, _altNauticalTop);
      return Color.lerp(AppColors.backgroundMid, AppColors.skyDawnCivil, t)!;
    }
    return AppColors.backgroundMid;
  }

  /// Moon glow intensity based on solar altitude (how dark the sky is) and
  /// the moon's current illumination fraction [0.0, 1.0].
  double _moonGlowIntensity(double solarAltitude, double moonPhase) {
    // No moon glow in full daylight.
    if (solarAltitude >= _altCivilTop) return 0.0;

    // Sky darkness fraction: 0 at civil twilight threshold, 1 at full night.
    final skyDarkness =
        _inverseLerp(solarAltitude, _altCivilTop, _altNauticalBottom)
            .clamp(0.0, 1.0);

    // Moon phase contribution: full moon (1.0) = peak glow.
    // Apply a sqrt curve so crescent moons still have a gentle glow.
    final phaseContrib = math.sqrt(moonPhase.clamp(0.0, 1.0));

    return (skyDarkness * phaseContrib).clamp(0.0, 1.0);
  }

  /// Atmospheric scatter (golden-hour warm tint) scalar.
  ///
  /// Peaks when the sun is between −0.833° and 10°.
  double _atmosphericScatter(double solarAltitude) {
    const peakLow = -0.833;
    const peakHigh = 5.0;
    const fadeHigh = 15.0;

    if (solarAltitude < _altCivilBottom) return 0.0;
    if (solarAltitude > fadeHigh) return 0.0;

    if (solarAltitude >= peakLow && solarAltitude <= peakHigh) {
      // In the peak band — full scatter.
      return 1.0;
    }
    if (solarAltitude < peakLow) {
      // Below the horizon, fading.
      return _inverseLerp(solarAltitude, _altCivilBottom, peakLow)
          .clamp(0.0, 1.0);
    }
    // Above peak band, fading toward zero at 15°.
    return (1.0 -
            _inverseLerp(solarAltitude, peakHigh, fadeHigh).clamp(0.0, 1.0));
  }

  // ── Math utilities ─────────────────────────────────────────────────────────

  /// Linear interpolation: returns 0 when [t] = [a], 1 when [t] = [b].
  double _inverseLerp(double t, double a, double b) {
    if ((b - a).abs() < 1e-10) return 0.0;
    return (t - a) / (b - a);
  }

  /// Standard linear interpolation from [a] to [b] by [t].
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Smooth-step easing: 3t² − 2t³.  Maps [0, 1] → [0, 1] with zero
  /// derivative at both ends, producing an ease-in/ease-out curve.
  double _smoothStep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3.0 - 2.0 * c);
  }
}

// ── AppColors aliases ──────────────────────────────────────────────────────────
// Re-used below; pulled from the central palette for clarity.
extension on AppColors {
  static const Color backgroundSurface = Color(0xFF0A0E2A);
}
