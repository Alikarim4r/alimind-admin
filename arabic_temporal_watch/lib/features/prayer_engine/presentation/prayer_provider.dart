// prayer_provider.dart
//
// Riverpod providers for the prayer engine.
//
// Provider graph
// ──────────────
//   prayerSettingsProvider (StateNotifierProvider<PrayerSettingsNotifier, PrayerSettings>)
//     └── drives prayerTimesProvider
//
//   locationProvider (from location feature — expected upstream)
//     └── drives prayerTimesProvider
//
//   prayerTimesProvider (Provider<AsyncValue<PrayerTimes>>)
//     ├── currentPrayerProvider
//     ├── nextPrayerProvider
//     ├── isPrayerTimeProvider
//     └── timeUntilNextPrayerProvider (StreamProvider — emits every second)
//
// All providers are family-free; location is consumed from a shared upstream
// provider.  Prayer settings are persisted via SharedPreferences through the
// PrayerSettingsNotifier.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart'
    show sharedPreferencesProvider, initialLocationPermissionProvider;
import '../data/prayer_calculator.dart';
import '../domain/prayer.dart';

// ── SharedPreferences keys ────────────────────────────────────────────────────

abstract final class _PrefKeys {
  static const String calculationMethod = 'prayer_calculation_method';
  static const String asrMethod = 'prayer_asr_method';
}

// ── PrayerSettings ────────────────────────────────────────────────────────────

/// Encapsulates all user-configurable prayer calculation preferences.
class PrayerSettings {
  const PrayerSettings({
    this.calculationMethod = CalculationMethod.ummAlQura,
    this.asrMethod = AsrMethod.standard,
  });

  final CalculationMethod calculationMethod;
  final AsrMethod asrMethod;

  /// Builds [PrayerCalculationParameters] for the current settings.
  PrayerCalculationParameters get parameters {
    switch (calculationMethod) {
      case CalculationMethod.ummAlQura:
        return PrayerCalculationParameters.ummAlQura(asrMethod: asrMethod);
      case CalculationMethod.muslimWorldLeague:
      case CalculationMethod.mwl:
        return PrayerCalculationParameters.muslimWorldLeague(
          asrMethod: asrMethod,
        );
      case CalculationMethod.qatar:
        return PrayerCalculationParameters.qatar(asrMethod: asrMethod);
      case CalculationMethod.egyptian:
        return PrayerCalculationParameters.egyptian(asrMethod: asrMethod);
      case CalculationMethod.karachi:
        return PrayerCalculationParameters.karachi(asrMethod: asrMethod);
    }
  }

  PrayerSettings copyWith({
    CalculationMethod? calculationMethod,
    AsrMethod? asrMethod,
  }) {
    return PrayerSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrMethod: asrMethod ?? this.asrMethod,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerSettings &&
          calculationMethod == other.calculationMethod &&
          asrMethod == other.asrMethod;

  @override
  int get hashCode => Object.hash(calculationMethod, asrMethod);

  @override
  String toString() =>
      'PrayerSettings(method: $calculationMethod, asr: $asrMethod)';
}

// ── PrayerSettingsNotifier ────────────────────────────────────────────────────

/// [StateNotifier] that persists prayer settings to [SharedPreferences].
///
/// On construction it restores previously saved values so settings survive
/// app restarts.
class PrayerSettingsNotifier extends StateNotifier<PrayerSettings> {
  PrayerSettingsNotifier(this._prefs) : super(const PrayerSettings()) {
    _restore();
  }

  final SharedPreferences _prefs;

  // ── Restore ─────────────────────────────────────────────────────────────────

  void _restore() {
    final methodIndex = _prefs.getInt(_PrefKeys.calculationMethod);
    final asrIndex = _prefs.getInt(_PrefKeys.asrMethod);

    final method = (methodIndex != null &&
            methodIndex >= 0 &&
            methodIndex < CalculationMethod.values.length)
        ? CalculationMethod.values[methodIndex]
        : CalculationMethod.ummAlQura;

    final asr = (asrIndex != null &&
            asrIndex >= 0 &&
            asrIndex < AsrMethod.values.length)
        ? AsrMethod.values[asrIndex]
        : AsrMethod.standard;

    state = PrayerSettings(calculationMethod: method, asrMethod: asr);
  }

  // ── Mutators ─────────────────────────────────────────────────────────────────

  /// Updates the calculation method and persists the choice.
  Future<void> setCalculationMethod(CalculationMethod method) async {
    state = state.copyWith(calculationMethod: method);
    await _prefs.setInt(
      _PrefKeys.calculationMethod,
      CalculationMethod.values.indexOf(method),
    );
  }

