// astronomical_provider.dart
//
// Riverpod providers for the astronomical engine.
//
// Provider dependency graph:
//
//   locationProvider  (StreamProvider<LocationData?>)
//        │
//        ▼
//   astronomicalDataProvider  (StreamProvider<AstronomicalData?>)
//        │ ┌──────────────────────────────────┐
//        │ │  recalculates every 60 s         │
//        │ └──────────────────────────────────┘
//        ▼
//   skyStateProvider  (Provider<SkyState?>)   ← derived
//
//   currentSolarAltitudeProvider  (StreamProvider<double?>)
//        │
//        └── independent 10-second ticker, uses location from locationProvider
//
// Design decisions:
//   • StreamProviders are used instead of StateNotifierProviders so that the
//     timer logic lives entirely inside the provider and is automatically
//     cancelled when the last listener disposes.
//   • Location is polled every 5 minutes to balance battery and accuracy.
//   • All heavy calculations are offloaded to a top-level compute-friendly
//     synchronous call so the UI thread is never blocked.
//   • Providers are family-less so that the widget layer can read them with
//     the simple ref.watch(astronomicalDataProvider) syntax.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/solar_calculator.dart';
import '../domain/astronomical_data.dart';
import '../domain/solar_event.dart';

// ── Shared calculator instance ─────────────────────────────────────────────────

/// A single, reusable [SolarCalculator] that all providers share.
/// Declared as a top-level constant so it is created once at app start.
const _calc = SolarCalculator();

// ── Location polling interval ──────────────────────────────────────────────────

/// How often the location provider re-queries the device GPS.
const Duration _kLocationPollInterval = Duration(minutes: 5);

/// How often [astronomicalDataProvider] recalculates the full data bundle.
const Duration _kAstroUpdateInterval = Duration(minutes: 1);

/// How often [currentSolarAltitudeProvider] refreshes the real-time altitude.
const Duration _kAltitudeUpdateInterval = Duration(seconds: 10);

// ── LocationData ──────────────────────────────────────────────────────────────

/// Simple immutable holder for a latitude/longitude pair, decoupled from the
/// [Position] class so that callers in the domain layer have no geolocator dep.
class LocationData {
  const LocationData({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'LocationData(lat: ${latitude.toStringAsFixed(5)}, '
      'lon: ${longitude.toStringAsFixed(5)})';
}

// ── 1. locationProvider ───────────────────────────────────────────────────────

/// Emits a fresh [LocationData] immediately on subscription and then every
/// [_kLocationPollInterval], or null when location permission is unavailable.
///
/// The stream never emits an error; failures are swallowed and null is emitted
/// instead so downstream providers degrade gracefully.
final locationProvider = StreamProvider<LocationData?>((ref) async* {
  // Emit current location immediately, then continue polling.
  yield await _fetchLocation();

  // Start the polling timer.
  while (true) {
    await Future.delayed(_kLocationPollInterval);
    yield await _fetchLocation();
  }
});

/// Attempts to retrieve the device's current GPS position.
/// Returns null on permission denial or any platform error.
Future<LocationData?> _fetchLocation() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 15),
    );

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (_) {
    return null;
  }
}

// ── 2. astronomicalDataProvider ───────────────────────────────────────────────

/// Emits a freshly computed [AstronomicalData] bundle on startup and then once
/// per [_kAstroUpdateInterval].
///
/// The data is recalculated whenever:
///   a) A new location is received from [locationProvider], or
///   b) The 60-second refresh ticker fires.
///
/// Emits null when no location is available yet or when location is denied.
final astronomicalDataProvider = StreamProvider<AstronomicalData?>((ref) async* {
  // Capture location BEFORE any await. ref.watch here means Riverpod will
  // cancel and restart this generator whenever locationProvider changes.
  final location = ref.watch(locationProvider).valueOrNull;

  if (location == null) {
    yield null;
  } else {
    yield _computeAstronomicalData(location);
  }

  // Periodic refresh using only the pre-captured location.
  // Do NOT call ref.read/ref.watch after any await.
  while (true) {
    await Future.delayed(_kAstroUpdateInterval);
    if (location != null) {
      yield _computeAstronomicalData(location);
    } else {
      yield null;
    }
  }
});

