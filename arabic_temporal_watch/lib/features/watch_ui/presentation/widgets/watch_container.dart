// watch_container.dart
//
// Container widget that sizes the watch face correctly, wraps it in a
// RepaintBoundary, and provides the computed diameter to its builder via an
// InheritedWidget.
//
// Design decisions
// ────────────────
//   • The watch face is always square; its side length is
//     min(availableWidth, availableHeight) × _watchSizeFraction (≈ 0.90).
//   • A [RepaintBoundary] is placed around the entire watch face so that
//     tick-driven repaints of the inner layers are isolated from the rest of
//     the widget tree (status bar, prayer bar, etc.).
//   • [WatchDiameterScope] is an [InheritedWidget] that propagates the
//     computed diameter downward so any nested widget can read it without
//     being explicitly handed the value.
//   • The outer bezel ring is drawn here rather than inside a painter so it
//     can easily respond to theme changes and be touched/tapped for a
//     long-press-to-info gesture.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

// ── WatchDiameterScope ─────────────────────────────────────────────────────────

/// [InheritedWidget] that propagates the computed watch-face diameter (logical
/// pixels) to all descendants.
///
/// Usage:
/// ```dart
/// final diameter = WatchDiameterScope.of(context);
/// ```
class WatchDiameterScope extends InheritedWidget {
  const WatchDiameterScope({
    super.key,
    required this.diameter,
    required super.child,
  });

  /// The watch face diameter in logical pixels.
  final double diameter;

  /// Returns the [WatchDiameterScope] ancestor's [diameter], or 0.0 if none
  /// exists (graceful degradation).
  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<WatchDiameterScope>()
            ?.diameter ??
        0.0;
  }

  @override
  bool updateShouldNotify(WatchDiameterScope oldWidget) =>
      oldWidget.diameter != diameter;
}

// ── WatchContainer ─────────────────────────────────────────────────────────────

/// Container that sizes the watch face, provides a bezel decoration, and
/// exposes the final [watchDiameter] to the [builder] callback.
///
/// Example:
/// ```dart
/// WatchContainer(
///   builder: (context, diameter) {
///     return Stack(children: [ /* painters */ ]);
///   },
/// )
/// ```
class WatchContainer extends StatelessWidget {
  const WatchContainer({
    super.key,
    required this.builder,
    this.sizeFraction = _defaultSizeFraction,
  });

  /// Callback that receives the computed [watchDiameter] and returns the watch
  /// face widget tree.
  final Widget Function(BuildContext context, double watchDiameter) builder;

  /// The watch face diameter as a fraction of the shorter screen dimension.
  /// Defaults to 0.90 (90 % of screen width on portrait phones).
  final double sizeFraction;

  /// Default size fraction — 90 % of the shorter screen axis.
  static const double _defaultSizeFraction = 0.90;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The watch face is always a square; its side is the shorter of the
        // available width and height, scaled by [sizeFraction].
        final available = constraints.biggest;
        final side = available.shortestSide.isFinite
            ? available.shortestSide * sizeFraction
            : available.width * sizeFraction;

