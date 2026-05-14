// solar_calculator.dart
//
// Full production solar calculation engine implementing Jean Meeus algorithms
// from "Astronomical Algorithms" (2nd ed., Willmann-Bell, 1998).
//
// All internal angle arithmetic is performed in degrees; conversion to radians
// occurs at trigonometric call sites only.  Julian Day numbers use the standard
// J2000.0 epoch (JD 2451545.0 = 2000-Jan-1.5 TT).
//
// Accuracy: better than ±1 minute for rise/set times for observers between
// ±60° latitude and for dates within ±50 years of J2000.0.
//
// Clean-architecture note: this is a pure-Dart service class with no Flutter
// or platform dependencies.  It is consumed by the presentation-layer providers
// and by the prayer-engine feature.

import 'dart:math' as math;

import '../domain/astronomical_data.dart';
import '../domain/solar_event.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Degrees → radians conversion factor.
const double _deg2rad = math.pi / 180.0;

/// Radians → degrees conversion factor.
const double _rad2deg = 180.0 / math.pi;

/// Standard atmospheric refraction + solar semi-diameter depression angle (°).
/// At the moment the upper limb is on the geometric horizon the sun's centre
/// is approximately 0.8333° below it.
const double _sunriseAngle = -0.8333;

// ── Internal value objects ─────────────────────────────────────────────────────

/// Equatorial solar coordinates at a given Julian Day.
class _SolarCoords {
  const _SolarCoords({
    required this.rightAscension,
    required this.declination,
  });

  /// Right ascension of the sun in degrees [0°, 360°).
  final double rightAscension;

  /// Declination of the sun in degrees [−90°, +90°].
  final double declination;
}

// ── SolarCalculator ───────────────────────────────────────────────────────────

/// Stateless service that performs all solar (and supporting lunar) position
/// and event-time calculations.
///
/// All public methods are pure functions: given the same inputs they always
/// return the same outputs, with no side-effects or mutable state.
class SolarCalculator {
  const SolarCalculator();

  // ── 1. Julian Day Number ────────────────────────────────────────────────────

  /// Converts a [DateTime] to a Julian Day Number (JDN).
  ///
  /// Meeus, Ch. 7.  The formula handles dates after the Gregorian reform
  /// (1582-Oct-15).  [dt] should be in UTC; the fractional-day term carries
  /// the time-of-day.
  ///
  /// Formula:
  ///   JD = 367·Y − INT(7·(Y + INT((M+9)/12)) / 4)
  ///       + INT(275·M/9) + D + 1 721 013.5 + UT/24
  double julianDay(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year;
    final m = utc.month;
    final d = utc.day;
    // Fractional day contribution from time-of-day components.
    final ut = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;

    return 367.0 * y -
        (7.0 * (y + ((m + 9) / 12).floor()) / 4.0).floor() +
        (275.0 * m / 9.0).floor() +
        d +
        1721013.5 +
        ut / 24.0;
  }

  // ── 2. Julian Century ───────────────────────────────────────────────────────

  /// Julian century measured from J2000.0.
  ///
  ///   T = (JD − 2 451 545.0) / 36 525
  double _julianCentury(double jd) => (jd - 2451545.0) / 36525.0;

  // ── 3. Solar Coordinates ────────────────────────────────────────────────────

