// lib/pages/home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';
import '../services/mtf_home_widget_service.dart';
import '../services/mtf_next_lesson_widget_sync.dart';

import 'client_card_page.dart';
import 'personal_training_log_page.dart';
import 'stats_page.dart';
import 'binder_card_page.dart'; // ✅ 추가
import 'client_list_page.dart';
import 'settings_page.dart';
import 'test_hub_pages.dart';
import 'my_page.dart';
import 'personal_training_log_quick_sign_page.dart';



/// ----------------------
/// 공통 컬러 팔레트 (홈 기준)
/// ----------------------
const Color kPrimaryColor = Color(0xFF4F46E5); // 홈 그라데이션 시작
const Color kPrimaryColor2 = Color(0xFF9333EA); // 홈 그라데이션 끝
const Color kAccentAmber = Color(0xFFFBBF24);
const Color kAccentOrange = Color(0xFFF97316);
const Color kBgColor = Color(0xFFF3F4F6); // 전체 배경 톤
const double kMaxContentWidth = 480;

const double kScheduleRowHeight = 40.0;
const double kScheduleHeaderCellHeight = 34.0;

// ── 홈 스케줄러 라이트 디자인 ─────────────────────────
const Color kScheduleLightBg = Color(0xFFFFFFFF);
const Color kScheduleRowEven = Color(0xFFEFF6FF);
const Color kScheduleRowOdd = Color(0xFFFFFFFF);

const Color kScheduleTimeColTop = Color(0xFFFFFFFF);
const Color kScheduleTimeColMid = Color(0xFFF8FAFC);
const Color kScheduleTimeColBottom = Color(0xFFEFF6FF);

const Color kScheduleGridLine = Color(0xFFE5E7EB);
const Color kScheduleTimeColLine = Color(0xFFD1D5DB);
const Color kScheduleTimeText = Color(0xFF475569);

const Color kScheduleTodayHeader = Color(0xFFFBBF24);
const Color kScheduleTodayHeaderDeep = Color(0xFFF59E0B);
const Color kScheduleTodayEven = Color(0x33FBBF24);
const Color kScheduleTodayOdd = Color(0x22FBBF24);
const Color kScheduleCurrentLine = Color(0xFFE11D48);

const String kMemberSignBaseUrl = 'https://more-than-fitness-f6adb.web.app/sign';

enum HomeAction {
  quickSchedule,
  quickMember,
  notifications,
  settings,
  expiringMembers,
}

// 빠른 등록용 enum & 결과 클래스
enum _QuickRegAction { fastSave, goDetail }

class _QuickRegResult {
  final _QuickRegAction action;
  final String name;
  final String phone;
  final DateTime visitDate;
  final DateTime? consultDate;

  const _QuickRegResult({
    required this.action,
    required this.name,
    required this.phone,
    required this.visitDate,
    required this.consultDate,
  });
}

class _LessonSaveResult {
  final bool success;
  final bool isLinkedMember;

  const _LessonSaveResult({
    required this.success,
    required this.isLinkedMember,
  });

  const _LessonSaveResult.failed()
      : success = false,
        isLinkedMember = false;
}

class ScheduleItem {
  final String docId;
  final DateTime startAt;
  final DateTime endAt;
  final String day;
  final String time;
  final String endTime;
  final String name;
  final String type;
  final bool attended;
  final String? memberId;
  final String? phone;
  final String? attendanceOverride;
  final String? totalSessions;
  final String? remainingSessions;
  final String? memo;
  final String? typeId;
  final String? typeColorHex;

  const ScheduleItem({
    required this.docId,
    required this.startAt,
    required this.endAt,
    required this.day,
    required this.time,
    required this.endTime,
    required this.name,
    required this.type,
    required this.attended,
    this.memberId,
    this.phone,
    this.attendanceOverride,
    this.totalSessions,
    this.remainingSessions,
    this.memo,
    this.typeId,
    this.typeColorHex,
  });

  ScheduleItem copyWith({
    String? docId,
    DateTime? startAt,
    DateTime? endAt,
    String? day,
    String? time,
    String? endTime,
    String? name,
    String? type,
    bool? attended,
    String? memberId,
    String? phone,
    String? attendanceOverride,
    String? totalSessions,
    String? remainingSessions,
    String? typeId,
    String? typeColorHex,
  }) {
    return ScheduleItem(
      docId: docId ?? this.docId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      day: day ?? this.day,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      name: name ?? this.name,
      type: type ?? this.type,
      attended: attended ?? this.attended,
      memberId: memberId ?? this.memberId,
      phone: phone ?? this.phone,
      attendanceOverride: attendanceOverride ?? this.attendanceOverride,
      totalSessions: totalSessions ?? this.totalSessions,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      memo: memo ?? this.memo,
      typeId: typeId ?? this.typeId,
      typeColorHex: typeColorHex ?? this.typeColorHex,
    );
  }



  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'startAt': startAt,
      'endAt': endAt,
      'day': day,
      'time': time,
      'endTime': endTime,
      'name': name,
      'type': type,
      'attended': attended,
      if (memberId != null && memberId!.isNotEmpty) 'memberId': memberId,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (attendanceOverride != null) 'attendanceOverride': attendanceOverride,
      if (totalSessions != null) 'totalSessions': totalSessions,
      if (remainingSessions != null) 'remainingSessions': remainingSessions,
      if (memo != null && memo!.isNotEmpty) 'memo' : memo,
      if (typeId != null && typeId!.isNotEmpty) 'typeId': typeId,
      if (typeColorHex != null && typeColorHex!.isNotEmpty) 'typeColorHex': typeColorHex,
    };
  }

  static ScheduleItem? fromMap(
      Map<String, dynamic> raw, {
        required int defaultDurationMinutes,
      }) {
    final rawStartAt = raw['startAt'];
    if (rawStartAt is! DateTime) return null;

    final rawEndAt = raw['endAt'];
    final endAt = rawEndAt is DateTime
        ? rawEndAt
        : rawStartAt.add(Duration(minutes: defaultDurationMinutes));

    final day = (raw['day'] ?? '').toString().trim().isNotEmpty
        ? (raw['day'] ?? '').toString()
        : const ['월', '화', '수', '목', '금', '토', '일'][rawStartAt.weekday - 1];

    final time = (raw['time'] ?? '').toString().trim().isNotEmpty
        ? (raw['time'] ?? '').toString()
        : '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}';

    final endTime = (raw['endTime'] ?? '').toString().trim().isNotEmpty
        ? (raw['endTime'] ?? '').toString()
        : '${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';

    return ScheduleItem(
      docId: (raw['docId'] ?? '').toString(),
      startAt: rawStartAt,
      endAt: endAt,
      day: day,
      time: time,
      endTime: endTime,
      name: (raw['name'] ?? '').toString(),
      type: (raw['type'] ?? 'PT수업').toString(),
      attended: raw['attended'] == true,
      memberId: raw['memberId']?.toString(),
      phone: raw['phone']?.toString(),
      attendanceOverride: raw['attendanceOverride']?.toString(),
      totalSessions: raw['totalSessions']?.toString(),
      remainingSessions: raw['remainingSessions']?.toString(),
      memo: raw[ 'memo']?.toString(),
      typeId: raw['typeId']?.toString(),
      typeColorHex: raw['typeColorHex']?.toString(),
    );
  }
}

const List<String> kSeedLessonTypeNames = [
  'PT수업',
  '필라테스',
  '그룹수업',
  'OT상담',
];

const List<Color> kLessonTypePalette = [
  Color(0xFF4F46E5), // indigo
  Color(0xFF7C3AED), // purple
  Color(0xFFF97316), // orange
  Color(0xFF0F766E), // teal
  Color(0xFFDB2777), // pink
  Color(0xFF2563EB), // blue
];

class LessonTypeItem {
  final String id;
  final String name;
  final String colorHex;

