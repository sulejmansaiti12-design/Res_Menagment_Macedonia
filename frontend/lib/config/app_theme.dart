import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ═══════════════════════════════════════════════════════════
/// APP THEME — iOS-Inspired Light & Dark
/// Light: Apple iOS 17 white/gray aesthetic
/// Dark:  Apple iOS 17 true-black aesthetic
/// ═══════════════════════════════════════════════════════════
class AppTheme {
  // ─── SHARED SEMANTIC COLORS (adapt per brightness) ───────
  // These are used directly in widgets — always reference
  // via Theme.of(context).colorScheme or AppTheme static helpers.

  // iOS Blue
  static const Color iosBlue       = Color(0xFF007AFF);
  static const Color iosBlueDark   = Color(0xFF0A84FF);

  // iOS Green
  static const Color iosGreen      = Color(0xFF34C759);
  static const Color iosGreenDark  = Color(0xFF30D158);

  // iOS Red
  static const Color iosRed        = Color(0xFFFF3B30);
  static const Color iosRedDark    = Color(0xFFFF453A);

  // iOS Orange
  static const Color iosOrange     = Color(0xFFFF9500);
  static const Color iosOrangeDark = Color(0xFFFF9F0A);

  // iOS Yellow
  static const Color iosYellow     = Color(0xFFFFCC00);
  static const Color iosYellowDark = Color(0xFFFFD60A);

  // iOS Purple
  static const Color iosPurple     = Color(0xFFAF52DE);
  static const Color iosPurpleDark = Color(0xFFBF5AF2);

  // iOS Teal
  static const Color iosTeal       = Color(0xFF5AC8FA);
  static const Color iosTealDark   = Color(0xFF64D2FF);

  // ─── LIGHT THEME SURFACES ─────────────────────────────────
  static const Color lightBg           = Color(0xFFF2F2F7); // iOS grouped bg
  static const Color lightSurface      = Color(0xFFFFFFFF); // Cards/sheets
  static const Color lightSurface2     = Color(0xFFF9F9FB); // Elevated layer
  static const Color lightSurfaceOffset= Color(0xFFEFEFF4); // Inset fills
  static const Color lightBorder       = Color(0xFFD1D1D6); // iOS separator
  static const Color lightText         = Color(0xFF000000);
  static const Color lightTextSecondary= Color(0xFF6C6C70); // iOS label secondary
  static const Color lightTextTertiary = Color(0xFFAEAEB2); // iOS label tertiary

