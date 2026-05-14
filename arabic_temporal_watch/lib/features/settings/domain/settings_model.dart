// settings_model.dart
//
// Domain model for all user-configurable application settings.
//
// Design notes
// ────────────
//   • [AppSettings] is immutable.  All mutations go through [SettingsNotifier]
//     which applies copyWith and persists to SharedPreferences.
//   • [WatchMode] mirrors and supersedes the identically named enum in
//     clock_face_painter.dart for the settings layer; the presentation layer is
//     responsible for mapping one to the other when constructing painters.
//   • Locales are represented as [Locale] objects so the app can be handed
//     directly to MaterialApp.locale without conversion.

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../prayer_engine/domain/prayer.dart'
    show CalculationMethod, AsrMethod;

// ── WatchMode ─────────────────────────────────────────────────────────────────

/// Controls the primary visual style rendered on the watch face.
///
/// Each mode emphasises different layers of the watch face stack; the painter
/// layer consults this value to decide which CustomPaint layers to draw and at
/// what opacity.
enum WatchMode {
  /// Default mode — full analog dial with the 24-period ring overlaid.
  /// Both the Swiss-style dial and Arabic ring are rendered at full opacity.
  hybrid,

  /// Maximises the Arabic rotating ring; the analog dial is hidden or very
  /// faint.  Period names and colours dominate the face.
  fullArabic,

  /// Emphasis on the astronomical sky background.  The background painter is
  /// promoted and the dial becomes semi-transparent so the sky shows through.
  astronomical,

  /// Stripped-back display: ring + hands, no numerals, no unnecessary glows.
  /// Ideal for low-distraction reading.
  minimal,
}

// ── AppSettings ───────────────────────────────────────────────────────────────

/// Immutable holder for every user-configurable setting in the app.
///
/// Persisted to [SharedPreferences] through [SettingsRepository].
/// Consumed application-wide via [settingsProvider].
class AppSettings extends Equatable {
  const AppSettings({
    this.prayerMethod = CalculationMethod.ummAlQura,
    this.asrMethod = AsrMethod.standard,
    this.watchMode = WatchMode.hybrid,
    this.showSeconds = true,
    this.use24Hour = false,
    this.showTransliteration = true,
    this.enableVibration = true,
    this.keepScreenOn = true,
    this.showMinuteBeads = true,
    this.showPrayerArc = true,
    this.appLocale = const Locale('ar', 'SA'),
  });

  // ── Prayer calculation ──────────────────────────────────────────────────────

  /// The authority / methodology used to calculate prayer times.
  final CalculationMethod prayerMethod;

  /// The juristic school used to compute the Asr shadow ratio.
  final AsrMethod asrMethod;

  // ── Display ─────────────────────────────────────────────────────────────────

  /// Overall watch face visual style.
  final WatchMode watchMode;

  /// Whether the seconds hand and second-level countdown digits are shown.
  final bool showSeconds;

  /// When true, time is displayed in 24-hour format.  When false, 12-hour.
  final bool use24Hour;

  /// Whether to show the Latin transliteration below Arabic period names.
  final bool showTransliteration;

  // ── Accessibility ───────────────────────────────────────────────────────────

  /// Whether haptic feedback is given at prayer time and period transitions.
  final bool enableVibration;

  /// Whether to request a wakelock so the screen stays on while the watch face
  /// is visible.
  final bool keepScreenOn;

  // ── Ring overlays ───────────────────────────────────────────────────────────

  /// Whether to render the minute-bead dots along each ring segment arc.
  final bool showMinuteBeads;

  /// Whether to overlay the prayer-time arc on the ring.
  final bool showPrayerArc;

  // ── Localisation ────────────────────────────────────────────────────────────

  /// The locale used for all in-app text.  Supported: ar-SA, en-US.
  final Locale appLocale;

  // ── copyWith ────────────────────────────────────────────────────────────────

  AppSettings copyWith({
    CalculationMethod? prayerMethod,
    AsrMethod? asrMethod,
    WatchMode? watchMode,
    bool? showSeconds,
    bool? use24Hour,
    bool? showTransliteration,
    bool? enableVibration,
    bool? keepScreenOn,
    bool? showMinuteBeads,
    bool? showPrayerArc,
    Locale? appLocale,
  }) {
    return AppSettings(
      prayerMethod: prayerMethod ?? this.prayerMethod,
      asrMethod: asrMethod ?? this.asrMethod,
      watchMode: watchMode ?? this.watchMode,
      showSeconds: showSeconds ?? this.showSeconds,
      use24Hour: use24Hour ?? this.use24Hour,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      enableVibration: enableVibration ?? this.enableVibration,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showMinuteBeads: showMinuteBeads ?? this.showMinuteBeads,
      showPrayerArc: showPrayerArc ?? this.showPrayerArc,
      appLocale: appLocale ?? this.appLocale,
    );
  }

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        prayerMethod,
        asrMethod,
        watchMode,
        showSeconds,
        use24Hour,
        showTransliteration,
        enableVibration,
        keepScreenOn,
        showMinuteBeads,
        showPrayerArc,
        appLocale,
      ];

  @override
  String toString() => 'AppSettings('
      'mode: $watchMode, '
      'method: $prayerMethod, '
      'locale: ${appLocale.toLanguageTag()}'
      ')';
}
