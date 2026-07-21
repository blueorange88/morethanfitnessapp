import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_tier_access_service.dart';
import '../models/schedule_item.dart';
import 'lesson_notification_prefs.dart';
import '../aifc/core/aifc_nickname.dart';

@visibleForTesting
String buildSmartAlarmDecisionDebugMessage({
  required ScheduleItem item,
  required String decision,
  required String reason,
  int? gapMinutes,
}) {
  return 'decision=$decision '
      'reason=$reason '
      'startAt=${item.startAt.toIso8601String()} '
      'gapMinutes=${gapMinutes ?? 'none'} '
      'lessonTypePresent=${item.type.trim().isNotEmpty} '
      'memberNamePresent=${item.name.trim().isNotEmpty} '
      'memberLinked=${(item.memberId ?? '').trim().isNotEmpty}';
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _timeZoneName = 'Asia/Seoul';

  static const String _channelSilent = 'mtf_lesson_silent_v1';
  static const String _channelVibration = 'mtf_lesson_vibration_v1';
  static const String _channelSoundVibration = 'mtf_lesson_sound_vibration_v1';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZoneName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    await _createAndroidChannels();

    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSilent,
        'MORE 레슨 알림 · 무음',
        description: '소리와 진동 없이 조용히 표시되는 레슨 알림입니다.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelVibration,
        'MORE 레슨 알림 · 진동',
        description: '소리 없이 진동으로 알려주는 레슨 알림입니다.',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSoundVibration,
        'MORE 레슨 알림 · 소리와 진동',
        description: '소리와 진동으로 함께 알려주는 레슨 알림입니다.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    return androidGranted && iosGranted;
  }

  Future<bool> isEnabled() {
    return LessonNotificationPrefs.loadEnabled();
  }

  Future<void> setEnabled(bool value) async {
    await LessonNotificationPrefs.saveEnabled(value);

    if (!value) {
      await cancelLessonNotifications();
    }
  }

  Future<List<int>> getMinutesBefore() {
    return LessonNotificationPrefs.loadReminderMinutes();
  }

  Future<void> setMinutesBefore(List<int> values) {
    return LessonNotificationPrefs.saveReminderMinutes(values);
  }

  Future<void> cancelLessonNotifications() async {
    await initialize();
    await _plugin.cancelAll();
    debugPrint('[MTF_NOTIFY] cancelAll');
  }

  Future<void> cancelAll() async {
    await cancelLessonNotifications();
  }

  Future<void> syncLessonNotifications(
    List<ScheduleItem> items, {
    String? personalOwnerUid,
  }) async {
    await initialize();

    final enabled = await LessonNotificationPrefs.loadEnabled();

    if (!enabled) {
      await cancelLessonNotifications();
      return;
    }

    final reminderMinutes = await LessonNotificationPrefs.loadReminderMinutes();

    final smartEnabled = await LessonNotificationPrefs.loadSmartAlarmEnabled();

    final ownerUid = (personalOwnerUid ?? '').trim();
    final tierAccess = ownerUid.isEmpty
        ? await AppTierAccessService.loadTrainerAccess()
        : await AppTierAccessService.loadPersonalTrainerAccess(uid: ownerUid);

    final smartTierRank = tierAccess.tierRank;
    final canUseSmartAlarm = tierAccess.canUseSmartAlarm;
    final canUseSemiProSmartAlarm = tierAccess.canUseSemiProSmartAlarm;

    final effectiveSmartEnabled = smartEnabled && canUseSmartAlarm;

    if (kDebugMode) {
      debugPrint(
        '[MTF_SMART_ALARM] '
        'source=${ownerUid.isEmpty ? 'legacy' : 'personal'} '
        'tier=${tierAccess.tierLabel} '
        'rank=$smartTierRank '
        'smart=$canUseSmartAlarm '
        'semiProSmart=$canUseSemiProSmartAlarm '
        'effective=$effectiveSmartEnabled',
      );
    }

    final smartGapMinutes =
        await LessonNotificationPrefs.loadSmartAlarmGapMinutes();

    final priorityMemoEnabled =
        await LessonNotificationPrefs.loadSmartAlarmPriorityMemoEnabled();

    final firstLessonEnabled =
        await LessonNotificationPrefs.loadSmartAlarmFirstLessonEnabled();

    final alertStyle = await LessonNotificationPrefs.loadAlertStyle();
    final deviceMode = await LessonNotificationPrefs.loadDeviceMode();

    final now = DateTime.now();

    final sortedItems = items.where((item) {
      // 미래 레슨은 당연히 포함.
      if (item.startAt.isAfter(now)) return true;

      // 방금 끝났거나 현재 진행 중인 레슨도 포함.
      // 그래야 첫 미래 레슨이 연속 레슨인지 판단할 수 있어요.
      final safeEndAt = _safeEndAt(item);
      return safeEndAt.isAfter(
        now.subtract(const Duration(hours: 6)),
      );
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final futureItems =
        sortedItems.where((item) => item.startAt.isAfter(now)).toList();

    await _plugin.cancelAll();

    if (futureItems.isEmpty) {
      debugPrint('[MTF_NOTIFY] no future lessons');
      return;
    }

    final targetItems = effectiveSmartEnabled
        ? _filterSmartAlarmTargets(
            sortedItems,
            now: now,
            gapMinutes: smartGapMinutes,
            priorityMemoEnabled: priorityMemoEnabled,
            firstLessonEnabled: firstLessonEnabled,
            canUseSemiProSmartAlarm: canUseSemiProSmartAlarm,
          )
        : futureItems;

    int scheduledCount = 0;

    for (final item in targetItems) {
      for (final minute in reminderMinutes) {
        final scheduledAt = item.startAt.subtract(
          Duration(minutes: minute),
        );

        if (!scheduledAt.isAfter(now)) {
          continue;
        }

        final id = _notificationId(
          lessonStartAt: item.startAt,
          minuteBefore: minute,
        );

        await _scheduleLessonNotification(
          id: id,
          item: item,
          minuteBefore: minute,
          scheduledAt: scheduledAt,
          alertStyle: alertStyle,
          deviceMode: deviceMode,
          canUseSemiProSmartAlarm: canUseSemiProSmartAlarm,
        );

        scheduledCount++;
      }
    }

    debugPrint(
      '[MTF_NOTIFY] sync done '
      'future=${futureItems.length}, '
      'target=${targetItems.length}, '
      'minutes=$reminderMinutes, '
      'smart=$smartEnabled, '
      'gap=$smartGapMinutes, '
      'priorityMemo=$priorityMemoEnabled, '
      'firstLesson=$firstLessonEnabled, '
      'scheduled=$scheduledCount',
    );
  }

  void _debugSmartAlarmDecision({
    required ScheduleItem item,
    required String decision,
    required String reason,
    int? gapMinutes,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_SMART_ALARM] ${buildSmartAlarmDecisionDebugMessage(
        item: item,
        decision: decision,
        reason: reason,
        gapMinutes: gapMinutes,
      )}',
    );
  }

  List<ScheduleItem> _filterSmartAlarmTargets(
    List<ScheduleItem> sortedItems, {
    required DateTime now,
    required int gapMinutes,
    required bool priorityMemoEnabled,
    required bool firstLessonEnabled,
    required bool canUseSemiProSmartAlarm,
  }) {
    if (sortedItems.isEmpty) return const [];

    final futureItems =
        sortedItems.where((item) => item.startAt.isAfter(now)).toList();

    if (futureItems.isEmpty) return const [];

    final result = <ScheduleItem>[];

    for (final current in futureItems) {
      final previous = _previousLessonBefore(
        sortedItems,
        current,
      );

      final canUseAdvancedMoreCare = canUseSemiProSmartAlarm &&
          _canUseAdvancedMoreCare(
            current,
            now: now,
          );

      if (previous == null) {
        result.add(current);
        _debugSmartAlarmDecision(
          item: current,
          decision: 'include',
          reason: 'first_lesson_flow',
        );
        continue;
      }

      if (!_isSameDay(previous.startAt, current.startAt)) {
        result.add(current);
        _debugSmartAlarmDecision(
          item: current,
          decision: 'include',
          reason: 'new_day_flow',
        );
        continue;
      }

      // Semi-Pro 이상부터: 첫 레슨 / 신규회원 판단
      // 이유: 계약서 또는 레슨일지 기반 판단이 섞이기 때문에 아마추어에서는 우선순위 조건으로 쓰지 않습니다.
      if (canUseAdvancedMoreCare &&
          firstLessonEnabled &&
          _looksLikeFirstLessonOrNewMember(current)) {
        result.add(current);
        _debugSmartAlarmDecision(
          item: current,
          decision: 'include',
          reason: 'semi_pro_first_or_new_member',
        );
        continue;
      }

      // Semi-Pro 이상부터: 계약서 근거 판단
      if (canUseAdvancedMoreCare && _hasContractBasedSmartHint(current)) {
        result.add(current);
        _debugSmartAlarmDecision(
          item: current,
          decision: 'include',
          reason: 'semi_pro_contract_basis',
        );
        continue;
      }

      // Semi-Pro 이상부터: 레슨일지 메모 / 중요 메모 판단
      if (canUseAdvancedMoreCare &&
          priorityMemoEnabled &&
          _hasLessonLogSmartHint(current)) {
        result.add(current);
        _debugSmartAlarmDecision(
          item: current,
          decision: 'include',
          reason: 'semi_pro_lesson_log_hint',
        );
        continue;
      }

      if (canUseSemiProSmartAlarm &&
          !canUseAdvancedMoreCare &&
          (_looksLikeFirstLessonOrNewMember(current) ||
              _hasContractBasedSmartHint(current) ||
              _hasLessonLogSmartHint(current))) {
        _debugSmartAlarmDecision(
          item: current,
          decision: 'skip',
          reason:
              'advanced_more_care_locked_${_moreCareStatusLabelForDebug(current)}',
        );
      }

      final previousEndAt = _safeEndAt(previous);
      final gap = current.startAt.difference(previousEndAt).inMinutes;

      if (gap < gapMinutes) {
        _debugSmartAlarmDecision(
          item: current,
          decision: 'skip',
          reason: 'continuous_lesson',
          gapMinutes: gap,
        );
        continue;
      }

      result.add(current);
      _debugSmartAlarmDecision(
        item: current,
        decision: 'include',
        reason: 'enough_gap',
        gapMinutes: gap,
      );
    }

    return result;
  }

  ScheduleItem? _previousLessonBefore(
    List<ScheduleItem> sortedItems,
    ScheduleItem current,
  ) {
    ScheduleItem? previous;

    for (final item in sortedItems) {
      if (identical(item, current)) break;

      if (item.startAt.isBefore(current.startAt)) {
        previous = item;
      }
    }

    return previous;
  }

  DateTime _safeEndAt(ScheduleItem item) {
    if (item.endAt.isAfter(item.startAt)) {
      return item.endAt;
    }

    return item.startAt.add(const Duration(minutes: 50));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _canUseAdvancedMoreCare(
    ScheduleItem item, {
    DateTime? now,
  }) {
    final status = (item.moreCareStatus ?? '').trim().toLowerCase();
    final currentTime = now ?? DateTime.now();

    if (status == 'active') {
      return true;
    }

    if (status == 'temporary') {
      final until = item.moreCareTemporaryUntil;

      // 임시 사용 종료 시간이 없으면, 서비스가 임시로 열어둔 상태로 보고 허용합니다.
      if (until == null) {
        return true;
      }

      return until.isAfter(currentTime);
    }

    return false;
  }

  String _moreCareStatusLabelForDebug(ScheduleItem item) {
    final status = (item.moreCareStatus ?? '').trim();

    if (status.isEmpty) return 'none';

    return status;
  }

  bool _hasPriorityMemo(ScheduleItem item) {
    final memo = (item.memo ?? '').trim().toLowerCase();

    if (memo.isEmpty) return false;

    const keywords = [
      '통증',
      '불편',
      '부상',
      '재활',
      '상담',
      '신규',
      '첫수업',
      '첫 레슨',
      '첫레슨',
      '재등록',
      '결제',
      '미납',
      '환불',
      '측정',
      '인바디',
      '바디프로필',
      '대회',
      '식단',
      '주의',
      '체크',
    ];

    return keywords.any(memo.contains);
  }

  bool _looksLikeFirstLessonOrNewMember(ScheduleItem item) {
    final memo = (item.memo ?? '').trim().toLowerCase();

    const memoKeywords = [
      '신규',
      '첫수업',
      '첫 수업',
      '첫레슨',
      '첫 레슨',
      '첫방문',
      '첫 방문',
      '오티',
      'ot',
      'orientation',
      '상담 후 첫',
    ];

    if (memoKeywords.any(memo.contains)) {
      return true;
    }

    final total = _readIntField(item, [
      'totalSessions',
      'total',
      'sessionTotal',
    ]);

    final remaining = _readIntField(item, [
      'remainingSessions',
      'remainSessions',
      'remain',
      'sessionRemain',
    ]);

    final done = _readIntField(item, [
      'doneSessions',
      'done',
      'usedSessions',
      'sessionDone',
    ]);

    if (done != null && done == 0) {
      return true;
    }

    if (total != null && remaining != null && total > 0 && remaining >= total) {
      return true;
    }

    return false;
  }

  bool _hasContractBasedSmartHint(ScheduleItem item) {
    final contractId = _readStringField(item, [
      'contractId',
      'lastContractId',
    ]);

    final contractNo = _readStringField(item, [
      'contractNo',
      'lastContractNo',
    ]);

    final contractSigned = _readBoolField(item, [
      'contractSigned',
      'isContractSigned',
      'finalSigned',
    ]);

    final lessonSyncSource = _readStringField(item, [
      'lessonSyncSource',
      'contractLessonSyncSource',
    ]);

    final memo = (item.memo ?? '').trim().toLowerCase();

    final hasContractMarker = contractId.isNotEmpty ||
        contractNo.isNotEmpty ||
        contractSigned ||
        lessonSyncSource.contains('contract');

    if (!hasContractMarker) {
      return memo.contains('계약서') ||
          memo.contains('서명') ||
          memo.contains('건강고지') ||
          memo.contains('계약 기준');
    }

    // 계약서 근거가 있고, 첫 레슨으로 보이면 알림.
    if (_looksLikeFirstLessonOrNewMember(item)) {
      return true;
    }

    // 계약서 관련 확인 키워드가 있으면 알림.
    return memo.contains('건강고지') ||
        memo.contains('서명') ||
        memo.contains('계약서') ||
        memo.contains('계약 기준') ||
        memo.contains('환불') ||
        memo.contains('홀드') ||
        memo.contains('이용정지');
  }

  bool _hasLessonLogSmartHint(ScheduleItem item) {
    final hint = _lessonLogReminderHint(item);
    if (hint.isNotEmpty) return true;

    final keywords = _readStringListField(item, [
      'lastLessonLogKeywords',
      'lessonLogKeywords',
      'smartAlarmKeywords',
    ]);

    if (keywords.isEmpty) return false;

    const priorityKeywords = [
      '통증',
      '불편',
      '부상',
      '재활',
      '가동성',
      '어깨',
      '허리',
      '무릎',
      '목',
      '손목',
      '발목',
      '측정',
      '인바디',
      '체중',
      '식단',
      '컨디션',
      '수면',
      '피로',
      '주의',
      '체크',
      '상담',
    ];

    return keywords.any((keyword) {
      final text = keyword.trim().toLowerCase();

      return priorityKeywords.any((priority) {
        return text.contains(priority.toLowerCase());
      });
    });
  }

  String _lessonLogReminderHint(ScheduleItem item) {
    final directHint = _readStringField(item, [
      'nextLessonReminderHint',
      'lessonLogReminderHint',
      'smartAlarmHint',
    ]);

    if (directHint.isNotEmpty) {
      return directHint;
    }

    final context = _readMapField(item, [
      'smartAlarmContext',
      'lessonLogContext',
      'lastLessonLogContext',
    ]);

    final contextHint = (context['nextLessonReminderHint'] ??
            context['lessonLogReminderHint'] ??
            context['smartAlarmHint'] ??
            '')
        .toString()
        .trim();

    if (contextHint.isNotEmpty) {
      return contextHint;
    }

    final summary = (context['lastLessonLogSummary'] ??
            context['summary'] ??
            context['memoSummary'] ??
            '')
        .toString()
        .trim();

    if (_summaryLooksImportant(summary)) {
      return summary;
    }

    final directSummary = _readStringField(item, [
      'lastLessonLogSummary',
      'lessonLogSummary',
    ]);

    if (_summaryLooksImportant(directSummary)) {
      return directSummary;
    }

    return '';
  }

  bool _summaryLooksImportant(String value) {
    final text = value.trim().toLowerCase();

    if (text.isEmpty) return false;

    const keywords = [
      '통증',
      '불편',
      '부상',
      '재활',
      '주의',
      '체크',
      '상담',
      '측정',
      '인바디',
      '식단',
      '컨디션',
      '피로',
    ];

    return keywords.any((keyword) => text.contains(keyword.toLowerCase()));
  }

  String _readStringField(
    ScheduleItem item,
    List<String> fieldNames,
  ) {
    final dynamic dynamicItem = item;

    for (final fieldName in fieldNames) {
      try {
        final value = switch (fieldName) {
          'contractId' => dynamicItem.contractId,
          'lastContractId' => dynamicItem.lastContractId,
          'contractNo' => dynamicItem.contractNo,
          'lastContractNo' => dynamicItem.lastContractNo,
          'lessonSyncSource' => dynamicItem.lessonSyncSource,
          'contractLessonSyncSource' => dynamicItem.contractLessonSyncSource,
          _ => null,
        };

        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      } catch (_) {
        continue;
      }
    }

    return '';
  }

  bool _readBoolField(
    ScheduleItem item,
    List<String> fieldNames,
  ) {
    final dynamic dynamicItem = item;

    for (final fieldName in fieldNames) {
      try {
        final value = switch (fieldName) {
          'contractSigned' => dynamicItem.contractSigned,
          'isContractSigned' => dynamicItem.isContractSigned,
          'finalSigned' => dynamicItem.finalSigned,
          _ => null,
        };

        if (value is bool) return value;
        if (value is String) {
          final text = value.trim().toLowerCase();
          if (text == 'true' || text == 'yes' || text == 'y') return true;
        }
      } catch (_) {
        continue;
      }
    }

    return false;
  }

  int? _readIntField(
    ScheduleItem item,
    List<String> fieldNames,
  ) {
    final dynamic dynamicItem = item;

    for (final fieldName in fieldNames) {
      try {
        final value = switch (fieldName) {
          'totalSessions' => dynamicItem.totalSessions,
          'total' => dynamicItem.total,
          'sessionTotal' => dynamicItem.sessionTotal,
          'remainingSessions' => dynamicItem.remainingSessions,
          'remainSessions' => dynamicItem.remainSessions,
          'remain' => dynamicItem.remain,
          'sessionRemain' => dynamicItem.sessionRemain,
          'doneSessions' => dynamicItem.doneSessions,
          'done' => dynamicItem.done,
          'usedSessions' => dynamicItem.usedSessions,
          'sessionDone' => dynamicItem.sessionDone,
          _ => null,
        };

        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Map<String, dynamic> _readMapField(
    ScheduleItem item,
    List<String> fieldNames,
  ) {
    final dynamic dynamicItem = item;

    for (final fieldName in fieldNames) {
      try {
        final value = switch (fieldName) {
          'smartAlarmContext' => dynamicItem.smartAlarmContext,
          'lessonLogContext' => dynamicItem.lessonLogContext,
          'lastLessonLogContext' => dynamicItem.lastLessonLogContext,
          _ => null,
        };

        if (value is Map<String, dynamic>) {
          return value;
        }

        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      } catch (_) {
        continue;
      }
    }

    return <String, dynamic>{};
  }

  List<String> _readStringListField(
    ScheduleItem item,
    List<String> fieldNames,
  ) {
    final dynamic dynamicItem = item;

    for (final fieldName in fieldNames) {
      try {
        final value = switch (fieldName) {
          'lastLessonLogKeywords' => dynamicItem.lastLessonLogKeywords,
          'lessonLogKeywords' => dynamicItem.lessonLogKeywords,
          'smartAlarmKeywords' => dynamicItem.smartAlarmKeywords,
          _ => null,
        };

        if (value is List) {
          return value.map((e) => e.toString()).toList();
        }

        if (value is String && value.trim().isNotEmpty) {
          return value
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        continue;
      }
    }

    final context = _readMapField(item, [
      'smartAlarmContext',
      'lessonLogContext',
      'lastLessonLogContext',
    ]);

    final rawKeywords = context['lastLessonLogKeywords'] ??
        context['keywords'] ??
        context['smartAlarmKeywords'];

    if (rawKeywords is List) {
      return rawKeywords.map((e) => e.toString()).toList();
    }

    if (rawKeywords is String && rawKeywords.trim().isNotEmpty) {
      return rawKeywords
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  Future<void> _scheduleLessonNotification({
    required int id,
    required ScheduleItem item,
    required int minuteBefore,
    required DateTime scheduledAt,
    required LessonNotificationAlertStyle alertStyle,
    required LessonNotificationDeviceMode deviceMode,
    required bool canUseSemiProSmartAlarm,
  }) async {
    final title = _titleForMinute(minuteBefore);
    final body = _bodyForLesson(
      item,
      canUseSemiProSmartAlarm: canUseSemiProSmartAlarm,
    );

    final details = NotificationDetails(
      android: _androidDetails(
        alertStyle: alertStyle,
        deviceMode: deviceMode,
      ),
      iOS: _iosDetails(
        alertStyle: alertStyle,
      ),
    );

    final tzAt = tz.TZDateTime.from(scheduledAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
      '[MTF_NOTIFY] scheduled notificationIdPresent=true '
      'at=$scheduledAt '
      'lesson=${item.startAt} '
      'before=${minuteBefore}m '
      'style=${alertStyle.name} '
      'device=${deviceMode.name}',
    );
  }

  AndroidNotificationDetails _androidDetails({
    required LessonNotificationAlertStyle alertStyle,
    required LessonNotificationDeviceMode deviceMode,
  }) {
    final importance = deviceMode == LessonNotificationDeviceMode.appPreferred
        ? Importance.high
        : Importance.defaultImportance;

    final priority = deviceMode == LessonNotificationDeviceMode.appPreferred
        ? Priority.high
        : Priority.defaultPriority;

    switch (alertStyle) {
      case LessonNotificationAlertStyle.silent:
        return AndroidNotificationDetails(
          _channelSilent,
          'MORE 레슨 알림 · 무음',
          channelDescription: '소리와 진동 없이 조용히 표시되는 레슨 알림입니다.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          channelShowBadge: true,
        );

      case LessonNotificationAlertStyle.vibrationOnly:
        return AndroidNotificationDetails(
          _channelVibration,
          'MORE 레슨 알림 · 진동',
          channelDescription: '소리 없이 진동으로 알려주는 레슨 알림입니다.',
          importance: importance,
          priority: priority,
          playSound: false,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 350, 120, 350]),
          channelShowBadge: true,
        );

      case LessonNotificationAlertStyle.soundAndVibration:
        return AndroidNotificationDetails(
          _channelSoundVibration,
          'MORE 레슨 알림 · 소리와 진동',
          channelDescription: '소리와 진동으로 함께 알려주는 레슨 알림입니다.',
          importance: importance,
          priority: priority,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 350, 120, 350]),
          channelShowBadge: true,
        );
    }
  }

  DarwinNotificationDetails _iosDetails({
    required LessonNotificationAlertStyle alertStyle,
  }) {
    switch (alertStyle) {
      case LessonNotificationAlertStyle.silent:
        return const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
          presentBadge: true,
        );

      case LessonNotificationAlertStyle.vibrationOnly:
        return const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
          presentBadge: true,
        );

      case LessonNotificationAlertStyle.soundAndVibration:
        return const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        );
    }
  }

  String _titleForMinute(int minuteBefore) {
    if (minuteBefore >= 60) {
      return 'MORE 레슨 알림 · 1시간 전';
    }

    return 'MORE 레슨 알림 · $minuteBefore분 전';
  }

  String _compactNotificationText(
    String value, {
    int maxLength = 44,
  }) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.length <= maxLength) return text;

    return '${text.substring(0, maxLength)}...';
  }

  String _bodyForLesson(
    ScheduleItem item, {
    required bool canUseSemiProSmartAlarm,
  }) {
    final name = item.name.trim().isEmpty ? '회원' : item.name.trim();
    final memberLabel = aifcPersonLabel(name);
    final type = item.type.trim().isEmpty ? '레슨' : item.type.trim();

    final hh = item.startAt.hour.toString().padLeft(2, '0');
    final mm = item.startAt.minute.toString().padLeft(2, '0');

    final scheduleMemo = (item.memo ?? '').trim();

    // Semi-Pro 이상에서만 레슨일지/계약서 기반 메모를 본문에 표시합니다.
    final canUseAdvancedMoreCare =
        canUseSemiProSmartAlarm && _canUseAdvancedMoreCare(item);

    final lessonLogHint =
        canUseAdvancedMoreCare ? _lessonLogReminderHint(item).trim() : '';

    final details = <String>[];

    // 스케줄표 메모는 등급과 상관없이 표시.
    // 단, 이것만으로 스마트 알림 우선 대상이 되지는 않습니다.
    if (scheduleMemo.isNotEmpty) {
      details.add(
        '스케줄 메모: ${_compactNotificationText(scheduleMemo)}',
      );
    }

    if (lessonLogHint.isNotEmpty) {
      details.add(
        '레슨일지 메모: ${_compactNotificationText(lessonLogHint)}',
      );
    }

    if (details.isNotEmpty) {
      return '$hh:$mm $memberLabel $type 예정 · ${details.join(' · ')}';
    }

    if (canUseAdvancedMoreCare && _hasContractBasedSmartHint(item)) {
      return '$hh:$mm $memberLabel $type 예정 · 계약서 기준 내용을 확인해 주세요.';
    }

    if (canUseAdvancedMoreCare && _looksLikeFirstLessonOrNewMember(item)) {
      return '$hh:$mm $memberLabel $type 예정 · 첫 레슨/신규회원 체크가 필요해요.';
    }

    return '$hh:$mm $memberLabel $type 예정입니다.';
  }

  int _notificationId({
    required DateTime lessonStartAt,
    required int minuteBefore,
  }) {
    final base = int.parse(
      '${lessonStartAt.month.toString().padLeft(2, '0')}'
      '${lessonStartAt.day.toString().padLeft(2, '0')}'
      '${lessonStartAt.hour.toString().padLeft(2, '0')}'
      '${lessonStartAt.minute.toString().padLeft(2, '0')}',
    );

    return math.max(1, base + minuteBefore);
  }
}
