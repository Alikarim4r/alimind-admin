import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location_model.dart';

/// Key used to persist the last known location in [SharedPreferences].
const String _kLocationPrefsKey = 'last_known_location';

/// Interval between automatic background location refreshes.
const Duration _kLocationUpdateInterval = Duration(minutes: 5);

class LocationService {
  LocationService({SharedPreferences? prefs}) : _prefs = prefs;

  /// Lazily-resolved [SharedPreferences] instance.
  SharedPreferences? _prefs;

  StreamController<LocationData>? _locationStreamController;
  Timer? _locationTimer;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests location permission from the OS.
  ///
  /// Returns `true` when [LocationPermission.always] or
  /// [LocationPermission.whileInUse] is granted.
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _isPermissionSufficient(permission);
  }

  /// Returns `true` when location permission has already been granted.
  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return _isPermissionSufficient(permission);
  }

  bool _isPermissionSufficient(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  // ---------------------------------------------------------------------------
  // One-shot GPS fix
  // ---------------------------------------------------------------------------

  /// Returns the current GPS position, or `null` if unavailable / denied.
  Future<LocationData?> getCurrentLocation() async {
    try {
      final granted = await requestPermission();
      if (!granted) return null;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final data = _positionToLocationData(position, LocationSource.gps);

      // Persist so it can be used as a fallback later.
      await saveManualLocation(data);
      return data;
    } on TimeoutException {
      return null;
    } on LocationServiceDisabledException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Continuous stream
  // ---------------------------------------------------------------------------

  /// Returns a [Stream] that emits a [LocationData] update roughly every
  /// [_kLocationUpdateInterval] (5 minutes).
  ///
  /// The stream also emits immediately with the best available location
  /// (GPS → saved → Makkah default).
  Stream<LocationData> locationStream() {
    // Close any existing stream before opening a new one.
    _locationStreamController?.close();
    _locationTimer?.cancel();

    _locationStreamController = StreamController<LocationData>.broadcast(
      onCancel: () {
        _locationTimer?.cancel();
        _locationTimer = null;
      },
    );

    // Emit the first reading immediately.
    _emitCurrentLocation();

    // Then emit on a recurring timer.
    _locationTimer = Timer.periodic(_kLocationUpdateInterval, (_) {
      _emitCurrentLocation();
    });

    return _locationStreamController!.stream;
  }

  Future<void> _emitCurrentLocation() async {
    final controller = _locationStreamController;
    if (controller == null || controller.isClosed) return;

    final location = await getCurrentLocation() ??
        await getLastKnownLocation() ??
        kDefaultMakkahLocation;

    if (!controller.isClosed) {
      controller.add(location);
    }
  }

  // ---------------------------------------------------------------------------
  // Last-known location cache
  // ---------------------------------------------------------------------------

  /// Returns the last location that was saved to [SharedPreferences], or
  /// `null` if none exists.
  Future<LocationData?> getLastKnownLocation() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(_kLocationPrefsKey);
      if (jsonString == null) return null;
      return LocationData.fromJsonString(jsonString);
    } catch (_) {
      return null;
    }
  }

  /// Persists [location] to [SharedPreferences] as a JSON string.
  Future<void> saveManualLocation(LocationData location) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_kLocationPrefsKey, location.toJsonString());
    } catch (_) {
      // Persist failure is non-fatal; location will just not be cached.
    }
  }

  /// Loads the saved location from [SharedPreferences].
  ///
  /// Alias for [getLastKnownLocation] kept for semantic clarity at call sites
  /// where the intent is to restore a previously chosen location.
  Future<LocationData?> loadSavedLocation() => getLastKnownLocation();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  LocationData _positionToLocationData(
    Position position,
    LocationSource source,
  ) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      // Reverse-geocoding is out of scope here; city/country left null and can
      // be resolved by an upstream provider if needed.
      city: null,
      country: null,
      timezoneName: DateTime.now().timeZoneName,
      timestamp: position.timestamp ?? DateTime.now(),
      source: source,
    );
  }

  /// Releases all resources held by this service.
  void dispose() {
    _locationTimer?.cancel();
    _locationStreamController?.close();
  }
}
