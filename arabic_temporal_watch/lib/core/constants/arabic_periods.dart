import 'package:flutter/material.dart';

// ── Period kind ───────────────────────────────────────────────────────────────

/// Whether a temporal period belongs to the day half or the night half.
enum PeriodKind { day, night }

// ── Domain model ─────────────────────────────────────────────────────────────

/// Immutable descriptor for one of the 24 classical Arabic temporal periods.
///
/// The Arabic calendar day is divided into 12 day periods (from sunrise to
/// sunset) and 12 night periods (from sunset to the following sunrise).  Each
/// period carries astronomical, spiritual and poetic significance in Arab
/// culture and is referenced in classical Arabic poetry and Hadith literature.
@immutable
final class ArabicPeriod {
  const ArabicPeriod({
    required this.index,
    required this.kind,
    required this.arabicName,
    required this.transliteration,
    required this.arabicDescription,
    required this.primaryColor,
    required this.secondaryColor,
  });

  /// Zero-based index within the kind (0–11 for day, 0–11 for night).
  final int index;

  /// Whether this period belongs to the day or night half.
  final PeriodKind kind;

  /// Name in Arabic script.
  final String arabicName;

  /// Latin-alphabet transliteration using the ALA-LC scheme.
  final String transliteration;

  /// Short description of the period in Arabic (used in tooltips / detail view).
  final String arabicDescription;

  /// Dominant sky / ambient colour associated with this period.
  final Color primaryColor;

  /// Accent / gradient end colour for smooth ring transitions.
  final Color secondaryColor;

  // ── Convenience getters ──────────────────────────────────────────────────

  /// True when this is one of the 12 daytime periods.
  bool get isDay => kind == PeriodKind.day;

  /// True when this is one of the 12 nighttime periods.
  bool get isNight => kind == PeriodKind.night;

  /// A globally unique index across all 24 periods (day 0–11, night 12–23).
  int get globalIndex => isDay ? index : index + 12;

  @override
  String toString() =>
      'ArabicPeriod($transliteration, ${kind.name}, index: $index)';
}

// ── Day periods (sunrise → sunset) ────────────────────────────────────────────

/// The 12 classical Arabic periods of the daytime, from sunrise to sunset.
///
/// Each period represents roughly 1/12 of the interval between local sunrise
/// and local sunset (a "temporal hour" — an ancient unit that varies with
/// the season and latitude).
const List<ArabicPeriod> kDayPeriods = [
  // ── Period 1 ── الشروق ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 0,
    kind: PeriodKind.day,
    arabicName: 'الشروق',
    transliteration: 'Al-Shurooq',
    arabicDescription:
        'لحظة شروق الشمس من الأفق الشرقي، تبدأ بها ساعات النهار',
    primaryColor: Color(0xFFFF6B35),   // horizon orange
    secondaryColor: Color(0xFFFFB347), // warm amber
  ),

  // ── Period 2 ── البكور ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 1,
    kind: PeriodKind.day,
    arabicName: 'البكور',
    transliteration: 'Al-Bukoor',
    arabicDescription:
        'أول ساعات النهار بعد الشروق، وقت مبارك يُستحب فيه التبكير',
    primaryColor: Color(0xFFFFB347), // warm amber
    secondaryColor: Color(0xFFFFCC70), // light gold
  ),

  // ── Period 3 ── الغدوة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 2,
    kind: PeriodKind.day,
    arabicName: 'الغدوة',
    transliteration: 'Al-Ghadwa',
    arabicDescription:
        'الغدوة: السير في أول النهار، ووقت الخروج إلى الأعمال',
    primaryColor: Color(0xFFFFD166), // golden yellow
    secondaryColor: Color(0xFFFFE08A), // pale gold
  ),

  // ── Period 4 ── الضحى ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 3,
    kind: PeriodKind.day,
    arabicName: 'الضحى',
    transliteration: 'Al-Duha',
    arabicDescription:
        'وقت الضحى حين ترتفع الشمس ويشتد ضوؤها، وفيه صلاة الضحى',
    primaryColor: Color(0xFFFFF176), // bright yellow
    secondaryColor: Color(0xFFFFEE58), // canary
  ),

  // ── Period 5 ── الهاجرة ───────────────────────────────────────────────────
  ArabicPeriod(
    index: 4,
    kind: PeriodKind.day,
    arabicName: 'الهاجرة',
    transliteration: 'Al-Hajira',
    arabicDescription:
        'وقت اشتداد الحر قبيل الزوال، وهي ساعة الاستراحة والقيلولة',
    primaryColor: Color(0xFFFFF9C4), // near-white yellow
    secondaryColor: Color(0xFFFFECB3), // pale amber
  ),

  // ── Period 6 ── الظهيرة ───────────────────────────────────────────────────
  ArabicPeriod(
    index: 5,
    kind: PeriodKind.day,
    arabicName: 'الظهيرة',
    transliteration: 'Al-Dhahira',
    arabicDescription:
        'منتصف النهار الحقيقي، حين تبلغ الشمس ذروتها وتقصر الظلال',
    primaryColor: Color(0xFFFFFFFF), // zenith white
    secondaryColor: Color(0xFFFFF9C4), // warm white
  ),

  // ── Period 7 ── الرواح ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 6,
    kind: PeriodKind.day,
    arabicName: 'الرواح',
    transliteration: 'Al-Rawah',
    arabicDescription:
        'وقت العودة من العمل والسفر، وأول النهار الميّال نحو الغروب',
    primaryColor: Color(0xFFFFE082), // afternoon gold
    secondaryColor: Color(0xFFFFCA28), // amber gold
  ),

  // ── Period 8 ── العصر ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 7,
    kind: PeriodKind.day,
    arabicName: 'العصر',
    transliteration: 'Al-Asr',
    arabicDescription:
        'وقت صلاة العصر، وهو من أفضل الأوقات المذكورة في القرآن الكريم',
    primaryColor: Color(0xFFFFB300), // deep amber
    secondaryColor: Color(0xFFFF8F00), // dark amber
  ),

  // ── Period 9 ── القصر ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 8,
    kind: PeriodKind.day,
    arabicName: 'القصر',
    transliteration: 'Al-Qasr',
    arabicDescription:
        'آخر العصر حين تميل الشمس نحو المغرب وتزداد حمرة الضوء',
    primaryColor: Color(0xFFFF8C00), // dark orange
    secondaryColor: Color(0xFFFF6D00), // deep orange
  ),

  // ── Period 10 ── الأصيل ───────────────────────────────────────────────────
  ArabicPeriod(
    index: 9,
    kind: PeriodKind.day,
    arabicName: 'الأصيل',
    transliteration: 'Al-Aseel',
    arabicDescription:
        'آخر ساعات النهار الجميل، حين يكتسي الأفق بالحمرة والذهب',
    primaryColor: Color(0xFFFF5722), // amber-red
    secondaryColor: Color(0xFFE64A19), // deep red-orange
  ),

  // ── Period 11 ── العشي ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 10,
    kind: PeriodKind.day,
    arabicName: 'العشي',
    transliteration: 'Al-Ashi',
    arabicDescription:
        'المساء الذي يسبق الغروب مباشرة، وقت الرحيل والخشوع',
    primaryColor: Color(0xFFBF360C), // dark crimson
    secondaryColor: Color(0xFF8D1A0E), // deep burgundy
  ),

  // ── Period 12 ── الغروب ───────────────────────────────────────────────────
  ArabicPeriod(
    index: 11,
    kind: PeriodKind.day,
    arabicName: 'الغروب',
    transliteration: 'Al-Ghurubb',
    arabicDescription:
        'لحظة غروب الشمس تحت الأفق، تنتهي بها ساعات النهار وتبدأ المغرب',
    primaryColor: Color(0xFF6A1E4B), // twilight purple-red
    secondaryColor: Color(0xFF4A0E35), // deep dusk
  ),
];

