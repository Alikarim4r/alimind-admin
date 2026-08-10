// arabic_period.dart
//
// Domain models for the temporal engine.
//
// The Arabic day is divided into 24 unequal "temporal hours": 12 between
// sunrise and sunset (day periods) and 12 between sunset and the following
// sunrise (night periods).  This file defines the domain value objects that
// capture the computed slot data for a given calendar day and location.
//
// Design notes
// ────────────
//   • [ArabicPeriod] descriptors live in core/constants/arabic_periods.dart
//     and are imported here for cross-referencing only.
//   • [ArabicPeriodSlot] attaches runtime time-of-day data to a descriptor.
//   • [TemporalData] is the aggregate consumed by the presentation layer.
//   • All fields are immutable; use copyWith where mutation is needed.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/arabic_periods.dart';

// Re-export so consumers only need this file.
export '../../../core/constants/arabic_periods.dart'
    show ArabicPeriod, PeriodKind, kDayPeriods, kNightPeriods, kAllPeriods;

// ── ArabicPeriodSlot ──────────────────────────────────────────────────────────

/// A computed time slot that binds an [ArabicPeriod] descriptor to its
/// concrete start/end instants for a specific calendar day and location.
///
/// The ring geometry fields ([startAngle], [endAngle]) use the convention
/// that 0 radians maps to the 12 o'clock position on the ring face, with
/// angles increasing clockwise (matching Flutter's [Canvas] coordinate system
/// after a −π/2 offset is applied by the painter).
class ArabicPeriodSlot extends Equatable {
  const ArabicPeriodSlot({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.startAngle,
    required this.endAngle,
  });

  /// The static descriptor (name, colour, transliteration …).
  final ArabicPeriod period;

  /// Local [DateTime] when this slot begins.
  final DateTime startTime;

  /// Local [DateTime] when this slot ends (exclusive — start of next slot).
  final DateTime endTime;

  /// Angle (radians) on the full 24-period ring where this slot begins.
  /// Range: [0, 2π).
  final double startAngle;

  /// Angle (radians) on the full 24-period ring where this slot ends.
  /// Range: (0, 2π].
  final double endAngle;

  // ── Derived ─────────────────────────────────────────────────────────────────

  /// Duration of the slot.
  Duration get duration => endTime.difference(startTime);

  /// Mid-point angle on the ring — useful for centering labels.
  double get midAngle => (startAngle + endAngle) / 2.0;

  /// Convenience access to [ArabicPeriod.index].
  int get index => period.index;

  /// Convenience access to [ArabicPeriod.kind].
  PeriodKind get kind => period.kind;

  /// Returns the fraction [0.0, 1.0] that [moment] has elapsed through this
  /// slot.  Clamps to [0.0, 1.0] for moments outside the slot's range.
  double progressAt(DateTime moment) {
    final total = duration.inMicroseconds;
    if (total <= 0) return 0.0;
    final elapsed = moment.difference(startTime).inMicroseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props =>
      [period, startTime, endTime, startAngle, endAngle];

  @override
  String toString() => 'ArabicPeriodSlot(${period.transliteration} '
      '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} – '
      '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')})';

  ArabicPeriodSlot copyWith({
    ArabicPeriod? period,
    DateTime? startTime,
    DateTime? endTime,
    double? startAngle,
    double? endAngle,
  }) {
    return ArabicPeriodSlot(
      period: period ?? this.period,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startAngle: startAngle ?? this.startAngle,
      endAngle: endAngle ?? this.endAngle,
    );
  }
}

// ── TemporalData ──────────────────────────────────────────────────────────────

/// The complete snapshot of temporal state for a given instant.
///
/// Produced by [TemporalCalculator.calculate] and consumed by every widget
/// in the temporal-engine presentation layer.  Because this is an [Equatable]
/// value object, Riverpod / Flutter can cheaply detect when a rebuild is
/// needed by comparing consecutive stream emissions.
class TemporalData extends Equatable {
  const TemporalData({
    required this.currentPeriod,
    required this.nextPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.progressFraction,
    required this.elapsed,
    required this.remaining,
    required this.totalDuration,
    required this.allDayPeriods,
    required this.allNightPeriods,
    required this.ringRotationAngle,
    required this.isDay,
    required this.transitionProgress,
  });

  // ── Current period ───────────────────────────────────────────────────────────

  /// The temporal slot that is currently active.
  final ArabicPeriodSlot currentPeriod;

  /// The slot that follows [currentPeriod], or null when [currentPeriod] is
  /// the last nighttime period just before the next sunrise.
  final ArabicPeriodSlot? nextPeriod;

  // ── Timing ───────────────────────────────────────────────────────────────────

  /// Local [DateTime] at which the current slot started.
  final DateTime periodStart;

  /// Local [DateTime] at which the current slot ends (start of [nextPeriod]).
  final DateTime periodEnd;

  /// Fraction [0.0, 1.0] of the current slot that has elapsed.
  final double progressFraction;

  /// Time elapsed since the start of the current slot.
  final Duration elapsed;

  /// Time remaining until the end of the current slot.
  final Duration remaining;

  /// Total duration of the current slot.
  final Duration totalDuration;

  // ── Full day schedule ─────────────────────────────────────────────────────────

  /// All 12 daytime slots for today (sunrise → sunset).
  final List<ArabicPeriodSlot> allDayPeriods;

  /// All 12 nighttime slots for today (sunset → next sunrise).
  final List<ArabicPeriodSlot> allNightPeriods;

  // ── Ring geometry ─────────────────────────────────────────────────────────────

  /// The angle (radians) by which the 24-period ring should be rotated so that
  /// the current period label is positioned at the 12 o'clock position.
  ///
  /// Negative values indicate counter-clockwise rotation.
  final double ringRotationAngle;

