import 'package:flutter/material.dart';

class AppTheme {
  // Primary orange colors
  static const Color primaryOrange = Color(0xFFFF8C00); // Deep orange
  static const Color secondaryOrange = Color(0xFFFFAB40); // Light orange
  static const Color accentOrange = Color(0xFFFF6D00); // Vivid orange

  // Supporting colors
  static const Color backgroundLight = Color(0xFFFFF8F0); // Light cream background
  static const Color backgroundDark = Color(0xFF2D2D2D); // Dark background
  static const Color textDark = Color(0xFF333333); // Dark text
  static const Color textLight = Color(0xFFF5F5F5); // Light text
  static const Color successGreen = Color(0xFF4CAF50); // Success green
  static const Color errorRed = Color(0xFFE53935); // Error red

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryOrange,
    colorScheme: ColorScheme.light(
      primary: primaryOrange,
      secondary: secondaryOrange,
      background: backgroundLight,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: textDark,
      onBackground: textDark,
      onSurface: textDark,
      error: errorRed,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: primaryOrange,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryOrange,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryOrange,
        side: const BorderSide(color: primaryOrange),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentOrange,
      foregroundColor: Colors.white,
    ),
    // カードのスタイルはCard widgetで直接設定します
    // Flutter 3.xではcardThemeの型が変更されています
    fontFamily: 'Roboto',
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    primaryColor: primaryOrange,
    colorScheme: ColorScheme.dark(
      primary: primaryOrange,
      secondary: secondaryOrange,
      background: backgroundDark,
      surface: const Color(0xFF424242),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: textLight,
      onSurface: textLight,
      error: errorRed,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: primaryOrange,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: secondaryOrange,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: secondaryOrange,
        side: const BorderSide(color: secondaryOrange),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentOrange,
      foregroundColor: Colors.white,
    ),
    // カードのスタイルはCard widgetで直接設定します
    // Flutter 3.xではcardThemeの型が変更されています
    fontFamily: 'Roboto',
  );
}
