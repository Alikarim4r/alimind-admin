// clock_face_painter.dart
//
// Paints the luxury Swiss-Islamic watch dial face.
//
// Layers (bottom to top):
//   1. Outer bezel ring     — dark navy fill with gold border stroke.
//   2. Guilloche texture    — engine-turned radial lines + concentric rings.
//   3. Minute markers       — 48 silver ticks at 1-minute intervals (non-5).
//   4. Hour markers         — 12 luxury filled baton markers; variable weight.
//   5. Hour numerals        — optional Eastern Arabic-Indic or Roman labels.
//   6. Center cap           — multi-layer jeweled boss where hands pivot.

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
    final outerR = radius * 0.82;

    // Radial engine-turned lines: 72 lines every 5°, very thin and low-opacity
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = const Color(0x09D4AF37);
    const int lineCount = 72;
    for (int i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * math.pi * 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + cosA * radius * 0.06, center.dy + sinA * radius * 0.06),
        Offset(center.dx + cosA * outerR, center.dy + sinA * outerR),
        linePaint,
      );
    }

    // Concentric rings that cross the radial lines to create a basket-weave texture
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25
      ..color = const Color(0x08D4AF37);
    const int ringCount = 9;
    for (int r = 1; r <= ringCount; r++) {
      canvas.drawCircle(center, outerR * r / ringCount, ringPaint);
    }
  }

  // ── Layer 4: Minute markers ────────────────────────────────────────────────

  void _drawMinuteMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    final onePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x30B0B0C0);

    for (int m = 0; m < 60; m++) {
      if (m % 5 == 0) continue; // hour positions handled by baton markers
      final angle = (m / 60.0) * math.pi * 2.0 - math.pi / 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final outerR = radius * 0.870;
      final innerR = radius * 0.858;
      canvas.drawLine(
        Offset(center.dx + cosA * outerR, center.dy + sinA * outerR),
        Offset(center.dx + cosA * innerR, center.dy + sinA * innerR),
        onePaint,
      );
    }
  }

  // ── Layer 5: Hour markers ──────────────────────────────────────────────────

  void _drawHourMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    for (int h = 1; h <= 12; h++) {
      final angle = (h / 12.0) * math.pi * 2.0 - math.pi / 2.0;
      final isCardinal = h == 3 || h == 6 || h == 9;
      final isTwelve = h == 12;

      final markerLen = isTwelve
          ? radius * 0.095
          : isCardinal
              ? radius * 0.072
              : radius * 0.052;
      final markerW = isTwelve
          ? radius * 0.024
          : isCardinal
              ? radius * 0.018
              : radius * 0.013;

      final outerEdge = radius * 0.868;
      final midR = outerEdge - markerLen / 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      canvas.save();
      canvas.translate(center.dx + midR * cosA, center.dy + midR * sinA);
      canvas.rotate(angle + math.pi / 2.0);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: markerW, height: markerLen),
        Radius.circular(markerW / 2.5),
      );

      final alpha = isTwelve ? 240 : (isCardinal ? 220 : 190);
      final markerPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.goldDark.withAlpha((alpha * 0.70).round()),
            AppColors.goldLight.withAlpha(alpha),
            AppColors.goldPale.withAlpha(alpha),
            AppColors.goldPrimary.withAlpha(alpha),
            AppColors.goldDark.withAlpha((alpha * 0.70).round()),
          ],
          stops: const [0.0, 0.20, 0.50, 0.80, 1.0],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: markerW, height: markerLen),
        );
      canvas.drawRRect(rect, markerPaint);
      canvas.restore();
    }
  }

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
        fontSize: radius * 0.13,
        fontWeight: FontWeight.w600,
        fontFamily: 'ArabicDisplay',
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
      const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      return hour.toString().split('').map((d) => indic[int.parse(d)]).join();
    }
    const labels = [
      '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'
    ];
    return labels[hour];
  }

  // ── Layer 7: Center cap ────────────────────────────────────────────────────

  void _drawCenterCap(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;
    final capR = radius * 0.028;

    // Warm outer glow
    final glowPaint = Paint()
      ..color = AppColors.glowGold.withAlpha(65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, capR * 2.8, glowPaint);

    // Dark outer bezel ring (like a watch stem bearing)
    canvas.drawCircle(
      center,
      capR * 1.15,
      Paint()..color = const Color(0xFF120D00),
    );

    // Main jewel cap — multi-stop radial gradient for gemstone depth
    final capPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 1.0,
        colors: const [
          Color(0xFFFFFBE8),
          Color(0xFFEDD458),
          Color(0xFFD4AF37),
          Color(0xFF9B7D1A),
          Color(0xFF4A3000),
        ],
        stops: const [0.0, 0.18, 0.45, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: capR));
    canvas.drawCircle(center, capR, capPaint);

    // Hairline rim
    canvas.drawCircle(
      center,
      capR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = AppColors.goldDark.withAlpha(200),
    );

    // Specular highlight — tiny bright spot simulating gem catching light
    canvas.drawCircle(
      Offset(center.dx - capR * 0.28, center.dy - capR * 0.28),
      capR * 0.22,
      Paint()..color = const Color(0xD8FFFFFF),
    );
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBezel(canvas, size);
    _drawGuillocheTexture(canvas, size);
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
