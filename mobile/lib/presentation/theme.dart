import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// TrailMate design tokens (dark dashboard palette, accent green) — matches
// the web admin portal's design system for a consistent cross-platform feel.
const kPrimary = Color(0xFF0F172A);
const kSecondary = Color(0xFF1E293B);
const kAccent = Color(0xFF22C55E);
const kBackground = Color(0xFF020617);
const kForeground = Color(0xFFF8FAFC);
const kMuted = Color(0xFF334155);
const kDestructive = Color(0xFFEF4444);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final bodyText = GoogleFonts.firaSansTextTheme(base.textTheme).apply(
    bodyColor: kForeground,
    displayColor: kForeground,
  );
  final headingFont = GoogleFonts.firaCodeTextTheme(base.textTheme);

  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    colorScheme: base.colorScheme.copyWith(
      primary: kAccent,
      secondary: kAccent,
      surface: kSecondary,
      error: kDestructive,
    ),
    textTheme: bodyText.copyWith(
      titleLarge: headingFont.titleLarge?.copyWith(
        color: kForeground,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: headingFont.titleMedium?.copyWith(color: kForeground),
      headlineSmall: headingFont.headlineSmall?.copyWith(
        color: kForeground,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: kForeground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: headingFont.titleLarge?.copyWith(
        color: kForeground,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: kSecondary,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kMuted, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: kMuted, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSecondary,
      hintStyle: const TextStyle(color: Colors.white38),
      labelStyle: const TextStyle(color: Colors.white70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kMuted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kMuted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDestructive),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kPrimary,
        disabledBackgroundColor: kAccent.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    iconTheme: const IconThemeData(color: kForeground),
    listTileTheme: const ListTileThemeData(
      iconColor: kAccent,
      textColor: kForeground,
      minVerticalPadding: 12,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSecondary,
      contentTextStyle: const TextStyle(color: kForeground),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: kPrimary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
    dialogTheme: DialogThemeData(
      backgroundColor: kSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
