// astronomical_data.dart
//
// Aggregate domain model that bundles every piece of astronomical data
// computed for a single observer position at a single calendar date.
//
// Clean-architecture note: this is a pure-Dart value object with no
// Flutter/platform dependencies.  The data/ layer populates it; the
// presentation/ layer consumes it.

import 'package:equatable/equatable.dart';
import 'solar_event.dart';

// ---------------------------------------------------------------------------
// SkyState
// ---------------------------------------------------------------------------

/// Describes the ambient light condition implied by the current solar altitude.
///
/// Altitude thresholds follow IAU / USNO conventions:
///   altitude ≥  −0.8333°  →  Day
///   −6°  ≤ altitude < −0.8333°  →  CivilTwilight
///   −12° ≤ altitude < −6°       →  NauticalTwilight
///   −18° ≤ altitude < −12°      →  AstronomicalTwilight
///   altitude < −18°             →  Night
enum SkyState {
  /// Sun is fully above the effective horizon.  Normal daylight.
  day,

  /// Sun between −0.8333° and −6°.  Enough light for most outdoor tasks.
  civilTwilight,

  /// Sun between −6° and −12°.  Sea horizon still visible to naked eye.
  nauticalTwilight,

  /// Sun between −12° and −18°.  Faint glow on horizon; deep-sky objects
  /// become visible.
  astronomicalTwilight,

  /// Sun below −18°.  True astronomical darkness.
  night,
}

/// Extension providing display labels and ordering for [SkyState].
extension SkyStateX on SkyState {
  String get label {
    switch (this) {
      case SkyState.day:
        return 'Day';
      case SkyState.civilTwilight:
        return 'Civil Twilight';
      case SkyState.nauticalTwilight:
        return 'Nautical Twilight';
      case SkyState.astronomicalTwilight:
        return 'Astronomical Twilight';
      case SkyState.night:
        return 'Night';
    }
  }

  /// Normalised brightness index: 1.0 = full day, 0.0 = deep night.
  double get brightnessIndex {
    switch (this) {
      case SkyState.day:
        return 1.0;
      case SkyState.civilTwilight:
        return 0.65;
      case SkyState.nauticalTwilight:
        return 0.35;
      case SkyState.astronomicalTwilight:
        return 0.15;
      case SkyState.night:
        return 0.0;
    }
  }

  bool get isDark =>
      this == SkyState.night || this == SkyState.astronomicalTwilight;
}

// ---------------------------------------------------------------------------
// TwilightType
// ---------------------------------------------------------------------------

/// Selects which twilight band to compute a rise/set time for.
enum TwilightType {
  /// −6° depression.
  civil,

  /// −12° depression.
  nautical,

  /// −18° depression.
  astronomical,
}

extension TwilightTypeX on TwilightType {
  /// Altitude (degrees) that defines the start/end of this twilight band.
  double get depressionAngle {
    switch (this) {
      case TwilightType.civil:
        return -6.0;
      case TwilightType.nautical:
        return -12.0;
      case TwilightType.astronomical:
        return -18.0;
    }
  }
}

// ---------------------------------------------------------------------------
// SolarData
// ---------------------------------------------------------------------------

/// All solar timing data for one day at one location.
class SolarData extends Equatable {
  const SolarData({
    required this.sunrise,
    required this.sunset,
    required this.solarNoon,
    required this.dayLengthSeconds,
    this.civilDawn,
    this.civilDusk,
    this.nauticalDawn,
    this.nauticalDusk,
    this.astronomicalDawn,
    this.astronomicalDusk,
  });

  /// Time of sunrise (upper-limb crossing, standard refraction applied).
  /// Null when the sun never rises (polar night) on this date.
  final DateTime? sunrise;

  /// Time of sunset.  Null during polar day/night.
  final DateTime? sunset;

  /// Time of solar transit (meridian crossing).  Always non-null.
  final DateTime solarNoon;

  /// Length of the sunlit period in seconds (0 during polar night,
  /// 86400 during midnight sun).
  final int dayLengthSeconds;

  // Twilight times – null when the sun stays below/above the threshold all day.
  final DateTime? civilDawn;
  final DateTime? civilDusk;
  final DateTime? nauticalDawn;
  final DateTime? nauticalDusk;
  final DateTime? astronomicalDawn;
  final DateTime? astronomicalDusk;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Day length as a [Duration].
  Duration get dayLength => Duration(seconds: dayLengthSeconds);

