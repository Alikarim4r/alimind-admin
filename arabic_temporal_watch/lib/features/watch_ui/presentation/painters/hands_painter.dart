// hands_painter.dart
//
// Paints the three luxury Swiss-style analog clock hands.
//
// Design:
//   • Hour hand   — thick tapered gold shape, 55 % of radius, counterweight tail.
//   • Minute hand — thinner tapered gold shape, 80 % of radius, elegant profile.
//   • Seconds hand — thin red/orange sweep pointer, 90 % of radius, lollipop tail.
//
// Each hand is rendered in three passes:
//   1. Drop shadow  — dark translucent blurred copy, offset 2 px SE.
//   2. Main shape   — LinearGradient for a 3-D bevel appearance.
//   3. Center highlight — bright line down the spine.
//
// Angles:
//   Hour   : (hours % 12 + minutes / 60) * π / 6
//   Minute : (minutes + seconds / 60) * π / 30
//   Second : seconds * π / 30

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

// ── HandsPainter ──────────────────────────────────────────────────────────────

/// [CustomPainter] that draws the three clock hands on top of the dial face.
///
/// The painter is intentionally decoupled from time sources — callers must
/// pre-compute the three angles using the formulas documented in the file
/// header and pass them in.
class HandsPainter extends CustomPainter {
  const HandsPainter({
    required this.hourAngle,
    required this.minuteAngle,
    required this.secondAngle,
    this.showSeconds = true,
    this.handColor = AppColors.goldPrimary,
    this.opacity = 1.0,
  });

  /// Hour-hand rotation angle in radians, measured clockwise from 12 o'clock.
  ///
  /// Correct formula: `(hours % 12 + minutes / 60) * math.pi / 6`
  final double hourAngle;

  /// Minute-hand rotation angle in radians, measured clockwise from 12 o'clock.
  ///
  /// Correct formula: `(minutes + seconds / 60) * math.pi / 30`
  final double minuteAngle;

  /// Second-hand rotation angle in radians, measured clockwise from 12 o'clock.
  ///
  /// Correct formula: `seconds * math.pi / 30`
  final double secondAngle;

  /// When false the seconds hand is not drawn (minimal / power-save mode).
  final bool showSeconds;

  /// Tint color for the hour and minute hands.  Defaults to luxury gold.
  final Color handColor;

  /// Overall opacity applied to all hands.  Used for fade-in/out transitions.
  final double opacity;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  double _radius(Size size) => math.min(size.width, size.height) / 2.0;

  // ── Hour hand ──────────────────────────────────────────────────────────────

  void _drawHourHand(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Elegant taper — slightly shorter, well-proportioned.
    final tipLength = radius * 0.52;
    final tailLength = radius * 0.12;
    final baseHalfWidth = radius * 0.032; // narrower than before
    final tipHalfWidth = radius * 0.005;

    final path = _buildTaperedHandPath(
      tipLength: tipLength,
      tailLength: tailLength,
      baseHalfWidth: baseHalfWidth,
      tipHalfWidth: tipHalfWidth,
    );

    final angle = hourAngle - math.pi / 2.0;

    _renderHand(
      canvas: canvas,
      center: center,
      radius: radius,
      path: path,
      angle: angle,
      tipLength: tipLength,
      color: handColor,
      highlightColor: AppColors.goldLight,
      shadowColor: const Color(0x80000000),
      strokeWidth: baseHalfWidth * 2.0,
    );
  }

  // ── Minute hand ────────────────────────────────────────────────────────────

  void _drawMinuteHand(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Thinner, slightly longer — reaches close to hour markers.
    final tipLength = radius * 0.78;
    final tailLength = radius * 0.15;
    final baseHalfWidth = radius * 0.020; // thinner than hour hand
    final tipHalfWidth = radius * 0.004;

    final path = _buildTaperedHandPath(
      tipLength: tipLength,
      tailLength: tailLength,
      baseHalfWidth: baseHalfWidth,
      tipHalfWidth: tipHalfWidth,
    );

    final angle = minuteAngle - math.pi / 2.0;

    // Slightly lighter gold for the minute hand.
    final minuteColor = Color.lerp(handColor, AppColors.goldLight, 0.25)!;

    _renderHand(
      canvas: canvas,
      center: center,
      radius: radius,
      path: path,
      angle: angle,
      tipLength: tipLength,
      color: minuteColor,
      highlightColor: AppColors.goldPale,
      shadowColor: const Color(0x60000000),
      strokeWidth: baseHalfWidth * 2.0,
    );
  }

