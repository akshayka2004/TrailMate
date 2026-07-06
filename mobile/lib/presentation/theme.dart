import 'package:flutter/material.dart';

// TrailMate design tokens (dark dashboard palette, accent green).
const kPrimary = Color(0xFF0F172A);
const kSecondary = Color(0xFF1E293B);
const kAccent = Color(0xFF22C55E);
const kBackground = Color(0xFF020617);
const kForeground = Color(0xFFF8FAFC);
const kMuted = Color(0xFF334155);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    colorScheme: base.colorScheme.copyWith(
      primary: kAccent,
      secondary: kAccent,
      surface: kSecondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: kForeground,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kPrimary,
      ),
    ),
  );
}
