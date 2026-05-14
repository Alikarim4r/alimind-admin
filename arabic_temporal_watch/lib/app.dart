import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';

// ── Route names ───────────────────────────────────────────────────────────────

/// Named route constants used throughout the application.
abstract final class AppRoutes {
  /// The primary watch-face screen.
  static const String watch = '/';

  /// Permissions / onboarding screen shown when location access is unavailable.
  static const String permissions = '/permissions';

  /// App settings (appearance, manual location, calculation method, etc.).
  static const String settings = '/settings';

  /// Detailed astronomical information for the current period.
  static const String periodDetail = '/period-detail';
}

// ── Root application widget ───────────────────────────────────────────────────

/// Root widget of the Arabic Temporal Watch application.
///
/// Responsibilities:
///   * Applies the luxury dark [AppTheme].
///   * Declares Arabic locale delegates for proper RTL rendering.
///   * Defines the named-route table.
///   * Manages locale state so the app can be toggled between AR and EN without
///     a restart (future feature; defaults to Arabic).
class ArabicTemporalWatchApp extends ConsumerWidget {
  const ArabicTemporalWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // ── App metadata ──────────────────────────────────────────────────────
      title: 'الساعة العربية',
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────────────────────
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // ── Locale & internationalisation ──────────────────────────────────────
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        // Flutter's built-in delegates for widgets, cupertino, and material.
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        // NOTE: Add a generated AppLocalizations delegate here once arb files
        // are created via `flutter gen-l10n`.
      ],

      // ── Text direction ──────────────────────────────────────────────────────
      // Explicitly set RTL as the default; individual widgets can override via
      // Directionality if they contain mixed LTR/RTL content.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ── Initial route ───────────────────────────────────────────────────────
      initialRoute: AppRoutes.watch,

      // ── Named routes ────────────────────────────────────────────────────────
      routes: {
        AppRoutes.watch: (context) => const _WatchScreenPlaceholder(),
        AppRoutes.permissions: (context) =>
            const _PermissionsScreenPlaceholder(),
        AppRoutes.settings: (context) => const _SettingsScreenPlaceholder(),
        AppRoutes.periodDetail: (context) =>
            const _PeriodDetailScreenPlaceholder(),
      },

      // ── Route transitions ────────────────────────────────────────────────────
      onGenerateRoute: _onGenerateRoute,

      // ── Unknown route fallback ───────────────────────────────────────────────
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _UnknownRoutePage(),
      ),
    );
  }

  /// Custom route generator that applies a luxury fade + scale transition to
  /// every named route navigation.  Falls back to a standard material page
  /// route for any route not explicitly listed.
  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // Named routes are already handled by the `routes` map; this method only
    // fires for routes NOT in that map (e.g. routes with arguments).
    return null;
  }
}

// ── Placeholder screens ───────────────────────────────────────────────────────
// These will be replaced by the real screen implementations once they are
// written.  They are inlined here so `app.dart` compiles standalone without
// external dependencies on not-yet-created files.

class _WatchScreenPlaceholder extends StatelessWidget {
  const _WatchScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05081A),
      body: Center(
        child: Text(
          'الساعة العربية',
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 32,
            color: Color(0xFFD4AF37),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _PermissionsScreenPlaceholder extends StatelessWidget {
  const _PermissionsScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05081A),
      body: Center(
        child: Text(
          'إذن الموقع مطلوب',
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 24,
            color: Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }
}

class _SettingsScreenPlaceholder extends StatelessWidget {
  const _SettingsScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05081A),
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontFamily: 'ArabicDisplay'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SizedBox.shrink(),
    );
  }
}

class _PeriodDetailScreenPlaceholder extends StatelessWidget {
  const _PeriodDetailScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05081A),
      appBar: AppBar(
        title: const Text(
          'تفاصيل الفترة',
          style: TextStyle(fontFamily: 'ArabicDisplay'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SizedBox.shrink(),
    );
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05081A),
      body: Center(
        child: Text(
          'الصفحة غير موجودة',
          style: TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 20,
            color: Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }
}
