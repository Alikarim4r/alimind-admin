// settings_provider.dart
//
// Riverpod provider for application settings.
//
// Provider graph
// ──────────────
//   sharedPreferencesProvider (from main.dart) — injected at startup
//     └── _settingsRepositoryProvider  (Provider<SettingsRepository>)
//           └── settingsProvider  (StateNotifierProvider<SettingsNotifier, AppSettings>)
//
// Design notes
// ────────────
//   • [SettingsNotifier] loads saved settings asynchronously in its constructor
//     using _restore().  Until the restore completes, the state holds factory
//     defaults so the UI is never blocked on startup.
//   • Every mutator calls [SettingsRepository.save] after updating state, so
//     changes are durable even when the app is killed immediately after.
//   • Expose individual convenience updaters (setWatchMode, setPrayerMethod,
//     etc.) rather than a raw copyWith-and-save pattern so callers have a clear
//     public contract and the repository call site is centralised.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart' show sharedPreferencesProvider;
import '../../prayer_engine/domain/prayer.dart'
    show CalculationMethod, AsrMethod;
import '../data/settings_repository.dart';
import '../domain/settings_model.dart';

// ── Internal repository provider ──────────────────────────────────────────────

/// Creates a [SettingsRepository] backed by the pre-loaded SharedPreferences.
final _settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsRepository(prefs);
  },
  name: '_settingsRepositoryProvider',
);

// ── SettingsNotifier ──────────────────────────────────────────────────────────

/// [StateNotifier] that holds the current [AppSettings] and persists every
/// change to [SharedPreferences] through [SettingsRepository].
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repository) : super(const AppSettings()) {
    _restore();
  }

  final SettingsRepository _repository;

  // ── Init ────────────────────────────────────────────────────────────────────

  /// Asynchronously loads previously saved settings and updates state.
  ///
  /// Called once at construction.  Until completion the notifier holds factory
  /// defaults which is a safe and visually consistent starting point.
  Future<void> _restore() async {
    final saved = await _repository.load();
    if (mounted) state = saved;
  }

  // ── Prayer calculation ──────────────────────────────────────────────────────

  Future<void> setPrayerMethod(CalculationMethod method) async {
    state = state.copyWith(prayerMethod: method);
    await _repository.save(state);
  }

  Future<void> setAsrMethod(AsrMethod method) async {
    state = state.copyWith(asrMethod: method);
    await _repository.save(state);
  }

  // ── Display ─────────────────────────────────────────────────────────────────

  Future<void> setWatchMode(WatchMode mode) async {
    state = state.copyWith(watchMode: mode);
    await _repository.save(state);
  }

  Future<void> setShowSeconds(bool value) async {
    state = state.copyWith(showSeconds: value);
    await _repository.save(state);
  }

  Future<void> setUse24Hour(bool value) async {
    state = state.copyWith(use24Hour: value);
    await _repository.save(state);
  }

  Future<void> setShowTransliteration(bool value) async {
    state = state.copyWith(showTransliteration: value);
    await _repository.save(state);
  }

  // ── Ring overlays ───────────────────────────────────────────────────────────

  Future<void> setShowMinuteBeads(bool value) async {
    state = state.copyWith(showMinuteBeads: value);
    await _repository.save(state);
  }

  Future<void> setShowPrayerArc(bool value) async {
    state = state.copyWith(showPrayerArc: value);
    await _repository.save(state);
  }

  // ── Accessibility ───────────────────────────────────────────────────────────

  Future<void> setEnableVibration(bool value) async {
    state = state.copyWith(enableVibration: value);
    await _repository.save(state);
  }

  Future<void> setKeepScreenOn(bool value) async {
    state = state.copyWith(keepScreenOn: value);
    await _repository.save(state);
  }

  // ── Localisation ────────────────────────────────────────────────────────────

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(appLocale: locale);
    await _repository.save(state);
  }

  // ── Bulk reset ──────────────────────────────────────────────────────────────

  /// Resets all settings to factory defaults and persists the reset state.
  Future<void> resetToDefaults() async {
    state = _repository.defaults;
    await _repository.save(state);
  }
}

// ── Public provider ────────────────────────────────────────────────────────────

/// The primary settings provider consumed by all settings-aware widgets.
///
/// Usage:
/// ```dart
/// // Read current settings
/// final settings = ref.watch(settingsProvider);
///
/// // Update a single field
/// ref.read(settingsProvider.notifier).setWatchMode(WatchMode.fullArabic);
/// ```
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) {
    final repo = ref.watch(_settingsRepositoryProvider);
    return SettingsNotifier(repo);
  },
  name: 'settingsProvider',
);