// ── Night periods (sunset → next sunrise) ─────────────────────────────────────

/// The 12 classical Arabic periods of the nighttime, from sunset to sunrise.
///
/// Night periods follow the same temporal-hour system: each is 1/12 of the
/// interval between local sunset and local sunrise.
const List<ArabicPeriod> kNightPeriods = [
  // ── Period 1 ── الشفق ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 0,
    kind: PeriodKind.night,
    arabicName: 'الشفق',
    transliteration: 'Al-Shafaq',
    arabicDescription:
        'الشفق الأحمر الذي يعقب الغروب مباشرة، ويُعدّ نهاية وقت المغرب',
    primaryColor: Color(0xFF4A1942), // twilight purple
    secondaryColor: Color(0xFF3B0F3A), // deep violet
  ),

  // ── Period 2 ── الغسق ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 1,
    kind: PeriodKind.night,
    arabicName: 'الغسق',
    transliteration: 'Al-Ghasaq',
    arabicDescription:
        'اشتداد الظلام بعد زوال الشفق، وهو وقت العشاء عند بعض الأئمة',
    primaryColor: Color(0xFF2E0D4A), // dark indigo
    secondaryColor: Color(0xFF1A0538), // deep navy purple
  ),

  // ── Period 3 ── العتمة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 2,
    kind: PeriodKind.night,
    arabicName: 'العتمة',
    transliteration: 'Al-Atama',
    arabicDescription:
        'أول الليل الداكن وصلاة العشاء، وهو وقت راحة الأبدان',
    primaryColor: Color(0xFF150A3A), // midnight blue-purple
    secondaryColor: Color(0xFF0D061F), // near-black
  ),

  // ── Period 4 ── السدفة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 3,
    kind: PeriodKind.night,
    arabicName: 'السدفة',
    transliteration: 'Al-Sudfa',
    arabicDescription:
        'الظلام الحالك في أوائل الليل، حين تسود الريح ويهدأ الناس',
    primaryColor: Color(0xFF0D0820), // very dark navy
    secondaryColor: Color(0xFF080510), // near-black blue
  ),

  // ── Period 5 ── الفحمة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 4,
    kind: PeriodKind.night,
    arabicName: 'الفحمة',
    transliteration: 'Al-Fahma',
    arabicDescription:
        'أحلك أوقات الليل دواماً، حين يشبه الظلام سواد الفحم',
    primaryColor: Color(0xFF05040F), // coal black
    secondaryColor: Color(0xFF020208), // absolute dark
  ),

  // ── Period 6 ── الزلة ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 5,
    kind: PeriodKind.night,
    arabicName: 'الزلة',
    transliteration: 'Al-Zalla',
    arabicDescription:
        'الربع الثالث من الليل، المقاربة للنصف في الظلام التام',
    primaryColor: Color(0xFF040612), // abyss dark
    secondaryColor: Color(0xFF03050E), // void dark
  ),

  // ── Period 7 ── الزلفة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 6,
    kind: PeriodKind.night,
    arabicName: 'الزلفة',
    transliteration: 'Al-Zulfa',
    arabicDescription:
        'منتصف الليل الحقيقي، وزلفات الليل المذكورة في القرآن الكريم',
    primaryColor: Color(0xFF05081A), // deepest midnight
    secondaryColor: Color(0xFF030614), // dark midnight blue
  ),

  // ── Period 8 ── البهرة ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 7,
    kind: PeriodKind.night,
    arabicName: 'البهرة',
    transliteration: 'Al-Bahra',
    arabicDescription:
        'النصف الثاني من الليل، حين يبدأ الكون في الاستعداد للفجر',
    primaryColor: Color(0xFF070B1F), // post-midnight
    secondaryColor: Color(0xFF0B1030), // hint of blue
  ),

  // ── Period 9 ── السحر ─────────────────────────────────────────────────────
  ArabicPeriod(
    index: 8,
    kind: PeriodKind.night,
    arabicName: 'السحر',
    transliteration: 'Al-Sahar',
    arabicDescription:
        'وقت السحر قبيل الفجر، من أفضل أوقات الدعاء والاستغفار',
    primaryColor: Color(0xFF0D1540), // pre-dawn navy
    secondaryColor: Color(0xFF151E5A), // dawn-approaching blue
  ),

  // ── Period 10 ── الفجر ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 9,
    kind: PeriodKind.night,
    arabicName: 'الفجر',
    transliteration: 'Al-Fajr',
    arabicDescription:
        'انبلاج الفجر الصادق، أول أوقات الصلاة وبداية نهاية الليل',
    primaryColor: Color(0xFF1A2A7A), // fajr blue
    secondaryColor: Color(0xFF2E3FA0), // pre-dawn blue
  ),

  // ── Period 11 ── الصبح ────────────────────────────────────────────────────
  ArabicPeriod(
    index: 10,
    kind: PeriodKind.night,
    arabicName: 'الصبح',
    transliteration: 'Al-Subh',
    arabicDescription:
        'أول ضوء الصباح قبل شروق الشمس، وقت صلاة الفجر',
    primaryColor: Color(0xFF3A5BA8), // morning blue
    secondaryColor: Color(0xFF6A8FD0), // light dawn blue
  ),

  // ── Period 12 ── الصباح ───────────────────────────────────────────────────
  ArabicPeriod(
    index: 11,
    kind: PeriodKind.night,
    arabicName: 'الصباح',
    transliteration: 'Al-Sabah',
    arabicDescription:
        'إشراق أنوار الصباح قبيل الشروق، حين يعود النهار من جديد',
    primaryColor: Color(0xFF7BAFD4), // pale morning sky
    secondaryColor: Color(0xFFADD6EC), // light sky approaching sunrise
  ),
];

