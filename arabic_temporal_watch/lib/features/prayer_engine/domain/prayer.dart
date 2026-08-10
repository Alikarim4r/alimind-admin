// prayer.dart
//
// Domain models for the prayer engine.  Covers the five daily prayers plus
// Sunrise, the two primary calculation paradigms (angle-based vs. fixed
// post-Maghrib minutes for Isha), and helper accessors that the presentation
// layer consumes.

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

// ── Enumerations ─────────────────────────────────────────────────────────────

/// The six canonical Islamic prayer markers, in chronological order.
enum PrayerName {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

/// Supported prayer-time calculation methods with their associated fiqh
/// authorities and geographic calibrations.
enum CalculationMethod {
  /// Umm Al-Qura University, Makkah — Fajr 18.5°, Isha 90 min after Maghrib.
  ummAlQura,

  /// Muslim World League — Fajr 18°, Isha 17°.
  muslimWorldLeague,

  /// Diwan Al-Awqaf, Qatar — Fajr 18°, Isha 90 min after Maghrib.
  qatar,

  /// Egyptian General Authority of Survey — Fajr 19.5°, Isha 17.5°.
  egyptian,

  /// University of Islamic Sciences, Karachi — Fajr 18°, Isha 18°.
  karachi,

  /// Alias kept for backwards compatibility.
  mwl,
}

/// Juristic method for computing the Asr shadow length.
enum AsrMethod {
  /// Shafi'i / Maliki / Hanbali: shadow ratio = 1 (shadow equals object height
  /// added to the noon shadow).
  standard,

  /// Hanafi: shadow ratio = 2 (double the object height added to noon shadow).
  hanafi,
}

// ── Prayer display metadata ───────────────────────────────────────────────────

/// Static display metadata for each [PrayerName].
class _PrayerMeta {
  const _PrayerMeta({
    required this.arabicName,
    required this.transliteration,
    required this.color,
    required this.icon,
  });

  final String arabicName;
  final String transliteration;
  final Color color;
  final IconData icon;
}

const Map<PrayerName, _PrayerMeta> _prayerMeta = {
  PrayerName.fajr: _PrayerMeta(
    arabicName: 'الفجر',
    transliteration: 'Fajr',
    color: Color(0xFF5B7FA6), // pre-dawn blue
    icon: Icons.brightness_3,
  ),
  PrayerName.sunrise: _PrayerMeta(
    arabicName: 'الشروق',
    transliteration: 'Shuruq',
    color: Color(0xFFE8A838), // golden sunrise
    icon: Icons.wb_sunny_outlined,
  ),
  PrayerName.dhuhr: _PrayerMeta(
    arabicName: 'الظهر',
    transliteration: 'Dhuhr',
    color: Color(0xFFF5D76E), // midday gold
    icon: Icons.wb_sunny,
  ),
  PrayerName.asr: _PrayerMeta(
    arabicName: 'العصر',
    transliteration: 'Asr',
    color: Color(0xFFE07B39), // afternoon amber
    icon: Icons.wb_twilight,
  ),
  PrayerName.maghrib: _PrayerMeta(
    arabicName: 'المغرب',
    transliteration: "Maghrib",
    color: Color(0xFFB8496B), // sunset rose
    icon: Icons.nights_stay_outlined,
  ),
  PrayerName.isha: _PrayerMeta(
    arabicName: 'العشاء',
    transliteration: "Isha'",
    color: Color(0xFF3A3F7A), // night indigo
    icon: Icons.star_border,
  ),
};

// ── Prayer ────────────────────────────────────────────────────────────────────

/// A single prayer with its computed local time and display metadata.
class Prayer extends Equatable {
  const Prayer({
    required this.name,
    required this.time,
  });

  final PrayerName name;

  /// Local [DateTime] for this prayer on the day it was computed.
  final DateTime time;

  // ── Display metadata (derived from [name]) ──────────────────────────────────

  String get arabicName => _prayerMeta[name]!.arabicName;
  String get transliteration => _prayerMeta[name]!.transliteration;
  Color get color => _prayerMeta[name]!.color;
  IconData get icon => _prayerMeta[name]!.icon;

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [name, time];

  @override
  String toString() => 'Prayer($transliteration @ $time)';

  Prayer copyWith({PrayerName? name, DateTime? time}) => Prayer(
        name: name ?? this.name,
        time: time ?? this.time,
      );
}

// ── PrayerTimes ───────────────────────────────────────────────────────────────

/// Immutable container holding the six computed prayer times for a single day
/// at a specific geographic location.
class PrayerTimes extends Equatable {
  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  final Prayer fajr;
  final Prayer sunrise;
  final Prayer dhuhr;
  final Prayer asr;
  final Prayer maghrib;
  final Prayer isha;

  /// The calendar date for which times were calculated (local midnight).
  final DateTime date;

  /// Observer latitude in decimal degrees (positive = North).
  final double latitude;

  /// Observer longitude in decimal degrees (positive = East).
  final double longitude;

