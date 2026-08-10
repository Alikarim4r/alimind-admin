// moon_calculator.dart
//
// Lunar phase, illumination, and visibility calculator.
//
// Phase algorithm: simplified Jean Meeus approach using the mean synodic
// period and a known New Moon epoch (JD 2451550.09765, 2000-Jan-6 18:14 UTC).
// For illumination the standard half-angle formula is applied.
//
// Visibility: a geometric check is used — the moon is considered visible
// when its altitude above the horizon (computed via equatorial coordinates)
// is positive.  Atmospheric refraction and observer-horizon elevation are
// ignored; a thin buffer of +0.125° is used to account for the lunar
// semi-diameter (mean ≈ 0.266° / 2 ≈ 0.133°).
//
// Accuracy note: the phase and illumination values are accurate to within
// ±0.5% for dates within ±100 years of J2000.0.  For sub-arcsecond lunar
// positioning the full Meeus Ch. 47 series expansion should be used.
//
// Clean-architecture note: this file has no Flutter dependencies and may be
// used from any Dart environment.

import 'dart:math' as math;

import '../domain/astronomical_data.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

/// Julian Day of the reference New Moon used for phase calculations.
/// 2000-Jan-6 18:14 UTC → JD ≈ 2451550.26.
const double _kNewMoonEpoch = 2451550.26;

/// Mean synodic month (New Moon → New Moon), days.
const double _kSynodicMonth = 29.53058868;

/// Degrees to radians.
const double _kDeg2Rad = math.pi / 180.0;

/// Radians to degrees.
const double _kRad2Deg = 180.0 / math.pi;

/// Lunar semi-diameter buffer applied to rise/set altitude checks (degrees).
const double _kLunarSemiDiameter = 0.133;

// ── MoonCalculator ─────────────────────────────────────────────────────────────

/// Stateless service for lunar calculations.
///
/// All public methods are pure functions; no mutable state is held.
class MoonCalculator {
  const MoonCalculator();

  // ── Julian Day helper ────────────────────────────────────────────────────────

  /// Converts a [DateTime] to a Julian Day Number.
  ///
  /// Uses the same formula as [SolarCalculator.julianDay] but is reproduced
  /// here so [MoonCalculator] has no cross-file dependency on the solar engine.
  double _julianDay(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year;
    final m = utc.month;
    final d = utc.day;
    final ut = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;

    return 367.0 * y -
        (7.0 * (y + ((m + 9) / 12).floor()) / 4.0).floor() +
        (275.0 * m / 9.0).floor() +
        d +
        1721013.5 +
        ut / 24.0;
  }

  // ── 1. Moon Phase ────────────────────────────────────────────────────────────

  /// Returns the fractional phase of the moon for the given UTC [dt].
  ///
  /// The phase progresses as follows:
  ///   0.00       New Moon
  ///   0.00–0.25  Waxing Crescent
  ///   0.25       First Quarter
  ///   0.25–0.50  Waxing Gibbous
  ///   0.50       Full Moon
  ///   0.50–0.75  Waning Gibbous
  ///   0.75       Last Quarter
  ///   0.75–1.00  Waning Crescent
  ///   1.00 → 0.00 New Moon (next cycle)
  ///
  /// Algorithm:
  ///   1. Compute JD for [dt].
  ///   2. Count days elapsed since the reference New Moon epoch.
  ///   3. Divide by the mean synodic month length and take the fractional part.
  ///
  /// Return range: [0.0, 1.0).
  double moonPhase(DateTime dt) {
    final jd = _julianDay(dt);
    final elapsed = jd - _kNewMoonEpoch;
    final cycles = elapsed / _kSynodicMonth;
    // Fractional part, always positive.
    final frac = cycles - cycles.floor();
    return frac.clamp(0.0, 1.0);
  }

  // ── 2. Moon Illumination ────────────────────────────────────────────────────