  // ── Day/night state ───────────────────────────────────────────────────────────

  /// True when the current time falls between sunrise and sunset.
  final bool isDay;

  /// How far through the sunrise → sunset (or sunset → sunrise) transition
  /// the current moment is, as a fraction [0.0, 1.0].
  ///
  /// Used by the UI to animate sky-gradient and glow-colour changes.
  final double transitionProgress;

  // ── Convenience getters ───────────────────────────────────────────────────────

  /// All 24 slots in order: 12 day then 12 night.
  List<ArabicPeriodSlot> get allPeriods => [
        ...allDayPeriods,
        ...allNightPeriods,
      ];

  /// The dominant background [Color] for the current period.
  Color get primaryColor => currentPeriod.period.primaryColor;

  /// The accent [Color] for the current period.
  Color get secondaryColor => currentPeriod.period.secondaryColor;

  /// The Arabic name of the current period.
  String get arabicName => currentPeriod.period.arabicName;

  /// The Latin transliteration of the current period name.
  String get transliteration => currentPeriod.period.transliteration;

  // ── Equatable ─────────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        currentPeriod,
        nextPeriod,
        periodStart,
        periodEnd,
        progressFraction,
        elapsed,
        remaining,
        totalDuration,
        allDayPeriods,
        allNightPeriods,
        ringRotationAngle,
        isDay,
        transitionProgress,
      ];

  @override
  String toString() => 'TemporalData('
      '${currentPeriod.period.transliteration}, '
      'progress: ${(progressFraction * 100).toStringAsFixed(1)}%, '
      'isDay: $isDay)';

  TemporalData copyWith({
    ArabicPeriodSlot? currentPeriod,
    ArabicPeriodSlot? nextPeriod,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? progressFraction,
    Duration? elapsed,
    Duration? remaining,
    Duration? totalDuration,
    List<ArabicPeriodSlot>? allDayPeriods,
    List<ArabicPeriodSlot>? allNightPeriods,
    double? ringRotationAngle,
    bool? isDay,
    double? transitionProgress,
  }) {
    return TemporalData(
      currentPeriod: currentPeriod ?? this.currentPeriod,
      nextPeriod: nextPeriod ?? this.nextPeriod,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      progressFraction: progressFraction ?? this.progressFraction,
      elapsed: elapsed ?? this.elapsed,
      remaining: remaining ?? this.remaining,
      totalDuration: totalDuration ?? this.totalDuration,
      allDayPeriods: allDayPeriods ?? this.allDayPeriods,
      allNightPeriods: allNightPeriods ?? this.allNightPeriods,
      ringRotationAngle: ringRotationAngle ?? this.ringRotationAngle,
      isDay: isDay ?? this.isDay,
      transitionProgress: transitionProgress ?? this.transitionProgress,
    );
  }
}

// ── TransitionState ───────────────────────────────────────────────────────────

/// Captures whether the UI is currently animating a day↔night transition.
///
/// Used by [transitionStateProvider] to gate transition animations so they
/// only fire once per sunrise/sunset crossing rather than on every tick.
enum TransitionPhase {
  /// Normal day period — no active transition.
  day,

  /// Normal night period — no active transition.
  night,

  /// Actively transitioning from night to day (sunrise window).
  sunriseTransition,

  /// Actively transitioning from day to night (sunset window).
  sunsetTransition,
}

/// The window either side of sunrise/sunset during which the transition
/// animation plays.  Chosen to match the typical civil-twilight duration.
const Duration kTransitionWindow = Duration(minutes: 20);

/// Returns the appropriate [TransitionPhase] for the given [now] relative to
/// [sunrise] and [sunset].
TransitionPhase resolveTransitionPhase({
  required DateTime now,
  required DateTime sunrise,
  required DateTime sunset,
}) {
  final sunriseStart = sunrise.subtract(kTransitionWindow);
  final sunriseEnd = sunrise.add(kTransitionWindow);
  final sunsetStart = sunset.subtract(kTransitionWindow);
  final sunsetEnd = sunset.add(kTransitionWindow);

  if (!now.isBefore(sunriseStart) && now.isBefore(sunriseEnd)) {
    return TransitionPhase.sunriseTransition;
  }
  if (!now.isBefore(sunsetStart) && now.isBefore(sunsetEnd)) {
    return TransitionPhase.sunsetTransition;
  }
  if (!now.isBefore(sunrise) && now.isBefore(sunset)) {
    return TransitionPhase.day;
  }
  return TransitionPhase.night;
}

/// Computes the transition progress fraction [0.0, 1.0] within the transition
/// window centred on [event] (sunrise or sunset).
///
/// Returns 0.0 outside the window and 1.0 at [event] + [kTransitionWindow].
double transitionProgressFor({
  required DateTime now,
  required DateTime event,
}) {
  final windowSeconds = kTransitionWindow.inSeconds * 2.0;
  if (windowSeconds <= 0) return 0.0;
  final elapsed = now.difference(event.subtract(kTransitionWindow)).inSeconds;
  return (elapsed / windowSeconds).clamp(0.0, 1.0);
}

// ── Ring geometry constants ───────────────────────────────────────────────────

/// Angular width of each of the 24 ring segments (radians).
///
/// With 24 equal segments: 2π / 24 = π / 12 ≈ 0.2618 radians (= 15°).
const double kSegmentAngle = math.pi / 12.0; // 15°

/// Total angular span of the day arc (12 segments = 180°).
const double kDayArcAngle = math.pi; // 180°

/// Total angular span of the night arc (12 segments = 180°).
const double kNightArcAngle = math.pi; // 180°