        return WatchDiameterScope(
          diameter: side,
          child: _BezelContainer(
            diameter: side,
            child: RepaintBoundary(
              child: SizedBox(
                width: side,
                height: side,
                child: builder(context, side),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── _BezelContainer ────────────────────────────────────────────────────────────

/// Outer decorative bezel drawn around the watch face.
///
/// Layers:
///   1. Outermost dark shadow halo — deep navy blur, gives depth.
///   2. Bezel body — radial gradient from dark navy to navy-blue.
///   3. Inner gold hairline ring.
///   4. Watch face child clipped to a circle.
///   5. Subtle inner-shadow ring to create a recessed look.
class _BezelContainer extends StatelessWidget {
  const _BezelContainer({
    super.key,
    required this.diameter,
    required this.child,
  });

  final double diameter;
  final Widget child;

  // How many logical pixels wide the bezel band is.
  static const double _bezelWidth = 7.0;

  @override
  Widget build(BuildContext context) {
    final outerDiameter = diameter + _bezelWidth * 2.0;
    final radius = outerDiameter / 2.0;

    return SizedBox(
      width: outerDiameter,
      height: outerDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Outer shadow halo + concentric ring bezel effect ─────────
          Container(
            width: outerDiameter,
            height: outerDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Concentric ring bezel shadows (outermost to innermost).
                BoxShadow(
                  color: AppColors.goldPrimary.withAlpha(33),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.backgroundDeep.withAlpha(158),
                  blurRadius: 0,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: AppColors.goldPrimary.withAlpha(46),
                  blurRadius: 0,
                  spreadRadius: 9,
                ),
                BoxShadow(
                  color: AppColors.backgroundDeep.withAlpha(224),
                  blurRadius: 0,
                  spreadRadius: 16,
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(184),
                  blurRadius: 80,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // ── Bezel body — brushed metal sweep ──────────────────────────
          // A SweepGradient (rather than a radial one) makes the bezel read as
          // a turned metal ring catching light at four points around its
          // circumference, the way a real case-band does.
          Container(
            width: outerDiameter,
            height: outerDiameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: -1.5707963267948966, // 12 o'clock
                endAngle: 4.71238898038469,      // 12 o'clock + 2π
                colors: [
                  Color(0xFF1A2452),
                  Color(0xFF0B1030),
                  Color(0xFF161E46),
                  Color(0xFF080C24),
                  Color(0xFF1A2452),
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // ── Top-light overlay — softens the sweep into a lit dome ─────
          Container(
            width: outerDiameter,
            height: outerDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.5),
                radius: 0.95,
                colors: [
                  Colors.white.withAlpha(20),
                  AppColors.transparent,
                  AppColors.backgroundDeep.withAlpha(90),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Outer gold hairline ───────────────────────────────────────
          Container(
            width: outerDiameter - 1.0,
            height: outerDiameter - 1.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldChampagne.withAlpha(200),
                width: 1.0,
              ),
            ),
          ),

          // ── Mid burnished hairline ────────────────────────────────────
          Container(
            width: outerDiameter - _bezelWidth * 0.8,
            height: outerDiameter - _bezelWidth * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldDark.withAlpha(150),
                width: 0.7,
              ),
            ),
          ),

          // ── Inner gold hairline ───────────────────────────────────────
          Container(
            width: outerDiameter - _bezelWidth * 1.6,
            height: outerDiameter - _bezelWidth * 1.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldPrimary.withAlpha(130),
                width: 0.6,
              ),
            ),
          ),

          // ── Watch face child (clipped to circle) ──────────────────────
          ClipOval(child: child),

          // ── Inner-shadow overlay (recessed look) ──────────────────────
          IgnorePointer(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    AppColors.transparent,
                    AppColors.backgroundDeep.withOpacity(0.18),
                  ],
                  stops: const [0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── Tick markers on the bezel (every 5°) ──────────────────────
          SizedBox(
            width: outerDiameter,
            height: outerDiameter,
            child: CustomPaint(
              painter: _BezelTickPainter(
                outerRadius: radius,
                bezelWidth: _bezelWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _BezelTickPainter ──────────────────────────────────────────────────────────

/// Paints 72 short tick marks around the outer bezel ring (every 5°).
/// Major ticks at 30° intervals (12 positions) are slightly taller.
class _BezelTickPainter extends CustomPainter {
  const _BezelTickPainter({
    required this.outerRadius,
    required this.bezelWidth,
  });

  final double outerRadius;
  final double bezelWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final majorPaint = Paint()
      ..color = AppColors.goldChampagne.withAlpha(165)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = AppColors.goldAntique.withAlpha(95)
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;

    // Cardinal ticks (12/3/6/9) get a warm halo so the case reads as jewelled
    // at the quarters — a detail borrowed from luxury dive-watch bezels.
    final cardinalGlowPaint = Paint()
      ..color = AppColors.glowChampagne
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    const int totalTicks = 72; // every 5°
    for (int i = 0; i < totalTicks; i++) {
      final isMajor = i % 6 == 0; // every 30°
      final angle = i / totalTicks * 2 * 3.141592653589793 - 1.5707963267948966;

      final tickLength = isMajor ? bezelWidth * 0.6 : bezelWidth * 0.35;
      final outerR = outerRadius - 1.5;
      final innerR = outerR - tickLength;

      final cosA = _cos(angle);
      final sinA = _sin(angle);

      final start = Offset(center.dx + cosA * outerR, center.dy + sinA * outerR);
      final end = Offset(center.dx + cosA * innerR, center.dy + sinA * innerR);

      // Quarter positions: i == 0, 18, 36, 54 → 12, 3, 6, 9 o'clock.
      if (i % 18 == 0) {
        canvas.drawLine(start, end, cardinalGlowPaint);
      }

      canvas.drawLine(start, end, isMajor ? majorPaint : minorPaint);
    }
  }

  double _cos(double a) => _cosSin(a, false);
  double _sin(double a) => _cosSin(a, true);

  double _cosSin(double a, bool isSin) {
    return isSin ? math.sin(a) : math.cos(a);
  }

  @override
  bool shouldRepaint(_BezelTickPainter old) =>
      old.outerRadius != outerRadius || old.bezelWidth != bezelWidth;
}
