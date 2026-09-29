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

// Light-mode counterparts of the tokens above — same accent, inverted
// surfaces, kept AA-contrast against kAccent per the dark palette's ratios.
const kLightPrimary = Color(0xFFFFFFFF);
const kLightSecondary = Color(0xFFF1F5F9);
const kLightBackground = Color(0xFFFFFFFF);
const kLightForeground = Color(0xFF0F172A);
const kLightMuted = Color(0xFFCBD5E1);

/// Semantic colors that flip between light/dark — widgets read these via
/// `context.palette` instead of hardcoding a dark-only constant, so the
/// light/dark toggle actually repaints every screen.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface,
    required this.divider,
    required this.onAccent,
    required this.textPrimary,
    required this.textSoft,
    required this.textMuted,
    required this.textFaint,
  });

  final Color surface;
  final Color divider;
  final Color onAccent;
  final Color textPrimary;
  final Color textSoft;
  final Color textMuted;
  final Color textFaint;

  static const dark = AppPalette(
    surface: kSecondary,
    divider: kMuted,
    onAccent: kPrimary,
    textPrimary: kForeground,
    textSoft: Colors.white70,
    textMuted: Colors.white54,
    textFaint: Colors.white38,
  );

  static const light = AppPalette(
    surface: kLightSecondary,
    divider: kLightMuted,
    onAccent: kLightPrimary,
    textPrimary: kLightForeground,
    textSoft: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
  );

  @override
  AppPalette copyWith({
    Color? surface,
    Color? divider,
    Color? onAccent,
    Color? textPrimary,
    Color? textSoft,
    Color? textMuted,
    Color? textFaint,
  }) {
    return AppPalette(
      surface: surface ?? this.surface,
      divider: divider ?? this.divider,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSoft: textSoft ?? this.textSoft,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

ThemeData buildTheme([Brightness brightness = Brightness.dark]) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppPalette.dark : AppPalette.light;
  final background = isDark ? kBackground : kLightBackground;
  final surface = isDark ? kSecondary : kLightSecondary;
  final divider = isDark ? kMuted : kLightMuted;
  final fg = isDark ? kForeground : kLightForeground;
  final appBarBg = isDark ? kPrimary : kLightPrimary;

  final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final bodyText = GoogleFonts.firaSansTextTheme(base.textTheme).apply(
    bodyColor: fg,
    displayColor: fg,
  );
  final headingFont = GoogleFonts.firaCodeTextTheme(base.textTheme);

  return base.copyWith(
    scaffoldBackgroundColor: background,
    colorScheme: base.colorScheme.copyWith(
      brightness: brightness,
      primary: kAccent,
      secondary: kAccent,
      surface: surface,
      error: kDestructive,
    ),
    extensions: [palette],
    textTheme: bodyText.copyWith(
      titleLarge: headingFont.titleLarge?.copyWith(
        color: fg,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: headingFont.titleMedium?.copyWith(color: fg),
      headlineSmall: headingFont.headlineSmall?.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: fg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: headingFont.titleLarge?.copyWith(
        color: fg,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: divider, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: palette.textFaint),
      labelStyle: TextStyle(color: palette.textSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: divider),
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
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: kAccent.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    iconTheme: IconThemeData(color: fg),
    listTileTheme: ListTileThemeData(
      iconColor: kAccent,
      textColor: fg,
      minVerticalPadding: 12,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: TextStyle(color: fg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: palette.onAccent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
