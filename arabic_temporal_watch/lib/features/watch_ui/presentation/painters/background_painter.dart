// background_painter.dart
//
// Paints the astronomical sky background behind the watch face.
//
// Layers (bottom to top):
//   1. Sky gradient      — radial gradient driven by TransitionState sky colors.
//   2. Star field        — 80+ fixed white dots with sin/cos seeding + twinkling.
//   3. Milky Way band    — diagonal blur band of faint white dots.
//   4. Sun glow          — orange/gold radial halo at the appropriate sky position.
//   5. Moon glow         — silver radial halo (opposite sun) with phase occlusion.
//   6. Horizon glow      — warm gradient band along bottom during twilight.
//   7. Atmospheric haze  — subtle tinted overlay driven by atmosphericScatter.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../features/temporal_engine/domain/arabic_period.dart'
    show TransitionPhase;

// ── TransitionState ───────────────────────────────────────────────────────────

/// Sky-color snapshot consumed by [BackgroundPainter].
///
/// Encodes the two radial-gradient stops and auxiliary opacity/scatter values
/// that change as the sun moves through its arc.
class TransitionState {
  const TransitionState({
    required this.skyColorTop,
    required this.skyColorBottom,
    required this.starOpacity,
    required this.atmosphericScatter,
    required this.phase,
  });

  /// Color at the zenith (center of the radial gradient).
  final Color skyColorTop;

  /// Color at the horizon edge of the radial gradient.
  final Color skyColorBottom;

  /// Opacity for the star field — 0.0 during full day, 1.0 at night.
  final double starOpacity;

  /// 0.0–1.0 atmospheric-scatter intensity used for the haze overlay tint.
  final double atmosphericScatter;

  /// Current transition phase, used to decide horizon-glow rendering.
  final TransitionPhase phase;

  // ── Named presets ──────────────────────────────────────────────────────────

  /// Default full-night preset.
  static const TransitionState night = TransitionState(
    skyColorTop: Color(0xFF02040F),
    skyColorBottom: Color(0xFF05081A),
    starOpacity: 1.0,
    atmosphericScatter: 0.0,
    phase: TransitionPhase.night,
  );

  /// Default full-day preset.
  static const TransitionState day = TransitionState(
    skyColorTop: Color(0xFF5BAAD0),
    skyColorBottom: Color(0xFF87CEEB),
    starOpacity: 0.0,
    atmosphericScatter: 0.3,
    phase: TransitionPhase.day,
  );
}

// ── BackgroundPainter ─────────────────────────────────────────────────────────

/// CustomPainter that renders the full astronomical sky background.
///
/// Designed to be composited *behind* the watch face rings so it fills a
/// perfect circle clipped to [size].
class BackgroundPainter extends CustomPainter {
  const BackgroundPainter({
    required this.transitionState,
    required this.solarAltitude,
    required this.moonPhase,
    required this.animationValue,
  });

  /// Sky gradient and opacity parameters.
  final TransitionState transitionState;

  /// Current solar altitude in degrees (positive = above horizon).
  final double solarAltitude;

  /// Moon phase as a fraction [0.0, 1.0) — 0 = new, 0.5 = full.
  final double moonPhase;

  /// 0.0–1.0 animation value for star twinkling (driven by an
  /// [AnimationController] ticking in the parent widget).
  final double animationValue;

