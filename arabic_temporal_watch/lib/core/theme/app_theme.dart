import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Luxury dark theme for the Arabic Temporal Watch application.
///
/// Built on Material 3 with a custom [ColorScheme] derived from the app's
/// gold/navy palette.  All component themes are explicitly configured so the
/// watch face and supporting screens look intentional and premium rather than
/// defaulting to Material 3's tonal surface algorithm.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.darkTheme,
///   themeMode: ThemeMode.dark,
/// )
/// ```
abstract final class AppTheme {
  // ── Public theme getter ────────────────────────────────────────────────────

  /// The single dark luxury theme used throughout the application.
  static ThemeData get darkTheme => _buildDarkTheme();

  // ── Color scheme ──────────────────────────────────────────────────────────

  /// The app's Material 3 [ColorScheme].
  ///
  /// The "seed" paradigm is intentionally bypassed: each role is assigned an
  /// exact color from [AppColors] so the palette remains precisely under
  /// design control.
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.dark,

        // ── Primary: gold ─────────────────────────────────────────────────
        primary: AppColors.goldPrimary,
        onPrimary: AppColors.backgroundDeep,
        primaryContainer: AppColors.goldDark,
        onPrimaryContainer: AppColors.goldPale,

        // ── Secondary: silver/moonlight ───────────────────────────────────
        secondary: AppColors.silverMid,
        onSecondary: AppColors.backgroundDeep,
        secondaryContainer: AppColors.silverDeep,
        onSecondaryContainer: AppColors.silverLight,

        // ── Tertiary: prayer blue ──────────────────────────────────────────
        tertiary: AppColors.prayerFajr,
        onTertiary: AppColors.moonlight,
        tertiaryContainer: AppColors.skyDawnAstro,
        onTertiaryContainer: AppColors.crescentSilver,

        // ── Error ──────────────────────────────────────────────────────────
        error: Color(0xFFCF6679),
        onError: Color(0xFF370B1E),
        errorContainer: Color(0xFF7E1C2F),
        onErrorContainer: Color(0xFFFFB4B4),

        // ── Surface / background ───────────────────────────────────────────
        surface: AppColors.backgroundMid,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.backgroundCard,
        onSurfaceVariant: AppColors.textSecondary,

        // ── Outline ────────────────────────────────────────────────────────
        outline: AppColors.borderNormal,
        outlineVariant: AppColors.borderSubtle,

        // ── Scrim & shadow ─────────────────────────────────────────────────
        scrim: AppColors.scrim,
        shadow: AppColors.backgroundDeep,

        // ── Inverse ────────────────────────────────────────────────────────
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.backgroundMid,
        inversePrimary: AppColors.goldDark,

        // ── Surface tint (M3 elevation tint) — turned off intentionally ───
        surfaceTint: AppColors.transparent,
      );

  // ── Private builder ────────────────────────────────────────────────────────

  static ThemeData _buildDarkTheme() {
    final cs = colorScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,

      // ── Scaffold background ────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.backgroundMid,

      // ── Canvas / card background ───────────────────────────────────────────
      canvasColor: AppColors.backgroundMid,
      cardColor: AppColors.backgroundCard,

      // ── Typography ─────────────────────────────────────────────────────────
      fontFamily: 'ArabicDisplay',
      textTheme: _buildTextTheme(),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.transparent,
        foregroundColor: AppColors.goldPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: AppColors.transparent,
        surfaceTintColor: AppColors.transparent,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.goldPrimary,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.goldPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.goldPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // ── Icon ──────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.goldPrimary,
        size: 24,
      ),
      primaryIconTheme: const IconThemeData(
        color: AppColors.goldPrimary,
        size: 24,
      ),

      // ── Elevated button ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldPrimary,
          foregroundColor: AppColors.backgroundDeep,
          shadowColor: AppColors.glowGold,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // ── Text button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldPrimary,
          textStyle: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 15,
            letterSpacing: 0.8,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.goldPrimary,
          side: const BorderSide(color: AppColors.goldPrimary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 15,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // ── FloatingActionButton ───────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.goldPrimary,
        foregroundColor: AppColors.backgroundDeep,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        splashColor: AppColors.goldLight,
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppColors.backgroundCard,
        shadowColor: AppColors.backgroundDeep,
        elevation: 4,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 0.5,
        space: 16,
      ),
      dividerColor: AppColors.borderSubtle,

      // ── List tile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.backgroundCard,
        textColor: AppColors.textPrimary,
        iconColor: AppColors.goldPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundSurface,
        modalBackgroundColor: AppColors.backgroundSurface,
        dragHandleColor: AppColors.goldAntique,
        dragHandleSize: Size(40, 4),
        elevation: 16,
        modalElevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundSurface,
        elevation: 24,
        shadowColor: AppColors.backgroundDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.goldPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundCard,
        contentTextStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.goldPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.goldPrimary;
          }
          return AppColors.silverDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.goldDark;
          }
          return AppColors.silverDeep;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.transparent),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.goldPrimary,
        inactiveTrackColor: AppColors.goldAntique,
        thumbColor: AppColors.goldLight,
        overlayColor: AppColors.glowGoldWide,
        valueIndicatorColor: AppColors.goldDark,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: 'ArabicDisplay',
          color: AppColors.backgroundDeep,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── Progress indicator ─────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.goldPrimary,
        circularTrackColor: AppColors.goldAntique,
        linearTrackColor: AppColors.goldAntique,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundCard,
        selectedColor: AppColors.goldDark,
        disabledColor: AppColors.backgroundSurface,
        labelStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 13,
          color: AppColors.backgroundDeep,
        ),
        side: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── Input decoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderNormal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679)),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          color: AppColors.textMuted,
        ),
        prefixIconColor: AppColors.goldPrimary,
        suffixIconColor: AppColors.goldPrimary,
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle, width: 0.5),
        ),
        textStyle: const TextStyle(
          fontFamily: 'ArabicDisplay',
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Navigation bar (bottom nav) ────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundSurface,
        indicatorColor: AppColors.goldDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.goldPrimary, size: 26);
          }
          return const IconThemeData(color: AppColors.silverDim, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'ArabicDisplay',
              fontSize: 12,
              color: AppColors.goldPrimary,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: 'ArabicDisplay',
            fontSize: 12,
            color: AppColors.silverDim,
          );
        }),
        elevation: 8,
        shadowColor: AppColors.backgroundDeep,
        surfaceTintColor: AppColors.transparent,
      ),

      // ── Scrollbar ─────────────────────────────────────────────────────────
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.goldAntique),
        trackColor: WidgetStatePropertyAll(AppColors.backgroundCard),
        radius: Radius.circular(4),
        thickness: WidgetStatePropertyAll(3),
      ),

      // ── Page transitions ───────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Text theme ─────────────────────────────────────────────────────────────

  /// Builds a complete [TextTheme] using the ArabicDisplay font family and
  /// the app's color palette.  All sizes follow Material 3 type scale naming.
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      // Display
      displayLarge: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.22,
      ),

      // Headline
      headlineLarge: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.goldPrimary,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.goldPrimary,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.goldPrimary,
        height: 1.33,
      ),

      // Title
      titleLarge: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColors.textPrimary,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: AppColors.textSecondary,
        height: 1.43,
      ),

      // Body
      bodyLarge: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.textSecondary,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
        height: 1.33,
      ),

      // Label
      labelLarge: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: AppColors.goldPrimary,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.goldPrimary,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontFamily: 'ArabicDisplay',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textMuted,
        height: 1.45,
      ),
    );
  }
}
