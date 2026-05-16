// temporal_provider.dart
//
// Riverpod providers for the temporal engine.
//
// Provider graph
// ──────────────
//   prayerTimesProvider (from prayer_engine) — supplies sunrise/sunset
//     └── _sunriseProvider, _sunsetProvider  (derived convenience)
//
//   temporalDataProvider (StreamProvider<TemporalData>) — ticks every second
//     ├── currentArabicPeriodProvider     (derived ArabicPeriodSlot)
//     ├── ringRotationProvider            (derived double, radians)
//     └── transitionStateProvider         (Provider<TransitionPhase>)
//
// Design notes
// ────────────
//   • [temporalDataProvider] drives a 1-second [Stream.periodic] so the
//     progress fraction and ring angle update in real time.
//   • Tomorrow's sunrise is approximated by advancing today's sunrise by 24 h
//     when a dedicated tomorrow-prayer-times provider is not yet available.
//     Callers can override [_tomorrowSunriseProvider] once that provider exists
//     without changing the downstream graph.
//   • [ringRotationProvider] emits the raw rotation angle from [TemporalData].
//     Smooth animation (Tween / AnimationController) should be applied in the
//     widget layer using [flutter_animate] or a custom implicit animation.
//   • [transitionStateProvider] is a derived [Provider] so the UI can read and
//     react to phase changes independently of the full [TemporalData] rebuild.
//     Widgets can use [ref.listen] on it to trigger one-shot animations.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../prayer_engine/presentation/prayer_provider.dart';
import '../../prayer_engine/presentation/prayer_provider.dart' show tomorrowPrayerTimesProvider;
import '../data/temporal_calculator.dart';
import '../domain/arabic_period.dart';

// ── Sunrise / Sunset convenience providers ────────────────────────────────────

/// Extracts today's sunrise [DateTime] from [prayerTimesProvider].
///
/// Returns null while prayer times are loading or on error.
final _sunriseProvider = Provider<DateTime?>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);
    return timesAsync.when(
      data: (times) => times.sunrise.time,
      loading: () => null,
      error: (_, __) => null,
    );
  },
  name: '_sunriseProvider',
);

/// Extracts today's sunset [DateTime] from [prayerTimesProvider].
///
/// Returns null while prayer times are loading or on error.
final _sunsetProvider = Provider<DateTime?>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);
    return timesAsync.when(
      data: (times) => times.maghrib.time,
      loading: () => null,
      error: (_, __) => null,
    );
  },
  name: '_sunsetProvider',
);

/// Provides tomorrow's accurate sunrise by computing next-day prayer times
/// using the same location and calculation method as today.
final _tomorrowSunriseProvider = Provider<DateTime?>(
  (ref) {
    final tomorrowTimesAsync = ref.watch(tomorrowPrayerTimesProvider);
    return tomorrowTimesAsync.whenOrNull(
      data: (times) => times.sunrise.time,
    );
  },
  name: '_tomorrowSunriseProvider',
);

// ── Temporal data stream ──────────────────────────────────────────────────────

/// Emits a fresh [TemporalData] snapshot every second.
///
/// Returns [AsyncValue.loading] until sunrise/sunset data are available, and
/// [AsyncValue.error] if the prayer-times provider is in an error state.
///
/// The stream is automatically cancelled when all listeners unsubscribe and
/// re-created when a new listener attaches, so battery drain is minimal when
/// the watch face is not visible.
final temporalDataProvider = StreamProvider<TemporalData>(
  (ref) {
    final sunrise = ref.watch(_sunriseProvider);
    final sunset = ref.watch(_sunsetProvider);
    final nextSunrise = ref.watch(_tomorrowSunriseProvider);

    // Surface upstream errors / loading states as an empty stream so the
    // provider's AsyncValue stays in loading/error rather than emitting stale
    // data.
    if (sunrise == null || sunset == null || nextSunrise == null) {
      return const Stream.empty();
    }

    const calculator = TemporalCalculator();

    return Stream.periodic(const Duration(seconds: 1), (_) {
      return calculator.calculate(
        now: DateTime.now(),
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
    }).distinct(
      // Only propagate when something meaningful changed (period or progress
      // fraction rounded to 3 decimal places) to avoid unnecessary rebuilds.
      (previous, next) =>
          previous.currentPeriod == next.currentPeriod &&
          (previous.progressFraction - next.progressFraction).abs() < 0.001 &&
          previous.isDay == next.isDay,
    );
  },
  name: 'temporalDataProvider',
);

// ── Derived providers ─────────────────────────────────────────────────────────

/// The [ArabicPeriodSlot] that is currently active.
///
/// Consumers that only need the period metadata (name, colour, etc.) should
/// watch this instead of [temporalDataProvider] to avoid rebuilds on every
/// second tick.
final currentArabicPeriodProvider = Provider<AsyncValue<ArabicPeriodSlot>>(
  (ref) {
    return ref
        .watch(temporalDataProvider)
        .whenData((data) => data.currentPeriod);
  },
  name: 'currentArabicPeriodProvider',
);

/// The raw ring rotation angle in radians from [TemporalData.ringRotationAngle].
///
/// This value changes every second (fractional arc within the current segment).
/// Widgets that render the ring should apply an implicit animation (e.g.
/// [TweenAnimationBuilder] or [flutter_animate]) to interpolate smoothly
/// between consecutive values rather than jumping.
final ringRotationProvider = Provider<AsyncValue<double>>(
  (ref) {
    return ref
        .watch(temporalDataProvider)
        .whenData((data) => data.ringRotationAngle);
  },
  name: 'ringRotationProvider',
);

// ── Transition state ──────────────────────────────────────────────────────────

/// Tracks the current day/night [TransitionPhase] so the UI can gate
/// transition animations independently of the full [TemporalData] stream.
///
/// Derived automatically from [temporalDataProvider] and the sunrise/sunset
/// times.  Re-evaluated whenever the stream emits a new value (once per
/// second).  Widgets that want to react to phase changes (e.g. to trigger a
/// one-shot animation) should listen to this provider with [ref.listen].
final transitionStateProvider = Provider<TransitionPhase>(
  (ref) {
    final dataAsync = ref.watch(temporalDataProvider);
    final sunrise = ref.watch(_sunriseProvider);
    final sunset = ref.watch(_sunsetProvider);

    return dataAsync.when(
      data: (data) {
        if (sunrise == null || sunset == null) {
          return data.isDay ? TransitionPhase.day : TransitionPhase.night;
        }
        return resolveTransitionPhase(
          now: DateTime.now(),
          sunrise: sunrise,
          sunset: sunset,
        );
      },
      loading: () => TransitionPhase.day,
      error: (_, __) => TransitionPhase.day,
    );
  },
  name: 'transitionStateProvider',
);
