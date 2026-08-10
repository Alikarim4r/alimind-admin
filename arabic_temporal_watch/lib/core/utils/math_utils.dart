/// Mathematical utility functions used by the astronomical engine and
/// watch-face rendering code.
///
/// All angle operations follow the convention:
///   * Degrees are the user-facing unit (Arabic astronomy uses degrees).
///   * Radians are the internal computation unit (Dart's [math] library).
///   * Normalised angles are in the range [0, 360).
///
/// Julian Day numbers (JD) follow the astronomical standard where JD 0 is
/// 1 January 4713 BC noon UTC (proleptic Julian calendar).
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;

// ── Constants ─────────────────────────────────────────────────────────────────

/// π — expose locally so callers don't need to import dart:math.
const double pi = math.pi;

/// 2π.
const double twoPi = 2.0 * math.pi;

/// π / 2.
const double halfPi = math.pi / 2.0;

/// Degrees → radians conversion factor.
const double degToRad = math.pi / 180.0;

/// Radians → degrees conversion factor.
const double radToDeg = 180.0 / math.pi;

/// Julian Day number for J2000.0 (1 January 2000 12:00 TT).
const double kJ2000 = 2451545.0;

/// Julian Day number for the Unix epoch (1 January 1970 00:00 UTC).
const double kJDUnixEpoch = 2440587.5;

// ── Angle conversions ─────────────────────────────────────────────────────────

/// Converts [degrees] to radians.
///
/// ```dart
/// final rad = degreesToRadians(180.0); // 3.14159…
/// ```
double degreesToRadians(double degrees) => degrees * degToRad;

/// Converts [radians] to degrees.
///
/// ```dart
/// final deg = radiansToDegrees(math.pi); // 180.0
/// ```
double radiansToDegrees(double radians) => radians * radToDeg;

// ── Angle normalisation ───────────────────────────────────────────────────────

/// Returns [angle] (in degrees) normalised to the range [0, 360).
///
/// Works correctly for large positive values, negative values, and values
/// that are already in range.
///
/// ```dart
/// normalizeAngle(370.0);  // 10.0
/// normalizeAngle(-10.0);  // 350.0
/// normalizeAngle(0.0);    // 0.0
/// normalizeAngle(360.0);  // 0.0
/// ```
double normalizeAngle(double angle) {
  final result = angle % 360.0;
  return result < 0.0 ? result + 360.0 : result;
}

/// Returns [radians] normalised to the range [0, 2π).
double normalizeRadians(double radians) {
  final result = radians % twoPi;
  return result < 0.0 ? result + twoPi : result;
}

/// Returns the shortest signed angular difference from [from] to [to] in
/// degrees, in the range (-180, 180].
///
/// Positive means counter-clockwise (forward); negative means clockwise.
///
/// ```dart
/// angularDifference(350.0, 10.0);  // 20.0
/// angularDifference(10.0, 350.0);  // -20.0
/// ```
double angularDifference(double from, double to) {
  final diff = normalizeAngle(to - from);
  return diff > 180.0 ? diff - 360.0 : diff;
}

// ── Interpolation ─────────────────────────────────────────────────────────────

/// Linear interpolation between [a] and [b] by factor [t].
///
/// [t] is not clamped — values outside [0, 1] extrapolate beyond the range.
/// Use [lerpClamped] if you need a guarantee that the result stays within
/// [[a], [b]].
///
/// ```dart
/// lerp(0.0, 100.0, 0.25); // 25.0
/// ```
double lerp(double a, double b, double t) => a + (b - a) * t;

/// Linearly interpolates between [a] and [b] with [t] clamped to [0, 1].
double lerpClamped(double a, double b, double t) =>
    lerp(a, b, clamp(t, 0.0, 1.0));

/// Clamps [value] to the inclusive range [[min], [max]].
///
/// Asserts that [min] ≤ [max] in debug mode.
double clamp(double value, double min, double max) {
  assert(min <= max, 'clamp: min ($min) must be ≤ max ($max)');
  return value < min ? min : (value > max ? max : value);
}

/// Integer clamp.
int clampInt(int value, int min, int max) {
  assert(min <= max, 'clampInt: min ($min) must be ≤ max ($max)');
  return value < min ? min : (value > max ? max : value);
}

/// Returns the inverse-lerp factor [t] such that `lerp(a, b, t) == value`.
///
/// Returns 0.5 if [a] == [b] (degenerate case).
double inverseLerp(double a, double b, double value) {
  if ((b - a).abs() < 1e-10) return 0.5;
  return (value - a) / (b - a);
}

/// Remaps [value] from the input range [[inMin], [inMax]] to the output range
/// [[outMin], [outMax]], clamping the input before remapping.
///
/// ```dart
/// remap(50.0, 0.0, 100.0, 0.0, 1.0); // 0.5
/// ```
double remap(
  double value,
  double inMin,
  double inMax,
  double outMin,
  double outMax,
) {
  final t = clamp(inverseLerp(inMin, inMax, value), 0.0, 1.0);
  return lerp(outMin, outMax, t);
}

