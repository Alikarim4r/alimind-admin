import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/period_detail/presentation/period_detail_screen.dart';
import 'features/permissions/presentation/permissions_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/temporal_engine/domain/arabic_period.dart' show ArabicPeriodSlot;
import 'features/watch_ui/presentation/watch_screen.dart';

// ── Route name constants ──────────────────────────────────────────────────────

/// All named route paths used throughout the application.
///
/// Using an abstract final class (rather than an enum) keeps the values as
/// compile-time string constants that can be used directly in [MaterialApp.routes]
/// and [Navigator.pushNamed] without any `.name` conversion.
abstract final class AppRoutes {
  /// First-run onboarding flow (3 pages: welcome → concept → setup).
  static const String onboarding = '/onboarding';

  /// The primary watch-face screen — the app's home.
  static const String watch = '/';

  /// Permissions screen shown when location access is unavailable.
  static const String permissions = '/permissions';

  /// App settings: appearance, manual location, prayer calculation method, etc.
  static const String settings = '/settings';

  /// Detailed astronomical information panel for the currently active period.
  static const String periodDetail = '/period-detail';
}

// ── Initial route provider ────────────────────────────────────────────────────

/// Determines whether to show onboarding or jump straight to the watch face.
/// Must be overridden in the root [ProviderScope] at startup.
final initialRouteProvider = Provider<String>(
  (_) => AppRoutes.watch,
  name: 'initialRouteProvider',
);

// ── Locale provider ───────────────────────────────────────────────────────────

/// Allows the app's locale to be toggled at runtime without a full restart.
///
/// Defaults to Arabic (Saudi Arabia).  Consumers can call
/// `ref.read(appLocaleProvider.notifier).state = const Locale('en', 'US')`
/// to switch languages dynamically.
final appLocaleProvider = StateProvider<Locale>(
  (_) => const Locale('ar', 'SA'),
  name: 'appLocaleProvider',
);

// ── Root widget ───────────────────────────────────────────────────────────────

/// Root widget of the Arabic Temporal Watch application.
///
/// Responsibilities:
///   * Applies the luxury dark [AppTheme] and forces [ThemeMode.dark].
///   * Declares locale delegates for proper RTL / Arabic rendering.
///   * Wraps every route in an RTL [Directionality] so Arabic text layout
///     is correct by default; individual widgets may override this for mixed
///     LTR/RTL content such as digit strings.
///   * Defines the named-route table and a custom page-route builder for
///     luxury fade + scale transitions.
///   * Handles unknown routes gracefully with a fallback page.
class ArabicTemporalWatchApp extends ConsumerWidget {
  const ArabicTemporalWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      // ── App metadata ──────────────────────────────────────────────────────
      title: 'الساعة العربية',
      debugShowCheckedModeBanner: false,

      // ── Theme ─────────────────────────────────────────────────────────────
      theme: AppTheme.darkTheme,
      // No lightTheme — this is an intentionally dark-only luxury product.
      themeMode: ThemeMode.dark,

      // ── Locale & internationalisation ─────────────────────────────────────
      locale: locale,
      supportedLocales: const [
        Locale('ar', 'SA'), // Arabic – Saudi Arabia (primary)
        Locale('ar'),       // Arabic – generic fallback
        Locale('en', 'US'), // English – US (secondary)
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Global RTL direction wrapper ──────────────────────────────────────
      // Every screen and dialog inherits RTL so Arabic text is laid out
      // correctly without needing per-widget Directionality wrappers.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ── Navigation ────────────────────────────────────────────────────────
      initialRoute: ref.watch(initialRouteProvider),
      routes: _buildRouteTable(),
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onUnknownRoute,
    );
  }

  // ── Route table ────────────────────────────────────────────────────────────

  static Map<String, WidgetBuilder> _buildRouteTable() {
    return {
      AppRoutes.onboarding: (_) => const OnboardingScreen(),
      AppRoutes.watch: (_) => const WatchScreen(),
      AppRoutes.permissions: (_) => const PermissionsScreen(),
      AppRoutes.settings: (_) => const SettingsScreen(),
      // period-detail requires an ArabicPeriodSlot argument — handled in
      // _onGenerateRoute below rather than in the static table.
    };
  }

  // ── Custom route generation ────────────────────────────────────────────────

  /// Handles named routes that carry arguments and therefore cannot be
  /// registered in the static [routes] map.
  ///
  /// Applies a luxury fade + scale transition to every generated route,
  /// consistent with the app's premium aesthetic.
  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // period-detail carries an ArabicPeriodSlot argument.
    if (settings.name == AppRoutes.periodDetail) {
      final slot = settings.arguments as ArabicPeriodSlot?;
      if (slot != null) {
        return LuxuryPageRoute(
          settings: settings,
          builder: (_) => PeriodDetailScreen(slot: slot),
        );
      }
    }
    return null;
  }

  // ── Unknown-route fallback ─────────────────────────────────────────────────

  static Route<void> _onUnknownRoute(RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const _UnknownRoutePage(),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
    );
  }
}

// ── Luxury page route ─────────────────────────────────────────────────────────

/// A [PageRouteBuilder] that applies a simultaneous fade and subtle scale-up
/// transition — the standard navigation animation used by this app.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   LuxuryPageRoute(builder: (_) => const SomeScreen()),
/// );
/// ```
class LuxuryPageRoute<T> extends PageRouteBuilder<T> {
  LuxuryPageRoute({
    required WidgetBuilder builder,
    super.settings,
    Duration transitionDuration = const Duration(milliseconds: 480),
  }) : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: transitionDuration,
          reverseTransitionDuration:
              Duration(milliseconds: transitionDuration.inMilliseconds ~/ 2),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade from 0 → 1
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
            );

            // Scale from 0.92 → 1.0 for a gentle "materialise" feel
            final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

// ── Unknown route fallback ────────────────────────────────────────────────────

class _BaseScaffold extends StatelessWidget {
  const _BaseScaffold({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF05081A),
        child: SafeArea(child: child),
      );
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05081A),
      body: _BaseScaffold(
        child: Center(
          child: Text(
            'الصفحة غير موجودة',
            style: TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 20,
              color: Color(0xFFD4AF37),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
