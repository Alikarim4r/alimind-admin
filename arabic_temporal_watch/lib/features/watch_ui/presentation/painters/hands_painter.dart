// hands_painter.dart
//
// Paints the three luxury Swiss-Islamic analog clock hands.
//
// Design:
//   • Hour hand   — wide lancet-profile gold baton, 72 % of face radius.
//   • Minute hand — slimmer lancet gold baton, 93 % of face radius.
//   • Seconds hand — ultra-thin rose-red sweep pointer, 88 % of face radius.
//
// Each main hand renders four passes (bottom → top):
//   0. Glow halo   — wide blurred copy; soft golden bloom for depth.
//   1. Drop shadow  — dark translucent blurred copy, offset 2 px SE.
//   2. Main shape   — 5-stop LinearGradient bevel (dark → gold → pale → gold → dark).
//   3. Spine highlight — bright hairline along the center ridge.
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

    // ── Main stem — rose-red ──
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4364A).withAlpha((opacity * 255).round());

    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY), stemPaint);

    // ── Thicker counterweight section (refined, no lollipop) ──
    final counterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 5.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4364A).withAlpha((opacity * 255).round());

    canvas.drawLine(
      Offset(tailX, tailY),
      Offset(
        center.dx - cosA * tailLength * 0.45,
        center.dy - sinA * tailLength * 0.45,
      ),
      counterPaint,
    );

    // ── Center jewel cap ──
    final capR = radius * 0.022;
    final capGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.goldPrimary.withAlpha((opacity * 50).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, capR * 1.7, capGlow);

    final capPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.5),
        colors: const [AppColors.goldPale, AppColors.goldPrimary, AppColors.goldDark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: capR));
    canvas.drawCircle(center, capR, capPaint);

    // Hairline bezel ring
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = capR * 0.12
      ..color = const Color(0xFF1A1400).withAlpha((opacity * 200).round());
    canvas.drawCircle(center, capR * 0.88, bezelPaint);
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

    // ── 2. Main hand — 5-stop metallic bevel ──
    final gradientPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppColors.goldDark.withAlpha((opacity * 220).round()),
          color.withAlpha((opacity * 255).round()),
          highlightColor.withAlpha((opacity * 255).round()),
          color.withAlpha((opacity * 255).round()),
          AppColors.goldDark.withAlpha((opacity * 200).round()),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(
        Rect.fromLTWH(
          -strokeWidth / 2,
          -tipLength,
          strokeWidth,
          tipLength + tailLength,
        ),
      );

    canvas.drawPath(path, gradientPaint);

    // ── 3. Spine highlight ──
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.14
      ..strokeCap = StrokeCap.round
      ..color = highlightColor.withAlpha((opacity * 185).round());

    canvas.drawLine(
      Offset(0, -tipLength * 0.94),
      Offset(0, 0),
      highlightPaint,
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
