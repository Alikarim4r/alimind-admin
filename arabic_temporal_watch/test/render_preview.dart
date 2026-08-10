// render_preview_test.dart
//
// Development harness, not an assertion test: renders the watch-face layer
// stack to PNG files so the design can be reviewed without a device.
//
//   flutter test test/render_preview.dart
//
// Deliberately NOT named *_test.dart so `flutter test` skips it — it renders
// images rather than asserting anything, and it is slow.
//
// Output: build/preview/watch_<label>.png
//
// It renders the same painters, in the same order, with the same radii the
// real screen uses, so what it produces is what the device shows.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arabic_temporal_watch/features/rotating_ring/data/ring_calculator.dart';
import 'package:arabic_temporal_watch/features/rotating_ring/presentation/painters/ring_painter.dart';
import 'package:arabic_temporal_watch/features/temporal_engine/data/temporal_calculator.dart';
import 'package:arabic_temporal_watch/features/temporal_engine/domain/arabic_period.dart';
import 'package:arabic_temporal_watch/features/watch_ui/presentation/painters/background_painter.dart';
import 'package:arabic_temporal_watch/features/watch_ui/presentation/painters/clock_face_painter.dart';
import 'package:arabic_temporal_watch/features/watch_ui/presentation/painters/hands_painter.dart';
import 'package:arabic_temporal_watch/features/watch_ui/presentation/painters/temporal_progress_painter.dart';

const double _kSide = 900.0;

Future<void> _renderScene({
  required String label,
  required DateTime now,
}) async {
  // Makkah-like day: sunrise 06:10, sunset 18:50.
  final sunrise = DateTime(now.year, now.month, now.day, 6, 10);
  final sunset = DateTime(now.year, now.month, now.day, 18, 50);
  final nextSunrise = sunrise.add(const Duration(days: 1));

  const temporalCalc = TemporalCalculator();
  final temporal = temporalCalc.calculate(
    now: now,
    sunrise: sunrise,
    sunset: sunset,
    nextSunrise: nextSunrise,
  );

  const ringCalc = RingCalculator();
  final ringRotation =
      -(temporal.currentPeriod.period.globalIndex + temporal.progressFraction) *
          kSegmentAngle;
  final ringState = ringCalc.buildRingState(
    temporalData: temporal,
    currentRotation: ringRotation,
    animationTime: 0.0,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(_kSide, _kSide);

  // Page background behind the watch.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _kSide, _kSide),
    Paint()..color = const Color(0xFF01030C),
  );

  // ── Layer 1: sky ──────────────────────────────────────────────────────────
  BackgroundPainter(
    transitionState: temporal.isDay ? TransitionState.day : TransitionState.night,
    solarAltitude: temporal.isDay ? 40.0 : -30.0,
    moonPhase: 0.35,
    animationValue: 0.3,
  ).paint(canvas, size);

  // ── Layer 2: dial ─────────────────────────────────────────────────────────
  const ClockFacePainter().paint(canvas, size);

  // ── Layer 3: rotating ring (the screen wraps this in Transform.rotate) ────
  canvas.save();
  canvas.translate(_kSide / 2, _kSide / 2);
  canvas.rotate(ringRotation);
  canvas.translate(-_kSide / 2, -_kSide / 2);
  RingPainter(
    ringState: ringState,
    progressFraction: temporal.progressFraction,
    glowIntensity: 0.85,
  ).paint(canvas, size);
  canvas.restore();

  // ── Layer 4: progress arc + period label ─────────────────────────────────
  TemporalProgressPainter(
    temporalData: temporal,
    animationValue: 0.4,
  ).paint(canvas, size);

  // ── Layer 6: hands ────────────────────────────────────────────────────────
  final hour = now.hour % 12 + now.minute / 60.0;
  HandsPainter(
    hourAngle: hour / 12.0 * 2 * math.pi,
    minuteAngle: now.minute / 60.0 * 2 * math.pi,
    secondAngle: now.second / 60.0 * 2 * math.pi,
  ).paint(canvas, size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(_kSide.toInt(), _kSide.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  final dir = Directory('build/preview')..createSync(recursive: true);
  File('${dir.path}/watch_$label.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());

  // Release both or the next render in the same test blocks on the raster
  // thread waiting for the previous image's memory.
  image.dispose();
  picture.dispose();
}

// One scene per test: rendering twice inside a single testWidgets body blocks
// on the second toImage() call.
void main() {
  testWidgets('preview — daytime', (tester) async {
    await _renderScene(label: 'day', now: DateTime(2026, 6, 15, 10, 8, 30));
  });

  testWidgets('preview — night', (tester) async {
    await _renderScene(label: 'night', now: DateTime(2026, 6, 15, 21, 42, 12));
  });
}
