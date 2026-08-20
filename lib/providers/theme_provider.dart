import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme_mode.dart';
import '../models/widget_theme.dart';
import '../services/mtf_home_widget_service.dart';
import '../theme.dart';

final appThemeProvider = StateNotifierProvider<AppThemeNotifier, AppThemeMode>(
  (ref) => AppThemeNotifier(),
);

WidgetThemeType widgetThemeForAppTheme(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return WidgetThemeType.brandLight;
    case AppThemeMode.dark:
      return WidgetThemeType.dark;
    case AppThemeMode.lululala:
      return WidgetThemeType.light;
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeNotifier({
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<void> Function(WidgetThemeType)? widgetThemeSync,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _widgetThemeSync =
            widgetThemeSync ?? MtfHomeWidgetService.syncWidgetTheme,
        super(AppThemeMode.light) {
    initialized = _load();
  }

  final Future<SharedPreferences> Function() _preferencesLoader;
  final Future<void> Function(WidgetThemeType) _widgetThemeSync;
  late final Future<void> initialized;

  Future<void> _load() async {
    final preferences = await _preferencesLoader();
    state = resolveAppThemeMode(
      appThemeRaw: preferences.getString(PrefKeys.appTheme),
      legacyDarkMode: preferences.getBool(PrefKeys.darkMode),
    );
    await _syncWidgetTheme(state);
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final preferences = await _preferencesLoader();
    state = mode;
    await preferences.setString(PrefKeys.appTheme, mode.name);
    await preferences.setBool(PrefKeys.darkMode, mode == AppThemeMode.dark);
    await _syncWidgetTheme(mode);
  }

  Future<void> _syncWidgetTheme(AppThemeMode mode) async {
    try {
      await _widgetThemeSync(widgetThemeForAppTheme(mode));
    } catch (_) {
      // 앱 테마 복원은 위젯 플러그인 상태와 무관하게 유지한다.
    }
  }
}
