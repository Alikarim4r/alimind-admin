import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart' show ArabicTemporalWatchApp, AppRoutes, initialRouteProvider;

/// Entry point for the Arabic Temporal Watch application.
///
/// Performs the following initialization sequence before [runApp]:
///   1. Ensure the Flutter engine binding is ready.
///   2. Lock device orientation to portrait.
///   3. Apply a dark system-UI overlay style (status bar / nav bar).
///   4. Pre-load [SharedPreferences] so providers can access it synchronously.
///   5. Request location permissions and capture the result for the initial
///      [ProviderScope] override so the permission state is available at build.
///   6. Wrap the widget tree in a [ProviderScope] with pre-loaded overrides.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── 1. Orientation ────────────────────────────────────────────────────────
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // ── 2. System UI style ────────────────────────────────────────────────────
      // Fully transparent status bar with light icons to float over the deep
      // navy watch face; navigation bar matches the background colour.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // iOS
          systemNavigationBarColor: Color(0xFF05081A),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // ── 3. SharedPreferences pre-load ─────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();

      // ── 4. Location permission flow ───────────────────────────────────────────
      final locationPermissionStatus = await _requestLocationPermission();

      // ── 5. Determine initial route ────────────────────────────────────────────
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      final initialRoute =
          onboardingDone ? AppRoutes.watch : AppRoutes.onboarding;

      // ── 6. Run app ────────────────────────────────────────────────────────────
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLocationPermissionProvider.overrideWithValue(
              locationPermissionStatus,
            ),
            initialRouteProvider.overrideWithValue(initialRoute),
          ],
          child: const ArabicTemporalWatchApp(),
        ),
      );
    },
    (error, stackTrace) {
      // Top-level error handler — in production forward to a crash reporting
      // service such as Firebase Crashlytics or Sentry.
      debugPrint('[ArabicTemporalWatch] Uncaught error: $error');
      debugPrint('$stackTrace');
    },
  );
}

// ── Global providers ─────────────────────────────────────────────────────────

/// Provides the pre-loaded [SharedPreferences] instance to the entire widget
/// tree.  Must be overridden in the root [ProviderScope] at startup.
///
/// Accessing this provider without the override will throw [UnimplementedError]
/// at runtime, which is intentional — it surfaces misconfiguration early.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in the root ProviderScope. '
    'Ensure main() calls SharedPreferences.getInstance() before runApp().',
  ),
  name: 'sharedPreferencesProvider',
);

/// Carries the [LocationPermission] status captured during app start-up.
///
/// This allows the first frame of the UI to immediately know whether location
/// access was granted without any asynchronous gap.  Overridden in the root
/// [ProviderScope] at startup.
final initialLocationPermissionProvider = Provider<LocationPermission>(
  (ref) => LocationPermission.denied,
  name: 'initialLocationPermissionProvider',
);

// ── Private helpers ──────────────────────────────────────────────────────────

/// Requests location permission following the correct platform flow:
///
///   1. Verify that location services are enabled on the device.
///   2. Check current permission status.
///   3. If denied, request it once (triggers the OS permission dialog).
///   4. If permanently denied, return gracefully without crashing — the UI
///      will surface an actionable prompt to open app settings.
///
/// Also aligns the `permission_handler` fine-location permission on Android
/// variants where `geolocator` alone is unreliable.
///
/// Returns the final [LocationPermission] so the UI can branch accordingly.
Future<LocationPermission> _requestLocationPermission() async {
  try {
    return await _requestLocationPermissionImpl();
  } catch (error) {
    // Geolocator has no implementation on some desktop targets. Start the app
    // anyway — it falls back to the Makkah coordinates — instead of dying
    // before runApp() and showing an empty window.
    debugPrint('[ArabicTemporalWatch] Location lookup unavailable on this '
        'platform: $error');
    return LocationPermission.unableToDetermine;
  }
}

Future<LocationPermission> _requestLocationPermissionImpl() async {
  // ── Check if location services are enabled at the device level ─────────────
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Return a distinguishable sentinel so the UI can prompt the user to
    // enable location services in their device Settings, not just app settings.
    debugPrint(
      '[ArabicTemporalWatch] Location services are disabled on the device.',
    );
    return LocationPermission.unableToDetermine;
  }

  // ── Check / request the Geolocator-level permission ─────────────────────────
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    // Do NOT auto-open settings here.  The WatchScreen / PermissionsScreen
    // handles this UX flow with proper user explanation before redirecting.
    debugPrint(
      '[ArabicTemporalWatch] Location permission permanently denied. '
      'App will fall back to manual location entry.',
    );
    return permission;
  }

  // ── Align permission_handler on Android where needed ────────────────────────
  // Some Android OEM variants (MIUI, ColorOS, etc.) require the
  // permission_handler plugin to complete the runtime permission grant even
  // after Geolocator reports success.
  //
  // Android only: permission_handler ships no macOS/Windows/Linux
  // implementation, so calling it there throws MissingPluginException — and
  // because this runs before runApp(), that would leave a blank window.
  final isAndroid =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (isAndroid &&
      (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always)) {
    try {
      final pHandlerStatus = await Permission.locationWhenInUse.status;
      if (pHandlerStatus.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    } catch (error) {
      // Never let a permission-plugin quirk block start-up; Geolocator has
      // already reported the authoritative status.
      debugPrint('[ArabicTemporalWatch] permission_handler alignment '
          'skipped: $error');
    }
  }

  return permission;
}
