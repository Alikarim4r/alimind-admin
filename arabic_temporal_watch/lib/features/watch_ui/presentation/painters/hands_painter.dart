// hands_painter.dart
//
// Paints the three luxury Swiss-Islamic analog clock hands.
//
// Design:
//   • Hour hand   — wide lancet-profile gold baton, 72 % of face radius.
//   • Minute hand — slimmer lancet gold baton, 93 % of face radius.
//   • Seconds hand — ultra-thin rose-gold sweep pointer, 88 % of face radius.
//
// Each main hand renders six passes (bottom → top):
//   0. Glow halo      — wide blurred copy; soft golden bloom for depth.
//   1. Drop shadow    — dark translucent blurred copy, offset 2 px SE.
//   2. Main shape     — 7-stop bevel gradient with a champagne crest at center.
//   3. Bevel edge     — hairline dark outline defining the silhouette.
//   4. Spine highlight — bright ridge along the hand's axis.
//   5. Tip jewel      — mother-of-pearl point at the reading tip.
//
// Hand profile: lancet / leaf shape with slightly convex bezier sides — the
// canonical form of a high-grade Swiss dress-watch hand.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

// ── HandsPainter ──────────────────────────────────────────────────────────────

class HandsPainter extends CustomPainter {
  const HandsPainter({
    required this.hourAngle,
    required this.minuteAngle,
    required this.secondAngle,
    this.showSeconds = true,
    this.handColor = AppColors.goldPrimary,
    this.opacity = 1.0,
    this.dialFraction = 0.70,
  });

  /// Hour-hand rotation angle in radians, measured clockwise from 12 o'clock.
  final double hourAngle;

  /// Minute-hand rotation angle in radians, measured clockwise from 12 o'clock.
  final double minuteAngle;

  /// Second-hand rotation angle in radians, measured clockwise from 12 o'clock.
  final double secondAngle;

  /// When false the seconds hand is not drawn (minimal / power-save mode).
  final bool showSeconds;

  /// Tint color for the hour and minute hands.
  final Color handColor;

  /// Overall opacity applied to all hands.
  final double opacity;