  /// True when the sun never sets on this date at this location.
  bool get isPolarDay => sunrise == null && sunset == null && dayLengthSeconds == 86400;

  /// True when the sun never rises on this date at this location.
  bool get isPolarNight => sunrise == null && sunset == null && dayLengthSeconds == 0;

  @override
  List<Object?> get props => [
        sunrise,
        sunset,
        solarNoon,
        dayLengthSeconds,
        civilDawn,
        civilDusk,
        nauticalDawn,
        nauticalDusk,
        astronomicalDawn,
        astronomicalDusk,
      ];

  SolarData copyWith({
    DateTime? sunrise,
    DateTime? sunset,
    DateTime? solarNoon,
    int? dayLengthSeconds,
    DateTime? civilDawn,
    DateTime? civilDusk,
    DateTime? nauticalDawn,
    DateTime? nauticalDusk,
    DateTime? astronomicalDawn,
    DateTime? astronomicalDusk,
  }) {
    return SolarData(
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      solarNoon: solarNoon ?? this.solarNoon,
      dayLengthSeconds: dayLengthSeconds ?? this.dayLengthSeconds,
      civilDawn: civilDawn ?? this.civilDawn,
      civilDusk: civilDusk ?? this.civilDusk,
      nauticalDawn: nauticalDawn ?? this.nauticalDawn,
      nauticalDusk: nauticalDusk ?? this.nauticalDusk,
      astronomicalDawn: astronomicalDawn ?? this.astronomicalDawn,
      astronomicalDusk: astronomicalDusk ?? this.astronomicalDusk,
    );
  }
}

// ---------------------------------------------------------------------------
// MoonData
// ---------------------------------------------------------------------------

/// Lunar data for a given moment.
class MoonData extends Equatable {
  const MoonData({
    required this.phase,
    required this.illumination,
    this.moonrise,
    this.moonset,
  });

  /// Lunar phase as a fraction of the synodic month.
  ///   0.00 = New Moon
  ///   0.25 = First Quarter
  ///   0.50 = Full Moon
  ///   0.75 = Last Quarter
  ///   1.00 = New Moon (next cycle)
  final double phase;

  /// Fraction of the lunar disc illuminated, in the range [0.0, 1.0].
  final double illumination;

  /// UTC time of moonrise for the calendar day, or null when the moon
  /// does not rise on this date (possible at extreme latitudes).
  final DateTime? moonrise;

  /// UTC time of moonset, or null when the moon does not set today.
  final DateTime? moonset;

  // ---------------------------------------------------------------------------
  // Phase name helpers
  // ---------------------------------------------------------------------------

  /// Conventional English name for the current phase.
  String get phaseName {
    if (phase < 0.0625 || phase >= 0.9375) return 'New Moon';
    if (phase < 0.1875) return 'Waxing Crescent';
    if (phase < 0.3125) return 'First Quarter';
    if (phase < 0.4375) return 'Waxing Gibbous';
    if (phase < 0.5625) return 'Full Moon';
    if (phase < 0.6875) return 'Waning Gibbous';
    if (phase < 0.8125) return 'Last Quarter';
    return 'Waning Crescent';
  }

  /// Illumination as a percentage string, e.g. "73%".
  String get illuminationPercent =>
      '${(illumination * 100).round()}%';

  @override
  List<Object?> get props => [phase, illumination, moonrise, moonset];

  MoonData copyWith({
    double? phase,
    double? illumination,
    DateTime? moonrise,
    DateTime? moonset,
  }) {
    return MoonData(
      phase: phase ?? this.phase,
      illumination: illumination ?? this.illumination,
      moonrise: moonrise ?? this.moonrise,
      moonset: moonset ?? this.moonset,
    );
  }
}

// ---------------------------------------------------------------------------
// AtmosphericData
// ---------------------------------------------------------------------------

/// Real-time positional data for the sun as seen from the observer.
///
/// All angles in degrees unless otherwise noted.
class AtmosphericData extends Equatable {
  const AtmosphericData({
    required this.solarAltitude,
    required this.solarAzimuth,
    required this.hourAngle,
    required this.observedAt,
  });

  /// Geometric altitude of the sun's centre above the mathematical horizon.
  /// Positive values = above horizon.  Does NOT include atmospheric refraction
  /// correction (the engine methods apply refraction separately when needed
  /// for rise/set computations).
  final double solarAltitude;

  /// True azimuth of the sun, measured clockwise from geographic North.
  /// Range: [0°, 360°).
  final double solarAzimuth;

