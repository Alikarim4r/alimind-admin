/// UI dimensions, size ratios, ring widths, font scales, and spacing constants
/// for the Arabic Temporal Watch app.
///
/// All ring-size constants are expressed as fractions of [watchDiameter] so the
/// layout remains perfectly proportional on every screen size.  The watch
/// diameter itself is computed at layout time from the smaller of
/// `MediaQuery.of(context).size.width` and `MediaQuery.of(context).size.height`
/// minus padding; see [WatchSizes.fromConstraints].
///
/// Naming conventions:
///   * Ratios (fractions of watchDiameter) end with `Ratio`.
///   * Absolute pixel values intended for a 1× density end with `Dp`.
///   * Semantic groups are nested under descriptively named classes so IDE
///     autocomplete surfaces the right constant immediately.
library;

// ── Watch geometry ────────────────────────────────────────────────────────────

/// The fraction of the shorter screen dimension that the watch face occupies.
///
/// Setting this to 0.90 leaves 5 % breathing room on each side of a square
/// layout and slightly more on tall phones.
const double kWatchScreenFraction = 0.90;

/// Maximum watch diameter in logical pixels, capped to prevent the face from
/// becoming impractically large on tablets or foldable devices.
const double kWatchMaxDiameterDp = 520.0;

/// Minimum watch diameter — ensures the face is still legible on small phones.
const double kWatchMinDiameterDp = 280.0;

// ── Ring radii as fractions of watchDiameter ─────────────────────────────────

/// Outer decorative bezel ring — the outermost visible circle.
const double kBezalOuterRatio = 0.500; // 50 % of diameter = 100 % of radius

/// Inner edge of the bezel (border).
const double kBezalInnerRatio = 0.475;

/// Outer edge of the 24-period ring arc band.
const double kPeriodRingOuterRatio = 0.470;

/// Inner edge of the 24-period ring arc band.
const double kPeriodRingInnerRatio = 0.400;

/// Outer edge of the hour-marker ring (Roman / Arabic numerals).
const double kHourRingOuterRatio = 0.395;

/// Inner edge of the hour-marker ring.
const double kHourRingInnerRatio = 0.340;

/// Outer edge of the prayer-time indicator ring.
const double kPrayerRingOuterRatio = 0.335;

/// Inner edge of the prayer-time indicator ring.
const double kPrayerRingInnerRatio = 0.295;

/// Outer edge of the astronomical data ring (sun/moon position arcs).
const double kAstroRingOuterRatio = 0.290;

/// Inner edge of the astronomical data ring.
const double kAstroRingInnerRatio = 0.250;

/// Radius of the central clock-face disc.
const double kClockFaceRatio = 0.245;

/// Radius of the central time display area (digital time readout).
const double kTimeDisplayRatio = 0.200;

// ── Ring stroke widths as fractions of watchDiameter ─────────────────────────

/// Stroke width for the outer bezel ring border.
const double kBezalStrokeRatio = 0.006;

/// Stroke width for tick marks on the period ring.
const double kPeriodTickStrokeRatio = 0.003;

/// Stroke width for the main hands (hour and minute).
const double kHandStrokeRatio = 0.008;

/// Stroke width for the seconds hand.
const double kSecondsHandStrokeRatio = 0.004;

/// Stroke width for prayer-time dot indicators.
const double kPrayerDotRadiusRatio = 0.012;

// ── Hand lengths as fractions of kClockFaceRatio * diameter ──────────────────

/// Hour hand length — fraction of the clock-face radius.
const double kHourHandLengthRatio = 0.55;

/// Minute hand length — fraction of the clock-face radius.
const double kMinuteHandLengthRatio = 0.75;

/// Seconds hand length — fraction of the clock-face radius.
const double kSecondsHandLengthRatio = 0.85;

/// Tail (counter-balance) length for the seconds hand.
const double kSecondsHandTailRatio = 0.25;

// ── Centre ornament ───────────────────────────────────────────────────────────

/// Radius of the decorative centre cap (pivot jewel).
const double kCentreCapRadiusRatio = 0.020;

/// Radius of the outer halo ring around the centre cap.
const double kCentreHaloRadiusRatio = 0.030;

// ── Sun and Moon indicator sizes ──────────────────────────────────────────────

/// Radius of the sun disc indicator on the period/astro ring.
const double kSunIndicatorRadiusRatio = 0.030;

/// Radius of the moon crescent indicator.
const double kMoonIndicatorRadiusRatio = 0.025;

// ── Typography scales ─────────────────────────────────────────────────────────

/// Base font size — scales with the watch diameter via [WatchSizes].
/// All text sizes below are multiples of this value.
const double kBaseFontSizeRatio = 0.040; // ~40 % of 1/10th diameter

/// Period name displayed in the centre (Arabic large text).
const double kPeriodNameFontRatio = 0.090;

/// Digital time readout (HH:MM).
const double kTimeFontRatio = 0.110;

/// Seconds readout (:SS).
const double kSecondsFontRatio = 0.050;

/// Hijri date label.
const double kHijriFontRatio = 0.038;

/// Gregorian date label.
const double kGregorianFontRatio = 0.030;

/// Hour numerals on the ring.
const double kHourNumFontRatio = 0.028;

/// Prayer name label on the ring.
const double kPrayerNameFontRatio = 0.022;

// ── Spacing / padding ─────────────────────────────────────────────────────────

/// Vertical padding above the watch face on the screen.
const double kWatchTopPaddingDp = 24.0;

/// Padding between the watch face and the bottom info bar.
const double kWatchBottomPaddingDp = 20.0;