/// Interpolates between two angles in degrees taking the shortest arc,
/// avoiding the 0°/360° discontinuity.
///
/// ```dart
/// circularLerp(350.0, 10.0, 0.5); // 0.0  (not 180.0)
/// ```
double circularLerp(double fromDeg, double toDeg, double t) {
  final diff = angularDifference(fromDeg, toDeg);
  return normalizeAngle(fromDeg + diff * t);
}

// ── Trigonometry helpers ──────────────────────────────────────────────────────

/// Sine of [degrees].
double sinDeg(double degrees) => math.sin(degreesToRadians(degrees));

/// Cosine of [degrees].
double cosDeg(double degrees) => math.cos(degreesToRadians(degrees));

/// Tangent of [degrees].
double tanDeg(double degrees) => math.tan(degreesToRadians(degrees));

/// Arc-sine returning degrees.
double asinDeg(double x) => radiansToDegrees(math.asin(x.clamp(-1.0, 1.0)));

/// Arc-cosine returning degrees.
double acosDeg(double x) => radiansToDegrees(math.acos(x.clamp(-1.0, 1.0)));

/// Arc-tangent of [y]/[x] (atan2) returning degrees in [0, 360).
double atan2Deg(double y, double x) =>
    normalizeAngle(radiansToDegrees(math.atan2(y, x)));

// ── Julian Day ────────────────────────────────────────────────────────────────

/// Computes the Julian Day Number (JD) for a [DateTime].
///
/// Supports UTC and local [DateTime] objects.  Local times are converted to
/// UTC before the calculation so the result is always in the TT/UTC frame
/// used by astronomical formulae (the difference between TT and UTC is
/// ΔT ≈ 69 s as of 2025 — neglected here for watch-face accuracy).
///
/// Algorithm: Meeus, "Astronomical Algorithms" 2nd ed., Chapter 7.
///
/// ```dart
/// final jd = julianDay(DateTime.utc(2000, 1, 1, 12));
/// // jd ≈ 2451545.0  (J2000.0)
/// ```
double julianDay(DateTime dateTime) {
  final utc = dateTime.toUtc();
  int y = utc.year;
  int m = utc.month;
  final d = utc.day +
      (utc.hour + utc.minute / 60.0 + utc.second / 3600.0 +
              utc.millisecond / 3_600_000.0) /
          24.0;

  if (m <= 2) {
    y -= 1;
    m += 12;
  }

  final a = (y / 100).floor();
  // Gregorian calendar correction (valid from 15 October 1582 onwards).
  final b = 2 - a + (a / 4).floor();

  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      d +
      b -
      1524.5;
}

/// Returns Julian centuries since J2000.0 for [dateTime].
///
/// Used by most solar/lunar position algorithms.
double julianCenturies(DateTime dateTime) =>
    (julianDay(dateTime) - kJ2000) / 36525.0;

/// Returns Julian millenia since J2000.0 for [dateTime].
double julianMillenia(DateTime dateTime) =>
    (julianDay(dateTime) - kJ2000) / 365250.0;

// ── Sidereal time ─────────────────────────────────────────────────────────────

/// Computes the Greenwich Mean Sidereal Time (GMST) in degrees for [dateTime].
///
/// Uses the IAU 1982 formula accurate to ±0.1″ over a century.
/// Result is normalised to [0, 360).
///
/// ```dart
/// final gmst = greenwichMeanSiderealTime(DateTime.utc(2000, 1, 1, 12));
/// // gmst ≈ 280.46061837°  (matches J2000.0 reference)
/// ```
double greenwichMeanSiderealTime(DateTime dateTime) {
  final jd = julianDay(dateTime);
  final t = (jd - kJ2000) / 36525.0;

  // Meeus eq. 12.4 (degrees)
  var gmst = 280.46061837 +
      360.98564736629 * (jd - kJ2000) +
      0.000387933 * t * t -
      (t * t * t) / 38710000.0;

  return normalizeAngle(gmst);
}

/// Computes the Local Sidereal Time (LST) in degrees for an observer at
/// [longitudeDeg] (positive east, negative west).
///
/// Result is normalised to [0, 360).
double localSiderealTime(DateTime dateTime, double longitudeDeg) =>
    normalizeAngle(greenwichMeanSiderealTime(dateTime) + longitudeDeg);

// ── Solar position helpers ────────────────────────────────────────────────────

/// Computes the Sun's mean longitude (degrees) for Julian centuries [T].
///
/// Meeus eq. 27.2.
double sunMeanLongitude(double T) =>
    normalizeAngle(280.46646 + 36000.76983 * T + 0.0003032 * T * T);

