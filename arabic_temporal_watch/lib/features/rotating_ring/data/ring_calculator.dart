// ring_calculator.dart
//
// Ring geometry and animation calculator for the Arabic Temporal Watch.
//
// Responsibilities
// ────────────────
//   • Build the list of 24 [RingSegment] objects from [TemporalData].
//   • Compute smooth, shortest-path ring rotation angles.
//   • Derive glow intensity for the current segment (slow sinusoidal pulse).
//   • Calculate the Cartesian positions of the minute bead dots.
//   • Assemble a complete [RingState] from [TemporalData] + animation values.
//
// Segment angle convention
// ────────────────────────
// The ring is conceptually a clock face laid flat.  The Flutter canvas has
// 0 rad at the 3 o'clock position; painters add −π/2 to shift 0 to 12 o'clock.
// Segment index 0 (Al-Shurooq) begins at angle 0 on the ring's own coordinate
// system (i.e. at 12 o'clock when the ring is un-rotated).  Each successive
// segment adds kSegmentAngle = π/12 radians clockwise.
//
// Rotation direction
// ──────────────────
// The ring rotates COUNTER-CLOCKWISE (negative radians) to bring the current
// period to the 12 o'clock position.  If segment i starts at angle φ, the
// required rotation is –φ (or equivalently 2π – φ CCW) modulo 2π.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../temporal_engine/domain/arabic_period.dart';
import '../domain/ring_state.dart';

// ── RingCalculator ────────────────────────────────────────────────────────────

/// Stateless calculator that converts [TemporalData] into ring geometry and
/// animation data consumed by [RingPainter].
///
/// All public methods are pure functions — they do not mutate state and can be
/// called on any isolate or in [CustomPainter.paint] without side effects.
class RingCalculator {
  const RingCalculator();

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Angular width of each segment when all 24 are equally spaced (π/12 = 15°).
  static const double _equalSegmentAngle = kSegmentAngle; // π/12

  /// Opacity for non-current segments during normal rendering.
  static const double _inactiveOpacity = 0.60;

  /// Opacity for current segment.
  static const double _activeOpacity = 1.00;

  /// Glow pulse frequency in Hz (one full pulse every ~3 seconds).
  static const double _glowPulseHz = 0.33;

  /// Minimum glow intensity (dim phase of the pulse).
  static const double _glowMin = 0.55;

  /// Maximum glow intensity (bright phase of the pulse).
  static const double _glowMax = 1.00;

  /// Minutes per minute-bead.
  static const int _minutesPerBead = 5;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Build all 24 [RingSegment] objects from [TemporalData].
  ///
  /// When [TemporalData.allDayPeriods] and [allNightPeriods] are populated,
  /// the segments use the actual unequal temporal-hour durations to compute
  /// proportional sweep angles.  If either list is empty (unlikely but
  /// defensive), equal 15° segments are used as a fallback.
  ///
  /// [currentRotation] and [animationTime] are forwarded to the segment color
  /// blending logic so that the day/night transition is reflected correctly.
  List<RingSegment> buildSegments(
    TemporalData data, {
    double dayNightBlend = 0.0,
  }) {
    final allSlots = data.allPeriods;
    final currentGlobalIndex = data.currentPeriod.period.globalIndex;

    // Decide whether to use proportional or equal segment angles.
    final useProportional =
        allSlots.length == 24 && _hasValidAngles(allSlots);

    final segments = <RingSegment>[];

    for (var i = 0; i < allSlots.length; i++) {
      final slot = allSlots[i];
      final period = slot.period;
      final isCurrent = period.globalIndex == currentGlobalIndex;

      // ── Geometry ──────────────────────────────────────────────────────────
      final double startAngle;
      final double sweepAngle;

      if (useProportional) {
        startAngle = slot.startAngle;
        sweepAngle = slot.endAngle - slot.startAngle;
      } else {
        startAngle = i * _equalSegmentAngle;
        sweepAngle = _equalSegmentAngle;
      }

      // ── Colors ────────────────────────────────────────────────────────────
      final segmentColor = _blendSegmentColor(
        period.primaryColor,
        period.secondaryColor,
        dayNightBlend,
        isDay: period.isDay,
        isCurrent: isCurrent,
      );

      final labelColor = _labelColor(
        isDay: period.isDay,
        isCurrent: isCurrent,
        dayNightBlend: dayNightBlend,
      );

      final glowColor = _glowColor(
        baseColor: period.primaryColor,
        isDay: period.isDay,
        dayNightBlend: dayNightBlend,
      );

      // ── Opacity ───────────────────────────────────────────────────────────
      final opacity = isCurrent ? _activeOpacity : _inactiveOpacity;

      // ── Minute beads ──────────────────────────────────────────────────────
      final durationMinutes = slot.duration.inMinutes;
      final beadCount =
          durationMinutes > 0 ? (durationMinutes / _minutesPerBead).floor() : 0;

      segments.add(RingSegment(
        index: period.globalIndex,
        arabicName: period.arabicName,
        transliteration: period.transliteration,
        isDay: period.isDay,
        isCurrent: isCurrent,
        opacity: opacity,
        labelColor: labelColor,
        segmentColor: segmentColor,
        glowColor: glowColor,
        startAngle: startAngle,
        sweepAngle: sweepAngle.abs(),
        beadCount: beadCount.toDouble(),
      ));
    }

    return segments;
  }