/// Internal padding for info panels / bottom sheets.
const double kPanelPaddingDp = 20.0;

/// Standard horizontal margin for full-width content below/above the watch.
const double kContentHorizontalMarginDp = 24.0;

/// Spacing between period labels and the nearest ring edge.
const double kLabelRingGapDp = 4.0;

/// Border radius for info cards and bottom-sheet panels.
const double kCardBorderRadiusDp = 16.0;

/// Bottom sheet corner radius.
const double kSheetBorderRadiusDp = 24.0;

// ── Glow / shadow radii ───────────────────────────────────────────────────────

/// Blur radius for the tight gold glow on the active period arc.
const double kGlowBlurNarrow = 6.0;

/// Blur radius for the wide ambient gold glow.
const double kGlowBlurWide = 18.0;

/// Blur radius for the sun-disc bloom effect.
const double kSunGlowBlur = 24.0;

/// Blur radius for the moon-disc bloom.
const double kMoonGlowBlur = 16.0;

/// Spread radius for the bezel outer shadow.
const double kBezalShadowSpread = 4.0;

// ── Tick mark dimensions ──────────────────────────────────────────────────────

/// Length of a major period boundary tick (at every period start).
const double kMajorTickLengthRatio = 0.015;

/// Length of a minor sub-division tick (e.g. quarter-period).
const double kMinorTickLengthRatio = 0.008;

/// Stroke width for major tick marks.
const double kMajorTickStrokeRatio = 0.004;

/// Stroke width for minor tick marks.
const double kMinorTickStrokeRatio = 0.002;

// ── Helper class ──────────────────────────────────────────────────────────────

/// Resolved, device-specific watch dimensions derived from a layout constraint.
///
/// Compute once per layout pass with [WatchSizes.fromDiameter] and pass
/// down the widget tree to avoid repeated multiplication.
///
/// Example:
/// ```dart
/// final sizes = WatchSizes.fromDiameter(constraints.maxWidth * kWatchScreenFraction);
/// final double hourHandLength = sizes.clockFaceRadius * kHourHandLengthRatio;
/// ```
final class WatchSizes {
  const WatchSizes._({required this.diameter});

  /// Constructs [WatchSizes] from a raw diameter in logical pixels.
  ///
  /// Clamps the value between [kWatchMinDiameterDp] and [kWatchMaxDiameterDp].
  factory WatchSizes.fromDiameter(double rawDiameter) {
    final clamped = rawDiameter.clamp(
      kWatchMinDiameterDp,
      kWatchMaxDiameterDp,
    );
    return WatchSizes._(diameter: clamped);
  }

  /// The watch face outer diameter in logical pixels.
  final double diameter;

  // ── Derived radii ──────────────────────────────────────────────────────────

  double get radius => diameter / 2;

  double get bezelOuter   => diameter * kBezalOuterRatio;
  double get bezelInner   => diameter * kBezalInnerRatio;

  double get periodRingOuter => diameter * kPeriodRingOuterRatio;
  double get periodRingInner => diameter * kPeriodRingInnerRatio;
  double get periodRingWidth => periodRingOuter - periodRingInner;

  double get hourRingOuter => diameter * kHourRingOuterRatio;
  double get hourRingInner => diameter * kHourRingInnerRatio;

  double get prayerRingOuter => diameter * kPrayerRingOuterRatio;
  double get prayerRingInner => diameter * kPrayerRingInnerRatio;

  double get astroRingOuter => diameter * kAstroRingOuterRatio;
  double get astroRingInner => diameter * kAstroRingInnerRatio;

  double get clockFaceRadius => diameter * kClockFaceRatio;
  double get timeDisplayRadius => diameter * kTimeDisplayRatio;

  // ── Derived stroke widths ──────────────────────────────────────────────────

  double get bezelStroke        => diameter * kBezalStrokeRatio;
  double get handStroke         => diameter * kHandStrokeRatio;
  double get secondsHandStroke  => diameter * kSecondsHandStrokeRatio;
  double get prayerDotRadius    => diameter * kPrayerDotRadiusRatio;

  // ── Derived font sizes ─────────────────────────────────────────────────────

  double get periodNameFontSize  => diameter * kPeriodNameFontRatio;
  double get timeFontSize        => diameter * kTimeFontRatio;
  double get secondsFontSize     => diameter * kSecondsFontRatio;
  double get hijriFontSize       => diameter * kHijriFontRatio;
  double get gregorianFontSize   => diameter * kGregorianFontRatio;
  double get hourNumFontSize     => diameter * kHourNumFontRatio;
  double get prayerNameFontSize  => diameter * kPrayerNameFontRatio;

  // ── Derived indicator sizes ────────────────────────────────────────────────

  double get sunIndicatorRadius  => diameter * kSunIndicatorRadiusRatio;
  double get moonIndicatorRadius => diameter * kMoonIndicatorRadiusRatio;
  double get centreCapRadius     => diameter * kCentreCapRadiusRatio;
  double get centreHaloRadius    => diameter * kCentreHaloRadiusRatio;

  // ── Hand lengths (absolute, from centre) ──────────────────────────────────

  double get hourHandLength    => clockFaceRadius * kHourHandLengthRatio;
  double get minuteHandLength  => clockFaceRadius * kMinuteHandLengthRatio;
  double get secondsHandLength => clockFaceRadius * kSecondsHandLengthRatio;
  double get secondsTailLength => clockFaceRadius * kSecondsHandTailRatio;

  @override
  String toString() => 'WatchSizes(diameter: $diameter)';
}