  // ─── DARK THEME SURFACES ──────────────────────────────────
  static const Color darkBg            = Color(0xFF000000); // True black
  static const Color darkSurface       = Color(0xFF1C1C1E); // iOS dark surface
  static const Color darkSurface2      = Color(0xFF2C2C2E); // Elevated layer
  static const Color darkSurfaceOffset = Color(0xFF3A3A3C); // Grouped inset
  static const Color darkBorder        = Color(0xFF38383A); // iOS dark separator
  static const Color darkText          = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93); // iOS dark label secondary
  static const Color darkTextTertiary  = Color(0xFF48484A); // iOS dark label tertiary

  // ─── LEGACY STATIC ALIASES (keep for widgets that still reference them) ─
  // These point to the DARK palette so existing dark-only widgets don't break.
  static const Color primary         = iosBlueDark;
  static const Color primaryLight    = iosTealDark;
  static const Color primaryDark     = Color(0xFF0060DF);
  static const Color accent          = iosOrangeDark;
  static const Color accentLight     = Color(0xFFFFBF4D);
  static const Color background      = darkBg;
  static const Color surface         = darkSurface;
  static const Color surfaceLight    = darkSurface2;
  static const Color surfaceDark     = Color(0xFF0D0D0F);
  static const Color cardBg          = darkSurface;
  static const Color textPrimary     = darkText;
  static const Color textSecondary   = darkTextSecondary;
  static const Color success         = iosGreenDark;
  static const Color warning         = iosOrangeDark;
  static const Color error           = iosRedDark;
  static const Color info            = iosBlueDark;

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [iosBlue, iosPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBg, Color(0xFF0D0D12)],
  );

  // ═══════════════════════════════════════════════
  // LIGHT THEME — iOS White / Apple HIG inspired
  // ═══════════════════════════════════════════════
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: iosBlue,
        secondary: iosOrange,
        surface: lightSurface,
        error: iosRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
        onError: Colors.white,
        outline: lightBorder,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  const TextStyle(color: lightText,          fontWeight: FontWeight.bold,  letterSpacing: -1.5),
        displayMedium: const TextStyle(color: lightText,          fontWeight: FontWeight.bold,  letterSpacing: -0.8),
        headlineLarge: const TextStyle(color: lightText,          fontWeight: FontWeight.w700,  letterSpacing: -0.5),
        headlineMedium:const TextStyle(color: lightText,          fontWeight: FontWeight.w700),
        headlineSmall: const TextStyle(color: lightText,          fontWeight: FontWeight.w600),
        titleLarge:    const TextStyle(color: lightText,          fontWeight: FontWeight.w600),
        titleMedium:   const TextStyle(color: lightText,          fontWeight: FontWeight.w500),
        bodyLarge:     const TextStyle(color: lightText),
        bodyMedium:    const TextStyle(color: lightTextSecondary),
        bodySmall:     const TextStyle(color: lightTextTertiary),
        labelLarge:    const TextStyle(color: lightText,          fontWeight: FontWeight.w600),
        labelSmall:    const TextStyle(color: lightTextSecondary, letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: iosBlue),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: lightText,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lightBorder.withValues(alpha: 0.6)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: iosBlue,
          side: const BorderSide(color: iosBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceOffset,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightBorder.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: lightTextTertiary),
        labelStyle: const TextStyle(color: lightTextSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: iosBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightSurface2,
        contentTextStyle: const TextStyle(color: lightText, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: iosBlue,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      dividerTheme: DividerThemeData(
        color: lightBorder.withValues(alpha: 0.6),
        thickness: 0.5,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? iosGreen : lightBorder),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: iosBlue,
        textColor: lightText,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: iosBlue,
        labelColor: iosBlue,
        unselectedLabelColor: lightTextSecondary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: iosBlue),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceOffset,
        labelStyle: const TextStyle(color: lightText),
        side: BorderSide(color: lightBorder.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // DARK THEME — iOS True Black inspired
  // ═══════════════════════════════════════════════
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: iosBlueDark,
        secondary: iosOrangeDark,
        surface: darkSurface,
        error: iosRedDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
        onError: Colors.white,
        outline: darkBorder,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  const TextStyle(color: darkText,          fontWeight: FontWeight.bold,  letterSpacing: -1.5),
        displayMedium: const TextStyle(color: darkText,          fontWeight: FontWeight.bold,  letterSpacing: -0.8),
        headlineLarge: const TextStyle(color: darkText,          fontWeight: FontWeight.w700,  letterSpacing: -0.5),
        headlineMedium:const TextStyle(color: darkText,          fontWeight: FontWeight.w700),
        headlineSmall: const TextStyle(color: darkText,          fontWeight: FontWeight.w600),
        titleLarge:    const TextStyle(color: darkText,          fontWeight: FontWeight.w600),
        titleMedium:   const TextStyle(color: darkText,          fontWeight: FontWeight.w500),
        bodyLarge:     const TextStyle(color: darkText),
        bodyMedium:    const TextStyle(color: darkTextSecondary),
        bodySmall:     const TextStyle(color: darkTextTertiary),
        labelLarge:    const TextStyle(color: darkText,          fontWeight: FontWeight.w600),
        labelSmall:    const TextStyle(color: darkTextSecondary, letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: iosBlueDark),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkText,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkBorder.withValues(alpha: 0.8)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlueDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: iosBlueDark,
          side: const BorderSide(color: iosBlueDark, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlueDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlueDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: darkTextSecondary.withValues(alpha: 0.6)),
        labelStyle: const TextStyle(color: darkTextSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: iosBlueDark,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface2,
        contentTextStyle: const TextStyle(color: darkText, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkBorder.withValues(alpha: 0.6)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: iosBlueDark,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      dividerTheme: DividerThemeData(
        color: darkBorder.withValues(alpha: 0.6),
        thickness: 0.5,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? iosGreenDark : darkBorder),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: iosBlueDark,
        textColor: darkText,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: iosBlueDark,
        labelColor: iosBlueDark,
        unselectedLabelColor: darkTextSecondary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: iosBlueDark),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface2,
        labelStyle: const TextStyle(color: darkText),
        side: BorderSide(color: darkBorder.withValues(alpha: 0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: darkBorder.withValues(alpha: 0.6)),
        ),
        elevation: 16,
      ),
    );
  }

  // ─── CONTEXT HELPERS ──────────────────────────────────────
  // Use these in widgets instead of hardcoded colors.
  static bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
    isDark(context) ? darkBg : lightBg;

  static Color surfaceColor(BuildContext context) =>
    isDark(context) ? darkSurface : lightSurface;

  static Color surface2Color(BuildContext context) =>
    isDark(context) ? darkSurface2 : lightSurface2;

  static Color textColor(BuildContext context) =>
    isDark(context) ? darkText : lightText;

  static Color textMuted(BuildContext context) =>
    isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color borderColor(BuildContext context) =>
    isDark(context) ? darkBorder : lightBorder;

  static Color primaryColor(BuildContext context) =>
    isDark(context) ? iosBlueDark : iosBlue;

  static Color successColor(BuildContext context) =>
    isDark(context) ? iosGreenDark : iosGreen;

  static Color errorColor(BuildContext context) =>
    isDark(context) ? iosRedDark : iosRed;

  static Color warningColor(BuildContext context) =>
    isDark(context) ? iosOrangeDark : iosOrange;
}
