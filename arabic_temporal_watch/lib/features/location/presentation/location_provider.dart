import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_service.dart';
import '../domain/location_model.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the singleton [LocationService] instance to the widget tree.
final locationServiceProvider = Provider<LocationService>(
  (ref) {
    final service = LocationService();
    // Dispose the service (stops timers and closes streams) when the provider
    // is destroyed.
    ref.onDispose(service.dispose);
    return service;
  },
);

// ---------------------------------------------------------------------------
// Preset locations provider
// ---------------------------------------------------------------------------

/// Exposes the compiled-in list of well-known [PresetLocation] values.
final presetLocationsProvider = Provider<List<PresetLocation>>(
  (_) => kPresetLocations,
);

// ---------------------------------------------------------------------------
// Location state notifier
// ---------------------------------------------------------------------------

/// Manages the active [LocationData] used throughout the app.
///
/// Initialisation order:
///   1. Try a live GPS fix.
///   2. Fall back to the last saved location.
///   3. Fall back to the Makkah default.
class LocationNotifier extends StateNotifier<LocationData> {
  LocationNotifier(this._service) : super(kDefaultMakkahLocation) {
    _init();
  }

  final LocationService _service;
  StreamSubscription<LocationData>? _streamSub;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    // 1. Try GPS first.
    final gpsLocation = await _service.getCurrentLocation();
    if (gpsLocation != null) {
      if (mounted) state = gpsLocation;
      _startStream();
      return;
    }

    // 2. Fall back to saved location.
    final savedLocation = await _service.loadSavedLocation();
    if (savedLocation != null) {
      if (mounted) state = savedLocation;
      _startStream();
      return;
    }

    // 3. Fall back to Makkah default — state is already set in super().
    _startStream();
  }

  /// Subscribes to [LocationService.locationStream] so the state stays fresh
  /// even after the initial fix.
  void _startStream() {
    _streamSub?.cancel();
    _streamSub = _service.locationStream().listen(
      (location) {
        if (mounted) state = location;
      },
      onError: (_) {
        // Stream errors are non-fatal; keep the last known state.
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Immediately applies [location] as the active location and persists it.
  Future<void> setManualLocation(LocationData location) async {
    await _service.saveManualLocation(
      location.copyWith(source: LocationSource.manual),
    );
    if (mounted) {
      state = location.copyWith(source: LocationSource.manual);
    }
  }

  /// Convenience overload that accepts a [PresetLocation].
  Future<void> setPresetLocation(PresetLocation preset) =>
      setManualLocation(preset.toLocationData());

  /// Triggers a fresh GPS fix and updates state if successful.
  Future<void> refreshGPS() async {
    final fresh = await _service.getCurrentLocation();
    if (fresh != null && mounted) {
      state = fresh;
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// StateNotifierProvider
// ---------------------------------------------------------------------------

/// The primary location provider for the app.
///
/// Widgets read this to get the current [LocationData] and call
/// [LocationNotifier.setManualLocation] / [LocationNotifier.refreshGPS]
/// to change it.
///
/// Example:
/// ```dart
/// // Read current location
/// final location = ref.watch(locationProvider);
///
/// // Refresh GPS
/// await ref.read(locationProvider.notifier).refreshGPS();
///
/// // Set a preset
/// final preset = ref.read(presetLocationsProvider)[0]; // Makkah
/// await ref.read(locationProvider.notifier).setPresetLocation(preset);
/// ```
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationData>(
  (ref) => LocationNotifier(ref.watch(locationServiceProvider)),
);
