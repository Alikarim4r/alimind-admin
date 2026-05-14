// segment_painter.dart
//
// CustomPainter for a single ring segment's glow effect and progress arc.
//
// Isolation rationale
// ───────────────────
// Drawing the active-segment bloom with [MaskFilter.blur] is GPU-intensive.
// By isolating it in a separate [CustomPainter] wrapped in [RepaintBoundary],
// Flutter can cache the raster for non-current segments and only re-rasterize
// this painter when the active segment changes or the glow pulse ticks.
//
// What this painter draws
// ───────────────────────
//   1. Radial gradient fill — period colour fading to transparent toward outer
//      and inner ring edges, giving a "luminous slab" appearance.
//   2. Progress arc fill    — filled arc sector proportional to elapsed time,
//      rendered above the gradient fill.
//   3. Outer glow bloom     — MaskFilter.blur halo on the progress arc edge.
//   4. Segment edge lines   — subtle gold lines at the start and end angles of
//      the segment, reinforcing the boundaries.
//
// This painter does NOT draw the ring background, dividers, or labels — those
// are handled by [RingPainter] for the full ring.
//
// Usage
// ─────
// ```dart
// RepaintBoundary(
//   child: CustomPaint(
//     painter: SegmentPainter(
//       segment: ringState.currentSegment,
//       progressFraction: data.progressFraction,
//       glowIntensity: calculator.glowIntensity(animTime),
//       outerRadius: outerR,
//       innerRadius: innerR,
//     ),
//   ),
// )
// ```

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/ring_state.dart';

// ── SegmentPainter ────────────────────────────────────────────────────────────

/// Isolated painter for the current-period glow effect and progress arc.
///
/// Should be wrapped in a [RepaintBoundary] so only this layer is
/// re-rasterised on animation ticks, leaving the rest of the ring paint cache
/// intact.
class SegmentPainter extends CustomPainter {
  const SegmentPainter({
    required this.segment,
    required this.progressFraction,
    required this.glowIntensity,
    required this.outerRadius,
    required this.innerRadius,
  });

  /// The single segment to draw the glow and progress for.
  final RingSegment segment;

  /// Elapsed fraction of this period, [0.0, 1.0].
  final double progressFraction;

  /// Current glow pulse intensity, [0.55, 1.0].
  final double glowIntensity;

  /// Outer radius of the ring in logical pixels (from the parent's geometry).
  final double outerRadius;

  /// Inner radius of the ring in logical pixels.
  final double innerRadius;

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Flutter canvas start offset: 0 rad in ring space = 12 o'clock =
  /// −π/2 in Flutter canvas space.
  static const double _startOffset = -math.pi / 2.0;

  /// Stroke width for the progress arc highlight line.
  static const double _progressStrokeWidth = 3.5;

  /// Stroke width for the segment edge lines.
  static const double _edgeStrokeWidth = 0.8;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (segment.sweepAngle <= 0) return;

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    final startFlutter = segment.startAngle + _startOffset;
    final sweep = segment.sweepAngle;
    final midR = (outerRadius + innerRadius) / 2.0;
    final ringWidth = outerRadius - innerRadius;

    // ── 1. Radial gradient fill ───────────────────────────────────────────────
    _drawRadialGradientFill(
        canvas, cx, cy, startFlutter, sweep, midR, ringWidth);

    // ── 2. Progress arc fill ─────────────────────────────────────────────────
    _drawProgressArcFill(canvas, cx, cy, startFlutter, sweep, midR, ringWidth);

    // ── 3. Outer glow bloom ───────────────────────────────────────────────────
    _drawGlowBloom(canvas, cx, cy, startFlutter, sweep, midR, ringWidth);