  /// Updates the Asr juristic method and persists the choice.
  Future<void> setAsrMethod(AsrMethod method) async {
    state = state.copyWith(asrMethod: method);
    await _prefs.setInt(
      _PrefKeys.asrMethod,
      AsrMethod.values.indexOf(method),
    );
  }
}

// ── Location helpers ──────────────────────────────────────────────────────────

/// Fetches the current device position.
///
/// Falls back to Makkah coordinates (21.3891°N, 39.8579°E) when location
/// permission is unavailable or the position fix fails.
Future<Position> _getPosition(LocationPermission permission) async {
  const fallbackLat = 21.3891;
  const fallbackLon = 39.8579;

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.unableToDetermine) {
    return Position(
      latitude: fallbackLat,
      longitude: fallbackLon,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
    );
  } catch (_) {
    return Position(
      latitude: fallbackLat,
      longitude: fallbackLon,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

// ── Provider declarations ─────────────────────────────────────────────────────

/// Exposes and persists [PrayerSettings].
///
/// Widgets and derived providers use this to read or change the active
/// calculation method and madhab.
final prayerSettingsProvider =
    StateNotifierProvider<PrayerSettingsNotifier, PrayerSettings>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return PrayerSettingsNotifier(prefs);
  },
  name: 'prayerSettingsProvider',
);

/// Asynchronously resolves the current device position.
///
/// Re-fetches whenever the initial permission status changes.  Caches the
/// result until the ref is invalidated (e.g. user grants permission later).
final _devicePositionProvider = FutureProvider<Position>(
  (ref) async {
    final permission = ref.watch(initialLocationPermissionProvider);
    return _getPosition(permission);
  },
  name: '_devicePositionProvider',
);

/// Computes [PrayerTimes] for today using the active settings and location.
///
/// Automatically recomputes when [prayerSettingsProvider] or the device
/// position changes.
final prayerTimesProvider = Provider<AsyncValue<PrayerTimes>>(
  (ref) {
    final positionAsync = ref.watch(_devicePositionProvider);
    final settings = ref.watch(prayerSettingsProvider);

    return positionAsync.when(
      data: (position) {
        const calculator = PrayerCalculator();
        final times = calculator.calculate(
          latitude: position.latitude,
          longitude: position.longitude,
          date: DateTime.now(),
          params: settings.parameters,
        );
        return AsyncValue.data(times);
      },
      loading: () => const AsyncValue.loading(),
      error: (err, stack) => AsyncValue.error(err, stack),
    );
  },
  name: 'prayerTimesProvider',
);

/// The prayer whose time window currently contains [DateTime.now()].
///
/// Returns `null` wrapped in [AsyncValue] when between prayers or while
/// prayer times are loading.
final currentPrayerProvider = Provider<AsyncValue<Prayer?>>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);
    return timesAsync.whenData((times) => times.currentPrayer(DateTime.now()));
  },
  name: 'currentPrayerProvider',
);

/// The next prayer after [DateTime.now()].
///
/// Returns `null` when Isha has already passed and no further prayers remain
/// for today.
final nextPrayerProvider = Provider<AsyncValue<Prayer?>>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);
    return timesAsync.whenData((times) => times.nextPrayer(DateTime.now()));
  },
  name: 'nextPrayerProvider',
);

/// Emits the remaining [Duration] until the next prayer, updating every second.
///
/// Completes with [Duration.zero] once no further prayers remain for today.
final timeUntilNextPrayerProvider = StreamProvider<Duration>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);

    return timesAsync.when(
      data: (times) => Stream.periodic(
        const Duration(seconds: 1),
        (_) => times.timeUntilNextPrayer(DateTime.now()),
      ).distinct(),
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
    );
  },
  name: 'timeUntilNextPrayerProvider',
);

/// True when [DateTime.now()] is within 3 minutes of any prayer time.
///
/// Suitable for triggering notifications, animations, or UI highlights.
final isPrayerTimeProvider = Provider<AsyncValue<bool>>(
  (ref) {
    final timesAsync = ref.watch(prayerTimesProvider);
    return timesAsync.whenData(
      (times) => times.isPrayerTime(DateTime.now()),
    );
  },
  name: 'isPrayerTimeProvider',
);

/// Computes [PrayerTimes] for tomorrow (today + 1 day) using the same
/// location and settings as today.
///
/// Used by the temporal engine to get tomorrow's accurate sunrise time
/// instead of the approximation today + 24 h.
final tomorrowPrayerTimesProvider = Provider<AsyncValue<PrayerTimes>>(
  (ref) {
    final positionAsync = ref.watch(_devicePositionProvider);
    final settings = ref.watch(prayerSettingsProvider);

    return positionAsync.when(
      data: (position) {
        const calculator = PrayerCalculator();
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final times = calculator.calculate(
          latitude: position.latitude,
          longitude: position.longitude,
          date: tomorrow,
          params: settings.parameters,
        );
        return AsyncValue.data(times);
      },
      loading: () => const AsyncValue.loading(),
      error: (err, stack) => AsyncValue.error(err, stack),
    );
  },
  name: 'tomorrowPrayerTimesProvider',
);
