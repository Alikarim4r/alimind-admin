// ring_painter.dart
//
// CustomPainter that draws the 24-segment rotating Arabic temporal ring.
//
// Rendering layers (back to front)
// ──────────────────────────────────
//   1. Arc tick marks  — 13 fading gold tick marks within the visible ±6 window,
//                        at 75% of canvas radius (outer ticks fade at window edge).
//   2. Floating labels — 13 Arabic period labels (offset -6 to +6 from current),
//                        with distance-based opacity and font-size gradient.
//                        Current period: white with gold glow.
//                        Night periods: moonlight/silver color.
//                        Others: gold.
//
// Sliding 12-hour window
// ──────────────────────
//   All 24 Arabic hours exist and the ring continuously rotates CCW.  Only a
//   sliding window of 13 periods (6 past + current + 6 future) is rendered at
//   any moment.  Labels and ticks at the outer edges of the window fade to zero
//   opacity, creating the "hours streaming endlessly around the clock" effect.
//
// Coordinate system
// ─────────────────
//   Flutter canvas: 0 rad = 3 o'clock, angles increase clockwise.
//   Ring face:      0 rad = 12 o'clock (a −π/2 offset is applied before drawing).
//
// Ring rotation logic
// ───────────────────
//   The ring ROTATES so the current Arabic period is always aligned with the
//   reader line (hour direction). The rotationAngle stored in ringState is the
//   current smooth rotation applied by Transform.rotate in the parent widget.
//   Inside the painter, segment angles are already in their natural positions;
//   the parent widget applies the rotation transform.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/ring_state.dart';

// ── PrayerMarker ──────────────────────────────────────────────────────────────

/// A single prayer-time marker that rides on the rotating ring.
///
/// [ringAngle] is the natural ring angle (radians, 0 = start of period 0,
/// increases clockwise) where the dot should be rendered.
/// Visibility fades in/out as the marker scrolls into or out of the
/// ±[RingPainter._labelHalfRange] window.
@immutable
class PrayerMarker {
  const PrayerMarker({
    required this.ringAngle,
    required this.color,
    required this.arabicName,
    this.isAm = true,
  });

  /// Natural ring angle in radians — computed from the prayer's real time
  /// relative to the day/night temporal-hour grid.
  final double ringAngle;

  /// Prayer color (blue for Fajr, gold for Sunrise, yellow for Dhuhr, etc.).
  final Color color;

  /// Short Arabic prayer name shown beside the dot.
  final String arabicName;

  /// True for morning (AM/صباحاً) prayers, false for evening (PM/مساءً).
  final bool isAm;
}

// ── RingPainter ───────────────────────────────────────────────────────────────

/// [CustomPainter] that draws the floating-label 24-period Arabic ring.
///
/// No filled arc segments — only floating labels with distance-based opacity
/// and 24 arc tick marks at 75% of the canvas radius.
///
/// Usage:
/// ```dart
/// CustomPaint(
///   painter: RingPainter(
///     ringState: state,
///     progressFraction: data.progressFraction,
///     glowIntensity: calculator.glowIntensity(animTime),
///   ),
/// )
/// ```
class RingPainter extends CustomPainter {
  const RingPainter({
    required this.ringState,
    required this.progressFraction,
    required this.glowIntensity,
    this.prayerMarkers = const [],
  });

  /// The complete ring render state produced by [RingCalculator].
  final RingState ringState;

  /// How far through the current temporal period we are — [0.0, 1.0].
  final double progressFraction;

  /// Current glow pulse intensity — [0.55, 1.0].
  final double glowIntensity;

  /// Prayer-time markers to draw on the ring.
  final List<PrayerMarker> prayerMarkers;

  // ── Geometry constants ─────────────────────────────────────────────────────

  /// Outer radius of the colored ring band as a fraction of half-canvas width.
  static const double _ringOuterFraction = 0.94;

  /// Inner radius of the colored ring band as a fraction of half-canvas width.
  static const double _ringInnerFraction = 0.73;

  /// Radial position of arc tick marks as a fraction of half-canvas width.
  static const double _tickRadiusFraction = 0.835;

  /// Radial position of floating labels as a fraction of half-canvas width.
  static const double _labelRadiusFraction = 0.835;

