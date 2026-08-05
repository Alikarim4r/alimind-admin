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
  //
  // Multi-layer luxury bezel inspired by high-end Swiss watches:
  //   • Outer diffuse gold halo   — soft champagne bloom
  //   • Brushed gold outer ring   — metallic diagonal gradient
  //   • Dark bezel groove         — shadowed recess
  //   • Polished gold inner ring  — bright highlight
  //   • Sapphire crystal dial     — jewel-tone radial fill w/ specular sheen
  //   • Inner hairline            — burnished gold accent

  void _drawBezel(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Outer champagne halo — subtle bloom around the whole dial ──────────
    final haloPaint = Paint()
      ..color = AppColors.glowChampagne
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.045);
    canvas.drawCircle(center, radius * 1.02, haloPaint);

    // ── Brushed outer bezel ring — metallic diagonal gradient ──────────────
    final outerBezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.020
      ..shader = AppColors.metallicGoldGradient.createShader(rect);
    canvas.drawCircle(center, radius - radius * 0.010, outerBezelPaint);

    // ── Bezel groove — thin dark recess separating outer / inner rings ────
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.006
      ..color = const Color(0xFF040610);
    canvas.drawCircle(center, radius - radius * 0.023, groovePaint);

    // ── Polished inner bezel ring — bright highlight ──────────────────────
    final innerBezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.goldChampagne,
          AppColors.goldLight,
          AppColors.goldPrimary,
          AppColors.goldDark,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius - radius * 0.032, innerBezelPaint);

    // ── Sapphire-crystal dial background ──────────────────────────────────
    final dialR = radius - radius * 0.038;
    final dialRect = Rect.fromCircle(center: center, radius: dialR);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = AppColors.dialSapphireGradient.createShader(dialRect);
    canvas.drawCircle(center, dialR, fillPaint);

    // Specular crystal sheen — a soft off-center highlight simulating light
    // catching a polished sapphire crystal.
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.65),
        radius: 0.9,
        colors: [
          const Color(0x18FFFFFF),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 1.0],
      ).createShader(dialRect);
    canvas.drawCircle(center, dialR, sheenPaint);

    // ── Inner hairline — burnished gold accent inside the dial ────────────
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.goldDark.withAlpha(140);
    canvas.drawCircle(center, radius * 0.88, innerRingPaint);
  }

  // ── Layer 2: Guilloche texture ─────────────────────────────────────────────

  void _drawGuillocheTexture(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;
    final outerR = radius * 0.82;

    // Radial engine-turned lines — champagne-tinted for warmer sheen.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.35
      ..color = const Color(0x0EF7E6A8);
    const int lineCount = 96;
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

    // Concentric rings — alternating brightness for a woven-metal effect.
    final ringPaintBright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.30
      ..color = const Color(0x10D4AF37);
    final ringPaintDim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.22
      ..color = const Color(0x08E8B4A0); // subtle rose-gold cross-tone
    const int ringCount = 11;
    for (int r = 1; r <= ringCount; r++) {
      final paint = r.isEven ? ringPaintBright : ringPaintDim;
      canvas.drawCircle(center, outerR * r / ringCount, paint);
    }
  }

  // ── Layer 4: Minute markers ────────────────────────────────────────────────

  void _drawMinuteMarkers(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size) * scaleFactor;

    final onePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.silverMid.withAlpha(80);

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

      final markerRect =
          Rect.fromCenter(center: Offset.zero, width: markerW, height: markerLen);
      final rect = RRect.fromRectAndRadius(
        markerRect,
        Radius.circular(markerW / 2.5),
      );

      // Soft drop shadow — lifts the baton off the dial
      final shadowRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(0.5, 1.0),
          width: markerW,
          height: markerLen,
        ),
        Radius.circular(markerW / 2.5),
      );
      canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = AppColors.backgroundDeep.withAlpha(160)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );

      final alpha = isTwelve ? 245 : (isCardinal ? 225 : 195);
      final markerPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.goldDark.withAlpha((alpha * 0.65).round()),
            AppColors.goldPrimary.withAlpha(alpha),
            AppColors.goldChampagne.withAlpha(alpha),
            AppColors.goldLight.withAlpha(alpha),
            AppColors.goldPrimary.withAlpha(alpha),
            AppColors.goldDark.withAlpha((alpha * 0.65).round()),
          ],
          stops: const [0.0, 0.20, 0.45, 0.55, 0.80, 1.0],
        ).createShader(markerRect);
      canvas.drawRRect(rect, markerPaint);

      // Hairline highlight along the top edge — polished-metal sheen
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = AppColors.goldChampagne.withAlpha(180);
      canvas.drawLine(
        Offset(-markerW / 2 + 0.6, -markerLen / 2 + 0.6),
        Offset(markerW / 2 - 0.6, -markerLen / 2 + 0.6),
        highlightPaint,
      );

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
        color: AppColors.goldChampagne,
        fontSize: radius * 0.135,
        fontWeight: FontWeight.w700,
        fontFamily: 'ArabicDisplay',
        height: 1.0,
        shadows: [
          Shadow(
            color: AppColors.goldDark.withAlpha(220),
            offset: const Offset(0.4, 0.6),
            blurRadius: 1.6,
          ),
          Shadow(
            color: AppColors.glowGold.withAlpha(80),
            offset: Offset.zero,
            blurRadius: 4.0,
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
    final capR = radius * 0.030;

    // Wide champagne bloom — atmospheric glow
    canvas.drawCircle(
      center,
      capR * 3.2,
      Paint()
        ..color = AppColors.glowChampagne
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, capR * 2.0),
    );

    // Warm gold glow — closer, brighter halo
    canvas.drawCircle(
      center,
      capR * 2.4,
      Paint()
        ..color = AppColors.glowGold.withAlpha(75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, capR * 1.4),
    );

    // Outer bezel setting — dark burnished ring around the jewel
    canvas.drawCircle(
      center,
      capR * 1.28,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: const [Color(0xFF1A1200), Color(0xFF060400)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: capR * 1.28)),
    );

    // Fine gold bezel ring around the setting
    canvas.drawCircle(
      center,
      capR * 1.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = AppColors.goldDark.withAlpha(220),
    );

    // Main jewel cap — 6-stop premium gradient (from AppColors)
    canvas.drawCircle(
      center,
      capR,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = AppColors.jewelCapGradient
            .createShader(Rect.fromCircle(center: center, radius: capR)),
    );

    // Rim hairline — final gold outline
    canvas.drawCircle(
      center,
      capR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = AppColors.goldDark.withAlpha(220),
    );

    // Primary specular highlight — main light-catch on the gem
    canvas.drawCircle(
      Offset(center.dx - capR * 0.32, center.dy - capR * 0.32),
      capR * 0.26,
      Paint()
        ..color = const Color(0xEEFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );

    // Secondary micro-glint — smaller sparkle for extra depth
    canvas.drawCircle(
      Offset(center.dx - capR * 0.42, center.dy - capR * 0.42),
      capR * 0.10,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Tiny rose-gold micro-reflection at the opposite edge — subtle warmth
    canvas.drawCircle(
      Offset(center.dx + capR * 0.42, center.dy + capR * 0.28),
      capR * 0.11,
      Paint()..color = AppColors.roseBlush.withAlpha(110),
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
