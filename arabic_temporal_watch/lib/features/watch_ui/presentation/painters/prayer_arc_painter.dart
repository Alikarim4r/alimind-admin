// prayer_arc_painter.dart
//
// Paints a prayer-time arc indicator around the outside of the watch face.
//
// Design:
//   • A thin arc ring (5 px wide) positioned just outside the main watch face.
//   • The full 360° represents a complete 24-hour day (midnight to midnight).
//   • Six colored segments — one per prayer period — sized proportionally to
//     the minutes each period spans in the day.
//   • The active (current) prayer segment pulses with a glow effect, driven by
//     [animationValue].
//   • A small gold dot marks the current time position on the arc.
//   • Segment joints are rounded so the ring reads as a continuous band.
//
// Angle mapping:
//   angle = ((minutesSinceMidnight(t)) / 1440) * 2π − π/2
//   (−π/2 maps midnight to the 12 o'clock position, consistent with the hands.)

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../prayer_engine/domain/prayer.dart';

// ── PrayerArcPainter ──────────────────────────────────────────────────────────

/// [CustomPainter] that renders the prayer-time arc ring around the watch face.
///
/// The arc sits in a band whose *center* radius is [outerRadiusFraction] times
/// the canvas half-size.  Callers should give this painter a canvas that is
/// slightly larger than the dial face so the arc ring is visible.
class PrayerArcPainter extends CustomPainter {
  const PrayerArcPainter({
    required this.prayerTimes,
    required this.now,
    required this.sunrise,
    required this.sunset,
    this.animationValue = 0.0,
    this.outerRadiusFraction = 0.99,
    this.arcStrokeWidth = 2.5, // thinner — precision instrument
  });

  /// The six computed prayer times for today.
  final PrayerTimes prayerTimes;

  /// Current local date-time — determines the time-marker dot position.
  final DateTime now;

  /// Today's sunrise time (local) — used as the boundary after which Fajr
  /// transitions to the next prayer in the display logic.
  final DateTime sunrise;

  /// Today's sunset time (local).
  final DateTime sunset;

  /// 0.0–1.0 animation phase for the active-segment pulse glow.
  final double animationValue;

  /// Fraction of the half-canvas at which the arc ring center sits.
  /// 0.97 places it just outside a 0.92-radius watch face.
  final double outerRadiusFraction;

  /// Width of the arc stroke in logical pixels.
  final double arcStrokeWidth;

  // ── Palette (segment colors) ───────────────────────────────────────────────

  static const _segmentColors = <PrayerName, Color>{
    PrayerName.fajr: Color(0xFF3A3F8A),    // deep indigo/blue
    PrayerName.sunrise: Color(0xFFD4AF37),  // gold
    PrayerName.dhuhr: Color(0xFFFFD166),    // warm yellow
    PrayerName.asr: Color(0xFFFF8C00),      // orange
    PrayerName.maghrib: Color(0xFFB8496B),  // rose/crimson
    PrayerName.isha: Color(0xFF1A3A8F),     // deep blue
  };

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  double _arcRadius(Size size) =>
      math.min(size.width, size.height) / 2.0 * outerRadiusFraction;

  /// Converts a [DateTime] to an arc angle in radians.
  /// Midnight → −π/2 (12 o'clock), then clockwise for 24 h.
  double _timeToAngle(DateTime t) {
    final minutesSinceMidnight =
        t.hour * 60 + t.minute + t.second / 60.0;
    return (minutesSinceMidnight / 1440.0) * math.pi * 2.0 - math.pi / 2.0;
  }

  // ── Segment building ───────────────────────────────────────────────────────

  // Static cache: segments depend on prayer times + date, not the current time.
  // Rebuilt only when prayer times are recalculated (typically once per day).
  static List<_ArcSegment>? _segmentsCache;
  static DateTime? _cachedDate;
  static PrayerTimes? _cachedPrayerTimes;
  static DateTime? _cachedSunrise;
  static DateTime? _cachedSunset;

  /// Builds an ordered list of [_ArcSegment] covering the full 24-hour day.
  ///
  /// The boundary times for each segment are:
  ///   Fajr    : midnight(today) → sunrise
  ///   Sunrise : sunrise → dhuhr
  ///   Dhuhr   : dhuhr → asr
  ///   Asr     : asr → maghrib
  ///   Maghrib : maghrib → isha
  ///   Isha    : isha → midnight(tomorrow)
  List<_ArcSegment> _buildSegments() {
    final midnight = DateTime(now.year, now.month, now.day);
    if (_segmentsCache != null &&
        _cachedDate == midnight &&
        _cachedPrayerTimes == prayerTimes &&
        _cachedSunrise == sunrise &&
        _cachedSunset == sunset) {
      return _segmentsCache!;
    }
    final nextMidnight = midnight.add(const Duration(days: 1));

    final boundaries = <PrayerName, _DateTimePair>{
      PrayerName.fajr: _DateTimePair(midnight, sunrise),
      PrayerName.sunrise: _DateTimePair(sunrise, prayerTimes.dhuhr.time),
      PrayerName.dhuhr: _DateTimePair(prayerTimes.dhuhr.time, prayerTimes.asr.time),
      PrayerName.asr: _DateTimePair(prayerTimes.asr.time, sunset),
      PrayerName.maghrib: _DateTimePair(sunset, prayerTimes.isha.time),
      PrayerName.isha: _DateTimePair(prayerTimes.isha.time, nextMidnight),
    };

    final segments = boundaries.entries.map((e) {
      final name = e.key;
      final pair = e.value;
      return _ArcSegment(
        name: name,
        startAngle: _timeToAngle(pair.start),
        endAngle: _timeToAngle(pair.end),
        color: _segmentColors[name] ?? AppColors.goldPrimary,
      );
    }).toList();

    _cachedDate = midnight;
    _cachedPrayerTimes = prayerTimes;
    _cachedSunrise = sunrise;
    _cachedSunset = sunset;
    _segmentsCache = segments;
    return segments;
  }

