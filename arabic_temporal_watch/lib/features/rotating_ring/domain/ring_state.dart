// ring_state.dart
//
// Complete state of the rotating ring at any given moment.
//
// The Arabic Temporal Watch ring shows all 24 classical Arabic temporal period
// names arranged around a circle.  The ring rotates COUNTER-CLOCKWISE so the
// currently active period is always positioned at the 12 o'clock (top) marker.
//
// Design notes
// ────────────
//   • [RingState] is an immutable snapshot consumed by [RingPainter].
//   • [RingSegment] carries both geometry and render-state for one of the 24
//     arc slices.  Keeping color/opacity here keeps the painter stateless.
//   • The [dayNightBlend] scalar lets painters morph between the warm gold day
//     palette and the cool silver night palette without the segment list
//     changing length or structure.
//   • [beadCount] on each segment drives the minute-bead overlay: one small
//     glowing dot per 5 minutes of that period's wall-clock duration.

import 'package:flutter/material.dart';

// ── RingState ────────────────────────────────────────────────────────────────

/// Immutable snapshot of the rotating ring's full render state.
///
/// Produced by [RingCalculator.buildRingState] and consumed by [RingPainter].
/// Because all fields are final, Flutter's repaint system can cheaply compare
/// two [RingState] instances to decide whether a repaint is needed.
@immutable
class RingState {
  const RingState({
    required this.rotationAngle,
    required this.targetRotationAngle,
    required this.segments,
    required this.dayNightBlend,
    required this.isTransitioning,
    required this.transitionProgress,
  });

  // ── Rotation ──────────────────────────────────────────────────────────────

  /// Current ring rotation in radians, applied as `Transform.rotate`.
  ///
  /// Negative values produce counter-clockwise rotation, which is the normal
  /// direction because the ring must rotate CCW to advance the current segment
  /// toward the 12 o'clock position as time moves forward.
  final double rotationAngle;

  /// Target rotation angle in radians — where the ring is currently animating
  /// towards.  The animator uses shortest-path interpolation across the 0/2π
  /// boundary to avoid spinning the wrong way.
  final double targetRotationAngle;

  // ── Segments ──────────────────────────────────────────────────────────────

  /// All 24 ring segments with their current render state.
  ///
  /// Ordered by global index: indices 0–11 are day periods (Al-Shurooq …
  /// Al-Ghurubb) and indices 12–23 are night periods (Al-Shafaq … Al-Sabah).
  final List<RingSegment> segments;

  // ── Day/night blend ───────────────────────────────────────────────────────

  /// Blend scalar for the day ↔ night visual palette.
  ///
  /// `0.0` = full day mode (gold palette, bright labels).
  /// `1.0` = full night mode (silver/moonlight palette, dim labels).
  ///
  /// Values between 0 and 1 occur during sunrise/sunset transitions.
  final double dayNightBlend;

  // ── Transition flags ──────────────────────────────────────────────────────

  /// True while a sunrise or sunset transition animation is playing.
  final bool isTransitioning;

  /// How far through the current transition animation we are.
  ///
  /// Range: `[0.0, 1.0]`.  Only meaningful when [isTransitioning] is true.
  final double transitionProgress;

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// The currently active segment (where [RingSegment.isCurrent] is true).
  ///
  /// Returns `null` in the degenerate case where no segment is marked current
  /// (should not happen in normal operation).
  RingSegment? get currentSegment {
    for (final seg in segments) {
      if (seg.isCurrent) return seg;
    }
    return null;
  }

  /// Convenience: true when the day/night blend is closer to night (> 0.5).
  bool get isNightDominant => dayNightBlend > 0.5;

  // ── copyWith ──────────────────────────────────────────────────────────────

  RingState copyWith({
    double? rotationAngle,
    double? targetRotationAngle,
    List<RingSegment>? segments,
    double? dayNightBlend,
    bool? isTransitioning,
    double? transitionProgress,
  }) {
    return RingState(
      rotationAngle: rotationAngle ?? this.rotationAngle,
      targetRotationAngle: targetRotationAngle ?? this.targetRotationAngle,
      segments: segments ?? this.segments,
      dayNightBlend: dayNightBlend ?? this.dayNightBlend,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      transitionProgress: transitionProgress ?? this.transitionProgress,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RingState) return false;
    return other.rotationAngle == rotationAngle &&
        other.targetRotationAngle == targetRotationAngle &&
        other.dayNightBlend == dayNightBlend &&
        other.isTransitioning == isTransitioning &&
        other.transitionProgress == transitionProgress &&
        _segmentsEqual(other.segments, segments);
  }

  @override
  int get hashCode => Object.hash(
        rotationAngle,
        targetRotationAngle,
        dayNightBlend,
        isTransitioning,
        transitionProgress,
        Object.hashAll(segments),
      );

