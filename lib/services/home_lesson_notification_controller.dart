import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class HomeLessonNotificationController {
  HomeLessonNotificationController({
    required this.nudgePrefsKey,
  });

  final String nudgePrefsKey;

  Timer? _syncDebounce;

  void dispose() {
    _syncDebounce?.cancel();
    _syncDebounce = null;
  }

  Future<bool> loadEnabled() {
    return NotificationService.instance.isEnabled();
  }

  void queueSync({
    required Future<void> Function() syncAction,
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _syncDebounce?.cancel();

    _syncDebounce = Timer(delay, () {
      unawaited(syncAction());
    });
  }

  Future<HomeLessonNotificationToggleResult> toggle({
    required bool currentlyEnabled,
  }) async {
    return setEnabled(!currentlyEnabled);
  }

  Future<HomeLessonNotificationToggleResult> setEnabled(bool enabled) async {
    final minutes = await NotificationService.instance.getMinutesBefore();
    final label = _minuteLabel(minutes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(nudgePrefsKey, true);

    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();

      await NotificationService.instance.setEnabled(true);

      return HomeLessonNotificationToggleResult(
        enabled: true,
        permissionGranted: granted,
        title: '$label 알림을 켰습니다',
        subtitle: granted
            ? '알림 간격은 설정에서 변경 할 수 있습니다'
            : '휴대폰 알림 권한이 꺼져 있으면 알림이 보이지 않을 수 있어요',
      );
    }

    await NotificationService.instance.setEnabled(false);
    await NotificationService.instance.cancelAll();

    return HomeLessonNotificationToggleResult(
      enabled: false,
      permissionGranted: false,
      title: '$label 알림을 껐습니다',
      subtitle: '알림 간격은 설정에서 변경 할 수 있습니다',
    );
  }

  String _minuteLabel(List<int> minutes) {
    final safe = minutes.isEmpty ? const [30] : minutes;

    if (safe.length == 1) {
      return '${safe.first}분';
    }

    return safe.map((e) => '${e}분').join(', ');
  }
}

class HomeLessonNotificationToggleResult {
  const HomeLessonNotificationToggleResult({
    required this.enabled,
    required this.permissionGranted,
    required this.title,
    required this.subtitle,
  });

  final bool enabled;
  final bool permissionGranted;
  final String title;
  final String subtitle;
}