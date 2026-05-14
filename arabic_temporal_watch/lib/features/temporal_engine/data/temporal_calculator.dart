// temporal_calculator.dart
//
// Core temporal calculation engine for the Arabic period system.
//
// Concept
// ───────
// The classical Arabic (and broader Semitic / Greek) system divides the day
// into 12 "temporal hours" — unequal civil hours whose length varies with the
// season.  Each temporal hour is simply:
//
//     day hour length   = (sunset − sunrise) / 12
//     night hour length = (next sunrise − sunset) / 12
//
// This implementation distributes the 12 day periods EQUALLY within
// [sunrise, sunset] and the 12 night periods EQUALLY within
// [sunset, next sunrise], matching the classical Arabic convention.
//
// Ring geometry
// ─────────────
// The watch-face ring displays all 24 periods as equal-width arc segments
// arranged in a full circle.  Each segment subtends 360° / 24 = 15° (π/12
// radians).  Day periods occupy the upper semicircle (−90° to +90°, i.e. the
// top half when looking at the watch) and night periods the lower.
//
// The ring is rotated counter-clockwise so the current period is always
// positioned at the 12 o'clock (top-centre) position.  The rotation angle
// is calculated as:
//
//     rotation = −(globalIndex × segmentAngle + progressFraction × segmentAngle)
//
// where globalIndex is 0–11 for day periods and 12–23 for night periods.
//
// All returned [DateTime] values are local time.

import 'dart:math' as math;

import '../domain/arabic_period.dart';

// ── TemporalCalculator ────────────────────────────────────────────────────────

/// Pure-Dart, dependency-free calculator for the Arabic temporal-period system.
///
/// Typical usage:
/// ```dart
/// final calc = TemporalCalculator();
/// final data = calc.calculate(
///   now: DateTime.now(),
///   sunrise: todaySunrise,
///   sunset: todaySunset,
///   nextSunrise: tomorrowSunrise,
/// );
/// ```
class TemporalCalculator {
  const TemporalCalculator();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Distributes 12 daytime slots equally between [sunrise] and [sunset].
  ///
  /// Slots are labelled with the corresponding [kDayPeriods] descriptors in
  /// order (index 0 = Al-Shurooq … index 11 = Al-Ghurubb).
  ///
  /// The ring arc angles place period 0 at the 12 o'clock position of the day
  /// semicircle (−π/2 from the top) and proceed clockwise.
  List<ArabicPeriodSlot> calculateDayPeriods({
    required DateTime sunrise,
    required DateTime sunset,
  }) {
    final dayDuration = sunset.difference(sunrise);
    assert(!dayDuration.isNegative, 'sunset must be after sunrise');

    final slotMicros = dayDuration.inMicroseconds / 12.0;
    final slots = <ArabicPeriodSlot>[];

    for (int i = 0; i < 12; i++) {
      final startMicros = (slotMicros * i).round();
      final endMicros = (slotMicros * (i + 1)).round();

      final slotStart =
          sunrise.add(Duration(microseconds: startMicros));
      final slotEnd = sunrise.add(Duration(microseconds: endMicros));

      // Day periods occupy the top half of the ring starting at 12 o'clock
      // and proceeding clockwise.  Segment 0 starts at −π/2 (12 o'clock) and
      // segment 11 ends at π/2 (6 o'clock on the right side).
      // In practice the ring painter rotates the whole ring; these angles
      // represent the natural position before rotation.
      final startAngle = i * kSegmentAngle;
      final endAngle = (i + 1) * kSegmentAngle;

      slots.add(ArabicPeriodSlot(
        period: kDayPeriods[i],
        startTime: slotStart,
        endTime: slotEnd,
        startAngle: startAngle,
        endAngle: endAngle,
      ));
    }

    return slots;
  }

  /// Distributes 12 nighttime slots equally between [sunset] and [nextSunrise].
  ///
  /// Slots are labelled with [kNightPeriods] descriptors (index 0 = Al-Shafaq
  /// … index 11 = Al-Sabah).  Night angles continue from where day angles end
  /// (globalIndex 12–23, angles π … 2π).
  List<ArabicPeriodSlot> calculateNightPeriods({
    required DateTime sunset,
    required DateTime nextSunrise,
  }) {
    final nightDuration = nextSunrise.difference(sunset);
    assert(!nightDuration.isNegative, 'nextSunrise must be after sunset');

    final slotMicros = nightDuration.inMicroseconds / 12.0;
    final slots = <ArabicPeriodSlot>[];

    for (int i = 0; i < 12; i++) {
      final startMicros = (slotMicros * i).round();
      final endMicros = (slotMicros * (i + 1)).round();

      final slotStart = sunset.add(Duration(microseconds: startMicros));
      final slotEnd = sunset.add(Duration(microseconds: endMicros));

      // Night periods follow day periods around the ring (angles π … 2π).
      final globalIndex = i + 12;
      final startAngle = globalIndex * kSegmentAngle;
      final endAngle = (globalIndex + 1) * kSegmentAngle;

      slots.add(ArabicPeriodSlot(
        period: kNightPeriods[i],
        startTime: slotStart,
        endTime: slotEnd,
        startAngle: startAngle,
        endAngle: endAngle,
      ));
    }

    return slots;
  }