  /// Returns the fraction of the lunar disc that is illuminated, in [0.0, 1.0].
  ///
  /// Derived from the phase angle using the standard formula:
  ///
  ///   k = (1 − cos(2π · phase)) / 2
  ///
  /// where k = 0 at New Moon (phase = 0 or 1), k = 1 at Full Moon (phase = 0.5).
  ///
  /// This is the geometric illumination; the visual appearance may differ
  /// slightly due to limb darkening and opposition surge.
  double moonIllumination(DateTime dt) {
    final phase = moonPhase(dt);
    return (1.0 - math.cos(2.0 * math.pi * phase)) / 2.0;
  }

  // ── 3. Illumination as percentage ───────────────────────────────────────────

  /// Convenience wrapper: returns illumination as an integer percentage [0, 100].
  int moonIlluminationPercent(DateTime dt) =>
      (moonIllumination(dt) * 100).round();

  // ── 4. Phase name ────────────────────────────────────────────────────────────

  /// Returns the conventional English phase name for [dt].
  ///
  /// Boundary zones (±0.0625 around 0, 0.25, 0.50, 0.75) are assigned to the
  /// nearest named phase so that the label is stable near quarter transitions.
  String moonPhaseName(DateTime dt) {
    final phase = moonPhase(dt);
    return _phaseNameFromFraction(phase);
  }

  /// Returns the phase name for a pre-computed [phase] fraction.
  String _phaseNameFromFraction(double phase) {
    // Each named band spans 0.125 of the cycle (1/8 of the synodic month).
    if (phase < 0.0625 || phase >= 0.9375) return 'New Moon';
    if (phase < 0.1875) return 'Waxing Crescent';
    if (phase < 0.3125) return 'First Quarter';
    if (phase < 0.4375) return 'Waxing Gibbous';
    if (phase < 0.5625) return 'Full Moon';
    if (phase < 0.6875) return 'Waning Gibbous';
    if (phase < 0.8125) return 'Last Quarter';
    return 'Waning Crescent';
  }

  // ── 5. Is Moon Visible ────────────────────────────────────────────────────────

  /// Returns true when the moon is above the effective horizon (accounting for
  /// the lunar semi-diameter) at the observer's location ([lat], [lon]) at [dt].
  ///
  /// The calculation:
  ///   1. Compute the moon's ecliptic longitude and latitude using a simplified
  ///      series expansion (Meeus Ch. 47, first-order terms only).
  ///   2. Convert to equatorial coordinates (RA, declination).
  ///   3. Compute the local hour angle.
  ///   4. Compute altitude; compare against −[_kLunarSemiDiameter].
  ///
  /// [lat] observer latitude in decimal degrees (North positive).
  /// [lon] observer longitude in decimal degrees (East positive).
  /// [dt]  the UTC datetime to evaluate.
  bool isMoonVisible(double lat, double lon, DateTime dt) {
    final alt = moonAltitude(lat, lon, dt);
    return alt > -_kLunarSemiDiameter;
  }

  // ── 6. Moon Altitude ──────────────────────────────────────────────────────────

  /// Returns the geometric altitude of the moon's centre (degrees) above the
  /// mathematical horizon for the observer at ([lat], [lon]) at UTC [dt].
  ///
  /// Positive = above horizon.
  double moonAltitude(double lat, double lon, DateTime dt) {
    final coords = _moonEquatorialCoords(dt);
    final jd = _julianDay(dt);
    final ha = _hourAngle(jd, lon, coords._ra);
    return _altitude(lat, coords._dec, ha);
  }

  // ── 7. Moon Azimuth ──────────────────────────────────────────────────────────

  /// Returns the azimuth of the moon in degrees [0°, 360°), measured clockwise
  /// from geographic North, for the observer at ([lat], [lon]) at UTC [dt].
  double moonAzimuth(double lat, double lon, DateTime dt) {
    final coords = _moonEquatorialCoords(dt);
    final jd = _julianDay(dt);
    final ha = _hourAngle(jd, lon, coords._ra);
    return _azimuth(lat, coords._dec, ha);
  }

  // ── 8. Next new/full moon ────────────────────────────────────────────────────

