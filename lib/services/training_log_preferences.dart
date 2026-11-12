import 'package:shared_preferences/shared_preferences.dart';

/// 레슨일지 화면 설정. 기기 안(SharedPreferences)에 계정별로 저장한다.
abstract final class TrainingLogPreferences {
  static String _autoPreCheckKey(String uid) {
    final owner = uid.trim();
    return 'training_log_auto_pre_check_${owner.isEmpty ? 'local' : owner}';
  }

  /// 새 레슨일지를 만들 때 레슨 전 체크리스트를 먼저 열지 여부. 기본은 켜짐.
  static Future<bool> autoOpenPreCheck(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoPreCheckKey(uid)) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAutoOpenPreCheck(String uid, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPreCheckKey(uid), value);
    } catch (_) {
      // 저장하지 못해도 이번 화면에서는 선택한 값을 쓴다.
    }
  }
}
