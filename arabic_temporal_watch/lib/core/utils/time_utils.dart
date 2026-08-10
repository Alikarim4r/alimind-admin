/// Time-related utility functions used throughout the Arabic Temporal Watch app.
///
/// Covers conversions between Dart's [DateTime] / [TimeOfDay] / [Duration]
/// types and the decimal-hours representation used by astronomical algorithms,
/// as well as Arabic-language formatting of durations and times.
///
/// All functions are pure and side-effect-free unless otherwise noted.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

// ── Decimal hours ─────────────────────────────────────────────────────────────

/// Converts a [DateTime] to decimal hours since midnight (local time).
///
/// For example, 13:30:00 → 13.5, 00:00:00 → 0.0, 23:59:59 → ≈ 23.9997.
///
/// ```dart
/// final dt = DateTime(2025, 1, 1, 13, 30, 0);
/// decimalHours(dt); // 13.5
/// ```
double decimalHours(DateTime dateTime) {
  return dateTime.hour +
      dateTime.minute / 60.0 +
      dateTime.second / 3600.0 +
      dateTime.millisecond / 3_600_000.0;
}

/// Converts decimal hours [h] to a [TimeOfDay].
///
/// Wraps around at 24 h, so 25.5 → TimeOfDay(hour: 1, minute: 30).
///
/// ```dart
/// decimalHoursToTimeOfDay(13.5); // TimeOfDay(hour: 13, minute: 30)
/// ```
TimeOfDay decimalHoursToTimeOfDay(double h) {
  final normalised = h % 24.0;
  final totalMinutes = (normalised * 60.0).round();
  return TimeOfDay(
    hour: (totalMinutes ~/ 60) % 24,
    minute: totalMinutes % 60,
  );
}

/// Converts a [TimeOfDay] to decimal hours.
///
/// ```dart
/// timeOfDayToDecimalHours(TimeOfDay(hour: 13, minute: 30)); // 13.5
/// ```
double timeOfDayToDecimalHours(TimeOfDay tod) =>
    tod.hour + tod.minute / 60.0;

/// Converts decimal hours [h] to a [Duration] since midnight.
///
/// ```dart
/// decimalHoursToDuration(1.5); // Duration(hours: 1, minutes: 30)
/// ```
Duration decimalHoursToDuration(double h) {
  final totalSeconds = (h * 3600.0).round();
  return Duration(seconds: totalSeconds);
}

/// Converts a [Duration] to decimal hours.
///
/// ```dart
/// durationToDecimalHours(Duration(hours: 1, minutes: 30)); // 1.5
/// ```
double durationToDecimalHours(Duration duration) =>
    duration.inSeconds / 3600.0;

// ── DateTime construction ─────────────────────────────────────────────────────

/// Creates a [DateTime] by combining [date]'s year/month/day with the time
/// expressed as decimal hours [h].
///
/// The returned value uses the same timezone-awareness (local vs UTC) as [date].
///
/// ```dart
/// final noon = dateTimeAtDecimalHours(DateTime(2025, 6, 1), 12.0);
/// // DateTime(2025, 6, 1, 12, 0, 0)
/// ```
DateTime dateTimeAtDecimalHours(DateTime date, double h) {
  final totalSeconds = (h * 3600.0).round();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  return date.isUtc
      ? DateTime.utc(date.year, date.month, date.day, hours, minutes, seconds)
      : DateTime(date.year, date.month, date.day, hours, minutes, seconds);
}

/// Returns a [DateTime] for midnight (00:00:00.000) of the given [date],
/// preserving its UTC or local status.
DateTime midnight(DateTime date) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day)
    : DateTime(date.year, date.month, date.day);

// ── HH:MM string formatting ────────────────────────────────────────────────────