  /// Computes the apparent geocentric right ascension and declination of the
  /// sun for a given Julian Day [jd].
  ///
  /// Implements the low-precision algorithm from Meeus, Ch. 25, accurate to
  /// within 0.01° for dates within a century of J2000.0.
  ///
  /// Steps:
  ///   T   = Julian century
  ///   L0  = geometric mean longitude (°)
  ///   M   = mean anomaly (°)
  ///   C   = equation of center (°)
  ///   Θ   = true longitude = L0 + C
  ///   Ω   = longitude of ascending node (for nutation correction)
  ///   λ   = apparent longitude = Θ − 0.00569 − 0.00478·sin(Ω)
  ///   ε   = mean obliquity of the ecliptic (°)
  ///   δ   = declination = arcsin(sin(ε)·sin(λ))
  ///   α   = right ascension = arctan2(cos(ε)·sin(λ), cos(λ))
  _SolarCoords solarCoordinates(double jd) {
    final t = _julianCentury(jd);

    // Mean longitude of the sun, degrees, Meeus eq. 25.2.
    // Normalised to [0°, 360°).
    final l0 = _normalizeDeg(280.46646 + 36000.76983 * t + 0.0003032 * t * t);

    // Mean anomaly of the sun, degrees, Meeus eq. 25.3.
    // Normalised to [0°, 360°).
    final m = _normalizeDeg(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final mRad = m * _deg2rad;

    // Equation of the center – accounts for orbital eccentricity.
    // Meeus eq. 25.4.
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mRad) +
        (0.019993 - 0.000101 * t) * math.sin(2.0 * mRad) +
        0.000289 * math.sin(3.0 * mRad);

    // Sun's true longitude (geometric), degrees.
    final sunTrueLon = l0 + c;

    // Longitude of the ascending node of the moon's mean orbit.
    // Used for the small nutation and aberration correction.
    final omega = _normalizeDeg(125.04 - 1934.136 * t);

    // Sun's apparent longitude (corrected for nutation and aberration).
    final lambda = sunTrueLon - 0.00569 - 0.00478 * math.sin(omega * _deg2rad);
    final lambdaRad = lambda * _deg2rad;

    // Mean obliquity of the ecliptic, degrees.  Meeus eq. 22.2 (truncated).
    final epsilon = 23.439291 - 0.013004 * t - 0.000000164 * t * t +
        0.000000504 * t * t * t;
    final epsilonRad = epsilon * _deg2rad;

    // Geocentric declination, degrees.
    final declination =
        math.asin(math.sin(epsilonRad) * math.sin(lambdaRad)) * _rad2deg;

    // Geocentric right ascension, degrees [0°, 360°).
    final raRad = math.atan2(
      math.cos(epsilonRad) * math.sin(lambdaRad),
      math.cos(lambdaRad),
    );
    final rightAscension = _normalizeDeg(raRad * _rad2deg);

    return _SolarCoords(
      rightAscension: rightAscension,
      declination: declination,
    );
  }

  // ── 4. Equation of Time ─────────────────────────────────────────────────────

