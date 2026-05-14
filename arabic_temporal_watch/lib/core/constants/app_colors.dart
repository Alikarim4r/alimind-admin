import 'package:flutter/material.dart';

/// Luxury color palette for the Arabic Temporal Watch app.
///
/// All colors are organized into named semantic groups.  Every constant is a
/// compile-time [Color] so it can be used in `const` widget constructors.
///
/// Naming convention:
///   * Group prefix in camelCase (e.g. `background`, `gold`, `prayer`).
///   * Suffix indicates lightness / variant (e.g. `Deep`, `Mid`, `Light`).
abstract final class AppColors {
  // ── Background ─────────────────────────────────────────────────────────────
  // Deep space / night-sky base layers for the watch face.

  /// Deepest background — near-black navy used for the outermost canvas.
  static const Color backgroundDeep = Color(0xFF02040F);

  /// Mid-depth background — the primary watch-body fill colour.
  static const Color backgroundMid = Color(0xFF05081A);

  /// Slightly lighter surface for elevated cards and panels.
  static const Color backgroundSurface = Color(0xFF0A0E2A);

  /// Subtle card / popover background with a hint of blue.
  static const Color backgroundCard = Color(0xFF0E1235);

  // ── Gold / amber accent ────────────────────────────────────────────────────
  // The primary accent — evokes Islamic geometric art, illuminated manuscripts.

  /// Rich 18-karat gold — primary accent for ring borders, labels, icons.
  static const Color goldPrimary = Color(0xFFD4AF37);

  /// Bright highlight gold — used on hover states and the active period glow.
  static const Color goldLight = Color(0xFFEDD458);

  /// Warm pale gold — secondary text, secondary icon tint.
  static const Color goldPale = Color(0xFFF5E28A);

  /// Deep burnished gold — shadow side of 3-D ring effects.
  static const Color goldDark = Color(0xFF9B7D1A);

  /// Antique brass — muted gold for disabled / inactive elements.
  static const Color goldAntique = Color(0xFF7A6020);

  /// Pure 24-karat gold — sparingly used for the highest-priority element.
  static const Color goldBright = Color(0xFFFFD700);

  // ── Silver / moonlight ─────────────────────────────────────────────────────
  // Cooler metallic palette for the night half of the watch face.

  /// Bright silver — primary silver highlight for the night ring.
  static const Color silverLight = Color(0xFFE8E8F0);

  /// Mid silver — standard silver text and ring stroke colour.
  static const Color silverMid = Color(0xFFC0C0D0);

  /// Dim silver — muted silver for secondary night-period labels.
  static const Color silverDim = Color(0xFF8888A0);

  /// Deep pewter — used for disabled night-period indicators.
  static const Color silverDeep = Color(0xFF444460);

  /// Moonlight white — the faint luminance of a full moon over water.
  static const Color moonlight = Color(0xFFF0F0FF);

  /// Crescent blue-silver — accent for moon-phase indicators.
  static const Color crescentSilver = Color(0xFFB8C8E8);

  // ── Prayer time colours ────────────────────────────────────────────────────
  // Distinct, accessible colours for each of the five daily prayers.

  /// Fajr (dawn prayer) — deep blue before the sun rises.
  static const Color prayerFajr = Color(0xFF1A3A8F);

  /// Dhuhr (noon prayer) — bright midday white-gold.
  static const Color prayerDhuhr = Color(0xFFFFD166);

  /// Asr (afternoon prayer) — warm amber of the lowering sun.
  static const Color prayerAsr = Color(0xFFFF9A3C);

  /// Maghrib (sunset prayer) — deep horizon crimson.
  static const Color prayerMaghrib = Color(0xFFE63946);

  /// Isha (night prayer) — deep indigo night sky.
  static const Color prayerIsha = Color(0xFF4A3880);

  // ── Day/night transition sky colours ──────────────────────────────────────
  // Used as gradient stops when animating the background between periods.

  /// Civil dawn sky — faintest blue before any light.
  static const Color skyDawnCivil = Color(0xFF0D1540);

  /// Astronomical dawn — first hint of indigo-blue.
  static const Color skyDawnAstro = Color(0xFF1A2A7A);

  /// Nautical dawn sky — medium blue with a tinge of violet.
  static const Color skyDawnNautical = Color(0xFF2E3FA0);