  /// Determines which prayer segment is currently active.
  PrayerName _activePrayer() {
    final current = prayerTimes.currentPrayer(now);
    return current?.name ?? PrayerName.isha;
  }

  // ── Layer 1: Background track ──────────────────────────────────────────────

  void _drawTrack(Canvas canvas, Offset center, double arcRadius) {
    // Very subtle dark track — barely visible foundation.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcStrokeWidth + 0.5
      ..color = const Color(0x25000000);

    canvas.drawCircle(center, arcRadius, trackPaint);
  }

  // ── Layer 2: Colored segments ──────────────────────────────────────────────

  void _drawSegments(
    Canvas canvas,
    Offset center,
    double arcRadius,
    List<_ArcSegment> segments,
    PrayerName activeSegment,
  ) {
    final rect = Rect.fromCircle(center: center, radius: arcRadius);

    for (final seg in segments) {
      final isActive = seg.name == activeSegment;

      // Segment color — active is brightened slightly.
      final baseColor = isActive
          ? Color.lerp(seg.color, AppColors.goldLight, 0.20)!
          : seg.color;

      // Subtle soft glow for active segment — not distracting.
      if (isActive) {
        final glowAlpha = 0.30 + 0.20 * math.sin(animationValue * math.pi * 2.0);
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = arcStrokeWidth + 3.5
          ..color = seg.color.withOpacity(glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, arcStrokeWidth * 1.5);

        final sweepAngle = _normalizedSweep(seg.startAngle, seg.endAngle);
        canvas.drawArc(rect, seg.startAngle, sweepAngle, false, glowPaint);
      }

      // ── Main segment arc — thin, precise ──
      final segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcStrokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = baseColor.withOpacity(isActive ? 0.92 : 0.55);

      final sweepAngle = _normalizedSweep(seg.startAngle, seg.endAngle);
      canvas.drawArc(rect, seg.startAngle, sweepAngle, false, segmentPaint);
    }
  }

  // ── Layer 3: Segment joints ────────────────────────────────────────────────

  void _drawJoints(
    Canvas canvas,
    Offset center,
    double arcRadius,
    List<_ArcSegment> segments,
  ) {
    // Hairline gold tick at each boundary — precision instrument style.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.goldPrimary.withOpacity(0.35)
      ..strokeCap = StrokeCap.butt;

    for (final seg in segments) {
      final x = center.dx + math.cos(seg.startAngle) * arcRadius;
      final y = center.dy + math.sin(seg.startAngle) * arcRadius;

      // Short radial tick at the boundary.
      final tickLen = arcStrokeWidth * 1.2;
      final dirX = math.cos(seg.startAngle);
      final dirY = math.sin(seg.startAngle);
      canvas.drawLine(
        Offset(x - dirX * tickLen * 0.5, y - dirY * tickLen * 0.5),
        Offset(x + dirX * tickLen * 0.5, y + dirY * tickLen * 0.5),
        tickPaint,
      );
    }
  }

  // ── Layer 4: Current time dot ──────────────────────────────────────────────

  void _drawTimeDot(Canvas canvas, Offset center, double arcRadius) {
    final angle = _timeToAngle(now);
    final x = center.dx + math.cos(angle) * arcRadius;
    final y = center.dy + math.sin(angle) * arcRadius;
    final dotPos = Offset(x, y);

    // Subtle gold glow.
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.glowGold.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(dotPos, arcStrokeWidth * 0.85, glowPaint);

    // Gold dot — small and precise.
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: const [AppColors.goldLight, AppColors.goldPrimary],
      ).createShader(
        Rect.fromCircle(center: dotPos, radius: arcStrokeWidth * 0.65),
      );
    canvas.drawCircle(dotPos, arcStrokeWidth * 0.65, dotPaint);
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  /// Returns the positive sweep angle from [start] to [end], handling wrap.
  double _normalizedSweep(double start, double end) {
    double sweep = end - start;
    if (sweep < 0) sweep += math.pi * 2.0;
    if (sweep > math.pi * 2.0) sweep = math.pi * 2.0;
    return sweep;
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final center = _center(size);
    final arcRadius = _arcRadius(size);

    final segments = _buildSegments();
    final active = _activePrayer();

    _drawTrack(canvas, center, arcRadius);
    _drawSegments(canvas, center, arcRadius, segments, active);
    _drawJoints(canvas, center, arcRadius, segments);
    _drawTimeDot(canvas, center, arcRadius);
  }

  @override
  bool shouldRepaint(PrayerArcPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.animationValue != animationValue ||
      oldDelegate.prayerTimes != prayerTimes ||
      oldDelegate.sunrise != sunrise ||
      oldDelegate.sunset != sunset;
}

// ── Private helpers ────────────────────────────────────────────────────────────

/// Simple date-time range helper.
class _DateTimePair {
  const _DateTimePair(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// One colored arc segment.
class _ArcSegment {
  const _ArcSegment({
    required this.name,
    required this.startAngle,
    required this.endAngle,
    required this.color,
  });

  final PrayerName name;
  final double startAngle;
  final double endAngle;
  final Color color;
}