  /// Returns the equation of time in minutes for the given Julian Day [jd].
  ///
  /// The equation of time E = apparent solar time − mean solar time.
  /// A positive value means the apparent sun is ahead of the mean sun.
  ///
  /// Meeus, Ch. 27, low-precision form.
  ///
  /// E (minutes) = 4 · [L0 − 0.0057183 − α + Δψ·cos(ε)]
  /// where Δψ is the nutation in longitude (simplified here as the
  /// apparent-longitude correction already absorbed into α).
  double equationOfTime(double jd) {
    final t = _julianCentury(jd);

    // Geometric mean longitude (degrees).
    final l0 = _normalizeDeg(280.46646 + 36000.76983 * t + 0.0003032 * t * t);

    // Mean anomaly (degrees).
    final m = _normalizeDeg(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final mRad = m * _deg2rad;

    // Mean obliquity of the ecliptic (degrees).
    final epsilon = 23.439291 - 0.013004 * t;
    final epsilonRad = epsilon * _deg2rad;

    // The "y" term used in Meeus's compact EoT formula.
    final y = math.pow(math.tan(epsilonRad / 2.0), 2).toDouble();

    final l0Rad = l0 * _deg2rad;

    // EoT in radians, Meeus eq. 27.1.
    final eotRad = y * math.sin(2.0 * l0Rad) -
        2.0 * _eccentricity(t) * math.sin(mRad) +
        4.0 * _eccentricity(t) * y * math.sin(mRad) * math.cos(2.0 * l0Rad) -
        0.5 * y * y * math.sin(4.0 * l0Rad) -
        1.25 * _eccentricity(t) * _eccentricity(t) * math.sin(2.0 * mRad);

    // Convert to minutes (full circle = 1440 min).
    return eotRad * _rad2deg * 4.0;
  }

  /// Earth's orbital eccentricity at Julian century [t].  Meeus eq. 25.4 coeff.
  double _eccentricity(double t) =>
      0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;

  // ── 5. Solar Altitude ───────────────────────────────────────────────────────

  /// Returns the geometric altitude of the sun's centre in degrees for the
  /// observer at ([lat], [lon]) at the given UTC [dt].
  ///
  /// Positive values are above the mathematical horizon.  Atmospheric
  /// refraction is NOT applied here; use the threshold −0.8333° when testing
  /// visibility (see [_sunriseAngle]).
  ///
  /// Formula (Meeus, Ch. 13):
  ///   H  = local hour angle of the sun
  ///   h  = arcsin( sin(lat)·sin(δ) + cos(lat)·cos(δ)·cos(H) )
  double solarAltitude(double lat, double lon, DateTime dt) {
    final jd = julianDay(dt);
    final coords = solarCoordinates(jd);
    final ha = _hourAngle(jd, lon, coords.rightAscension);
    return _altitudeFromHourAngle(lat, coords.declination, ha);
  }

  // ── 6. Solar Azimuth ────────────────────────────────────────────────────────

  /// Returns the solar azimuth in degrees [0°, 360°) measured clockwise from
  /// geographic North for the observer at ([lat], [lon]) at UTC [dt].
  ///
  /// Formula (Meeus, Ch. 13):
  ///   A = arctan2( sin(H), cos(H)·sin(lat) − tan(δ)·cos(lat) )
  ///   then rotated so that 0° = North.
  double solarAzimuth(double lat, double lon, DateTime dt) {
    final jd = julianDay(dt);
    final coords = solarCoordinates(jd);
    final ha = _hourAngle(jd, lon, coords.rightAscension);
    return _azimuthFromHourAngle(lat, coords.declination, ha);
  }

  // ── 7. Sunrise ──────────────────────────────────────────────────────────────

  /// Returns the UTC [DateTime] of sunrise at ([lat], [lon]) for the calendar
  /// day given by [date] (year/month/day components only; time-of-day ignored).
  ///
  /// Returns null when the sun does not rise on that date (polar night or
  /// midnight sun).
  DateTime? sunriseTime(double lat, double lon, DateTime date) {
    return _riseOrSet(lat, lon, date, isSunrise: true, altitudeDeg: _sunriseAngle);
  }

  // ── 8. Sunset ───────────────────────────────────────────────────────────────

  /// Returns the UTC [DateTime] of sunset at ([lat], [lon]) for [date].
  ///
  /// Returns null when the sun does not set on that date.
  DateTime? sunsetTime(double lat, double lon, DateTime date) {
    return _riseOrSet(lat, lon, date, isSunrise: false, altitudeDeg: _sunriseAngle);
  }

  // ── 9. Solar Noon ───────────────────────────────────────────────────────────

  /// Returns the UTC [DateTime] of solar transit (meridian crossing / solar
  /// noon) at ([lat], [lon]) for [date].
  ///
  /// Solar noon is when the sun's hour angle is exactly zero (it crosses the
  /// observer's meridian).
  ///
  /// Formula:
  ///   J_noon = 2451545.0 + 0.0009 + (−lon/360) + n
  ///   where n is the integer day count from J2000.0 to the target date.
  ///   Then iterate once using EoT for higher accuracy.
  DateTime solarNoon(double lat, double lon, DateTime date) {
    // Approximate JD for local noon at longitude [lon].
    final jd0 = _jdAtNoon(date, lon);
    // Refine with equation of time (one iteration gives <30 s accuracy).
    final eotMinutes = equationOfTime(jd0);
    final refinedJd = jd0 - eotMinutes / 1440.0;
    return _jdToDateTime(refinedJd);
  }

  // ── 10. Twilight Times ──────────────────────────────────────────────────────

  /// Returns the UTC time at which the sun crosses [type]'s depression angle
  /// for the given [date] and location.
  ///
  /// [isMorning] selects the rising (morning) or setting (evening) crossing.
  ///
  /// Returns null when no crossing occurs (circumpolar conditions).
  DateTime? twilightTime(
    double lat,
    double lon,
    DateTime date,
    TwilightType type, {
    bool isMorning = true,
  }) {
    return _riseOrSet(
      lat,
      lon,
      date,
      isSunrise: isMorning,
      altitudeDeg: type.depressionAngle,
    );
  }

  // ── 11. calculateAll ────────────────────────────────────────────────────────

  /// Computes the complete [AstronomicalData] bundle for the observer at
  /// ([lat], [lon]) on the calendar day given by [date].
  ///
  /// The returned [AstronomicalData.atmospheric] reflects the solar position
  /// at the exact UTC instant this method is called (i.e. [DateTime.now]).
  AstronomicalData calculateAll(double lat, double lon, DateTime date) {
    final now = DateTime.now().toUtc();

    // ── Solar timing ────────────────────────────────────────────────────────
    final rise = sunriseTime(lat, lon, date);
    final set_ = sunsetTime(lat, lon, date);
    final noon = solarNoon(lat, lon, date);

    final dayLengthSec = (rise != null && set_ != null)
        ? set_.difference(rise).inSeconds.clamp(0, 86400)
        : (rise == null && set_ == null)
            ? _isMidnightSun(lat, date)
                ? 86400
                : 0
            : 0;

    // Twilight times (morning = rising crossing, evening = setting crossing).
    final civDawn =
        twilightTime(lat, lon, date, TwilightType.civil, isMorning: true);
    final civDusk =
        twilightTime(lat, lon, date, TwilightType.civil, isMorning: false);
    final nautDawn =
        twilightTime(lat, lon, date, TwilightType.nautical, isMorning: true);
    final nautDusk =
        twilightTime(lat, lon, date, TwilightType.nautical, isMorning: false);
    final astroDawn =
        twilightTime(lat, lon, date, TwilightType.astronomical, isMorning: true);
    final astroDusk =
        twilightTime(lat, lon, date, TwilightType.astronomical, isMorning: false);

    final solarData = SolarData(
      sunrise: rise,
      sunset: set_,
      solarNoon: noon,
      dayLengthSeconds: dayLengthSec,
      civilDawn: civDawn,
      civilDusk: civDusk,
      nauticalDawn: nautDawn,
      nauticalDusk: nautDusk,
      astronomicalDawn: astroDawn,
      astronomicalDusk: astroDusk,
    );

    // ── Real-time atmospheric position ──────────────────────────────────────
    final jdNow = julianDay(now);
    final coordsNow = solarCoordinates(jdNow);
    final haNow = _hourAngle(jdNow, lon, coordsNow.rightAscension);
    final altNow = _altitudeFromHourAngle(lat, coordsNow.declination, haNow);
    final azNow = _azimuthFromHourAngle(lat, coordsNow.declination, haNow);

    final atmospheric = AtmosphericData(
      solarAltitude: altNow,
      solarAzimuth: azNow,
      hourAngle: haNow,
      observedAt: now,
    );

    // ── Sky state ───────────────────────────────────────────────────────────
    final sky = skyState(altNow);

    // ── Moon data ───────────────────────────────────────────────────────────
    final moonCalc = MoonCalculatorHelper();
    final moonPhaseVal = moonCalc.moonPhase(now);
    final moonIllumVal = moonCalc.moonIllumination(now);
    // Simplified moon rise/set (not computed in this pass; set to null).
    final moonData = MoonData(
      phase: moonPhaseVal,
      illumination: moonIllumVal,
      moonrise: null,
      moonset: null,
    );

    // ── Events list ─────────────────────────────────────────────────────────
    final events = _buildEventList(
      lat: lat,
      lon: lon,
      solarData: solarData,
      coordsNow: coordsNow,
    );

    return AstronomicalData(
      solar: solarData,
      moon: moonData,
      atmospheric: atmospheric,
      skyState: sky,
      latitude: lat,
      longitude: lon,
      date: date,
      events: events,
    );
  }

  // ── 12. skyState ────────────────────────────────────────────────────────────

  /// Returns the [SkyState] corresponding to the given solar [altitudeDeg].
  ///
  /// Thresholds (IAU / USNO):
  ///   ≥ −0.8333° → Day
  ///   ≥ −6°      → CivilTwilight
  ///   ≥ −12°     → NauticalTwilight
  ///   ≥ −18°     → AstronomicalTwilight
  ///   <  −18°    → Night
  SkyState skyState(double altitudeDeg) {
    if (altitudeDeg >= _sunriseAngle) return SkyState.day;
    if (altitudeDeg >= -6.0) return SkyState.civilTwilight;
    if (altitudeDeg >= -12.0) return SkyState.nauticalTwilight;
    if (altitudeDeg >= -18.0) return SkyState.astronomicalTwilight;
    return SkyState.night;
  }

  // ── 13. currentSolarAltitude ────────────────────────────────────────────────

  /// Convenience wrapper: returns the solar altitude at the current UTC instant
  /// for an observer at ([lat], [lon]).
  double currentSolarAltitude(double lat, double lon) =>
      solarAltitude(lat, lon, DateTime.now().toUtc());

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Local hour angle H (degrees) of the sun from the observer's meridian.
  ///
  ///   H = GMST + lon − α
  ///
  /// where GMST is Greenwich Mean Sidereal Time converted to degrees, and
  /// α is the sun's right ascension.  H is normalised to (−180°, +180°]:
  /// negative east of meridian (morning), positive west (afternoon).
  double _hourAngle(double jd, double lon, double rightAscension) {
    final gmst = _greenwichSiderealTime(jd); // degrees
    final lha = _normalizeDeg(gmst + lon - rightAscension);
    // Map to (−180°, +180°] so that negative = morning, positive = afternoon.
    return lha > 180.0 ? lha - 360.0 : lha;
  }

  /// Greenwich Mean Sidereal Time in degrees for Julian Day [jd].
  ///
  /// Meeus, eq. 12.4.
  double _greenwichSiderealTime(double jd) {
    final t = _julianCentury(jd);
    final theta0 = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;
    return _normalizeDeg(theta0);
  }

  /// Geometric altitude (°) from hour angle [ha], declination [dec], and
  /// observer latitude [lat] (all in degrees).
  ///
  ///   h = arcsin( sin(lat)·sin(δ) + cos(lat)·cos(δ)·cos(H) )
  double _altitudeFromHourAngle(double lat, double dec, double ha) {
    final latR = lat * _deg2rad;
    final decR = dec * _deg2rad;
    final haR = ha * _deg2rad;
    final sinAlt =
        math.sin(latR) * math.sin(decR) + math.cos(latR) * math.cos(decR) * math.cos(haR);
    return math.asin(sinAlt.clamp(-1.0, 1.0)) * _rad2deg;
  }

  /// Azimuth (°, clockwise from North) from hour angle [ha], declination [dec],
  /// and observer latitude [lat] (all in degrees).
  ///
  ///   A = arctan2( sin(H), cos(H)·sin(lat) − tan(δ)·cos(lat) )
  ///   Then adjusted so 0° = North (add 180°, normalise).
  double _azimuthFromHourAngle(double lat, double dec, double ha) {
    final latR = lat * _deg2rad;
    final decR = dec * _deg2rad;
    final haR = ha * _deg2rad;

    final azRad = math.atan2(
      math.sin(haR),
      math.cos(haR) * math.sin(latR) - math.tan(decR) * math.cos(latR),
    );
    // atan2 result is measured from South; add 180° to convert to North-based.
    return _normalizeDeg(azRad * _rad2deg + 180.0);
  }

  /// Computes the UTC time of either sunrise or sunset (controlled by
  /// [isSunrise]) using the iterative algorithm described in Meeus, Ch. 15.
  ///
  /// The target altitude threshold is [altitudeDeg] (e.g. −0.8333° for
  /// sunrise/sunset, −6° for civil twilight, etc.).
  ///
  /// Returns null when no crossing occurs (the sun stays above or below the
  /// threshold all day).
  DateTime? _riseOrSet(
    double lat,
    double lon,
    DateTime date, {
    required bool isSunrise,
    required double altitudeDeg,
  }) {
    // ── Step 1: approximate hour angle at rise/set ──────────────────────────
    // Start with solar noon as the first estimate.
    final jdNoon = _jdAtNoon(date, lon);
    final coords = solarCoordinates(jdNoon);
    final dec = coords.declination;

    // cos(H0) = (sin(h0) − sin(lat)·sin(δ)) / (cos(lat)·cos(δ))
    // h0 = target altitude threshold.
    final cosH0 = (math.sin(altitudeDeg * _deg2rad) -
            math.sin(lat * _deg2rad) * math.sin(dec * _deg2rad)) /
        (math.cos(lat * _deg2rad) * math.cos(dec * _deg2rad));

    // No solution exists (circumpolar / never rises).
    if (cosH0 < -1.0 || cosH0 > 1.0) return null;

    // Hour angle at horizon crossing, degrees [0°, 180°].
    final h0 = math.acos(cosH0.clamp(-1.0, 1.0)) * _rad2deg;

    // ── Step 2: first estimate of crossing time ─────────────────────────────
    // Transit offset from apparent noon in fractional days.
    // Sunrise: noon − H0/360, Sunset: noon + H0/360.
    final eotMin = equationOfTime(jdNoon);
    final transitJd = jdNoon - eotMin / 1440.0;
    final offsetDays = (isSunrise ? -h0 : h0) / 360.0;
    double crossingJd = transitJd + offsetDays;

    // ── Step 3: iterate to refine (two passes are sufficient) ──────────────
    for (int i = 0; i < 2; i++) {
      final coordsAt = solarCoordinates(crossingJd);
      final haAt = _hourAngle(crossingJd, lon, coordsAt.rightAscension);
      final altAt =
          _altitudeFromHourAngle(lat, coordsAt.declination, haAt);

      // Correction: Δt = (h − h0) / (360 · cos(δ) · cos(lat) · sin(H))
      // where h is the computed altitude and h0 the target altitude.
      final denominator = 360.0 *
          math.cos(coordsAt.declination * _deg2rad) *
          math.cos(lat * _deg2rad) *
          math.sin(haAt * _deg2rad);

      if (denominator.abs() < 1e-10) break; // Sun near pole – skip correction.

      final correction = (altAt - altitudeDeg) / denominator;
      crossingJd -= correction;
    }

    return _jdToDateTime(crossingJd);
  }

  /// Julian Day for local apparent noon at longitude [lon] on [date].
  ///
  /// The fractional-day offset −lon/360 shifts the Greenwich JD to the
  /// observer's meridian.
  double _jdAtNoon(DateTime date, double lon) {
    final utcDate = DateTime.utc(date.year, date.month, date.day, 12, 0, 0);
    return julianDay(utcDate) - lon / 360.0;
  }

  /// Converts a Julian Day Number back to a UTC [DateTime].
  DateTime _jdToDateTime(double jd) {
    // Meeus, Ch. 7 – inverse JD formula.
    final jdShifted = jd + 0.5;
    final z = jdShifted.floor().toDouble();
    final f = jdShifted - z;

    double a;
    if (z < 2299161) {
      a = z;
    } else {
      final alpha = ((z - 1867216.25) / 36524.25).floor().toDouble();
      a = z + 1 + alpha - (alpha / 4).floor();
    }

    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor().toDouble();
    final d = (365.25 * c).floor().toDouble();
    final e = ((b - d) / 30.6001).floor().toDouble();

    // Day with fractional time.
    final dayFrac = b - d - (30.6001 * e).floor() + f;
    final day = dayFrac.floor();
    final timeFrac = dayFrac - day;

    // Month.
    final month = (e < 14) ? (e - 1).toInt() : (e - 13).toInt();

    // Year.
    final year = (month > 2) ? (c - 4716).toInt() : (c - 4715).toInt();

    // Time components.
    final totalSeconds = (timeFrac * 86400.0).round();
    final hour = totalSeconds ~/ 3600;
    final minute = (totalSeconds % 3600) ~/ 60;
    final second = totalSeconds % 60;

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  /// Normalises an angle to the range [0°, 360°).
  double _normalizeDeg(double deg) => deg - 360.0 * (deg / 360.0).floor();

  /// Heuristic check for midnight-sun conditions:
  /// If the sun's declination is greater than (90° − |lat|) the sun never
  /// sets; if less than -(90° − |lat|) it never rises.
  bool _isMidnightSun(double lat, DateTime date) {
    final jd = julianDay(DateTime.utc(date.year, date.month, date.day, 12, 0, 0));
    final dec = solarCoordinates(jd).declination;
    return dec.abs() > (90.0 - lat.abs());
  }

  /// Assembles the ordered list of [SolarEvent] objects for a day.
  List<SolarEvent> _buildEventList({
    required double lat,
    required double lon,
    required SolarData solarData,
    required _SolarCoords coordsNow,
  }) {
    final events = <SolarEvent>[];

    void addEvent(DateTime? time, SolarEventType type) {
      if (time == null) return;
      final jd = julianDay(time);
      final coords = solarCoordinates(jd);
      final ha = _hourAngle(jd, lon, coords.rightAscension);
      events.add(SolarEvent(
        time: time,
        type: type,
        azimuth: _azimuthFromHourAngle(lat, coords.declination, ha),
        altitude: _altitudeFromHourAngle(lat, coords.declination, ha),
      ));
    }

    addEvent(solarData.astronomicalDawn, SolarEventType.astronomicalDawn);
    addEvent(solarData.nauticalDawn, SolarEventType.nauticalDawn);
    addEvent(solarData.civilDawn, SolarEventType.civilDawn);
    addEvent(solarData.sunrise, SolarEventType.sunrise);
    addEvent(solarData.solarNoon, SolarEventType.solarNoon);
    addEvent(solarData.sunset, SolarEventType.sunset);
    addEvent(solarData.civilDusk, SolarEventType.civilDusk);
    addEvent(solarData.nauticalDusk, SolarEventType.nauticalDusk);
    addEvent(solarData.astronomicalDusk, SolarEventType.astronomicalDusk);

    events.sort((a, b) => a.time.compareTo(b.time));
    return List.unmodifiable(events);
  }
}

// ── MoonCalculatorHelper (thin wrapper used by SolarCalculator.calculateAll) ──

/// Lightweight lunar calculation helper used internally by [SolarCalculator].
///
/// For the standalone public API see [MoonCalculator] in moon_calculator.dart.
class MoonCalculatorHelper {
  const MoonCalculatorHelper();

  static const double _synodicMonth = 29.53058868; // mean synodic month, days
  static const double _knownNewMoon = 2451550.1; // JD of 2000-Jan-6 new moon

  /// Returns the fractional phase of the moon (0.0 = New, 0.5 = Full, 1.0 = New).
  double moonPhase(DateTime dt) {
    final jd = SolarCalculator().julianDay(dt);
    final daysSinceNew = jd - _knownNewMoon;
    final cycles = daysSinceNew / _synodicMonth;
    return cycles - cycles.floor();
  }

  /// Returns the fraction of the lunar disc illuminated [0.0, 1.0].
  ///
  /// Illumination ≈ (1 − cos(2π·phase)) / 2.
  double moonIllumination(DateTime dt) {
    final phase = moonPhase(dt);
    return (1.0 - math.cos(2.0 * math.pi * phase)) / 2.0;
  }
}
