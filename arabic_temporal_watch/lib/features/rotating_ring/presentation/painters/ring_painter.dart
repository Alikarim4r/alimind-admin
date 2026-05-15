// ring_painter.dart
//
// CustomPainter that draws the full 24-segment rotating Arabic temporal ring.
//
// Rendering layers (back to front)
// ──────────────────────────────────
//   1. Outer ring background  — dark navy arc with gold border
//   2. Segment fills          — arc fills colored per period, blended day/night
//   3. Segment dividers       — fine gold radial lines at each 15° boundary
//   4. Progress arc           — fills current segment proportional to elapsed time
//   5. Minute beads           — small glowing dots, one per 5 min of period length
//   6. Arabic labels          — curved text at each segment's midpoint arc
//   7. Current segment glow   — MaskFilter.blur gold/silver halo on active segment
//
// Coordinate system
// ─────────────────
//   Flutter canvas: 0 rad = 3 o'clock, angles increase clockwise.
//   Ring face:      0 rad = 12 o'clock (a −π/2 offset is applied before drawing).
//
// The ring itself is rendered at its natural orientation; the parent widget
// applies [Transform.rotate(angle: ringState.rotationAngle)] to spin the whole
// ring CCW so the current segment arrives at the 12 o'clock indicator.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/ring_state.dart';

// ── RingPainter ───────────────────────────────────────────────────────────────