/// Formats a [TimeOfDay] as "HH:MM" using 24-hour notation with zero-padded
/// fields.
///
/// ```dart
/// formatTimeOfDay24(TimeOfDay(hour: 9, minute: 5)); // "09:05"
/// ```
String formatTimeOfDay24(TimeOfDay tod) {
  final h = tod.hour.toString().padLeft(2, '0');
  final m = tod.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats decimal hours [h] as "HH:MM" (24-hour, zero-padded).
///
/// ```dart
/// formatDecimalHours24(9.083); // "09:05"
/// ```
String formatDecimalHours24(double h) =>
    formatTimeOfDay24(decimalHoursToTimeOfDay(h));

/// Formats decimal hours [h] as "H:MM AM/PM" for 12-hour display.
///
/// Returns Arabic AM/PM strings (ص / م).
String formatDecimalHoursArabic12(double h) {
  final tod = decimalHoursToTimeOfDay(h);
  final hour12 = tod.hour % 12 == 0 ? 12 : tod.hour % 12;
  final amPm = tod.hour < 12 ? 'ص' : 'م'; // صباح / مساء abbreviated
  final m = tod.minute.toString().padLeft(2, '0');
  return '$hour12:$m $amPm';
}

// ── Arabic duration strings ───────────────────────────────────────────────────

/// Eastern Arabic-Indic digit characters (٠١٢٣٤٥٦٧٨٩).
///
/// Used to render digits in the Arabic numeral style expected in Arabic UI.
const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts an integer [n] to Eastern Arabic-Indic numeral string.
///
/// ```dart
/// toArabicNumerals(1430); // "١٤٣٠"
/// ```
String toArabicNumerals(int n) {
  if (n < 0) return '−${toArabicNumerals(-n)}';
  return n.toString().split('').map((c) {
    final digit = int.tryParse(c);
    return digit != null ? _arabicDigits[digit] : c;
  }).join();
}

/// Formats a [Duration] as a natural Arabic string.
///
/// Examples:
///   * 3 h 15 min → "ثلاث ساعات وخمسة عشر دقيقة"  (uses Arabic numerals)
///   * 0 h 45 min → "خمسة وأربعون دقيقة"
///   * 0 h 0 min 30 s → "ثلاثون ثانية"
///
/// For UI contexts that prefer compact numeral strings, use
/// [formatDurationCompactArabic] instead.
String formatDurationArabic(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  final parts = <String>[];

  if (h > 0) {
    parts.add('${toArabicNumerals(h)} ${_hoursLabel(h)}');
  }
  if (m > 0) {
    parts.add('${toArabicNumerals(m)} ${_minutesLabel(m)}');
  }
  if (s > 0 && h == 0) {
    // Only show seconds when the duration is less than one hour.
    parts.add('${toArabicNumerals(s)} ${_secondsLabel(s)}');
  }

  if (parts.isEmpty) return 'الآن';
  return parts.join(' و');
}

/// Formats a [Duration] as a compact Arabic numeral string: "H:MM:SS" or
/// "MM:SS" for durations under one hour, using Eastern Arabic-Indic digits.
///
/// ```dart
/// formatDurationCompactArabic(Duration(hours: 1, minutes: 5, seconds: 9));
/// // "١:٠٥:٠٩"
/// formatDurationCompactArabic(Duration(minutes: 5, seconds: 9));
/// // "٠٥:٠٩"
/// ```
String formatDurationCompactArabic(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  final mm = toArabicNumerals(m).padLeft(2, '٠');
  final ss = toArabicNumerals(s).padLeft(2, '٠');

  if (h > 0) {
    return '${toArabicNumerals(h)}:$mm:$ss';
  }
  return '$mm:$ss';
}

/// Formats a [Duration] as a concise Arabic countdown string, showing only
/// the most significant non-zero unit.
///
/// Used for "next prayer in X" display on the watch face.
///
/// Examples:
///   * 90 min → "ساعة ونصف"
///   * 45 min → "٤٥ دقيقة"
///   * 5 min  → "٥ دقائق"
///   * 30 s   → "٣٠ ثانية"
String formatCountdownArabic(Duration remaining) {
  final totalSeconds = remaining.inSeconds.abs();

  if (totalSeconds >= 3600) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (m == 30) return '${_hoursLabel(h)} ونصف';
    if (m == 0)  return '${toArabicNumerals(h)} ${_hoursLabel(h)}';
    return '${toArabicNumerals(h)} ${_hoursLabel(h)} و${toArabicNumerals(m)} دقيقة';
  }

  if (totalSeconds >= 60) {
    final m = totalSeconds ~/ 60;
    return '${toArabicNumerals(m)} ${_minutesLabel(m)}';
  }

  return '${toArabicNumerals(totalSeconds)} ${_secondsLabel(totalSeconds)}';
}

// ── Minutes to Arabic text (cardinal numbers) ─────────────────────────────────