/// Computes the Sun's mean anomaly (degrees) for Julian centuries [T].
///
/// Meeus eq. 27.3.
double sunMeanAnomaly(double T) =>
    normalizeAngle(357.52911 + 35999.05029 * T - 0.0001537 * T * T);

/// Computes the Sun's equation of centre (degrees) — the correction from mean
/// to true anomaly — for mean anomaly [M] (degrees) and Julian centuries [T].
double sunEquationOfCentre(double M, double T) {
  return sinDeg(M) * (1.914602 - T * (0.004817 + 0.000014 * T)) +
      sinDeg(2 * M) * (0.019993 - 0.000101 * T) +
      sinDeg(3 * M) * 0.000289;
}

/// Computes the Sun's true longitude (degrees) for Julian centuries [T].
double sunTrueLongitude(double T) {
  final L0 = sunMeanLongitude(T);
  final M = sunMeanAnomaly(T);
  return normalizeAngle(L0 + sunEquationOfCentre(M, T));
}

/// Computes the Sun's apparent longitude (degrees), applying the correction
/// for the aberration of light and nutation for Julian centuries [T].
double sunApparentLongitude(double T) {
  final trueLon = sunTrueLongitude(T);
  final omega = normalizeAngle(125.04 - 1934.136 * T);
  return normalizeAngle(trueLon - 0.00569 - 0.00478 * sinDeg(omega));
}

// ── Vector2 utilities ─────────────────────────────────────────────────────────

/// Returns a unit [Vector2] pointing in the direction of [angleDeg] measured
/// clockwise from the top (12 o'clock position), matching the canvas
/// coordinate system where the y-axis points downward.
///
/// This is the standard convention for clock hands and watch-ring indicators.
///
/// ```dart
/// final v = unitVectorFromClockAngle(90.0); // → Vector2(1, 0)  (3 o'clock)
/// ```
Vector2 unitVectorFromClockAngle(double angleDeg) {
  // Convert clockwise-from-top to standard math angle (CCW from east):
  // mathAngle = 90° - clockAngle
  final rad = degreesToRadians(90.0 - angleDeg);
  return Vector2(math.cos(rad), -math.sin(rad)); // y down in canvas
}

/// Returns a [Vector2] from polar coordinates [r], [angleDeg] (clockwise from
/// top) in the canvas coordinate system.
Vector2 polarToCanvasVector(double r, double angleDeg) =>
    unitVectorFromClockAngle(angleDeg).scaled(r);

/// Computes the dot product of two [Vector2] objects.
double dot2(Vector2 a, Vector2 b) => a.x * b.x + a.y * b.y;

/// Returns the angle in degrees between two [Vector2] objects.
double angleBetween(Vector2 a, Vector2 b) {
  final cosTheta = dot2(a.normalized(), b.normalized()).clamp(-1.0, 1.0);
  return radiansToDegrees(math.acos(cosTheta));
}

/// Rotates [v] by [angleDeg] counter-clockwise.
Vector2 rotateVector(Vector2 v, double angleDeg) {
  final rad = degreesToRadians(angleDeg);
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);
  return Vector2(
    v.x * cosA - v.y * sinA,
    v.x * sinA + v.y * cosA,
  );
}

// ── Miscellaneous ─────────────────────────────────────────────────────────────

/// Returns the fractional part of [value] (value - floor(value)).
double fractional(double value) => value - value.floorToDouble();

/// Converts decimal hours [h] (e.g. 13.5) to clock angle in degrees
/// (0° at top / noon for 12-hour, 360° = full rotation).
///
/// For a 12-hour face: 12 h = 360°, so 1 h = 30°.
double decimalHoursToClockAngle12(double h) =>
    normalizeAngle((h % 12.0) * 30.0);

/// For a 24-hour face: 24 h = 360°, so 1 h = 15°.
double decimalHoursToClockAngle24(double h) =>
    normalizeAngle((h % 24.0) * 15.0);

/// Converts decimal degrees, minutes, seconds to decimal degrees.
double dmsToDecimalDegrees(double degrees, double minutes, double seconds) =>
    degrees + minutes / 60.0 + seconds / 3600.0;

/// Wraps a value into [-180, 180] (signed normalisation).
double wrapSigned180(double deg) {
  double d = deg % 360.0;
  if (d < -180.0) d += 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Smooth-steps [t] using the classic 3t²−2t³ Hermite polynomial,
/// producing an S-curve that eases in and out.
///
/// [t] should be in [0, 1]; result is also in [0, 1].
double smoothStep(double t) {
  final tc = clamp(t, 0.0, 1.0);
  return tc * tc * (3.0 - 2.0 * tc);
}

/// Smooth-steps with a smoother C2-continuous quintic (6t⁵−15t⁴+10t³).
double smootherStep(double t) {
  final tc = clamp(t, 0.0, 1.0);
  return tc * tc * tc * (tc * (tc * 6.0 - 15.0) + 10.0);
}