    // ── 4. Segment edge lines ─────────────────────────────────────────────────
    _drawEdgeLines(canvas, cx, cy, startFlutter, sweep);
  }

  // ── Private drawing layers ─────────────────────────────────────────────────

  void _drawRadialGradientFill(
    Canvas canvas,
    double cx,
    double cy,
    double startAngle,
    double sweep,
    double midR,
    double ringWidth,
  ) {
    // Build a path that is the arc sector (annular wedge).
    final path = _buildAnnularWedge(
        cx, cy, innerRadius, outerRadius, startAngle, sweep);

    // Radial gradient: period colour at midR, transparent at both edges.
    final gradientRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: outerRadius);

    final fillPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          segment.segmentColor.withOpacity(0.05),
          segment.segmentColor.withOpacity(0.35 * glowIntensity),
          segment.segmentColor.withOpacity(0.15),
          AppColors.transparent,
        ],
        stops: const [0.0, 0.55, 0.80, 1.0],
      ).createShader(gradientRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  void _drawProgressArcFill(
    Canvas canvas,
    double cx,
    double cy,
    double startAngle,
    double sweep,
    double midR,
    double ringWidth,
  ) {
    final clampedProgress = progressFraction.clamp(0.0, 1.0);
    if (clampedProgress <= 0.0) return;

    final progressSweep = sweep * clampedProgress;

    // Filled arc sector (annular wedge) up to progress.
    final progressPath = _buildAnnularWedge(
        cx, cy, innerRadius, outerRadius, startAngle, progressSweep);

    // Use a sweep gradient from the period's secondary colour to gold.
    final fillColor = Color.lerp(
      segment.segmentColor,
      segment.isDay ? AppColors.goldPrimary : AppColors.silverMid,
      0.4,
    )!;

    final progressFillPaint = Paint()
      ..color = fillColor.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(progressPath, progressFillPaint);

    // Bright leading-edge arc stroke at the current progress position.
    final leadingAngle = startAngle + progressSweep;
    final arcMidRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: midR);

    final progressArcPaint = Paint()
      ..color = Color.lerp(
        fillColor,
        AppColors.goldBright,
        0.55 * glowIntensity,
      )!
          .withOpacity(0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _progressStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcMidRect, startAngle, progressSweep, false, progressArcPaint);

    // Leading-edge dot (a small circle at the tip of the progress arc).
    final leadCos = math.cos(leadingAngle);
    final leadSin = math.sin(leadingAngle);
    final dotCenter = Offset(cx + midR * leadCos, cy + midR * leadSin);

    final dotGlowPaint = Paint()
      ..color = AppColors.goldBright.withOpacity(0.55 * glowIntensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * glowIntensity);
    canvas.drawCircle(dotCenter, _progressStrokeWidth * 1.8, dotGlowPaint);

    final dotPaint = Paint()
      ..color = AppColors.goldBright.withOpacity(0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, _progressStrokeWidth * 0.9, dotPaint);
  }

  void _drawGlowBloom(
    Canvas canvas,
    double cx,
    double cy,
    double startAngle,
    double sweep,
    double midR,
    double ringWidth,
  ) {
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: midR);

    // Wide outer bloom — faint, large blur radius.
    final outerBloomPaint = Paint()
      ..color = segment.glowColor.withOpacity(0.20 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 2.5
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, 12.0 + 6.0 * glowIntensity);
    canvas.drawArc(arcRect, startAngle, sweep, false, outerBloomPaint);

    // Tight inner bloom — brighter, small blur radius.
    final innerBloomPaint = Paint()
      ..color = segment.glowColor.withOpacity(0.50 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.6
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * glowIntensity);
    canvas.drawArc(arcRect, startAngle, sweep, false, innerBloomPaint);
  }

  void _drawEdgeLines(
    Canvas canvas,
    double cx,
    double cy,
    double startAngle,
    double sweep,
  ) {
    final edgePaint = Paint()
      ..color = AppColors.goldPrimary.withOpacity(0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeStrokeWidth
      ..strokeCap = StrokeCap.butt;

    // Start edge.
    _drawRadialLine(canvas, cx, cy, startAngle, edgePaint);

    // End edge.
    _drawRadialLine(canvas, cx, cy, startAngle + sweep, edgePaint);
  }

  void _drawRadialLine(
    Canvas canvas,
    double cx,
    double cy,
    double angle,
    Paint paint,
  ) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    canvas.drawLine(
      Offset(cx + innerRadius * cosA, cy + innerRadius * sinA),
      Offset(cx + outerRadius * cosA, cy + outerRadius * sinA),
      paint,
    );
  }

  // ── Geometry helper ────────────────────────────────────────────────────────

  /// Build an annular wedge [Path] — the filled region between [innerR] and
  /// [outerR] spanning [startAngle] to [startAngle] + [sweep].
  ///
  /// Uses clockwise arc for the outer edge and counter-clockwise for the inner
  /// edge so the path's interior is the ring segment area.
  Path _buildAnnularWedge(
    double cx,
    double cy,
    double innerR,
    double outerR,
    double startAngle,
    double sweep,
  ) {
    final outerRect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    final innerRect = Rect.fromCircle(center: Offset(cx, cy), radius: innerR);

    final path = Path();

    // Start at outer radius at startAngle.
    path.moveTo(
      cx + outerR * math.cos(startAngle),
      cy + outerR * math.sin(startAngle),
    );

    // Outer arc (CW).
    path.arcTo(outerRect, startAngle, sweep, false);

    // Line to inner radius at end angle.
    final endAngle = startAngle + sweep;
    path.lineTo(
      cx + innerR * math.cos(endAngle),
      cy + innerR * math.sin(endAngle),
    );

    // Inner arc (CCW — negative sweep).
    path.arcTo(innerRect, endAngle, -sweep, false);

    path.close();
    return path;
  }

  // ── shouldRepaint ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(covariant SegmentPainter oldDelegate) {
    return oldDelegate.segment != segment ||
        oldDelegate.progressFraction != progressFraction ||
        (oldDelegate.glowIntensity - glowIntensity).abs() > 0.005 ||
        oldDelegate.outerRadius != outerRadius ||
        oldDelegate.innerRadius != innerRadius;
  }
}
