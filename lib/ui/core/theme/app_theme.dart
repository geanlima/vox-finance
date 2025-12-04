import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  //  CORES DO TEMA CLARO — MATERIAL YOU + MINIMAL FINANCE
  // ============================================================
  static const Color lightPrimary = Color(0xFF006E5F); // Verde petróleo
  static const Color lightPrimaryContainer = Color(0xFF00B894);
  static const Color lightSecondary = Color(0xFF006E5F);
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnPrimary = Colors.white;
  static const Color lightOnBackground = Color(0xFF1F2937);

  // ============================================================
  //  CORES DO TEMA ESCURO — FINANCE TECH NEON (Splash B)
  // ============================================================
  static const Color darkPrimary = Color(0xFF00E5FF); // Neon azul
  static const Color darkPrimaryContainer = Color(0xFF00FF9D); // Neon verde
  static const Color darkBackground = Color(0xFF050812); // Preto azulado
  static const Color darkSurface = Color(0xFF0A0F1F);
  static const Color darkOnPrimary = Colors.black;
  static const Color darkOnBackground = Colors.white;

  // ============================================================
  //  THEME DATA — M3
  // ============================================================

  // ---------------------- LIGHT ----------------------
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightSecondary,
      primaryContainer: lightPrimaryContainer,
      onPrimary: lightOnPrimary,
      surface: lightSurface,
      onSurface: lightOnBackground,
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightPrimary,
      foregroundColor: lightBackground,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lightPrimary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  // ---------------------- DARK ----------------------
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkPrimaryContainer,
      primaryContainer: darkPrimaryContainer,
      onPrimary: darkOnPrimary,
      surface: darkSurface,
      onSurface: darkOnBackground,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkOnBackground,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: darkPrimary,
      foregroundColor: Colors.black,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0D1222),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    ),
  );
}
