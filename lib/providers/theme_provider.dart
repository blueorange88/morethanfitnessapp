import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

/// 앱 전역 다크모드 상태
final darkModeProvider =
StateNotifierProvider<DarkModeNotifier, bool>((ref) => DarkModeNotifier());

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    state = sp.getBool(PrefKeys.darkMode) ?? false;
  }

  Future<void> toggle() async {
    final sp = await SharedPreferences.getInstance();
    final next = !state;
    state = next;
    await sp.setBool(PrefKeys.darkMode, next);
  }
}
