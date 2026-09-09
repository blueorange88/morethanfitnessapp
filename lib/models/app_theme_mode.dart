enum AppThemeMode {
  light,
  dark,
  lululala,
}

AppThemeMode? appThemeModeFromRaw(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) return null;

  for (final mode in AppThemeMode.values) {
    if (mode.name == normalized) return mode;
  }
  return null;
}

AppThemeMode resolveAppThemeMode({
  required String? appThemeRaw,
  required bool? legacyDarkMode,
}) {
  final current = appThemeModeFromRaw(appThemeRaw);
  if (current != null) return current;
  if (legacyDarkMode == true) return AppThemeMode.dark;
  if (legacyDarkMode == false) return AppThemeMode.lululala;
  return AppThemeMode.light;
}
