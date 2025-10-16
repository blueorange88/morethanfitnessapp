import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0D1B2A);
  static const gold = Color(0xFFD4AF37);
  static const offWhite = Color(0xFFF5F0E8);
}

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
    primary: AppColors.navy,
    secondary: AppColors.gold,
    background: AppColors.offWhite,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.background,
      foregroundColor: scheme.primary,
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.primary.withOpacity(0.5),
      type: BottomNavigationBarType.fixed,
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.dark,
    primary: AppColors.gold,
    secondary: AppColors.gold,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );
}

class PrefKeys {
  static const darkMode = 'pref_dark_mode';
}