  /// Returns the [ArabicPeriodSlot] from [periods] that contains [now], or
  /// null when [now] falls outside every slot in the list.
  ///
  /// The last slot's [ArabicPeriodSlot.endTime] is treated as exclusive so
  /// that the transition to the next list (day → night or night → day) is
  /// unambiguous.
  ArabicPeriodSlot? getCurrentPeriod({
    required DateTime now,
    required List<ArabicPeriodSlot> periods,
  }) {
    for (final slot in periods) {
      if (!now.isBefore(slot.startTime) && now.isBefore(slot.endTime)) {
        return slot;
      }
    }
    // Edge case: exactly at or after the last slot's end — return the last.
    if (periods.isNotEmpty && !now.isBefore(periods.last.endTime)) {
      return periods.last;
    }
    return null;
  }

  /// Calculates the ring rotation angle so the current period is centred at
  /// the 12 o'clock position.
  ///
  /// The ring has 24 equal segments, each [kSegmentAngle] (π/12) radians wide.
  /// The global index for day periods is [periodIndex] (0–11) and for night
  /// periods is [periodIndex] + 12 (12–23).
  ///
  /// The rotation is negative (counter-clockwise) because we want to bring the
  /// current segment up to the top.
  ///
  /// ```
  /// rotation = −(globalIndex × segmentAngle + progressFraction × segmentAngle)
  /// ```
  double calculateRingRotation({
    required int periodIndex,
    required double progressFraction,
    required bool isDay,
  }) {
    final globalIndex = isDay ? periodIndex : periodIndex + 12;
    final exactAngle =
        (globalIndex + progressFraction.clamp(0.0, 1.0)) * kSegmentAngle;
    return -exactAngle;
  }

  /// Computes the complete [TemporalData] snapshot for [now].
  ///
  /// [sunrise] and [sunset] define today's solar day.
  /// [nextSunrise] is tomorrow's sunrise, needed to bound the final night slot.
  ///
  /// If [now] falls before [sunrise] it is treated as still within the
  /// preceding night (using tonight's night slots reversed so the last slot
  /// covers [now]).  In that case the caller should supply a [sunrise] from
  /// the previous day and [sunset] from the previous day for accurate night
  /// slot durations; however, this method will degrade gracefully by using the
  /// current [sunset] as a proxy.
  TemporalData calculate({
    required DateTime now,
    required DateTime sunrise,
    required DateTime sunset,
    required DateTime nextSunrise,
  }) {
    // Compute both period lists.
    final dayPeriods = calculateDayPeriods(
      sunrise: sunrise,
      sunset: sunset,
    );
    final nightPeriods = calculateNightPeriods(
      sunset: sunset,
      nextSunrise: nextSunrise,
    );

    // Determine whether we are in the day or night half.
    final isDay = !now.isBefore(sunrise) && now.isBefore(sunset);

    // Find the active slot.
    ArabicPeriodSlot? activeSlot;
    if (isDay) {
      activeSlot = getCurrentPeriod(now: now, periods: dayPeriods);
    } else {
      activeSlot = getCurrentPeriod(now: now, periods: nightPeriods);
    }

    // Fallback: if [now] is before sunrise use last night period; if after
    // sunset but before first night period start use first night period.
    activeSlot ??= isDay ? dayPeriods.first : nightPeriods.first;

    // Progress within the active slot.
    final progress = activeSlot.progressAt(now);

    // Elapsed / remaining durations.
    final totalDuration = activeSlot.duration;
    final elapsed = now.difference(activeSlot.startTime);
    final remaining = activeSlot.endTime.difference(now);

    // Next slot.
    ArabicPeriodSlot? nextSlot;
    if (isDay) {
      final idx = dayPeriods.indexOf(activeSlot);
      if (idx >= 0 && idx + 1 < dayPeriods.length) {
        nextSlot = dayPeriods[idx + 1];
      } else {
        // Transition to night.
        nextSlot = nightPeriods.isNotEmpty ? nightPeriods.first : null;
      }
    } else {
      final idx = nightPeriods.indexOf(activeSlot);
      if (idx >= 0 && idx + 1 < nightPeriods.length) {
        nextSlot = nightPeriods[idx + 1];
      } else {
        // Last night period — next is the first day period of tomorrow.
        // Return null since tomorrow's slots are not computed here.
        nextSlot = null;
      }
    }

    // Ring rotation.
    final rotation = calculateRingRotation(
      periodIndex: activeSlot.period.index,
      progressFraction: progress,
      isDay: isDay,
    );

    // Day/night transition progress.
    final phase = resolveTransitionPhase(
      now: now,
      sunrise: sunrise,
      sunset: sunset,
    );
    final transitionProg = (phase == TransitionPhase.sunriseTransition ||
            phase == TransitionPhase.sunsetTransition)
        ? transitionProgressFor(
            now: now,
            event: phase == TransitionPhase.sunriseTransition
                ? sunrise
                : sunset,
          )
        : (isDay ? 1.0 : 0.0);

    return TemporalData(
      currentPeriod: activeSlot,
      nextPeriod: nextSlot,
      periodStart: activeSlot.startTime,
      periodEnd: activeSlot.endTime,
      progressFraction: progress,
      elapsed: elapsed.isNegative ? Duration.zero : elapsed,
      remaining: remaining.isNegative ? Duration.zero : remaining,
      totalDuration: totalDuration,
      allDayPeriods: dayPeriods,
      allNightPeriods: nightPeriods,
      ringRotationAngle: rotation,
      isDay: isDay,
      transitionProgress: transitionProg,
    );
  }
}