  // ── Seconds hand ───────────────────────────────────────────────────────────

  void _drawSecondsHand(Canvas canvas, Size size) {
    if (!showSeconds) return;

    final center = _center(size);
    final radius = _radius(size);

    final angle = secondAngle - math.pi / 2.0;

    // Ultra-thin rose/red accent line — precision instrument style.
    final tipLength = radius * 0.85;
    final tailLength = radius * 0.20;
    final handHalfWidth = radius * 0.004; // very thin

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final tipX = center.dx + cosA * tipLength;
    final tipY = center.dy + sinA * tipLength;
    final tailX = center.dx - cosA * tailLength;
    final tailY = center.dy - sinA * tailLength;

    // ── Subtle drop shadow ──
    _drawShadow(
      canvas: canvas,
      center: center,
      angle: angle,
      tipLength: tipLength,
      tailLength: tailLength,
      halfWidth: handHalfWidth * 1.5,
      shadowColor: const Color(0x50000000),
    );

    // ── Main stem — rose-red, ultra-thin ──
    // Slight gradient: brighter at tip, deeper at tail.
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4364A).withAlpha((opacity * 255).round()); // rose-red

    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY), stemPaint);

    // ── Small flat counterweight (no lollipop — more refined) ──
    // Just a slightly wider section near the tail.
    final counterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = handHalfWidth * 4.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4364A).withAlpha((opacity * 255).round());

    canvas.drawLine(
      Offset(tailX, tailY),
      Offset(center.dx - cosA * tailLength * 0.5, center.dy - sinA * tailLength * 0.5),
      counterPaint,
    );

    // ── Center cap — small, gold ──
    final collarPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: const [AppColors.goldLight, AppColors.goldPrimary],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.012));
    canvas.drawCircle(center, radius * 0.012, collarPaint);
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Builds a tapered, pointed hand shape pointing toward positive-Y (6 o'clock
  /// in canvas space).  The caller rotates [canvas] before stroking.
  ///
  /// The path is centred on the origin.  Tip extends [tipLength] upward
  /// (negative Y), tail extends [tailLength] downward (positive Y).
  Path _buildTaperedHandPath({
    required double tipLength,
    required double tailLength,
    required double baseHalfWidth,
    required double tipHalfWidth,
  }) {
    // We draw in a canonical frame where the hand points toward negative-Y
    // (12 o'clock direction in standard math orientation with y-up).
    // Flutter's y-axis is flipped, but we rotate so the net effect is correct.
    final path = Path();

    // Right side: from tail → base → taper to tip.
    path.moveTo(tipHalfWidth, -tipLength);
    path.lineTo(baseHalfWidth, 0);
    path.lineTo(baseHalfWidth * 0.75, tailLength);

    // Left side: mirror.
    path.lineTo(-baseHalfWidth * 0.75, tailLength);
    path.lineTo(-baseHalfWidth, 0);
    path.lineTo(-tipHalfWidth, -tipLength);

    path.close();
    return path;
  }

  void _renderHand({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Path path,
    required double angle,
    required double tipLength,
    required Color color,
    required Color highlightColor,
    required Color shadowColor,
    required double strokeWidth,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // ── 1. Drop shadow ──
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = shadowColor.withAlpha((opacity * shadowColor.alpha).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.save();
    canvas.translate(2.0, 2.0); // SE offset
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // ── 2. Main hand with linear gradient bevel ──
    final gradientPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppColors.goldDark.withAlpha((opacity * 255).round()),
          color.withAlpha((opacity * 255).round()),
          highlightColor.withAlpha((opacity * 255).round()),
          color.withAlpha((opacity * 255).round()),
          AppColors.goldDark.withAlpha((opacity * 200).round()),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(
        Rect.fromLTWH(-strokeWidth / 2, -tipLength, strokeWidth, tipLength),
      );

    canvas.drawPath(path, gradientPaint);

    // ── 3. Center highlight line ──
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.12
      ..strokeCap = StrokeCap.round
      ..color = highlightColor.withAlpha((opacity * 160).round());

    canvas.drawLine(
      Offset(0, -tipLength * 0.95),
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawLine(
      Offset(center.dx - cosA * tailLength + 2, center.dy - sinA * tailLength + 2),
      Offset(center.dx + cosA * tipLength + 2, center.dy + sinA * tipLength + 2),
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
      oldDelegate.opacity != opacity;
}
