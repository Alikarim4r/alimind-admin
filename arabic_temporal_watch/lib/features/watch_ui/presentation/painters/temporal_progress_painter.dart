// temporal_progress_painter.dart
//
// Paints the temporal period progress indicator inside the watch face ring.
//
// Layers (bottom to top):
//   1. Background arc    — full-circle thin dark arc (track).
//   2. Progress arc      — thick colored arc, fills [progressFraction] of circle.
//                          Gradient: period primaryColor → brighter period color.
//   3. End-point glow    — radial bloom at the leading tip of the progress arc.
//   4. Period label      — at the top: Arabic name + elapsed/total in Arabic
//                          numerals, e.g. "الضحى  ٣٢/٦٨ دقيقة".
//
// Geometry:
//   • The arc is centered on the canvas.  Its radius is [progressRadiusFraction]
//     × half-canvas.
//   • 0 % progress = no arc drawn; 100 % = full circle.
//   • The arc starts at the 12 o'clock position (−π/2) and sweeps clockwise.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../temporal_engine/domain/arabic_period.dart';

// ── TemporalProgressPainter ───────────────────────────────────────────────────

/// [CustomPainter] that renders the Arabic temporal period progress arc and
/// its accompanying Arabic-language label.
class TemporalProgressPainter extends CustomPainter {
  const TemporalProgressPainter({
    required this.temporalData,
    this.animationValue = 0.0,
    this.progressRadiusFraction = 0.70,
    this.trackStrokeWidth = 1.0,   // thinner — precision instrument feel
    this.progressStrokeWidth = 3.5, // slimmer progress indicator
  });

  /// Full temporal state snapshot — supplies progress fraction, period colors,
  /// Arabic name, elapsed and remaining durations.
  final TemporalData temporalData;

  /// 0.0–1.0 animation value for the end-point glow pulse and label fade.
  final double animationValue;

  /// Arc center radius as a fraction of the half-canvas size.
  final double progressRadiusFraction;

  /// Track arc stroke width in logical pixels.
  final double trackStrokeWidth;

  /// Progress arc stroke width in logical pixels.
  final double progressStrokeWidth;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  double _radius(Size size) =>
      math.min(size.width, size.height) / 2.0 * progressRadiusFraction;

  // Angle: 12 o'clock = −π/2; progress sweeps clockwise.
  static const double _startAngle = -math.pi / 2.0;

  // ── Layer 1: Background track ──────────────────────────────────────────────

  void _drawTrack(Canvas canvas, Offset center, double radius) {
    // Sweep-graded track: brighter at the top (12 o'clock) where the arc
    // begins, fading toward the bottom — suggests a machined groove.
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + math.pi * 2.0,
        colors: [
          AppColors.goldPrimary.withAlpha(70),
          AppColors.goldPrimary.withAlpha(30),
          AppColors.goldDark.withAlpha(26),
          AppColors.goldPrimary.withAlpha(70),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, trackPaint);
  }

  // ── Layer 2: Progress arc ──────────────────────────────────────────────────

  void _drawProgressArc(Canvas canvas, Offset center, double radius) {
    final fraction = temporalData.progressFraction.clamp(0.0, 1.0);
    if (fraction <= 0.001) return;

    final sweepAngle = fraction * math.pi * 2.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Colors: period primary → champagne-warmed mid → brightened leading edge.
    final primary = temporalData.primaryColor;
    final warm = Color.lerp(primary, AppColors.goldChampagne, 0.28) ?? primary;
    final bright = Color.lerp(primary, Colors.white, 0.35) ?? primary;

    // Soft under-bloom so the arc appears lit from within.
    final bloomPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressStrokeWidth * 2.6
      ..strokeCap = StrokeCap.round
      ..color = primary.withAlpha(46)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, progressStrokeWidth * 1.4);
    canvas.drawArc(rect, _startAngle, sweepAngle, false, bloomPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressStrokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + sweepAngle,
        colors: [primary, warm, bright],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, _startAngle, sweepAngle, false, progressPaint);