  /// Calculate the smooth rotation angle that brings [targetSegmentIndex] to
  /// the 12 o'clock position via the shortest rotational path.
  ///
  /// [current] and [target] are both in radians.  This function resolves the
  /// 0/2π boundary discontinuity so the animation never spins the wrong way.
  ///
  /// Returns a value suitable for direct use with [Transform.rotate] (negative
  /// = counter-clockwise).
  double smoothRotation(double current, double target) {
    // Normalise both angles to [0, 2π).
    final normCurrent = _normalise(current);
    final normTarget = _normalise(target);

    // Compute the signed shortest delta (range: [−π, π]).
    double delta = normTarget - normCurrent;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    // Return the new angle without normalising, so the animator can track
    // cumulative rotation and avoid sudden jumps at the 0/2π wrap point.
    return current + delta;
  }

  /// Compute the target ring rotation (radians, negative = CCW) needed to
  /// place [segmentStartAngle] at the 12 o'clock position.
  ///
  /// On the ring the 12 o'clock position corresponds to angle 0 (top).  To
  /// bring segment at [segmentStartAngle] to the top, we rotate the ring by
  /// −segmentStartAngle.
  double targetRotationForSegment(double segmentStartAngle) {
    // We want the ring to rotate CCW so the segment's START angle aligns with
    // 12 o'clock.  Negative rotation = CCW.
    return -_normalise(segmentStartAngle);
  }

  /// Determine the glow pulse intensity for the current segment at [time]
  /// (wall-clock seconds, e.g. from [DateTime.now().millisecondsSinceEpoch] /
  /// 1000.0).
  ///
  /// Returns a value in [_glowMin, _glowMax].  The pulse uses a smooth cosine
  /// envelope so it never snaps.
  double glowIntensity(double time) {
    final phase = 2.0 * math.pi * _glowPulseHz * time;
    // cos oscillates [−1, 1]; remap to [_glowMin, _glowMax].
    final normalised = (math.cos(phase) + 1.0) / 2.0; // [0, 1]
    return _glowMin + normalised * (_glowMax - _glowMin);
  }

  /// Calculate the Cartesian positions of the minute bead dots for a single
  /// ring segment.
  ///
  /// Beads are evenly spaced along the arc from [startAngle] to
  /// [startAngle] + [sweepAngle], placed at [ringRadius] from the centre.
  ///
  /// The returned [Offset] values are in canvas coordinates relative to
  /// ([centerX], [centerY]).
  List<Offset> minuteBeadPositions({
    required double centerX,
    required double centerY,
    required double ringRadius,
    required int beadCount,
    required double startAngle,
    required double sweepAngle,
  }) {
    if (beadCount <= 0) return const [];

    final positions = <Offset>[];
    // Divide the sweep evenly; place the first bead slightly inset from the
    // start divider and the last bead slightly before the end divider.
    final padding = sweepAngle * 0.05; // 5% of sweep as a margin at each end
    final usableSweep = sweepAngle - 2.0 * padding;

    if (beadCount == 1) {
      final angle = startAngle + sweepAngle / 2.0;
      positions.add(_polarToOffset(centerX, centerY, ringRadius, angle));
    } else {
      final step = usableSweep / (beadCount - 1);
      for (var i = 0; i < beadCount; i++) {
        final angle = startAngle + padding + i * step;
        positions.add(_polarToOffset(centerX, centerY, ringRadius, angle));
      }
    }

    return positions;
  }