  /// Fraction of the canvas half-size used as the hand-calculation radius.
  /// 0.70 → hands fill the inner dial, staying inside the Arabic ring.
  final double dialFraction;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);
  double _radius(Size size) => math.min(size.width, size.height) / 2.0;

  // ── Hour hand ──────────────────────────────────────────────────────────────

  void _drawHourHand(Canvas canvas, Size size) {
    _drawTaperedHand(
      canvas, size,
      tipFraction: 0.73,
      tailFraction: 0.23,
      baseHalfFraction: 0.048,
      tipHalfFraction: 0.007,
      rawAngle: hourAngle,
      color: handColor,
      highlightColor: AppColors.goldLight,
      shadowColor: const Color(0x90000000),
    );
  }

  // ── Minute hand ────────────────────────────────────────────────────────────

  void _drawMinuteHand(Canvas canvas, Size size) {
    _drawTaperedHand(
      canvas, size,
      tipFraction: 0.93,
      tailFraction: 0.27,
      baseHalfFraction: 0.030,
      tipHalfFraction: 0.005,
      rawAngle: minuteAngle,
      color: Color.lerp(handColor, AppColors.goldLight, 0.30)!,
      highlightColor: AppColors.goldPale,
      shadowColor: const Color(0x70000000),
    );
  }

  // ── Shared tapered-hand builder ────────────────────────────────────────────

  void _drawTaperedHand(
    Canvas canvas,
    Size size, {
    required double tipFraction,
    required double tailFraction,
    required double baseHalfFraction,
    required double tipHalfFraction,
    required double rawAngle,
    required Color color,
    required Color highlightColor,
    required Color shadowColor,
  }) {
    final center = _center(size);
    final radius = _radius(size) * dialFraction;

    final tipLength = radius * tipFraction;
    final tailLength = radius * tailFraction;
    final baseHalfWidth = radius * baseHalfFraction;
    final tipHalfWidth = radius * tipHalfFraction;

    final path = _buildLancetHandPath(
      tipLength: tipLength,
      tailLength: tailLength,
      baseHalfWidth: baseHalfWidth,
      tipHalfWidth: tipHalfWidth,
    );

    _renderHand(
      canvas: canvas,
      center: center,
      radius: radius,
      path: path,
      angle: rawAngle - math.pi / 2.0,
      tipLength: tipLength,
      tailLength: tailLength,
      color: color,
      highlightColor: highlightColor,
      shadowColor: shadowColor,
      strokeWidth: baseHalfWidth * 2.0,
    );
  }

  // ── Seconds hand ───────────────────────────────────────────────────────────

  void _drawSecondsHand(Canvas canvas, Size size) {
    if (!showSeconds) return;

    final center = _center(size);
    final radius = _radius(size) * dialFraction;
    final angle = secondAngle - math.pi / 2.0;

    final tipLength = radius * 0.88;
    final tailLength = radius * 0.24;
    // Always at least 1 px half-width so it stays visible on small screens.
    final handHalfWidth = math.max(radius * 0.009, 1.0);

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final tipX = center.dx + cosA * tipLength;
    final tipY = center.dy + sinA * tipLength;
    final tailX = center.dx - cosA * tailLength;
    final tailY = center.dy - sinA * tailLength;

    // ── Subtle shadow ──
    _drawShadow(
      canvas: canvas,
      center: center,
      angle: angle,
      tipLength: tipLength,
      tailLength: tailLength,
      halfWidth: handHalfWidth * 1.6,
      shadowColor: const Color(0x55000000),
    );

    // ── Rose-gold bloom along the stem — warm halo, unique to the sweep hand ──
    final bloomPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 4.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.roseGold.withAlpha((opacity * 40).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, handHalfWidth * 3.0);
    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY), bloomPaint);

    // ── Main stem — rose gold with a graded shaft ──
    final stemRect = Rect.fromPoints(
      Offset(tailX, tailY),
      Offset(tipX, tipY),
    ).inflate(handHalfWidth * 2.0);
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.roseGoldDeep.withAlpha((opacity * 255).round()),
          AppColors.roseGold.withAlpha((opacity * 255).round()),
          AppColors.roseBlush.withAlpha((opacity * 255).round()),
          AppColors.roseGold.withAlpha((opacity * 255).round()),
        ],
        stops: const [0.0, 0.35, 0.6, 1.0],
      ).createShader(stemRect);

    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY), stemPaint);

    // ── Counterweight — tapered rose-gold tail, no lollipop ──
    final counterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 5.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.roseGoldDeep.withAlpha((opacity * 255).round()),
          AppColors.roseGold.withAlpha((opacity * 255).round()),
        ],
      ).createShader(stemRect);

    canvas.drawLine(
      Offset(tailX, tailY),
      Offset(
        center.dx - cosA * tailLength * 0.45,
        center.dy - sinA * tailLength * 0.45,
      ),
      counterPaint,
    );

    // ── Blush tip highlight — catches the eye as the hand sweeps ──
    canvas.drawCircle(
      Offset(tipX, tipY),
      handHalfWidth * 1.15,
      Paint()
        ..color = AppColors.roseBlush.withAlpha((opacity * 235).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );

    // ── Center jewel cap — pivot boss sitting above all three hands ──
    final capR = radius * 0.024;

    // Champagne bloom
    canvas.drawCircle(
      center,
      capR * 2.2,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.glowChampagne.withAlpha((opacity * 60).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, capR * 1.6),
    );

    // Dark setting beneath the jewel
    canvas.drawCircle(
      center,
      capR * 1.24,
      Paint()..color = const Color(0xFF120C00).withAlpha((opacity * 255).round()),
    );

    // Jewel body — shared premium gradient
    canvas.drawCircle(
      center,
      capR,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = AppColors.jewelCapGradient
            .createShader(Rect.fromCircle(center: center, radius: capR)),
    );

    // Hairline bezel ring
    canvas.drawCircle(
      center,
      capR * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = capR * 0.11
        ..color = const Color(0xFF1A1400).withAlpha((opacity * 190).round()),
    );

    // Specular glint
    canvas.drawCircle(
      Offset(center.dx - capR * 0.34, center.dy - capR * 0.34),
      capR * 0.24,
      Paint()..color = Colors.white.withAlpha((opacity * 225).round()),
    );
  }

  // ── Lancet hand path ───────────────────────────────────────────────────────

  /// Builds a lancet / leaf-profile hand shape. The hand points toward −Y
  /// (12 o'clock). Slightly convex bezier sides give the classical Swiss
  /// dress-watch profile rather than a flat trapezoid.
  Path _buildLancetHandPath({
    required double tipLength,
    required double tailLength,
    required double baseHalfWidth,
    required double tipHalfWidth,
  }) {
    final path = Path();

    // Right side: fine tip → bulge at ~38% of tip-length from pivot → pivot → tail
    path.moveTo(tipHalfWidth * 0.5, -tipLength);
    path.quadraticBezierTo(
      baseHalfWidth * 1.08, -tipLength * 0.38,
      baseHalfWidth, 0,
    );
    path.lineTo(baseHalfWidth * 0.55, tailLength);

    // Left side (mirror)
    path.lineTo(-baseHalfWidth * 0.55, tailLength);
    path.lineTo(-baseHalfWidth, 0);
    path.quadraticBezierTo(
      -baseHalfWidth * 1.08, -tipLength * 0.38,
      -tipHalfWidth * 0.5, -tipLength,
    );

    path.close();
    return path;
  }

  // ── Render helper ──────────────────────────────────────────────────────────

  void _renderHand({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Path path,
    required double angle,
    required double tipLength,
    required double tailLength,
    required Color color,
    required Color highlightColor,
    required Color shadowColor,
    required double strokeWidth,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // ── 0. Soft golden glow beneath the hand ──
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha((opacity * 45).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11.0);
    canvas.drawPath(path, glowPaint);

    // ── 1. Drop shadow ──
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = shadowColor.withAlpha((opacity * shadowColor.alpha).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.save();
    canvas.translate(2.0, 2.5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // ── 2. Main hand — 7-stop metallic bevel with champagne crest ──
    // The narrow champagne band at 0.46–0.54 reads as a polished ridge running
    // down the center of the hand, the hallmark of a faceted dress-watch hand.
    final gradientPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppColors.goldDark.withAlpha((opacity * 225).round()),
          color.withAlpha((opacity * 245).round()),
          highlightColor.withAlpha((opacity * 255).round()),
          AppColors.goldChampagne.withAlpha((opacity * 255).round()),
          highlightColor.withAlpha((opacity * 255).round()),
          color.withAlpha((opacity * 245).round()),
          AppColors.goldDark.withAlpha((opacity * 205).round()),
        ],
        stops: const [0.0, 0.18, 0.38, 0.50, 0.62, 0.82, 1.0],
      ).createShader(
        Rect.fromLTWH(
          -strokeWidth / 2,
          -tipLength,
          strokeWidth,
          tipLength + tailLength,
        ),
      );

    canvas.drawPath(path, gradientPaint);

    // ── 3. Bevel edge — hairline dark outline defines the silhouette ──
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.goldDark.withAlpha((opacity * 170).round());
    canvas.drawPath(path, edgePaint);

    // ── 4. Spine highlight — bright ridge along the hand's axis ──
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.13
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldChampagne.withAlpha((opacity * 200).round());

    canvas.drawLine(
      Offset(0, -tipLength * 0.94),
      Offset(0, 0),
      highlightPaint,
    );

    // ── 5. Tip jewel — tiny bright point where the hand reads the dial ──
    canvas.drawCircle(
      Offset(0, -tipLength * 0.965),
      strokeWidth * 0.11,
      Paint()
        ..color = AppColors.motherOfPearl.withAlpha((opacity * 210).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7),
    );

    canvas.restore();
  }

  void _drawShadow({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required double tipLength,
    required double tailLength,
    required double halfWidth,
    required Color shadowColor,
  }) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = halfWidth * 2.2
      ..strokeCap = StrokeCap.round
      ..color = shadowColor.withAlpha((opacity * shadowColor.alpha).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawLine(
      Offset(center.dx - cosA * tailLength + 2, center.dy - sinA * tailLength + 2.5),
      Offset(center.dx + cosA * tipLength + 2, center.dy + sinA * tipLength + 2.5),
      paint,
    );
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawHourHand(canvas, size);
    _drawMinuteHand(canvas, size);
    _drawSecondsHand(canvas, size);
  }

  @override
  bool shouldRepaint(HandsPainter oldDelegate) =>
      oldDelegate.hourAngle != hourAngle ||
      oldDelegate.minuteAngle != minuteAngle ||
      oldDelegate.secondAngle != secondAngle ||
      oldDelegate.showSeconds != showSeconds ||
      oldDelegate.handColor != handColor ||
      oldDelegate.opacity != opacity ||
      oldDelegate.dialFraction != dialFraction;
}