  static bool _segmentsEqual(List<RingSegment> a, List<RingSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'RingState('
      'rotation: ${rotationAngle.toStringAsFixed(4)} rad, '
      'blend: ${dayNightBlend.toStringAsFixed(2)}, '
      'transitioning: $isTransitioning)';
}

// ── RingSegment ───────────────────────────────────────────────────────────────

/// Render state for a single arc segment of the 24-period ring.
///
/// Each [RingSegment] describes:
///   * Which temporal period it represents ([index], [arabicName], …).
///   * Its position on the ring arc ([startAngle], [sweepAngle]).
///   * Its current visual state ([opacity], [labelColor], [segmentColor], …).
///   * The number of minute beads to overlay on the arc ([beadCount]).
@immutable
class RingSegment {
  const RingSegment({
    required this.index,
    required this.arabicName,
    required this.transliteration,
    required this.isDay,
    required this.isCurrent,
    required this.opacity,
    required this.labelColor,
    required this.segmentColor,
    required this.glowColor,
    required this.startAngle,
    required this.sweepAngle,
    required this.beadCount,
  });

  // ── Identity ──────────────────────────────────────────────────────────────

  /// Global index across all 24 periods: 0–11 = day, 12–23 = night.
  final int index;

  /// Arabic script name, e.g. "الشروق".
  final String arabicName;

  /// Latin transliteration using the ALA-LC scheme, e.g. "Al-Shurooq".
  final String transliteration;

  // ── Kind ──────────────────────────────────────────────────────────────────

  /// True if this segment belongs to the 12 daytime periods.
  final bool isDay;

  // ── State flags ───────────────────────────────────────────────────────────

  /// True when this segment is the currently active temporal period.
  ///
  /// The painter draws a gold highlight and glow effect on the current segment.
  final bool isCurrent;

  // ── Visual properties ─────────────────────────────────────────────────────

  /// Overall opacity of this segment in the ring.
  ///
  /// Non-current segments are rendered at reduced opacity (≈ 0.6) to let the
  /// active period visually "pop".  During day/night transitions the segments
  /// entering/leaving also fade.
  final double opacity;

  /// Color used to render the Arabic label text.
  final Color labelColor;

  /// Background fill color of the arc segment.
  final Color segmentColor;

  /// Glow color applied via [MaskFilter.blur] on the current segment.
  final Color glowColor;

  // ── Geometry ──────────────────────────────────────────────────────────────

  /// Start angle of this segment on the ring in radians.
  ///
  /// Uses the Flutter canvas convention: 0 = 3 o'clock, angles increase
  /// clockwise.  A −π/2 offset is applied by the painter to orient 0 toward
  /// 12 o'clock before drawing.
  final double startAngle;

  /// Angular width of this segment in radians.
  ///
  /// For 24 equal segments: π/12 ≈ 0.2618 rad (15°).  Non-equal temporal-hour
  /// segments have values proportional to the sunrise-to-sunset or
  /// sunset-to-sunrise durations.
  final double sweepAngle;

  // ── Minute beads ──────────────────────────────────────────────────────────

  /// Number of minute bead dots to place along this segment's arc.
  ///
  /// Computed as `floor(period.duration.inMinutes / 5)` so there is one bead
  /// per 5-minute interval.  A segment representing 70 minutes → 14 beads.
  final double beadCount;

  // ── Derived ───────────────────────────────────────────────────────────────

  /// Mid-point angle of this segment — used to center the Arabic label.
  double get midAngle => startAngle + sweepAngle * 0.5;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RingSegment) return false;
    return other.index == index &&
        other.isCurrent == isCurrent &&
        other.opacity == opacity &&
        other.labelColor == labelColor &&
        other.segmentColor == segmentColor &&
        other.glowColor == glowColor &&
        other.startAngle == startAngle &&
        other.sweepAngle == sweepAngle &&
        other.beadCount == beadCount;
  }

  @override
  int get hashCode => Object.hash(
        index,
        isCurrent,
        opacity,
        labelColor,
        segmentColor,
        glowColor,
        startAngle,
        sweepAngle,
        beadCount,
      );

  RingSegment copyWith({
    int? index,
    String? arabicName,
    String? transliteration,
    bool? isDay,
    bool? isCurrent,
    double? opacity,
    Color? labelColor,
    Color? segmentColor,
    Color? glowColor,
    double? startAngle,
    double? sweepAngle,
    double? beadCount,
  }) {
    return RingSegment(
      index: index ?? this.index,
      arabicName: arabicName ?? this.arabicName,
      transliteration: transliteration ?? this.transliteration,
      isDay: isDay ?? this.isDay,
      isCurrent: isCurrent ?? this.isCurrent,
      opacity: opacity ?? this.opacity,
      labelColor: labelColor ?? this.labelColor,
      segmentColor: segmentColor ?? this.segmentColor,
      glowColor: glowColor ?? this.glowColor,
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
      beadCount: beadCount ?? this.beadCount,
    );
  }

  @override
  String toString() => 'RingSegment($transliteration, '
      'idx: $index, current: $isCurrent, '
      'start: ${startAngle.toStringAsFixed(3)} rad)';
}
