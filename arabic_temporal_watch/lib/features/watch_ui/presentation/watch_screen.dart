// watch_screen.dart
//
// Main watch-face screen — the centrepiece of the Arabic Temporal Watch app.
//
// Architecture
// ────────────
//   • ConsumerStatefulWidget with TickerProviderStateMixin.
//   • Four AnimationControllers drive distinct animation layers:
//       _ringController  — continuous ring rotation (lerps toward target angle).
//       _glowController  — sinusoidal glow pulse [0 → 1 → 0], ~3-second cycle.
//       _skyController   — cross-fade for day/night sky transitions [0 → 1].
//       _tickController  — 60 fps heartbeat driving the analog hand sweep.
//   • All heavy state is read from Riverpod providers so the widget itself
//     contains no business logic.
//
// Layer order (bottom → top inside the watch face Stack):
//   1. BackgroundPainter    — astronomical sky gradient + stars.
//   2. ClockFacePainter     — luxury Swiss-Islamic dial.
//   3. RingPainter          — 24-segment rotating Arabic temporal ring.
//   4. TemporalProgressPainter — period progress arc + Arabic period label.
//   5. PrayerArcPainter     — 6-segment prayer-time arc around the bezel.
//   6. HandsPainter         — hour, minute, and second hands.
//   7. Center cap overlay   — decorative gold boss rendered by ClockFacePainter
//                             but kept topmost for z-order correctness.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../astronomical_engine/presentation/astronomical_provider.dart'
    hide locationProvider;
import '../../location/presentation/location_provider.dart'
    show locationProvider;
import '../../prayer_engine/domain/prayer.dart';
import '../../prayer_engine/presentation/prayer_provider.dart';
import '../../rotating_ring/data/ring_calculator.dart';
import '../../rotating_ring/presentation/painters/ring_painter.dart'
    show RingPainter, PrayerMarker;
import '../../adhan/presentation/adhan_provider.dart';
import '../../settings/domain/settings_model.dart' show AppSettings;
import '../../settings/presentation/settings_provider.dart';
import '../../temporal_engine/domain/arabic_period.dart';
import '../../../core/utils/shake_detector.dart';
import '../../temporal_engine/presentation/temporal_provider.dart';
import 'painters/background_painter.dart';
import 'painters/clock_face_painter.dart'
    show ClockFacePainter, NumeralStyle;
import 'painters/hands_painter.dart';
import 'painters/prayer_arc_painter.dart';
import 'painters/temporal_progress_painter.dart';
import 'widgets/prayer_info_widget.dart';
import 'widgets/watch_container.dart';

// ── WatchScreen ───────────────────────────────────────────────────────────────