/// Converts [minutes] (0–59) to its Arabic cardinal string.
///
/// The result uses the masculine form appropriate for "minutes" (دقيقة) which
/// is feminine in Arabic, so adjectives use the masculine form per Arabic
/// grammar rules for counting.
///
/// Handles:
///   * Units: ١–٩
///   * Teens: ١١–١٩
///   * Tens: ١٠, ٢٠, …, ٥٠
///   * Compound: ٢١–٢٩, ٣١–٣٩, ٤١–٤٩, ٥١–٥٩
///
/// Falls back to Eastern Arabic-Indic numeral string for any value outside
/// [0, 59].
String minutesToArabicText(int minutes) {
  if (minutes < 0 || minutes > 59) return toArabicNumerals(minutes);

  switch (minutes) {
    case 0:  return 'صفر';
    case 1:  return 'واحدة';
    case 2:  return 'اثنتان';
    case 3:  return 'ثلاث';
    case 4:  return 'أربع';
    case 5:  return 'خمس';
    case 6:  return 'ست';
    case 7:  return 'سبع';
    case 8:  return 'ثماني';
    case 9:  return 'تسع';
    case 10: return 'عشر';
    case 11: return 'إحدى عشرة';
    case 12: return 'اثنتا عشرة';
    case 13: return 'ثلاث عشرة';
    case 14: return 'أربع عشرة';
    case 15: return 'خمس عشرة';
    case 16: return 'ست عشرة';
    case 17: return 'سبع عشرة';
    case 18: return 'ثماني عشرة';
    case 19: return 'تسع عشرة';
    case 20: return 'عشرون';
    case 30: return 'ثلاثون';
    case 40: return 'أربعون';
    case 50: return 'خمسون';
    default:
      final tens = (minutes ~/ 10) * 10;
      final units = minutes % 10;
      final tensText = minutesToArabicText(tens);
      final unitsText = minutesToArabicText(units);
      return '$unitsText و$tensText';
  }
}

// ── Period progress ───────────────────────────────────────────────────────────

/// Returns the progress through the current day or night as a value in [0, 1].
///
/// [nowDecimalHours] — current time as decimal hours.
/// [startDecimalHours] — start of the current period as decimal hours.
/// [endDecimalHours] — end of the current period as decimal hours.
///
/// Handles periods that cross midnight (end < start) correctly.
double periodProgress({
  required double nowDecimalHours,
  required double startDecimalHours,
  required double endDecimalHours,
}) {
  double duration = endDecimalHours - startDecimalHours;
  double elapsed  = nowDecimalHours - startDecimalHours;

  // Cross-midnight case: e.g. period from 23.0 to 1.0 h.
  if (duration < 0) duration += 24.0;
  if (elapsed  < 0) elapsed  += 24.0;

  if (duration <= 0.0) return 0.0;
  return (elapsed / duration).clamp(0.0, 1.0);
}

// ── Hijri month names ─────────────────────────────────────────────────────────

/// The 12 Hijri (Islamic lunar calendar) month names in Arabic.
const List<String> kHijriMonthNames = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الثاني',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

/// Returns the Arabic name for Hijri month [month] (1-indexed).
///
/// Throws [RangeError] if [month] is not in [1, 12].
String hijriMonthName(int month) {
  RangeError.checkValueInInterval(month, 1, 12, 'month');
  return kHijriMonthNames[month - 1];
}

/// The 7 Arabic day-of-week names, starting from Sunday (index 0).
const List<String> kArabicWeekdays = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