    // Hairline champagne highlight riding the outer edge of the arc — reads as
    // light catching a raised metal band.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressStrokeWidth * 0.22
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldChampagne.withAlpha(90);
    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius + progressStrokeWidth * 0.34,
      ),
      _startAngle,
      sweepAngle,
      false,
      edgePaint,
    );
  }

  // ── Layer 3: End-point glow ────────────────────────────────────────────────

  void _drawEndGlow(Canvas canvas, Offset center, double radius) {
    final fraction = temporalData.progressFraction.clamp(0.0, 1.0);
    if (fraction <= 0.001) return;

    final sweepAngle = fraction * math.pi * 2.0;
    final tipAngle = _startAngle + sweepAngle;

    final tipX = center.dx + math.cos(tipAngle) * radius;
    final tipY = center.dy + math.sin(tipAngle) * radius;
    final tipPos = Offset(tipX, tipY);

    final primary = temporalData.primaryColor;
    final bright = Color.lerp(primary, Colors.white, 0.40) ?? primary;

    // Pulsing glow: radius oscillates slightly with [animationValue].
    final pulseScale = 1.0 + 0.2 * math.sin(animationValue * math.pi * 2.0);
    final glowRadius = progressStrokeWidth * 2.4 * pulseScale;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          bright.withAlpha(200),
          primary.withAlpha(100),
          primary.withAlpha(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: tipPos, radius: glowRadius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, progressStrokeWidth * 0.8);

    canvas.drawCircle(tipPos, glowRadius, glowPaint);

    // Small bright dot at the exact tip.
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = bright.withAlpha(230);

    canvas.drawCircle(tipPos, progressStrokeWidth * 0.55, dotPaint);
  }

  // ── Layer 4: Period label ──────────────────────────────────────────────────

  void _drawLabel(Canvas canvas, Offset center, double radius, Size size) {
    // Subtle overlay: Arabic period name positioned inside the arc.
    // Positioned at ~68% height from center toward the arc — upper zone.
    final faceRadius = math.min(size.width, size.height) / 2.0;
    final labelCenterY = center.dy - faceRadius * 0.38;

    // ── Arabic period name — large, champagne-gold, cinematic ──
    final nameStyle = TextStyle(
      color: AppColors.goldChampagne.withAlpha(228),
      fontSize: math.min(size.width, size.height) * 0.052,
      fontFamily: 'ArabicDisplay',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      shadows: [
        const Shadow(
          color: Color(0x80000000),
          offset: Offset(0, 1),
          blurRadius: 6.0,
        ),
        Shadow(
          color: AppColors.glowGold.withAlpha(90),
          offset: Offset.zero,
          blurRadius: 12.0,
        ),
      ],
    );

    final namePainter = TextPainter(
      text: TextSpan(text: temporalData.arabicName, style: nameStyle),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: radius * 1.6);

    namePainter.paint(
      canvas,
      Offset(
        center.dx - namePainter.width / 2,
        labelCenterY - namePainter.height / 2,
      ),
    );

    // ── Remaining time — small, silver, below the name ──
    final remaining = temporalData.remaining;
    final remainStr = _formatRemainingMinutes(remaining);

    final subStyle = TextStyle(
      color: AppColors.crescentSilver.withAlpha(175),
      fontSize: math.min(size.width, size.height) * 0.026,
      fontFamily: 'ArabicDisplay',
      fontWeight: FontWeight.w300,
      letterSpacing: 1.5,
      shadows: const [
        Shadow(color: Color(0x70000000), offset: Offset(0, 1), blurRadius: 4.0),
      ],
    );

    final subPainter = TextPainter(
      text: TextSpan(text: remainStr, style: subStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: radius * 1.6);

    subPainter.paint(
      canvas,
      Offset(
        center.dx - subPainter.width / 2,
        labelCenterY + namePainter.height / 2 + 3.0,
      ),
    );
  }

  /// Formats remaining time as MM:SS or HH:MM:SS using Eastern Arabic-Indic digits.
  String _formatRemainingMinutes(Duration d) {
    if (d <= Duration.zero) return '٠٠:٠٠';
    const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String toIndic(int n, int pad) =>
        n.toString().padLeft(pad, '0').split('').map((c) => indic[int.parse(c)]).join();
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${toIndic(h, 2)}:${toIndic(m, 2)}:${toIndic(s, 2)}';
    return '${toIndic(m, 2)}:${toIndic(s, 2)}';
  }

  // ── Decorative outer ring accent ──────────────────────────────────────────

  void _drawOuterAccentRing(Canvas canvas, Offset center, double radius) {
    // Two hairline rings framing the progress arc — a machined channel effect.
    // The outer ring is champagne-warm, the inner one burnished, so the arc
    // appears recessed between two turned metal edges.
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.goldChampagne.withAlpha(48);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.goldDark.withAlpha(60);

    canvas.drawCircle(
        center, radius + progressStrokeWidth / 2.0 + 2.0, outerPaint);
    canvas.drawCircle(
        center, radius - progressStrokeWidth / 2.0 - 2.0, innerPaint);
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    _drawOuterAccentRing(canvas, center, radius);
    _drawTrack(canvas, center, radius);
    _drawProgressArc(canvas, center, radius);
    _drawEndGlow(canvas, center, radius);
    _drawLabel(canvas, center, radius, size);
  }

  @override
  bool shouldRepaint(TemporalProgressPainter oldDelegate) =>
      oldDelegate.temporalData != temporalData ||
      oldDelegate.animationValue != animationValue ||
      oldDelegate.progressRadiusFraction != progressRadiusFraction ||
      oldDelegate.progressStrokeWidth != progressStrokeWidth;
}