  /// Pre-sunrise glow — warm purple-blue just before the sun breaks.
  static const Color skyPreSunrise = Color(0xFF6A3FA0);

  /// Sunrise sky — orange-pink horizon at the moment of sunrise.
  static const Color skySunrise = Color(0xFFFF6B35);

  /// Morning sky — clear blue after the sun has risen.
  static const Color skyMorning = Color(0xFF5BAAD0);

  /// Midday sky — brilliant azure at the zenith.
  static const Color skyMidday = Color(0xFF87CEEB);

  /// Afternoon sky — slightly warmer, hazier blue.
  static const Color skyAfternoon = Color(0xFF7AB8D0);

  /// Pre-sunset sky — golden warm light flooding the atmosphere.
  static const Color skyPreSunset = Color(0xFFFF9A3C);

  /// Sunset sky — deep orange-red as the sun dips below the horizon.
  static const Color skySunset = Color(0xFFE64A19);

  /// Civil dusk sky — dark crimson after sunset.
  static const Color skyDusk = Color(0xFF8D1A0E);

  /// Twilight sky — the final red-purple glow of Al-Shafaq.
  static const Color skyTwilight = Color(0xFF4A1942);

  /// Full night sky — almost pitch-black navy.
  static const Color skyNight = Color(0xFF05081A);

  // ── Temporal period colours ────────────────────────────────────────────────
  // One representative colour per period for ring-segment fills, ordered
  // chronologically (day 1–12, night 1–12).  Mirrors the primaryColor fields
  // in ArabicPeriod but accessible as standalone constants for painting.

  // Day periods ───
  static const Color periodShurooq  = Color(0xFFFF6B35); // Sunrise
  static const Color periodBukoor   = Color(0xFFFFB347); // Early morning
  static const Color periodGhadwa   = Color(0xFFFFD166); // Morning
  static const Color periodDuha     = Color(0xFFFFF176); // Forenoon
  static const Color periodHajira   = Color(0xFFFFF9C4); // Pre-noon
  static const Color periodDhahira  = Color(0xFFFFFFFF); // Noon zenith
  static const Color periodRawah    = Color(0xFFFFE082); // Early afternoon
  static const Color periodAsr      = Color(0xFFFFB300); // Afternoon
  static const Color periodQasr     = Color(0xFFFF8C00); // Late afternoon
  static const Color periodAseel    = Color(0xFFFF5722); // Pre-sunset
  static const Color periodAshi     = Color(0xFFBF360C); // Evening
  static const Color periodGhurubb  = Color(0xFF6A1E4B); // Sunset

  // Night periods ─
  static const Color periodShafaq   = Color(0xFF4A1942); // Twilight
  static const Color periodGhasaq   = Color(0xFF2E0D4A); // Dusk
  static const Color periodAtama    = Color(0xFF150A3A); // Deep night start
  static const Color periodSudfa    = Color(0xFF0D0820); // Darkness
  static const Color periodFahma    = Color(0xFF05040F); // Pitch black
  static const Color periodZalla    = Color(0xFF040612); // Midnight approach
  static const Color periodZulfa    = Color(0xFF05081A); // Midnight
  static const Color periodBahra    = Color(0xFF070B1F); // Post-midnight
  static const Color periodSahar    = Color(0xFF0D1540); // Pre-dawn
  static const Color periodFajr     = Color(0xFF1A2A7A); // Dawn
  static const Color periodSubh     = Color(0xFF3A5BA8); // Early morning light
  static const Color periodSabah    = Color(0xFF7BAFD4); // Morning begins

  // ── Glow / radiance colours ────────────────────────────────────────────────
  // Semi-transparent versions used for bloom / shadow effects.

  /// Gold glow — applied around the active period indicator ring.
  static const Color glowGold = Color(0x80D4AF37);

  /// Soft gold bloom — wider, lower-opacity halo.
  static const Color glowGoldWide = Color(0x40D4AF37);

  /// Silver glow — used for night-mode ring glow.
  static const Color glowSilver = Color(0x60C0C0D0);

  /// Dawn glow — blue-violet bloom at Al-Fajr / Al-Subh.
  static const Color glowDawn = Color(0x702E3FA0);

  /// Sunset glow — warm orange bloom at Al-Ghurubb / Al-Shafaq.
  static const Color glowSunset = Color(0x70E64A19);

