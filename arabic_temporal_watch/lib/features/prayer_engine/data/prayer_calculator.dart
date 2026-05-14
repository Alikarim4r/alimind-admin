// prayer_calculator.dart
//
// Astronomical prayer-time calculation engine.
//
// Algorithm overview
// ──────────────────
// All times are derived from the solar noon (transit) for the given day and
// location.  The key sub-routines are:
//
//   1. Julian Day Number from a calendar date.
//   2. Solar declination and equation of time via low-precision VSOP87
//      approximations (Spencer / Blanco-Muriel formulas).
//   3. Solar noon = 12h - equation_of_time / 60 - longitude / 15
//      (expressed in local civil time).
//   4. Hour angle H solved from the standard horizon-angle equation:
//        cos(H) = (sin(angle) − sin(lat)·sin(dec)) / (cos(lat)·cos(dec))
//   5. Each event is offset from solar noon by ±H/15 hours.
//   6. Asr shadow ratio (1 or 2) determines its dedicated hour-angle.

import 'dart:math' as math;

import '../domain/prayer.dart';

// ── PrayerCalculator ──────────────────────────────────────────────────────────

/// Pure-Dart, dependency-free prayer-time calculator.
///
/// Typical usage:
/// ```dart
/// final calc = PrayerCalculator();
/// final times = calc.calculate(
///   latitude: 24.6877,
///   longitude: 46.7219,
///   date: DateTime.now(),
///   params: PrayerCalculationParameters.ummAlQura(),
/// );
/// ```
class PrayerCalculator {
  const PrayerCalculator();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Computes prayer times for [date] at ([latitude], [longitude]) using
  /// the supplied [params].
  ///
  /// [date] should be a local [DateTime]; only its year/month/day components
  /// are used.  All returned [Prayer.time] values are local [DateTime]s on
  /// the same calendar date.
  PrayerTimes calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationParameters params,
  }) {
    // Normalise to local midnight so we always work with the correct date.
    final day = DateTime(date.year, date.month, date.day);

    // --- Step 1: Julian Day ---------------------------------------------------
    final jd = _julianDay(day.year, day.month, day.day);

    // --- Step 2: Solar position parameters ------------------------------------
    final dec = _solarDeclination(jd); // radians
    final eot = _equationOfTime(jd); // minutes

    // --- Step 3: Solar noon (local civil time, fractional hours) ---------------
    final solarNoonHours = 12.0 - eot / 60.0 - longitude / 15.0;

    // Timezone offset in hours so we can convert back to local time.
    final tzOffsetHours = day.timeZoneOffset.inSeconds / 3600.0;

    // Solar noon expressed as fractional hours in the local timezone.
    final localNoonHours = solarNoonHours + tzOffsetHours;

    // --- Step 4: Horizon hour angles ------------------------------------------
    final latRad = _deg2rad(latitude);

    // Sunrise / Sunset: standard −0.8333° accounts for refraction + semi-dia.
    final hSunrise = _hourAngle(latRad, dec, _deg2rad(-0.8333));

    // Fajr
    final hFajr = _hourAngle(latRad, dec, _deg2rad(-params.fajrAngle));

    // Isha (angle-based; overridden below if ishaMinutes is set)
    final hIsha = (params.ishaMinutes == null)
        ? _hourAngle(latRad, dec, _deg2rad(-params.ishaAngle))
        : null;

    // Asr: solve for the altitude angle first, then derive the hour angle.
    final hAsr = _asrHourAngle(latRad, dec, params.asrMethod);

    // --- Step 5: Map hour angles to local times -------------------------------
    // Morning events: noon − H/15;  afternoon events: noon + H/15.
    final fajrHours = localNoonHours - _rad2hours(hFajr);
    final sunriseHours = localNoonHours - _rad2hours(hSunrise);
    final dhuhrHours = localNoonHours; // Dhuhr = solar noon
    final asrHours = localNoonHours + _rad2hours(hAsr);
    final maghribHours = localNoonHours + _rad2hours(hSunrise); // sunset
    final ishaHours = (params.ishaMinutes != null)
        ? maghribHours + params.ishaMinutes! / 60.0
        : localNoonHours + _rad2hours(hIsha!);

    // --- Step 6: Build Prayer objects -----------------------------------------
    Prayer _make(PrayerName name, double fractionalHours) => Prayer(
          name: name,
          time: _hoursToDateTime(day, fractionalHours),
        );

    final maghribPrayer = _make(PrayerName.maghrib, maghribHours);

    return PrayerTimes(
      fajr: _make(PrayerName.fajr, fajrHours),
      sunrise: _make(PrayerName.sunrise, sunriseHours),
      dhuhr: _make(PrayerName.dhuhr, dhuhrHours),
      asr: _make(PrayerName.asr, asrHours),
      maghrib: maghribPrayer,
      isha: _make(PrayerName.isha, ishaHours),
      date: day,
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  // --- Julian Day Number ------------------------------------------------------

  /// Converts a proleptic Gregorian calendar date to the Julian Day Number
  /// (integer, at noon UTC).  Uses the standard astronomical algorithm.
  double _julianDay(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  // --- Solar position (low-precision VSOP87 approximation) --------------------

  /// Julian centuries since J2000.0.
  double _julianCenturies(double jd) => (jd - 2451545.0) / 36525.0;

  /// Mean longitude of the sun (degrees).
  double _meanSolarLongitude(double t) {
    return (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360.0;
  }

  /// Mean anomaly of the sun (degrees).
  double _meanSolarAnomaly(double t) {
    return (357.52911 + t * (35999.05029 - t * 0.0001537)) % 360.0;
  }

  /// Equation of centre (degrees).
  double _equationOfCentre(double t) {
    final mRad = _deg2rad(_meanSolarAnomaly(t));
    return math.sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * mRad) * (0.019993 - 0.000101 * t) +
        math.sin(3 * mRad) * 0.000289;
  }

  /// Apparent solar longitude (degrees) including aberration.
  double _apparentSolarLongitude(double t) {
    final sunLon = _meanSolarLongitude(t) + _equationOfCentre(t);
    final omega = 125.04 - 1934.136 * t; // ascending node of moon's orbit
    return sunLon - 0.00569 - 0.00478 * math.sin(_deg2rad(omega));
  }

  /// Mean obliquity of the ecliptic (degrees).
  double _meanObliquity(double t) {
    return 23.0 +
        (26.0 +
                (21.448 -
                        t * (46.8150 + t * (0.00059 - t * 0.001813))) /
                    60.0) /
            60.0;
  }

  /// Corrected obliquity (degrees) accounting for nutation.
  double _correctedObliquity(double t) {
    final omega = 125.04 - 1934.136 * t;
    return _meanObliquity(t) + 0.00256 * math.cos(_deg2rad(omega));
  }

  /// Solar declination in radians for the Julian Day [jd].
  double _solarDeclination(double jd) {
    final t = _julianCenturies(jd);
    final eps = _deg2rad(_correctedObliquity(t));
    final sunLon = _deg2rad(_apparentSolarLongitude(t));
    return math.asin(math.sin(eps) * math.sin(sunLon));
  }

  /// Equation of time in minutes for Julian Day [jd].
  ///
  /// Based on the USNO algorithm (Spencer, 1971; Meeus, Astronomical
  /// Algorithms, 2nd ed., chapter 27).
  double _equationOfTime(double jd) {
    final t = _julianCenturies(jd);
    final eps = _deg2rad(_correctedObliquity(t));
    final l0 = _deg2rad(_meanSolarLongitude(t));
    final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final m = _deg2rad(_meanSolarAnomaly(t));
    final y = math.pow(math.tan(eps / 2), 2) as double;

    final eot = y * math.sin(2 * l0) -
        2 * e * math.sin(m) +
        4 * e * y * math.sin(m) * math.cos(2 * l0) -
        0.5 * y * y * math.sin(4 * l0) -
        1.25 * e * e * math.sin(2 * m);

    return _rad2deg(eot) * 4.0; // convert to minutes (1° = 4 min)
  }

  // --- Hour angle from altitude angle ------------------------------------------

  /// Solves the spherical-trigonometry equation for the hour angle H given
  /// the observer's latitude [latRad], solar declination [decRad], and the
  /// target altitude [altRad] (all in radians).
  ///
  /// cos(H) = (sin(alt) − sin(lat)·sin(dec)) / (cos(lat)·cos(dec))
  ///
  /// Returns 0.0 if the sun does not reach the target altitude (circumpolar /
  /// polar night) — callers should validate the output when needed.
  double _hourAngle(double latRad, double decRad, double altRad) {
    final cosH = (math.sin(altRad) -
            math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));

    // Clamp to [-1, 1] to guard against floating-point noise at extreme lats.
    if (cosH < -1.0) return math.pi;
    if (cosH > 1.0) return 0.0;
    return math.acos(cosH);
  }

  // --- Asr hour angle ----------------------------------------------------------

  /// Computes the Asr hour angle for the given [asrMethod].
  ///
  /// The shadow ratio [r] is 1 for Standard (Shafi'i) and 2 for Hanafi.
  /// The target altitude is: arctan(1 / (r + tan(|lat − dec|))).
  double _asrHourAngle(
    double latRad,
    double decRad,
    AsrMethod asrMethod,
  ) {
    final r = asrMethod == AsrMethod.hanafi ? 2.0 : 1.0;
    final targetAlt = math.atan(1.0 / (r + math.tan((latRad - decRad).abs())));
    return _hourAngle(latRad, decRad, targetAlt);
  }

  // --- Unit converters --------------------------------------------------------

  double _deg2rad(double degrees) => degrees * math.pi / 180.0;
  double _rad2deg(double radians) => radians * 180.0 / math.pi;

  /// Converts an hour angle in radians to hours (H / 15°).
  double _rad2hours(double radians) => _rad2deg(radians) / 15.0;

  // --- Time helpers -----------------------------------------------------------

  /// Converts a fractional-hours offset from local midnight [base] into a
  /// local [DateTime].
  DateTime _hoursToDateTime(DateTime base, double hours) {
    // Guard against NaN / infinite values from extreme latitudes.
    if (!hours.isFinite) {
      // Return midnight as a safe fallback.
      return base;
    }

    // Normalise into [0, 24) to handle sub-midnight wrap-arounds.
    final normalised = hours % 24.0;
    final totalMinutes = (normalised * 60.0).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return DateTime(base.year, base.month, base.day, h, m);
  }
}