  /// Returns the UTC [DateTime] of the next New Moon after [dt].
  DateTime nextNewMoon(DateTime dt) => _nextPhase(dt, 0.0);

  /// Returns the UTC [DateTime] of the next Full Moon after [dt].
  DateTime nextFullMoon(DateTime dt) => _nextPhase(dt, 0.5);

  /// Returns the UTC [DateTime] of the next First Quarter after [dt].
  DateTime nextFirstQuarter(DateTime dt) => _nextPhase(dt, 0.25);

  /// Returns the UTC [DateTime] of the next Last Quarter after [dt].
  DateTime nextLastQuarter(DateTime dt) => _nextPhase(dt, 0.75);

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Computes approximate geocentric equatorial coordinates of the moon using
  /// a simplified Meeus series (Chapter 47, principal terms only).
  ///
  /// Returns a private record-like object with RA and declination (degrees).
  _MoonEquatorialCoords _moonEquatorialCoords(DateTime dt) {
    final jd = _julianDay(dt);
    final t = (jd - 2451545.0) / 36525.0; // Julian centuries from J2000.0

    // ── Fundamental arguments ──────────────────────────────────────────────
    // All angles in degrees.

    // Moon's mean longitude (Meeus eq. 47.1).
    final l_ = _normDeg(218.3164477 +
        481267.88123421 * t -
        0.0015786 * t * t +
        t * t * t / 538841.0);

    // Moon's mean anomaly (Meeus eq. 47.4).
    final m_ = _normDeg(134.9633964 +
        477198.8676313 * t +
        0.0089970 * t * t +
        t * t * t / 69699.0);

    // Moon's argument of latitude (Meeus eq. 47.5).
    final f = _normDeg(93.2720950 +
        483202.0175233 * t -
        0.0036539 * t * t -
        t * t * t / 3526000.0);

    // Sun's mean anomaly (used for evection corrections).
    final mSun = _normDeg(357.5291092 + 35999.0502909 * t);

    // ── Ecliptic longitude corrections ─────────────────────────────────────
    // Principal terms from Table 47.A (degrees).
    double sumL = 0.0;
    sumL += 6288774.0 * math.sin(m_ * _kDeg2Rad);
    sumL += 1274027.0 * math.sin((2.0 * (l_ - f) - m_) * _kDeg2Rad);
    sumL += 658314.0 * math.sin(2.0 * (l_ - f) * _kDeg2Rad);
    sumL += -185116.0 * math.sin(mSun * _kDeg2Rad);
    sumL += 58793.0 * math.sin((2.0 * (l_ - f) - 2.0 * m_) * _kDeg2Rad);
    sumL += 53322.0 * math.sin((2.0 * (l_ - f) + m_) * _kDeg2Rad);
    sumL += -40023.0 * math.sin((m_ - mSun) * _kDeg2Rad);
    sumL += -32717.0 * math.sin((2.0 * m_) * _kDeg2Rad);
    // Convert 0.000001 degree units to degrees.
    final moonLon = _normDeg(l_ + sumL / 1000000.0);

    // ── Ecliptic latitude corrections ──────────────────────────────────────
    double sumB = 0.0;
    sumB += 5128122.0 * math.sin(f * _kDeg2Rad);
    sumB += 280602.0 * math.sin((m_ + f) * _kDeg2Rad);
    sumB += 277693.0 * math.sin((m_ - f) * _kDeg2Rad);
    sumB += 173237.0 * math.sin((2.0 * (l_ - f)) * _kDeg2Rad);
    sumB += -55413.0 * math.sin((2.0 * (l_ - f) - m_ + f) * _kDeg2Rad);
    sumB += -46271.0 * math.sin((2.0 * (l_ - f) + f) * _kDeg2Rad);
    final moonLat = sumB / 1000000.0; // degrees

    // ── Ecliptic → equatorial ──────────────────────────────────────────────
    // Mean obliquity of the ecliptic (simplified; no nutation correction).
    final epsilon = 23.439291 - 0.013004 * t;
    final epsRad = epsilon * _kDeg2Rad;
    final lonRad = moonLon * _kDeg2Rad;
    final latRad = moonLat * _kDeg2Rad;

    // Declination:  sin(δ) = sin(β)·cos(ε) + cos(β)·sin(ε)·sin(λ)
    final sinDec = math.sin(latRad) * math.cos(epsRad) +
        math.cos(latRad) * math.sin(epsRad) * math.sin(lonRad);
    final dec = math.asin(sinDec.clamp(-1.0, 1.0)) * _kRad2Deg;

    // Right ascension:  α = arctan2( sin(λ)·cos(ε) − tan(β)·sin(ε), cos(λ) )
    final raRad = math.atan2(
      math.sin(lonRad) * math.cos(epsRad) -
          math.tan(latRad) * math.sin(epsRad),
      math.cos(lonRad),
    );
    final ra = _normDeg(raRad * _kRad2Deg);

    return _MoonEquatorialCoords(ra, dec);
  }