  /// Build a complete [RingState] from [TemporalData] and animation values.
  ///
  /// [currentRotation] is the ring's current rendered rotation (radians),
  /// driven by an external [AnimationController].
  ///
  /// [animationTime] is the elapsed wall-clock time in seconds, used to
  /// animate the glow pulse.
  RingState buildRingState({
    required TemporalData temporalData,
    required double currentRotation,
    required double animationTime,
  }) {
    // ── Day/night blend ──────────────────────────────────────────────────────
    // During a day→night or night→day transition the blend eases between 0 and
    // 1.  Outside transitions it sits at exactly 0 (day) or 1 (night).
    final double dayNightBlend;
    if (temporalData.isDay) {
      dayNightBlend = temporalData.transitionProgress > 0
          ? (1.0 - temporalData.transitionProgress).clamp(0.0, 1.0)
          : 0.0;
    } else {
      dayNightBlend = temporalData.transitionProgress > 0
          ? temporalData.transitionProgress.clamp(0.0, 1.0)
          : 1.0;
    }

    // ── Segments ─────────────────────────────────────────────────────────────
    final segments = buildSegments(temporalData, dayNightBlend: dayNightBlend);

    // ── Target rotation ───────────────────────────────────────────────────────
    final currentSlotStartAngle =
        temporalData.currentPeriod.startAngle;
    final rawTarget = targetRotationForSegment(currentSlotStartAngle);
    final targetAngle = smoothRotation(currentRotation, rawTarget);

    // ── Transition state ──────────────────────────────────────────────────────
    final isTransitioning = temporalData.transitionProgress > 0.0 &&
        temporalData.transitionProgress < 1.0;

    return RingState(
      rotationAngle: currentRotation,
      targetRotationAngle: targetAngle,
      segments: segments,
      dayNightBlend: dayNightBlend,
      isTransitioning: isTransitioning,
      transitionProgress: temporalData.transitionProgress,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalise [angle] to [0, 2π).
  double _normalise(double angle) {
    final result = angle % (2.0 * math.pi);
    return result < 0.0 ? result + 2.0 * math.pi : result;
  }

  /// Convert polar coordinates to a canvas [Offset].
  ///
  /// [angle] uses the Flutter canvas convention (0 = 3 o'clock, CW positive).
  Offset _polarToOffset(
    double cx,
    double cy,
    double r,
    double angle,
  ) {
    return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
  }

  /// Check that the slot list has non-trivial start/end angles (i.e. the
  /// calculator has run and set real proportional angles, not all zeros).
  bool _hasValidAngles(List<ArabicPeriodSlot> slots) {
    if (slots.isEmpty) return false;
    // If more than one slot has a non-zero endAngle the angles are real.
    var nonZero = 0;
    for (final slot in slots) {
      if (slot.endAngle.abs() > 1e-6) nonZero++;
      if (nonZero >= 2) return true;
    }
    return false;
  }

  /// Blend a segment's primary/secondary colors based on [dayNightBlend] and
  /// whether the segment is active.
  ///
  /// Day segments: primary is a warm hue, blended toward the muted version
  /// at night to keep the ring readable.
  /// Night segments: primary is dark; we lighten slightly during day mode so
  /// the label remains legible against the bright background.
  Color _blendSegmentColor(
    Color primary,
    Color secondary,
    double dayNightBlend, {
    required bool isDay,
    required bool isCurrent,
  }) {
    // Base color interpolated between primary (day/night mode) and secondary.
    final base = Color.lerp(primary, secondary, 0.3) ?? primary;

    // For the current segment, boost luminance regardless of day/night.
    if (isCurrent) {
      return Color.lerp(
        base,
        isDay ? AppColors.goldLight : AppColors.silverLight,
        0.25,
      )!;
    }

    // Non-current segments: modulate opacity to recede visually.
    return base.withOpacity(isDay
        ? (1.0 - dayNightBlend * 0.3)
        : (0.5 + dayNightBlend * 0.5));
  }

  /// Determine the text color for a segment label.
  Color _labelColor({
    required bool isDay,
    required bool isCurrent,
    required double dayNightBlend,
  }) {
    if (isCurrent) {
      // Active period label: bright gold (day) or bright silver (night).
      return Color.lerp(AppColors.goldPrimary, AppColors.silverLight,
          dayNightBlend)!;
    }

    if (isDay) {
      // Inactive day label: pale gold to muted, fades during night transition.
      return Color.lerp(
        AppColors.goldPale,
        AppColors.goldAntique,
        dayNightBlend * 0.6,
      )!;
    }

    // Inactive night label: dim silver.
    return Color.lerp(
      AppColors.silverDim,
      AppColors.silverMid,
      dayNightBlend,
    )!;
  }

  /// Determine the glow halo color for a segment based on its base color.
  Color _glowColor({
    required Color baseColor,
    required bool isDay,
    required double dayNightBlend,
  }) {
    // Day: gold glow.  Night: silver/blue glow.  Blend in between.
    final dayGlow = AppColors.glowGold;
    final nightGlow = AppColors.glowSilver;
    final blendedGlow = Color.lerp(dayGlow, nightGlow, dayNightBlend)!;

    // Modulate with the segment's own color for a tinted halo.
    return Color.lerp(blendedGlow, baseColor.withOpacity(0.5), 0.4)!;
  }
}