  // ── Geometry helpers ───────────────────────────────────────────────────────

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);
  double _radius(Size size) =>
      math.min(size.width, size.height) / 2.0;

  // ── Layer 1: Sky gradient ──────────────────────────────────────────────────

  void _drawSkyGradient(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          transitionState.skyColorTop,
          transitionState.skyColorBottom,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  // ── Layer 2: Star field ────────────────────────────────────────────────────

  /// Returns a pseudo-random but deterministic list of star positions seeded
  /// from trigonometric values so no external PRNG state is needed.
  List<_Star> _buildStars(double radius) {
    const int count = 88;
    final stars = <_Star>[];
    for (int i = 0; i < count; i++) {
      // Seed from index using sin/cos to scatter across the circle.
      final angle = math.sin(i * 2.39996) * math.pi * 2.0;
      final r = math.cos(i * 1.61803) * 0.5 + 0.5; // [0, 1]
      final dist = math.sqrt(r) * radius * 0.95; // uniform area distribution
      final x = math.cos(angle) * dist;
      final y = math.sin(angle) * dist;
      // Star size: mostly tiny, a few larger
      final size = 0.6 + (math.sin(i * 7.3) * 0.5 + 0.5) * 1.4;
      // Twinkle phase offset per star so they don't all pulse together.
      final phaseOffset = (math.cos(i * 3.7) * 0.5 + 0.5);
      stars.add(_Star(dx: x, dy: y, size: size, phaseOffset: phaseOffset));
    }
    return stars;
  }

  void _drawStarField(Canvas canvas, Size size) {
    final opacity = transitionState.starOpacity;
    if (opacity <= 0.0) return;

    final center = _center(size);
    final radius = _radius(size);
    final stars = _buildStars(radius);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final star in stars) {
      // Twinkling: each star has its own phase so they don't sync.
      final twinkle = math.sin(
                (animationValue * math.pi * 2.0) + star.phaseOffset * math.pi * 2.0,
              ) *
              0.3 +
          0.7; // oscillates between 0.4 and 1.0
      final alpha = (opacity * twinkle).clamp(0.0, 1.0);

      paint.color = Color.fromRGBO(240, 240, 255, alpha);
      canvas.drawCircle(
        Offset(center.dx + star.dx, center.dy + star.dy),
        star.size,
        paint,
      );
    }
  }

  // ── Layer 3: Milky Way band ────────────────────────────────────────────────

  void _drawMilkyWay(Canvas canvas, Size size) {
    final opacity = transitionState.starOpacity * 0.35;
    if (opacity <= 0.0) return;

    final center = _center(size);
    final radius = _radius(size);
    final rng = List.generate(120, (i) => i);

    // Diagonal band: roughly −30° tilt across the circle.
    const double bandAngle = -math.pi / 6.0; // −30 degrees
    final cosA = math.cos(bandAngle);
    final sinA = math.sin(bandAngle);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    for (final i in rng) {
      // Parameterised along the band.
      final t = (i / 120.0) * 2.0 - 1.0; // [-1, 1]
      final along = t * radius * 1.1;
      // Gaussian spread across the band width.
      final spread = (math.sin(i * 2.17 + 1.3) * 0.5 + 0.5) * radius * 0.15;
      final perp = math.cos(i * 3.91) * spread;

      final bx = along * cosA - perp * sinA;
      final by = along * sinA + perp * cosA;

      // Skip points outside the circle.
      if (bx * bx + by * by > radius * radius * 0.98) continue;

      final brightness = math.sin(i * 5.29 + 0.7) * 0.5 + 0.5;
      final dotSize = 0.3 + brightness * 0.8;
      final alpha = opacity * (0.3 + brightness * 0.7);

      paint.color = Color.fromRGBO(220, 230, 255, alpha.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(center.dx + bx, center.dy + by),
        dotSize,
        paint,
      );
    }
  }

  // ── Layer 4: Sun glow ──────────────────────────────────────────────────────

  /// Maps [solarAltitude] to a vertical position inside the circle.
  /// Altitude 90° → top; 0° → centre-bottom; negative → below circle.
  Offset _sunPosition(Offset center, double radius) {
    // Convert altitude to a fraction: 90° = top, −90° = bottom.
    final fraction = (solarAltitude / 90.0).clamp(-1.0, 1.0);
    final y = center.dy - fraction * radius * 0.7;
    return Offset(center.dx, y);
  }

  void _drawSunGlow(Canvas canvas, Size size) {
    if (solarAltitude < -18.0) return; // sun well below horizon — nothing to draw

    final center = _center(size);
    final radius = _radius(size);
    final sunPos = _sunPosition(center, radius);

    // Glow intensity fades as sun descends below horizon.
    final intensity = ((solarAltitude + 18.0) / 36.0).clamp(0.0, 1.0);

    final glowRadius = radius * 0.30;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(255, 200, 50, intensity * 0.9),
          Color.fromRGBO(255, 120, 20, intensity * 0.5),
          Color.fromRGBO(255, 80, 0, 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: sunPos, radius: glowRadius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06);

    canvas.drawCircle(sunPos, glowRadius, glowPaint);

    // Sun disc
    if (solarAltitude > -1.0) {
      final discPaint = Paint()
        ..color = Color.fromRGBO(255, 220, 100, intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.015);
      canvas.drawCircle(sunPos, radius * 0.030, discPaint);
    }
  }

  // ── Layer 5: Moon glow ─────────────────────────────────────────────────────

  /// Moon is roughly opposite the sun in the sky.
  Offset _moonPosition(Offset center, double radius) {
    final fraction = (solarAltitude / 90.0).clamp(-1.0, 1.0);
    // Moon appears on the opposite side of the sky from the sun.
    final y = center.dy + fraction * radius * 0.65;
    // Slight horizontal offset for visual separation.
    return Offset(center.dx + radius * 0.15, y);
  }

  void _drawMoonGlow(Canvas canvas, Size size) {
    // Only show moon when sun is below horizon.
    if (solarAltitude > 6.0) return;

    final center = _center(size);
    final radius = _radius(size);
    final moonPos = _moonPosition(center, radius);

    // Fade in as sun descends.
    final intensity = ((-solarAltitude) / 18.0).clamp(0.0, 1.0);

    // Moon glow: silver/white halo.
    final glowRadius = radius * 0.20;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(200, 216, 240, intensity * 0.7),
          Color.fromRGBO(180, 200, 230, intensity * 0.3),
          Color.fromRGBO(150, 180, 220, 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: moonPos, radius: glowRadius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04);

    canvas.drawCircle(moonPos, glowRadius, glowPaint);

    // Moon disc with phase illumination (crescent shadow).
    _drawMoonDisc(canvas, moonPos, radius * 0.025, intensity);
  }

  void _drawMoonDisc(Canvas canvas, Offset pos, double discRadius, double intensity) {
    // Full lit disc.
    final discPaint = Paint()
      ..color = Color.fromRGBO(240, 245, 255, intensity * 0.9);
    canvas.drawCircle(pos, discRadius, discPaint);

    // Phase shadow: occlude a portion based on moonPhase.
    // 0 = new (fully dark), 0.5 = full (no shadow), 1.0 = new again.
    final illumination = moonPhase < 0.5
        ? moonPhase * 2.0 // waxing: 0 → 1
        : (1.0 - moonPhase) * 2.0; // waning: 1 → 0

    if (illumination < 0.99) {
      // Draw a shadow circle offset to create crescent effect.
      final shadowOffset = discRadius * (1.0 - illumination * 2.0);
      final shadowPaint = Paint()
        ..color = Color.fromRGBO(5, 8, 26, intensity * 0.95)
        ..blendMode = BlendMode.srcOver;

      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: pos, radius: discRadius)));
      canvas.drawCircle(
        Offset(pos.dx + shadowOffset, pos.dy),
        discRadius,
        shadowPaint,
      );
      canvas.restore();
    }
  }

  // ── Layer 6: Horizon glow ──────────────────────────────────────────────────

  void _drawHorizonGlow(Canvas canvas, Size size) {
    final phase = transitionState.phase;
    final isTwilight = phase == TransitionPhase.sunriseTransition ||
        phase == TransitionPhase.sunsetTransition;
    if (!isTwilight) return;

    final center = _center(size);
    final radius = _radius(size);

    // Sunrise: gold/orange; Sunset: deeper red/orange.
    final isSunrise = phase == TransitionPhase.sunriseTransition;
    final Color warmColor = isSunrise
        ? const Color(0xFFFF9A3C)
        : const Color(0xFFE64A19);

    // Glow band along the bottom of the circle.
    final rect = Rect.fromLTWH(
      center.dx - radius,
      center.dy + radius * 0.3,
      radius * 2.0,
      radius * 0.7,
    );

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          warmColor.withAlpha(0),
          warmColor.withAlpha(120),
          warmColor.withAlpha(180),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06);

    // Clip to the circle before drawing.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawRect(rect, glowPaint);
    canvas.restore();
  }

  // ── Layer 7: Atmospheric haze ──────────────────────────────────────────────

  void _drawAtmosphericHaze(Canvas canvas, Size size) {
    final scatter = transitionState.atmosphericScatter;
    if (scatter <= 0.0) return;

    final center = _center(size);
    final radius = _radius(size);

    // During daytime, a warm blueish tint fills the sky.
    final hazeColor = Color.fromRGBO(100, 160, 210, scatter * 0.12);
    final hazePaint = Paint()
      ..shader = RadialGradient(
        colors: [hazeColor, hazeColor.withAlpha(0)],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, hazePaint);
  }

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final center = _center(size);
    final radius = _radius(size);

    // Clip all drawing to the watch circle.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    _drawSkyGradient(canvas, size);
    _drawStarField(canvas, size);
    _drawMilkyWay(canvas, size);
    _drawSunGlow(canvas, size);
    _drawMoonGlow(canvas, size);
    _drawHorizonGlow(canvas, size);
    _drawAtmosphericHaze(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      oldDelegate.transitionState != oldDelegate.transitionState ||
      oldDelegate.transitionState.skyColorTop !=
          transitionState.skyColorTop ||
      oldDelegate.transitionState.skyColorBottom !=
          transitionState.skyColorBottom ||
      oldDelegate.transitionState.starOpacity !=
          transitionState.starOpacity ||
      oldDelegate.transitionState.phase != transitionState.phase ||
      oldDelegate.solarAltitude != solarAltitude ||
      oldDelegate.moonPhase != moonPhase ||
      oldDelegate.animationValue != animationValue;
}

// ── Private helpers ────────────────────────────────────────────────────────────

/// Lightweight data class for a single star's relative position and metadata.
class _Star {
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phaseOffset,
  });

  /// Offset from the circle center in logical pixels.
  final double dx;
  final double dy;

  /// Dot radius in logical pixels.
  final double size;

  /// Per-star twinkle phase offset in [0, 1].
  final double phaseOffset;
}
