// clock_face_painter.dart
//
// Paints the luxury Swiss-Islamic watch dial face.
//
// Layers (bottom to top):
//   1. Outer bezel ring     — dark navy fill with gold border stroke.
//   2. Guilloche texture    — subtle crosshatch/engine-turned pattern in the dial.
//   3. Inner decorative ring — etched ring at 80 % of face radius.
//   4. Minute markers       — 60 silver ticks / dots at 1-minute intervals.
//   5. Hour markers         — 12 gold tick marks; variable weight by position.
//   6. Hour numerals        — optional gold Arabic or Roman hour labels.
//   7. Center cap           — small gold boss where hands pivot.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

// ── NumeralStyle ──────────────────────────────────────────────────────────────

/// Controls which numeral style to render on the watch dial.
enum NumeralStyle {
  /// No numerals — markers only.
  minimal,

  /// Eastern Arabic–Indic digits: ١ ٢ ٣ … ١٢
  arabicIndic,

  /// Roman numerals: I II III … XII
  roman,
}

// ── ClockFacePainter ──────────────────────────────────────────────────────────

/// [CustomPainter] that renders the static luxury watch dial.
///
/// Intentionally stateless — it does not know what time it is. Clock hands are
/// drawn by [HandsPainter] composited on top of this layer.
class ClockFacePainter extends CustomPainter {
  const ClockFacePainter({
    this.dialColor = AppColors.backgroundMid,
    this.markerColor = AppColors.goldPrimary,
    this.showNumerals = true,
    this.mode = NumeralStyle.arabicIndic,
    this.scaleFactor = 0.46,
  });

  /// Background fill for the dial surface.
  final Color dialColor;

  /// Primary color for hour markers and numerals.
  final Color markerColor;

  /// Whether to draw hour numerals.
  final bool showNumerals;

  /// Numeral style when [showNumerals] is true.
  final NumeralStyle mode;

  /// Fraction of the canvas half-size at which the dial face is drawn.
  /// 0.74 keeps the dial inside the Arabic temporal ring (78%–97% band).
  final double scaleFactor;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  double _radius(Size size) => math.min(size.width, size.height) / 2.0;

  // ── Layer 1: Outer bezel ───────────────────────────────────────────────────

  void _drawBezel(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    // Dial background fill — deep navy with subtle radial gradient.
    // Rich, precise — like polished onyx.
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.15, -0.25),
        radius: 1.15,
        colors: const [
          Color(0xFF0A0E28), // very deep blue-black at top
          Color(0xFF060818), // near-black mid
          Color(0xFF03050F), // deepest at edges
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fillPaint);

    // Outer bezel ring — hairline gold stroke.
    final outerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.goldPrimary.withAlpha(200);

    canvas.drawCircle(center, radius - 0.4, outerBorderPaint);

    // Inner dial ring — slightly smaller, more subtle.
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.goldDark.withAlpha(120);