/// [CustomPainter] that draws the entire 24-segment rotating Arabic ring.
///
/// Pass a [RingState] to the constructor and call [notifyListeners] / mark
/// the widget dirty whenever the state changes.  The [shouldRepaint] override
/// performs a cheap equality check so no pixels are touched when the state
/// is unchanged.
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
  /// Drives the progress arc that fills the active segment.
  final double progressFraction;

  /// Current glow pulse intensity — [0.55, 1.0].
  /// Output of [RingCalculator.glowIntensity] using the animation clock.
  final double glowIntensity;

  // ── Geometry constants ─────────────────────────────────────────────────────

  /// Outer radius of the ring arc as a fraction of half the canvas width.
  static const double _outerFraction = 0.48;

  /// Inner radius of the ring arc as a fraction of half the canvas width.
  static const double _innerFraction = 0.34;

  /// Extra radius used for the outer decorative border stroke.
  static const double _borderExtraFraction = 0.005;

  /// Stroke width for segment divider lines (logical pixels).
  static const double _dividerStrokeWidth = 0.6;

  /// Stroke width for the ring border stroke (logical pixels).
  static const double _borderStrokeWidth = 1.0;

  /// Stroke width for the progress arc highlight.
  static const double _progressStrokeWidth = 2.5;

  /// Radius of each minute bead dot (logical pixels).
  static const double _beadRadius = 1.8;

  /// Radial position of beads as a fraction between inner and outer radius.
  static const double _beadRadialFraction = 0.72;

  /// Font size for Arabic period labels (logical pixels).
  static const double _labelFontSize = 9.0;

  /// Font size for small transliteration labels below the Arabic (optional).
  static const double _subLabelFontSize = 6.5;

  /// Flutter canvas offset so that 0 rad = 12 o'clock (−π/2).
  static const double _startOffset = -math.pi / 2.0;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final halfW = size.width / 2.0;

    final outerR = halfW * _outerFraction;
    final innerR = halfW * _innerFraction;
    final midR = (outerR + innerR) / 2.0;
    final ringWidth = outerR - innerR;

    // Save the base canvas state so we can restore after each layer.
    canvas.save();

    // ── Layer 1: Ring background ─────────────────────────────────────────────
    _drawRingBackground(canvas, cx, cy, outerR, innerR, halfW);

    // ── Layer 2: Segment fills ────────────────────────────────────────────────
    _drawSegmentFills(canvas, cx, cy, outerR, innerR);

    // ── Layer 3: Segment dividers ─────────────────────────────────────────────
    _drawSegmentDividers(canvas, cx, cy, innerR, outerR);

    // ── Layer 4: Progress arc ─────────────────────────────────────────────────
    _drawProgressArc(canvas, cx, cy, outerR, innerR, ringWidth);

    // ── Layer 5: Minute beads ─────────────────────────────────────────────────
    _drawMinuteBeads(canvas, cx, cy, innerR, outerR, midR);

    // ── Layer 6: Arabic labels ────────────────────────────────────────────────
    _drawArabicLabels(canvas, cx, cy, midR, outerR, innerR, size);

    // ── Layer 7: Current segment glow ─────────────────────────────────────────
    _drawCurrentSegmentGlow(canvas, cx, cy, outerR, innerR);

    canvas.restore();
  }

  // ── Layer implementations ──────────────────────────────────────────────────

  void _drawRingBackground(
    Canvas canvas,
    double cx,
    double cy,
    double outerR,
    double innerR,
    double halfW,
  ) {
    final ringPaint = Paint()
      ..color = AppColors.backgroundMid.withOpacity(0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR;

    // Draw the solid dark ring track.
    canvas.drawCircle(Offset(cx, cy), (outerR + innerR) / 2.0, ringPaint);

    // Outer decorative gold border.
    final outerBorderPaint = Paint()
      ..color = AppColors.borderProminent
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderStrokeWidth;
    canvas.drawCircle(Offset(cx, cy), outerR, outerBorderPaint);

    // Inner decorative gold border.
    final innerBorderPaint = Paint()
      ..color = AppColors.borderNormal
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderStrokeWidth;
    canvas.drawCircle(Offset(cx, cy), innerR, innerBorderPaint);

    // Subtle inner shadow to give depth.
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          AppColors.transparent,
          AppColors.backgroundDeep.withOpacity(0.45),
        ],
        stops: const [0.78, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: outerR));
    canvas.drawCircle(Offset(cx, cy), outerR, shadowPaint);
  }

  void _drawSegmentFills(
    Canvas canvas,
    double cx,
    double cy,
    double outerR,
    double innerR,
  ) {
    final segments = ringState.segments;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    final ringWidth = outerR - innerR;

    // Determine total number of segments for distance-based opacity falloff.
    final int totalSegs = segments.length; // 24
    final currentIdx = segments.indexWhere((s) => s.isCurrent);

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.sweepAngle <= 0) continue;

      // Distance from current segment — used for smooth opacity gradient.
      // Wrap-around distance on a 24-segment ring.
      final rawDist = (i - currentIdx).abs();
      final dist = rawDist > totalSegs ~/ 2 ? totalSegs - rawDist : rawDist;

      // Smooth opacity falloff: current=full, adjacent=60%, far=20%.
      final double opacityMultiplier;
      if (seg.isCurrent) {
        opacityMultiplier = 1.0;
      } else if (dist == 1) {
        opacityMultiplier = 0.60;
      } else if (dist == 2) {
        opacityMultiplier = 0.38;
      } else {
        // Gradual falloff for farther segments.
        opacityMultiplier = math.max(0.10, 0.38 - (dist - 2) * 0.04);
      }

      // Current segment: warm gold fill; others: period color.
      final Color fillColor;
      if (seg.isCurrent) {
        // Warm gold blend — the active segment glows gold.
        fillColor = Color.lerp(
          seg.segmentColor,
          AppColors.goldPrimary,
          0.45,
        )!;
      } else {
        fillColor = seg.segmentColor;
      }

      final segPaint = Paint()
        ..color = fillColor.withOpacity(
            (seg.opacity * opacityMultiplier * (seg.isCurrent ? 0.42 : 0.22)).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth;

      final startFlutter = _toFlutter(seg.startAngle);
      canvas.drawArc(arcRect, startFlutter, seg.sweepAngle, false, segPaint);
    }
  }

  void _drawSegmentDividers(
    Canvas canvas,
    double cx,
    double cy,
    double innerR,
    double outerR,
  ) {
    // Hairline gold dividers — 0.5px, very refined.
    final dividerPaint = Paint()
      ..color = AppColors.goldPrimary.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 // hairline
      ..strokeCap = StrokeCap.butt;

    for (final seg in ringState.segments) {
      final angle = _toFlutter(seg.startAngle);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final innerPt = Offset(cx + innerR * cosA, cy + innerR * sinA);
      final outerPt = Offset(cx + outerR * cosA, cy + outerR * sinA);
      canvas.drawLine(innerPt, outerPt, dividerPaint);
    }
  }

  void _drawProgressArc(
    Canvas canvas,
    double cx,
    double cy,
    double outerR,
    double innerR,
    double ringWidth,
  ) {
    final currentSeg = ringState.segments.firstWhere(
      (s) => s.isCurrent,
      orElse: () => ringState.segments.first,
    );

    if (currentSeg.sweepAngle <= 0 || progressFraction <= 0) return;

    final progressSweep = currentSeg.sweepAngle * progressFraction.clamp(0.0, 1.0);
    final startFlutter = _toFlutter(currentSeg.startAngle);

    // Highlight arc — colored stroke at mid-ring radius.
    final progressMidR = (outerR + innerR) / 2.0;
    final progressRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: progressMidR);

    final progressPaint = Paint()
      ..color = Color.lerp(
        currentSeg.segmentColor,
        AppColors.goldBright,
        0.5 * glowIntensity,
      )!
          .withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _progressStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(progressRect, startFlutter, progressSweep, false, progressPaint);

    // Soft glow behind the progress arc.
    final glowPaint = Paint()
      ..color = currentSeg.glowColor.withOpacity(0.35 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _progressStrokeWidth * 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawArc(progressRect, startFlutter, progressSweep, false, glowPaint);
  }

  void _drawMinuteBeads(
    Canvas canvas,
    double cx,
    double cy,
    double innerR,
    double outerR,
    double midR,
  ) {
    final beadR = innerR + (outerR - innerR) * _beadRadialFraction;
    final isNightDominant = ringState.dayNightBlend > 0.5;

    for (final seg in ringState.segments) {
      final count = seg.beadCount.toInt();
      if (count <= 0) continue;

      final baseBeadColor = seg.isCurrent
          ? (isNightDominant ? AppColors.silverLight : AppColors.goldBright)
          : (isNightDominant
              ? AppColors.silverDim.withOpacity(0.6)
              : AppColors.goldAntique.withOpacity(0.5));

      final beadGlowColor = seg.isCurrent
          ? seg.glowColor.withOpacity(0.5 * glowIntensity)
          : Colors.transparent;

      final padding = seg.sweepAngle * 0.06;
      final usableSweep = seg.sweepAngle - 2.0 * padding;
      if (usableSweep <= 0) continue;

      for (var i = 0; i < count; i++) {
        final double angle;
        if (count == 1) {
          angle = _toFlutter(seg.startAngle + seg.sweepAngle / 2.0);
        } else {
          final frac = i / (count - 1);
          angle = _toFlutter(seg.startAngle + padding + frac * usableSweep);
        }

        final bx = cx + beadR * math.cos(angle);
        final by = cy + beadR * math.sin(angle);
        final beadCenter = Offset(bx, by);

        // Glow bloom on current segment beads.
        if (seg.isCurrent) {
          final glowPaint = Paint()
            ..color = beadGlowColor
            ..maskFilter = MaskFilter.blur(
                BlurStyle.normal, _beadRadius * 2.5 * glowIntensity);
          canvas.drawCircle(beadCenter, _beadRadius * 2.0, glowPaint);
        }

        // Solid bead dot.
        final solidPaint = Paint()
          ..color = baseBeadColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(beadCenter, _beadRadius, solidPaint);
      }
    }
  }

  void _drawArabicLabels(
    Canvas canvas,
    double cx,
    double cy,
    double midR,
    double outerR,
    double innerR,
    Size size,
  ) {
    // Label radius — center of the ring band.
    final labelR = (outerR + innerR) / 2.0;

    final int totalSegs = ringState.segments.length;
    final currentIdx = ringState.segments.indexWhere((s) => s.isCurrent);

    for (int i = 0; i < ringState.segments.length; i++) {
      final seg = ringState.segments[i];
      if (seg.sweepAngle <= 0) continue;

      // Distance-based opacity for labels too.
      final rawDist = (i - currentIdx).abs();
      final dist = rawDist > totalSegs ~/ 2 ? totalSegs - rawDist : rawDist;
      final double labelOpacity;
      if (seg.isCurrent) {
        labelOpacity = 1.0;
      } else if (dist == 1) {
        labelOpacity = 0.65;
      } else if (dist == 2) {
        labelOpacity = 0.40;
      } else {
        labelOpacity = math.max(0.08, 0.35 - dist * 0.05);
      }

      // Mid-angle of this segment in Flutter canvas coords.
      final midAngleFlutter = _toFlutter(seg.midAngle);

      // Current segment gets larger, bolder text with gold color.
      final fontSize = seg.isCurrent ? _labelFontSize * 1.35 : _labelFontSize;
      final fontWeight = seg.isCurrent ? FontWeight.w700 : FontWeight.w400;
      final textColor = seg.isCurrent
          ? AppColors.goldPrimary.withOpacity(labelOpacity)
          : seg.labelColor.withOpacity(labelOpacity * seg.opacity);

      // ── Arabic label ──────────────────────────────────────────────────────
      final arabicPainter = TextPainter(
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

      canvas.save();
      canvas.translate(
        cx + labelR * math.cos(midAngleFlutter),
        cy + labelR * math.sin(midAngleFlutter),
      );
      canvas.rotate(midAngleFlutter + math.pi / 2.0);

      arabicPainter.paint(
        canvas,
        Offset(-arabicPainter.width / 2.0, -arabicPainter.height / 2.0),
      );
      canvas.restore();
    }
  }

  void _drawCurrentSegmentGlow(
    Canvas canvas,
    double cx,
    double cy,
    double outerR,
    double innerR,
  ) {
    final currentSeg = ringState.segments.firstWhere(
      (s) => s.isCurrent,
      orElse: () => ringState.segments.first,
    );

    if (currentSeg.sweepAngle <= 0) return;

    final ringWidth = outerR - innerR;
    final midR = (outerR + innerR) / 2.0;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: midR);
    final startFlutter = _toFlutter(currentSeg.startAngle);

    // Outer bloom — wide, soft halo giving the "alive" feel.
    final outerGlowPaint = Paint()
      ..color = AppColors.goldPrimary.withOpacity(0.18 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 2.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + 5.0 * glowIntensity);
    canvas.drawArc(arcRect, startFlutter, currentSeg.sweepAngle, false, outerGlowPaint);

    // Inner warm gold bloom — tighter, more intense.
    final innerGlowPaint = Paint()
      ..color = AppColors.goldPrimary.withOpacity(0.38 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.7
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * glowIntensity);
    canvas.drawArc(arcRect, startFlutter, currentSeg.sweepAngle, false, innerGlowPaint);

    // Bright outer edge — hairline gold arc for precision.
    final edgePaint = Paint()
      ..color = AppColors.goldLight.withOpacity(0.75 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.butt;
    final outerEdgeRect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR - 0.4);
    canvas.drawArc(outerEdgeRect, startFlutter, currentSeg.sweepAngle, false, edgePaint);

    // Inner edge hairline.
    final innerEdgePaint = Paint()
      ..color = AppColors.goldPrimary.withOpacity(0.50 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.butt;
    final innerEdgeRect = Rect.fromCircle(center: Offset(cx, cy), radius: innerR + 0.4);
    canvas.drawArc(innerEdgeRect, startFlutter, currentSeg.sweepAngle, false, innerEdgePaint);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convert an angle in the ring's coordinate system (0 = 12 o'clock, CW) to
  /// Flutter's canvas coordinate system (0 = 3 o'clock, CW).
  double _toFlutter(double ringAngle) => ringAngle + _startOffset;

  // ── shouldRepaint ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    // Repaint when any of the inputs have changed.
    return oldDelegate.ringState != ringState ||
        oldDelegate.progressFraction != progressFraction ||
        // Glow changes every frame while animating — compare with a tolerance
        // so we don't skip repaints when the pulse is actively running.
        (oldDelegate.glowIntensity - glowIntensity).abs() > 0.005;
  }
}