/// Performs the full [AstronomicalData] calculation synchronously.
///
/// Kept as a top-level function (not a method) so it can be passed to
/// Isolate.run / compute() in a future performance improvement without
/// changing the call site.
AstronomicalData _computeAstronomicalData(LocationData location) {
  final now = DateTime.now().toUtc();
  return _calc.calculateAll(location.latitude, location.longitude, now);
}

// ── 3. currentSolarAltitudeProvider ──────────────────────────────────────────

/// Emits the sun's current geometric altitude (degrees) every
/// [_kAltitudeUpdateInterval] (10 seconds), computed from the most recently
/// known location.
///
/// Emits null when location is unavailable.
///
/// This is intentionally kept as a separate, lightweight provider so the UI
/// can drive smooth animations without triggering a full [AstronomicalData]
/// rebuild on every tick.
final currentSolarAltitudeProvider = StreamProvider<double?>((ref) async* {
  // Capture location BEFORE any await. ref.watch restarts this generator
  // whenever locationProvider emits a new value.
  final location = ref.watch(locationProvider).valueOrNull;

  yield location != null
      ? _calc.currentSolarAltitude(location.latitude, location.longitude)
      : null;

  while (true) {
    await Future.delayed(_kAltitudeUpdateInterval);
    // Use pre-captured location — do NOT call ref after any await.
    if (location != null) {
      yield _calc.currentSolarAltitude(location.latitude, location.longitude);
    } else {
      yield null;
    }
  }
});

// ── 4. skyStateProvider ───────────────────────────────────────────────────────

/// Derived provider: maps the latest solar altitude from
/// [currentSolarAltitudeProvider] to the corresponding [SkyState].
///
/// Returns null when no altitude data is available yet.
///
/// Because this provider is synchronous and derived, it updates every time
/// [currentSolarAltitudeProvider] emits a new value – i.e., every 10 seconds.
final skyStateProvider = Provider<SkyState?>((ref) {
  final altitudeAsync = ref.watch(currentSolarAltitudeProvider);
  return altitudeAsync.whenOrNull(
    data: (altitude) =>
        altitude != null ? _calc.skyState(altitude) : null,
  );
});

// ── 5. solarDataProvider ──────────────────────────────────────────────────────

/// Derived provider: extracts [SolarData] from [astronomicalDataProvider].
/// Returns null when the full bundle is not yet available.
final solarDataProvider = Provider<SolarData?>((ref) {
  final dataAsync = ref.watch(astronomicalDataProvider);
  return dataAsync.valueOrNull?.solar;
});

// ── 6. moonDataProvider ───────────────────────────────────────────────────────

/// Derived provider: extracts [MoonData] from [astronomicalDataProvider].
final moonDataProvider = Provider<MoonData?>((ref) {
  final dataAsync = ref.watch(astronomicalDataProvider);
  return dataAsync.valueOrNull?.moon;
});

// ── 7. atmosphericDataProvider ────────────────────────────────────────────────

/// Derived provider: extracts [AtmosphericData] from [astronomicalDataProvider].
///
/// Updates on the [_kAstroUpdateInterval] (1 minute) cadence of the parent.
/// For higher-frequency position updates, prefer watching
/// [currentSolarAltitudeProvider] directly.
final atmosphericDataProvider = Provider<AtmosphericData?>((ref) {
  final dataAsync = ref.watch(astronomicalDataProvider);
  return dataAsync.valueOrNull?.atmospheric;
});

// ── 8. nextSolarEventProvider ─────────────────────────────────────────────────

/// Derived provider: returns the next upcoming [SolarEvent] for today, or null
/// when all of today's events have passed or data is unavailable.
final nextSolarEventProvider = Provider<SolarEvent?>((ref) {
  final dataAsync = ref.watch(astronomicalDataProvider);
  return dataAsync.valueOrNull?.nextEvent();
});