  /// Flutter canvas offset so that 0 rad = 12 o'clock (−π/2).
  static const double _startOffset = -math.pi / 2.0;

  /// Number of visible label offsets on each side of the current period.
  /// 6 → shows 13 labels total: 6 past + current + 6 future (sliding 12-hour window).
  static const int _labelHalfRange = 6;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final halfW = size.width / 2.0;

    final tickR = halfW * _tickRadiusFraction;
    final labelR = halfW * _labelRadiusFraction;

    // ── Layer 0: Watch body fill — covers sky background between inner clock and ring ──
    _drawWatchBodyFill(canvas, cx, cy, halfW);

    // ── Layer 0.5: Colored arc sectors for the sliding 12-period window ───────
    _drawArcSectors(canvas, cx, cy, halfW);

    // ── Layer 1: Arc tick marks ───────────────────────────────────────────────
    _drawArcTicks(canvas, cx, cy, tickR, halfW);

    // ── Layer 1.5: Prayer time markers ────────────────────────────────────────
    _drawPrayerMarkers(canvas, cx, cy, tickR);

    // ── Layer 2: Floating Arabic labels ──────────────────────────────────────
    _drawFloatingLabels(canvas, cx, cy, labelR, size);
  }

  void _drawWatchBodyFill(Canvas canvas, double cx, double cy, double halfW) {
    // Fill the entire watch face area with a dark gradient so the sky background
    // painter does not show through between the inner clock (46%) and the ring.
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.0,
        colors: const [
          Color(0xFF0C1230),
          Color(0xFF071126),
          Color(0xFF030712),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: halfW * 0.97),
      );
    canvas.drawCircle(Offset(cx, cy), halfW * 0.97, fillPaint);
  }

  // ── Layer implementations ──────────────────────────────────────────────────

  void _drawArcSectors(Canvas canvas, double cx, double cy, double halfW) {
    final segments = ringState.segments;
    if (segments.isEmpty) return;

    final currentIdx = segments.indexWhere((s) => s.isCurrent);
    if (currentIdx < 0) return;

    const segAngle = math.pi * 2.0 / 24.0;
    final totalSegs = segments.length;
    final outerR = halfW * _ringOuterFraction;
    final innerR = halfW * _ringInnerFraction;

    // Small radians gap between adjacent sectors so boundaries are visible.
    const gap = 0.007;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    for (int offset = -_labelHalfRange; offset <= _labelHalfRange; offset++) {
      final idx = ((currentIdx + offset) % totalSegs + totalSegs) % totalSegs;
      final seg = segments[idx];

      // Same fade curve used by ticks and labels for visual coherence.
      final dist = (offset - progressFraction).abs();
      final norm = math.max(0.0, 1.0 - dist / 6.5);
      final sectorOpacity = math.pow(norm, 1.1).toDouble();
      if (sectorOpacity < 0.02) continue;

      final startAngle = _startOffset + idx * segAngle + gap / 2;
      final sweepAngle = segAngle - gap;

      final path = _annularSectorPath(cx, cy, innerR, outerR, startAngle, sweepAngle);

      // Fill with segment color modulated by window opacity.
      fillPaint.color = seg.segmentColor.withOpacity(sectorOpacity * 0.72);
      canvas.drawPath(path, fillPaint);

      // Gold border on the current-period sector.
      if (offset == 0) {
        borderPaint.color = AppColors.goldPrimary.withOpacity(sectorOpacity * 0.75 * glowIntensity);
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  Path _annularSectorPath(
    double cx, double cy,
    double innerR, double outerR,
    double startAngle, double sweepAngle,
  ) {
    final outerRect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    final innerRect = Rect.fromCircle(center: Offset(cx, cy), radius: innerR);
    return Path()
      ..arcTo(outerRect, startAngle, sweepAngle, true)
      ..arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false)
      ..close();
  }

  void _drawArcTicks(
    Canvas canvas,
    double cx,
    double cy,
    double tickR,
    double halfW,
  ) {
    // Tick marks for the visible ±(_labelHalfRange + 1) window only.
    // Each tick fades using the same opacity curve as the floating labels so
    // ticks and labels appear / disappear together at the window edges.
    final segments = ringState.segments;
    if (segments.isEmpty) return;

    final currentIdx = segments.indexWhere((s) => s.isCurrent);
    if (currentIdx < 0) return;

    const segmentAngle = math.pi * 2.0 / 24.0;
    final totalSegs = segments.length;

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalSegs; i++) {
      // Signed offset from current period, wrapped to [−12, 12].
      int rawOffset = i - currentIdx;
      if (rawOffset > 12) rawOffset -= 24;
      if (rawOffset < -12) rawOffset += 24;

      // Ignore ticks outside the visible window.
      if (rawOffset.abs() > _labelHalfRange + 1) continue;

      // Fade using the same formula as the floating labels for visual coherence.
      final dist = (rawOffset - progressFraction).abs();
      final norm = math.max(0.0, 1.0 - dist / 6.4);
      final tickOpacity = math.pow(norm, 1.35).toDouble();
      if (tickOpacity < 0.02) continue;

      final angle = _startOffset + i * segmentAngle;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      const tickLen = 2.0;
      tickPaint.color =
          AppColors.goldPrimary.withAlpha((107 * tickOpacity).round());

      canvas.drawLine(
        Offset(cx + (tickR - tickLen) * cosA, cy + (tickR - tickLen) * sinA),
        Offset(cx + (tickR + tickLen) * cosA, cy + (tickR + tickLen) * sinA),
        tickPaint,
      );
    }
  }

  void _drawFloatingLabels(
    Canvas canvas,
    double cx,
    double cy,
    double labelR,
    Size size,
  ) {
    final segments = ringState.segments;
    if (segments.isEmpty) return;

    final int totalSegs = segments.length; // 24
    final currentIdx = segments.indexWhere((s) => s.isCurrent);
    if (currentIdx < 0) return;

    const segmentAngle = math.pi * 2.0 / 24.0;

    // Draw labels for offsets -6 to +6 from current period.
    for (int offset = -_labelHalfRange; offset <= _labelHalfRange; offset++) {
      // Wrap-around index in the 24-period cycle.
      final idx = ((currentIdx + offset) % totalSegs + totalSegs) % totalSegs;
      final seg = segments[idx];

      // Angle of the center of this segment in the parent's rotated frame.
      // The parent applies Transform.rotate(ringState.rotationAngle), so within
      // the painter's local coordinates we use the natural segment angle.
      // Natural angle: segment i center = i * segmentAngle + segmentAngle/2
      // In flutter coords (0 = 3 o'clock): add _startOffset
      final segCenterAngle = _startOffset + idx * segmentAngle + segmentAngle * 0.5;

      // Distance-based opacity and font size.
      // dist = |offset - progressFraction| — how far from the reader-aligned position.
      final dist = (offset - progressFraction).abs();
      final norm = math.max(0.0, 1.0 - dist / 6.4);
      final opacity = math.pow(norm, 1.35).toDouble();

      if (opacity < 0.02) continue; // skip nearly invisible labels

      final fontSize = 8.5 + norm * 7.5; // 8.5 to 16 px

      // Color: current (offset == 0, closest) = white; night = moonlight/silver; other = gold.
      final Color textColor;
      if (offset == 0) {
        // Current period — white text
        textColor = Colors.white.withAlpha((opacity * 255).round());
      } else if (!seg.isDay) {
        // Night period — moonlight/crescent silver
        textColor = AppColors.crescentSilver.withAlpha((opacity * 255).round());
      } else {
        // Day period — gold
        textColor = AppColors.goldPrimary.withAlpha((opacity * 255).round());
      }

      final fontWeight = offset == 0 ? FontWeight.w700 : FontWeight.w400;

      // ── Gold glow for current period ──────────────────────────────────────
      if (offset == 0 && opacity > 0.5) {
        _drawLabelGlow(canvas, cx, cy, labelR, segCenterAngle, seg.arabicName, fontSize);
      }

      // ── Arabic label ──────────────────────────────────────────────────────
      final textPainter = TextPainter(
        text: TextSpan(
          text: seg.arabicName,
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: fontSize,
            color: textColor,
            fontWeight: fontWeight,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();

      final labelX = cx + labelR * math.cos(segCenterAngle);
      final labelY = cy + labelR * math.sin(segCenterAngle);

      canvas.save();
      canvas.translate(labelX, labelY);
      // Rotate label to face outward along the radial direction.
      canvas.rotate(segCenterAngle + math.pi / 2.0);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
      );
      canvas.restore();
    }
  }

  void _drawPrayerMarkers(
    Canvas canvas,
    double cx,
    double cy,
    double tickR,
  ) {
    if (prayerMarkers.isEmpty) return;

    final segments = ringState.segments;
    if (segments.isEmpty) return;

    final currentIdx = segments.indexWhere((s) => s.isCurrent);
    if (currentIdx < 0) return;

    const segmentAngle = math.pi * 2.0 / 24.0;
    final centerPos = currentIdx + progressFraction;

    for (final marker in prayerMarkers) {
      // Prayer position in fractional segment units (0–24).
      final prayerPos = marker.ringAngle / segmentAngle;

      // Signed offset from current center — wrap to [−12, 12].
      double offset = prayerPos - centerPos;
      if (offset > 12) offset -= 24;
      if (offset < -12) offset += 24;

      if (offset.abs() > _labelHalfRange + 1.5) continue;

      final norm = math.max(0.0, 1.0 - offset.abs() / (_labelHalfRange + 1.2));
      final opacity = math.pow(norm, 1.2).toDouble();
      if (opacity < 0.04) continue;

      final angle = _startOffset + marker.ringAngle;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // ── Glow halo ─────────────────────────────────────────────────────────
      final glowPaint = Paint()
        ..color = marker.color.withAlpha((opacity * 70).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(
          Offset(cx + tickR * cosA, cy + tickR * sinA), 5.0, glowPaint);

      // ── Colored dot ───────────────────────────────────────────────────────
      final dotPaint = Paint()
        ..color = marker.color.withAlpha((opacity * 230).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(cx + tickR * cosA, cy + tickR * sinA), 2.8, dotPaint);

      // ── AM / PM badge ─────────────────────────────────────────────────────
      if (opacity > 0.30) {
        final badgeText = marker.isAm ? 'ص' : 'م'; // ص=صباح(AM) م=مساء(PM)
        final badgeR = tickR - 9.0;
        final badgeTp = TextPainter(
          text: TextSpan(
            text: badgeText,
            style: TextStyle(
              fontSize: 5.5,
              color: marker.color.withAlpha((opacity * 180).round()),
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout();

        canvas.save();
        canvas.translate(cx + badgeR * cosA, cy + badgeR * sinA);
        canvas.rotate(angle + math.pi / 2.0);
        badgeTp.paint(canvas,
            Offset(-badgeTp.width / 2.0, -badgeTp.height / 2.0));
        canvas.restore();
      }

      // ── Arabic prayer name ────────────────────────────────────────────────
      if (opacity > 0.18) {
        final nameR = tickR + 9.0;
        final nameTp = TextPainter(
          text: TextSpan(
            text: marker.arabicName,
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 6.0,
              color: marker.color.withAlpha((opacity * 200).round()),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          textDirection: ui.TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout();

        canvas.save();
        canvas.translate(cx + nameR * cosA, cy + nameR * sinA);
        canvas.rotate(angle + math.pi / 2.0);
        nameTp.paint(
            canvas, Offset(-nameTp.width / 2.0, -nameTp.height / 2.0));
        canvas.restore();
      }
    }
  }

  void _drawLabelGlow(
    Canvas canvas,
    double cx,
    double cy,
    double labelR,
    double angle,
    String text,
    double fontSize,
  ) {
    // Draw the label twice with a gold MaskFilter blur for a glow effect.
    final glowPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: fontSize,
          color: AppColors.goldPrimary.withAlpha(140),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();

    final labelX = cx + labelR * math.cos(angle);
    final labelY = cy + labelR * math.sin(angle);

    canvas.save();
    canvas.translate(labelX, labelY);
    canvas.rotate(angle + math.pi / 2.0);

    // Save and apply blur paint layer for glow.
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.saveLayer(null, glowPaint);
    glowPainter.paint(
      canvas,
      Offset(-glowPainter.width / 2.0, -glowPainter.height / 2.0),
    );
    canvas.restore(); // restore saveLayer

    canvas.restore(); // restore translate+rotate
  }

  // ── shouldRepaint ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    return oldDelegate.ringState != ringState ||
        oldDelegate.progressFraction != progressFraction ||
        (oldDelegate.glowIntensity - glowIntensity).abs() > 0.005;
  }
}
