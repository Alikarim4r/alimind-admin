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
  });

  /// Background fill for the dial surface.
  final Color dialColor;

  /// Primary color for hour markers and numerals.
  final Color markerColor;

  /// Whether to draw hour numerals.
  final bool showNumerals;

  /// Numeral style when [showNumerals] is true.
  final NumeralStyle mode;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  double _radius(Size size) => math.min(size.width, size.height) / 2.0;

  // ── Layer 1: Outer bezel ───────────────────────────────────────────────────

  void _drawBezel(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Dial background fill — deep navy.
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.2,
        colors: const [
          Color(0xFF0E1340),
          AppColors.backgroundMid,
          AppColors.backgroundDeep,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fillPaint);

    // Gold outer border stroke — 2 px.
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = AppColors.goldPrimary;

    canvas.drawCircle(center, radius - 1.0, borderPaint);

    // Subtle inner shadow ring (dark translucent, slightly smaller radius).
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = const Color(0x30000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawCircle(center, radius - 3.0, shadowPaint);
  }

  // ── Layer 2: Guilloche texture ─────────────────────────────────────────────

  void _drawGuillocheTexture(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Engine-turned crosshatch: two families of concentric arcs at ±45°.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25
      ..color = const Color(0x10D4AF37); // very subtle gold tint

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.88)),
    );

    const int lines = 36;
    for (int i = 0; i < lines; i++) {
      final t = (i / lines) * 2.0 - 1.0; // [-1, 1]
      final offset = t * radius * 0.88;

      // Horizontal family.
      canvas.drawLine(
        Offset(center.dx - radius, center.dy + offset),
        Offset(center.dx + radius, center.dy + offset),
        linePaint,
      );
      // Vertical family.
      canvas.drawLine(
        Offset(center.dx + offset, center.dy - radius),
        Offset(center.dx + offset, center.dy + radius),
        linePaint,
      );
    }

    // Concentric ring pattern overlaid on crosshatch.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = const Color(0x08D4AF37);

    const int rings = 12;
    for (int r = 1; r <= rings; r++) {
      canvas.drawCircle(center, radius * 0.88 * r / rings, ringPaint);
    }

    canvas.restore();
  }

  // ── Layer 3: Inner decorative ring ────────────────────────────────────────

  void _drawInnerRing(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);
    final ringRadius = radius * 0.80;

    // Outer fine line.
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.goldPrimary.withAlpha(180);

    canvas.drawCircle(center, ringRadius, outerPaint);

    // Inner fine line — forms a thin etched channel.
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.goldDark.withAlpha(140);

    canvas.drawCircle(center, ringRadius - 2.5, innerPaint);

    // Faint fill between the two lines.
    final channelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0x18D4AF37);

    canvas.drawCircle(center, ringRadius - 1.25, channelPaint);
  }

  // ── Layer 4: Minute markers ────────────────────────────────────────────────

  void _drawMinuteMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Minute dots sit just inside the inner decorative ring.
    final dotRadius = radius * 0.795;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFC0C0C0); // mid silver

    for (int m = 0; m < 60; m++) {
      // Skip positions that coincide with hour markers.
      if (m % 5 == 0) continue;

      final angle = (m / 60.0) * math.pi * 2.0 - math.pi / 2.0;
      final x = center.dx + math.cos(angle) * dotRadius;
      final y = center.dy + math.sin(angle) * dotRadius;

      canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
    }
  }

  // ── Layer 5: Hour markers ──────────────────────────────────────────────────

  void _drawHourMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    for (int h = 1; h <= 12; h++) {
      final angle = (h / 12.0) * math.pi * 2.0 - math.pi / 2.0;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      if (h == 12) {
        _drawDoubleBar(canvas, center, radius, cosA, sinA);
      } else if (h == 3 || h == 6 || h == 9) {
        _drawThickBar(canvas, center, radius, cosA, sinA);
      } else {
        _drawThinLine(canvas, center, radius, cosA, sinA);
      }
    }
  }

  /// 12 o'clock: double gold bar (two parallel rectangles).
  void _drawDoubleBar(
    Canvas canvas,
    Offset center,
    double radius,
    double cosA,
    double sinA,
  ) {
    final outerR = radius * 0.92;
    final innerR = radius * 0.72;
    final halfGap = 2.0; // half-gap between twin bars

    // Perpendicular direction.
    final perpX = -sinA;
    final perpY = cosA;

    for (final sign in [-1.0, 1.0]) {
      final ox = center.dx + cosA * outerR + perpX * sign * halfGap;
      final oy = center.dy + sinA * outerR + perpY * sign * halfGap;
      final ix = center.dx + cosA * innerR + perpX * sign * halfGap;
      final iy = center.dy + sinA * innerR + perpY * sign * halfGap;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: const [AppColors.goldLight, AppColors.goldPrimary],
        ).createShader(
          Rect.fromPoints(Offset(ox, oy), Offset(ix, iy)),
        );

      canvas.drawLine(Offset(ox, oy), Offset(ix, iy), paint);
    }
  }

  /// 3/6/9 o'clock: single thick gold bar.
  void _drawThickBar(
    Canvas canvas,
    Offset center,
    double radius,
    double cosA,
    double sinA,
  ) {
    final outerR = radius * 0.92;
    final innerR = radius * 0.74;

    final ox = center.dx + cosA * outerR;
    final oy = center.dy + sinA * outerR;
    final ix = center.dx + cosA * innerR;
    final iy = center.dy + sinA * innerR;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: const [AppColors.goldLight, AppColors.goldPrimary],
      ).createShader(Rect.fromPoints(Offset(ox, oy), Offset(ix, iy)));

    canvas.drawLine(Offset(ox, oy), Offset(ix, iy), paint);
  }

  /// All other hours: thin gold line.
  void _drawThinLine(
    Canvas canvas,
    Offset center,
    double radius,
    double cosA,
    double sinA,
  ) {
    final outerR = radius * 0.91;
    final innerR = radius * 0.80;

    final ox = center.dx + cosA * outerR;
    final oy = center.dy + sinA * outerR;
    final ix = center.dx + cosA * innerR;
    final iy = center.dy + sinA * innerR;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldPrimary.withAlpha(230);

    canvas.drawLine(Offset(ox, oy), Offset(ix, iy), paint);
  }

  // ── Layer 6: Hour numerals ─────────────────────────────────────────────────

  void _drawNumerals(Canvas canvas, Size size) {
    if (!showNumerals || mode == NumeralStyle.minimal) return;

    final center = _center(size);
    final radius = _radius(size);
    // Place numerals just inside the hour markers.
    final numRadius = radius * 0.63;

    for (int h = 1; h <= 12; h++) {
      final angle = (h / 12.0) * math.pi * 2.0 - math.pi / 2.0;
      final x = center.dx + math.cos(angle) * numRadius;
      final y = center.dy + math.sin(angle) * numRadius;

      final label = _labelFor(h);
      final textStyle = TextStyle(
        color: AppColors.goldPrimary,
        fontSize: radius * 0.095,
        fontWeight: FontWeight.w600,
        fontFamily: mode == NumeralStyle.arabicIndic ? 'ArabicDisplay' : null,
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
      const labels = [
        '', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠', '١١', '١٢',
      ];
      return labels[hour];
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
    final radius = _radius(size);

    // Outer glow halo.
    final glowPaint = Paint()
      ..color = AppColors.glowGold
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(center, radius * 0.040, glowPaint);

    // Gold boss gradient.
    final capPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: const [
          AppColors.goldLight,
          AppColors.goldPrimary,
          AppColors.goldDark,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.038),
      );

    canvas.drawCircle(center, radius * 0.038, capPaint);

    // Fine black-outlined rim for the jewel effect.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.goldDark;

    canvas.drawCircle(center, radius * 0.038, rimPaint);

    // Specular highlight dot.
    final specPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xB0FFFFFF);

    canvas.drawCircle(
      Offset(center.dx - radius * 0.012, center.dy - radius * 0.012),
      radius * 0.008,
      specPaint,
    );
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
      oldDelegate.mode != mode;
}