  /// Sun disc halo — bright bloom simulating the sun's corona.
  static const Color glowSun = Color(0x80FFD166);

  /// Moon disc halo — cool bloom for the lunar indicator.
  static const Color glowMoon = Color(0x60C8D8F0);

  // ── Text colours ──────────────────────────────────────────────────────────

  /// Primary text — used for the current period name, large numerals.
  static const Color textPrimary = Color(0xFFF0E6C0);

  /// Secondary text — descriptions, sub-labels.
  static const Color textSecondary = Color(0xFFB8A070);

  /// Muted text — disabled or de-emphasised content.
  static const Color textMuted = Color(0xFF6A5C38);

  /// Accent text — gold-coloured labels for prayer times and highlights.
  static const Color textAccent = Color(0xFFD4AF37);

  /// Night text — used when the background is at its deepest (Al-Fahma).
  static const Color textNight = Color(0xFF8888AA);

  // ── Separator / border colours ─────────────────────────────────────────────

  /// Thin ring border stroke — very subtle division between concentric rings.
  static const Color borderSubtle = Color(0x20D4AF37);

  /// Standard ring border — visible but not distracting.
  static const Color borderNormal = Color(0x50D4AF37);

  /// Prominent border — used for the outermost decorative ring.
  static const Color borderProminent = Color(0x90D4AF37);

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Fully transparent — alias for [Colors.transparent].
  static const Color transparent = Color(0x00000000);

  /// Scrim overlay — darkens content beneath modal sheets / dialogs.
  static const Color scrim = Color(0xCC02040F);

  // ── Gradient factories ────────────────────────────────────────────────────

  /// Returns a [LinearGradient] sweeping from dawn colours to midday colours,
  /// suitable for the background of the day half of the watch face.
  static const LinearGradient dayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyMorning, backgroundMid],
    stops: [0.0, 1.0],
  );

  /// Returns a [LinearGradient] for the night half — deep navy to absolute dark.
  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSurface, backgroundDeep],
    stops: [0.0, 1.0],
  );

  /// Radial gold shimmer gradient for ring highlight arcs.
  static const RadialGradient goldShimmerGradient = RadialGradient(
    colors: [goldBright, goldPrimary, goldDark],
    stops: [0.0, 0.5, 1.0],
  );

  /// Sweep gradient covering all 24 temporal periods for the outer ring fill.
  static SweepGradient get allPeriodsGradient => const SweepGradient(
        colors: [
          // Day arc (12 stops)
          periodShurooq,
          periodBukoor,
          periodGhadwa,
          periodDuha,
          periodHajira,
          periodDhahira,
          periodRawah,
          periodAsr,
          periodQasr,
          periodAseel,
          periodAshi,
          periodGhurubb,
          // Night arc (12 stops)
          periodShafaq,
          periodGhasaq,
          periodAtama,
          periodSudfa,
          periodFahma,
          periodZalla,
          periodZulfa,
          periodBahra,
          periodSahar,
          periodFajr,
          periodSubh,
          periodSabah,
          // Wrap back to sunrise
          periodShurooq,
        ],
      );

  // ── Colour list accessors ─────────────────────────────────────────────────

  /// All 12 day-period primary colours in chronological order (index 0–11).
  static const List<Color> dayPeriodColors = [
    periodShurooq,
    periodBukoor,
    periodGhadwa,
    periodDuha,
    periodHajira,
    periodDhahira,
    periodRawah,
    periodAsr,
    periodQasr,
    periodAseel,
    periodAshi,
    periodGhurubb,
  ];

  /// All 12 night-period primary colours in chronological order (index 0–11).
  static const List<Color> nightPeriodColors = [
    periodShafaq,
    periodGhasaq,
    periodAtama,
    periodSudfa,
    periodFahma,
    periodZalla,
    periodZulfa,
    periodBahra,
    periodSahar,
    periodFajr,
    periodSubh,
    periodSabah,
  ];

  /// All 24 period colours: day (0–11) then night (12–23).
  static const List<Color> allPeriodColors = [
    ...dayPeriodColors,
    ...nightPeriodColors,
  ];

  /// The five prayer-time colours in the canonical order:
  /// Fajr, Dhuhr, Asr, Maghrib, Isha.
  static const List<Color> prayerColors = [
    prayerFajr,
    prayerDhuhr,
    prayerAsr,
    prayerMaghrib,
    prayerIsha,
  ];
}
