// ring_painter.dart
//
// CustomPainter that draws the 24-segment rotating Arabic temporal ring.
//
// Rendering layers (back to front)
// ──────────────────────────────────
//   1. Arc tick marks  — 24 small gold tick marks at 75% of canvas radius,
//                        one at each period boundary.
//   2. Floating labels — 13 Arabic period labels (offset -6 to +6 from current),
//                        with distance-based opacity and font-size gradient.
//                        Current period: white with gold glow.
//                        Night periods: moonlight/silver color.
//                        Others: gold.
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
  });

  /// The complete ring render state produced by [RingCalculator].
  final RingState ringState;

  /// How far through the current temporal period we are — [0.0, 1.0].
  final double progressFraction;

  /// Current glow pulse intensity — [0.55, 1.0].
  final double glowIntensity;

  // ── Geometry constants ─────────────────────────────────────────────────────

  /// Radial position of arc tick marks as a fraction of half-canvas width.
  static const double _tickRadiusFraction = 0.75;

  /// Radial position of floating labels as a fraction of half-canvas width.
  static const double _labelRadiusFraction = 0.69;

  /// Flutter canvas offset so that 0 rad = 12 o'clock (−π/2).
  static const double _startOffset = -math.pi / 2.0;

  /// Number of visible label offsets on each side of the current period.
  static const int _labelHalfRange = 6;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final halfW = size.width / 2.0;

    final tickR = halfW * _tickRadiusFraction;
    final labelR = halfW * _labelRadiusFraction;

    // ── Layer 1: Arc tick marks ───────────────────────────────────────────────
    _drawArcTicks(canvas, cx, cy, tickR, halfW);

    // ── Layer 2: Floating Arabic labels ──────────────────────────────────────
    _drawFloatingLabels(canvas, cx, cy, labelR, size);
  }

  // ── Layer implementations ──────────────────────────────────────────────────

  void _drawArcTicks(
    Canvas canvas,
    double cx,
    double cy,
    double tickR,
    double halfW,
  ) {
    // 24 small arc tick marks at period boundaries.
    // Drawn in the painter's local coordinate system (before parent rotation).
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldPrimary.withAlpha(107); // ~42% opacity

    const segmentAngle = math.pi * 2.0 / 24.0;

    for (int i = 0; i < 24; i++) {
      // Natural ring angle: 0 = 12 o'clock start, shifted by _startOffset for flutter.
      final angle = _startOffset + i * segmentAngle;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Short tick outward: 2px long.
      const tickLen = 2.0;
      final outerX = cx + (tickR + tickLen) * cosA;
      final outerY = cy + (tickR + tickLen) * sinA;
      final innerX = cx + (tickR - tickLen) * cosA;
      final innerY = cy + (tickR - tickLen) * sinA;

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);
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

      final fontSize = 12.0 + norm * 10.0; // 12 to 22 px

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