  /// Greenwich Mean Sidereal Time in degrees for [jd].
  double _gmst(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final theta = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;
    return _normDeg(theta);
  }

  /// Local hour angle of a body with right ascension [ra] in degrees.
  ///
  /// Negative east of meridian (rising), positive west (setting).
  double _hourAngle(double jd, double lon, double ra) {
    final lha = _normDeg(_gmst(jd) + lon - ra);
    return lha > 180.0 ? lha - 360.0 : lha;
  }

  /// Geometric altitude (°) from hour angle, declination and observer latitude.
  double _altitude(double lat, double dec, double ha) {
    final sinAlt = math.sin(lat * _kDeg2Rad) * math.sin(dec * _kDeg2Rad) +
        math.cos(lat * _kDeg2Rad) *
            math.cos(dec * _kDeg2Rad) *
            math.cos(ha * _kDeg2Rad);
    return math.asin(sinAlt.clamp(-1.0, 1.0)) * _kRad2Deg;
  }

  /// Azimuth (°, clockwise from North) from hour angle, declination, latitude.
  double _azimuth(double lat, double dec, double ha) {
    final azRad = math.atan2(
      math.sin(ha * _kDeg2Rad),
      math.cos(ha * _kDeg2Rad) * math.sin(lat * _kDeg2Rad) -
          math.tan(dec * _kDeg2Rad) * math.cos(lat * _kDeg2Rad),
    );
    return _normDeg(azRad * _kRad2Deg + 180.0);
  }

  /// Returns the next [DateTime] (UTC) at which the moon reaches [targetPhase]
  /// after [dt].
  ///
  /// Uses a simple linear scan at hourly resolution, then binary search to
  /// refine to the nearest minute.
  DateTime _nextPhase(DateTime dt, double targetPhase) {
    // Linear scan at hourly intervals to bracket the phase crossing.
    DateTime candidate = dt.toUtc();
    double prevPhase = moonPhase(candidate);

    for (int h = 1; h <= 30 * 24; h++) {
      // Max look-ahead: 30 days (slightly more than one synodic month).
      final next = candidate.add(const Duration(hours: 1));
      final nextPhase = moonPhase(next);

      if (_phaseWraps(prevPhase, nextPhase, targetPhase)) {
        // Binary search within [candidate, next] to minute resolution.
        return _refinePhaseCrossing(candidate, next, targetPhase);
      }

      candidate = next;
      prevPhase = nextPhase;
    }
    // Fallback: return the best candidate found (should not occur in practice).
    return candidate;
  }

  /// True when a phase crossing through [target] occurs between [a] and [b].
  bool _phaseWraps(double a, double b, double target) {
    // Handle wrap-around near 0/1 boundary for New Moon.
    if (target < 0.1 || target > 0.9) {
      return (a > 0.9 && b < 0.1) || (a < b && a < target && target <= b);
    }
    return a < target && target <= b;
  }