  /// Local hour angle of the sun in degrees.
  ///   Negative = east of meridian (morning)
  ///   Zero     = solar noon
  ///   Positive = west of meridian (afternoon)
  final double hourAngle;

  /// The UTC instant these values were computed for.
  final DateTime observedAt;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// True when the sun's geometric centre is above the mathematical horizon.
  bool get isSunAboveHorizon => solarAltitude > 0;

  /// True when refraction-corrected sun is visible (upper limb above effective
  /// horizon, accounting for −0.8333° standard depression).
  bool get isSunVisible => solarAltitude > -0.8333;

  /// Compass cardinal point closest to the solar azimuth.
  String get cardinalDirection {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    return directions[((solarAzimuth + 22.5) / 45).floor() % 8];
  }

  @override
  List<Object?> get props =>
      [solarAltitude, solarAzimuth, hourAngle, observedAt];

  AtmosphericData copyWith({
    double? solarAltitude,
    double? solarAzimuth,
    double? hourAngle,
    DateTime? observedAt,
  }) {
    return AtmosphericData(
      solarAltitude: solarAltitude ?? this.solarAltitude,
      solarAzimuth: solarAzimuth ?? this.solarAzimuth,
      hourAngle: hourAngle ?? this.hourAngle,
      observedAt: observedAt ?? this.observedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// AstronomicalData  (aggregate root)
// ---------------------------------------------------------------------------

/// The complete output of one engine calculation pass for a given
/// (latitude, longitude, date) triple.
///
/// Designed as an immutable value object; use [copyWith] when the
/// real-time [atmospheric] sub-model updates on a short timer.
class AstronomicalData extends Equatable {
  const AstronomicalData({
    required this.solar,
    required this.moon,
    required this.atmospheric,
    required this.skyState,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.events,
  });

  /// Static solar timing data (computed once per day).
  final SolarData solar;

  /// Lunar data (computed once per day or on-demand for real-time).
  final MoonData moon;

  /// Real-time solar position (updated every few seconds by the provider).
  final AtmosphericData atmospheric;

  /// Current ambient sky condition derived from [atmospheric.solarAltitude].
  final SkyState skyState;

  /// Observer latitude in decimal degrees (North positive).
  final double latitude;

  /// Observer longitude in decimal degrees (East positive).
  final double longitude;

  /// The UTC calendar date this data set covers.
  final DateTime date;

  /// Ordered list of all discrete events for this day, sorted by time.
  final List<SolarEvent> events;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Next upcoming event relative to [now] (UTC).
  SolarEvent? nextEvent([DateTime? now]) {
    final ref = now ?? DateTime.now().toUtc();
    try {
      return events.firstWhere((e) => e.time.isAfter(ref));
    } catch (_) {
      return null;
    }
  }

  /// Most recently passed event relative to [now] (UTC).
  SolarEvent? lastEvent([DateTime? now]) {
    final ref = now ?? DateTime.now().toUtc();
    final past = events.where((e) => e.time.isBefore(ref)).toList();
    return past.isEmpty ? null : past.last;
  }

  /// Progress through the current solar day as a fraction [0.0, 1.0].
  /// 0.0 = astronomical dawn, 1.0 = astronomical dusk.
  double get daylightProgress {
    final dawn = solar.astronomicalDawn ?? solar.civilDawn ?? solar.sunrise;
    final dusk = solar.astronomicalDusk ?? solar.civilDusk ?? solar.sunset;
    if (dawn == null || dusk == null) return 0.5;

    final now = DateTime.now().toUtc();
    if (now.isBefore(dawn)) return 0.0;
    if (now.isAfter(dusk)) return 1.0;

    final totalSpan = dusk.difference(dawn).inSeconds;
    if (totalSpan <= 0) return 0.5;
    return now.difference(dawn).inSeconds / totalSpan;
  }

  @override
  List<Object?> get props => [
        solar,
        moon,
        atmospheric,
        skyState,
        latitude,
        longitude,
        date,
        events,
      ];

  AstronomicalData copyWith({
    SolarData? solar,
    MoonData? moon,
    AtmosphericData? atmospheric,
    SkyState? skyState,
    double? latitude,
    double? longitude,
    DateTime? date,
    List<SolarEvent>? events,
  }) {
    return AstronomicalData(
      solar: solar ?? this.solar,
      moon: moon ?? this.moon,
      atmospheric: atmospheric ?? this.atmospheric,
      skyState: skyState ?? this.skyState,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      date: date ?? this.date,
      events: events ?? this.events,
    );
  }
}