    canvas.drawCircle(center, radius * 0.88, innerRingPaint);
  }

  // ── Layer 2: Guilloche texture ─────────────────────────────────────────────

  void _drawGuillocheTexture(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    // Minimal engine-turned pattern: just a few concentric rings for depth.
    // Very subtle — not distracting.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2
      ..color = const Color(0x08D4AF37);

    const int rings = 6;
    for (int r = 1; r <= rings; r++) {
      final frac = r / (rings + 1);
      canvas.drawCircle(center, radius * 0.87 * frac, ringPaint);
    }
  }

  // ── Layer 3: Inner decorative ring — removed (see _drawBezel) ─────────────

  void _drawInnerRing(Canvas canvas, Size size) {
    // Intentionally left empty — bezel now handles the two ring borders.
    // Keeping method signature for paint() call compatibility.
  }

  // ── Layer 4: Minute markers ────────────────────────────────────────────────

  void _drawMinuteMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    // Fine silver minute tick marks — barely-visible precision instrument feel.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55B0B0C0); // very subtle silver

    for (int m = 0; m < 60; m++) {
      if (m % 5 == 0) continue; // skip hour positions

      final angle = (m / 60.0) * math.pi * 2.0 - math.pi / 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Tiny tick from 87% to 90% of radius
      final outerR = radius * 0.870;
      final innerR = radius * 0.855;

      canvas.drawLine(
        Offset(center.dx + cosA * outerR, center.dy + sinA * outerR),
        Offset(center.dx + cosA * innerR, center.dy + sinA * innerR),
        tickPaint,
      );
    }
  }

  // ── Layer 5: Hour markers ──────────────────────────────────────────────────

  void _drawHourMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    for (int h = 1; h <= 12; h++) {
      final angle = (h / 12.0) * math.pi * 2.0 - math.pi / 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // All hour markers are elegant thin lines — cardinal hours slightly longer.
      final isCardinal = (h == 12 || h == 3 || h == 6 || h == 9);

      // Outer edge: just inside the inner dial ring.
      final outerR = radius * (isCardinal ? 0.870 : 0.870);
      // Cardinal markers go deeper; others are short.
      final innerR = radius * (isCardinal ? 0.820 : 0.845);
      // Weight: cardinal slightly heavier but still thin.
      final strokeW = isCardinal ? 1.5 : 0.8;

      final ox = center.dx + cosA * outerR;
      final oy = center.dy + sinA * outerR;
      final ix = center.dx + cosA * innerR;
      final iy = center.dy + sinA * innerR;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = AppColors.goldPrimary.withAlpha(isCardinal ? 230 : 180);

      canvas.drawLine(Offset(ox, oy), Offset(ix, iy), paint);
    }
  }

  // Keep these for binary compatibility — they are no longer called.
  void _drawDoubleBar(Canvas canvas, Offset center, double radius, double cosA, double sinA) {}
  void _drawThickBar(Canvas canvas, Offset center, double radius, double cosA, double sinA) {}
  void _drawThinLine(Canvas canvas, Offset center, double radius, double cosA, double sinA) {}

  // ── Layer 6: Hour numerals ─────────────────────────────────────────────────

  void _drawNumerals(Canvas canvas, Size size) {
    if (!showNumerals || mode == NumeralStyle.minimal) return;

    final center = _center(size);
    final radius = _radius(size) * scaleFactor;
    // Place numerals just inside the hour markers.
    final numRadius = radius * 0.63;

    for (int h = 1; h <= 12; h++) {
      final angle = (h / 12.0) * math.pi * 2.0 - math.pi / 2.0;
      final x = center.dx + math.cos(angle) * numRadius;
      final y = center.dy + math.sin(angle) * numRadius;

      final label = _labelFor(h);
      final textStyle = TextStyle(
        color: AppColors.goldPrimary,
        fontSize: radius * 0.11,
        fontWeight: FontWeight.w600,
        fontFamily: null,
        height: 1.0,
        shadows: const [
          Shadow(
            color: AppColors.goldDark,
            offset: Offset(0.5, 0.5),
            blurRadius: 2.0,
          ),
        ],
      );

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  String _labelFor(int hour) {
    if (mode == NumeralStyle.arabicIndic) {
      // Standard Western Arabic numerals (1–12)
      return hour.toString();
    } else {
      // Roman numerals.
      const labels = [
        '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
      ];
      return labels[hour];
    }
  }

  // ── Layer 7: Center cap ────────────────────────────────────────────────────

  void _drawCenterCap(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    // Small elegant center dot — like a premium Swiss jewel.
    // Keep it tiny: 1.5% of radius.
    final capR = radius * 0.015;

    // Very soft glow — barely perceptible.
    final glowPaint = Paint()
      ..color = AppColors.glowGold.withAlpha(100)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(center, capR * 2.2, glowPaint);

    // Gold dot with radial gradient for slight 3-D depth.
    final capPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [
          AppColors.goldLight,
          AppColors.goldPrimary,
          AppColors.goldDark,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: capR));

    canvas.drawCircle(center, capR, capPaint);

    // Hairline rim.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = AppColors.goldDark.withAlpha(160);

    canvas.drawCircle(center, capR, rimPaint);
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBezel(canvas, size);
    _drawGuillocheTexture(canvas, size);
    _drawInnerRing(canvas, size);
    _drawMinuteMarkers(canvas, size);
    _drawHourMarkers(canvas, size);
    _drawNumerals(canvas, size);
    _drawCenterCap(canvas, size);
  }

  @override
  bool shouldRepaint(ClockFacePainter oldDelegate) =>
      oldDelegate.dialColor != dialColor ||
      oldDelegate.markerColor != markerColor ||
      oldDelegate.showNumerals != showNumerals ||
      oldDelegate.mode != mode ||
      oldDelegate.scaleFactor != scaleFactor;
}
