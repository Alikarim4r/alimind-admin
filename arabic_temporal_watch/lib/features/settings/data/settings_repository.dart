// settings_repository.dart
//
// Persists and restores [AppSettings] to/from [SharedPreferences].
//
// Design notes
// ────────────
//   • All keys are private constants to avoid typos and guard against external
//     mutation.
//   • Enum values are stored by their integer index so the key space remains
//     compact.  Index-stability must be maintained when adding new enum values
//     — always append, never reorder.
//   • Locale is stored as a language-tag string (e.g. "ar-SA").
//   • [load] returns [defaults] for any key that is absent so the very first
//     run works correctly without an explicit migration step.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../prayer_engine/domain/prayer.dart'
    show CalculationMethod, AsrMethod;
import '../domain/settings_model.dart';

// ── Preference keys ───────────────────────────────────────────────────────────

abstract final class _Keys {
  static const String prayerMethod      = 'settings_prayer_method';
  static const String asrMethod         = 'settings_asr_method';
  static const String watchMode         = 'settings_watch_mode';
  static const String showSeconds       = 'settings_show_seconds';
  static const String use24Hour         = 'settings_use_24_hour';
  static const String showTranslit      = 'settings_show_transliteration';
  static const String enableVibration   = 'settings_enable_vibration';
  static const String keepScreenOn      = 'settings_keep_screen_on';
  static const String showMinuteBeads   = 'settings_show_minute_beads';
  static const String showPrayerArc     = 'settings_show_prayer_arc';
  static const String appLocale         = 'settings_app_locale';
}

// ── SettingsRepository ────────────────────────────────────────────────────────

/// Reads and writes [AppSettings] through [SharedPreferences].
///
/// Instantiate with a pre-loaded [SharedPreferences] instance (available from
/// the root [sharedPreferencesProvider] in main.dart).
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  // ── Defaults ────────────────────────────────────────────────────────────────

  /// Factory defaults returned when no persisted settings are found.
  AppSettings get defaults => const AppSettings();

  // ── Load ────────────────────────────────────────────────────────────────────

  /// Loads [AppSettings] from [SharedPreferences].
  ///
  /// Any missing key falls back to the corresponding field from [defaults].
  Future<AppSettings> load() async {
    final d = defaults;

    final prayerIdx  = _prefs.getInt(_Keys.prayerMethod);
    final asrIdx     = _prefs.getInt(_Keys.asrMethod);
    final modeIdx    = _prefs.getInt(_Keys.watchMode);
    final localeTag  = _prefs.getString(_Keys.appLocale);

    return AppSettings(
      prayerMethod: _enumFromIndex(
        CalculationMethod.values,
        prayerIdx,
        d.prayerMethod,
      ),
      asrMethod: _enumFromIndex(
        AsrMethod.values,
        asrIdx,
        d.asrMethod,
      ),
      watchMode: _enumFromIndex(
        WatchMode.values,
        modeIdx,
        d.watchMode,
      ),
      showSeconds:       _prefs.getBool(_Keys.showSeconds)     ?? d.showSeconds,
      use24Hour:         _prefs.getBool(_Keys.use24Hour)        ?? d.use24Hour,
      showTransliteration:
          _prefs.getBool(_Keys.showTranslit) ?? d.showTransliteration,
      enableVibration:   _prefs.getBool(_Keys.enableVibration) ?? d.enableVibration,
      keepScreenOn:      _prefs.getBool(_Keys.keepScreenOn)    ?? d.keepScreenOn,
      showMinuteBeads:   _prefs.getBool(_Keys.showMinuteBeads) ?? d.showMinuteBeads,
      showPrayerArc:     _prefs.getBool(_Keys.showPrayerArc)   ?? d.showPrayerArc,
      appLocale: localeTag != null
          ? _parseLocale(localeTag)
          : d.appLocale,
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Persists [settings] to [SharedPreferences].
  ///
  /// All writes are fire-and-forget via the async SharedPreferences API; the
  /// futures are awaited to ensure data reaches the disk before the function
  /// returns (important for settings that must survive an immediate app kill).
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setInt(
          _Keys.prayerMethod,
          CalculationMethod.values.indexOf(settings.prayerMethod)),
      _prefs.setInt(
          _Keys.asrMethod,
          AsrMethod.values.indexOf(settings.asrMethod)),
      _prefs.setInt(
          _Keys.watchMode,
          WatchMode.values.indexOf(settings.watchMode)),
      _prefs.setBool(_Keys.showSeconds, settings.showSeconds),
      _prefs.setBool(_Keys.use24Hour, settings.use24Hour),
      _prefs.setBool(_Keys.showTranslit, settings.showTransliteration),
      _prefs.setBool(_Keys.enableVibration, settings.enableVibration),
      _prefs.setBool(_Keys.keepScreenOn, settings.keepScreenOn),
      _prefs.setBool(_Keys.showMinuteBeads, settings.showMinuteBeads),
      _prefs.setBool(_Keys.showPrayerArc, settings.showPrayerArc),
      _prefs.setString(_Keys.appLocale, settings.appLocale.toLanguageTag()),
    ]);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Returns the enum value at [index], or [fallback] when the index is null
  /// or out of range.
  static T _enumFromIndex<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  /// Parses a BCP-47 language tag such as "ar-SA" back to a [Locale].
  static Locale _parseLocale(String tag) {
    final parts = tag.split('-');
    if (parts.length >= 2) return Locale(parts[0], parts[1]);
    return Locale(parts[0]);
  }
}