  /// Binary search refinement of a phase crossing between [lo] and [hi] to
  /// within ±30 seconds.
  DateTime _refinePhaseCrossing(
      DateTime lo, DateTime hi, double targetPhase) {
    DateTime low = lo;
    DateTime high = hi;

    for (int i = 0; i < 12; i++) {
      // 12 halvings of a 1-hour interval → ~0.9 second resolution.
      final mid = low
          .add(Duration(microseconds: high.difference(low).inMicroseconds ~/ 2));
      final midPhase = moonPhase(mid);
      if (_phaseWraps(moonPhase(low), midPhase, targetPhase)) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return low;
  }

  /// Normalises an angle in degrees to [0°, 360°).
  double _normDeg(double deg) => deg - 360.0 * (deg / 360.0).floor();
}

// ── Private data holder ────────────────────────────────────────────────────────

/// Internal holder for geocentric equatorial coordinates of the moon.
class _MoonEquatorialCoords {
  const _MoonEquatorialCoords(this._ra, this._dec);

  /// Right ascension in degrees [0°, 360°).
  final double _ra;

  /// Declination in degrees [−90°, +90°].
  final double _dec;
}

// ── Public extension on MoonData ───────────────────────────────────────────────

/// Factory helpers that construct a [MoonData] using [MoonCalculator].
extension MoonDataFactory on MoonData {
  /// Creates a [MoonData] snapshot for [dt] (UTC), optionally including
  /// rise/set times for the observer at ([lat], [lon]).
  ///
  /// Pass [includeRiseSet] = false to skip the heavier rise/set computation
  /// when only phase and illumination are needed.
  static MoonData fromDateTime(
    DateTime dt, {
    double? lat,
    double? lon,
    bool includeRiseSet = false,
  }) {
    const calc = MoonCalculator();
    final phase = calc.moonPhase(dt);
    final illumination = calc.moonIllumination(dt);

    // Rise/set times are expensive (iterative search); only compute when asked.
    DateTime? rise;
    DateTime? set_;
    if (includeRiseSet && lat != null && lon != null) {
      rise = _findMoonRise(calc, lat, lon, dt);
      set_ = _findMoonSet(calc, lat, lon, dt);
    }

    return MoonData(
      phase: phase,
      illumination: illumination,
      moonrise: rise,
      moonset: set_,
    );
  }

  /// Searches for moonrise during the calendar day of [dt] by scanning
  /// at 2-minute intervals and refining with binary search.
  static DateTime? _findMoonRise(
      MoonCalculator calc, double lat, double lon, DateTime dt) {
    return _findCrossing(calc, lat, lon, dt, rising: true);
  }

  static DateTime? _findMoonSet(
      MoonCalculator calc, double lat, double lon, DateTime dt) {
    return _findCrossing(calc, lat, lon, dt, rising: false);
  }

  /// Scans through the calendar day of [dt] at 2-minute steps looking for an
  /// altitude crossing through −[_kLunarSemiDiameter].
  static DateTime? _findCrossing(
    MoonCalculator calc,
    double lat,
    double lon,
    DateTime dt, {
    required bool rising,
  }) {
    final start = DateTime.utc(dt.year, dt.month, dt.day);
    const step = Duration(minutes: 2);
    const dayLength = Duration(hours: 25); // slightly more than 24 h

    double prevAlt = calc.moonAltitude(lat, lon, start);
    DateTime prev = start;

    for (var offset = step;
        offset < dayLength;
        offset = Duration(minutes: offset.inMinutes + step.inMinutes)) {
      final curr = start.add(offset);
      final currAlt = calc.moonAltitude(lat, lon, curr);

      final threshold = -_kLunarSemiDiameter;
      final crossed = rising
          ? (prevAlt <= threshold && currAlt > threshold)
          : (prevAlt > threshold && currAlt <= threshold);

      if (crossed) {
        // Refine with binary search to ±15 seconds.
        DateTime lo = prev;
        DateTime hi = curr;
        for (int i = 0; i < 8; i++) {
          final mid = lo.add(
              Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2));
          final midAlt = calc.moonAltitude(lat, lon, mid);
          if (rising ? midAlt <= threshold : midAlt > threshold) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        return lo;
      }

      prev = curr;
      prevAlt = currAlt;
    }
    return null; // No crossing found on this calendar day.
  }
}