/// The primary watch-face screen.
///
/// Full-screen, black/dark background with three regions:
///   • Top   : Minimal status bar (location + mode indicator).
///   • Centre: The watch face — 90% of screen width, layered CustomPaints.
///   • Bottom: Prayer info bar — current / next prayer + countdown.
class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen>
    with TickerProviderStateMixin {
  // ── Shake detector ────────────────────────────────────────────────────────

  final _shakeDetector = ShakeDetector();

  // ── Animation controllers ─────────────────────────────────────────────────

  /// Continuous ring rotation animation — driven toward [_targetRingRotation]
  /// each frame using a simple exponential approach.
  late AnimationController _ringController;

  /// Glow pulse animation — oscillates 0 → 1 → 0 on a ~3-second cycle.
  late AnimationController _glowController;

  /// Sky transition animation — cross-fades the background on day/night change.
  late AnimationController _skyController;

  /// 60 fps heartbeat that triggers a `setState` so the clock hands update
  /// every frame without needing a 1-second timer.
  late AnimationController _tickController;

  // ── Ring rotation state ───────────────────────────────────────────────────

  /// The current rendered ring rotation in radians.
  double _currentRingRotation = 0.0;

  /// The target ring rotation we are easing toward (from the provider).
  double _targetRingRotation = 0.0;

  // ── Transition phase ──────────────────────────────────────────────────────

  TransitionPhase _previousPhase = TransitionPhase.day;

  // ── Calculator ────────────────────────────────────────────────────────────

  static const _ringCalculator = RingCalculator();

  int _lastPeriodGlobalIndex = -1;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Continuous 60 fps ticker — solely used to invalidate the widget so the
    // hands and ring lerp update on every frame.
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Ring controller: drives ring lerp in the AnimatedBuilder callback.
    // Duration is notional — we use addListener with a frame callback.
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Glow pulse: 0 → 1 → 0 over ~3 seconds, repeating.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Sky transition: fires once per sunrise/sunset crossing.
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // When the tick fires, update the ring lerp.
    _tickController.addListener(_onTick);

    // Apply keep-screen-on setting after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      if (settings.keepScreenOn) WakelockPlus.enable();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _shakeDetector.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _tickController.removeListener(_onTick);
    _tickController.dispose();
    _ringController.dispose();
    _glowController.dispose();
    _skyController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ── Tick handler ──────────────────────────────────────────────────────────

  void _onTick() {
    final temporalAsync = ref.read(temporalDataProvider);
    final temporal = temporalAsync.valueOrNull;
    if (temporal == null) return;

    // Haptic feedback when the Arabic temporal period changes.
    final newIdx = temporal.currentPeriod.period.globalIndex;
    if (_lastPeriodGlobalIndex != -1 && newIdx != _lastPeriodGlobalIndex) {
      final settings = ref.read(settingsProvider);
      if (settings.enableVibration) HapticFeedback.mediumImpact();
    }
    _lastPeriodGlobalIndex = newIdx;

    final globalIdx = temporal.currentPeriod.period.globalIndex;

    // rawTarget ∈ [−2π, 0] — resets to ≈ 0 at every day/night boundary.
    // Make it CONTINUOUS by pulling it down by multiples of 2π until it is
    // at or below _currentRingRotation. This eliminates the boundary jump
    // where rawTarget would otherwise flip from ≈ −2π back to ≈ 0, causing
    // either a CW reversal or a huge CCW snap.
    double rawTarget =
        -(globalIdx + temporal.progressFraction) * kSegmentAngle;
    const twoPi = 2.0 * math.pi;
    while (rawTarget > _currentRingRotation + 1e-9) {
      rawTarget -= twoPi;
    }

    _targetRingRotation = rawTarget;

    // Exponential approach — ring only ever moves CCW (delta is always ≤ 0).
    const lerpFactor = 0.04;
    final delta = _targetRingRotation - _currentRingRotation;

    if (mounted && delta < -1e-5) {
      setState(() {
        _currentRingRotation += delta * lerpFactor;
      });
    }
  }

  // ── Sky transition listener ───────────────────────────────────────────────

  void _checkSkyTransition(TransitionPhase currentPhase) {
    if (currentPhase != _previousPhase) {
      _previousPhase = currentPhase;
      // Play the transition animation forward; the AnimatedBuilder will drive
      // the BackgroundPainter's animationValue accordingly.
      _skyController.forward(from: 0.0);
    }
  }

  // ── Prayer marker helpers ──────────────────────────────────────────────────

  /// Builds [PrayerMarker] entries for all 6 prayers using the current
  /// temporal grid (day + night period slots) to map prayer wall-clock times
  /// to ring natural angles.
  List<PrayerMarker> _computePrayerMarkers(
      PrayerTimes prayerTimes, TemporalData temporal) {
    final markers = <PrayerMarker>[];
    final allPeriods = [
      ...temporal.allDayPeriods,
      ...temporal.allNightPeriods,
    ];

    for (final prayer in prayerTimes.all) {
      final angle = _prayerRingAngle(prayer.time, allPeriods);
      if (angle == null) continue;

      // AM: Fajr / Sunrise / Dhuhr    PM: Asr / Maghrib / Isha
      final isAm = prayer.name == PrayerName.fajr ||
          prayer.name == PrayerName.sunrise ||
          prayer.name == PrayerName.dhuhr;

      markers.add(PrayerMarker(
        ringAngle: angle,
        color: prayer.color,
        arabicName: prayer.arabicName,
        isAm: isAm,
      ));
    }
    return markers;
  }

  /// Returns the ring angle (radians) for [prayerTime] pinned to the START
  /// of whichever temporal-hour slot contains the prayer.
  ///
  /// Pinning to startAngle keeps the marker fixed on the ring's period divider
  /// so it doesn't drift as the ring rotates — e.g. the Fajr marker stays
  /// exactly aligned with the first day-period entry tick.
  /// Returns null when the prayer time falls outside all known slots.
  double? _prayerRingAngle(
      DateTime prayerTime, List<ArabicPeriodSlot> allPeriods) {
    for (final slot in allPeriods) {
      if (!prayerTime.isBefore(slot.startTime) &&
          prayerTime.isBefore(slot.endTime)) {
        return slot.startAngle;
      }
    }
    return null;
  }

  // ── Angle helpers ─────────────────────────────────────────────────────────

  static double _hourAngle(DateTime now) =>
      ((now.hour % 12) + now.minute / 60.0 + now.second / 3600.0) *
      math.pi /
      6.0;

  static double _minuteAngle(DateTime now) =>
      (now.minute + now.second / 60.0) * math.pi / 30.0;

  static double _secondAngle(DateTime now) =>
      now.second * math.pi / 30.0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final temporalAsync = ref.watch(temporalDataProvider);
    final prayerAsync = ref.watch(prayerTimesProvider);
    final transitionPhase = ref.watch(transitionStateProvider);
    final solarAltitude =
        ref.watch(currentSolarAltitudeProvider).valueOrNull ?? 0.0;
    final moonData = ref.watch(moonDataProvider);

    // React to phase changes to trigger sky animation.
    _checkSkyTransition(transitionPhase);

    // Start/stop shake detector based on whether adhan is playing.
    ref.listen<bool>(adhanNotifierProvider, (prev, isPlaying) {
      if (isPlaying) {
        _shakeDetector.start(() {
          ref.read(adhanNotifierProvider.notifier).silenceAdhan();
          if (settings.enableVibration) HapticFeedback.heavyImpact();
        });
      } else {
        _shakeDetector.stop();
      }
    });

    ref.listen<AppSettings>(settingsProvider, (_, settings) {
      if (settings.keepScreenOn) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          // Watch face fills all available space
          Center(
            child: _buildWatchFace(
              context: context,
              settings: settings,
              temporalAsync: temporalAsync,
              prayerAsync: prayerAsync,
              transitionPhase: transitionPhase,
              solarAltitude: solarAltitude,
              moonPhase: moonData?.illumination ?? 0.5,
            ),
          ),
          // Status bar floats at top
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
              child: SafeArea(bottom: false, child: _StatusBar(settings: settings)),
            ),
          ),
          // Prayer info floats at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
              child: SafeArea(top: false, child: const PrayerInfoWidget()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Watch face builder ─────────────────────────────────────────────────────

  Widget _buildWatchFace({
    required BuildContext context,
    required settings,
    required AsyncValue<TemporalData> temporalAsync,
    required AsyncValue<PrayerTimes> prayerAsync,
    required TransitionPhase transitionPhase,
    required double solarAltitude,
    required double moonPhase,
  }) {
    return WatchContainer(
      sizeFraction: 0.97,
      builder: (context, watchDiameter) {
        final size = Size(watchDiameter, watchDiameter);

        return AnimatedBuilder(
          animation: Listenable.merge([
            _tickController,
            _glowController,
            _skyController,
          ]),
          builder: (context, _) {
            final now = DateTime.now();
            final glowIntensity =
                _glowController.value * 0.45 + 0.55; // [0.55, 1.0]
            final animValue = _tickController.value;

            // ── Sky transition state ─────────────────────────────────────
            final skyState = _buildTransitionState(
              transitionPhase: transitionPhase,
              solarAltitude: solarAltitude,
              skyAnimValue: _skyController.value,
            );

            return Stack(
              children: [
                // ── Layer 1: Astronomical background ─────────────────────
                CustomPaint(
                  size: size,
                  painter: BackgroundPainter(
                    transitionState: skyState,
                    solarAltitude: solarAltitude,
                    moonPhase: moonPhase,
                    animationValue: animValue,
                  ),
                ),

                // ── Layer 2: Clock face dial ──────────────────────────────
                CustomPaint(
                  size: size,
                  painter: ClockFacePainter(
                    showNumerals: settings.watchMode.toString().split('.').last != 'minimal',
                    mode: _mapWatchMode(settings.watchMode),
                  ),
                ),

                // ── Layer 3: Rotating Arabic ring ─────────────────────────
                temporalAsync.when(
                  data: (temporal) {
                    final ringState = _ringCalculator.buildRingState(
                      temporalData: temporal,
                      currentRotation: _currentRingRotation,
                      animationTime: now.millisecondsSinceEpoch / 1000.0,
                    );

                    final markers = prayerAsync.valueOrNull != null
                        ? _computePrayerMarkers(
                            prayerAsync.valueOrNull!, temporal)
                        : const <PrayerMarker>[];

                    return Transform.rotate(
                      angle: _currentRingRotation,
                      child: CustomPaint(
                        size: size,
                        painter: RingPainter(
                          ringState: ringState,
                          progressFraction: temporal.progressFraction,
                          glowIntensity: glowIntensity,
                          prayerMarkers: markers,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Layer 4: Temporal period progress arc ─────────────────
                temporalAsync.when(
                  data: (temporal) => GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed(
                      '/period-detail',
                      arguments: temporal.currentPeriod,
                    ),
                    child: CustomPaint(
                      size: size,
                      painter: TemporalProgressPainter(
                        temporalData: temporal,
                        animationValue: animValue,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Layer 5: Prayer arc ────────────────────────────────────
                if (settings.showPrayerArc)
                  prayerAsync.when(
                    data: (times) => CustomPaint(
                      size: size,
                      painter: PrayerArcPainter(
                        prayerTimes: times,
                        now: now,
                        sunrise: times.sunrise.time,
                        sunset: times.maghrib.time,
                        animationValue: animValue,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                // ── Layer 6: Analog hands ─────────────────────────────────
                CustomPaint(
                  size: size,
                  painter: HandsPainter(
                    hourAngle: _hourAngle(now),
                    minuteAngle: _minuteAngle(now),
                    secondAngle: _secondAngle(now),
                    showSeconds: settings.showSeconds,
                  ),
                ),

                // ── Layer 7: Reader line — fixed at 12 o'clock (current-moment pointer) ─
                // Fixed (no rotation) so it stays aligned with the ring's reference
                // position. The ring rotates to keep the current Arabic period under
                // this pointer; rotating the pointer with the clock hour would cause drift.
                CustomPaint(
                  size: size,
                  painter: const _ReaderLinePainter(),
                ),

                // ── Layer 8: 12 o'clock reader indicator — tapered gold baton ──
                Positioned(
                  top: watchDiameter * 0.010,
                  left: watchDiameter / 2 - 1.5,
                  child: Container(
                    width: 3.0,
                    height: watchDiameter * 0.042,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.goldPale,
                          AppColors.goldPrimary,
                          AppColors.goldPrimary.withAlpha(80),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(1.5),
                        topRight: Radius.circular(1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.goldPrimary.withOpacity(0.85),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: AppColors.goldLight.withOpacity(0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Builds a [TransitionState] for the [BackgroundPainter] by interpolating
  /// between the day and night sky presets based on the current [solarAltitude]
  /// and [skyAnimValue].
  TransitionState _buildTransitionState({
    required TransitionPhase transitionPhase,
    required double solarAltitude,
    required double skyAnimValue,
  }) {
    // Determine which preset we're transitioning toward.
    final isDay = transitionPhase == TransitionPhase.day ||
        transitionPhase == TransitionPhase.sunriseTransition;

    final double blend;
    if (transitionPhase == TransitionPhase.sunriseTransition) {
      // Sunrise: night → day.
      blend = skyAnimValue;
    } else if (transitionPhase == TransitionPhase.sunsetTransition) {
      // Sunset: day → night.
      blend = 1.0 - skyAnimValue;
    } else {
      blend = isDay ? 1.0 : 0.0;
    }

    // Linearly interpolate between night and day presets.
    final top = Color.lerp(
      TransitionState.night.skyColorTop,
      TransitionState.day.skyColorTop,
      blend,
    )!;
    final bottom = Color.lerp(
      TransitionState.night.skyColorBottom,
      TransitionState.day.skyColorBottom,
      blend,
    )!;
    final starOpacity = (1.0 - blend).clamp(0.0, 1.0);
    final scatter = blend * 0.3;

    return TransitionState(
      skyColorTop: top,
      skyColorBottom: bottom,
      starOpacity: starOpacity,
      atmosphericScatter: scatter,
      phase: transitionPhase,
    );
  }

  /// Maps the app-level [WatchMode] enum from settings to the painter-level
  /// [WatchMode] used by [ClockFacePainter].
  NumeralStyle _mapWatchMode(
    covariant dynamic mode,
  ) {
    // Import aliases:
    //   settings WatchMode  — from settings_model.dart
    //   painter  WatchMode  — from clock_face_painter.dart
    // Both are in scope; the painter's WatchMode is what ClockFacePainter uses.
    //
    // We resolve by name to avoid circular dependency.
    switch (mode.toString().split('.').last) {
      case 'minimal':
        return NumeralStyle.minimal;
      case 'fullArabic':
        return NumeralStyle.arabicIndic;
      case 'astronomical':
        return NumeralStyle.arabicIndic;
      case 'hybrid':
      default:
        return NumeralStyle.arabicIndic;
    }
  }
}

// ── _ReaderLinePainter ─────────────────────────────────────────────────────────

/// A thin gold radial line from the center pointing toward the current hour
/// angle. The ring rotates so the current Arabic period is always aligned with
/// this reader line. The painter is rotated by [_hourAngle] in the parent.
class _ReaderLinePainter extends CustomPainter {
  const _ReaderLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Thin gold line from center to outer ring area (76% of radius).
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          AppColors.goldPrimary.withAlpha(80),
          AppColors.goldPrimary.withAlpha(200),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw from center up to 76% of radius (inner edge of ring).
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.76),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReaderLinePainter old) => false;
}

// ── _StatusBar ─────────────────────────────────────────────────────────────────

/// Ultra-minimal top status bar: city name only + settings icon.
/// No clutter — just location context and access to settings.
class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.settings});

  final dynamic settings; // AppSettings

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    final cityName = location.city ?? location.country ?? 'GPS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // City name — elegant, understated
          Text(
            cityName,
            style: const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 11,
              color: AppColors.silverDim,
              letterSpacing: 1.5,
            ),
          ),

          // Settings — minimal icon only, no border box
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/settings'),
            child: const Icon(
              Icons.tune_outlined,
              color: AppColors.silverDim,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