  const LessonTypeItem({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  LessonTypeItem copyWith({
    String? id,
    String? name,
    String? colorHex,
  }) {
    return LessonTypeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorHex': colorHex,
  };

  factory LessonTypeItem.fromMap(Map<String, dynamic> map) {
    return LessonTypeItem(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      colorHex: (map['colorHex'] ?? '#4F46E5').toString(),
    );
  }
}

class WidgetScheduleBlock {
  final String day;
  final double topRatio;
  final double heightRatio;
  final int columnIndex;
  final int totalColumns;
  final String label;
  final String type;
  final String colorHex;

  const WidgetScheduleBlock({
    required this.day,
    required this.topRatio,
    required this.heightRatio,
    required this.columnIndex,
    required this.totalColumns,
    required this.label,
    required this.type,
    required this.colorHex,
  });

  String encode() {
    return [
      day,
      topRatio.toStringAsFixed(6),
      heightRatio.toStringAsFixed(6),
      columnIndex.toString(),
      totalColumns.toString(),
      label.replaceAll('|', '/'),
      type.replaceAll('|', '/'),
      colorHex,
    ].join('|');
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isHeaderExpanded = false;

  /// 0=고객리스트, 1=수업일지, 2=통계, 3=홈
  int activeTab = 3; // 기본: 홈 탭 (현재는 UI에서 직접 쓰진 않음)

  String dayFilter = "all";

  int startHour = 6;
  int endHour = 22;
  int defaultMinute = 0;
  final Map<int, int> _timeRowMinutes = {};

  late DateTime currentTime;
  Timer? _timer;

  /// 내부 저장용 수업일정 데이터
  /// 키 형식: "weekOffset-요일-시간"  예) "0-월-09:00"
  /// - weekOffset:  0 = 이번 주,  -1(지난 주), 1(다음 주)
  final Map<String, dynamic> scheduleData = {};

  bool _notificationsOn = true;
  bool _showScheduleHelp = false;

  /// "이번 주 수업일정 사용법" 안내 토글
  bool _hideScheduleExamples = false;

  /// 주간 수업일정 슬라이드
  int _weekPageIndex = _todayWeekIndex; // 처음엔 "이번 주"

  // PageView 컨트롤러 (처음 페이지를 이번 주로)
  late final PageController _weekPageController =
  PageController(initialPage: _todayWeekIndex);

  /// 빠른 등록 중 중복 요청 방지
  bool _isSubmitting = false;
  String _lastSelectedLessonTypeId = '';
  List<LessonTypeItem> _lessonTypes = [];
  static const int _defaultLessonDurationMinutes = 50;

  int _preferredLessonDurationMinutes = _defaultLessonDurationMinutes;



  List<Map<String, dynamic>> _copiedWeekSchedules = [];
  String? _copiedWeekSourceLabel;

  final List<String> _headerNoticeMessages = const [
    '오늘 확인하면 좋은 일정들이 있어요!',
    '지금 보면 딱 좋은 일정이 기다리고 있어요!',
    '오늘 수업일정 먼저 살짝 체크해볼까요?',
    '놓치기 전에 확인하면 좋은 일정이 있어요!',
    '오늘 챙기면 좋은 소식들이 준비되어 있어요!',
  ];

  final math.Random _headerNoticeRandom = math.Random();
  late String _currentHeaderNotice;
  DateTime? _streamAnchorMonday;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _scheduleSub;

  @override
  void initState() {
    super.initState();
    currentTime = DateTime.now();
    _ensureTimeRowMinutes();
    unawaited(_loadScheduleViewPrefs());
    unawaited(_loadScheduleExamplePrefs());
    _bindScheduleStream();
    _pickInitialHeaderNotice();
    unawaited(_loadLessonTypePrefs());
    unawaited(_syncHomeWidgetPreview());

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;

      setState(() {
        currentTime = DateTime.now();
      });

      _rebindScheduleStreamIfNeeded();
      unawaited(_syncHomeWidgetPreview());
    });
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    _weekPageController.dispose();
    _timer?.cancel();
    _hideActionToast();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').substring(2);
    return '#${hex.toUpperCase()}';
  }

  Color _colorFromHex(String hex) {
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) {
      value = 'FF$value';
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return kPrimaryColor;
    return Color(parsed);
  }

  Color _sessionColor(Map<String, dynamic>? session) {
    final colorHex = session?['typeColorHex']?.toString();
    if (colorHex != null && colorHex.isNotEmpty) {
      return _colorFromHex(colorHex);
    }

    final String type = session?['type']?.toString() ?? '';

    switch (type) {
      case 'PT':
      case '수업':
      case 'PT수업':
        return kPrimaryColor;
      case '재활수업':
        return const Color(0xFF2563EB);
      case '필라테스':
        return const Color(0xFF7C3AED);
      case '요가':
        return const Color(0xFF0F766E);
      case '그룹':
      case '그룹수업':
        return kAccentOrange;
      case '줌바':
        return const Color(0xFFDB2777);
      case '상담':
      case 'OT상담':
        return kAccentAmber;
      case 'OT':
        return const Color(0xFF22C55E);
      default:
        return kPrimaryColor;
    }
  }

  String _generateLessonTypeId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Color _nextSeedColor(int index) {
    return kLessonTypePalette[index % kLessonTypePalette.length];
  }

  List<LessonTypeItem> _buildSeedLessonTypes() {
    return List<LessonTypeItem>.generate(
      kSeedLessonTypeNames.length,
          (index) => LessonTypeItem(
        id: 'seed_$index',
        name: kSeedLessonTypeNames[index],
        colorHex: _colorToHex(_nextSeedColor(index)),
      ),
    );
  }

  Future<void> _loadLessonTypePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('home_lesson_types_v3');
    final lastId = prefs.getString('home_last_lesson_type_id') ?? '';

    List<LessonTypeItem> nextItems = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          nextItems = decoded
              .whereType<Map>()
              .map(
                (e) => LessonTypeItem.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
              .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    if (nextItems.isEmpty) {
      nextItems = _buildSeedLessonTypes();
      await prefs.setString(
        'home_lesson_types_v3',
        jsonEncode(nextItems.map((e) => e.toMap()).toList()),
      );
    }

    final safeLastId =
    nextItems.any((e) => e.id == lastId) ? lastId : nextItems.first.id;

    if (!mounted) return;

    setState(() {
      _lessonTypes = nextItems;
      _lastSelectedLessonTypeId = safeLastId;
    });
  }

  Future<void> _saveLessonTypePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'home_lesson_types_v3',
      jsonEncode(_lessonTypes.map((e) => e.toMap()).toList()),
    );
    await prefs.setString(
      'home_last_lesson_type_id',
      _lastSelectedLessonTypeId,
    );
  }

  Future<void> _loadScheduleViewPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final savedStartHour = prefs.getInt('home_start_hour');
    final savedEndHour = prefs.getInt('home_end_hour');
    final savedDefaultMinute = prefs.getInt('home_default_minute');

    final rawRowMinutes = prefs.getString('home_time_row_minutes_v1');

    if (!mounted) return;

    setState(() {
      if (savedStartHour != null) startHour = savedStartHour;
      if (savedEndHour != null) endHour = savedEndHour;
      if (savedDefaultMinute != null) defaultMinute = savedDefaultMinute;

      _timeRowMinutes.clear();

      if (rawRowMinutes != null && rawRowMinutes.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawRowMinutes) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            final hour = int.tryParse(key);
            final minute = int.tryParse(value.toString());
            if (hour != null && minute != null) {
              _timeRowMinutes[hour] = minute;
            }
          });
        } catch (_) {}
      }

      _ensureTimeRowMinutes();
    });
  }

  Future<void> _saveScheduleViewPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('home_start_hour', startHour);
    await prefs.setInt('home_end_hour', endHour);
    await prefs.setInt('home_default_minute', defaultMinute);

    final map = <String, int>{};
    _timeRowMinutes.forEach((key, value) {
      map[key.toString()] = value;
    });

    await prefs.setString('home_time_row_minutes_v1', jsonEncode(map));
  }

  Future<void> _loadScheduleExamplePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getBool('home_hide_schedule_examples_v1') ?? false;

    if (!mounted) return;

    setState(() {
      _hideScheduleExamples = hidden;
    });
  }

  Future<void> _hideScheduleExamplesForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_hide_schedule_examples_v1', true);

    if (!mounted) return;

    setState(() {
      _hideScheduleExamples = true;
    });

    _showActionToast(context, '예시 수업을 숨겼어요.');
  }

  bool _shouldShowScheduleExamples(int weekOffset) {
    if (_hideScheduleExamples) return false;
    if (weekOffset != 0) return false;

    // 실제 수업이 3개 이상 등록되면 예시는 자연스럽게 사라집니다.
    return _allScheduleItems().length < 3;
  }

  void _showScheduleExampleInfo() {
    _showActionToast(
      context,
      '예시용 수업입니다. 실제 데이터에는 저장되지 않아요.',
      bottomOffset: 110,
    );
  }

  LessonTypeItem? _findLessonTypeById(String id, List<LessonTypeItem> items) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  LessonTypeItem? _findLessonTypeByName(String name, List<LessonTypeItem> items) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }

  Color _legacyLessonTypeColor(String type) {
    switch (type) {
      case 'PT':
      case '수업':
      case 'PT수업':
        return kPrimaryColor;
      case '필라테스':
        return const Color(0xFF7C3AED);
      case '그룹':
      case '그룹수업':
        return kAccentOrange;
      case '요가':
        return const Color(0xFF0F766E);
      case 'OT상담':
      case '상담':
        return const Color(0xFF2563EB);
      default:
        return kPrimaryColor;
    }
  }

  String _lessonTypeColorHexByName(String type) {
    final item = _findLessonTypeByName(type, _lessonTypes);
    if (item != null) return item.colorHex;
    return _colorToHex(_legacyLessonTypeColor(type));
  }

  LessonTypeItem _resolveLessonTypeForSchedule(Map<String, dynamic>? session) {
    final typeId = session?['typeId']?.toString() ?? '';
    final typeName = (session?['typeName'] ?? session?['type'] ?? 'PT수업').toString();
    final typeColorHex = session?['typeColorHex']?.toString();

    final byId = typeId.isNotEmpty ? _findLessonTypeById(typeId, _lessonTypes) : null;
    if (byId != null) return byId;

    final byName = _findLessonTypeByName(typeName, _lessonTypes);
    if (byName != null) return byName;

    return LessonTypeItem(
      id: _generateLessonTypeId(),
      name: typeName,
      colorHex: typeColorHex?.isNotEmpty == true
          ? typeColorHex!
          : _colorToHex(_legacyLessonTypeColor(typeName)),
    );
  }

  void _rebindScheduleStreamIfNeeded() {
    final nextAnchor = _mondayOfWeek(currentTime);
    final prevAnchor = _streamAnchorMonday;

    if (prevAnchor == null ||
        prevAnchor.year != nextAnchor.year ||
        prevAnchor.month != nextAnchor.month ||
        prevAnchor.day != nextAnchor.day) {
      _bindScheduleStream();
    }
  }



  void _bindScheduleStream() {
    _scheduleSub?.cancel();

    final anchorMonday = _mondayOfWeek(currentTime);
    _streamAnchorMonday = anchorMonday;

    final start = anchorMonday.add(Duration(days: _minWeekOffset * 7));
    final endExclusive =
    anchorMonday.add(Duration(days: (_maxWeekOffset + 1) * 7));

    _scheduleSub = FirebaseFirestore.instance
        .collection('schedules')
        .where(
      'startAt',
      isGreaterThanOrEqualTo: Timestamp.fromDate(start),
    )
        .where(
      'startAt',
      isLessThan: Timestamp.fromDate(endExclusive),
    )
        .snapshots()
        .listen((snapshot) {
      final next = <String, dynamic>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ts = data['startAt'];
        if (ts is! Timestamp) continue;

        final dt = ts.toDate();
        final key = _makeKey(
          ((_mondayOfWeek(dt)
              .difference(anchorMonday)
              .inDays) / 7).round(),
          _weekDaysAll[dt.weekday - 1],
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(
              2, '0')}',
        );

        DateTime? endDt;
        final endTs = data['endAt'];
        if (endTs is Timestamp) {
          endDt = endTs.toDate();
        }

        next[key] = {
          'docId': doc.id,
          'startAt': dt,
          'name': (data['name'] ?? '').toString(),
          'type': (data['type'] ?? 'PT수업').toString(),
          if (data['typeName'] != null) 'typeName': data['typeName'].toString(),
          if (data['typeId'] != null) 'typeId': data['typeId'].toString(),
          if (data['typeColorHex'] != null)
            'typeColorHex': data['typeColorHex'].toString(),
          'attended': data['attended'] == true,
          'endAt': endDt ?? dt.add(Duration(minutes: _defaultLessonDurationMinutes)),
          'endTime': (data['endTime'] ?? '').toString(),
          if (data['attendanceOverride'] != null)
            'attendanceOverride': data['attendanceOverride'],
          if (data['totalSessions'] != null)
            'totalSessions': data['totalSessions'].toString(),
          if (data['remainingSessions'] != null)
            'remainingSessions': data['remainingSessions'].toString(),
          if (data['memberId'] != null) 'memberId': data['memberId'],
          if (data['phone'] != null) 'phone': data['phone'],
          if (data['memo'] != null) 'memo': data['memo'].toString(),
        };
      }

      if (!mounted) return;

      final shouldUpdate = !mapEquals(scheduleData, next);
      if (!shouldUpdate) return;

      setState(() {
        scheduleData
          ..clear()
          ..addAll(next);
      });

      unawaited(_refreshScheduleCountsFromMembers());
      unawaited(_syncHomeWidgetPreview());
    });
  }

  void _pickInitialHeaderNotice() {
    _currentHeaderNotice = _headerNoticeMessages[
    _headerNoticeRandom.nextInt(_headerNoticeMessages.length)];
  }

  void _refreshHeaderOnEntry() {
    _rotateHeaderNotice();
  }

  void _rotateHeaderNotice() {
    if (_headerNoticeMessages.length <= 1) return;

    String next = _currentHeaderNotice;
    while (next == _currentHeaderNotice) {
      next = _headerNoticeMessages[
      _headerNoticeRandom.nextInt(_headerNoticeMessages.length)];
    }

    if (!mounted) return;
    setState(() {
      _currentHeaderNotice = next;
    });
  }


  // -------- 주간 수업일정 범위 관련 상수 --------
  // 이번 주 기준으로 뒤로 4주, 앞으로 4주
  static const int _minWeekOffset = -4;
  static const int _maxWeekOffset = 4;

  // 전체 페이지 수 = -4 ~ +4 → 9
  static const int _totalWeeks = _maxWeekOffset - _minWeekOffset + 1; // 9

  // index(0~8) 중에서 "이번 주"가 되는 인덱스
  // offset = 0 이 되게 하려면  index + _minWeekOffset = 0
  // → index = -_minWeekOffset
  static const int _todayWeekIndex = -_minWeekOffset; // 4

  // ---------- 공통 유틸 ----------
  String _trainerHeaderNameFromData(Map<String, dynamic>? data) {
    final displayName = (data?['displayName'] ?? '').toString().trim();
    final name = (data?['name'] ?? '').toString().trim();

    final value = displayName.isNotEmpty ? displayName : name;
    return value.isEmpty ? '트레이너' : value;
  }

  String _trainerShortNameFromData(Map<String, dynamic>? data) {
    final savedShortName = (data?['shortName'] ?? '').toString().trim();
    if (savedShortName.isNotEmpty) return savedShortName;

    final headerName = _trainerHeaderNameFromData(data);
    return _buildTrainerShortName(headerName);
  }

  String _buildTrainerShortName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '트';

    final normalized = text.endsWith('트레이너')
        ? text.replaceAll('트레이너', '').trim()
        : text;

    if (normalized.isEmpty) {
      return text.length <= 2 ? text : text.substring(0, 2);
    }

    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }
  /// PageView index(0~8) → weekOffset(-4~4) 변환
  int _indexToOffset(int index) {
    return _minWeekOffset + index;
  }

  DateTime _mondayOfWeek(DateTime base) {
    return DateTime(base.year, base.month, base.day)
        .subtract(Duration(days: base.weekday - 1));
  }

  DateTime _dateForCell(int weekOffset, String day, String time) {
    final dayIndex = _weekDaysAll.indexOf(day);
    final monday =
    _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final date = monday.add(Duration(days: dayIndex));

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _makeKey(int weekOffset, String day, String time) {
    final dt = _dateForCell(weekOffset, day, time);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d-$h:$min';
  }

  String _sessionAttendanceLabel(String day,
      String time,
      int weekOffset,
      Map<String, dynamic> session,) {
    final override = session["attendanceOverride"]?.toString();

    switch (override) {
      case "no_show_deducted":
        return "노쇼(차감)";
      case "no_show_not_deducted":
        return "노쇼(미차감)";
      case "attendance_cancelled":
        return "출석취소";
    }

    final startAt = _dateForCell(weekOffset, day, time);
    DateTime endAt;
    final rawEndAt = session['endAt'];

    if (rawEndAt is DateTime) {
      endAt = rawEndAt;
    } else {
      endAt = startAt.add(Duration(minutes: _defaultLessonDurationMinutes),
      );
    }

    if (currentTime.isBefore(startAt)) {
      return "수업예정";
    }

    if (currentTime.isBefore(endAt)) {
      return "수업중";
    }

    return "수업완료";
  }

  bool _hasLinkedMemberConnection({
    String? memberId,
    String? phone,
  }) {
    final cleanMemberId = memberId?.trim() ?? '';

    // 회원카드/수업일지 이동은 memberId가 있을 때만 연결된 회원으로 봅니다.
    // phone이나 이름만으로 연결 판단하면 동명이인/예전 데이터에서 잘못 열릴 수 있어요.
    return cleanMemberId.isNotEmpty;
  }

  bool _isManualScheduleMember(Map<String, dynamic>? session) {
    if (session == null) return false;

    final memberId = (session['memberId'] ?? '').toString().trim();
    final phone = _normalizePhone((session['phone'] ?? '').toString());

    return memberId.isEmpty && phone.isEmpty;
  }



  Color _lessonStatusChipTextColor(String label) {
    switch (label) {
      case '수업예정':
        return Colors.grey.shade700;
      case '수업중':
        return const Color(0xFF2563EB);
      case '수업완료':
        return const Color(0xFF16A34A);
      case '노쇼(차감)':
        return const Color(0xFFDC2626);
      case '노쇼(미차감)':
        return const Color(0xFFF97316);
      case '출석취소':
        return Colors.blueGrey;
      default:
        return kPrimaryColor;
    }
  }

  Color _lessonStatusChipBackgroundColor(String label) {
    switch (label) {
      case '수업예정':
        return Colors.grey.shade100;
      case '수업중':
        return const Color(0xFFDBEAFE);
      case '수업완료':
        return const Color(0xFFDCFCE7);
      case '노쇼(차감)':
        return const Color(0xFFFEE2E2);
      case '노쇼(미차감)':
        return const Color(0xFFFFEDD5);
      case '출석취소':
        return const Color(0xFFE2E8F0);
      default:
        return kPrimaryColor.withOpacity(0.08);
    }
  }

  Color _statusChipBgColor(String label) {
    switch (label) {
      case '수업예정':
        return Colors.white.withOpacity(0.15);
      case '수업중':
        return const Color(0xFF2563EB).withOpacity(0.35);
      case '수업완료':
        return const Color(0xFF16A34A).withOpacity(0.30);
      case '노쇼(차감)':
        return const Color(0xFFDC2626).withOpacity(0.30);
      case '노쇼(미차감)':
        return const Color(0xFFF97316).withOpacity(0.30);
      case '출석취소':
        return Colors.white.withOpacity(0.12);
      default:
        return Colors.white.withOpacity(0.15);
    }
  }

  Color _statusChipTextColor(String label) {
    switch (label) {
      case '수업중':
        return const Color(0xFF93C5FD);
      case '수업완료':
        return const Color(0xFF86EFAC);
      case '노쇼(차감)':
        return const Color(0xFFFCA5A5);
      case '노쇼(미차감)':
        return const Color(0xFFFDBA74);
      case '출석취소':
        return Colors.white.withOpacity(0.65);
      default:
        return Colors.white.withOpacity(0.85);
    }
  }

  bool _canOpenAttendanceStatusSheet(String day,
      String time,
      int weekOffset,) {
    final startAt = _dateForCell(weekOffset, day, time);
    return !currentTime.isBefore(startAt);
  }

  Future<void> _setAttendanceOverride({
    required String docId,
    String? overrideValue,
  }) async {
    await FirebaseFirestore.instance.collection('schedules').doc(docId).set({
      if (overrideValue == null)
        'attendanceOverride': FieldValue.delete()
      else
        'attendanceOverride': overrideValue,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      unawaited(_syncHomeWidgetPreview());
    }
  }

  Future<String?> _openAttendanceStatusSheet(String day,
      String time,
      int weekOffset,
      Map<String, dynamic> session,) async {
    if (!_canOpenAttendanceStatusSheet(day, time, weekOffset)) {
      _showSnack('수업 시작 후부터 출석 상태를 변경할 수 있어요.');
      return null;
    }

    final currentLabel = _sessionAttendanceLabel(
        day, time, weekOffset, session);
    final docId = session['docId']?.toString().trim() ?? '';

    if (docId.isEmpty) {
      _showSnack('연결된 일정 문서를 찾지 못했어요.');
      return null;
    }


    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '출석 상태 변경',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '현재 상태: $currentLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_off_outlined,
                    color: Colors.red,
                  ),
                  title: const Text('노쇼(차감)'),
                  onTap: () async {
                    await _setAttendanceOverride(
                      docId: docId,
                      overrideValue: 'no_show_deducted',
                    );
                    Navigator.of(sheetContext).pop('no_show_deducted');
                    _showActionToast(sheetContext, '노쇼(차감)으로 변경했어요.');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_off_outlined,
                    color: Colors.orange,
                  ),
                  title: const Text('노쇼(미차감)'),
                  onTap: () async {
                    await _setAttendanceOverride(
                      docId: docId,
                      overrideValue: 'no_show_not_deducted',
                    );
                    Navigator.of(sheetContext).pop('no_show_not_deducted');
                    _showActionToast(sheetContext, '노쇼(미차감)으로 변경했어요.');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.undo_rounded,
                    color: Colors.blueGrey,
                  ),
                  title: const Text('출석 취소하기'),
                  onTap: () async {
                    await _setAttendanceOverride(
                      docId: docId,
                      overrideValue: null,
                    );
                    Navigator.of(sheetContext).pop('');
                    _showActionToast(sheetContext,'예외 상태가 취소되었습니다.');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }


  Map<String, dynamic> _buildWeekSlice(int weekOffset) {
    final Map<String, dynamic> result = {};

    for (final item in _scheduleItemsForWeek(weekOffset)) {
      result['${item.day}-${item.time}'] = item.toMap();
    }

    return result;
  }

  Map<String, dynamic> _buildScheduleExampleSlice(int weekOffset) {
    if (!_shouldShowScheduleExamples(weekOffset)) {
      return {};
    }

    final monday = _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));

    DateTime exampleDate(int dayOffset, int hour, int minute) {
      final date = monday.add(Duration(days: dayOffset));
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    Map<String, dynamic> exampleItem({
      required String id,
      required DateTime startAt,
      required int minutes,
      required String name,
      required String type,
      required String memo,
      required String remainingSessions,
      required String totalSessions,
    }) {
      final endAt = startAt.add(Duration(minutes: minutes));
      final day = _weekDaysAll[startAt.weekday - 1];

      return {
        'docId': id,
        'isExample': true,
        'startAt': startAt,
        'endAt': endAt,
        'day': day,
        'time': _timeStringFromDateTime(startAt),
        'endTime': _timeStringFromDateTime(endAt),
        'name': name,
        'type': type,
        'typeName': type,
        'typeColorHex': '#9CA3AF',
        'attended': false,
        'remainingSessions': remainingSessions,
        'totalSessions': totalSessions,
        'memo': memo,
      };
    }

    final examples = <Map<String, dynamic>>[
      exampleItem(
        id: 'example_schedule_1',
        startAt: exampleDate(0, 9, 0),
        minutes: 50,
        name: '김모어',
        type: 'PT수업',
        memo: '하체운동 · 무릎 체크',
        remainingSessions: '9',
        totalSessions: '10',
      ),
      exampleItem(
        id: 'example_schedule_2',
        startAt: exampleDate(2, 14, 0),
        minutes: 50,
        name: '박회원',
        type: '필라테스',
        memo: '코어 안정화',
        remainingSessions: '4',
        totalSessions: '8',
      ),
      exampleItem(
        id: 'example_schedule_3',
        startAt: exampleDate(4, 18, 0),
        minutes: 60,
        name: '이예시',
        type: '그룹수업',
        memo: '그룹 컨디셔닝',
        remainingSessions: '2',
        totalSessions: '12',
      ),
    ];

    final result = <String, dynamic>{};

    for (final item in examples) {
      final startAt = item['startAt'];
      if (startAt is! DateTime) continue;

      final key = '${item['day']}-${item['time']}';
      result[key] = item;
    }

    return result;
  }

  List<String> get _weekDaysAll => const ["월", "화", "수", "목", "금", "토", "일"];

  List<String> get _weekDays {
    const weekdayDays = ["월", "화", "수", "목", "금"];
    const weekendDays = ["토", "일"];
    switch (dayFilter) {
      case "weekday":
        return weekdayDays;
      case "weekend":
        return weekendDays;
      default:
        return _weekDaysAll;
    }
  }

  void _ensureTimeRowMinutes() {
    for (int h = startHour; h < endHour; h++) {
      _timeRowMinutes.putIfAbsent(h, () => defaultMinute);
    }
  }

  List<String> get _timeSlots {
    _ensureTimeRowMinutes();
    return List<String>.generate(
      endHour - startHour,
          (i) {
        final hour = startHour + i;
        final minute = _timeRowMinutes[hour] ?? defaultMinute;
        return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(
            2, '0')}";
      },
    );
  }

  void _showSnack(String msg, {
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  OverlayEntry? _actionToastEntry;
  Timer? _actionToastTimer;

  void _hideActionToast() {
    _actionToastTimer?.cancel();
    _actionToastTimer = null;
    _actionToastEntry?.remove();
    _actionToastEntry = null;
  }

  void _showActionToast(
      BuildContext targetContext,
      String message, {
        double bottomOffset = 76,
        Duration duration = const Duration(milliseconds: 1400),
      }) {
    final overlay = Overlay.of(targetContext);
    if (overlay == null) return;

    _hideActionToast();

    _actionToastEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: bottomOffset,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_actionToastEntry!);

    _actionToastTimer = Timer(duration, _hideActionToast);
  }

  void _showError(String msg) => _showSnack(msg);

  String _widgetDisplayName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'ㆍ';

    final normalized = name.endsWith('님')
        ? name.substring(0, name.length - 1).trim()
        : name;

    final safe = normalized.isEmpty ? name : normalized;
    return safe.length <= 4 ? safe : safe.substring(0, 4);
  }

  String _widgetDayFilterLabel() {
    switch (dayFilter) {
      case 'weekday':
        return '주5';
      case 'weekend':
        return '주2';
      default:
        return '주7';
    }
  }

  String _timeLabelFromDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _absoluteKeyFromDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d-$h:$min';
  }

  String _scheduleDocIdFromDate(DateTime dt, String day) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y$m$d-$h$min-$day';
  }

  ScheduleItem? _scheduleItemFromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    return ScheduleItem.fromMap(
      raw,
      defaultDurationMinutes: _defaultLessonDurationMinutes,
    );
  }

  List<ScheduleItem> _allScheduleItems() {
    final items = <ScheduleItem>[];

    for (final raw in scheduleData.values) {
      final item = _scheduleItemFromRaw(raw);
      if (item != null) {
        items.add(item);
      }
    }

    items.sort((a, b) => a.startAt.compareTo(b.startAt));
    return items;
  }

  List<ScheduleItem> _scheduleItemsForDay(DateTime dayDate) {
    final start = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final end = start.add(const Duration(days: 1));

    return _allScheduleItems().where((item) {
      return !item.startAt.isBefore(start) && item.startAt.isBefore(end);
    }).toList();
  }

  List<ScheduleItem> _scheduleItemsForToday() {
    final now = currentTime;
    return _scheduleItemsForDay(DateTime(now.year, now.month, now.day));
  }

  List<ScheduleItem> _scheduleItemsForWeek(int weekOffset) {
    final start = _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final end = start.add(const Duration(days: 7));

    return _allScheduleItems().where((item) {
      return !item.startAt.isBefore(start) && item.startAt.isBefore(end);
    }).toList();
  }

  List<String> _buildWidgetVisibleDays() {
    return List<String>.from(_weekDays);
  }

  DateTime _widgetTableStartForWeek(int weekOffset) {
    final monday = _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    return DateTime(monday.year, monday.month, monday.day, startHour, 0);
  }

  DateTime _widgetTableEndForWeek(int weekOffset) {
    final monday = _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    return DateTime(monday.year, monday.month, monday.day, endHour, 0);
  }

  double? _buildWidgetCurrentMarkerRatio(int weekOffset) {
    if (weekOffset != 0) return null;

    final tableStart = _widgetTableStartForWeek(weekOffset);
    final tableEnd = _widgetTableEndForWeek(weekOffset);

    if (!currentTime.isAfter(tableStart) || !currentTime.isBefore(tableEnd)) {
      return null;
    }

    final totalMinutes = tableEnd.difference(tableStart).inMinutes;
    if (totalMinutes <= 0) return null;

    final passedMinutes = currentTime.difference(tableStart).inMinutes;
    return (passedMinutes / totalMinutes).clamp(0.0, 1.0);
  }

  List<WidgetScheduleBlock> _buildWidgetBlocks(int weekOffset) {
    final days = _buildWidgetVisibleDays();

    final items = _scheduleItemsForWeek(weekOffset)
        .where((item) => days.contains(item.day))
        .toList();

    if (items.isEmpty) return const [];

    final blocks = <WidgetScheduleBlock>[];

    for (final day in days) {
      final dayIndex = _weekDaysAll.indexOf(day);
      if (dayIndex < 0) continue;

      final monday = _mondayOfWeek(currentTime).add(
        Duration(days: weekOffset * 7),
      );
      final baseDate = monday.add(Duration(days: dayIndex));

      final tableStart = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        startHour,
        0,
      );

      final tableEnd = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        endHour,
        0,
      );

      final totalMinutes = tableEnd.difference(tableStart).inMinutes;
      if (totalMinutes <= 0) continue;

      final dayItems = items.where((item) => item.day == day).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      for (final item in dayItems) {
        final clippedStart =
        item.startAt.isBefore(tableStart) ? tableStart : item.startAt;
        final clippedEnd =
        item.endAt.isAfter(tableEnd) ? tableEnd : item.endAt;

        if (!clippedEnd.isAfter(clippedStart)) continue;

        final topMinutes = clippedStart.difference(tableStart).inMinutes;
        final heightMinutes = clippedEnd.difference(clippedStart).inMinutes;

        final label = _widgetDisplayName(item.name);

        blocks.add(
          WidgetScheduleBlock(
            day: day,
            topRatio: (topMinutes / totalMinutes).clamp(0.0, 1.0),
            heightRatio: (heightMinutes / totalMinutes).clamp(0.0, 1.0),
            columnIndex: 0,
            totalColumns: 1,
            label: label,
            type: item.type,
            colorHex: item.typeColorHex ?? _lessonTypeColorHexByName(item.type),
          ),
        );
      }
    }

    return blocks;
  }
  int _countThisWeekSessions() {
    return _scheduleItemsForWeek(0).length;
  }

  int _weeklyGoalTarget() {
    return 40;
  }

  List<String> _buildWidgetVisibleTimes(Map<String, dynamic> weekSlice,
      int weekOffset,) {
    if (_timeSlots.isEmpty) {
      return const [];
    }

    return List<String>.from(_timeSlots);
  }

  String? _buildWidgetCurrentMarkerTime(List<String> visibleTimes,
      int weekOffset,) {
    if (visibleTimes.isEmpty || weekOffset != 0) return null;

    final nowLabel =
        '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute
        .toString().padLeft(2, '0')}';

    String? currentMarkerTime;
    for (final time in visibleTimes) {
      if (time.compareTo(nowLabel) <= 0) {
        currentMarkerTime = time;
        continue;
      }
      break;
    }

    return currentMarkerTime ?? visibleTimes.first;
  }

  int _countThisWeekMemoMembers() {
    final seen = <String>{};

    for (final item in _scheduleItemsForWeek(0)) {
      final raw = scheduleData[_absoluteKeyFromDate(item.startAt)];
      if (raw is! Map<String, dynamic>) continue;

      final memo = (raw['memo'] ?? '').toString().trim();
      if (memo.isEmpty) continue;

      final memberId = (raw['memberId'] ?? '').toString().trim();
      final name = (raw['name'] ?? '').toString().trim();

      final key = memberId.isNotEmpty ? memberId : name;
      if (key.isNotEmpty) {
        seen.add(key);
      }
    }

    return seen.length;
  }

  List<String> _buildWidgetWeekRows(int weekOffset) {
    final widgetDays = List<String>.from(_weekDays);
    final rows = <String>[];

    for (final time in _timeSlots) {
      final parts = time.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? -1 : -1;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final rowStartMinutes = hour * 60 + minute;
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;

      final isCurrent = weekOffset == 0 &&
          currentMinutes >= rowStartMinutes &&
          currentMinutes < rowStartMinutes + 60;

      final cells = <String>[];
      for (final day in widgetDays) {
        cells.add('ㆍ');
      }

      rows.add('$time|${isCurrent ? '1' : '0'}|${cells.join('|')}');
    }

    return rows;
  }

  void _patchScheduleData({
    List<String> removeKeys = const [],
    Map<String, Map<String, dynamic>> upsert = const {},
    bool syncWidget = true,
  }) {
    var changed = false;

    for (final key in removeKeys) {
      changed = scheduleData.remove(key) != null || changed;
    }

    upsert.forEach((key, value) {
      final prev = scheduleData[key];
      if (prev is Map<String, dynamic>) {
        if (mapEquals(prev, value)) return;
      }
      scheduleData[key] = value;
      changed = true;
    });

    if (!changed) return;

    if (mounted) {
      setState(() {});
    }

    if (syncWidget) {
      unawaited(_syncHomeWidgetPreview());
    }
  }

  String _buildWidgetHeaderText({
    required int weekOffset,
    required String emptyFallback,
  }) {
    final weekSlice = _buildWeekSlice(weekOffset);
    final filterLabel = _widgetDayFilterLabel();
    final rangeLabel =
        '${startHour.toString().padLeft(2, '0')}-${(endHour - 1)
        .toString()
        .padLeft(2, '0')}';
    final count = weekSlice.length;

    if (count == 0) {
      return '$filterLabel · $rangeLabel · 수업일정 없음';
    }

    return '$filterLabel · $rangeLabel · ${count}건';
  }

  Future<void> _syncHomeWidgetPreview() async {
    final rows0 = _buildWidgetWeekRows(0);
    final rows1 = _buildWidgetWeekRows(1);

    final days0 = _buildWidgetVisibleDays();
    final days1 = _buildWidgetVisibleDays();

    debugPrint(
      '[MTF_WIDGET] rows0=${rows0.length}, rows1=${rows1.length}, '
          'startHour=$startHour, endHour=$endHour, days=${days0.join(",")}',
    );

    final List<String> blocks0 =
    _buildWidgetBlocks(0).map((WidgetScheduleBlock e) => e.encode()).toList();

    final List<String> blocks1 =
    _buildWidgetBlocks(1).map((WidgetScheduleBlock e) => e.encode()).toList();

    final currentMarkerRatio0 = _buildWidgetCurrentMarkerRatio(0);
    final currentMarkerRatio1 = _buildWidgetCurrentMarkerRatio(1);

    final header0 =
        '${_buildWidgetHeaderText(
      weekOffset: 0,
      emptyFallback: '수업일정 없음',
    )} · ${rows0.length}줄';

    final header1 =
        '${_buildWidgetHeaderText(
      weekOffset: 1,
      emptyFallback: '수업일정 없음',
    )} · ${rows1.length}줄';

    await MtfHomeWidgetService.syncGridWeeks(
      dayFilter: dayFilter,
      startHour: startHour,
      endHour: endHour,
      title0: _weekTitleForOffset(0),
      header0: header0,
      rows0: rows0,
      days0: days0,
      blocks0: blocks0,
      currentMarkerRatio0: currentMarkerRatio0,
      title1: _weekTitleForOffset(1),
      header1: header1,
      rows1: rows1,
      days1: days1,
      blocks1: blocks1,
      currentMarkerRatio1: currentMarkerRatio1,
    );

    final widgetEvents = _allScheduleItems().map((item) {
      return WidgetLessonEvent(
        startAt: item.startAt,
        memberName: item.name,
        lessonType: item.type,
        memo: item.memo ?? '',
      );
    }).toList();

    await syncNextLessonWidgetFromEvents(widgetEvents);
  }

  // ---------- 시간/분 설정 관련 ----------

  Future<int?> _updateScheduleKeysForHour(int hour,
      int oldMinute,
      int newMinute, {
        bool syncAfter = true,
      }) async {
    if (oldMinute == newMinute) return 0;

    final candidates = <Map<String, dynamic>>[];
    final movingDocIds = <String>{};

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) return;
      if (rawStartAt.hour != hour || rawStartAt.minute != oldMinute) return;

      final docId = value['docId']?.toString().trim() ?? '';
      final day = _weekDaysAll[rawStartAt.weekday - 1];

      candidates.add({
        'docId': docId,
        'day': day,
        'startAt': rawStartAt,
        'data': Map<String, dynamic>.from(value),
      });

      if (docId.isNotEmpty) {
        movingDocIds.add(docId);
      }
    });

    if (candidates.isEmpty) return 0;

    final conflictTimes = <String>{};

    for (final item in candidates) {
      final startAt = item['startAt'] as DateTime;
      final targetAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        hour,
        newMinute,
      );

      final targetKey = _absoluteKeyFromDate(targetAt);
      final targetRaw = scheduleData[targetKey];

      if (targetRaw is! Map<String, dynamic>) continue;

      final targetDocId = targetRaw['docId']?.toString().trim() ?? '';
      if (targetDocId.isEmpty) continue;
      if (movingDocIds.contains(targetDocId)) continue;

      conflictTimes.add(_timeLabelFromDate(targetAt));
    }

    if (conflictTimes.isNotEmpty) {
      _showError(
        '${hour.toString().padLeft(2, '0')}시 줄은 ${conflictTimes.join(
            ', ')} 충돌 때문에 변경하지 않았어요.',
      );
      return null;
    }

    final batch = FirebaseFirestore.instance.batch();
    final localUpdates = <Map<String, dynamic>>[];

    for (final item in candidates) {
      final originalData =
      Map<String, dynamic>.from(item['data'] as Map<String, dynamic>);
      final sourceDocId = item['docId']?.toString().trim() ?? '';
      final day = item['day'] as String;
      final startAt = item['startAt'] as DateTime;

      final targetAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        hour,
        newMinute,
      );
      final targetDocId = _scheduleDocIdFromDate(targetAt, day);
      final sourceKey = _absoluteKeyFromDate(startAt);
      final targetKey = _absoluteKeyFromDate(targetAt);
      final targetTime = _timeLabelFromDate(targetAt);

      final firestoreData = Map<String, dynamic>.from(originalData);
      firestoreData.remove('docId');
      firestoreData['startAt'] = Timestamp.fromDate(targetAt);
      firestoreData['day'] = day;
      firestoreData['time'] = targetTime;
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();

      final targetRef =
      FirebaseFirestore.instance.collection('schedules').doc(targetDocId);
      batch.set(targetRef, firestoreData, SetOptions(merge: true));

      if (sourceDocId.isNotEmpty && sourceDocId != targetDocId) {
        final sourceRef =
        FirebaseFirestore.instance.collection('schedules').doc(sourceDocId);
        batch.delete(sourceRef);
      }

      localUpdates.add({
        'sourceKey': sourceKey,
        'targetKey': targetKey,
        'data': {
          ...originalData,
          'docId': targetDocId,
          'startAt': targetAt,
          'day': day,
          'time': targetTime,
        },
      });
    }

    await batch.commit();

    final removeKeys = <String>[];
    final upsert = <String, Map<String, dynamic>>{};

    for (final item in localUpdates) {
      final sourceKey = item['sourceKey']?.toString() ?? '';
      final targetKey = item['targetKey']?.toString() ?? '';
      final data = item['data'];

      if (sourceKey.isNotEmpty) {
        removeKeys.add(sourceKey);
      }
      if (targetKey.isNotEmpty && data is Map<String, dynamic>) {
        upsert[targetKey] = Map<String, dynamic>.from(data);
      }
    }

    _patchScheduleData(
      removeKeys: removeKeys,
      upsert: upsert,
      syncWidget: syncAfter,
    );

    return candidates.length;
  }

  void _openAllRowsMinuteSheet() {
    final validMinutes = [0, 10, 20, 30, 40, 50];
    int tempMinute = validMinutes.contains(defaultMinute) ? defaultMinute : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (sheetContext, localSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(13, 8, 13, 9),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4F46E5),
                          Color(0xFF7C3AED),
                          Color(0xFF9333EA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '전체 시간 분 일괄 변경',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(sheetContext).pop(),
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: Color(0xB3FFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '모든 시간 줄의 분과 새로 등록하는 수업의 기본 시작 분을 한 번에 바꿉니다.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 7,
                            runSpacing: 7,
                            children: validMinutes.map((m) {
                              final selected = tempMinute == m;

                              return GestureDetector(
                                onTap: () {
                                  localSetState(() {
                                    tempMinute = m;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? kPrimaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? kPrimaryColor
                                          : const Color(0xFFE5E7EB),
                                      width: selected ? 1.1 : 0.9,
                                    ),
                                    boxShadow: selected
                                        ? [
                                      BoxShadow(
                                        color:
                                        kPrimaryColor.withOpacity(0.22),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                        : null,
                                  ),
                                  child: Text(
                                    '${m.toString().padLeft(2, '0')}분',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 15),

                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4F46E5),
                                  Color(0xFF9333EA),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withOpacity(0.22),
                                  blurRadius: 9,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final moveResults = <int, int?>{};

                                for (int h = startHour; h < endHour; h++) {
                                  final oldMinute =
                                      _timeRowMinutes[h] ?? defaultMinute;

                                  moveResults[h] =
                                  await _updateScheduleKeysForHour(
                                    h,
                                    oldMinute,
                                    tempMinute,
                                    syncAfter: false,
                                  );
                                }

                                if (!mounted) return;

                                final successfulHours = moveResults.entries
                                    .where((e) => e.value != null)
                                    .map((e) => e.key)
                                    .toList();

                                final conflictHours = moveResults.entries
                                    .where((e) => e.value == null)
                                    .map((e) => e.key)
                                    .toList();

                                final movedCount = moveResults.values
                                    .whereType<int>()
                                    .fold<int>(0, (sum, value) => sum + value);

                                setState(() {
                                  for (final h in successfulHours) {
                                    _timeRowMinutes[h] = tempMinute;
                                  }

                                  if (successfulHours.length ==
                                      endHour - startHour) {
                                    defaultMinute = tempMinute;
                                  }
                                });

                                await _saveScheduleViewPrefs();

                                if (!mounted) return;

                                Navigator.of(sheetContext).pop();

                                await _syncHomeWidgetPreview();

                                if (conflictHours.isEmpty) {
                                  _showSnack(
                                    '모든 시간 줄과 기본 시작 분이 ${tempMinute.toString().padLeft(2, '0')}분으로 설정되었습니다.'
                                        '${movedCount > 0 ? ' 기존 수업일정 $movedCount개도 함께 옮겼어요.' : ''}',
                                  );
                                } else if (successfulHours.isEmpty) {
                                  _showActionToast(
                                    context,
                                    '충돌 때문에 변경된 시간 줄이 없어요.',
                                  );
                                } else {
                                  _showSnack(
                                    '충돌 없는 ${successfulHours.length}개 시간 줄만 ${tempMinute.toString().padLeft(2, '0')}분으로 적용했어요. '
                                        '충돌 ${conflictHours.length}개 줄은 기존 시간으로 유지했어요.',
                                  );
                                }
                              },
                              child: const Text(
                                '전체 적용',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Center(
                          child: Text(
                            '충돌이 있는 시간 줄은 기존 값으로 유지돼요',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openRowMinuteSheet(int hour, int currentMinute) {
    final validMinutes = [0, 10, 20, 30, 40, 50];
    int tempMinute = validMinutes.contains(currentMinute) ? currentMinute : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${hour.toString().padLeft(2, '0')}시 줄 분 변경",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "이 시간 줄만 분을 바꿉니다.\n이미 등록된 수업일정도 같이 옮겨집니다.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: validMinutes.map((m) {
                      final selected = (tempMinute == m);
                      return ChoiceChip(
                        label: Text("${m.toString().padLeft(2, '0')}분"),
                        selected: selected,
                        selectedColor: kPrimaryColor.withOpacity(0.12),
                        checkmarkColor: kPrimaryColor,
                        onSelected: (_) {
                          localSetState(() {
                            tempMinute = m;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final oldMinute = _timeRowMinutes[hour] ??
                            currentMinute;
                        final movedCount = await _updateScheduleKeysForHour(
                          hour,
                          oldMinute,
                          tempMinute,
                          syncAfter: false,
                        );

                        if (!mounted || movedCount == null) return;

                        setState(() {
                          _timeRowMinutes[hour] = tempMinute;
                          defaultMinute = tempMinute;
                        });

                        await _saveScheduleViewPrefs();

                        Navigator.pop(context);
                        await _syncHomeWidgetPreview();

                        _showSnack(
                          "${hour.toString().padLeft(2, '0')}시 줄이 ${tempMinute
                              .toString().padLeft(2, '0')}분으로 변경되었습니다."
                              "${movedCount > 0
                              ? ' 기존 수업일정 $movedCount개도 함께 옮겼어요.'
                              : ''}",
                        );
                      },
                      child: const Text("적용"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ (변경) 더블탭 → 롱프레스
  void _onTimeRowLongPress(String timeLabel) {
    final parts = timeLabel.split(":");
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? -1;
    if (hour < 0 || hour > 23) return;
    final minuteFromLabel = int.tryParse(parts[1]) ?? 0;
    final currentMinute = _timeRowMinutes[hour] ?? minuteFromLabel;
    _openRowMinuteSheet(hour, currentMinute);
  }

  Future<void> _openTimeRangeDialog() async {
    int tempStart = startHour;
    int tempEnd = endHour - 1;
    bool useKeyboard = false;

    final startWheelController = FixedExtentScrollController(
        initialItem: tempStart);
    final endWheelController = FixedExtentScrollController(
        initialItem: tempEnd);

    final startTextController =
    TextEditingController(text: tempStart.toString().padLeft(2, '0'));
    final endTextController =
    TextEditingController(text: tempEnd.toString().padLeft(2, '0'));

    String formatHour(int h) {
      final isPm = h >= 12;
      final displayHour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final ampm = isPm ? "오후" : "오전";
      return "$ampm ${displayHour12.toString().padLeft(2, '0')}:00";
    }

    Widget buildFlipColumn({
      required String label,
      required FixedExtentScrollController controller,
      required int selectedValue,
      required ValueChanged<int> onChanged,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Container(
            width: 64,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              physics: const BouncingScrollPhysics(
                parent: FixedExtentScrollPhysics(),
              ),
              itemExtent: 40,
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 24,
                builder: (context, index) {
                  final isSelected = index == selectedValue;
                  return Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(
                        vertical: 2, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? kAccentAmber : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "시간 범위 설정",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight
                            .w600),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: useKeyboard ? "점수판으로 보기" : "키보드로 직접 입력",
                        icon: Icon(useKeyboard
                            ? Icons.flip_to_front
                            : Icons.keyboard_alt_outlined),
                        onPressed: () {
                          localSetState(() {
                            useKeyboard = !useKeyboard;
                            startTextController.text =
                                tempStart.toString().padLeft(2, '0');
                            endTextController.text =
                                tempEnd.toString().padLeft(2, '0');
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "시작/종료 시간을 점수판처럼 위아래로 돌리거나,\n"
                        "오른쪽 키보드 아이콘을 눌러 숫자로 직접 입력할 수 있어요.\n"
                        "(최소 3시간 이상)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (!useKeyboard) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildFlipColumn(
                          label: "시작",
                          controller: startWheelController,
                          selectedValue: tempStart,
                          onChanged: (idx) {
                            localSetState(() {
                              tempStart = idx;
                              if (tempEnd < tempStart + 2) {
                                tempEnd = (tempStart + 2).clamp(2, 23);
                                endWheelController.jumpToItem(tempEnd);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        const Text("~"),
                        const SizedBox(width: 16),
                        buildFlipColumn(
                          label: "종료",
                          controller: endWheelController,
                          selectedValue: tempEnd,
                          onChanged: (idx) {
                            localSetState(() {
                              tempEnd = idx;
                              if (tempEnd < tempStart + 2) {
                                tempStart = (tempEnd - 2).clamp(0, 21);
                                startWheelController.jumpToItem(tempStart);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ] else
                    ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startTextController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "시작 시간 (0~23)",
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endTextController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "종료 시간 (0~23)",
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  const SizedBox(height: 12),
                  Text(
                    "현재: ${formatHour(tempStart)} ~ ${formatHour(tempEnd)}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    int applyStart = tempStart;
                    int applyEnd = tempEnd;

                    if (useKeyboard) {
                      final parsedStart = int.tryParse(
                          startTextController.text);
                      final parsedEnd = int.tryParse(endTextController.text);
                      if (parsedStart == null || parsedEnd == null) {
                        _showError("숫자만 입력해주세요. (0~23)");
                        return;
                      }
                      applyStart = parsedStart.clamp(0, 23);
                      applyEnd = parsedEnd.clamp(0, 23);
                    }

                    if (applyEnd < applyStart) {
                      _showError("종료 시간이 시작 시간보다 빠를 수 없습니다.");
                      return;
                    }
                    if (applyEnd - applyStart < 2) {
                      _showError("최소 3시간 이상으로 설정해주세요.");
                      return;
                    }

                    setState(() {
                      startHour = applyStart;
                      endHour = applyEnd + 1;
                      _ensureTimeRowMinutes();
                    });

                    await _saveScheduleViewPrefs();

                    Navigator.pop(context);
                    await _syncHomeWidgetPreview();
                  },
                  child: const Text("적용"),
                ),
              ],
            );
          },
        );
      },
    );

    // 안정화 우선:
// 시간 범위 설정 다이얼로그도 키보드 hide / route 닫힘 애니메이션 중
// TextField가 controller를 다시 참조할 수 있어 여기서 dispose하지 않습니다.
// 추후 이 다이얼로그를 별도 StatefulWidget으로 분리한 뒤 State.dispose()에서 정리합니다.
  }

  String _formatLessonSheetTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = isPm ? '오후' : '오전';

    return '$ampm ${displayHour.toString().padLeft(2, '0')}:${minute
        .toString()
        .padLeft(2, '0')}';
  }

  String _timeStringFromDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>?> _openSingleLessonTimeDialog(
      String initialTime, {
        required String title,
        required int selectedDurationMinutes,
        required ValueChanged<int> onDurationSelected,
        String? startPreviewTime,
        bool showDurationChips = true,
        bool showUnsetPreview = false,
      }) async {
    final validMinutes = List<int>.generate(12, (i) => i * 5);

    final initialParts = initialTime.split(':');
    int tempHour = int.tryParse(initialParts.first) ?? 9;
    int tempMinute =
    initialParts.length > 1 ? (int.tryParse(initialParts[1]) ?? 0) : 0;

    tempMinute = ((tempMinute / 5).round() * 5).clamp(0, 55);

    int tempSelectedDuration = selectedDurationMinutes;
    bool useKeyboard = false;

    final hourWheelController =
    FixedExtentScrollController(initialItem: tempHour);
    final minuteWheelController = FixedExtentScrollController(
      initialItem: validMinutes.indexOf(tempMinute),
    );

    final hourTextController =
    TextEditingController(text: tempHour.toString().padLeft(2, '0'));
    final minuteTextController =
    TextEditingController(text: tempMinute.toString().padLeft(2, '0'));

    String currentPickedTime() {
      return '${tempHour.toString().padLeft(2, '0')}:${tempMinute.toString().padLeft(2, '0')}';
    }

    void syncInputsFromPickedTime() {
      hourTextController.text = tempHour.toString().padLeft(2, '0');
      minuteTextController.text = tempMinute.toString().padLeft(2, '0');

      if (!useKeyboard) {
        hourWheelController.animateToItem(
          tempHour,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        minuteWheelController.animateToItem(
          validMinutes.indexOf(tempMinute),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }

    void applyDurationFromStart(int minutes) {
      if (startPreviewTime == null || startPreviewTime.trim().isEmpty) return;

      final startParts = startPreviewTime.split(':');
      if (startParts.length != 2) return;

      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMinute = int.tryParse(startParts[1]) ?? 0;

      final base = DateTime(2000, 1, 1, startHour, startMinute);
      final next = base.add(Duration(minutes: minutes));

      tempHour = next.hour;
      tempMinute = next.minute;
      syncInputsFromPickedTime();
    }

    String previewText() {
      final picked = currentPickedTime();

      if (startPreviewTime != null && startPreviewTime.trim().isNotEmpty) {
        return '수업 시간 : ${_formatLessonSheetTime(startPreviewTime)} - ${_formatLessonSheetTime(picked)}';
      }

      if (showUnsetPreview) {
        return '수업 시간 : ${_formatLessonSheetTime(picked)} - 종료시간 설정전';
      }

      return '수업 시간 : ${_formatLessonSheetTime(picked)}';
    }

    Widget buildDurationChip(
        int minutes,
        String label,
        void Function(void Function()) setStateDialog,
        ) {
      final selected = tempSelectedDuration == minutes;

      return GestureDetector(
        onTap: () {
          tempSelectedDuration = minutes;

          if (startPreviewTime != null && startPreviewTime.trim().isNotEmpty) {
            applyDurationFromStart(minutes);
          }

          setStateDialog(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? kPrimaryColor.withOpacity(0.16)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? kPrimaryColor : Colors.grey.shade300,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? kPrimaryColor : Colors.black87,
            ),
          ),
        ),
      );
    }

    Widget buildWheelColumn({
      required String label,
      required FixedExtentScrollController controller,
      required int itemCount,
      required int selectedIndex,
      required String Function(int index) labelBuilder,
      required ValueChanged<int> onChanged,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            width: 66,
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 108 / 2 - 18,
                  left: 4,
                  right: 4,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x1FFBBF24),
                      borderRadius: BorderRadius.circular(7),
                      border: const Border(
                        top: BorderSide(color: Color(0x80FBBF24), width: 1),
                        bottom: BorderSide(color: Color(0x80FBBF24), width: 1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 28,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF111827), Colors.transparent],
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 28,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF111827), Colors.transparent],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  physics: const FixedExtentScrollPhysics(),
                  itemExtent: 34,
                  onSelectedItemChanged: onChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: itemCount,
                    builder: (context, index) {
                      final isSelected = index == selectedIndex;
                      final distance = (index - selectedIndex).abs();

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFBBF24)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          labelBuilder(index),
                          style: TextStyle(
                            fontSize: isSelected ? 20 : 17,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF111827)
                                : distance == 1
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF2E3A4E),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, localSetState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (showDurationChips) ...[
                                      buildDurationChip(30, '30분', localSetState),
                                      const SizedBox(width: 4),
                                      buildDurationChip(50, '50분', localSetState),
                                      const SizedBox(width: 4),
                                      buildDurationChip(60, '1시간', localSetState),
                                      const SizedBox(width: 6),
                                    ],
                                    IconButton(
                                      tooltip: useKeyboard ? '다이얼로 보기' : '숫자로 직접 입력',
                                      icon: Icon(
                                        useKeyboard
                                            ? Icons.schedule_outlined
                                            : Icons.keyboard_alt_outlined,
                                      ),
                                      onPressed: () {
                                        localSetState(() {
                                          useKeyboard = !useKeyboard;
                                          syncInputsFromPickedTime();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '분은 5분 단위로 설정할 수 있어요.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                if (!useKeyboard) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildWheelColumn(
                                        label: '시',
                                        controller: hourWheelController,
                                        itemCount: 24,
                                        selectedIndex: tempHour,
                                        labelBuilder: (index) =>
                                            index.toString().padLeft(2, '0'),
                                        onChanged: (idx) {
                                          localSetState(() {
                                            tempHour = idx;
                                            syncInputsFromPickedTime();
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 18),
                                      buildWheelColumn(
                                        label: '분',
                                        controller: minuteWheelController,
                                        itemCount: validMinutes.length,
                                        selectedIndex: validMinutes.indexOf(tempMinute),
                                        labelBuilder: (index) =>
                                            validMinutes[index].toString().padLeft(2, '0'),
                                        onChanged: (idx) {
                                          localSetState(() {
                                            tempMinute = validMinutes[idx];
                                            syncInputsFromPickedTime();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: hourTextController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: '시 (0~23)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: minuteTextController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: '분 (00~55)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 14),
                                Text(
                                  previewText(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 1),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.of(dialogContext).pop();
                                },
                                child: const Text('취소'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  int nextHour = tempHour;
                                  int nextMinute = tempMinute;

                                  if (useKeyboard) {
                                    final parsedHour =
                                    int.tryParse(hourTextController.text.trim());
                                    final parsedMinute =
                                    int.tryParse(minuteTextController.text.trim());

                                    if (parsedHour == null || parsedMinute == null) {
                                      _showError('숫자로만 입력해주세요.');
                                      return;
                                    }

                                    if (parsedHour < 0 || parsedHour > 23) {
                                      _showError('시는 0~23 사이만 가능합니다.');
                                      return;
                                    }

                                    if (parsedMinute < 0 ||
                                        parsedMinute > 59 ||
                                        parsedMinute % 5 != 0) {
                                      _showError('분은 5분 단위만 가능합니다.');
                                      return;
                                    }

                                    nextHour = parsedHour;
                                    nextMinute = parsedMinute;
                                  }

                                  Navigator.of(dialogContext).pop({
                                    'time':
                                    '${nextHour.toString().padLeft(2, '0')}:${nextMinute.toString().padLeft(2, '0')}',
                                    'duration': tempSelectedDuration,
                                  });
                                },
                                child: const Text('적용'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // 안정화 우선:
// 이 다이얼로그는 키보드/닫힘 애니메이션 중 TextField가 controller를 다시 참조할 수 있어
// 여기서 dispose하면 "TextEditingController was used after being disposed"가 발생합니다.
// 추후 별도 StatefulWidget으로 분리할 때 State.dispose()에서 정리합니다.

    if (result != null) {
      final duration = result['duration'];
      if (duration is int) {
        onDurationSelected(duration);
      }
    }

    return result;
  }

  Future<Map<String, String>?> _openLessonStartEndTimeDialog({
    required String initialStartTime,
    required String initialEndTime,
  }) async {
    final startResult = await _openSingleLessonTimeDialog(
      initialStartTime,
      title: '시작시간 변경',
      selectedDurationMinutes: _preferredLessonDurationMinutes,
      onDurationSelected: (minutes) {
        _preferredLessonDurationMinutes = minutes;
      },
      showUnsetPreview: true,
    );

    if (startResult == null) return null;

    final start = (startResult['time'] ?? '').toString();
    if (start.isEmpty) return null;

    FocusManager.instance.primaryFocus?.unfocus();

    await Future.delayed(const Duration(milliseconds: 260));

    if (!mounted) return null;

    final pickedDuration = startResult['duration'];
    final int selectedDuration = pickedDuration is int
        ? pickedDuration
        : _preferredLessonDurationMinutes;

    _preferredLessonDurationMinutes = selectedDuration;

    final startParts = start.split(':');
    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMinute = int.tryParse(startParts[1]) ?? 0;
    final startBase = DateTime(2000, 1, 1, startHour, startMinute);

    final autoEnd = _timeStringFromDateTime(
      startBase.add(Duration(minutes: selectedDuration)),
    );

    final endResult = await _openSingleLessonTimeDialog(
      autoEnd,
      title: '종료시간 변경',
      selectedDurationMinutes: selectedDuration,
      onDurationSelected: (minutes) {
        _preferredLessonDurationMinutes = minutes;
      },
      startPreviewTime: start,
    );

    if (endResult == null) return null;

    final end = (endResult['time'] ?? '').toString();
    if (end.isEmpty) return null;

    final endParts = end.split(':');
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMinute = int.tryParse(endParts[1]) ?? 0;
    final endBase = DateTime(2000, 1, 1, endHour, endMinute);

    if (!endBase.isAfter(startBase)) {
      _showError('종료 시간은 시작 시간보다 늦어야 해요.');
      return null;
    }

    final diff = endBase.difference(startBase).inMinutes;
    if (diff == 30 || diff == 50 || diff == 60) {
      _preferredLessonDurationMinutes = diff;
    }

    return {
      'startTime': start,
      'endTime': end,
    };
  }

  void _showComingSoon(String label) {
    _showSnack('$label 기능은 서비스 준비중입니다.');
  }

  void _openLegacyTestPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TestHubPage(),
      ),
    );
  }

  void _openLegacySettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }
  // -------------- 정식 회원 등록 (헤더 아이콘) --------------
  Future<void> _openFullRegistrationPage() async {
    final newId = FirebaseFirestore.instance
        .collection('members')
        .doc()
        .id;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClientCardPage.fromQuickRegistration(
              memberId: newId,
              initialName: '',
              initialPhone: '',
              initialVisitDate: DateTime.now(),
              initialConsultDate: null,
            ),
      ),
    );
  }

  // ---------- 빠른 회원 등록 ----------

  Future<_QuickRegResult?> _openQuickRegistrationDialog() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    DateTime visitDate = DateTime.now();
    DateTime? consultDate;

    final result = await showGeneralDialog<_QuickRegResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '빠른 등록',
      barrierColor: Colors.black.withOpacity(0.32),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, _) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final popScale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.92, end: 1.03)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 55,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.03, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 45,
          ),
        ]).animate(curved);

        final slideY = Tween<double>(begin: 34, end: 0).animate(curved);
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);

        return Transform.translate(
          offset: Offset(0, slideY.value),
          child: Opacity(
            opacity: fade.value,
            child: Transform.scale(
              scale: popScale.value,
              alignment: Alignment.bottomCenter,
              child: _QuickRegisterDialogBody(
                nameC: nameC,
                phoneC: phoneC,
                visitDate: visitDate,
                consultDate: consultDate,
                onVisitDateChanged: (value) {
                  visitDate = value;
                },
                onConsultDateChanged: (value) {
                  consultDate = value;
                },
                onClose: () => Navigator.pop(dialogContext),
                onDetail: () {
                  final name = nameC.text.trim();
                  final phone = phoneC.text.trim().replaceAll(RegExp(r'\D'), '');

                  Navigator.pop(
                    dialogContext,
                    _QuickRegResult(
                      action: _QuickRegAction.goDetail,
                      name: name,
                      phone: phone,
                      visitDate: visitDate,
                      consultDate: consultDate,
                    ),
                  );
                },
                onQuickSave: () {
                  final name = nameC.text.trim();
                  final rawPhone = phoneC.text.trim();
                  final phone = rawPhone.replaceAll(RegExp(r'\D'), '');

                  if (name.isEmpty || phone.isEmpty) {
                    _showActionToast(
                      dialogContext,
                      '이름과 연락처를 입력해주세요.',
                      bottomOffset: 110,
                    );
                    return;
                  }
                  if (phone.length < 9 || phone.length > 11) {
                    _showActionToast(
                      dialogContext,
                      '연락처 형식을 확인해주세요.',
                      bottomOffset: 110,
                    );
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    _QuickRegResult(
                      action: _QuickRegAction.fastSave,
                      name: name,
                      phone: phone,
                      visitDate: visitDate,
                      consultDate: consultDate,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<void> _showQuickRegistrationDialog() async {
    if (_isSubmitting) return;

    final result = await _openQuickRegistrationDialog();
    if (!mounted || result == null) return;

    if (result.action == _QuickRegAction.goDetail) {
      final newId = FirebaseFirestore.instance
          .collection('members')
          .doc()
          .id;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClientCardPage.fromQuickRegistration(
                memberId: newId,
                initialName: result.name,
                initialPhone: result.phone,
                initialVisitDate: result.visitDate,
                initialConsultDate: result.consultDate,
              ),
        ),
      );
      return;
    }

    if (result.action == _QuickRegAction.fastSave) {
      setState(() => _isSubmitting = true);
      try {
        final newId = FirebaseFirestore.instance
            .collection('members')
            .doc()
            .id;
        await FirebaseFirestore.instance.collection('members').doc(newId).set({
          'name': result.name,
          'phone': result.phone,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'memberStatus': '활성',
          'membershipGrade': 'BRONZE',
          'note': '최초 방문일: ${DateFormat('yyyy-MM-dd').format(
              result.visitDate)}',
          if (result.consultDate != null)
            'nextReservationAt': Timestamp.fromDate(result.consultDate!),
        }, SetOptions(merge: true));

        if (!mounted) return;
        _showActionToast(context, '${result.name} 님이 등록되었습니다.', bottomOffset: 110,
        );
      } catch (e) {
        if (!mounted) return;
        _showActionToast(context, '등록에 실패했습니다.', bottomOffset: 110,
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  void _onAction(HomeAction action) {
    switch (action) {
      case HomeAction.quickSchedule:
        _showQuickRegistrationDialog();
        break;
      case HomeAction.quickMember:
        _openFullRegistrationPage();
        break;
      case HomeAction.notifications:
        setState(() {
          _notificationsOn = !_notificationsOn;
        });
        break;
      case HomeAction.settings:
        _openLegacySettingsPage();
        break;
      case HomeAction.expiringMembers:
        _showComingSoon('만료 임박 / 잔여 수업 관리');
        break;
    }
  }

  // ---------- 오늘 다음 수업 ----------

  List<Map<String, dynamic>> _findTodayNextLessons() {
    final now = currentTime;
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final List<Map<String, dynamic>> entries = [];

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) return;

      final startAt = rawStartAt;
      if (startAt.isBefore(todayStart) || !startAt.isBefore(tomorrowStart)) {
        return;
      }

      final rawEndAt = value['endAt'];
      final endAt = rawEndAt is DateTime
          ? rawEndAt
          : startAt.add(
        const Duration(minutes: _defaultLessonDurationMinutes),
      );

      final day = _weekDaysAll[startAt.weekday - 1];
      final time =
          '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';

      entries.add({
        'day': day,
        'time': time,
        'name': (value['name'] ?? '').toString(),
        'type': (value['type'] ?? 'PT수업').toString(),
        'memo': (value['memo'] ?? '').toString(),
        'totalSessions': (value['totalSessions'] ?? '').toString(),
        'remainingSessions': (value['remainingSessions'] ?? '').toString(),
        'memberId': (value['memberId'] ?? '').toString(),
        'phone': (value['phone'] ?? '').toString(),
        'isManualMember': _isManualScheduleMember(value),
        'dt': startAt,
        'endAt': endAt,
      });
    });

    if (entries.isEmpty) return [];

    entries.sort((a, b) =>
        (a['dt'] as DateTime).compareTo(b['dt'] as DateTime));

    Map<String, dynamic>? current;
    final List<Map<String, dynamic>> upcoming = [];

    for (final e in entries) {
      final startAt = e['dt'] as DateTime;
      final endAt = e['endAt'] as DateTime;

      if (!now.isBefore(startAt) && now.isBefore(endAt)) {
        current ??= e;
      } else if (startAt.isAfter(now)) {
        upcoming.add(e);
      }
    }

    final List<Map<String, dynamic>> result = [];

    if (current != null) {
      current!['isOngoing'] = true;
      current!['minutesToStart'] = 0;
      current!['minutesToEnd'] =
          (current!['endAt'] as DateTime).difference(now).inMinutes;
      result.add(current!);
    }

    if (upcoming.isNotEmpty) {
      final next = upcoming.first;
      next['isOngoing'] = false;
      next['minutesToStart'] =
          (next['dt'] as DateTime).difference(now).inMinutes;
      result.add(next);
    }

    return result;
  }

  int _countTodaySessions() {
    return _scheduleItemsForToday().length;
  }

  Map<String, int> _countThisWeekLessonTypes() {
    final result = <String, int>{};

    for (final item in _scheduleItemsForWeek(0)) {
      result[item.type] = (result[item.type] ?? 0) + 1;
    }

    return result;
  }

  double _weeklyGoalProgress(int current, int target) {
    if (target <= 0) return 0;
    final value = current / target;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  String _topWeeklyLessonTypeLabel(Map<String, int> typeCounts, int rank) {
    if (typeCounts.isEmpty) return '-';

    final sorted = typeCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    if (rank < 0 || rank >= sorted.length) return '-';
    return '${sorted[rank].key} ${sorted[rank].value}회';
  }

  void _openTodayScheduleFocus() {
    if (_weekPageIndex != _todayWeekIndex) {
      _weekPageController.animateToPage(
        _todayWeekIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (!isHeaderExpanded) {
      setState(() {
        isHeaderExpanded = true;
      });
    }
  }

  void _openMembersPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientListPage(),
      ),
    );
  }

  void _openThisWeekStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StatsPage(
              scheduleData: Map<String, dynamic>.from(scheduleData),
            ),
      ),
    );
  }

  void _openExpiringMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientListPage(),
      ),
    );
  }

  void _openConsultPlaceholder() {
    _showSnack('상담 / OT 수업일지는 아직 준비중입니다.');
  }

  // ---------- 셀 탭 처리 ----------

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static const List<String> _koreanChoseongTable = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ',
    'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ',
    'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
    'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];

  String _extractChoseong(String text) {
    final buffer = StringBuffer();

    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final index = ((rune - 0xAC00) ~/ 588);
        buffer.write(_koreanChoseongTable[index]);
      } else {
        buffer.write(String.fromCharCode(rune));
      }
    }

    return buffer.toString();
  }

  bool _matchesNameKeyword(String name, String keyword) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedKeyword = keyword.trim().toLowerCase();

    if (normalizedKeyword.isEmpty) return true;
    if (normalizedName.contains(normalizedKeyword)) return true;

    final nameChoseong = _extractChoseong(normalizedName);
    final keywordChoseong = _extractChoseong(normalizedKeyword);

    return nameChoseong.contains(keywordChoseong);
  }

  String _buildSessionCountText(Map<String, dynamic>? session) {
    final remain = session?['remainingSessions']?.toString().trim() ?? '';
    final total = session?['totalSessions']?.toString().trim() ?? '';

    if (remain.isEmpty && total.isEmpty) return '';
    if (remain.isNotEmpty && total.isNotEmpty) return '$remain/$total';
    if (remain.isNotEmpty) return '$remain/';
    return '/$total';
  }

  Map<String, String> _memberSessionCountFieldsFromData(
      Map<String, dynamic> data,
      ) {
    final sessions = data['sessions'] is Map
        ? Map<String, dynamic>.from(data['sessions'] as Map)
        : <String, dynamic>{};

    final remainRaw = data['remainSessions'] ??
        data['remainingSessions'] ??
        sessions['remain'] ??
        data['remainingPt'] ??
        data['ptRemaining'];

    final totalRaw = data['totalSessions'] ??
        sessions['total'] ??
        data['sessionTotal'];

    final remain = remainRaw is num
        ? remainRaw.toInt()
        : int.tryParse((remainRaw ?? '').toString()) ?? 0;

    final total = totalRaw is num
        ? totalRaw.toInt()
        : int.tryParse((totalRaw ?? '').toString()) ?? 0;

    if (remain <= 0 && total <= 0) return {};

    return {
      'remainingSessions': remain.toString(),
      'totalSessions': total.toString(),
    };
  }

  String _sessionCountTextFromMemberData(Map<String, dynamic> data) {
    final fields = _memberSessionCountFieldsFromData(data);
    final remain = fields['remainingSessions'] ?? '';
    final total = fields['totalSessions'] ?? '';

    if (remain.isEmpty && total.isEmpty) return '';
    if (remain.isNotEmpty && total.isNotEmpty) return '$remain/$total';
    if (remain.isNotEmpty) return '$remain/';
    return '/$total';
  }

  Future<String> _loadMemberSessionCountText(String memberId) async {
    final cleanId = memberId.trim();
    if (cleanId.isEmpty) return '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanId)
          .get();

      final data = snap.data();
      if (data == null) return '';

      return _sessionCountTextFromMemberData(data);
    } catch (e) {
      debugPrint('회원 회차정보 불러오기 실패: $e');
      return '';
    }
  }
  Future<Map<String, String>> _loadMemberSessionCountFields(
      String memberId,
      ) async {
    final cleanId = memberId.trim();
    if (cleanId.isEmpty) return {};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanId)
          .get();

      final data = snap.data();
      if (data == null) return {};

      return _memberSessionCountFieldsFromData(data);
    } catch (e) {
      debugPrint('회원 최신 회차정보 불러오기 실패: $e');
      return {};
    }
  }

  Future<void> _refreshScheduleCountsFromMembers() async {
    if (scheduleData.isEmpty) return;

    final upsert = <String, Map<String, dynamic>>{};

    for (final entry in scheduleData.entries) {
      final raw = entry.value;
      if (raw is! Map<String, dynamic>) continue;

      final memberId = (raw['memberId'] ?? '').toString().trim();
      if (memberId.isEmpty) continue;

      final latestCountFields = await _loadMemberSessionCountFields(memberId);
      if (latestCountFields.isEmpty) continue;

      final currentRemain = (raw['remainingSessions'] ?? '').toString();
      final currentTotal = (raw['totalSessions'] ?? '').toString();

      final nextRemain = latestCountFields['remainingSessions'] ?? '';
      final nextTotal = latestCountFields['totalSessions'] ?? '';

      if (currentRemain == nextRemain && currentTotal == nextTotal) {
        continue;
      }

      upsert[entry.key] = {
        ...Map<String, dynamic>.from(raw),
        'remainingSessions': nextRemain,
        'totalSessions': nextTotal,
      };
    }

    if (upsert.isEmpty) return;

    _patchScheduleData(
      upsert: upsert,
      syncWidget: true,
    );
  }

  String _buildTodayLessonCountText(Map<String, dynamic> data) {
    final total = (data['totalSessions'] ?? '').toString().trim();
    final remain = (data['remainingSessions'] ?? '').toString().trim();

    if (total.isEmpty && remain.isEmpty) return '';
    if (total.isNotEmpty && remain.isNotEmpty) {
      return '총 ${total}회 / ${remain}회차';
    }
    if (total.isNotEmpty) return '총 ${total}회';
    return '${remain}회차';
  }

  Map<String, dynamic> _parseSessionCount(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return {};

    final parts = value.split('/');
    if (parts.length != 2) return {};

    final remain = parts[0].trim();
    final total = parts[1].trim();

    final result = <String, dynamic>{};
    if (remain.isNotEmpty) result['remainingSessions'] = remain;
    if (total.isNotEmpty) result['totalSessions'] = total;
    return result;
  }


  List<LessonTypeItem> _orderedLessonTypes() {
    final items = _lessonTypes.isNotEmpty
        ? List<LessonTypeItem>.from(_lessonTypes)
        : _buildSeedLessonTypes();

    items.sort((a, b) {
      if (a.id == _lastSelectedLessonTypeId) return -1;
      if (b.id == _lastSelectedLessonTypeId) return 1;
      return 0;
    });

    return items;
  }

  Future<void> _saveScheduleToFirestore({
    required int weekOffset,
    required String day,
    required String time,
    required String endTime,
    required String name,
    required LessonTypeItem lessonType,
    required bool attended,
    required Map<String, dynamic> countMap,
    String? memberId,
    String? phone,
    String? memo,
  }) async {
    final dt = _dateForCell(weekOffset, day, time);
    final endDt = _dateForCell(weekOffset, day, endTime);

    if (!endDt.isAfter(dt)) {
      throw Exception('종료 시간은 시작 시간보다 늦어야 합니다.');
    }

    final docId = _scheduleDocIdFromDate(dt, day);

    await FirebaseFirestore.instance.collection('schedules').doc(docId).set({
      'startAt': Timestamp.fromDate(dt),
      'endAt': Timestamp.fromDate(endDt),
      'day': day,
      'time': time,
      'endTime': endTime,
      'name': name,
      'type': lessonType.name,      // 기존 호환용
      'typeName': lessonType.name,
      'typeId': lessonType.id,
      'typeColorHex': lessonType.colorHex,
      'attended': attended,
      if (memberId != null && memberId.trim().isNotEmpty) 'memberId': memberId,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone,
      if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
      ...countMap,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _refreshMemberNextLesson(String memberId) async {
    try {
      final now = DateTime.now();

      final query = await FirebaseFirestore.instance
          .collection('schedules')
          .where('memberId', isEqualTo: memberId)
          .get();

      DateTime? nearest;

      for (final doc in query.docs) {
        final data = doc.data();
        final raw = data['startAt'];

        DateTime? date;
        if (raw is Timestamp) {
          date = raw.toDate();
        } else if (raw is DateTime) {
          date = raw;
        } else if (raw is String && raw.isNotEmpty) {
          date = DateTime.tryParse(raw);
        }

        if (date == null) continue;
        if (date.isBefore(now)) continue;

        if (nearest == null || date.isBefore(nearest)) {
          nearest = date;
        }
      }

      await FirebaseFirestore.instance
          .collection('members')
          .doc(memberId)
          .set({
        'nextLessonAt': nearest == null ? null : Timestamp.fromDate(nearest),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('nextLessonAt 갱신 실패: $e');
    }
  }

  Future<bool> _deleteScheduleFromFirestore(String docId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('schedules').doc(docId);
      final snap = await ref.get();

      if (!snap.exists) {
        debugPrint('수업일정 삭제 실패: 문서 없음 ($docId)');
        return false;
      }

      final data = snap.data();
      final memberId = (data?['memberId'] ?? '').toString().trim();

      await ref.delete();

      final removeKeys = <String>[];

      scheduleData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final currentDocId = value['docId']?.toString().trim() ?? '';
          if (currentDocId == docId) {
            removeKeys.add(key);
          }
        }
      });

      _patchScheduleData(
        removeKeys: removeKeys,
        syncWidget: false,
      );

      if (memberId.isNotEmpty) {
        await _refreshMemberNextLesson(memberId);
      }

      if (mounted) {
        unawaited(_syncHomeWidgetPreview());
      }

      return true;
    } catch (e) {
      debugPrint('수업일정 삭제 실패: $e');
      return false;
    }
  }

  Future<void> _setScheduleAttendance(String currentKey,
      bool nextAttended) async {
    final raw = scheduleData[currentKey];
    if (raw is! Map<String, dynamic>) return;

    final docId = raw['docId']?.toString();
    if (docId == null || docId.isEmpty) return;

    await FirebaseFirestore.instance.collection('schedules').doc(docId).set({
      'attended': nextAttended,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      unawaited(_syncHomeWidgetPreview());
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findMemberDocFromSchedule({
    required String memberName,
    String? phone,
  }) async {
    final cleanName = memberName.trim();
    final cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');

    if (cleanPhone.isNotEmpty) {
      final byPhone = await FirebaseFirestore.instance
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (byPhone.docs.isNotEmpty) {
        return byPhone.docs.first;
      }
    }

    if (cleanName.isEmpty) return null;

    final byName = await FirebaseFirestore.instance
        .collection('members')
        .where('name', isEqualTo: cleanName)
        .limit(1)
        .get();

    if (byName.docs.isNotEmpty) {
      return byName.docs.first;
    }

    return null;
  }

  Future<String?> _resolveLinkedMemberId({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    final cleanMemberId = memberId?.trim() ?? '';

    if (cleanMemberId.isNotEmpty) {
      return cleanMemberId;
    }

    // 안전 기준:
    // 회원카드/수업일지는 memberId가 있을 때만 직접 이동합니다.
    // 이름이나 전화번호로 자동 탐색하면 동명이인 또는 예전 수기 데이터가
    // 다른 회원카드로 열릴 수 있습니다.
    return null;
  }

  String _memberGenderLabel(Map<String, dynamic> data) {
    final raw = data['gender'] ??
        data['sex'] ??
        data['genderLabel'] ??
        data['memberGender'];

    final value = raw?.toString().trim().toLowerCase() ?? '';

    switch (value) {
      case '남':
      case '남자':
      case 'male':
      case 'm':
      case 'man':
      case '1':
        return '남';
      case '여':
      case '여자':
      case 'female':
      case 'f':
      case 'woman':
      case '2':
        return '여';
      default:
        return '-';
    }
  }

  String _formatPhoneDisplay(String value) {
    final digits = _normalizePhone(value);

    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits
          .substring(7)}';
    }

    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits
          .substring(6)}';
    }

    return digits.isEmpty ? '-' : digits;
  }

  Future<List<Map<String, dynamic>>> _findExactMemberCandidates(
      String inputText,) async {
    final cleanText = inputText.trim();
    final normalizedDigits = _normalizePhone(cleanText);

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void addDocs(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        if (seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);

        final data = doc.data();
        final sessionCountText = _sessionCountTextFromMemberData(data);
        final parts = sessionCountText.split('/');
        final remain = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
        final total = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

        DateTime? nextLessonAt;
        final rawNextLesson = data['nextLessonAt'] ?? data['nextReservationAt'];

        if (rawNextLesson is Timestamp) {
          nextLessonAt = rawNextLesson.toDate();
        } else if (rawNextLesson is DateTime) {
          nextLessonAt = rawNextLesson;
        } else if (rawNextLesson is String && rawNextLesson.isNotEmpty) {
          nextLessonAt = DateTime.tryParse(rawNextLesson);
        }

        results.add({
          'id': doc.id,
          'name': (data['name'] ?? '').toString().trim(),
          'phone': (data['phone'] ?? '').toString().trim(),
          'phoneDisplay': _formatPhoneDisplay(
            (data['phone'] ?? '').toString(),
          ),
          'gender': _memberGenderLabel(data),
          'job': (data['job'] ??
              data['occupation'] ??
              data['work'] ??
              data['memberJob'] ??
              '')
              .toString()
              .trim(),
          'totalSessions': total,
          'remainingSessions': remain,
          'nextLessonAt': nextLessonAt,
        });
      }
    }

    if (normalizedDigits.length >= 9) {
      final byPhone = await FirebaseFirestore.instance
          .collection('members')
          .where('phone', isEqualTo: normalizedDigits)
          .limit(10)
          .get();
      addDocs(byPhone);
    }

    if (cleanText.isNotEmpty) {
      final byName = await FirebaseFirestore.instance
          .collection('members')
          .where('name', isEqualTo: cleanText)
          .limit(10)
          .get();
      addDocs(byName);
    }

    return results;
  }

  Future<Map<String, dynamic>?> _openMemberMatchPickerSheet({
    required String typedName,
    required String lessonLabel,
    required List<Map<String, dynamic>> candidates,
  }) async {
    String nextLessonLabel(dynamic value) {
      if (value is! DateTime) return '다음 수업 없음';

      final month = value.month;
      final day = value.day;
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');

      return '다음 수업 $month월 $day일 $hour:$minute';
    }

    String memberMetaLabel(Map<String, dynamic> candidate) {
      final gender = (candidate['gender'] ?? '-').toString().trim();
      final job = (candidate['job'] ?? '').toString().trim();

      if (job.isEmpty) return gender;
      return '$gender / $job';
    }

    String sessionLabel(Map<String, dynamic> candidate) {
      final remain = candidate['remainingSessions'];
      final total = candidate['totalSessions'];

      final remainValue = remain is num
          ? remain.toInt()
          : int.tryParse((remain ?? '').toString()) ?? 0;

      final totalValue = total is num
          ? total.toInt()
          : int.tryParse((total ?? '').toString()) ?? 0;

      if (totalValue <= 0 && remainValue <= 0) {
        return '회차정보 없음';
      }

      return '잔여 $remainValue/$totalValue';
    }

    String shortPhoneLabel(String value) {
      final digits = _normalizePhone(value);

      if (digits.length == 11) {
        return '${digits.substring(0, 3)}-****-${digits.substring(7)}';
      }

      if (digits.length == 10) {
        return '${digits.substring(0, 3)}-***-${digits.substring(6)}';
      }

      return digits.isEmpty ? '-' : _formatPhoneDisplay(digits);
    }

    Map<String, dynamic>? selectedCandidate;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '기존 회원과 이름이 같아요',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${typedName.trim().isEmpty ? '입력한 이름' : typedName.trim()} 후보 ${candidates.length}명을 확인해 주세요.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final isSelected =
                            identical(selectedCandidate, candidate);

                            final name = (candidate['name'] ?? typedName)
                                .toString()
                                .trim();
                            final phone = (candidate['phone'] ?? '')
                                .toString()
                                .trim();

                            final meta = memberMetaLabel(candidate);
                            final phoneText = shortPhoneLabel(phone);
                            final sessionText = sessionLabel(candidate);
                            final nextLesson =
                            nextLessonLabel(candidate['nextLessonAt']);

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setSheetState(() {
                                  selectedCandidate = candidate;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: double.infinity,
                                padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kPrimaryColor.withOpacity(0.07)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? kPrimaryColor
                                        : const Color(0xFFE5E7EB),
                                    width: isSelected ? 1.4 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.025),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? kPrimaryColor
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$name 님',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '$meta · $phoneText',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _MemberMatchInfoChip(
                                                label: sessionText,
                                              ),
                                              _MemberMatchInfoChip(
                                                label: nextLesson,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop({
                                  'manual': true,
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF374151),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '새로 저장',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedCandidate == null
                                  ? null
                                  : () {
                                Navigator.of(sheetContext)
                                    .pop(selectedCandidate);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFFE5E7EB),
                                disabledForegroundColor:
                                const Color(0xFF9CA3AF),
                                padding:
                                const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '선택한 회원으로 저장',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String?>?> _resolveMemberLinkBeforeSave({
    required String inputText,
    required String lessonLabel,
    String? selectedMemberId,
    String? selectedMemberPhone,
  }) async {
    final cleanMemberId = selectedMemberId?.trim() ?? '';
    final cleanPhone = _normalizePhone(selectedMemberPhone ?? '');

    if (cleanMemberId.isNotEmpty || cleanPhone.isNotEmpty) {
      String sessionCountText = '';

      if (cleanMemberId.isNotEmpty) {
        sessionCountText = await _loadMemberSessionCountText(cleanMemberId);
      }

      return {
        'memberId': cleanMemberId.isNotEmpty ? cleanMemberId : null,
        'phone': cleanPhone.isNotEmpty ? cleanPhone : null,
        'name': null,
        'sessionCountText': sessionCountText.isNotEmpty ? sessionCountText : null,
      };
    }

    final candidates = await _findExactMemberCandidates(inputText);

    if (candidates.isEmpty) {
      return {
        'memberId': null,
        'phone': null,
        'name': null,
        'sessionCountText': null,
      };
    }

    final picked = await _openMemberMatchPickerSheet(
      typedName: inputText.trim(),
      lessonLabel: lessonLabel,
      candidates: candidates,
    );

    if (picked == null || picked['manual'] == true) {
      return {
        'memberId': null,
        'phone': null,
        'name': null,
        'sessionCountText': null,
      };
    }

    final remain = picked['remainingSessions'];
    final total = picked['totalSessions'];

    final remainValue = remain is num
        ? remain.toInt()
        : int.tryParse((remain ?? '').toString()) ?? 0;

    final totalValue = total is num
        ? total.toInt()
        : int.tryParse((total ?? '').toString()) ?? 0;

    return {
      'memberId': picked['id']?.toString(),
      'phone': _normalizePhone(picked['phone']?.toString() ?? ''),
      'name': picked['name']?.toString(),
      'sessionCountText': totalValue > 0 ? '$remainValue/$totalValue' : null,
    };
  }

  Future<void> _openClientCardFromManualSchedule({
    required String memberName,
    String? phone,
    String? scheduleDocId,
  }) async {
    final cleanName = memberName.trim();
    final cleanPhone = _normalizePhone(phone ?? '');

    if (cleanName.isEmpty) {
      _showActionToast(context, '회원 이름을 먼저 입력해주세요.', bottomOffset: 110);
      return;
    }

    final newId = FirebaseFirestore.instance.collection('members').doc().id;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.fromQuickRegistration(
          memberId: newId,
          initialName: cleanName,
          initialPhone: cleanPhone,
          initialVisitDate: DateTime.now(),
          initialConsultDate: null,
        ),
      ),
    );

    if (!mounted) return;

    final memberSnap = await FirebaseFirestore.instance
        .collection('members')
        .doc(newId)
        .get();

    if (!memberSnap.exists) {
      _showActionToast(
        context,
        '회원 등록이 완료되지 않아 미등록 상태로 유지되었어요.',
        bottomOffset: 110,
      );
      return;
    }

    final memberData = memberSnap.data() ?? <String, dynamic>{};
    final countFields = _memberSessionCountFieldsFromData(memberData);

    final docId = scheduleDocId?.trim() ?? '';

    if (docId.isNotEmpty) {
      await _applyMemberLinkToSchedule(
        scheduleDocId: docId,
        memberId: newId,
        phone: cleanPhone,
        sessionCountFields: countFields,
      );
    }

    if (!mounted) return;
    _showActionToast(context, '회원으로 등록하고 수업일정에 연결했어요.', bottomOffset: 110);
  }

  Future<void> _applyMemberLinkToSchedule({
    required String scheduleDocId,
    required String memberId,
    String? phone,
    Map<String, String> sessionCountFields = const {},
  }) async {
    final cleanDocId = scheduleDocId.trim();
    final cleanMemberId = memberId.trim();
    final cleanPhone = _normalizePhone(phone ?? '');

    if (cleanDocId.isEmpty || cleanMemberId.isEmpty) return;

    await FirebaseFirestore.instance.collection('schedules').doc(cleanDocId).set({
      'memberId': cleanMemberId,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      if (sessionCountFields['remainingSessions'] != null)
        'remainingSessions': sessionCountFields['remainingSessions'],
      if (sessionCountFields['totalSessions'] != null)
        'totalSessions': sessionCountFields['totalSessions'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final upsert = <String, Map<String, dynamic>>{};

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final currentDocId = (value['docId'] ?? '').toString().trim();
      if (currentDocId != cleanDocId) return;

      upsert[key] = {
        ...Map<String, dynamic>.from(value),
        'memberId': cleanMemberId,
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
        if (sessionCountFields['remainingSessions'] != null)
          'remainingSessions': sessionCountFields['remainingSessions'],
        if (sessionCountFields['totalSessions'] != null)
          'totalSessions': sessionCountFields['totalSessions'],
      };
    });

    if (upsert.isNotEmpty) {
      _patchScheduleData(
        upsert: upsert,
        syncWidget: true,
      );
    }

    await _refreshMemberNextLesson(cleanMemberId);
    await _refreshScheduleCountsFromMembers();
  }

  Future<void> _linkManualScheduleToExistingMember({
    required String memberName,
    required String scheduleDocId,
  }) async {
    final cleanName = memberName.trim();
    final cleanDocId = scheduleDocId.trim();

    if (cleanName.isEmpty) {
      _showActionToast(context, '회원 이름을 먼저 입력해주세요.', bottomOffset: 110);
      return;
    }

    if (cleanDocId.isEmpty) {
      _showActionToast(context, '연결할 수업일정을 찾지 못했어요.', bottomOffset: 110);
      return;
    }

    final candidates = await _findExactMemberCandidates(cleanName);

    if (!mounted) return;

    if (candidates.isEmpty) {
      _showActionToast(context, '같은 이름의 기존 회원을 찾지 못했어요.', bottomOffset: 110);
      return;
    }

    final picked = await _openMemberMatchPickerSheet(
      typedName: cleanName,
      lessonLabel: '이 수업',
      candidates: candidates,
    );

    if (!mounted || picked == null || picked['manual'] == true) return;

    final memberId = picked['id']?.toString() ?? '';
    final phone = picked['phone']?.toString() ?? '';

    final remain = picked['remainingSessions'];
    final total = picked['totalSessions'];

    final remainValue = remain is num
        ? remain.toInt()
        : int.tryParse((remain ?? '').toString()) ?? 0;

    final totalValue = total is num
        ? total.toInt()
        : int.tryParse((total ?? '').toString()) ?? 0;

    final countFields = <String, String>{};
    if (totalValue > 0 || remainValue > 0) {
      countFields['remainingSessions'] = remainValue.toString();
      countFields['totalSessions'] = totalValue.toString();
    }

    await _applyMemberLinkToSchedule(
      scheduleDocId: cleanDocId,
      memberId: memberId,
      phone: phone,
      sessionCountFields: countFields,
    );

    if (!mounted) return;
    _showActionToast(context, '기존 회원과 수업일정을 연결했어요.', bottomOffset: 110);
  }

  Future<void> _openClientCardFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    final resolvedMemberId = await _resolveLinkedMemberId(
      memberId: memberId,
      memberName: memberName,
      phone: phone,
    );

    if (!mounted) return;

    if (resolvedMemberId == null || resolvedMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 회원카드를 열 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage(
          memberId: resolvedMemberId,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshScheduleCountsFromMembers();
  }

  Future<void> _openWorkoutLogFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    final resolvedMemberId = await _resolveLinkedMemberId(
      memberId: memberId,
      memberName: memberName,
      phone: phone,
    );

    if (!mounted) return;

    if (resolvedMemberId == null || resolvedMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 수업일지를 열 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: resolvedMemberId,
          memberName: memberName,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshScheduleCountsFromMembers();
  }

  Future<void> _openQuickSignFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
    String? scheduleDocId,
    String lessonType = 'PT수업',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final cleanMemberId = memberId?.trim() ?? '';

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 빠른 서명을 사용할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingQuickLogSignPage(
          memberId: cleanMemberId,
          memberName: memberName,
          memberPhone: phone,
          scheduleDocId: scheduleDocId,
          lessonType: lessonType,
          startAt: startAt,
          endAt: endAt,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _refreshScheduleCountsFromMembers();
    }
  }

  String _generateMemberSignToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random.secure();

    return List.generate(
      32,
          (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _buildMemberSignUrl(String token) {
    return '$kMemberSignBaseUrl?t=$token';
  }

  String _quickSignLogIdFromSchedule({
    required String memberId,
    String? scheduleDocId,
    DateTime? startAt,
  }) {
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanScheduleDocId.isNotEmpty) {
      return 'quick_sign_$cleanScheduleDocId';
    }

    final start = startAt ?? DateTime.now();
    final y = start.year.toString().padLeft(4, '0');
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    final h = start.hour.toString().padLeft(2, '0');
    final min = start.minute.toString().padLeft(2, '0');

    return 'quick_sign_${memberId}_${y}${m}${d}_$h$min';
  }

  Future<Map<String, String>?> _createMemberSignRequestFromSchedule({
    required String memberId,
    required String memberName,
    String? memberPhone,
    String? scheduleDocId,
    String lessonType = 'PT수업',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final cleanMemberId = memberId.trim();
    final cleanMemberName = memberName.trim();
    final cleanPhone = _normalizePhone(memberPhone ?? '');
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 서명 요청을 만들 수 있어요.',
        bottomOffset: 110,
      );
      return null;
    }

    final token = _generateMemberSignToken();
    final link = _buildMemberSignUrl(token);

    final effectiveStartAt = startAt ?? DateTime.now();
    final effectiveEndAt =
        endAt ?? effectiveStartAt.add(const Duration(minutes: 50));

    final trainingLogId = _quickSignLogIdFromSchedule(
      memberId: cleanMemberId,
      scheduleDocId: cleanScheduleDocId,
      startAt: effectiveStartAt,
    );

    final existingLog = await FirebaseFirestore.instance
        .collection('training_logs')
        .doc(trainingLogId)
        .get();

    final existingLogData = existingLog.data();

    if (existingLogData != null) {
      final locked = existingLogData['locked'] == true;
      final deductionApplied = existingLogData['deductionApplied'] == true;
      final waitingTrainerConfirm =
          existingLogData['waitingTrainerConfirm'] == true;
      final memberSigned = existingLogData['memberSigned'] == true;

      if (locked || deductionApplied) {
        _showActionToast(
          context,
          '이미 QUICK SIGN으로 확정된 수업이에요.',
          bottomOffset: 110,
        );
      }

      if (waitingTrainerConfirm || memberSigned) {
        _showActionToast(
          context,
          '이미 REMOTE SIGN 서명이 도착했어요. 빠른서명에서 확인해 주세요.',
          bottomOffset: 110,
        );
        return null;
      }
    }

    await FirebaseFirestore.instance.collection('sign_requests').doc(token).set({
      'token': token,
      'status': 'waiting_member_signature',
      'used': false,

      'memberId': cleanMemberId,
      'memberName': cleanMemberName.isEmpty ? '회원' : cleanMemberName,
      if (cleanPhone.isNotEmpty) 'memberPhone': cleanPhone,

      if (cleanScheduleDocId.isNotEmpty) 'scheduleDocId': cleanScheduleDocId,
      'trainingLogId': trainingLogId,

      'lessonType': lessonType,
      'startAt': Timestamp.fromDate(effectiveStartAt),
      'endAt': Timestamp.fromDate(effectiveEndAt),

      'requestType': 'member_signature',
      'source': 'trainer_app',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    }, SetOptions(merge: true));

    return {
      'token': token,
      'link': link,
      'trainingLogId': trainingLogId,
    };
  }

  Future<void> _openMemberSignRequestSheet({
    required String memberId,
    required String memberName,
    String? memberPhone,
    String? scheduleDocId,
    String lessonType = 'PT수업',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final result = await _createMemberSignRequestFromSchedule(
      memberId: memberId,
      memberName: memberName,
      memberPhone: memberPhone,
      scheduleDocId: scheduleDocId,
      lessonType: lessonType,
      startAt: startAt,
      endAt: endAt,
    );

    if (!mounted || result == null) return;

    final link = result['link'] ?? '';
    if (link.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '회원 서명 요청',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${memberName.trim().isEmpty ? '회원' : memberName.trim()} 님에게 서명 링크를 공유하세요.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 210,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: link),
                            );

                            if (!mounted) return;
                            _showActionToast(
                              sheetContext,
                              '서명 링크를 복사했어요.',
                              bottomOffset: 110,
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            '링크 복사',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: BorderSide(
                              color: kPrimaryColor.withOpacity(0.25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            '완료',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '링크는 이 수업의 이 회원에게만 연결돼요. 웹 서명 페이지가 연결되면 회원 서명이 수업일지에 자동 반영됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.8,
                      height: 1.35,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCellTap(String day, String time, bool hasSession, int weekOffset) {
    final key = _makeKey(weekOffset, day, time);
    final raw = scheduleData[key];

    if (raw is Map<String, dynamic>) {
      _openLessonEditorSheet(
        day,
        time,
        weekOffset,
        existingSession: Map<String, dynamic>.from(raw),
      );
      return;
    }

    _openLessonEditorSheet(day, time, weekOffset);
  }

  String _lessonSlotKey(String day, String time) {
    return '$day|$time';
  }
  DateTime _resolveSessionEndAt(Map<String, dynamic> session) {
    final start = session['startAt'];
    if (start is! DateTime) return DateTime.now();

    final end = session['endAt'];
    if (end is DateTime) return end;

    return start.add(Duration(minutes: _defaultLessonDurationMinutes));
  }

  bool _timeRangeOverlaps({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  Future<List<Map<String, dynamic>>> _findMoveConflicts({
    required int weekOffset,
    required String originalDay,
    required String originalTime,
    required Set<String> selectedDays,
    required String editableTime,
    required String editableEndTime,
    required Map<String, dynamic> existingSession,
  }) async {
    final conflicts = <Map<String, dynamic>>[];
    final originalDocId = existingSession['docId']?.toString().trim() ?? '';

    for (final d in selectedDays) {
      final targetStartAt = _dateForCell(weekOffset, d, editableTime);
      final targetEndAt = _dateForCell(weekOffset, d, editableEndTime);

      if (!targetEndAt.isAfter(targetStartAt)) continue;

      for (final value in scheduleData.values) {
        if (value is! Map<String, dynamic>) continue;

        final candidateDocId = value['docId']?.toString().trim() ?? '';
        if (candidateDocId.isEmpty) continue;
        if (candidateDocId == originalDocId) continue;

        final rawStartAt = value['startAt'];
        if (rawStartAt is! DateTime) continue;

        final candidateDay = _weekDaysAll[rawStartAt.weekday - 1];
        if (candidateDay != d) continue;

        final candidateEndAt = _resolveSessionEndAt(value);

        final overlaps = _timeRangeOverlaps(
          startA: targetStartAt,
          endA: targetEndAt,
          startB: rawStartAt,
          endB: candidateEndAt,
        );

        if (!overlaps) continue;

        conflicts.add({
          'day': d,
          'time': '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}',
          'endTime': '${candidateEndAt.hour.toString().padLeft(2, '0')}:${candidateEndAt.minute.toString().padLeft(2, '0')}',
          'docId': candidateDocId,
          'name': (value['name'] ?? '').toString(),
        });
      }
    }

    final unique = <String, Map<String, dynamic>>{};
    for (final item in conflicts) {
      final docId = item['docId']?.toString() ?? '';
      if (docId.isEmpty) continue;
      unique[docId] = item;
    }

    return unique.values.toList();
  }

  Future<bool> _saveEditedLessonSchedule({
    required int weekOffset,
    required String originalDay,
    required String originalTime,
    required Set<String> selectedDays,
    required String editableTime,
    required String editableEndTime,
    required String resolvedName,
    required LessonTypeItem lessonType,
    required bool attended,
    required Map<String, dynamic> countMap,
    String? memberId,
    String? phone,
    String? memo,
    required Map<String, dynamic> existingSession,

  }) async {

    final originalDocId = existingSession['docId']?.toString().trim() ?? '';
    if (originalDocId.isEmpty) return false;

    final originalSlotKey = _lessonSlotKey(originalDay, originalTime);
    final newSlots = selectedDays.map((d) => _lessonSlotKey(d, editableTime)).toSet();
    final shouldDeleteOriginal = !newSlots.contains(originalSlotKey);

    final batch = FirebaseFirestore.instance.batch();
    final localRemoves = <String>{};
    final localWrites = <Map<String, dynamic>>[];
    final affectedMemberIds = <String>{};

    final previousMemberId =
    (existingSession['memberId'] ?? '').toString().trim();

    if (previousMemberId.isNotEmpty) {
      affectedMemberIds.add(previousMemberId);
    }

    if ((memberId ?? '').trim().isNotEmpty) {
      affectedMemberIds.add(memberId!.trim());
    }

    if (shouldDeleteOriginal) {
      batch.delete(
        FirebaseFirestore.instance.collection('schedules').doc(originalDocId),
      );

      final originalKey = _makeKey(weekOffset, originalDay, originalTime);
      localRemoves.add(originalKey);
    }

    for (final d in selectedDays) {
      final dt = _dateForCell(weekOffset, d, editableTime);
      final endDt = _dateForCell(weekOffset, d, editableEndTime);

      if (!endDt.isAfter(dt)) {
        return false;
      }
      final targetDocId = _scheduleDocIdFromDate(dt, d);
      final targetKey = _absoluteKeyFromDate(dt);

      final firestoreData = <String, dynamic>{
        'startAt': Timestamp.fromDate(dt),
        'day': d,
        'time': editableTime,
        'name': resolvedName,
        'type': lessonType.name,
        'typeName': lessonType.name,
        'typeId': lessonType.id,
        'typeColorHex': lessonType.colorHex,
        'attended': d == originalDay && editableTime == originalTime ? attended : false,
        'updatedAt': FieldValue.serverTimestamp(),
        'endAt': Timestamp.fromDate(endDt),
        'endTime': editableEndTime,
        if (memberId != null && memberId.trim().isNotEmpty) 'memberId': memberId.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
        ...countMap,
      };

      batch.set(
        FirebaseFirestore.instance.collection('schedules').doc(targetDocId),
        firestoreData,
        SetOptions(merge: true),
      );

      localWrites.add({
        'key': targetKey,
        'data': {
          ...existingSession,
          'docId': targetDocId,
          'startAt': dt,
          'day': d,
          'time': editableTime,
          'name': resolvedName,
          'type': lessonType.name,
          'typeId': lessonType.id,
          'typeColorHex': lessonType.colorHex,
          'attended': d == originalDay && editableTime == originalTime ? attended : false,
          'endAt': endDt,
          'endTime': editableEndTime,
          if (memberId != null && memberId.trim().isNotEmpty) 'memberId': memberId.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
          ...countMap,
        },
      });
    }

    try {
      await batch.commit();

      final removeKeys = localRemoves.toList();
      final upsert = <String, Map<String, dynamic>>{};

      for (final item in localWrites) {
        final key = item['key'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map<String, dynamic>);
        upsert[key] = data;
      }

      _patchScheduleData(
        removeKeys: removeKeys,
        upsert: upsert,
        syncWidget: false,
      );

      for (final memberId in affectedMemberIds) {
        await _refreshMemberNextLesson(memberId);
      }

      if (mounted) {
        unawaited(_syncHomeWidgetPreview());
      }

      return true;
    } catch (e) {
      debugPrint('수업일정 수정 저장 실패: $e');
      return false;
    }
  }

  Future<_LessonSaveResult> _handleLessonSave({
    required bool isEditMode,
    required int weekOffset,
    required String originalDay,
    required String originalTime,
    required Set<String> selectedDays,
    required String editableTime,
    required String editableEndTime,
    required String typedName,
    required LessonTypeItem lessonType,
    required TextEditingController sessionCountController,
    required Map<String, dynamic>? existingSession,
    required TextEditingController memoController,
    String? selectedMemberId,
    String? selectedMemberPhone,
  }) async {
    if (typedName.isEmpty) {
      _showError('이름을 입력해주세요.');
      return const _LessonSaveResult.failed();
    }

    final resolvedMember = await _resolveMemberLinkBeforeSave(
      inputText: typedName,
      lessonLabel: '${_formatLessonSheetTime(editableTime)} 수업',
      selectedMemberId: selectedMemberId,
      selectedMemberPhone: selectedMemberPhone,
    );

    if (resolvedMember == null) {
      return const _LessonSaveResult.failed();
    }

    final resolvedMemberId = resolvedMember['memberId']?.trim() ?? '';
    final resolvedPhone = _normalizePhone(resolvedMember['phone'] ?? '');
    final resolvedName =
    (resolvedMember['name']?.trim().isNotEmpty ?? false)
        ? resolvedMember['name']!.trim()
        : typedName;

    Map<String, dynamic> countMap = _parseSessionCount(sessionCountController.text);

    final resolvedSessionCountText =
    (resolvedMember['sessionCountText'] ?? '').trim();

    if (resolvedMemberId.isNotEmpty) {
      String linkedSessionCountText = resolvedSessionCountText;

      if (linkedSessionCountText.isEmpty) {
        linkedSessionCountText = await _loadMemberSessionCountText(resolvedMemberId);
      }

      if (linkedSessionCountText.isNotEmpty) {
        sessionCountController.text = linkedSessionCountText;
        countMap = _parseSessionCount(linkedSessionCountText);
      } else {
        countMap = {};
      }
    }

    final memoText = memoController.text.trim();

    for (final d in selectedDays) {
      final targetStartAt = _dateForCell(weekOffset, d, editableTime);
      final targetEndAt = _dateForCell(weekOffset, d, editableEndTime);

      if (!targetEndAt.isAfter(targetStartAt)) {
        _showError('종료 시간은 시작 시간보다 늦어야 해요.');
        return const _LessonSaveResult.failed();
      }

      if (isEditMode) {
        final conflicts = await _findMoveConflicts(
          weekOffset: weekOffset,
          originalDay: originalDay,
          originalTime: originalTime,
          selectedDays: {d},
          editableTime: editableTime,
          editableEndTime: editableEndTime,
          existingSession: existingSession!,
        );

        if (conflicts.isNotEmpty) {
          _showError('겹치는 시간의 수정일정이 있어요.');
          return const _LessonSaveResult.failed();
        }
      } else {
        for (final raw in scheduleData.values) {
          final item = _scheduleItemFromRaw(raw);
          if (item == null) continue;
          if (item.day != d) continue;

          final overlaps = _timeRangeOverlaps(
            startA: targetStartAt,
            endA: targetEndAt,
            startB: item.startAt,
            endB: item.endAt,
          );

          if (overlaps) {
            _showError('겹치는 시간의 수업일정이 있어요.');
            return const _LessonSaveResult.failed();
          }
        }
      }
    }

    if (isEditMode) {
      final saved = await _saveEditedLessonSchedule(
        weekOffset: weekOffset,
        originalDay: originalDay,
        originalTime: originalTime,
        selectedDays: selectedDays,
        editableTime: editableTime,
        editableEndTime: editableEndTime,
        resolvedName: resolvedName,
        lessonType: lessonType,
        attended: existingSession?['attended'] == true,
        countMap: countMap,
        memberId: resolvedMemberId.isNotEmpty ? resolvedMemberId : null,
        phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
        existingSession: existingSession!,
        memo: memoText.isNotEmpty ? memoText : null,
      );

      if (!saved) {
        _showError('수업일정 저장에 실패했어요.');
        return const _LessonSaveResult.failed();
      }
    } else {
      try {
        for (final d in selectedDays) {
          await _saveScheduleToFirestore(
            weekOffset: weekOffset,
            day: d,
            time: editableTime,
            endTime: editableEndTime,
            name: resolvedName,
            lessonType: lessonType,
            attended: false,
            countMap: countMap,
            memberId: resolvedMemberId.isNotEmpty ? resolvedMemberId : null,
            phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
            memo: memoText.isNotEmpty ? memoText : null,
          );
        }

        if (resolvedMemberId.isNotEmpty) {
          await _refreshMemberNextLesson(resolvedMemberId);
        }
      } catch (_) {
        _showError('수업일정 저장에 실패했어요.');
        return const _LessonSaveResult.failed();
      }
    }

    return _LessonSaveResult(
      success: true,
      isLinkedMember: resolvedMemberId.isNotEmpty,
    );
  }

  // _buildLessonEditorHeader() 메서드 전체 교체

  Widget _buildLessonEditorHeader({
    required BuildContext sheetContext,
    required bool isEditMode,
    required String day,
    required String editableTime,
    required String editableEndTime,
    required int weekOffset,
    required Map<String, dynamic>? existingSession,
    required VoidCallback onClose,
    required VoidCallback onTimeTap,
    required void Function(String? result) onAttendanceChanged,
  }) {
    final String currentStatusLabel = isEditMode && existingSession != null
        ? _sessionAttendanceLabel(day, editableTime, weekOffset, existingSession)
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFF9333EA),
          ],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 42,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2BFFFFFF),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
          ),

          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Divider(
              height: 1,
              color: Color(0x2EFFFFFF),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$day요일',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: GestureDetector(
                    onTap: onTimeTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _formatLessonSheetTime(editableTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.50),
                              height: 1.0,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            editableEndTime.isEmpty
                                ? '미설정'
                                : _formatLessonSheetTime(editableEndTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: editableEndTime.isEmpty
                                  ? Colors.white.withOpacity(0.40)
                                  : Colors.white.withOpacity(0.80),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                if (isEditMode && currentStatusLabel.isNotEmpty) ...[
                  GestureDetector(
                    onLongPress: () async {
                      HapticFeedback.mediumImpact();

                      final result = await _openAttendanceStatusSheet(
                        day,
                        editableTime,
                        weekOffset,
                        existingSession!,
                      );

                      onAttendanceChanged(result);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusChipBgColor(currentStatusLabel),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        currentStatusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _statusChipTextColor(currentStatusLabel),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                GestureDetector(
                  onTap: onClose,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLessonDaySection({
    required List<String> allDays,
    required Set<String> selectedDays,
    required VoidCallback onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allDays.map((d) {
        final bool isSelected = selectedDays.contains(d);

        return GestureDetector(
          onTap: () {
            if (isSelected) {
              if (selectedDays.length > 1) {
                selectedDays.remove(d);
              }
            } else {
              selectedDays.add(d);
            }
            onChanged();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? kPrimaryColor.withOpacity(0.10)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? kPrimaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              d,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? kPrimaryColor : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLessonTypeSection({
    required List<LessonTypeItem> lessonTypes,
    required String selectedTypeId,
    required ValueChanged<LessonTypeItem> onSelected,
    required VoidCallback onAddTap,
    required ValueChanged<LessonTypeItem> onChipLongPress,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...lessonTypes.map((item) {
          final bool isSelected = selectedTypeId == item.id;
          final Color baseColor = _colorFromHex(item.colorHex);

          // 선택 시 → 진한 배경 (블럭 색과 동일)
          // 미선택 시 → 파스텔 배경
          final Color bgColor = isSelected
              ? baseColor
              : baseColor.withOpacity(0.12);

          final Color textColor = isSelected
              ? Colors.white
              : baseColor;

          return GestureDetector(
            onLongPress: () => onChipLongPress(item),
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? baseColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? baseColor : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.0 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.28),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : null,
              ),
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }),
        // 추가 버튼
        GestureDetector(
          onTap: onAddTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                width: 0.9,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(width: 3),
                Text(
                  '추가',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberConnectionHintBubble({
    required bool visible,
    required bool hasLinkedMember,
    required String currentNameText,
    String? selectedMemberPhone,
  }) {
    final hasInput = currentNameText.trim().isNotEmpty;
    final phoneLabel = _normalizePhone(selectedMemberPhone ?? '').isEmpty
        ? ''
        : _formatPhoneDisplay(selectedMemberPhone ?? '');

    final Color bgColor = hasLinkedMember
        ? const Color(0xFFECFDF5)
        : hasInput
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF8FAFC);

    final Color borderColor = hasLinkedMember
        ? const Color(0xFFBBF7D0)
        : hasInput
        ? const Color(0xFFFED7AA)
        : const Color(0xFFE5E7EB);

    final Color iconColor = hasLinkedMember
        ? const Color(0xFF059669)
        : hasInput
        ? const Color(0xFFEA580C)
        : const Color(0xFF6B7280);

    final String title = hasLinkedMember
        ? '회원 연결됨'
        : hasInput
        ? '미등록 회원 수업입니다'
        : '회원을 선택하거나 이름을 입력해 주세요';

    final String subtitle = hasLinkedMember
        ? [
      if (phoneLabel.isNotEmpty) phoneLabel,
      '회원카드와 수업일지로 바로 이동할 수 있어요.',
    ].join(' · ')
        : hasInput
        ? '회차정보를 직접 입력할 수 있어요.'
        : '최근 조회 회원을 누르면 자동으로 연결돼요.';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: visible
          ? Container(
        key: ValueKey('$title-$subtitle'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 7),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.98),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                hasLinkedMember
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                size: 16,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.8,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLessonMemberInputSection({
    required TextEditingController nameController,
    required TextEditingController sessionCountController,
    required ValueChanged<String> onNameChanged,
    required VoidCallback onClearName,
    required bool hasLinkedMember,
    required VoidCallback onNameTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이름 / 번호
        Expanded(
          flex: 5,
          child: TextField(
            controller: nameController,
            onTap: onNameTap,
            onChanged: onNameChanged,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '이름 / 번호',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextHint,
              ),
              filled: true,
              fillColor: AppColors.lightSurface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorderFocus,
                  width: 1.0,
                ),
              ),
              suffixIcon: nameController.text.trim().isEmpty
                  ? null
                  : GestureDetector(
                onTap: onClearName,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.lightTextTertiary,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        // 회차 — 고정 너비 (5/30 짧은 숫자)
        SizedBox(
          width: 72,
          child: TextField(
            controller: sessionCountController,
            readOnly: hasLinkedMember,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '5/30',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextHint,
              ),
              filled: true,
              fillColor: hasLinkedMember
                  ? const Color(0xFFF3F4F6)
                  : AppColors.lightSurface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorderFocus,
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonMemoSection({
    required TextEditingController memoController,
  }) {
    return TextField(
      controller: memoController,
      minLines: 1,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: '메모 (선택) — 예: 하체운동, 무릎 체크',
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.lightTextHint,
        ),
        filled: true,
        fillColor: AppColors.lightSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorderFocus,
            width: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentMembersSection({
    required BuildContext sheetContext,
    required String searchKeyword,
    required String normalizedKeyword,
    required void Function(
        String name,
        String memberId,
        String phone,
        String sessionCountText,
        ) onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 조회 회원',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await Future.delayed(const Duration(milliseconds: 120));
                if (!mounted) return;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClientListPage(),
                  ),
                );
              },
              child: const Text(
                '전체보기',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('members')
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '회원 목록을 불러오지 못했습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;
            final seen = <String>{};

            final members = docs
                .map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString().trim();
              final phone = (data['phone'] ?? '').toString().trim();
              return {
                'id': doc.id,
                'name': name,
                'phone': phone,
                'sessionCountText': _sessionCountTextFromMemberData(data),
              };
            })
                .where((m) {
              final name = (m['name'] ?? '').trim();
              final phone = (m['phone'] ?? '').trim();
              if (name.isEmpty && phone.isEmpty) return false;

              final key = '$name|$phone';
              if (seen.contains(key)) return false;
              seen.add(key);

              if (searchKeyword.isEmpty) return true;

              final nameMatch = _matchesNameKeyword(name, searchKeyword);
              final phoneMatch = normalizedKeyword.isNotEmpty &&
                  _normalizePhone(phone).contains(normalizedKeyword);

              return nameMatch || phoneMatch;
            })
                .take(5)
                .toList();

            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '검색되는 회원이 없습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final member = index < members.length ? members[index] : null;
                  final name = member?['name']?.trim();

                  return Expanded(
                    child: Center(
                      child: _RecentMemberBubble(
                        name: name,
                        onTap: member == null
                            ? null
                            : () {
                          onPicked(
                            name ?? '',
                            member['id']?.toString() ?? '',
                            member['phone']?.toString() ?? '',
                            member['sessionCountText']?.toString() ?? '',
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLessonQuickActionsSection({
    required bool hasLinkedMember,
    required String memberName,
    required String? memberId,
    required String? memberPhone,
    required String? scheduleDocId,
    required String lessonType,
    required DateTime? startAt,
    required DateTime? endAt,
    required BuildContext sheetContext,
    required VoidCallback onBeforeNavigate,
  }) {

    Widget buildQuickAction({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool enabled = true,
      Color? foregroundColor,
    }) {
      final color = foregroundColor ?? kPrimaryColor;

      return Opacity(
        opacity: enabled ? 1 : 0.42,
        child: IgnorePointer(
          ignoring: !enabled,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withOpacity(0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '빠른 작업',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 7,
          children: [
            if (hasLinkedMember) ...[
              buildQuickAction(
                label: '빠른 서명',
                icon: Icons.draw_rounded,
                foregroundColor: const Color(0xFF059669),
                onTap: () async {
                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _openQuickSignFromSchedule(
                    memberId: memberId,
                    memberName: memberName,
                    phone: memberPhone,
                    scheduleDocId: scheduleDocId,
                    lessonType: lessonType,
                    startAt: startAt,
                    endAt: endAt,
                  );
                },
              ),
              buildQuickAction(
                label: '서명 요청',
                icon: Icons.qr_code_2_rounded,
                foregroundColor: const Color(0xFF2563EB),
                onTap: () async {
                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _openMemberSignRequestSheet(
                    memberId: memberId ?? '',
                    memberName: memberName,
                    memberPhone: memberPhone,
                    scheduleDocId: scheduleDocId,
                    lessonType: lessonType,
                    startAt: startAt,
                    endAt: endAt,
                  );
                },
              ),
              buildQuickAction(
                label: '회원카드',
                icon: Icons.person_outline,
                onTap: () async {
                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _openClientCardFromSchedule(
                    memberId: memberId,
                    memberName: memberName,
                    phone: memberPhone,
                  );
                },
              ),
              buildQuickAction(
                label: '수업일지',
                icon: Icons.menu_book_outlined,
                onTap: () async {
                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _openWorkoutLogFromSchedule(
                    memberId: memberId,
                    memberName: memberName,
                    phone: memberPhone,
                  );
                },
              ),
            ] else ...[
              buildQuickAction(
                label: '기존 회원 연결',
                icon: Icons.link_rounded,
                foregroundColor: kPrimaryColor,
                onTap: () async {
                  final cleanName = memberName.trim();

                  if (cleanName.isEmpty) {
                    _showActionToast(
                      context,
                      '회원 이름을 먼저 입력해주세요.',
                      bottomOffset: 110,
                    );
                    return;
                  }

                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _linkManualScheduleToExistingMember(
                    memberName: cleanName,
                    scheduleDocId: scheduleDocId ?? '',
                  );
                },
              ),
              buildQuickAction(
                label: '내 회원으로 등록',
                icon: Icons.person_add_alt_1_rounded,
                foregroundColor: const Color(0xFFEA580C),
                onTap: () async {
                  final cleanName = memberName.trim();

                  if (cleanName.isEmpty) {
                    _showActionToast(
                      context,
                      '회원 이름을 먼저 입력해주세요.',
                      bottomOffset: 110,
                    );
                    return;
                  }

                  onBeforeNavigate();
                  await Future.delayed(const Duration(milliseconds: 120));
                  if (!mounted) return;

                  await _openClientCardFromManualSchedule(
                    memberName: cleanName,
                    phone: memberPhone,
                    scheduleDocId: scheduleDocId,
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLessonFooterActions({
    required BuildContext sheetContext,
    required bool isEditMode,
    required VoidCallback onCancel,
    required Future<void> Function() onDelete,
    required Future<void> Function() onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // 취소
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lightTextSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
            child: const Text(
              '취소',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          // 삭제 (수정 모드만)
          if (isEditMode) ...[
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text(
                '삭제',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 저장 — 그라데이션 버튼
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.lightGradientStart,
                  AppColors.lightGradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightGradientStart.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                '저장',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLessonEditorSheet(

      String day,
      String time,
      int weekOffset, {
        Map<String, dynamic>? existingSession,
      }) async {
    final bool isEditMode = existingSession != null;

    final nameController = TextEditingController(
      text: existingSession?['name']?.toString() ?? '',
    );

    final sessionCountController = TextEditingController(
      text: _buildSessionCountText(existingSession),
    );

    final memoController = TextEditingController(
      text: existingSession?['memo']?.toString() ?? '',
    );

    final List<LessonTypeItem> localLessonTypes =
    (_lessonTypes.isNotEmpty ? _lessonTypes : _buildSeedLessonTypes())
        .map((e) => e.copyWith())
        .toList();

    if (isEditMode && existingSession != null) {
      final existingType = _resolveLessonTypeForSchedule(existingSession);
      final exists = localLessonTypes.any(
            (e) => e.id == existingType.id || e.name == existingType.name,
      );
      if (!exists) {
        localLessonTypes.add(existingType);
      }
    }

    String selectedLessonTypeId = (() {
      if (isEditMode && existingSession != null) {
        final existingType = _resolveLessonTypeForSchedule(existingSession);
        final byId = localLessonTypes.where((e) => e.id == existingType.id);
        if (byId.isNotEmpty) return byId.first.id;

        final byName = localLessonTypes.where((e) =>
        e.name == existingType.name);
        if (byName.isNotEmpty) return byName.first.id;
      }

      if (_lastSelectedLessonTypeId.isNotEmpty &&
          localLessonTypes.any((e) => e.id == _lastSelectedLessonTypeId)) {
        return _lastSelectedLessonTypeId;
      }

      return localLessonTypes.first.id;
    })();

    final Set<String> selectedDays = {day};

    String? selectedMemberId = existingSession?['memberId']?.toString();
    String? selectedMemberPhone = existingSession?['phone']?.toString();

    final List<String> allDays = _weekDaysAll;

    String editableTime = time;

    String editableEndTime;

    if (isEditMode) {
      final existingEndAt = existingSession?['endAt'];

      if (existingEndAt is DateTime) {
        editableEndTime = _timeStringFromDateTime(existingEndAt);
      } else {
        final baseStart = _dateForCell(weekOffset, day, time);
        editableEndTime = _timeStringFromDateTime(
          baseStart.add(const Duration(minutes: _defaultLessonDurationMinutes)),
        );
      }
    } else {
      editableEndTime = '';
    }

    String? sheetToastMessage;
    Timer? sheetToastTimer;
    bool showMemberHint = false;
    Timer? memberHintTimer;
    bool showLessonTypeEditor = false;
    bool sheetAlive = true;
    String? editingLessonTypeId;
    String editingColorHex = localLessonTypes.first.colorHex;
    final lessonTypeNameController = TextEditingController();


    LessonTypeItem? getSelectedLessonType() {
      for (final item in localLessonTypes) {
        if (item.id == selectedLessonTypeId) return item;
      }
      return localLessonTypes.isNotEmpty ? localLessonTypes.first : null;
    }

    void showSheetToast(void Function(VoidCallback fn) setModalState,
        String message,) {
      if (!sheetAlive || !mounted) return;

      sheetToastTimer?.cancel();

      setModalState(() {
        sheetToastMessage = message;
      });

      sheetToastTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!sheetAlive || !mounted) return;

        setModalState(() {
          sheetToastMessage = null;
        });
      });
    }

    void openAddLessonTypeEditor(void Function(VoidCallback fn) setModalState) {
      setModalState(() {
        showLessonTypeEditor = true;
        editingLessonTypeId = null;
        editingColorHex = _colorToHex(_nextSeedColor(localLessonTypes.length));
        lessonTypeNameController.clear();
      });
    }

    void openEditLessonTypeEditor(LessonTypeItem item,
        void Function(VoidCallback fn) setModalState,) {
      setModalState(() {
        showLessonTypeEditor = true;
        editingLessonTypeId = item.id;
        editingColorHex = item.colorHex;
        lessonTypeNameController.text = item.name;
        lessonTypeNameController.selection = TextSelection.collapsed(
          offset: lessonTypeNameController.text.length,
        );
      });
    }

    void submitLessonTypeEditor(void Function(VoidCallback fn) setModalState) {
      final name = lessonTypeNameController.text.trim();
      if (name.isEmpty) {
        _showSnack('수업 종류 이름을 입력해주세요.');
        return;
      }

      final duplicated = localLessonTypes.any((e) {
        if (editingLessonTypeId != null && e.id == editingLessonTypeId) {
          return false;
        }
        return e.name == name;
      });

      if (duplicated) {
        _showSnack('이미 있는 수업 종류예요.');
        return;
      }

      FocusManager.instance.primaryFocus?.unfocus();

      setModalState(() {
        if (editingLessonTypeId == null) {
          final item = LessonTypeItem(
            id: _generateLessonTypeId(),
            name: name,
            colorHex: editingColorHex,
          );
          localLessonTypes.add(item);
          selectedLessonTypeId = item.id;
        } else {
          final index =
          localLessonTypes.indexWhere((e) => e.id == editingLessonTypeId);
          if (index >= 0) {
            localLessonTypes[index] = localLessonTypes[index].copyWith(
              name: name,
              colorHex: editingColorHex,
            );
            selectedLessonTypeId = localLessonTypes[index].id;
          }
        }

        showLessonTypeEditor = false;
        editingLessonTypeId = null;
        lessonTypeNameController.clear();
      });
    }

    void deleteEditingLessonType(void Function(VoidCallback fn) setModalState) {
      if (editingLessonTypeId == null) return;

      if (localLessonTypes.length <= 1) {
        _showSnack('수업 종류는 최소 1개는 남아 있어야 해요.');
        return;
      }

      FocusManager.instance.primaryFocus?.unfocus();

      setModalState(() {
        localLessonTypes.removeWhere((e) => e.id == editingLessonTypeId);

        if (!localLessonTypes.any((e) => e.id == selectedLessonTypeId)) {
          selectedLessonTypeId = localLessonTypes.first.id;
        }

        showLessonTypeEditor = false;
        editingLessonTypeId = null;
        lessonTypeNameController.clear();
      });
    }

    Map<String, dynamic> buildResult({String? snackMessage}) {
      return {
        'lessonTypes': localLessonTypes.map((e) => e.toMap()).toList(),
        'selectedLessonTypeId': selectedLessonTypeId,
        if (snackMessage != null) 'snackMessage': snackMessage,
      };
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery
                .of(sheetContext)
                .viewInsets
                .bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setModalState) {
              void safeSetModalState(VoidCallback fn) {
                if (!sheetAlive || !mounted) return;
                setModalState(fn);
              }
              final currentNameText = nameController.value.text.trim();
              final searchKeyword = currentNameText.toLowerCase();
              final normalizedKeyword = _normalizePhone(currentNameText);

              final bool hasLinkedMember = _hasLinkedMemberConnection(
                memberId: selectedMemberId,
                phone: selectedMemberPhone,
              );

              void showMemberConnectionHint() {
                memberHintTimer?.cancel();

                setModalState(() {
                  showMemberHint = true;
                });

                memberHintTimer = Timer(const Duration(milliseconds: 2100), () {
                  if (!mounted) return;
                  setModalState(() {
                    showMemberHint = false;
                  });
                });
              }

              return SafeArea(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLessonEditorHeader(
                            sheetContext: sheetContext,
                            isEditMode: isEditMode,
                            day: day,
                            editableTime: editableTime,
                            editableEndTime: editableEndTime,
                            weekOffset: weekOffset,
                            existingSession: existingSession,
                            onClose: () => Navigator.of(sheetContext).pop(),
                            onTimeTap: () async {
                              final picked = await _openLessonStartEndTimeDialog(
                                initialStartTime: editableTime,
                                initialEndTime: editableEndTime,
                              );
                              if (picked == null) return;

                              safeSetModalState(() {
                                editableTime = picked['startTime']!;
                                editableEndTime = picked['endTime']!;
                              });
                            },
                            onAttendanceChanged: (result) {
                              if (result == null || existingSession == null)
                                return;

                              safeSetModalState(() {
                                if (result.isEmpty) {
                                  existingSession.remove('attendanceOverride');
                                } else {
                                  existingSession['attendanceOverride'] =
                                      result;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          _buildLessonTypeSection(
                            lessonTypes: localLessonTypes,
                            selectedTypeId: selectedLessonTypeId,
                            onSelected: (item) {
                              setModalState(() {
                                selectedLessonTypeId = item.id;
                              });
                            },
                            onAddTap: () =>
                                openAddLessonTypeEditor(setModalState),
                            onChipLongPress: (item) =>
                                openEditLessonTypeEditor(item, setModalState),
                          ),

                          if (showLessonTypeEditor) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        11, 8, 11, 8),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF7C3AED),
                                          Color(0xFF9333EA),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            editingLessonTypeId == null
                                                ? '새 수업 종류 추가'
                                                : '수업 종류 수정',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            setModalState(() {
                                              showLessonTypeEditor = false;
                                              editingLessonTypeId = null;
                                              lessonTypeNameController.clear();
                                            });
                                          },
                                          child: const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: Color(0xB3FFFFFF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        11, 9, 11, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Stack(
                                          children: [
                                            TextField(
                                              controller: lessonTypeNameController,
                                              maxLength: 8,
                                              buildCounter: (context, {
                                                required currentLength,
                                                required isFocused,
                                                maxLength,
                                              }) =>
                                              null,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF374151),
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '예: 발레핏, 재활수업',
                                                hintStyle: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF9CA3AF),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                filled: true,
                                                fillColor: const Color(
                                                    0xFFF8FAFF),
                                                contentPadding: const EdgeInsets
                                                    .fromLTRB(10, 8, 42, 8),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius
                                                      .circular(9),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFE5E7EB),
                                                    width: 0.7,
                                                  ),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius
                                                      .circular(9),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFE5E7EB),
                                                    width: 0.7,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius
                                                      .circular(9),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF4F46E5),
                                                    width: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 9,
                                              bottom: 8,
                                              child: ValueListenableBuilder<
                                                  TextEditingValue>(
                                                valueListenable: lessonTypeNameController,
                                                builder: (context, value, _) {
                                                  return Text(
                                                    '${value.text.length}/8',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight
                                                          .w700,
                                                      color: Color(0xFF9CA3AF),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        const Text(
                                          '색상 선택',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),

                                        const SizedBox(height: 7),

                                        Wrap(
                                          spacing: 7,
                                          runSpacing: 7,
                                          children: kLessonTypePalette.map((
                                              color) {
                                            final hex = _colorToHex(color);
                                            final selected = editingColorHex ==
                                                hex;

                                            return GestureDetector(
                                              onTap: () {
                                                setModalState(() {
                                                  editingColorHex = hex;
                                                });
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 140),
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: selected ? Colors
                                                        .white : Colors
                                                        .transparent,
                                                    width: 2,
                                                  ),
                                                  boxShadow: selected
                                                      ? [
                                                    BoxShadow(
                                                      color: color.withOpacity(
                                                          0.55),
                                                      blurRadius: 8,
                                                      spreadRadius: 1,
                                                      offset: const Offset(
                                                          0, 2),
                                                    ),
                                                    const BoxShadow(
                                                      color: Color(0xFF111827),
                                                      blurRadius: 0,
                                                      spreadRadius: 0.6,
                                                    ),
                                                  ]
                                                      : null,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),

                                        const SizedBox(height: 11),

                                        Row(
                                          children: [
                                            if (editingLessonTypeId !=
                                                null) ...[
                                              OutlinedButton(
                                                onPressed: () =>
                                                    deleteEditingLessonType(
                                                        setModalState),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: BorderSide(
                                                    color: Colors.red
                                                        .withOpacity(0.28),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 7,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize
                                                      .shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius
                                                        .circular(9),
                                                  ),
                                                ),
                                                child: const Text(
                                                  '삭제',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],

                                            TextButton(
                                              onPressed: () {
                                                FocusManager.instance
                                                    .primaryFocus?.unfocus();
                                                setModalState(() {
                                                  showLessonTypeEditor = false;
                                                  editingLessonTypeId = null;
                                                  lessonTypeNameController
                                                      .clear();
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(
                                                    0xFF9CA3AF),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 9,
                                                  vertical: 7,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize
                                                    .shrinkWrap,
                                              ),
                                              child: const Text(
                                                '취소',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),

                                            const Spacer(),

                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF4F46E5),
                                                    Color(0xFF9333EA),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius
                                                    .circular(9),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                        0xFF4F46E5).withOpacity(
                                                        0.22),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    submitLessonTypeEditor(
                                                        setModalState),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors
                                                      .transparent,
                                                  shadowColor: Colors
                                                      .transparent,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 15,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize
                                                      .shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius
                                                        .circular(9),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: Text(
                                                  editingLessonTypeId == null
                                                      ? '칩 추가'
                                                      : '수정 저장',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),
                          _buildLessonDaySection(
                            allDays: allDays,
                            selectedDays: selectedDays,
                            onChanged: () {
                              safeSetModalState(() {});
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildLessonMemberInputSection(
                            nameController: nameController,
                            sessionCountController: sessionCountController,
                            hasLinkedMember: hasLinkedMember,
                            onNameTap: showMemberConnectionHint,
                            onNameChanged: (_) {
                              safeSetModalState(() {
                                selectedMemberId = null;
                                selectedMemberPhone = null;
                              });
                              showMemberConnectionHint();
                            },
                            onClearName: () {
                              FocusManager.instance.primaryFocus?.unfocus();

                              safeSetModalState(() {
                                nameController.value = const TextEditingValue(
                                  text: '',
                                  selection: TextSelection.collapsed(offset: 0),
                                );
                                selectedMemberId = null;
                                selectedMemberPhone = null;
                              });
                              showMemberConnectionHint();
                            },
                          ),

                          _buildMemberConnectionHintBubble(
                            visible: showMemberHint,
                            hasLinkedMember: hasLinkedMember,
                            currentNameText: currentNameText,
                            selectedMemberPhone: selectedMemberPhone,
                          ),

                          const SizedBox(height: 10),
                          _buildLessonMemoSection(
                            memoController: memoController,
                          ),
                          if (!isEditMode) ...[
                            const SizedBox(height: 14),
                            _buildRecentMembersSection(
                              sheetContext: sheetContext,
                              searchKeyword: searchKeyword,
                              normalizedKeyword: normalizedKeyword,
                              onPicked: (name, memberId, phone,
                                  sessionCountText) {
                                safeSetModalState(() {
                                  nameController.value = TextEditingValue(
                                    text: name,
                                    selection: TextSelection.collapsed(
                                        offset: name.length),
                                  );
                                  selectedMemberId = memberId;
                                  selectedMemberPhone = phone;

                                  if (sessionCountText.isNotEmpty) {
                                    sessionCountController.value =
                                        TextEditingValue(
                                          text: sessionCountText,
                                          selection: TextSelection.collapsed(
                                              offset: sessionCountText.length),
                                        );
                                  }
                                });

                                showMemberConnectionHint();
                              },
                            ),
                          ],

                          if (isEditMode) ...[
                            const SizedBox(height: 14),
                            _buildLessonQuickActionsSection(
                              hasLinkedMember: hasLinkedMember,
                              memberName: nameController.text.trim(),
                              memberId: selectedMemberId,
                              memberPhone: selectedMemberPhone,
                              scheduleDocId: existingSession?['docId']
                                  ?.toString(),
                              lessonType: (existingSession?['typeName'] ??
                                  existingSession?['type'] ??
                                  'PT수업')
                                  .toString(),
                              startAt: existingSession?['startAt'] is DateTime
                                  ? existingSession!['startAt'] as DateTime
                                  : null,
                              endAt: existingSession?['endAt'] is DateTime
                                  ? existingSession!['endAt'] as DateTime
                                  : null,
                              sheetContext: sheetContext,
                              onBeforeNavigate: () {
                                final selectedLessonType = getSelectedLessonType();
                                if (selectedLessonType != null) {
                                  setState(() {
                                    _lessonTypes =
                                        localLessonTypes.map((e) =>
                                            e.copyWith()).toList();
                                    _lastSelectedLessonTypeId =
                                        selectedLessonType.id;
                                  });
                                  unawaited(_saveLessonTypePrefs());
                                }
                                Navigator.of(sheetContext).pop();
                              },
                            ),
                          ],

                          const SizedBox(height: 18),
                          const SizedBox(height: 36),

                          _buildLessonFooterActions(
                            sheetContext: sheetContext,
                            isEditMode: isEditMode,
                            onCancel: () => Navigator.of(sheetContext).pop(),
                            onDelete: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(
                                  const Duration(milliseconds: 10));

                              final docId =
                                  existingSession?['docId']
                                      ?.toString()
                                      .trim() ?? '';
                              if (docId.isEmpty) {
                                showSheetToast(
                                    setModalState, '삭제할 수업일정을 찾지 못했어요.');
                                return;
                              }

                              final deleted = await _deleteScheduleFromFirestore(
                                  docId);
                              if (!mounted) return;

                              if (!deleted) {
                                showSheetToast(
                                    setModalState, '수업일정 삭제에 실패했어요.');
                                return;
                              }

                              Navigator.of(sheetContext).pop(
                                buildResult(
                                  snackMessage: '$day $time 수업일정이 삭제되었어요.',
                                ),
                              );
                            },
                            onSave: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              await Future.delayed(
                                  const Duration(milliseconds: 10));

                              final selectedLessonType = getSelectedLessonType();
                              if (selectedLessonType == null) {
                                showSheetToast(setModalState, '수업 종류를 선택해주세요.');
                                return;
                              }

                              final typedName = nameController.text.trim();

                              if (editableEndTime
                                  .trim()
                                  .isEmpty) {
                                showSheetToast(setModalState, '종료 시간을 설정해주세요.');
                                return;
                              }

                              final saveResult = await _handleLessonSave(
                                isEditMode: isEditMode,
                                weekOffset: weekOffset,
                                originalDay: day,
                                originalTime: time,
                                selectedDays: selectedDays,
                                editableTime: editableTime,
                                editableEndTime: editableEndTime,
                                typedName: typedName,
                                lessonType: selectedLessonType,
                                sessionCountController: sessionCountController,
                                existingSession: existingSession,
                                selectedMemberId: selectedMemberId,
                                selectedMemberPhone: selectedMemberPhone,
                                memoController: memoController,
                              );

                              if (!saveResult.success) {
                                showSheetToast(
                                    setModalState, '수업일정을 저장하지 못했어요.');
                                return;
                              }

                              if (!mounted) return;

                              final orderedDays = _weekDaysAll
                                  .where((d) => selectedDays.contains(d))
                                  .toList();

                              final savedTypeLabel =
                              saveResult.isLinkedMember ? '회원 수업' : '미등록 회원 수업';

                              Navigator.of(sheetContext).pop(
                                buildResult(
                                  snackMessage:
                                  '${orderedDays.join(
                                      ', ')} ${_formatLessonSheetTime(
                                      editableTime)} ~ ${_formatLessonSheetTime(
                                      editableEndTime)} $savedTypeLabel으로 저장되었어요.',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 70,
                      child: IgnorePointer(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: sheetToastMessage == null
                              ? const SizedBox.shrink()
                              : Center(
                            key: ValueKey(sheetToastMessage),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 280),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withOpacity(
                                    0.94),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.16),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      sheetToastMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    sheetAlive = false;

    sheetToastTimer?.cancel();
    memberHintTimer?.cancel();

// 안정화 우선:
// 레슨 등록 바텀시트는 닫힘 애니메이션, 키보드 hide, TextField 정리 타이밍이 겹치면
// TextEditingController was used after being disposed 오류가 발생할 수 있습니다.
// 지금은 빨간 화면 방지를 우선해서 dispose를 하지 않습니다.
// 추후 이 바텀시트를 별도 StatefulWidget으로 분리한 뒤 State.dispose()에서 정리합니다.

    if (!mounted || result == null) return;

    final rawLessonTypes = (result['lessonTypes'] as List?) ?? const [];
    final nextLessonTypes = rawLessonTypes
        .whereType<Map>()
        .map((e) => LessonTypeItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final nextSelectedLessonTypeId =
    (result['selectedLessonTypeId'] ?? _lastSelectedLessonTypeId).toString();

    final safeSelectedId = nextLessonTypes.any((e) => e.id == nextSelectedLessonTypeId)
        ? nextSelectedLessonTypeId
        : (nextLessonTypes.isNotEmpty
        ? nextLessonTypes.first.id
        : _lastSelectedLessonTypeId);

    final snackMessage = result['snackMessage']?.toString();
    final nextLessonTypesSnapshot =
    nextLessonTypes.map((e) => e.copyWith()).toList();
    final nextSelectedLessonTypeIdSnapshot = safeSelectedId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        if (nextLessonTypesSnapshot.isNotEmpty) {
          _lessonTypes = nextLessonTypesSnapshot;
        }
        _lastSelectedLessonTypeId = nextSelectedLessonTypeIdSnapshot;
      });

      unawaited(_saveLessonTypePrefs());

      if (snackMessage != null && snackMessage.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 80), () {
          if (!mounted) return;
          _showActionToast(context, snackMessage, bottomOffset: 110);
        });
      }
    });
  }

  int _weekDaySortValue(String day) {
    return _weekDaysAll.indexOf(day);
  }

  List<Map<String, dynamic>> _buildWeekCopyPayload(int weekOffset) {
    final weekSlice = _buildWeekSlice(weekOffset);
    final entries = weekSlice.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split('-');
        final bParts = b.key.split('-');

        final aDay = aParts.first;
        final bDay = bParts.first;
        final aTime = aParts.length > 1 ? aParts.sublist(1).join('-') : '';
        final bTime = bParts.length > 1 ? bParts.sublist(1).join('-') : '';

        final dayCompare =
        _weekDaySortValue(aDay).compareTo(_weekDaySortValue(bDay));
        if (dayCompare != 0) return dayCompare;

        return aTime.compareTo(bTime);
      });

    final payload = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final raw = entry.value;
      if (raw is! Map<String, dynamic>) continue;

      final parts = entry.key.split('-');
      if (parts.length < 2) continue;

      final day = parts.first;
      final time = parts.sublist(1).join('-');

      payload.add({
        'day': day,
        'time': time,
        'name': (raw['name'] ?? '').toString(),
        'type': (raw['typeName'] ?? raw['type'] ?? 'PT수업').toString(),
        if (raw['typeId'] != null) 'typeId': raw['typeId'].toString(),
        if (raw['typeColorHex'] != null)
          'typeColorHex': raw['typeColorHex'].toString(),
        'endTime': raw['endTime']?.toString(),
        'memberId': raw['memberId']?.toString(),
        'phone': raw['phone']?.toString(),
        'remainingSessions': raw['remainingSessions']?.toString(),
        'totalSessions': raw['totalSessions']?.toString(),
      });
    }

    return payload;
  }

  Future<List<Map<String, dynamic>>> _findPasteConflictsForWeek(
      int weekOffset,
      List<Map<String, dynamic>> items,
      ) async {
    final conflicts = <Map<String, dynamic>>[];
    final seenDocIds = <String>{};

    for (final item in items) {
      final day = (item['day'] ?? '').toString().trim();
      final time = (item['time'] ?? '').toString().trim();
      final endTimeRaw = (item['endTime'] ?? '').toString().trim();

      if (day.isEmpty || time.isEmpty) continue;

      final startAt = _dateForCell(weekOffset, day, time);
      final endAt = endTimeRaw.isNotEmpty
          ? _dateForCell(weekOffset, day, endTimeRaw)
          : startAt.add(
        const Duration(minutes: _defaultLessonDurationMinutes),
      );

      if (!endAt.isAfter(startAt)) continue;

      for (final value in scheduleData.values) {
        if (value is! Map<String, dynamic>) continue;

        final docId = value['docId']?.toString().trim() ?? '';
        if (docId.isEmpty) continue;
        if (seenDocIds.contains(docId)) continue;

        final rawStartAt = value['startAt'];
        if (rawStartAt is! DateTime) continue;

        final existingDay = _weekDaysAll[rawStartAt.weekday - 1];
        if (existingDay != day) continue;

        final existingEndAt = _resolveSessionEndAt(value);

        final overlaps = _timeRangeOverlaps(
          startA: startAt,
          endA: endAt,
          startB: rawStartAt,
          endB: existingEndAt,
        );

        if (!overlaps) continue;

        seenDocIds.add(docId);
        conflicts.add({
          'docId': docId,
          'day': day,
          'time':
          '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}',
          'endTime':
          '${existingEndAt.hour.toString().padLeft(2, '0')}:${existingEndAt.minute.toString().padLeft(2, '0')}',
          'name': (value['name'] ?? '').toString(),
        });
      }
    }

    return conflicts;
  }

  Future<bool> _confirmWeekPasteOverwrite({
    required int conflictCount,
    required String targetLabel,
    List<Map<String, dynamic>> conflictExamples = const [],
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('같은 시간의 수업일정이 있어요'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$targetLabel 에 $conflictCount개의 겹치는 수업일정이 있어요.\n붙여넣으면 덮어써집니다.',
              ),
              if (conflictExamples.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '예시',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...conflictExamples.take(3).map((c) {
                  final day = (c['day'] ?? '').toString();
                  final time = (c['time'] ?? '').toString();
                  final endTime = (c['endTime'] ?? '').toString();
                  final name = (c['name'] ?? '').toString();

                  final timeLabel = endTime.isNotEmpty
                      ? '$time ~ $endTime'
                      : time;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $day $timeLabel ${name.isNotEmpty ? "($name)" : ""}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }),
                if (conflictExamples.length > 3)
                  Text(
                    '외 ${conflictExamples.length - 3}건',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('붙여넣기'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<bool> _confirmDeleteWeekSchedules({
    required String targetLabel,
    required int count,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('수업일정 전체 삭제'),
          content: Text(
            '$targetLabel 의 수업일정 $count개를 모두 삭제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('전체 삭제'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _copyWeekSchedules(int weekOffset) async {
    final payload = _buildWeekCopyPayload(weekOffset);

    if (payload.isEmpty) {
      _showSnack('복사할 수업일정이 없어요.');
      return;
    }

    setState(() {
      _copiedWeekSchedules = payload;
      _copiedWeekSourceLabel =
          _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');
    });

    _showSnack('${payload.length}개의 수업일정을 복사했어요.');
  }

  Future<void> _pasteWeekSchedules(int weekOffset) async {
    if (_copiedWeekSchedules.isEmpty) {
      _showSnack('먼저 복사한 수업일정이 있어야 해요.');
      return;
    }

    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');

    final conflicts = await _findPasteConflictsForWeek(
      weekOffset,
      _copiedWeekSchedules,
    );

    if (conflicts.isNotEmpty) {
      final confirmed = await _confirmWeekPasteOverwrite(
        conflictCount: conflicts.length,
        targetLabel: targetLabel,
        conflictExamples: conflicts,
      );

      if (!confirmed) return;
    }

    final affectedMemberIds = <String>{};

    for (final item in _copiedWeekSchedules) {
      final day = (item['day'] ?? '').toString().trim();
      final time = (item['time'] ?? '').toString().trim();
      final endTime = (item['endTime'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();

      if (day.isEmpty || time.isEmpty || name.isEmpty) continue;

      final startAt = _dateForCell(weekOffset, day, time);
      final resolvedEndTime = endTime.isNotEmpty
          ? endTime
          : _timeStringFromDateTime(
        startAt.add(
          const Duration(minutes: _defaultLessonDurationMinutes),
        ),
      );

      final countMap = <String, dynamic>{};
      final remainingSessions =
      (item['remainingSessions'] ?? '').toString().trim();
      final totalSessions =
      (item['totalSessions'] ?? '').toString().trim();

      if (remainingSessions.isNotEmpty) {
        countMap['remainingSessions'] = remainingSessions;
      }
      if (totalSessions.isNotEmpty) {
        countMap['totalSessions'] = totalSessions;
      }

      final memberId = (item['memberId'] ?? '').toString().trim();
      final phone = _normalizePhone((item['phone'] ?? '').toString());

      if (memberId.isNotEmpty) {
        affectedMemberIds.add(memberId);
      }

      final copiedTypeId = (item['typeId'] ?? '').toString().trim();
      final copiedTypeName = (item['type'] ?? 'PT수업').toString().trim();
      final copiedTypeColorHex =
      (item['typeColorHex'] ?? '').toString().trim();

      final lessonType = copiedTypeId.isNotEmpty
          ? (_findLessonTypeById(copiedTypeId, _lessonTypes) ??
          LessonTypeItem(
            id: copiedTypeId,
            name: copiedTypeName.isEmpty ? 'PT수업' : copiedTypeName,
            colorHex: copiedTypeColorHex.isNotEmpty
                ? copiedTypeColorHex
                : _lessonTypeColorHexByName(copiedTypeName),
          ))
          : (_findLessonTypeByName(copiedTypeName, _lessonTypes) ??
          LessonTypeItem(
            id: _generateLessonTypeId(),
            name: copiedTypeName.isEmpty ? 'PT수업' : copiedTypeName,
            colorHex: copiedTypeColorHex.isNotEmpty
                ? copiedTypeColorHex
                : _lessonTypeColorHexByName(copiedTypeName),
          ));

      await _saveScheduleToFirestore(
        weekOffset: weekOffset,
        day: day,
        time: time,
        endTime: resolvedEndTime,
        name: name,
        lessonType: lessonType,
        attended: false,
        countMap: countMap,
        memberId: memberId.isNotEmpty ? memberId : null,
        phone: phone.isNotEmpty ? phone : null,
      );
    }

    for (final memberId in affectedMemberIds) {
      await _refreshMemberNextLesson(memberId);
    }

    _showSnack(
      '${_copiedWeekSourceLabel ?? '복사한 수업일정'}을(를) $targetLabel 에 붙여넣었어요.',
    );
  }

  Future<void> _deleteAllSchedulesInWeek(int weekOffset) async {
    final weekSlice = _buildWeekSlice(weekOffset);

    final docIds = weekSlice.values
        .whereType<Map<String, dynamic>>()
        .map((e) => e['docId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final affectedMemberIds = weekSlice.values
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['memberId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (docIds.isEmpty) {
      _showSnack('삭제할 수업일정이 없어요.');
      return;
    }

    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');
    final confirmed = await _confirmDeleteWeekSchedules(
      targetLabel: targetLabel,
      count: docIds.length,
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final docId in docIds) {
      final ref = FirebaseFirestore.instance.collection('schedules').doc(docId);
      batch.delete(ref);
    }

    await batch.commit();

    for (final memberId in affectedMemberIds) {
      await _refreshMemberNextLesson(memberId);
    }

    final removeKeys = <String>[];

    weekSlice.forEach((dayTimeKey, value) {
      final parts = dayTimeKey.split('-');
      if (parts.length < 2) return;

      final day = parts.first;
      final time = parts.sublist(1).join('-');
      removeKeys.add(_makeKey(weekOffset, day, time));
    });

    _patchScheduleData(
      removeKeys: removeKeys,
      syncWidget: true,
    );

    _showSnack('$targetLabel 수업일정을 모두 삭제했어요.');
  }

  Future<void> _openWeekActionMenu(int weekOffset) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('수업일정 복사'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _copyWeekSchedules(weekOffset);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.content_paste_rounded),
                  title: const Text('수업일정 붙여넣기'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pasteWeekSchedules(weekOffset);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('수업일정 시간 범위 설정'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future.delayed(const Duration(milliseconds: 120));
                    if (!mounted) return;
                    await _openTimeRangeDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    '수업일정 전체삭제',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _deleteAllSchedulesInWeek(weekOffset);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- offset에 따라 상단 제목 문자열 생성 ----------
  String _weekTitleForOffset(int offset) {
    if (offset == -1) return "지난 주 스케줄";
    if (offset == 0) return "이번 주 스케줄";
    if (offset == 1) return "다음 주 스케줄";

    final mondayThisWeek = _mondayOfWeek(currentTime);
    final monday = mondayThisWeek.add(Duration(days: 7 * offset));
    final sunday = monday.add(const Duration(days: 6));

    String fmt(DateTime d) => "${d.month}월 ${d.day}일";

    return "${fmt(monday)}부터\n${fmt(sunday)}까지";
  }

  // ---------- 빌드 ----------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width = isTablet ? kMaxContentWidth : constraints.maxWidth;

        final nextLessons = _findTodayNextLessons();

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            extendBody: true,
            backgroundColor: kBgColor,
            endDrawer: _buildMainMenuDrawer(),
            body: Center(
              child: SizedBox(
                width: width,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 10),
                          _buildProBanner(),
                          const SizedBox(height: 24),
                          _buildTodayNextLessons(nextLessons),
                          const SizedBox(height: 24),
                          _buildThisWeekSchedule(),
                          const SizedBox(height: 24),
                          _buildWeeklyGoal(),
                          const SizedBox(height: 24),
                          _buildRecentClients(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      left: 0,
                      right: 0,
                      child: _BottomNavBar(
                        activeIndex: 1,
                        onChanged: (i) {
                          if (i == 0) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StatsPage(
                                  scheduleData: Map<String, dynamic>.from(scheduleData),
                                ),
                              ),
                            );
                          } else if (i == 1) {
                            _refreshHeaderOnEntry();

                            if (_weekPageIndex != _todayWeekIndex) {
                              _weekPageController.animateToPage(
                                _todayWeekIndex,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          } else if (i == 2) {
                            _openConsultPlaceholder();
                          } else if (i == 3) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ClientListPage(),
                              ),
                            );
                          }
                        },
                        onCenterTap: _showQuickRegistrationDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- 섹션 위젯들 ----------

  Widget _buildHeader() {
    final int todayCount = _countTodaySessions();
    final int weekCount = _countThisWeekSessions();
    final double topInset = MediaQuery
        .of(context)
        .padding
        .top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.only(
        top: topInset + 16,
        left: 24,
        right: 24,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => isHeaderExpanded = !isHeaderExpanded);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('trainer_profile')
                      .doc('me')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();

                    final trainerName = _trainerHeaderNameFromData(data);
                    final shortName = _trainerShortNameFromData(data);

                    return Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              shortName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '안녕하세요,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$trainerName님',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    _circleIcon(
                      Icons.note_add,
                      onTap: () => _onAction(HomeAction.quickMember),
                    ),
                    const SizedBox(width: 6),
                    _circleIcon(
                      _notificationsOn
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      onTap: () => _onAction(HomeAction.notifications),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (innerCtx) =>
                          _circleIcon(
                            Icons.menu,
                            onTap: () => Scaffold.of(innerCtx).openEndDrawer(),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () {
              setState(() => isHeaderExpanded = !isHeaderExpanded);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentHeaderNotice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isHeaderExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: Alignment.topCenter,
              heightFactor: isHeaderExpanded ? 1.0 : 0.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: isHeaderExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today,
                            label: "오늘",
                            value: "$todayCount",
                            onTap: _openTodayScheduleFocus,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people,
                            label: "체크포인트",
                            value: "${_countThisWeekMemoMembers()}",
                            onTap: _openTodayScheduleFocus,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up,
                            label: "이번 주",
                            value: "$weekCount",
                            onTap: _openThisWeekStats,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('members')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int expiringSoon = 0;
                      int lowRemaining = 0;

                      if (snapshot.hasData) {
                        final now = DateTime.now();
                        final soon = now.add(const Duration(days: 30));

                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data();

                          final nextReservationRaw = data['nextReservationAt'];
                          if (nextReservationRaw is Timestamp) {
                            final date = nextReservationRaw.toDate();
                            if (!date.isBefore(now) && !date.isAfter(soon)) {
                              expiringSoon++;
                            }
                          }

                          final remainingRaw =
                              data['remainingSessions'] ??
                                  data['remainingPt'] ?? data['ptRemaining'];
                          final remaining = int.tryParse((remainingRaw ?? '')
                              .toString());

                          if (remaining != null && remaining > 0 &&
                              remaining <= 3) {
                            lowRemaining++;
                          }
                        }
                      }

                      return GestureDetector(
                        onTap: _openExpiringMembers,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "만료 임박 $expiringSoon명 · 잔여 수업 부족 $lowRemaining명",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuDrawer() {
    final width = MediaQuery
        .of(context)
        .size
        .width;

    return Drawer(
      width: width > kMaxContentWidth ? 360 : width * 0.82,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MORE THAN GYM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ANATOMY EXCERCISE CATEGORY',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kAccentAmber, kAccentOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentOrange.withOpacity(0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '프리미엄 업그레이드',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '회원 관리 · 결제 · 통계 연동 기능 준비 중입니다.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(39, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '자세히',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '메뉴',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _drawerItem(
                icon: Icons.person_outline,
                label: '내 정보관리 ',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyPage()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _drawerItem(
                icon: Icons.person_outline,
                label: '고객카드',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClientListPage()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.fitness_center_outlined,
                label: '운동기록일지',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BinderCardPage()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.bar_chart_outlined,
                label: '통계',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StatsPage(
                            scheduleData: Map<String, dynamic>.from(
                                scheduleData),
                          ),
                    ),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.shopping_bag_outlined,
                label: '상품구매',
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon('상품구매');
                },
              ),
              const Spacer(),
              const Divider(),
              _drawerItem(
                icon: Icons.science_outlined,
                label: '테스트',
                onTap: () {
                  Navigator.of(context).pop();
                  _openLegacyTestPage();
                },
              ),
              _drawerItem(
                icon: Icons.settings_outlined,
                label: '설정',
                onTap: () {
                  Navigator.of(context).pop();
                  _openLegacySettingsPage();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22, color: Colors.black87),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildProBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kAccentAmber, kAccentOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: kAccentOrange.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.18),
              blurRadius: 0,
              spreadRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.white, size: 17),
                      SizedBox(width: 5),
                      _ProChip(),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    "프리미엄 업그레이드",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "계약서 작성 · 매출 수업 통계 · 백업 더 편리하고 똑똑한 관리",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => _showComingSoon('프리미엄 업그레이드'),
              style: TextButton.styleFrom(
                foregroundColor: kAccentOrange,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text("자세히"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayNextLessons(List<Map<String, dynamic>> nextLessons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "오늘 다음 수업",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (nextLessons.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(
                      Icons.check_circle_outline, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "오늘 남은 수업이 없습니다.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            )
          else
            ...nextLessons
                .asMap()
                .entries
                .map((entry) {
              final idx = entry.key;
              final data = entry.value;
              final String day = data["day"] as String;
              final String time = data["time"] as String;
              final String name = data["name"] as String;
              final String type = data["type"] as String;
              final bool isOngoing = (data["isOngoing"] == true);
              final int minutesToStart = (data["minutesToStart"] is int)
                  ? data["minutesToStart"] as int
                  : 9999;

              int emphasis = 0;
// 0=예정, 1=30분 전, 2=10분 전, 3=진행중
              if (isOngoing) {
                emphasis = 3;
              } else if (minutesToStart <= 10) {
                emphasis = 2;
              } else if (minutesToStart <= 30) {
                emphasis = 1;
              }

              String statusText = "예정";
              if (isOngoing) {
                statusText = "진행중";
              } else {
                if (minutesToStart <= 10) {
                  statusText = "10분 전";
                } else if (minutesToStart <= 30) {
                  statusText = "30분 전";
                }
              }
              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx == nextLessons.length - 1 ? 0 : 8,
                ),
                child: _NextLessonCard(
                  name: name,
                  time: time,
                  type: type,
                  status: statusText,
                  emphasis: emphasis,
                  enrolled: 0,
                  cap: 0,
                  memo: (data['memo'] ?? '').toString(),
                  countText: _buildTodayLessonCountText(data),
                  isManualMember: data['isManualMember'] == true,
                  onTap: () => _onCellTap(day, time, true, 0),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildThisWeekSchedule() {
    const double rowHeight = kScheduleRowHeight;
    const double headerCellHeight = kScheduleHeaderCellHeight;
    final int rows = _timeSlots.length + 1;
    final double tableHeight = rows * rowHeight;

    final int weekOffset = _indexToOffset(_weekPageIndex);
    final String title = _weekTitleForOffset(weekOffset);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onLongPress: () async {
                          HapticFeedback.mediumImpact();
                          await _openWeekActionMenu(weekOffset);
                        },
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() =>
                          _showScheduleHelp = !_showScheduleHelp),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '사용법',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.help_outline,
                            size: 16,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openWeekActionMenu(weekOffset),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: _weekPageIndex > 0
                        ? () =>
                        _weekPageController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: _weekPageIndex < _totalWeeks - 1
                        ? () =>
                        _weekPageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        )
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_showScheduleHelp) ...[
            const Text(
              "· 좌우 스와이프해서 지난 주 / 이번 주 / 다음 주는 물론 앞뒤 4주까지 볼 수 있어요.\n"
                  "· 빈 칸을 탭하면 수업일정을 등록할 수 있어요.\n"
                  "· 수업 시간은 시작시간 / 종료시간으로 나눠서 설정할 수 있어요.\n"
                  "· 시간 왼쪽 줄(예: 06:00)을 길게 누르면 시간 줄의 분 설정을 바꿀 수 있어요.\n"
                  "· '시간' 칸을 길게 누르면 전체 시간 줄의 기본 분 설정을 한 번에 바꿀 수 있어요.\n"
                  "· 제목(예: 이번 주 수업일정)을 길게 누르거나 ··· 버튼을 누르면 수업일정 복사 / 붙여넣기 / 시간 범위 설정 / 전체삭제 메뉴가 열려요.",
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _DayFilterButton(
                  label: "전체 (7일)",
                  isSelected: dayFilter == "all",
                  onTap: () {
                    setState(() => dayFilter = "all");
                    unawaited(_syncHomeWidgetPreview());
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DayFilterButton(
                  label: "평일 (5일)",
                  isSelected: dayFilter == "weekday",
                  onTap: () {
                    setState(() => dayFilter = "weekday");
                    unawaited(_syncHomeWidgetPreview());
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DayFilterButton(
                  label: "주말 (2일)",
                  isSelected: dayFilter == "weekend",
                  onTap: () {
                    setState(() => dayFilter = "weekend");
                    unawaited(_syncHomeWidgetPreview());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_shouldShowScheduleExamples(weekOffset)) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '회색 카드는 예시용이에요. 실제 수업을 3개 이상 등록하면 자동으로 사라져요.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _hideScheduleExamplesForever,
                    child: const Text(
                      '숨기기',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            height: tableHeight,
            child: PageView.builder(
              controller: _weekPageController,
              itemCount: _totalWeeks,
              onPageChanged: (index) => setState(() => _weekPageIndex = index),
              itemBuilder: (context, index) {
                final int offset = _indexToOffset(index);
                final weekSchedule = _buildWeekSlice(offset);

                return _WeeklyScheduleTable(
                  dayFilter: dayFilter,
                  weekOffset: offset,
                  scheduleData: weekSchedule,
                  exampleScheduleData: _buildScheduleExampleSlice(offset),
                  currentTime: currentTime,
                  timeSlots: _timeSlots,
                  onCellTap: (day, time, hasSession) =>
                      _onCellTap(day, time, hasSession, offset),
                  onTimeHeaderTap: _openTimeRangeDialog,
                  onTimeHeaderLongPress: _openAllRowsMinuteSheet,
                  onTimeRowLongPress: _onTimeRowLongPress,
                  onEventTap: (session) {
                    final rawStartAt = session['startAt'];
                    if (rawStartAt is! DateTime) return;

                    final day = _weekDaysAll[rawStartAt.weekday - 1];
                    final time =
                        '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}';

                    _openLessonEditorSheet(
                      day,
                      time,
                      offset,
                      existingSession: Map<String, dynamic>.from(session),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoal() {
    final weekCount = _countThisWeekSessions();
    final goalTarget = _weeklyGoalTarget();
    final progress = _weeklyGoalProgress(weekCount, goalTarget);
    final typeCounts = _countThisWeekLessonTypes();

    final top1 = _topWeeklyLessonTypeLabel(typeCounts, 0);
    final top2 = _topWeeklyLessonTypeLabel(typeCounts, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "이번 주 목표",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "주간 세션",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      Text(
                        "$weekCount/$goalTarget",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: kPrimaryColor.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        kPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _GoalInfo(label: "가장 많은 수업", value: top1),
                      ),
                      Expanded(
                        child: _GoalInfo(label: "다음 수업 타입", value: top2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentClients() {
    final colors = [
      {"bg": const Color(0xFFEEF2FF), "text": const Color(0xFF4338CA)},
      {"bg": const Color(0xFFF3E8FF), "text": const Color(0xFF6B21A8)},
      {"bg": const Color(0xFFFFE4E6), "text": const Color(0xFFBE123C)},
      {"bg": const Color(0xFFE0F2FE), "text": const Color(0xFF0369A1)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "최근 회원",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: _openMembersPage,
                child: const Text(
                  "전체보기",
                  style: TextStyle(fontSize: 12, color: kPrimaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('members')
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text(
                    '최근 회원을 불러오지 못했습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text(
                    '아직 등록된 회원이 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                );
              }

              return GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(docs.length, (i) {
                  final data = docs[i].data();
                  final name = (data['name'] ?? '').toString().trim();
                  final safeName = name.isEmpty ? '회원' : name;
                  final colorSet = colors[i % colors.length];

                  return GestureDetector(
                    onTap: _openMembersPage,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorSet["bg"] as Color,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            safeName.length > 4
                                ? safeName.substring(0, 4)
                                : safeName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorSet["text"] as Color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          safeName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- 공용 위젯들 ----------

class _MemberMatchInfoChip extends StatelessWidget {
  const _MemberMatchInfoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

// ============================================================
//  _QuickRegisterDialogBody — 개선 버전
//
//  home_page.dart 안의 _QuickRegisterDialogBody 클래스를
//  아래 코드로 통째로 교체하세요.
//
//  변경 사항:
//  1. 헤더 그라데이션 + 반투명 원형 depth 레이어
//  2. 이름 + 연락처 한 줄 배치 (공간 절약)
//  3. 방문일 + 상담예정일 한 줄 배치
//  4. 입력 필드 높이 컴팩트하게 조정
//  5. 버튼 스타일 통일
// ============================================================

class _QuickRegisterDialogBody extends StatefulWidget {
  const _QuickRegisterDialogBody({
    required this.nameC,
    required this.phoneC,
    required this.visitDate,
    required this.consultDate,
    required this.onVisitDateChanged,
    required this.onConsultDateChanged,
    required this.onClose,
    required this.onDetail,
    required this.onQuickSave,
  });

  final TextEditingController nameC;
  final TextEditingController phoneC;
  final DateTime visitDate;
  final DateTime? consultDate;
  final ValueChanged<DateTime> onVisitDateChanged;
  final ValueChanged<DateTime?> onConsultDateChanged;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onQuickSave;

  @override
  State<_QuickRegisterDialogBody> createState() =>
      _QuickRegisterDialogBodyState();
}

class _QuickRegisterDialogBodyState
    extends State<_QuickRegisterDialogBody> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.lightGradientStart.withOpacity(0.22),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 헤더 ──────────────────────────────────
                  _buildHeader(),
                  // ── 바디 ──────────────────────────────────
                  _buildBody(),
                  // ── 푸터 버튼 ─────────────────────────────
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: Colors.white.withOpacity(0.20),
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '빠른 등록',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '최소 정보만 입력하고 바로 등록',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0x94FFFFFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                Icons.close_rounded,
                size: 17,
                color: Color(0xB3FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── 바디 ────────────────────────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 이름 + 연락처 한 줄 ──────────────────────────
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _CompactField(
                  controller: widget.nameC,
                  hint: '이름',
                  icon: Icons.person_outline_rounded,
                  maxLength: 20,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _CompactField(
                  controller: widget.phoneC,
                  hint: '010-0000-0000',
                  icon: Icons.phone_iphone_rounded,
                  maxLength: 11,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── 방문일 + 상담예정일 한 줄 ────────────────────
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: '방문일',
                  value: DateFormat('yy.MM.dd').format(widget.visitDate),
                  dotColor: AppColors.lightGradientStart,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.visitDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      widget.onVisitDateChanged(picked);
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateTile(
                  label: '상담 예정',
                  value: widget.consultDate == null
                      ? '미정'
                      : DateFormat('yy.MM.dd').format(widget.consultDate!),
                  dotColor: widget.consultDate == null
                      ? const Color(0xFFD1D5DB)
                      : AppColors.lightGradientEnd,
                  valueMuted: widget.consultDate == null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: widget.consultDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    widget.onConsultDateChanged(picked);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── 푸터 ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(
        children: [
          // 취소
          TextButton(
            onPressed: widget.onClose,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lightTextSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '취소',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          // 상세 입력
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.lightGradientStart,
                side: BorderSide(
                  color: AppColors.lightGradientStart.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '상세 입력',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 빠른 등록
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.lightGradientStart,
                    AppColors.lightGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lightGradientStart.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.onQuickSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '빠른 등록',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  _CompactField — 컴팩트 입력 필드
//  home_page.dart 하단 공용 위젯 영역에 추가하세요.
//  (기존 _QuickRegisterField 대체)
// ============================================================

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLength,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.lightTextHint,
        ),
        prefixIcon: Icon(
          icon,
          size: 16,
          color: AppColors.lightTextTertiary,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        filled: true,
        fillColor: AppColors.lightSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorderFocus,
            width: 1.0,
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  _DateTile — 날짜 선택 버튼
//  home_page.dart 하단 공용 위젯 영역에 추가하세요.
//  (기존 _QuickRegisterDateTile 대체)
// ============================================================

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.onTap,
    this.valueMuted = false,
  });

  final String label;
  final String value;
  final Color dotColor;
  final VoidCallback onTap;
  final bool valueMuted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.lightTextTertiary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueMuted
                          ? AppColors.lightTextTertiary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}


Widget _circleIcon(IconData icon, {required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _WeeklyScheduleTable extends StatelessWidget {
  final String dayFilter;
  final int weekOffset;
  final Map<String, dynamic> scheduleData;
  final Map<String, dynamic> exampleScheduleData;
  final DateTime currentTime;
  final List<String> timeSlots;
  final void Function(String day, String time, bool hasSession) onCellTap;
  final VoidCallback? onTimeHeaderTap;
  final VoidCallback? onTimeHeaderLongPress;
  final VoidCallback? onExampleTap;
  final void Function(String timeLabel)? onTimeRowLongPress;
  final void Function(Map<String, dynamic> session)? onEventTap;

  static const int _defaultLessonDurationMinutes = 50;

  const _WeeklyScheduleTable({
    Key? key,
    required this.dayFilter,
    required this.weekOffset,
    required this.scheduleData,
    this.exampleScheduleData = const {},
    required this.currentTime,
    required this.timeSlots,
    required this.onCellTap,
    this.onTimeHeaderTap,
    this.onTimeHeaderLongPress,
    this.onTimeRowLongPress,
    this.onEventTap,
    this.onExampleTap,
  }) : super(key: key);

  List<String> get _weekDaysAll => const ['월', '화', '수', '목', '금', '토', '일'];

  List<String> _filteredDays() {
    const weekdayDays = ['월', '화', '수', '목', '금'];
    const weekendDays = ['토', '일'];

    switch (dayFilter) {
      case 'weekday':
        return weekdayDays;
      case 'weekend':
        return weekendDays;
      default:
        return _weekDaysAll;
    }
  }

  int _findTodayIndex(List<String> days) {
    final todayName = _weekDaysAll[currentTime.weekday - 1];
    return days.indexOf(todayName);
  }

  double? _getTimeLinePos(String time, DateTime now, double cellHeight) {
    final parts = time.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]) ?? -1;
    final baseMinute = int.tryParse(parts[1]) ?? 0;

    if (hour != now.hour) return null;

    final diff = now.minute - baseMinute;
    if (diff < 0 || diff >= 60) return null;

    return (diff / 60) * cellHeight;
  }

  Color _sessionColor(Map<String, dynamic>? session) {
    final colorHex = session?['typeColorHex']?.toString();
    if (colorHex != null && colorHex.isNotEmpty) {
      var value = colorHex.trim().replaceFirst('#', '');
      if (value.length == 6) {
        value = 'FF$value';
      }
      final parsed = int.tryParse(value, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }

    final String type = session?['type']?.toString() ?? '';

    switch (type) {
      case 'PT':
      case '수업':
      case 'PT수업':
        return kPrimaryColor;
      case '재활':
        return const Color(0xFF2563EB);
      case '필라테스':
        return const Color(0xFF7C3AED);
      case '요가':
        return const Color(0xFF0F766E);
      case '그룹':
      case '그룹수업':
        return kAccentOrange;
      case '줌바':
        return const Color(0xFFDB2777);
      case '상담':
      case 'OT상담':
        return kAccentAmber;
      case 'OT':
        return const Color(0xFF22C55E);
      default:
        return kPrimaryColor;
    }
  }

  int _hourIndexOfSlot(String slotTime) {
    final parts = slotTime.split(':');
    if (parts.length != 2) return -1;
    return int.tryParse(parts[0]) ?? -1;
  }

  int _startHourFromTimeSlots() {
    if (timeSlots.isEmpty) return 0;
    return _hourIndexOfSlot(timeSlots.first);
  }

  int _endHourExclusiveFromTimeSlots() {
    if (timeSlots.isEmpty) return 24;
    return _hourIndexOfSlot(timeSlots.last) + 1;
  }

  List<Map<String, dynamic>> _collectDaySessions(String day) {
    final List<Map<String, dynamic>> sessions = [];

    void collectFrom(Map<String, dynamic> source) {
      for (final value in source.values) {
        if (value is! Map<String, dynamic>) continue;

        final rawStartAt = value['startAt'];
        if (rawStartAt is! DateTime) continue;

        final valueDay = _weekDaysAll[rawStartAt.weekday - 1];
        if (valueDay != day) continue;

        sessions.add(Map<String, dynamic>.from(value));
      }
    }

    collectFrom(scheduleData);
    collectFrom(exampleScheduleData);

    sessions.sort((a, b) {
      final aStart = a['startAt'];
      final bStart = b['startAt'];
      if (aStart is DateTime && bStart is DateTime) {
        return aStart.compareTo(bStart);
      }
      return 0;
    });

    return sessions;
  }

  DateTime _sessionEndAt(Map<String, dynamic> session) {
    final rawStartAt = session['startAt'];
    if (rawStartAt is! DateTime) {
      return DateTime.now().add(
        const Duration(minutes: _defaultLessonDurationMinutes),
      );
    }

    final rawEndAt = session['endAt'];
    if (rawEndAt is DateTime && rawEndAt.isAfter(rawStartAt)) {
      return rawEndAt;
    }

    return rawStartAt.add(
      const Duration(minutes: _defaultLessonDurationMinutes),
    );
  }

  bool _sessionsOverlap(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
      ) {
    final aStart = a['startAt'];
    final bStart = b['startAt'];
    if (aStart is! DateTime || bStart is! DateTime) return false;

    final aEnd = _sessionEndAt(a);
    final bEnd = _sessionEndAt(b);

    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  List<Map<String, dynamic>> _buildSessionLayouts(
      List<Map<String, dynamic>> sessions,
      ) {
    if (sessions.isEmpty) return [];

    final sorted = List<Map<String, dynamic>>.from(sessions)
      ..sort((a, b) {
        final aStart = a['startAt'];
        final bStart = b['startAt'];
        if (aStart is DateTime && bStart is DateTime) {
          return aStart.compareTo(bStart);
        }
        return 0;
      });

    final layouts = <Map<String, dynamic>>[];
    int i = 0;

    while (i < sorted.length) {
      final group = <Map<String, dynamic>>[];
      DateTime groupEnd = _sessionEndAt(sorted[i]);

      group.add(sorted[i]);
      int j = i + 1;

      while (j < sorted.length) {
        final next = sorted[j];
        final nextStart = next['startAt'];

        if (nextStart is! DateTime) {
          j++;
          continue;
        }

        if (nextStart.isBefore(groupEnd)) {
          group.add(next);
          final nextEnd = _sessionEndAt(next);
          if (nextEnd.isAfter(groupEnd)) {
            groupEnd = nextEnd;
          }
          j++;
        } else {
          break;
        }
      }

      final columns = <List<Map<String, dynamic>>>[];

      for (final session in group) {
        bool placed = false;

        for (int col = 0; col < columns.length; col++) {
          final last = columns[col].last;
          if (!_sessionsOverlap(last, session)) {
            columns[col].add(session);
            layouts.add({
              'session': session,
              'columnIndex': col,
              'totalColumns': 0,
            });
            placed = true;
            break;
          }
        }

        if (!placed) {
          columns.add([session]);
          layouts.add({
            'session': session,
            'columnIndex': columns.length - 1,
            'totalColumns': 0,
          });
        }
      }

      final groupColumnCount = columns.length;

      for (int k = layouts.length - group.length; k < layouts.length; k++) {
        layouts[k]['totalColumns'] = groupColumnCount;
      }

      i = j;
    }

    return layouts;
  }

  double _topFromStartAt({
    required DateTime startAt,
    required int firstHour,
    required double rowHeight,
  }) {
    final totalMinutes =
        ((startAt.hour - firstHour) * 60) + startAt.minute.toDouble();
    return (totalMinutes / 60.0) * rowHeight;
  }

  double _heightFromDuration({
    required int durationMinutes,
    required double rowHeight,
  }) {
    return (durationMinutes / 60.0) * rowHeight;
  }

  Widget _buildEventBlock({
    required Map<String, dynamic> session,
    required int columnIndex,
    required int totalColumns,
    required double dayColWidth,
    required double rowHeight,
    required int firstHour,
    VoidCallback? onTap,
  }) {
    final rawStartAt = session['startAt'];
    if (rawStartAt is! DateTime) return const SizedBox.shrink();

    const double columnGap = 2.0;
    const double horizontalPadding = 3.0;
    const double verticalPadding = 1.5;

    final startAt = rawStartAt;
    final endAt = _sessionEndAt(session);

    int durationMinutes = endAt.difference(startAt).inMinutes;
    if (durationMinutes <= 0) {
      durationMinutes = _defaultLessonDurationMinutes;
    }

    final top = _topFromStartAt(
      startAt: startAt,
      firstHour: firstHour,
      rowHeight: rowHeight,
    ) +
        verticalPadding;

    final rawHeight = _heightFromDuration(
      durationMinutes: durationMinutes,
      rowHeight: rowHeight,
    );

    final height = math.max(10.0, rawHeight - (verticalPadding * 2));

    final availableWidth = dayColWidth -
        (horizontalPadding * 2) -
        ((totalColumns - 1) * columnGap);

    final blockWidth = totalColumns <= 1
        ? dayColWidth - (horizontalPadding * 2)
        : availableWidth / totalColumns;

    final left = horizontalPadding + columnIndex * (blockWidth + columnGap);

    final rawName = (session['name'] ?? '').toString().trim();
    final isExample = session['isExample'] == true;

    // ── 색상 결정 ──────────────────────────────────────────
    // 예시 블럭은 회색, 실제 블럭은 typeColorHex 우선 → AppColors 폴백
    Color blockColor;
    if (isExample) {
      blockColor = const Color(0xFF9CA3AF);
    } else {
      final colorHex = session['typeColorHex']?.toString();
      if (colorHex != null && colorHex.isNotEmpty) {
        var value = colorHex.trim().replaceFirst('#', '');
        if (value.length == 6) value = 'FF$value';
        final parsed = int.tryParse(value, radix: 16);
        blockColor = parsed != null ? Color(parsed) : AppColors.lessonPt;
      } else {
        final typeName = (session['typeName'] ?? session['type'] ?? '').toString();
        blockColor = AppColors.lessonBlockColor(typeName);
      }
    }

    // ── 출석 상태에 따른 opacity ───────────────────────────
    final attendanceOverride = session['attendanceOverride']?.toString();
    final attended = session['attended'] == true;
    final isDone = attended ||
        attendanceOverride == 'no_show_deducted' ||
        attendanceOverride == 'no_show_not_deducted';

    // 완료/노쇼 → 흐리게, 예시 → 더 흐리게
    final double blockOpacity = isExample
        ? 0.42
        : isDone
        ? AppColors.schedulerDoneOpacity
        : 1.0;

    // ── 이름 표시 여부 ─────────────────────────────────────
    // 20분 이상 + 이름 있을 때만 표시
    final bool showName = durationMinutes >= 20 && rawName.isNotEmpty;

    // 이름은 최대 4글자 (좁은 블럭 대응)
    final String displayName =
    rawName.length <= 4 ? rawName : rawName.substring(0, 4);

    return Positioned(
      left: left,
      top: top,
      width: blockWidth,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isExample ? onTap : onTap,
        child: Opacity(
          opacity: blockOpacity,
          child: Container(
            decoration: BoxDecoration(
              color: isExample
                  ? blockColor.withOpacity(0.42)
                  : blockColor.withOpacity(0.90),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(isExample ? 0.0 : 0.20),
                width: 0.6,
              ),
              boxShadow: isExample
                  ? null
                  : [
                BoxShadow(
                  color: blockColor.withOpacity(0.22),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (!isExample)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: height * 0.45,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.24),
                            Colors.white.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),

                if (!isExample)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: height * 0.28,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.14),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),

                if (showName)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isExample
                                ? const Color(0xFF374151)
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            shadows: isExample
                                ? null
                                : [
                              Shadow(
                                color: Colors.black.withOpacity(0.36),
                                offset: const Offset(0, 1.1),
                                blurRadius: 2.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (isExample)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.55,
                          child: Text(
                            '예시용',
                            style: TextStyle(
                              color: const Color(0xFF111827).withOpacity(0.22),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (!isExample &&
                    (attendanceOverride == 'no_show_deducted' ||
                        attendanceOverride == 'no_show_not_deducted') &&
                    height > 20)
                  Positioned(
                    bottom: 4,
                    right: 5,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _filteredDays();
    final todayIndex = _findTodayIndex(weekDays);
    final String? todayName =
    (todayIndex >= 0 && todayIndex < weekDays.length)
        ? weekDays[todayIndex]
        : null;

    const double rowHeight = kScheduleRowHeight;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWeekendMode = weekDays.length == 2;
          final totalCols = weekDays.length + 1;

          final double timeColWidth = isWeekendMode
              ? math.min(88, constraints.maxWidth * 0.18)
              : constraints.maxWidth / totalCols;

          final double dayColWidth = isWeekendMode
              ? (constraints.maxWidth - timeColWidth) / weekDays.length
              : timeColWidth;

          final int firstHour = _startHourFromTimeSlots();
          final int endHourExclusive = _endHourExclusiveFromTimeSlots();
          final double bodyHeight = timeSlots.length * rowHeight;

          return Column(
            children: [
              Row(
                children: [
                  _buildTimeHeaderCell(
                    '시간',
                    width: timeColWidth,
                    height: kScheduleHeaderCellHeight,
                    onTap: onTimeHeaderTap,
                    onLongPress: onTimeHeaderLongPress,
                  ),
                  ...weekDays.map((d) {
                    final isTodayCol = todayName != null && d == todayName;

                    return Container(
                      width: dayColWidth,
                      height: kScheduleHeaderCellHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isTodayCol
                            ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFD97706),
                            kScheduleTodayHeaderDeep,
                            kScheduleTodayHeader,
                            Color(0xFFFFD66B),
                          ],
                          stops: [0.0, 0.22, 0.72, 1.0],
                        )
                            : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF6D63F1),
                            kPrimaryColor,
                            kPrimaryColor2,
                            Color(0xFF7C2CD6),
                          ],
                          stops: [0.0, 0.36, 0.78, 1.0],
                        ),
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.16),
                            width: 0.5,
                          ),
                          bottom: BorderSide(
                            color: isTodayCol
                                ? Colors.black.withOpacity(0.18)
                                : kScheduleGridLine,
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                              ),
                            ),
                          ),

                          if (!isTodayCol)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 7,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                ),
                              ),
                            ),

                          if (isTodayCol) ...[
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 9,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.18),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.white.withOpacity(0.30),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          Center(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: isTodayCol ? FontWeight.w900 : FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(isTodayCol ? 0.28 : 0.18),
                                    offset: const Offset(0, 1),
                                    blurRadius: 1.4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
              SizedBox(
                height: bodyHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: timeColWidth,
                      child: Column(
                        children: timeSlots.map((time) {
                          return _buildTimeCell(
                            time,
                            width: timeColWidth,
                            height: rowHeight,
                            onLongPress: onTimeRowLongPress != null
                                ? () => onTimeRowLongPress!(time)
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                    ...weekDays.map((day) {
                      final isTodayColumn = todayName != null && day == todayName;

                      final daySessions = _collectDaySessions(day).where((session) {
                        final rawStartAt = session['startAt'];
                        if (rawStartAt is! DateTime) return false;

                        final startAt = rawStartAt;
                        final endAt = _sessionEndAt(session);

                        final tableStart = DateTime(
                          startAt.year,
                          startAt.month,
                          startAt.day,
                          firstHour,
                        );

                        final tableEnd = DateTime(
                          startAt.year,
                          startAt.month,
                          startAt.day,
                          endHourExclusive,
                        );

                        return endAt.isAfter(tableStart) &&
                            startAt.isBefore(tableEnd);
                      }).toList();

                      final sessionLayouts = _buildSessionLayouts(daySessions);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final localY = details.localPosition.dy;
                          int rowIndex = (localY / rowHeight).floor();

                          if (rowIndex < 0) rowIndex = 0;
                          if (rowIndex >= timeSlots.length) {
                            rowIndex = timeSlots.length - 1;
                          }

                          final tappedTime = timeSlots[rowIndex];
                          final hasSession = daySessions.any((session) {
                            final rawStartAt = session['startAt'];
                            if (rawStartAt is! DateTime) return false;

                            final sessionTime =
                                '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}';

                            return sessionTime == tappedTime;
                          });

                          onCellTap(day, tappedTime, hasSession);
                        },
                        child: Container(
                          width: dayColWidth,
                          height: bodyHeight,
                          decoration: const BoxDecoration(
                            color: kScheduleLightBg,
                          ),
                          child: Stack(
                            children: [
                              for (int i = 0; i < timeSlots.length; i++)
                                Positioned(
                                  top: i * rowHeight,
                                  left: 0,
                                  right: 0,
                                  height: rowHeight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isTodayColumn
                                          ? (i % 2 == 0 ? kScheduleTodayEven : kScheduleTodayOdd)
                                          : (i % 2 == 0 ? kScheduleRowEven : kScheduleRowOdd),
                                      border: const Border(
                                        right: BorderSide(
                                          color: kScheduleGridLine,
                                          width: 0.5,
                                        ),
                                        bottom: BorderSide(
                                          color: kScheduleGridLine,
                                          width: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              for (final layout in sessionLayouts)
                                Builder(
                                  builder: (_) {
                                    final session = Map<String, dynamic>.from(
                                      layout['session'] as Map,
                                    );
                                    final isExample = session['isExample'] == true;

                                    return _buildEventBlock(
                                      session: session,
                                      columnIndex: layout['columnIndex'] as int,
                                      totalColumns: layout['totalColumns'] as int,
                                      dayColWidth: dayColWidth,
                                      rowHeight: rowHeight,
                                      firstHour: firstHour,
                                      onTap: isExample
                                          ? onExampleTap
                                          : onEventTap == null
                                          ? null
                                          : () => onEventTap!(session),
                                    );
                                  },
                                ),
                              if (isTodayColumn)
                                ...timeSlots.map((time) {
                                  final showLine =
                                  _getTimeLinePos(time, currentTime, rowHeight);
                                  if (showLine == null) {
                                    return const SizedBox.shrink();
                                  }

                                  final rowIndex = timeSlots.indexOf(time);
                                  return Positioned(
                                    top: rowIndex * rowHeight + showLine,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 2.2,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: kScheduleCurrentLine,
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: kScheduleCurrentLine.withOpacity(0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeHeaderCell(
      String label, {
        double width = 70,
        double height = kScheduleHeaderCellHeight,
        VoidCallback? onTap,
        VoidCallback? onLongPress,
      }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kScheduleTimeColTop,
              kScheduleTimeColMid,
              kScheduleTimeColBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          border: Border(
            right: BorderSide(
              color: kScheduleTimeColLine,
              width: 1.6,
            ),
            bottom: BorderSide(
              color: kScheduleGridLine,
              width: 0.8,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kScheduleTimeText,
            fontSize: 11.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCell(
      String time, {
        double width = 70,
        double height = 40,
        VoidCallback? onLongPress,
      }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kScheduleTimeColTop,
              kScheduleTimeColMid,
              kScheduleTimeColBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          border: Border(
            right: BorderSide(
              color: kScheduleTimeColLine,
              width: 1.6,
            ),
            bottom: BorderSide(
              color: kScheduleGridLine,
              width: 0.6,
            ),
          ),
        ),
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
            color: kScheduleTimeText,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onCenterTap;

  const _BottomNavBar({
    Key? key,
    required this.activeIndex,
    required this.onChanged,
    required this.onCenterTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 100 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _BottomNavNotchPainter(),
              child: Container(
                height: 74 + bottomInset,
                padding: EdgeInsets.fromLTRB(12, 14, 12, 10 + bottomInset),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.bar_chart_outlined,
                              label: '통계',
                              index: 0,
                              activeIndex: activeIndex,
                              onTap: () => onChanged(0),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.calendar_month_outlined,
                              label: '수업일정',
                              index: 1,
                              activeIndex: activeIndex,
                              onTap: () => onChanged(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 74),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '상담',
                              index: 2,
                              activeIndex: activeIndex,
                              onTap: () => onChanged(2),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.credit_card_outlined,
                              label: '고객리스트',
                              index: 3,
                              activeIndex: activeIndex,
                              onTap: () => onChanged(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCenterTap,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [kPrimaryColor, kPrimaryColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '빠른 등록',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double topRadius = 28;
    const double notchRadius = 38;
    const double notchDepth = 31;

    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Path path = Path();

    path.moveTo(0, topRadius);
    path.quadraticBezierTo(0, 0, topRadius, 0);

    path.lineTo(size.width / 2 - notchRadius - 18, 0);

    path.cubicTo(
      size.width / 2 - notchRadius + 4,
      0,
      size.width / 2 - notchRadius + 2,
      notchDepth,
      size.width / 2,
      notchDepth,
    );

    path.cubicTo(
      size.width / 2 + notchRadius - 2,
      notchDepth,
      size.width / 2 + notchRadius - 4,
      0,
      size.width / 2 + notchRadius + 18,
      0,
    );

    path.lineTo(size.width - topRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.10), 14, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int activeIndex;
  final VoidCallback onTap;

  const _NavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.index,
    required this.activeIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == activeIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? kPrimaryColor : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? kPrimaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "PRO",
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------- 공용 위젯들 ----------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalInfo extends StatelessWidget {
  final String label;
  final String value;
  const _GoalInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SessionTypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SessionTypeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withOpacity(selected ? 0.95 : 0.30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  final String name;
  final String time;
  final String type;
  final String status;
  final int enrolled;
  final int cap;
  final int emphasis;
  final String memo;
  final String countText;
  final bool isManualMember;
  final VoidCallback? onTap;

  const _NextLessonCard({
    Key? key,
    required this.name,
    required this.time,
    required this.type,
    required this.status,
    required this.enrolled,
    required this.cap,
    this.emphasis = 0,
    this.memo = '',
    this.countText = '',
    this.isManualMember = false,
    this.onTap,
  }) : super(key: key);

  String lessonShortLabel(String value) {
    switch (value.trim()) {
      case 'PT':
      case '수업':
      case 'PT수업':
        return 'PT';
      case '그룹':
      case '그룹수업':
        return '그룹';
      case '요가':
        return '요가';
      case '필라테스':
        return 'PL';
      case '재활':
        return '재활';
      case '상담':
        return '상담';
      default:
        return value.length <= 2 ? value : value.substring(0, 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool alreadyHasNim = name.trim().endsWith('님');
    final String displayName = alreadyHasNim ? name.trim() : '${name.trim()} 님';
    final String memoText = memo.trim();

    final double bgOpacity = switch (emphasis) {
      1 => 0.05,
      2 => 0.09,
      3 => 0.12,
      _ => 0.00,
    };

    final double iconOpacity = switch (emphasis) {
      1 => 0.12,
      2 => 0.16,
      3 => 0.20,
      _ => 0.10,
    };

    final Color badgeBg = switch (emphasis) {
      3 => const Color(0xFFD1FAE5),
      2 => kPrimaryColor.withOpacity(0.18),
      1 => kPrimaryColor.withOpacity(0.12),
      _ => const Color(0xFFDBEAFE),
    };

    final Color badgeText = switch (emphasis) {
      3 => const Color(0xFF047857),
      2 => kPrimaryColor,
      1 => kPrimaryColor,
      _ => const Color(0xFF1E40AF),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: kPrimaryColor, width: 4)),
          color: bgOpacity > 0 ? kPrimaryColor.withOpacity(bgOpacity) : Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(iconOpacity),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                lessonShortLabel(type),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (countText.isNotEmpty)
                              Text(
                                countText,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            if (isManualMember)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: const Text(
                                  '미등록',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEA580C),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      memoText.isEmpty ? '' : memoText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: badgeText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayFilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayFilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecentMemberBubble extends StatelessWidget {
  final String? name;
  final VoidCallback? onTap;

  const _RecentMemberBubble({
    Key? key,
    this.name,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasName = name != null && name!.isNotEmpty;
    final String displayName = hasName
        ? (name!.length > 4 ? name!.substring(0, 4) : name!)
        : '';

    return GestureDetector(
      onTap: hasName ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: hasName
              ? kPrimaryColor.withOpacity(0.08)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: hasName
                ? kPrimaryColor.withOpacity(0.14)
                : Colors.grey.shade300,
          ),
        ),
        child: hasName
            ? Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 26,
              color: kPrimaryColor.withOpacity(0.12),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryColor,
                  height: 1.0,
                ),
              ),
            ),
          ],
        )
            : const Icon(
          Icons.person_outline,
          size: 18,
          color: Colors.grey,
        ),
      ),
    );
  }
}