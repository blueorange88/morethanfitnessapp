import 'package:shared_preferences/shared_preferences.dart';

enum LessonNotificationAlertStyle {
  silent,
  vibrationOnly,
  soundAndVibration,
}

extension LessonNotificationAlertStyleLabel on LessonNotificationAlertStyle {
  String get label {
    switch (this) {
      case LessonNotificationAlertStyle.silent:
        return '무음';
      case LessonNotificationAlertStyle.vibrationOnly:
        return '진동만';
      case LessonNotificationAlertStyle.soundAndVibration:
        return '소리 + 진동';
    }
  }

  String get description {
    switch (this) {
      case LessonNotificationAlertStyle.silent:
        return '소리와 진동 없이 조용히 표시합니다.';
      case LessonNotificationAlertStyle.vibrationOnly:
        return '소리 없이 진동으로만 알려드립니다.';
      case LessonNotificationAlertStyle.soundAndVibration:
        return '소리와 진동으로 함께 알려드립니다.';
    }
  }
}

enum LessonNotificationDeviceMode {
  followDevice,
  appPreferred,
}

extension LessonNotificationDeviceModeLabel on LessonNotificationDeviceMode {
  String get label {
    switch (this) {
      case LessonNotificationDeviceMode.followDevice:
        return '휴대폰 설정 따르기';
      case LessonNotificationDeviceMode.appPreferred:
        return '앱 알림 방식 우선 요청';
    }
  }

  String get description {
    switch (this) {
      case LessonNotificationDeviceMode.followDevice:
        return '무음/진동/방해금지 등 기기 설정을 우선합니다.';
      case LessonNotificationDeviceMode.appPreferred:
        return '앱에서 선택한 방식을 우선 요청합니다. 단, 기기 설정에 따라 제한될 수 있어요.';
    }
  }
}

class LessonNotificationPrefs {
  const LessonNotificationPrefs._();

  static const String enabledKey = 'notification_lesson_enabled';

  // 기존 단일 선택 key. 마이그레이션용으로 남김.
  static const String legacyMinutesBeforeKey =
      'notification_lesson_minutes_before';

  // 신규 복수 선택 key.
  static const String reminderMinutesListKey =
      'notification_lesson_minutes_before_list';

  static const String alertStyleKey =
      'notification_lesson_alert_style';

  static const String deviceModeKey =
      'notification_lesson_device_mode';

  static const String smartAlarmEnabledKey =
      'notification_lesson_smart_alarm_enabled';

  static const String smartAlarmGapMinutesKey =
      'notification_lesson_smart_alarm_gap_minutes';

  static const String smartAlarmPriorityMemoEnabledKey =
      'notification_lesson_smart_alarm_priority_memo_enabled';

  static const String smartAlarmFirstLessonEnabledKey =
      'notification_lesson_smart_alarm_first_lesson_enabled';

  static const String smartAlarmContractBasisEnabledKey =
      'notification_lesson_smart_alarm_contract_basis_enabled';

  static const List<int> defaultReminderMinutes = [30];
  static const int defaultSmartGapMinutes = 90;

  static Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? true;
  }

  static Future<void> saveEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
  }

  static Future<List<int>> loadReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();

    final rawList = prefs.getStringList(reminderMinutesListKey);

    if (rawList != null && rawList.isNotEmpty) {
      final values = rawList
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .where((e) => e > 0)
          .toSet()
          .toList()
        ..sort();

      if (values.isNotEmpty) {
        return values;
      }
    }

    final legacy = prefs.getInt(legacyMinutesBeforeKey);

    if (legacy != null && legacy > 0) {
      await saveReminderMinutes([legacy]);
      return [legacy];
    }

    await saveReminderMinutes(defaultReminderMinutes);
    return defaultReminderMinutes;
  }

  static Future<void> saveReminderMinutes(List<int> values) async {
    final prefs = await SharedPreferences.getInstance();

    final cleaned = values
        .where((e) => e > 0)
        .toSet()
        .toList()
      ..sort();

    final safeValues = cleaned.isEmpty ? defaultReminderMinutes : cleaned;

    await prefs.setStringList(
      reminderMinutesListKey,
      safeValues.map((e) => '$e').toList(),
    );

    // 기존 코드가 아직 단일 int를 읽더라도 깨지지 않게 대표값 저장.
    await prefs.setInt(legacyMinutesBeforeKey, safeValues.first);
  }

  static Future<LessonNotificationAlertStyle> loadAlertStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(alertStyleKey);

    return LessonNotificationAlertStyle.values.firstWhere(
          (e) => e.name == raw,
      orElse: () => LessonNotificationAlertStyle.vibrationOnly,
    );
  }

  static Future<void> saveAlertStyle(
      LessonNotificationAlertStyle value,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(alertStyleKey, value.name);
  }

  static Future<LessonNotificationDeviceMode> loadDeviceMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(deviceModeKey);

    return LessonNotificationDeviceMode.values.firstWhere(
          (e) => e.name == raw,
      orElse: () => LessonNotificationDeviceMode.followDevice,
    );
  }

  static Future<void> saveDeviceMode(
      LessonNotificationDeviceMode value,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(deviceModeKey, value.name);
  }

  static Future<bool> loadSmartAlarmEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(smartAlarmEnabledKey) ?? true;
  }

  static Future<void> saveSmartAlarmEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(smartAlarmEnabledKey, value);
  }

  static Future<int> loadSmartAlarmGapMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(smartAlarmGapMinutesKey) ?? defaultSmartGapMinutes;
  }

  static Future<void> saveSmartAlarmGapMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(smartAlarmGapMinutesKey, value);
  }
  static Future<bool> loadSmartAlarmPriorityMemoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(smartAlarmPriorityMemoEnabledKey) ?? true;
  }

  static Future<void> saveSmartAlarmPriorityMemoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(smartAlarmPriorityMemoEnabledKey, value);
  }
  static Future<bool> loadSmartAlarmFirstLessonEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(smartAlarmFirstLessonEnabledKey) ?? true;
  }
  static Future<bool> loadSmartAlarmContractBasisEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(smartAlarmContractBasisEnabledKey) ?? true;
  }

  static Future<void> saveSmartAlarmContractBasisEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(smartAlarmContractBasisEnabledKey, value);
  }
  static Future<void> saveSmartAlarmFirstLessonEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(smartAlarmFirstLessonEnabledKey, value);
  }
}