  // ── Convenience list ────────────────────────────────────────────────────────

  /// All six prayers in chronological order.
  List<Prayer> get all => [fajr, sunrise, dhuhr, asr, maghrib, isha];

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the prayer whose time window contains [now], or null if we are
  /// between prayers.  The window for a prayer ends when the next one begins.
  Prayer? currentPrayer(DateTime now) {
    final ordered = all;
    for (int i = 0; i < ordered.length; i++) {
      final start = ordered[i].time;
      final end = (i + 1 < ordered.length)
          ? ordered[i + 1].time
          : ordered[i].time.add(const Duration(hours: 2)); // Isha window
      if (!now.isBefore(start) && now.isBefore(end)) {
        return ordered[i];
      }
    }
    return null;
  }

  /// Returns the next prayer after [now], or null if [isha] has already passed.
  Prayer? nextPrayer(DateTime now) {
    for (final prayer in all) {
      if (prayer.time.isAfter(now)) return prayer;
    }
    return null;
  }

  /// Remaining time until the next prayer after [now].
  /// Returns [Duration.zero] if there is no next prayer today.
  Duration timeUntilNextPrayer(DateTime now) {
    final next = nextPrayer(now);
    if (next == null) return Duration.zero;
    final diff = next.time.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Returns true when [now] falls within [tolerance] of any prayer time.
  bool isPrayerTime(
    DateTime now, {
    Duration tolerance = const Duration(minutes: 3),
  }) {
    for (final prayer in all) {
      final diff = now.difference(prayer.time).abs();
      if (diff <= tolerance) return true;
    }
    return false;
  }

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        fajr,
        sunrise,
        dhuhr,
        asr,
        maghrib,
        isha,
        date,
        latitude,
        longitude,
      ];

  @override
  String toString() =>
      'PrayerTimes(date: ${date.toIso8601String()}, '
      'lat: $latitude, lon: $longitude)';
}

// ── PrayerCalculationParameters ───────────────────────────────────────────────

/// Encapsulates the angular and juristic parameters that govern a particular
/// prayer-time calculation method.
class PrayerCalculationParameters extends Equatable {
  const PrayerCalculationParameters({
    required this.fajrAngle,
    required this.ishaAngle,
    this.ishaMinutes,
    required this.method,
    this.asrMethod = AsrMethod.standard,
  }) : assert(
          ishaAngle >= 0 || ishaMinutes != null,
          'Provide either ishaAngle or ishaMinutes',
        );

  /// Sun depression angle below the horizon at Fajr (positive degrees).
  final double fajrAngle;

  /// Sun depression angle below the horizon at Isha (positive degrees).
  /// Ignored when [ishaMinutes] is set.
  final double ishaAngle;

  /// Fixed minutes after Maghrib for Isha.  When non-null, [ishaAngle] is
  /// not used.
  final int? ishaMinutes;

  /// The authority whose parameters are encoded here.
  final CalculationMethod method;

  /// The juristic school determining Asr shadow-length ratio.
  final AsrMethod asrMethod;

  // ── Named constructors for each standard method ──────────────────────────────

  factory PrayerCalculationParameters.ummAlQura({
    AsrMethod asrMethod = AsrMethod.standard,
  }) =>
      PrayerCalculationParameters(
        fajrAngle: 18.5,
        ishaAngle: 0, // unused — fixed minutes used instead
        ishaMinutes: 90,
        method: CalculationMethod.ummAlQura,
        asrMethod: asrMethod,
      );

  factory PrayerCalculationParameters.muslimWorldLeague({
    AsrMethod asrMethod = AsrMethod.standard,
  }) =>
      PrayerCalculationParameters(
        fajrAngle: 18.0,
        ishaAngle: 17.0,
        method: CalculationMethod.muslimWorldLeague,
        asrMethod: asrMethod,
      );

  factory PrayerCalculationParameters.qatar({
    AsrMethod asrMethod = AsrMethod.standard,
  }) =>
      PrayerCalculationParameters(
        fajrAngle: 18.0,
        ishaAngle: 0, // unused
        ishaMinutes: 90,
        method: CalculationMethod.qatar,
        asrMethod: asrMethod,
      );

  factory PrayerCalculationParameters.egyptian({
    AsrMethod asrMethod = AsrMethod.standard,
  }) =>
      PrayerCalculationParameters(
        fajrAngle: 19.5,
        ishaAngle: 17.5,
        method: CalculationMethod.egyptian,
        asrMethod: asrMethod,
      );

  factory PrayerCalculationParameters.karachi({
    AsrMethod asrMethod = AsrMethod.standard,
  }) =>
      PrayerCalculationParameters(
        fajrAngle: 18.0,
        ishaAngle: 18.0,
        method: CalculationMethod.karachi,
        asrMethod: asrMethod,
      );

  // ── Equatable ───────────────────────────────────────────────────────────────

  @override
  List<Object?> get props =>
      [fajrAngle, ishaAngle, ishaMinutes, method, asrMethod];
}