/// Returns the Arabic day name for [weekday] using the [DateTime.weekday]
/// convention (1 = Monday … 7 = Sunday).
String arabicWeekdayName(int weekday) {
  // DateTime.weekday: 1=Mon, 7=Sun. Our list: 0=Sun, 1=Mon, …, 6=Sat.
  final index = weekday % 7; // 1→1, 7→0
  return kArabicWeekdays[index];
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// Returns the Arabic word for "hours" correctly inflected for [count].
String _hoursLabel(int count) {
  if (count == 1) return 'ساعة';
  if (count == 2) return 'ساعتان';
  if (count <= 10) return 'ساعات';
  return 'ساعة';
}

/// Returns the Arabic word for "minutes" correctly inflected for [count].
String _minutesLabel(int count) {
  if (count == 1) return 'دقيقة';
  if (count == 2) return 'دقيقتان';
  if (count <= 10) return 'دقائق';
  return 'دقيقة';
}

/// Returns the Arabic word for "seconds" correctly inflected for [count].
String _secondsLabel(int count) {
  if (count == 1) return 'ثانية';
  if (count == 2) return 'ثانيتان';
  if (count <= 10) return 'ثوانٍ';
  return 'ثانية';
}

// ── TimeUtils class ───────────────────────────────────────────────────────────

/// Static facade over all time utility functions.
///
/// Every method delegates to the corresponding top-level function defined
/// above, so callers may use either the class style (`TimeUtils.toDecimalHours`)
/// or the function style (`decimalHours`) — both are equivalent.
///
/// The class interface is the contract described in the design specification;
/// the top-level functions are the canonical implementation.
abstract final class TimeUtils {
  TimeUtils._();

  // ── Decimal hours ─────────────────────────────────────────────────────────

  /// Convert [dt] to decimal hours since midnight (e.g. 14:30 → 14.5).
  ///
  /// See top-level [decimalHours].
  static double toDecimalHours(DateTime dt) => decimalHours(dt);

  // ── Duration formatting ───────────────────────────────────────────────────

  /// Format [d] as a natural Arabic string (e.g. "٤٥ دقيقة").
  ///
  /// Mirrors the top-level [formatDurationArabic] function.
  static String formatDurationArabic(Duration d) {
    final totalSeconds = d.inSeconds.abs();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    final parts = <String>[];
    if (h > 0) parts.add('${toArabicNumerals(h)} ${_hoursLabel(h)}');
    if (m > 0) parts.add('${toArabicNumerals(m)} ${_minutesLabel(m)}');
    if (s > 0 && h == 0) parts.add('${toArabicNumerals(s)} ${_secondsLabel(s)}');
    if (parts.isEmpty) return 'الآن';
    return parts.join(' و');
  }

  // ── Time formatting ───────────────────────────────────────────────────────

  /// Format [dt] as "H:MM ص/م" in Arabic-Indic numerals.
  ///
  /// Uses a 12-hour clock with Arabic AM/PM suffix (ص = am, م = pm).
  ///
  /// Example: DateTime(2025, 1, 1, 13, 30) → "١:٣٠ م"
  static String formatTimeArabic(DateTime dt) {
    final hour24 = dt.hour;
    final minute = dt.minute;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final amPm = hour24 < 12 ? 'ص' : 'م';
    final mStr = toArabicNumerals(minute).padLeft(2, '٠');
    return '${toArabicNumerals(hour12)}:$mStr $amPm';
  }

  // ── Numeral conversion ────────────────────────────────────────────────────

  /// Convert [n] to Eastern Arabic-Indic numeral string (e.g. 45 → "٤٥").
  ///
  /// Mirrors the top-level [toArabicNumerals] function.
  static String toArabicNumerals(int n) {
    if (n < 0) return '−${toArabicNumerals(-n)}';
    return n.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? _arabicDigits[d] : c;
    }).join();
  }

  // ── Days until ────────────────────────────────────────────────────────────

  /// Number of whole days from today (local) until [target].
  ///
  /// Returns 0 if [target] is today or in the past.
  ///
  /// Example:
  /// ```dart
  /// TimeUtils.daysUntil(DateTime.now().add(const Duration(days: 3))); // 3
  /// ```
  static int daysUntil(DateTime target) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight =
        DateTime(target.year, target.month, target.day);
    final diff = targetMidnight.difference(todayMidnight).inDays;
    return diff < 0 ? 0 : diff;
  }

  // ── Daytime check ─────────────────────────────────────────────────────────

  /// Returns `true` when [now] falls between [sunrise] and [sunset].
  ///
  /// Only the time-of-day component is considered; the date parts are ignored.
  ///
  /// Example:
  /// ```dart
  /// TimeUtils.isDaytime(
  ///   DateTime(2025, 6, 1, 14, 0),   // 14:00
  ///   DateTime(2025, 6, 1,  5, 30),  // sunrise 05:30
  ///   DateTime(2025, 6, 1, 19, 45),  // sunset  19:45
  /// ); // true
  /// ```
  static bool isDaytime(DateTime now, DateTime sunrise, DateTime sunset) {
    final nowH = decimalHours(now);
    final riseH = decimalHours(sunrise);
    final setH = decimalHours(sunset);
    return nowH >= riseH && nowH < setH;
  }
}