// ── Combined list ─────────────────────────────────────────────────────────────

/// All 24 periods in a single list: 12 day periods followed by 12 night periods.
const List<ArabicPeriod> kAllPeriods = [...kDayPeriods, ...kNightPeriods];

// ── Lookup helpers ─────────────────────────────────────────────────────────────

/// Returns the day period at [index] (0–11).
///
/// Throws [RangeError] if [index] is out of bounds.
ArabicPeriod dayPeriodAt(int index) => kDayPeriods[index];

/// Returns the night period at [index] (0–11).
///
/// Throws [RangeError] if [index] is out of bounds.
ArabicPeriod nightPeriodAt(int index) => kNightPeriods[index];

/// Returns the period matching [globalIndex] where 0–11 are day and 12–23
/// are night.  Throws [RangeError] if [globalIndex] is out of range.
ArabicPeriod periodByGlobalIndex(int globalIndex) {
  RangeError.checkValueInInterval(globalIndex, 0, 23, 'globalIndex');
  return kAllPeriods[globalIndex];
}

/// Finds the [ArabicPeriod] whose [ArabicPeriod.transliteration] matches
/// [transliteration] (case-insensitive).  Returns `null` if not found.
ArabicPeriod? periodByTransliteration(String transliteration) {
  final lower = transliteration.toLowerCase();
  try {
    return kAllPeriods.firstWhere(
      (p) => p.transliteration.toLowerCase() == lower,
    );
  } on StateError {
    return null;
  }
}
