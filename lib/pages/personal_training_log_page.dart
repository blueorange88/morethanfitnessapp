// lib/pages/personal_training_log_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'personal_training_log_text_voice_page.dart';
import 'personal_training_log_category_page.dart';
import 'personal_training_log_pdf_page.dart';
import 'personal_training_log_anatomy/anatomy_history_page.dart';
import 'personal_training_log_anatomy/anatomy_page.dart';
import 'personal_training_log_anatomy/anatomy_trend_page.dart'
    show anatomyNoteTitle;
import 'personal_training_log_anatomy/models/anatomy_lesson_summary.dart';
import 'personal_training_log_anatomy/models/anatomy_log.dart'
    show AnatomyLogRecord, AnatomyRecordType, MobilityResult;
import 'personal_training_log_anatomy/models/anatomy_trend.dart'
    show AnatomyMemberHistory;
import 'personal_training_log_anatomy/widgets/anatomy_change_card.dart';
import 'personal_training_log_anatomy/widgets/anatomy_mini_figures.dart';
import 'personal_training_log_anatomy/widgets/lesson_share_card.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../services/inbody_camera_permission_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/member_smart_alarm_context_service.dart';
import '../services/more_care_slot_service.dart';
import '../services/app_tier_access_service.dart';
import '../services/member_sign_url_service.dart';

import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/personal_training_log_entry_guard.dart';
import '../models/personal_training_log.dart';
import '../models/personal_training_log_details.dart';
import '../services/personal_training_log_repository.dart';
import '../services/training_log_preferences.dart';
import '../services/anatomy_exercise_store.dart';
import '../services/anatomy_history_service.dart';
import '../services/personal_custom_exercise_service.dart';
import '../services/inbody_history.dart';
import '../widgets/inbody_measure_flow.dart';
import '../widgets/inbody_trend_card.dart';
import '../widgets/training_log_pre_check.dart';
import '../widgets/mtf_header_neon_overlay.dart';

import '../aifc/core/aifc_chat_sheet.dart';
import '../aifc/widget/aifc_log_manage_chat_sheet.dart';
import '../theme/app_colors.dart';

const Color kLogBgColor = Color(0xFFF3F4F6);
const Color kLogCardColor = Colors.white;
const Color kLogBorderColor = Color(0xFFE5E7EB);
const double kLogPageHorizontalPadding = 16;
const double kLogMaxContentWidth = 520;

class PersonalTrainingLogPage extends StatefulWidget {
  final String? memberId;
  final String? memberName;
  final String? trainerName;
  final String? memberPhone;
  final int? totalSessions;
  final int? remainingSessions;
  final DateTime? lastLogAt;
  final String? personalOwnerUid;

  /// 2차 확장용
  final String? quickMemo;
  final String? recentIssue;
  final String? reRegistrationLabel;
  final String? openingMent;

  const PersonalTrainingLogPage({
    super.key,
    this.memberId,
    this.memberName,
    this.trainerName,
    this.memberPhone,
    this.totalSessions,
    this.remainingSessions,
    this.lastLogAt,
    this.personalOwnerUid,
    this.quickMemo,
    this.recentIssue,
    this.reRegistrationLabel,
    this.openingMent,
  });

  @override
  State<PersonalTrainingLogPage> createState() =>
      _PersonalTrainingLogPageState();
}

enum AchievementBadgeCode {
  lesson100,
  bodyProfileDone,
  competitionDone,
  weddingDone,
  ddayDone,
  reregister10,
  longTerm,
  attendance,
  manual,
}

class _PersonalTrainingLogPageState extends State<PersonalTrainingLogPage> {
  static const String kResetPin = '0000';

  final List<_TrainingLogItem> _logs = [];

  String _lastTrainerTyped = '';
  String _lastCustomerTyped = '';
  bool _isHeaderInfoExpanded = false;
  String _logFilter = 'all';
  bool _showMoreLogFilters = false;
  String _searchQuery = '';
  String? _highlightDraftId;
  String? _expandedLogId;

  /// 아나토미 레슨일지 카드에 보여줄 레슨별 요약(운동 이름·통증·주의·가동성). 레슨일지 id가 키.
  Map<String, AnatomyLessonSummary> _anatomySummaries =
      const <String, AnatomyLessonSummary>{};

  /// 이 회원의 아나토미 기록 전체(변화 보기 화면용).
  List<AnatomyLogRecord> _anatomyRecords = const <AnatomyLogRecord>[];

  /// 마지막 작성 타입 유지
  String _lastSelectedSessionType = '개인PT';

  /// 달력/빠른 이동용 날짜 필터
  DateTime? _selectedDateFilter;

  /// 회원 건강정보에 쌓인 인바디 이력(개인 워크스페이스). 기록이 없으면 비어 있다.
  List<InbodyHistoryPoint> _inbodyHistory = const [];
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  final Map<String, GlobalKey> _logCardKeys = {};
  final List<_GoalDdayItem> _goalDdays = [];

  AppTierAccessSnapshot? _tierAccess;
  bool _isTierAccessLoaded = false;
  bool _femaleConditionEnabled = false;
  DateTime? _femaleConditionLastStartAt;
  int _femaleConditionCycleDays = 28;
  bool _entryAccessResolved = false;
  bool _entryAccessAllowed = false;

  String get _personalOwnerUid => widget.personalOwnerUid?.trim() ?? '';
  bool get _isPersonalWorkspace => _personalOwnerUid.isNotEmpty;

  String _latestInbodyDate = '';
  String _latestWeight = '';
  String _latestBodyFatPercent = '';

  String _initialGoalLabel() {
    return '체중 감량';
  }

  GlobalKey _keyForLog(String id) {
    return _logCardKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _scrollToLog(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _logCardKeys[id];
      final context = key?.currentContext;
      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  ({AchievementBadgeCode code, String title}) _resolveBadgeFromGoalName(
    String goalName,
  ) {
    final value = goalName.trim().toLowerCase();

    if (value.contains('바디프로필') ||
        value.contains('바프') ||
        value.contains('body')) {
      return (code: AchievementBadgeCode.bodyProfileDone, title: '바디프로필 완료');
    }

    if (value.contains('대회') ||
        value.contains('시합') ||
        value.contains('competition')) {
      return (code: AchievementBadgeCode.competitionDone, title: '대회 완료');
    }

    if (value.contains('웨딩') || value.contains('결혼') || value.contains('촬영')) {
      return (code: AchievementBadgeCode.weddingDone, title: '웨딩촬영 완료');
    }

    return (
      code: AchievementBadgeCode.ddayDone,
      title: goalName.trim().isEmpty ? 'D-DAY 목표 완료' : '${goalName.trim()} 완료',
    );
  }

  bool _isBodyProfileGoalName(String goalName) {
    final value = goalName.trim().toLowerCase();

    return value.contains('바디프로필') ||
        value.contains('바프') ||
        value.contains('body');
  }

  bool _isCompetitionGoalName(String goalName) {
    final value = goalName.trim().toLowerCase();

    return value.contains('대회') ||
        value.contains('시합') ||
        value.contains('competition');
  }

  bool _isWeddingGoalName(String goalName) {
    final value = goalName.trim().toLowerCase();

    return value.contains('웨딩') ||
        value.contains('웨딩촬영') ||
        value.contains('결혼') ||
        value.contains('촬영');
  }

  List<({String suffix, String title, int dayOffset})>
  _followUpSpecsForGoalName(String goalName) {
    final cleanName = goalName.trim().isEmpty ? 'D-DAY' : goalName.trim();

    if (_isBodyProfileGoalName(goalName)) {
      return [
        (suffix: '14', title: '$cleanName 후 14일 컨디션 체크', dayOffset: 14),
        (suffix: '50', title: '$cleanName 후 50일 루틴 재정비', dayOffset: 50),
        (suffix: '100', title: '$cleanName 후 100일 리텐션 체크', dayOffset: 100),
      ];
    }

    if (_isCompetitionGoalName(goalName)) {
      return [(suffix: '14', title: '$cleanName 후 14일 회복 체크', dayOffset: 14)];
    }

    if (_isWeddingGoalName(goalName)) {
      return [(suffix: '14', title: '$cleanName 후 14일 컨디션 체크', dayOffset: 14)];
    }

    // 생일, 결혼기념일, 자녀 수능, 가족 행사 같은 개인 일정은
    // 자동 후속 MORE 포커스를 만들지 않습니다.
    return [];
  }

  Future<void> _createAchievementBadgeFromGoal({
    required _GoalDdayItem goal,
    required DateTime completedAt,
  }) async {
    if (_isPersonalWorkspace) return;

    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    final resolved = _resolveBadgeFromGoalName(goal.name);

    final ref = FirebaseFirestore.instance
        .collection('members')
        .doc(memberId)
        .collection('achievement_badges');

    try {
      final existing =
          await ref
              .where('source', isEqualTo: 'goal_dday')
              .where('sourceGoalId', isEqualTo: goal.id)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) return;

      await ref.add({
        'title': resolved.title,
        'code': resolved.code.name,
        'type': 'auto',
        'source': 'goal_dday',
        'sourceGoalId': goal.id,
        'isRepresentative': false,
        'earnedAt': Timestamp.fromDate(completedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _logFirestoreReadFailure(
        source: 'legacy_achievement_badge_write',
        error: error,
      );
    }
  }

  Future<void> _loadGoalDdaysFromFirestore() async {
    final ref = _goalDdaysRef();
    if (ref == null) return;

    try {
      final snapshot = await ref.orderBy('targetDate').get();

      final items =
          snapshot.docs
              .map((doc) => _GoalDdayItem.fromFirestore(doc.id, doc.data()))
              .where((item) => item.name.trim().isNotEmpty)
              .toList();

      if (!mounted) return;

      setState(() {
        _goalDdays
          ..clear()
          ..addAll(items);
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'legacy_goal_ddays', error: error);
    }
  }

  Future<void> _loadFemaleConditionFromMember() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberId)
              .get();

      final data = snap.data();
      if (data == null) return;
      if (_isPersonalWorkspace &&
          (data['memberId'] != memberId ||
              data['trainerId'] != _personalOwnerUid ||
              data['workspaceType'] != 'personal')) {
        return;
      }

      final health =
          data['health'] is Map
              ? Map<String, dynamic>.from(data['health'] as Map)
              : <String, dynamic>{};

      final femaleCondition =
          health['femaleCondition'] is Map
              ? Map<String, dynamic>.from(health['femaleCondition'] as Map)
              : <String, dynamic>{};

      DateTime? toDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String && value.isNotEmpty)
          return DateTime.tryParse(value);
        return null;
      }

      if (!mounted) return;

      setState(() {
        _femaleConditionEnabled = femaleCondition['enabled'] == true;
        _femaleConditionLastStartAt = toDate(femaleCondition['lastStartAt']);
        _femaleConditionCycleDays =
            (femaleCondition['cycleDays'] as num?)?.toInt() ?? 28;
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'member_condition', error: error);
    }
  }

  Future<void> _upsertGoalDday(_GoalDdayItem item) async {
    final ref = _goalDdaysRef();
    if (ref == null) {
      _showSnack('회원 연결이 없어 D-DAY를 저장할 수 없어요.');
      return;
    }

    final docId = item.id.trim().isEmpty ? _goalDdayDocId() : item.id;
    item.id = docId;

    await ref.doc(docId).set({
      ...item.toFirestorePayload(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _loadGoalDdaysFromFirestore();
    await _syncNextMoreDaySummaryToMember();
  }

  Future<void> _deleteGoalDday(_GoalDdayItem item) async {
    final ref = _goalDdaysRef();
    if (ref == null) return;

    await ref.doc(item.id).delete();
    await _loadGoalDdaysFromFirestore();
    await _syncNextMoreDaySummaryToMember();
  }

  Future<void> _completeGoalDday(_GoalDdayItem item) async {
    final ref = _goalDdaysRef();

    if (ref == null) {
      _showSnack('회원 연결이 없어 D-DAY를 완료할 수 없어요.');
      return;
    }

    final completedAt = DateTime.now();

    await ref.doc(item.id).set({
      'isCompleted': true,
      'status': 'completed',
      'completedAt': Timestamp.fromDate(completedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _createAchievementBadgeFromGoal(goal: item, completedAt: completedAt);

    final followUpEnabled = await _isDdayFollowUpEnabled();
    int createdFollowUpCount = 0;

    if (followUpEnabled && !item.followUpCreated) {
      createdFollowUpCount = await _createFollowUpCareMilestones(
        item,
        completedAt,
      );

      if (createdFollowUpCount > 0) {
        await ref.doc(item.id).set({
          'followUpCreated': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _loadGoalDdaysFromFirestore();
    await _syncNextMoreDaySummaryToMember();

    if (!mounted) return;

    _showSnack(
      createdFollowUpCount > 0
          ? '${item.name} 완료 · 메달과 후속 MORE 포커스 $createdFollowUpCount개를 생성했어요.'
          : '${item.name} 완료 · 메달을 생성했어요.',
    );
  }

  Future<void> _updateGoalDdayStatus(_GoalDdayItem item, String status) async {
    final ref = _goalDdaysRef();

    if (ref == null) {
      _showSnack('회원 연결이 없어 D-DAY 상태를 변경할 수 없어요.');
      return;
    }

    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'active') {
      payload['isCompleted'] = false;
      payload['completedAt'] = FieldValue.delete();
    }

    if (status == 'paused') {
      payload['isCompleted'] = false;
    }

    if (status == 'stopped') {
      payload['isCompleted'] = false;
      payload['stoppedAt'] = FieldValue.serverTimestamp();
    }

    await ref.doc(item.id).set(payload, SetOptions(merge: true));

    await _loadGoalDdaysFromFirestore();
    await _syncNextMoreDaySummaryToMember();

    if (!mounted) return;

    switch (status) {
      case 'active':
        _showSnack('${item.name} D-DAY를 다시 진행으로 바꿨어요.');
        break;
      case 'paused':
        _showSnack('${item.name} D-DAY를 보류했어요.');
        break;
      case 'stopped':
        _showSnack('${item.name} D-DAY를 중단했어요.');
        break;
    }
  }

  Future<void> _pauseGoalDday(_GoalDdayItem item) async {
    await _updateGoalDdayStatus(item, 'paused');
  }

  Future<void> _stopGoalDday(_GoalDdayItem item) async {
    await _updateGoalDdayStatus(item, 'stopped');
  }

  Future<void> _resumeGoalDday(_GoalDdayItem item) async {
    await _updateGoalDdayStatus(item, 'active');
  }

  Future<int> _createFollowUpCareMilestones(
    _GoalDdayItem goal,
    DateTime completedAt,
  ) async {
    final ref = _careMilestonesRef();
    if (ref == null) return 0;

    final goalName = goal.name.trim().isEmpty ? 'D-DAY' : goal.name.trim();
    final completedDate = _dateOnly(completedAt);

    final followUps = _followUpSpecsForGoalName(goalName);

    if (followUps.isEmpty) {
      return 0;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (final item in followUps) {
      final dueDate = completedDate.add(Duration(days: item.dayOffset));

      batch.set(ref.doc('follow_${goal.id}_${item.suffix}'), {
        'source': 'goal_dday_follow_up',
        'sourceGoalId': goal.id,
        'sourceGoalName': goalName,
        'title': item.title,
        'type': 'auto',
        'status': 'active',
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    return followUps.length;
  }

  CollectionReference<Map<String, dynamic>>? _goalDdaysRef() {
    if (_isPersonalWorkspace) return null;

    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('members')
        .doc(memberId)
        .collection('goal_ddays');
  }

  DocumentReference<Map<String, dynamic>>? _memberDocRef() {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return null;

    return FirebaseFirestore.instance.collection('members').doc(memberId);
  }

  _GoalDdayItem? _nearestActiveGoalDdayForSummary() {
    final activeGoals =
        _goalDdays.where((goal) {
          if (goal.isCompleted) return false;
          if (goal.status == 'paused') return false;
          if (goal.status == 'stopped') return false;
          return goal.name.trim().isNotEmpty;
        }).toList();

    if (activeGoals.isEmpty) return null;

    final today = _dateOnly(DateTime.now());

    final futureGoals =
        activeGoals.where((goal) {
            final goalDate = _dateOnly(goal.date);
            return !goalDate.isBefore(today);
          }).toList()
          ..sort((a, b) => _dateOnly(a.date).compareTo(_dateOnly(b.date)));

    if (futureGoals.isNotEmpty) {
      return futureGoals.first;
    }

    final pastGoals =
        activeGoals.toList()
          ..sort((a, b) => _dateOnly(b.date).compareTo(_dateOnly(a.date)));

    return pastGoals.first;
  }

  Future<void> _syncNextMoreDaySummaryToMember() async {
    final memberRef = _memberDocRef();
    if (memberRef == null) return;

    final nextGoal = _nearestActiveGoalDdayForSummary();

    try {
      if (nextGoal == null) {
        await memberRef.set({
          'nextMoreDayAt': FieldValue.delete(),
          'nextMoreDayLabel': FieldValue.delete(),
          'nextMoreDaySource': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      await memberRef.set({
        'nextMoreDayAt': Timestamp.fromDate(_dateOnly(nextGoal.date)),
        'nextMoreDayLabel': nextGoal.name.trim(),
        'nextMoreDaySource': 'goal_dday',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('MORE 데이 요약 저장 실패: $e');
    }
  }

  CollectionReference<Map<String, dynamic>>? _careMilestonesRef() {
    if (_isPersonalWorkspace) return null;

    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('members')
        .doc(memberId)
        .collection('care_milestones');
  }

  Future<bool> _isDdayFollowUpEnabled() async {
    final memberId = (widget.memberId ?? '').trim();

    if (memberId.isEmpty) return true;

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberId)
              .get();

      final data = snap.data();
      final settings =
          (data?['milestoneSettings'] is Map)
              ? Map<String, dynamic>.from(data!['milestoneSettings'] as Map)
              : <String, dynamic>{};

      return (settings['ddayFollowUpEnabled'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  int? _femaleConditionDaysLeftForDate(DateTime date) {
    if (!_femaleConditionEnabled) return null;

    final lastStart = _femaleConditionLastStartAt;
    if (lastStart == null) return null;

    final cycleDays = _femaleConditionCycleDays.clamp(20, 45);
    final targetDate = _dateOnly(date);

    var expectedDate = _dateOnly(lastStart);

    while (expectedDate.isBefore(
      targetDate.subtract(const Duration(days: 2)),
    )) {
      expectedDate = expectedDate.add(Duration(days: cycleDays));
    }

    return expectedDate.difference(targetDate).inDays;
  }

  bool _shouldShowFemaleConditionChip(DateTime date) {
    final daysLeft = _femaleConditionDaysLeftForDate(date);
    if (daysLeft == null) return false;

    // 추천 기준: D-3 ~ D+2
    return daysLeft >= -2 && daysLeft <= 3;
  }

  void _showFemaleConditionHint() {
    _showSnack(
      '컨디션주기를 가볍게 확인해보세요.\n'
      '오늘은 강도, 통증, 컨디션을 한 번 더 체크하면 좋아요.',
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _goalDdayDocId() {
    return 'goal_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _goalDateText(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseGoalDateText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed
        .replaceAll('.', '-')
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'\s+'), '');

    final match = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
    ).firstMatch(normalized);
    if (match == null) return null;

    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);

    if (y == null || m == null || d == null) return null;

    try {
      final parsed = DateTime(y, m, d);

      if (parsed.year != y || parsed.month != m || parsed.day != d) {
        return null;
      }

      return parsed;
    } catch (_) {
      return null;
    }
  }

  _GoalDdayItem? _nearestGoalDday() {
    final activeGoals =
        _goalDdays.where((goal) {
          if (goal.isCompleted) return false;
          if (goal.status == 'paused') return false;
          if (goal.status == 'stopped') return false;
          return true;
        }).toList();

    if (activeGoals.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final sorted = [...activeGoals]..sort((a, b) => a.date.compareTo(b.date));

    for (final goal in sorted) {
      final goalDate = DateTime(goal.date.year, goal.date.month, goal.date.day);
      if (!goalDate.isBefore(today)) {
        return goal;
      }
    }

    return sorted.first;
  }

  String _goalDdayLabel() {
    final goal = _nearestGoalDday();
    if (goal == null) return '-';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final goalDate = DateTime(goal.date.year, goal.date.month, goal.date.day);
    final diff = goalDate.difference(today).inDays;

    if (diff == 0) {
      return '${goal.name} D-DAY';
    }

    if (diff > 0) {
      return '${goal.name} D-$diff';
    }

    return '${goal.name} D+${diff.abs()}';
  }

  String _bodyPartSummaryFromLog(_TrainingLogItem log) {
    if (log.inputMethod == 'category') {
      final parts = _extractCategoryPartsFromMemo(log.memo);
      if (parts.isNotEmpty) {
        return parts.join(' · ');
      }
    }

    final memo = log.memo;
    if (memo.contains('하체')) return '하체';
    if (memo.contains('코어')) return '코어';
    if (memo.contains('어깨')) return '어깨';
    if (memo.contains('허리')) return '허리';
    if (memo.contains('상체')) return '상체';
    if (memo.contains('전신')) return '전신';
    return '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final owner = widget.personalOwnerUid?.trim() ?? '';
    if (owner.isEmpty) {
      _entryAccessResolved = true;
      _entryAccessAllowed = true;
      _loadTierAccess();
      _loadTrainingLogDataSources();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolvePersonalEntryAccess(owner);
      });
    }
  }

  void _loadTrainingLogDataSources() {
    _loadQuickSignedLogsFromFirestore();
    if (_isPersonalWorkspace) {
      _loadFormalLogsFromFirestore();
      _loadInbodyHistory();
    }
    _loadAnatomyLogsFromFirestore();
    _loadAnatomySummaries();
    if (_isPersonalWorkspace) {
      _loadFemaleConditionFromMember();
      return;
    }
    _loadGoalDdaysFromFirestore().then((_) {
      if (!mounted) return;
      _syncNextMoreDaySummaryToMember();
    });
    _loadFemaleConditionFromMember();
  }

  Future<void> _resolvePersonalEntryAccess(String owner) async {
    final allowed = await PersonalTrainingLogEntryGuard.guard(
      context: context,
      ownerUid: owner,
      memberId: widget.memberId ?? '',
      loadAccess:
          () => AppTierAccessService.loadPersonalTrainerAccess(uid: owner),
      entryPoint: 'personal_training_log_direct_route',
    );
    if (!mounted) return;
    setState(() {
      _entryAccessResolved = true;
      _entryAccessAllowed = allowed;
    });
    if (!allowed && mounted) {
      Navigator.of(context).maybePop();
      return;
    }
    await _loadTierAccess();
    if (!mounted) return;
    _loadTrainingLogDataSources();
  }

  DateTime? _quickLogDateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _quickLogDateText(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _quickLogTimeText(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _quickLogStatusToLocalStatus(String raw) {
    switch (raw) {
      case 'service':
        return 'service';
      case 'no_show_deducted':
        return 'no_show';
      case 'no_show_not_deducted':
        return 'no_show_no_deduct';
      case 'confirm_cancelled':
        return 'normal';
      case 'completed':
      default:
        return 'normal';
    }
  }

  Query<Map<String, dynamic>> _trainingLogsQuery(String memberId) {
    var query = FirebaseFirestore.instance
        .collection('training_logs')
        .where('memberId', isEqualTo: memberId);
    if (!_isPersonalWorkspace) return query;

    query = query
        .where('trainerId', isEqualTo: _personalOwnerUid)
        .where('workspaceType', isEqualTo: 'personal');
    return query;
  }

  void _logFirestoreReadFailure({
    required String source,
    required Object error,
  }) {
    final errorCode =
        error is FirebaseException ? error.code : error.runtimeType.toString();
    debugPrint(
      '[MTF_TRAINING_LOG_READ] source=$source result=failure '
      'errorCode=$errorCode identifiersLogged=false',
    );
  }

  Future<void> _loadQuickSignedLogsFromFirestore() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final snapshot = await _trainingLogsQuery(memberId).get();

      if (!mounted) return;

      final nextLogs = <_TrainingLogItem>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['quickSignedOnly'] != true) continue;

        final rawStartAt = data['startAt'];
        final startAt = _quickLogDateFromAny(rawStartAt) ?? DateTime.now();

        final statusRaw = (data['sessionStatus'] ?? '').toString();
        final localStatus = _quickLogStatusToLocalStatus(statusRaw);

        final title = (data['title'] ?? '빠른 서명').toString();
        final memo = (data['memo'] ?? '').toString();
        final type = (data['lessonType'] ?? data['type'] ?? '개인PT').toString();
        final name =
            (data['memberName'] ?? widget.memberName ?? '회원').toString();

        final trainerSignature = data['trainerSignature'];
        final memberSignature = data['memberSignature'];

        final trainerSignedAt =
            trainerSignature is Map
                ? _quickLogDateFromAny(trainerSignature['signedAt'])
                : null;

        final memberSignedAt =
            memberSignature is Map
                ? _quickLogDateFromAny(memberSignature['signedAt'])
                : null;

        final trainerSignedDate =
            trainerSignedAt == null ? '' : _quickLogDateText(trainerSignedAt);
        final trainerSignedTime =
            trainerSignedAt == null ? '' : _quickLogTimeText(trainerSignedAt);

        final memberSignedDate =
            memberSignedAt == null ? '' : _quickLogDateText(memberSignedAt);
        final memberSignedTime =
            memberSignedAt == null ? '' : _quickLogTimeText(memberSignedAt);

        final trainerSigned = data['trainerSigned'] == true;
        final memberSigned = data['memberSigned'] == true;

        nextLogs.add(
          _TrainingLogItem(
            id: 'quick_${doc.id}',
            trainingLogDocId: doc.id,
            scheduleDocId: (data['scheduleDocId'] ?? '').toString().trim(),
            confirmCancelled:
                data['confirmCancelled'] == true || data['voided'] == true,
            title: title,
            name: name,
            time: _quickLogTimeText(startAt),
            type: type,
            memo: memo.isEmpty ? '빠른 서명으로 저장된 레슨일지입니다.' : memo,
            date: DateTime(startAt.year, startAt.month, startAt.day),
            performanceScore: 0,
            inputMethod: 'quick_sign',
            source: (data['source'] ?? '').toString(),
            waitingTrainerConfirm: data['waitingTrainerConfirm'] == true,
            memberSignedFromWeb:
                memberSignature is Map &&
                (memberSignature['signedBy'] ?? '').toString() == 'member_web',
            sessionStatus: localStatus,
            isDraft: false,
            trainerSig:
                trainerSigned
                    ? const SigCell(type: 'typed', value: '서명 완료')
                    : SigCell.empty(),
            customerSig:
                memberSigned
                    ? const SigCell(type: 'typed', value: '서명 완료')
                    : SigCell.empty(),
            locked:
                data['locked'] == true &&
                data['confirmCancelled'] != true &&
                data['voided'] != true,
            trainerSignedDate: trainerSignedDate,
            trainerSignedTime: trainerSignedTime,
            customerSignedDate: memberSignedDate,
            customerSignedTime: memberSignedTime,
            lockedAtDate:
                data['lockedAt'] is Timestamp
                    ? _quickLogDateText(
                      (data['lockedAt'] as Timestamp).toDate(),
                    )
                    : '',
            lockedAtTime:
                data['lockedAt'] is Timestamp
                    ? _quickLogTimeText(
                      (data['lockedAt'] as Timestamp).toDate(),
                    )
                    : '',
          ),
        );
      }

      if (nextLogs.isEmpty) return;

      setState(() {
        final existingIds = _logs.map((e) => e.id).toSet();

        for (final log in nextLogs) {
          if (existingIds.contains(log.id)) continue;
          _logs.add(log);
        }
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'quick_signed_logs', error: error);
    }
  }

  // 회원 문서의 건강정보에서 인바디 이력을 읽어 헤더 추이에 보여준다.
  Future<void> _loadInbodyHistory() async {
    final memberId = (widget.memberId ?? '').trim();
    if (!_isPersonalWorkspace || memberId.isEmpty) return;
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberId)
              .get();
      if (!mounted) return;
      setState(() {
        _inbodyHistory = parseInbodyHistory(snapshot.data()?['health']);
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'inbody_history', error: error);
    }
  }

  // 헤더의 인바디 입력 아이콘·추이 카드·체크리스트가 같이 쓰는 입구. 개인 워크스페이스는
  // 새 측정 흐름(본인 확인 + 서버 기록)을, 기존 워크스페이스는 이전 흐름을 연다.
  Future<void> _openInbodyMeasure() async {
    final memberId = (widget.memberId ?? '').trim();
    if (!_isPersonalWorkspace || memberId.isEmpty) {
      await _showInbodyScanOptions();
      return;
    }
    final result = await runInbodyMeasureFlow(
      context,
      memberId: memberId,
      memberName: (widget.memberName ?? '').trim(),
    );
    if (result != null) await _loadInbodyHistory();
  }

  // 개인 워크스페이스에서 이 화면이 서버에 저장한 일반(formal) 레슨일지를 목록에 불러온다.
  Future<void> _loadFormalLogsFromFirestore() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final snapshot = await _trainingLogsQuery(memberId).get();
      if (!mounted) return;

      final loaded = <_TrainingLogItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['source'] != 'formal' || data['schemaVersion'] != 1) continue;
        loaded.add(_logItemFromFormalDoc(doc.id, data));
      }
      if (loaded.isEmpty) return;

      setState(() {
        final knownDocIds =
            _logs
                .map((e) => e.trainingLogDocId.trim())
                .where((e) => e.isNotEmpty)
                .toSet();
        for (final log in loaded) {
          if (knownDocIds.contains(log.trainingLogDocId)) continue;
          _logs.add(log);
        }
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'formal_logs', error: error);
    }
  }

  _TrainingLogItem _logItemFromFormalDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    final start = _quickLogDateFromAny(data['startAt']) ?? DateTime.now();
    final status = (data['status'] ?? '').toString();
    final memo = (data['memo'] ?? '').toString();
    final details =
        data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : null;
    final hasPreCheck = details != null && details['pre'] is Map;
    final hasContent =
        memo.trim().isNotEmpty ||
        (details != null &&
            ((details['title'] ?? '').toString().trim().isNotEmpty ||
                (details['inputMethod'] ?? '').toString().trim().isNotEmpty ||
                (details['exercises'] is List &&
                    (details['exercises'] as List).isNotEmpty)));
    final finalized = PersonalTrainingLogStatus.finalized.contains(status);

    final item = _TrainingLogItem(
      id: 'formal_$docId',
      trainingLogDocId: docId,
      scheduleDocId: (data['scheduleDocId'] ?? '').toString().trim(),
      title: '레슨일지 작성 전',
      name:
          (widget.memberName ?? '').trim().isEmpty
              ? '회원'
              : (widget.memberName ?? '').trim(),
      time: _quickLogTimeText(start),
      type: (data['lessonType'] ?? '개인PT').toString(),
      memo: memo,
      date: DateTime(start.year, start.month, start.day),
      performanceScore: 0,
      source: 'formal',
      sessionStatus: _quickLogStatusToLocalStatus(status),
      isDraft: !hasContent,
      locked: finalized,
      deductionApplied: data['deductionApplied'] == true,
      confirmCancelled: status == 'confirm_cancelled',
    );
    if (details != null) {
      final flat = editorMapFromPersonalTrainingLogDetails(details);
      _assignEditorMap(item, {
        ...flat,
        'memo': memo,
        'type': item.type,
        'name': item.name,
      });
    }
    if (hasContent) {
      item.draftEntryMode =
          item.inputMethod == 'category' ? 'category' : 'text';
    } else {
      // 레슨 전 체크만 저장된 초안: 작성 전 상태를 유지하고 체크 값만 복원한다.
      item.title = '레슨일지 작성 전';
      item.inputMethod = 'text';
      item.isDraft = true;
    }
    item.preCheckDone = hasPreCheck;
    return item;
  }

  Future<void> _loadAnatomyLogsFromFirestore() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final snapshot = await _trainingLogsQuery(memberId).get();
      if (!mounted) return;

      final nextLogs = <_TrainingLogItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['hasAnatomyRecords'] != true ||
            data['quickSignedOnly'] == true) {
          continue;
        }
        final records = data['anatomyRecords'];
        final count = records is List ? records.length : 0;
        final startAt = _quickLogDateFromAny(data['startAt']) ?? DateTime.now();
        nextLogs.add(
          _TrainingLogItem(
            id: 'anatomy_${doc.id}',
            trainingLogDocId: doc.id,
            scheduleDocId: (data['scheduleDocId'] ?? '').toString().trim(),
            title: (data['title'] ?? '해부학 레슨일지').toString(),
            name: (data['memberName'] ?? widget.memberName ?? '회원').toString(),
            time: _quickLogTimeText(startAt),
            type: (data['lessonType'] ?? data['type'] ?? '개인PT').toString(),
            memo: '신체 부위 기록 $count개',
            date: DateTime(startAt.year, startAt.month, startAt.day),
            performanceScore: 0,
            inputMethod: 'anatomy',
            isDraft: false,
          ),
        );
      }
      if (nextLogs.isEmpty || !mounted) return;

      setState(() {
        final existingDocIds =
            _logs
                .map((log) => log.trainingLogDocId.trim())
                .where((id) => id.isNotEmpty)
                .toSet();
        for (final log in nextLogs) {
          if (existingDocIds.add(log.trainingLogDocId)) {
            _logs.add(log);
          }
        }
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'anatomy_logs', error: error);
    }
  }

  /// 이 회원의 아나토미 기록을 한 번에 읽어 레슨별로 나눈다. 못 읽으면 카드는
  /// 기존처럼 '신체 부위 기록 N개'만 보여준다.
  Future<void> _loadAnatomySummaries() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;
    try {
      final trainerId = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
      if (trainerId.isEmpty) return;
      final records = await FirestoreAnatomyHistoryStore().loadMemberRecords(
        trainerId: trainerId,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(() {
        _anatomyRecords = records;
        _anatomySummaries = AnatomyLessonSummary.groupByLesson(records);
      });
    } catch (error) {
      _logFirestoreReadFailure(source: 'anatomy_summaries', error: error);
    }
  }

  /// 회원에게 보낼 레슨 요약 이미지 시트(운동 내용만. 통증·주의·가동성은 넣지 않는다).
  Future<void> _shareAnatomyLesson(_TrainingLogItem log) async {
    final lessonLogId = _firestoreLogDocIdFromLog(log).trim();
    final records = shareSafeRecords(
      _anatomyRecords.where((r) => r.lessonLogId.trim() == lessonLogId),
    );
    if (records.isEmpty) {
      _showSnack('보낼 운동 기록이 없어요.');
      return;
    }
    await showLessonShareSheet(
      context,
      dateText: _fmtDotYmd(log.date),
      timeText: log.time,
      subtitle: '${_sessionNumberOf(log)}회차 · ${log.name} 님',
      records: records,
    );
  }

  /// 텍스트·음성·카테고리 레슨을 회원에게 보낼 이미지로 만든다(몸 그림 없음).
  /// 카테고리는 운동 구성(이름, 세트×횟수), 텍스트는 회원 공개 메모(없으면 레슨 내용)를 쓰고
  /// 내부 메모·통증·레슨 전 체크는 넣지 않는다. 보내기 전에 시트에서 내용을 확인한다.
  Future<void> _shareTextOrCategoryLesson(_TrainingLogItem log) async {
    final lines = categoryShareLines(log.exercises);
    final fallbackNames =
        log.inputMethod == 'category' && lines.isEmpty
            ? _extractCategoryExercisesFromMemo(log.memo)
            : const <String>[];
    final body = textLessonShareBody(
      inputMethod: log.inputMethod,
      publicSummary: log.publicSummary,
      publicGood: log.publicGood,
      publicHomeworkNote: log.publicHomeworkNote,
      publicCaution: log.publicCaution,
      memo: log.memo,
    );
    final shareLines = [
      ...lines,
      for (final name in fallbackNames)
        ShareExerciseLine(name: name, summary: ''),
    ];
    if (shareLines.isEmpty && body.isEmpty) {
      _showSnack('보낼 레슨 내용이 없어요.');
      return;
    }
    await showLessonShareSheet(
      context,
      dateText: _fmtDotYmd(log.date),
      timeText: log.time,
      subtitle: '${_sessionNumberOf(log)}회차 · ${log.name} 님',
      lines: shareLines,
      bodyText: body,
      notice: '아래 내용이 이미지로 보내져요. 내부 메모·통증 기록은 들어가지 않아요.',
    );
  }

  /// 회원의 운동 변화·통증·가동성 기록 화면(아나토미 기록 기준).
  Future<void> _openAnatomyHistory() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => AnatomyHistoryPage(
              memberName: widget.memberName ?? '',
              history: AnatomyMemberHistory(_anatomyRecords),
            ),
      ),
    );
  }

  _TrainingLogItem? _findTodayDraft() {
    final now = DateTime.now();

    for (final log in _logsNewestFirst()) {
      if (!log.isDraft) continue;
      if (_isSameDate(log.date, now)) {
        return log;
      }
    }
    return null;
  }

  String _nowIsoDate() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _nowHm() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  DateTime _logDateTime(_TrainingLogItem item) {
    final parts = item.time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      hour,
      minute,
    );
  }

  List<_TrainingLogItem> _logsNewestFirst() {
    final items = List<_TrainingLogItem>.from(_logs);
    items.sort((a, b) => _logDateTime(b).compareTo(_logDateTime(a)));
    return items;
  }

  List<_TrainingLogItem> _logsOldestFirst() {
    final items = List<_TrainingLogItem>.from(_logs);
    items.sort((a, b) => _logDateTime(a).compareTo(_logDateTime(b)));
    return items;
  }

  bool _sameLog(_TrainingLogItem a, _TrainingLogItem b) {
    final aId = a.id.trim();
    final bId = b.id.trim();

    if (aId.isNotEmpty && bId.isNotEmpty) {
      return aId == bId;
    }

    return identical(a, b);
  }

  int _sessionNumberOf(_TrainingLogItem item) {
    final asc = _logsOldestFirst();
    int count = 0;

    for (final log in asc) {
      final isCounted =
          log.sessionStatus == 'normal' || log.sessionStatus == 'no_show';

      if (isCounted) {
        count += 1;
      }

      if (identical(log, item)) {
        return isCounted ? count : count;
      }
    }

    return 0;
  }

  int _serviceSequenceOf(_TrainingLogItem item) {
    final asc = _logsOldestFirst();
    int count = 0;

    for (final log in asc) {
      final isServiceLike =
          log.sessionStatus == 'service' ||
          log.sessionStatus == 'no_show_no_deduct';

      if (isServiceLike) {
        count += 1;
      }

      if (identical(log, item)) {
        return isServiceLike ? count : 0;
      }
    }

    return 0;
  }

  String _sessionDisplayText(_TrainingLogItem log) {
    final countedNo = _sessionNumberOf(log);
    final serviceNo = _serviceSequenceOf(log);

    switch (log.sessionStatus) {
      case 'service':
        return 'S.V-$serviceNo';
      case 'no_show':
        return '${countedNo}회차 NO SHOW';
      case 'no_show_no_deduct':
        return 'NO SHOW(미차감)-$serviceNo';
      case 'normal':
      default:
        return '${countedNo}회차';
    }
  }

  DateTime? _latestLogDate() {
    if (_logs.isEmpty) return null;
    return _logsNewestFirst().first.date;
  }

  DateTime? _firstLogDate() {
    if (_logs.isEmpty) return null;
    return _logsOldestFirst().first.date;
  }

  List<_TrainingLogItem> _filteredLogs() {
    var items = _logsNewestFirst();

    if (_selectedDateFilter != null) {
      items =
          items
              .where((e) => _isSameDate(e.date, _selectedDateFilter!))
              .toList();
    }

    switch (_logFilter) {
      case 'unsigned':
        items =
            items.where((e) {
              if (e.confirmCancelled) return false;

              final trainerOk = e.trainerSig.isSigned;
              final customerOk = e.customerSig.isSigned;

              return !(trainerOk && customerOk);
            }).toList();
        break;

      case 'locked':
        items =
            items.where((e) {
              return e.locked && !e.confirmCancelled;
            }).toList();
        break;

      case 'no_show':
        items =
            items.where((e) {
              return e.sessionStatus == 'no_show' && !e.confirmCancelled;
            }).toList();
        break;

      case 'no_show_no_deduct':
        items =
            items.where((e) {
              return e.sessionStatus == 'no_show_no_deduct' &&
                  !e.confirmCancelled;
            }).toList();
        break;

      case 'service':
        items =
            items.where((e) {
              return e.sessionStatus == 'service' && !e.confirmCancelled;
            }).toList();
        break;

      case 'cancelled':
        items =
            items.where((e) {
              return e.confirmCancelled;
            }).toList();
        break;

      case 'all':
      default:
        // 전체는 진짜 전체: 확정취소까지 포함
        break;
    }

    if (_searchQuery.isNotEmpty) {
      items =
          items.where((e) {
            return logSearchMatches(_searchTextFor(e), _searchQuery);
          }).toList();
    }

    return items;
  }

  /// 검색에 쓰는 한 레슨일지의 글자: 제목·메모·종류·날짜에 더해 특이사항 칩, 통증 메모,
  /// 카테고리 운동 구성, 아나토미 기록(운동·통증·주의·가동성)까지 모은다.
  String _searchTextFor(_TrainingLogItem e) {
    final dateText =
        '${e.date.year}.${e.date.month.toString().padLeft(2, '0')}.${e.date.day.toString().padLeft(2, '0')}';
    final parts = <String>[
      e.title,
      e.memo,
      e.type,
      dateText,
      ...e.issueChips,
      e.nextLessonCheckpoint,
      e.preNote,
      e.prePainDetail,
      e.duringPainDetail,
      e.postPainDetail,
      e.internalMemo,
      e.publicSummary,
      e.publicCaution,
      e.publicHomeworkNote,
      if (e.prePain == '있음') '통증',
    ];
    for (final exercise in e.exercises) {
      for (final key in const ['main', 'part', 'name', 'note']) {
        parts.add((exercise[key] ?? '').toString());
      }
    }
    if (e.inputMethod == 'anatomy') {
      final summary = _anatomySummaries[_firestoreLogDocIdFromLog(e)];
      if (summary != null) parts.add(summary.searchText);
    }
    return parts.join(' ');
  }

  List<_TrainingLogItem> _chartLogs() {
    final asc = _logsOldestFirst();
    if (asc.length <= 7) return asc;
    return asc.sublist(asc.length - 7);
  }

  double _latestScore() {
    if (_logs.isEmpty) return 0;
    return _logsNewestFirst().first.performanceScore;
  }

  double _scoreChange() {
    final chart = _chartLogs();
    if (chart.length < 2) return 0;
    return chart.last.performanceScore - chart.first.performanceScore;
  }

  Set<DateTime> _lessonDates() {
    return _logs
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
  }

  Future<void> _openLessonCalendar() async {
    final result = await showModalBottomSheet<_LessonCalendarResult?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _LessonCalendarSheet(
            lessonDates: _lessonDates(),
            selectedDate: _selectedDateFilter,
            firstDate: _firstLogDate(),
            lastDate: _latestLogDate(),
          ),
    );

    if (!mounted || result == null) return;

    setState(() {
      if (result.clearFilter) {
        _selectedDateFilter = null;
      } else if (result.selectedDate != null) {
        final selected = result.selectedDate!;
        _selectedDateFilter = DateTime(
          selected.year,
          selected.month,
          selected.day,
        );
      }
    });
  }

  Future<void> _loadTierAccess() async {
    try {
      final owner = widget.personalOwnerUid?.trim() ?? '';
      final access =
          owner.isEmpty
              ? await AppTierAccessService.loadTrainerAccess()
              : await AppTierAccessService.loadPersonalTrainerAccess(
                uid: owner,
              );

      if (!mounted) return;

      setState(() {
        _tierAccess = access;
        _isTierAccessLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _tierAccess = null;
        _isTierAccessLoaded = true;
      });
    }
  }

  Future<bool> _guardDdayFeature() async {
    final owner = widget.personalOwnerUid?.trim() ?? '';
    return AifcTierFeatureGateSheet.guard(
      context: context,
      access: _tierAccess,
      feature: AppTierFeatureKey.dday,
      loadAccess:
          owner.isEmpty
              ? AppTierAccessService.loadTrainerAccess
              : () =>
                  AppTierAccessService.loadPersonalTrainerAccess(uid: owner),
      onShowTierGuide: (info) async {
        _showSnack(
          '${info.requiredTierLabel} 안내는 마이페이지의 등급 안내에서 다시 확인할 수 있어요.',
        );
      },
    );
  }

  Future<bool> _openGoalDdayAifcFlow({required _GoalDdayItem? editing}) async {
    if (!await _guardDdayFeature()) return false;

    if (editing == null &&
        _goalDdays.where((goal) => !goal.isCompleted).length >= 3) {
      _showSnack('진행 중인 D-DAY는 최대 3개까지 등록할 수 있어요.');
      return false;
    }

    final goalName = await AifcChatSheet.show(
      context: context,
      question:
          editing == null
              ? '어떤 D-DAY 목표를 등록할까요?\n\n바디프로필, 대회, 웨딩촬영처럼 날짜가 정해진 목표를 등록할 수 있어요.'
              : '수정할 D-DAY 목표 이름을 알려주세요.',
      inputLabel: '예: 바디프로필 / 대회 / 웨딩촬영',
      initialValue: editing?.name ?? '',
      autoCompleteHints: const ['바디프로필', '대회', '웨딩촬영', '결혼식', '생일'],
      skipLabel: '취소할게요',
      onSkip: () {},
      onSave: (value) async {
        final name = value.trim();
        if (name.isEmpty) {
          return '목표 이름을 입력해야 D-DAY로 관리할 수 있어요.';
        }

        return '$name 목표로 등록해볼게요.\n이제 목표 날짜를 알려주세요.';
      },
    );

    if (!mounted || goalName == null || goalName.trim().isEmpty) {
      return false;
    }

    final defaultGoalDate = editing?.date ?? DateTime.now();

    final dateText = await AifcChatSheet.show(
      context: context,
      question: '${goalName.trim()} 목표 날짜는 언제인가요?',
      inputLabel: 'YYYY-MM-DD',
      initialValue: _goalDateText(defaultGoalDate),
      keyboardType: TextInputType.datetime,
      autoCompleteHints: [
        _goalDateText(DateTime.now()),
        _goalDateText(DateTime.now().add(const Duration(days: 30))),
        _goalDateText(DateTime.now().add(const Duration(days: 60))),
        _goalDateText(DateTime.now().add(const Duration(days: 100))),
      ],
      skipLabel: '취소할게요',
      onSkip: () {},
      onSave: (value) async {
        final rawDate =
            value.trim().isEmpty
                ? _goalDateText(defaultGoalDate)
                : value.trim();

        final parsed = _parseGoalDateText(rawDate);

        if (parsed == null) {
          return '날짜 형식이 맞지 않아요.\n예: 2026-08-20 형식으로 입력해주세요.';
        }

        final today = _dateOnly(DateTime.now());
        final target = _dateOnly(parsed);

        if (target.isBefore(today)) {
          return 'D-DAY는 오늘 이후 날짜만 등록할 수 있어요.\n오늘 날짜 또는 앞으로의 날짜로 다시 입력해주세요.';
        }

        final diff = target.difference(today).inDays;

        final ddayText =
            diff == 0
                ? 'D-DAY'
                : diff > 0
                ? 'D-$diff'
                : 'D+${diff.abs()}';

        return '${goalName.trim()} · $ddayText로 저장할게요.\n회원리스트의 MORE 데이에도 함께 반영돼요.';
      },
    );

    if (!mounted || dateText == null) {
      return false;
    }

    final safeDateText =
        dateText.trim().isEmpty
            ? _goalDateText(defaultGoalDate)
            : dateText.trim();

    final parsedDate = _parseGoalDateText(safeDateText);

    if (parsedDate == null) {
      _showSnack('D-DAY 날짜를 YYYY-MM-DD 형식으로 입력해주세요.');
      return false;
    }

    final today = _dateOnly(DateTime.now());
    final targetDate = _dateOnly(parsedDate);

    if (targetDate.isBefore(today)) {
      _showSnack('D-DAY는 오늘 이후 날짜만 등록할 수 있어요.');
      return false;
    }

    final next =
        editing ??
        _GoalDdayItem(
          id: _goalDdayDocId(),
          name: goalName.trim(),
          date: parsedDate,
        );

    next.name = goalName.trim();
    next.date = parsedDate;

    await _upsertGoalDday(next);

    if (!mounted) return false;

    _showSnack(
      editing == null
          ? '${next.name} D-DAY를 추가했어요.'
          : '${next.name} D-DAY를 수정했어요.',
    );

    return true;
  }

  Future<void> _openGoalDdayManageSheet() async {
    if (!await _guardDdayFeature()) return;

    await _loadGoalDdaysFromFirestore();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _GoalDdayManageSheet(
            goals: List<_GoalDdayItem>.from(_goalDdays),
            onAdd: () async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 160));
              if (!mounted) return;
              await _openGoalDdayAifcFlow(editing: null);
            },
            onEdit: (goal) async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(milliseconds: 160));
              if (!mounted) return;
              await _openGoalDdayAifcFlow(editing: goal);
            },
            onComplete: (goal) async {
              Navigator.of(context).pop();
              await _completeGoalDday(goal);
            },
            onPause: (goal) async {
              Navigator.of(context).pop();
              await _pauseGoalDday(goal);
            },
            onStop: (goal) async {
              Navigator.of(context).pop();
              await _stopGoalDday(goal);
            },
            onResume: (goal) async {
              Navigator.of(context).pop();
              await _resumeGoalDday(goal);
            },
            onDelete: (goal) async {
              Navigator.of(context).pop();

              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('D-DAY를 삭제할까요?'),
                    content: Text(
                      '${goal.name} D-DAY를 삭제합니다.\n삭제 후에는 되돌릴 수 없어요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  );
                },
              );

              if (ok == true) {
                await _deleteGoalDday(goal);
                if (!mounted) return;
                _showSnack('${goal.name} D-DAY를 삭제했어요.');
              }
            },
          ),
    );
  }

  // 레슨일지 설정: 새 레슨일지에서 레슨 전 체크리스트를 자동으로 열지 정한다(기기 안 저장).
  Future<void> _openLogSettings() async {
    final owner = _personalOwnerUid;
    var autoOpen = await TrainingLogPreferences.autoOpenPreCheck(owner);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        '레슨일지 설정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      key: const Key('log_setting_auto_pre_check'),
                      title: const Text('레슨 전 체크 자동으로 열기'),
                      subtitle: Text(
                        autoOpen
                            ? '새 레슨일지를 만들면 레슨 전 체크리스트가 먼저 열려요.'
                            : '꺼져 있어요. 레슨 전 체크는 일지 안의 카드에서 직접 열 수 있어요.',
                      ),
                      value: autoOpen,
                      onChanged: (value) async {
                        setSheetState(() => autoOpen = value);
                        await TrainingLogPreferences.setAutoOpenPreCheck(
                          owner,
                          value,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCalendarMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('레슨 달력 보기'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openLessonCalendar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('목표 D-DAY 추가'),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Future.delayed(const Duration(milliseconds: 180));

                    if (!mounted) return;

                    await _openGoalDdayAifcFlow(editing: null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('목표 D-DAY 관리'),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Future.delayed(const Duration(milliseconds: 180));

                    if (!mounted) return;

                    await _openGoalDdayManageSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInbodyScanOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('카메라로 촬영'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!await prepareInbodyCameraUse(context)) return;
                    if (!mounted) return;
                    await _pickAndScanInbody(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('갤러리에서 가져오기'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickAndScanInbody(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndScanInbody(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) return;

      final recognizer = TextRecognizer(script: TextRecognitionScript.korean);

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      final extracted = _extractInbodyData(recognizedText.text);

      if (!mounted) return;

      await _openInbodyReviewSheet(
        imageFile: File(picked.path),
        data: extracted,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('인바디 용지 인식 중 오류가 발생했어요: $e');
    }
  }

  _ExtractedInbodyData _extractInbodyData(String raw) {
    final lines =
        raw
            .split(RegExp(r'[\r\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    String findValue(List<String> keywords) {
      for (int i = 0; i < lines.length; i++) {
        final compact = lines[i].replaceAll(' ', '').toLowerCase();
        final hasKeyword = keywords.any(
          (keyword) =>
              compact.contains(keyword.replaceAll(' ', '').toLowerCase()),
        );

        if (!hasKeyword) continue;

        final currentMatch = RegExp(
          r'(\d{1,3}(?:[.,]\d{1,2})?)',
        ).firstMatch(lines[i]);
        if (currentMatch != null) {
          return currentMatch.group(1)!.replaceAll(',', '.');
        }

        if (i + 1 < lines.length) {
          final nextMatch = RegExp(
            r'(\d{1,3}(?:[.,]\d{1,2})?)',
          ).firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            return nextMatch.group(1)!.replaceAll(',', '.');
          }
        }
      }

      return '';
    }

    final dateMatch = RegExp(
      r'(20\d{2}[.\-/]\d{1,2}[.\-/]\d{1,2})',
    ).firstMatch(raw);

    return _ExtractedInbodyData(
      date: dateMatch?.group(1)?.replaceAll('/', '.') ?? '',
      weight: findValue(['체중', 'weight']),
      skeletalMuscle: findValue(['골격근량', 'smm']),
      bodyFatPercent: findValue(['체지방률', 'pbf', '%체지방']),
    );
  }

  double? _tryParseDouble(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _openInbodyReviewSheet({
    required File imageFile,
    required _ExtractedInbodyData data,
  }) async {
    final dateC = TextEditingController(text: data.date);
    final weightC = TextEditingController(text: data.weight);
    final skeletalC = TextEditingController(text: data.skeletalMuscle);
    final bodyFatC = TextEditingController(text: data.bodyFatPercent);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '인바디 인식 결과 확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '자동 인식된 값이 맞는지 확인하고 필요하면 수정해주세요.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      imageFile,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: dateC,
                    decoration: const InputDecoration(
                      labelText: '측정일',
                      hintText: '예: 2026.06.01',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '체중',
                      suffixText: 'kg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: skeletalC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '골격근량',
                      suffixText: 'kg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyFatC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '체지방률',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _latestInbodyDate = dateC.text.trim();
                          _latestWeight = weightC.text.trim();
                          _latestBodyFatPercent = bodyFatC.text.trim();
                        });

                        Navigator.pop(sheetContext);
                        _showSnack('인바디 값을 반영했어요.');
                      },
                      child: const Text('반영하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    dateC.dispose();
    weightC.dispose();
    skeletalC.dispose();
    bodyFatC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_entryAccessResolved || !_entryAccessAllowed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final headerName = (widget.memberName ?? '').trim();
    final headerTrainer = (widget.trainerName ?? '').trim();

    final headerTitle = headerName.isNotEmpty ? '$headerName 님 레슨일지' : '레슨일지';

    final latestLessonDate = widget.lastLogAt ?? _latestLogDate();
    final lastLessonText =
        latestLessonDate == null ? '기록없음' : _fmtDotYmd(latestLessonDate);

    final recentIssue =
        (widget.recentIssue ?? '').trim().isNotEmpty
            ? widget.recentIssue!.trim()
            : '최근 이슈 · 무릎 통증 호소';

    final reRegistrationLabel =
        (widget.reRegistrationLabel ?? '').trim().isNotEmpty
            ? widget.reRegistrationLabel!.trim()
            : '3회차';

    final openingMent =
        (widget.openingMent ?? '').trim().isNotEmpty
            ? widget.openingMent!.trim()
            : '지난레슨에 상체근력 트레이닝 진행하여, 오늘은 하체근력 트레이닝을 진행해볼게요.';
    final headerInitialGoal = _initialGoalLabel();
    final headerGoalDday = _goalDdayLabel();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kLogMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _ExerciseLogBlueHeader(
                    title: headerTitle,
                    totalSessions: _logs.length,
                    remainingSessions: widget.remainingSessions ?? 0,
                    lastLessonText: lastLessonText,
                    reRegistrationLabel: reRegistrationLabel,
                    recentIssue: recentIssue,
                    openingMent: openingMent,
                    inbodyPoints: _inbodyHistory,
                    briefingLastLesson: _briefingLastLesson(),
                    briefingWarning: _briefingWarning(),
                    briefingRested: _briefingRested(),
                    initialGoalLabel: headerInitialGoal,
                    goalDdayLabel: headerGoalDday,
                    isExpanded: _isHeaderInfoExpanded,
                    onBackTap: () {
                      Navigator.of(context).maybePop();
                    },
                    onToggleExpand: () {
                      setState(() {
                        _isHeaderInfoExpanded = !_isHeaderInfoExpanded;
                      });
                    },
                    onInbodyTap: _openInbodyMeasure,
                    onCalendarTap: _openCalendarMenu,
                    onSettingsTap: _openLogSettings,
                    anatomyHistory:
                        _isHeaderInfoExpanded &&
                                (widget.memberId ?? '').trim().isNotEmpty
                            ? AnatomyMemberHistory(_anatomyRecords)
                            : null,
                    onAnatomyHistoryTap: _openAnatomyHistory,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _logScrollController,
                      padding: const EdgeInsets.fromLTRB(
                        kLogPageHorizontalPadding,
                        14,
                        kLogPageHorizontalPadding,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCreateButton(),
                          const SizedBox(height: 12),
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildLogFilterBar(),
                          const SizedBox(height: 12),
                          _buildNoticeBox(),
                          const SizedBox(height: 12),
                          _buildLogList(),
                          const SizedBox(height: 90),
                        ],
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
  }

  Widget _buildPerformanceCard() {
    final chartLogs = _chartLogs();
    final latest = _latestScore();
    final change = _scoreChange();

    final changeLabel =
        change == 0
            ? '변화 없음'
            : change > 0
            ? '+${change.toStringAsFixed(1)}'
            : change.toStringAsFixed(1);

    final latestInbodySummary = <String>[
      if (_latestInbodyDate.isNotEmpty) '최근 인바디 $_latestInbodyDate',
      if (_latestWeight.isNotEmpty) '체중 $_latestWeight',
      if (_latestBodyFatPercent.isNotEmpty) '체지방률 $_latestBodyFatPercent%',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: kLogCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLogBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '운동성과',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD7EAFE)),
                ),
                child: Text(
                  '최근점수 ${latest.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '최근 ${chartLogs.length}회 기준 · 변화 $changeLabel',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (latestInbodySummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              latestInbodySummary,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            height: 190,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child:
                chartLogs.isEmpty
                    ? const Center(
                      child: Text(
                        '아직 표시할 운동성과 기록이 없어요.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black45,
                        ),
                      ),
                    )
                    : _PerformanceLineChart(logs: chartLogs),
          ),
          const SizedBox(height: 14),
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildLogFilterBar() {
    final chips = <Widget>[
      _buildFilterChip('전체', 'all'),
      const SizedBox(width: 8),
      _buildFilterChip('확정완료', 'locked'),
      const SizedBox(width: 8),
      _buildMoreFilterToggleChip(),
    ];

    if (_showMoreLogFilters) {
      chips.addAll([
        const SizedBox(width: 8),
        _buildFilterChip('서비스', 'service'),
        const SizedBox(width: 8),
        _buildFilterChip('미서명', 'unsigned'),
        const SizedBox(width: 8),
        _buildFilterChip('노쇼', 'no_show'),
        const SizedBox(width: 8),
        _buildFilterChip('미차감 노쇼', 'no_show_no_deduct'),
        const SizedBox(width: 8),
        _buildFilterChip('확정취소', 'cancelled'),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _buildSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.trainingLogSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.trainingLogSetDivider),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '스쿼트, 무릎통증, 허리, 메모, 큐잉',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              tooltip: '검색 지우기',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreFilterToggleChip() {
    final opened = _showMoreLogFilters;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return InkWell(
      onTap: () {
        setState(() {
          _showMoreLogFilters = !_showMoreLogFilters;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: opened ? tokens.trainingLogSetRow : tokens.trainingLogSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.trainingLogSetDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              opened ? Icons.keyboard_arrow_up_rounded : Icons.add_rounded,
              size: 15,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              opened ? '접기' : '더보기',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSectionHeader(DateTime date) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Text(
            _fmtDotYmd(date),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: tokens.trainingLogSetDivider),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _logFilter == value;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return InkWell(
      onTap: () {
        setState(() {
          _logFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.secondary : tokens.trainingLogSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.secondary : tokens.trainingLogSetDivider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? scheme.onSecondary : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openNewLogSheet,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '오늘 레슨일지 작성',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMemberSignRequestSheetFromLogPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.secondary,
              side: BorderSide(color: scheme.secondary.withValues(alpha: 0.44)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text(
              '회원 서명 요청',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeBox() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.44)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "• 달력에서 표시된 날만 레슨 기록이 있어요\n"
              "• 날짜를 누르면 당일의 레슨일지만 바로 볼 수 있어요\n"
              "• 전체 기록으로 다시 흐름을 확인할 수 있어요\n"
              "• 카드에는 핵심만, 자세한 내용은 탭해서 확인해요",
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSecondaryContainer,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final logs = _filteredLogs();
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    if (logs.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.trainingLogSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.trainingLogSetDivider),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _searchQuery.isNotEmpty
                    ? "검색 결과가 없어요.\n다른 키워드로 다시 검색해보세요."
                    : "조건에 맞는 레슨일지가 없어요.\n필터를 바꾸거나 새 기록을 작성해보세요.",
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> children = [];
    DateTime? previousDate;

    for (final log in logs) {
      final currentDate = DateTime(log.date.year, log.date.month, log.date.day);

      if (_isMonthChanged(currentDate, previousDate)) {
        children.add(
          _buildTimelineSectionHeader(_monthSectionLabel(currentDate)),
        );
      }

      children.add(
        KeyedSubtree(
          key: _keyForLog(log.id),
          child: _TrainingLogCard(
            item: log,
            sessionNumber: _sessionNumberOf(log),
            sessionDisplayText: _sessionDisplayText(log),
            registrationStartText: '',
            isHighlighted: _highlightDraftId == log.id,
            isExpanded: _expandedLogId == log.id,
            anatomySummary:
                log.inputMethod == 'anatomy' && !log.isDraft
                    ? _anatomySummaries[_firestoreLogDocIdFromLog(log)]
                    : null,
            onShareLesson:
                log.isDraft
                    ? null
                    : log.inputMethod == 'anatomy'
                    ? () => _shareAnatomyLesson(log)
                    : (log.inputMethod == 'category' ||
                        log.inputMethod == 'text' ||
                        log.inputMethod == 'voice_draft')
                    ? () => _shareTextOrCategoryLesson(log)
                    : null,
            // 아나토미 카드는 탭하면 레슨일지가 열리므로 펼침은 화살표로 따로 한다.
            onToggleExpand:
                log.inputMethod == 'anatomy' && !log.isDraft
                    ? () => setState(() {
                      _expandedLogId = _expandedLogId == log.id ? null : log.id;
                    })
                    : null,
            goalDdayLabel: _goalDdayLabel(),
            femaleConditionVisible: _shouldShowFemaleConditionChip(log.date),
            onFemaleConditionTap: _showFemaleConditionHint,
            draftEntryMode: log.draftEntryMode,
            onTap: () {
              if (log.isDraft) {
                if (log.draftEntryMode == 'text' ||
                    log.draftEntryMode == 'category') {
                  _openEditorForDraft(log, forcedMode: log.draftEntryMode);
                  return;
                }

                if (log.draftEntryMode == 'pdf') {
                  _openPdfDraftPage(log);
                  return;
                }

                if (log.draftEntryMode == 'anatomy') {
                  _openAnatomyLogPage(log);
                  return;
                }

                _openDraftEntryPicker(log);
                return;
              }

              if (log.inputMethod == 'anatomy') {
                _openAnatomyLogPage(log);
                return;
              }

              setState(() {
                _expandedLogId = _expandedLogId == log.id ? null : log.id;
              });
            },
            onLongPress: () async {
              if (log.isDraft) {
                if (log.draftEntryMode.isNotEmpty) {
                  final ok = await _confirmChangeDraftEntryMode(log);
                  if (!ok) return;

                  setState(() {
                    log.draftEntryMode = '';
                    log.memo = '';
                    log.title = '레슨일지 작성 전';
                    log.inputMethod = '';
                    log.issueChips = [];
                    log.homeworkStatus = '없음';
                    log.nextLessonCheckpoint = '';
                    log.internalMemo = '';
                    log.publicSummary = '';
                    log.publicGood = '';
                    log.publicHomeworkNote = '';
                    log.publicCaution = '';
                    log.exercises = [];
                  });
                  await _persistPersonalLogDraft(log);
                }

                _openDraftEntryPicker(log);
                return;
              }

              _openLogMoreMenu(log);
            },
            onTapTrainerSig: () => _tapSig(log, 'trainer'),
            onTapCustomerSig: () => _tapSig(log, 'customer'),
            onLongPressSig: () => _openLogMoreMenu(log),
          ),
        ),
      );

      if (log.isRegistrationStart && log.registrationLabel.isNotEmpty) {
        children.add(
          _buildTimelineSectionHeader(
            '${_fmtDotYmd(log.date)} ${log.registrationLabel} ${log.packageCount}회 ${log.type} 레슨 시작',
          ),
        );
      }

      children.add(const SizedBox(height: 10));
      previousDate = currentDate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Future<String?> _askPin(BuildContext ctx) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('PIN 입력'),
            content: TextField(
              controller: c,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '기본 PIN 0000',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  int _minusOneFloorZero(dynamic value) {
    final current = _intFromAny(value);
    return current > 0 ? current - 1 : 0;
  }

  String _firestoreLogDocIdFromLog(_TrainingLogItem log) {
    final explicit = log.trainingLogDocId.trim();
    if (explicit.isNotEmpty) return explicit;

    final id = log.id.trim();

    if (id.startsWith('quick_')) {
      return id.replaceFirst('quick_', '');
    }

    return id;
  }

  String _firestoreStatusFromLocalStatus(String status) {
    switch (status) {
      case 'service':
        return 'service';
      case 'no_show':
        return 'no_show_deducted';
      case 'no_show_no_deduct':
        return 'no_show_not_deducted';
      case 'normal':
      default:
        return 'completed';
    }
  }

  List<String> _deductionKeysForCancel({
    required _TrainingLogItem log,
    required String logDocId,
    required Map<String, dynamic> logData,
  }) {
    final keys = <String>{
      if ((logData['deductionKey'] ?? '').toString().trim().isNotEmpty)
        (logData['deductionKey'] ?? '').toString().trim(),

      // 빠른서명 페이지에서 쓰는 키
      'personal_training_quick_log:$logDocId',

      // 레슨일지 페이지에서 쓰는 키
      'training_log_${log.id.trim()}',
      'training_log_$logDocId',
    };

    keys.removeWhere((e) => e.trim().isEmpty);
    return keys.toList();
  }

  DateTime _dateFromAnyOrLog(dynamic value, _TrainingLogItem log) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }

    return _actualLessonDateTime(log);
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _koreanLessonDateTimeText(DateTime value) {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

    final weekday = weekdays[value.weekday - 1];
    final isPm = value.hour >= 12;
    final ampm = isPm ? '오후' : '오전';

    var hour = value.hour % 12;
    if (hour == 0) hour = 12;

    final minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}년 ${value.month}월 ${value.day}일 $weekday $ampm $hour:$minute';
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findScheduleRefForLog({
    required String logDocId,
    required String scheduleDocId,
  }) async {
    final db = FirebaseFirestore.instance;

    final cleanScheduleId = scheduleDocId.trim();
    if (cleanScheduleId.isNotEmpty) {
      return db.collection('schedules').doc(cleanScheduleId);
    }

    final fields = ['trainingLogId', 'quickTrainingLogId', 'lastTrainingLogId'];

    try {
      for (final field in fields) {
        Query<Map<String, dynamic>> query = db
            .collection('schedules')
            .where(field, isEqualTo: logDocId);
        if (_isPersonalWorkspace) {
          final memberId = (widget.memberId ?? '').trim();
          if (memberId.isEmpty) return null;
          query = query
              .where('trainerId', isEqualTo: _personalOwnerUid)
              .where('workspaceType', isEqualTo: 'personal')
              .where('memberId', isEqualTo: memberId);
        }
        final snap = await query.limit(1).get();

        if (snap.docs.isNotEmpty) {
          return snap.docs.first.reference;
        }
      }
    } catch (error) {
      _logFirestoreReadFailure(source: 'schedule_for_log', error: error);
    }

    return null;
  }

  Future<void> _queueLessonConfirmCancelledTalkNotice({
    required String memberId,
    required String memberName,
    required String memberPhone,
    required String scheduleDocId,
    required String trainingLogId,
    required String lessonType,
    required DateTime startAt,
  }) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    String resolvedName = memberName.trim().isEmpty ? '회원' : memberName.trim();
    String resolvedPhone = _normalizePhone(memberPhone);

    try {
      final memberSnap =
          await FirebaseFirestore.instance
              .collection('members')
              .doc(cleanMemberId)
              .get();

      final data = memberSnap.data();

      if (data != null) {
        final loadedName = (data['name'] ?? '').toString().trim();
        final loadedPhone = _normalizePhone((data['phone'] ?? '').toString());

        if (loadedName.isNotEmpty) resolvedName = loadedName;
        if (resolvedPhone.isEmpty && loadedPhone.isNotEmpty) {
          resolvedPhone = loadedPhone;
        }
      }
    } catch (_) {}

    final dateText = _koreanLessonDateTimeText(startAt);

    await FirebaseFirestore.instance.collection('talk_notification_queue').add({
      'type': 'lesson_confirm_cancelled',
      'channel': 'kakao_alimtalk',
      'templateCode': 'lesson_confirm_cancelled_v1',

      // 실제 카카오 API 연결 전까지 대기 상태
      'status':
          resolvedPhone.isEmpty
              ? 'pending_missing_phone'
              : 'pending_integration',

      // 확정취소는 설정과 무관하게 필수 발송 대상
      'sendRequired': true,
      'canBeDisabledByMemberSetting': false,

      'memberId': cleanMemberId,
      'memberName': resolvedName,
      'memberPhone': resolvedPhone,

      'scheduleDocId': scheduleDocId,
      'trainingLogId': trainingLogId,

      'lessonType': lessonType,
      'startAt': Timestamp.fromDate(startAt),
      'cancelReason': '강사 확정 취소',

      'messagePreview':
          '$resolvedName 님, $dateText $lessonType 레슨 확정이 취소되었습니다.',

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _applyConfirmCancelToLocalLog(_TrainingLogItem log) {
    setState(() {
      log.locked = false;
      log.deductionApplied = false;
      log.confirmCancelled = true;
      log.waitingTrainerConfirm = false;

      log.trainerSig = SigCell.empty();
      log.customerSig = SigCell.empty();

      log.trainerSignedDate = '';
      log.trainerSignedTime = '';
      log.customerSignedDate = '';
      log.customerSignedTime = '';
      log.lockedAtDate = '';
      log.lockedAtTime = '';
    });
  }

  Future<bool> _confirmCancelLogWithPin(
    _TrainingLogItem log,
    String pin,
  ) async {
    if (pin.trim() != kResetPin) {
      return false;
    }

    if (!log.locked) {
      return true;
    }

    final memberId = (widget.memberId ?? '').trim();
    final logDocId = _firestoreLogDocIdFromLog(log);

    if (logDocId.isEmpty) {
      _applyConfirmCancelToLocalLog(log);
      return true;
    }

    final db = FirebaseFirestore.instance;

    final logRef = db.collection('training_logs').doc(logDocId);

    final scheduleRef = await _findScheduleRefForLog(
      logDocId: logDocId,
      scheduleDocId: log.scheduleDocId,
    );

    final memberRef =
        memberId.isEmpty ? null : db.collection('members').doc(memberId);

    String resolvedScheduleDocId = log.scheduleDocId.trim();
    String resolvedMemberPhone = (widget.memberPhone ?? '').toString();
    String resolvedMemberName =
        log.name.trim().isEmpty
            ? ((widget.memberName ?? '').trim().isEmpty
                ? '회원'
                : widget.memberName!.trim())
            : log.name.trim();

    DateTime resolvedStartAt = _actualLessonDateTime(log);
    String resolvedLessonType = log.type;

    await db.runTransaction((tx) async {
      final logSnap = await tx.get(logRef);
      final logData = logSnap.data() ?? <String, dynamic>{};

      DocumentSnapshot<Map<String, dynamic>>? scheduleSnap;
      Map<String, dynamic> scheduleData = <String, dynamic>{};

      if (scheduleRef != null) {
        scheduleSnap = await tx.get(scheduleRef);
        scheduleData = scheduleSnap.data() ?? <String, dynamic>{};

        resolvedScheduleDocId = scheduleRef.id;

        final scheduleStartAt = scheduleData['startAt'];
        resolvedStartAt = _dateFromAnyOrLog(scheduleStartAt, log);

        final scheduleName = (scheduleData['name'] ?? '').toString().trim();
        if (scheduleName.isNotEmpty) resolvedMemberName = scheduleName;

        final schedulePhone = (scheduleData['phone'] ?? '').toString().trim();
        if (schedulePhone.isNotEmpty) resolvedMemberPhone = schedulePhone;

        final scheduleType =
            (scheduleData['type'] ?? scheduleData['lessonType'] ?? '')
                .toString()
                .trim();

        if (scheduleType.isNotEmpty) resolvedLessonType = scheduleType;
      }

      Map<String, dynamic> memberData = <String, dynamic>{};

      if (memberRef != null) {
        final memberSnap = await tx.get(memberRef);
        memberData = memberSnap.data() ?? <String, dynamic>{};

        final memberName = (memberData['name'] ?? '').toString().trim();
        if (memberName.isNotEmpty) resolvedMemberName = memberName;

        final memberPhone = (memberData['phone'] ?? '').toString().trim();
        if (memberPhone.isNotEmpty) resolvedMemberPhone = memberPhone;
      }

      final sessions =
          memberData['sessions'] is Map
              ? Map<String, dynamic>.from(memberData['sessions'] as Map)
              : <String, dynamic>{};

      final lessonStats =
          memberData['lessonStats'] is Map
              ? Map<String, dynamic>.from(memberData['lessonStats'] as Map)
              : <String, dynamic>{};

      final currentRemain = _intFromAny(
        memberData['remainSessions'] ??
            memberData['remainingSessions'] ??
            sessions['remain'] ??
            memberData['remainingPt'] ??
            memberData['ptRemaining'],
      );

      final currentTotal = _intFromAny(
        memberData['totalSessions'] ??
            sessions['total'] ??
            memberData['sessionTotal'],
      );

      final rawDone = memberData['doneSessions'] ?? sessions['done'];
      final currentDone =
          rawDone == null
              ? (currentTotal - currentRemain).clamp(0, currentTotal)
              : _intFromAny(rawDone);

      final logDeductionApplied =
          logData['deductionApplied'] == true || log.deductionApplied;

      final snapshotBefore = _intFromAny(
        scheduleData['sessionSnapshotRemainBefore'],
      );
      final snapshotAfter = _intFromAny(
        scheduleData['sessionSnapshotRemainAfter'],
      );

      final looksDeductedBySnapshot =
          snapshotBefore > 0 && snapshotBefore > snapshotAfter;

      final shouldRestoreOne = logDeductionApplied || looksDeductedBySnapshot;

      final restoredRemain =
          shouldRestoreOne ? currentRemain + 1 : currentRemain;

      final restoredDone =
          shouldRestoreOne
              ? (currentDone > 0 ? currentDone - 1 : 0)
              : currentDone;

      final firestoreStatus =
          (logData['sessionStatus'] ??
                  scheduleData['lessonConfirmStatus'] ??
                  _firestoreStatusFromLocalStatus(log.sessionStatus))
              .toString();

      final deductionKeys = _deductionKeysForCancel(
        log: log,
        logDocId: logDocId,
        logData: logData,
      );

      if (memberRef != null) {
        final memberUpdate = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLessonStatus': 'confirm_cancelled',
          'lessonStats.lastConfirmStatus': 'confirm_cancelled',
          'lessonStats.lastCancelledAt': FieldValue.serverTimestamp(),
          'confirmedTrainingLogIds': FieldValue.arrayRemove([logDocId]),
          'deductedTrainingLogIds': FieldValue.arrayRemove(deductionKeys),
        };

        if (shouldRestoreOne) {
          memberUpdate.addAll({
            'remainSessions': restoredRemain,
            'remainingSessions': restoredRemain,
            'doneSessions': restoredDone,
            'sessions.remain': restoredRemain,
            'sessions.done': restoredDone,
            'lessonSync.cancelledLogId': logDocId,
            'lessonSync.cancelledAt': FieldValue.serverTimestamp(),
          });
        }

        if (firestoreStatus == 'no_show_deducted') {
          memberUpdate['noShowDeductedCount'] = _minusOneFloorZero(
            memberData['noShowDeductedCount'],
          );
          memberUpdate['sessions.noShowDeductedCount'] = _minusOneFloorZero(
            sessions['noShowDeductedCount'],
          );
          memberUpdate['lessonStats.noShowDeductedCount'] = _minusOneFloorZero(
            lessonStats['noShowDeductedCount'],
          );
        } else if (firestoreStatus == 'no_show_not_deducted') {
          memberUpdate['noShowUndeductedCount'] = _minusOneFloorZero(
            memberData['noShowUndeductedCount'],
          );
          memberUpdate['sessions.noShowUndeductedCount'] = _minusOneFloorZero(
            sessions['noShowUndeductedCount'],
          );
          memberUpdate['lessonStats.noShowUndeductedCount'] =
              _minusOneFloorZero(lessonStats['noShowUndeductedCount']);
        } else if (firestoreStatus == 'service') {
          memberUpdate['serviceSessionCount'] = _minusOneFloorZero(
            memberData['serviceSessionCount'],
          );
          memberUpdate['sessions.serviceSessionCount'] = _minusOneFloorZero(
            sessions['serviceSessionCount'],
          );
          memberUpdate['lessonStats.serviceSessionCount'] = _minusOneFloorZero(
            lessonStats['serviceSessionCount'],
          );
        } else if (firestoreStatus == 'completed') {
          memberUpdate['lessonStats.completedCount'] = _minusOneFloorZero(
            lessonStats['completedCount'],
          );
        }

        memberUpdate['lessonStats.confirmedCount'] = _minusOneFloorZero(
          lessonStats['confirmedCount'],
        );

        tx.set(memberRef, memberUpdate, SetOptions(merge: true));

        final reverseLedgerRef = memberRef
            .collection('lesson_ledger')
            .doc('${logDocId}_reverse');

        tx.set(reverseLedgerRef, {
          'type': 'reverse',
          'source': 'confirm_cancel',
          'scheduleId': resolvedScheduleDocId,
          'logId': logDocId,
          'status': firestoreStatus,
          'restoredSessions': shouldRestoreOne ? 1 : 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      tx.set(logRef, {
        'voided': true,
        'voidedAt': FieldValue.serverTimestamp(),
        'voidReason': 'trainer_cancel_confirm',
        'voidSource': 'training_log_page',
        'locked': false,
        'lessonConfirmed': false,
        'deductionApplied': false,
        'confirmCancelled': true,
        'confirmCancelledAt': FieldValue.serverTimestamp(),
        'sessionStatusBeforeCancel': firestoreStatus,
        'updatedAt': FieldValue.serverTimestamp(),

        // 기존 문서가 없던 수기 로그도 최소 식별 가능하게 보강
        'memberId': memberId.isEmpty ? null : memberId,
        'memberName': resolvedMemberName,
        'lessonType': resolvedLessonType,
        'startAt': Timestamp.fromDate(resolvedStartAt),
      }, SetOptions(merge: true));

      if (scheduleRef != null) {
        final scheduleCancelUpdate = <String, dynamic>{
          'lessonConfirmed': FieldValue.delete(),
          'lessonConfirmedAt': FieldValue.delete(),
          'lessonConfirmStatus': FieldValue.delete(),
          'lessonConfirmLabel': FieldValue.delete(),
          'trainingLogId': FieldValue.delete(),
          'quickTrainingLogId': FieldValue.delete(),
          'lastTrainingLogId': FieldValue.delete(),
          'lastSignedAt': FieldValue.delete(),
          'attendanceOverride': FieldValue.delete(),
          'memberSigned': FieldValue.delete(),
          'customerSigned': FieldValue.delete(),
          'memberSignedAt': FieldValue.delete(),
          'customerSignedAt': FieldValue.delete(),
          'memberSignature': FieldValue.delete(),
          'customerSignature': FieldValue.delete(),
          'cancelLockedByMemberSignature': FieldValue.delete(),
          'cancelLockReason': FieldValue.delete(),
          'sessionSnapshotTotal': FieldValue.delete(),
          'sessionSnapshotRemainBefore': FieldValue.delete(),
          'sessionSnapshotRemainAfter': FieldValue.delete(),
          'sessionSnapshotDoneBefore': FieldValue.delete(),
          'sessionSnapshotDoneAfter': FieldValue.delete(),
          'sessionSnapshotLessonNumber': FieldValue.delete(),
          'sessionSnapshotLabel': FieldValue.delete(),
          'attended': false,
          'confirmCancelledAt': FieldValue.serverTimestamp(),
          'confirmCancelledLogId': logDocId,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (currentTotal > 0) {
          scheduleCancelUpdate['totalSessions'] = currentTotal.toString();
        }

        scheduleCancelUpdate['remainingSessions'] = restoredRemain.toString();
        scheduleCancelUpdate['remainSessions'] = restoredRemain.toString();

        tx.set(scheduleRef, scheduleCancelUpdate, SetOptions(merge: true));
      }
    });

    await _queueLessonConfirmCancelledTalkNotice(
      memberId: memberId,
      memberName: resolvedMemberName,
      memberPhone: resolvedMemberPhone,
      scheduleDocId: resolvedScheduleDocId,
      trainingLogId: logDocId,
      lessonType: resolvedLessonType,
      startAt: resolvedStartAt,
    );

    _applyConfirmCancelToLocalLog(log);

    return true;
  }

  Future<void> _tryUnlockLog(_TrainingLogItem log) async {
    if (!log.locked) return;
    _openLogMoreMenu(log);

    setState(() {
      log.locked = false;
      log.trainerSig = SigCell.empty();
      log.customerSig = SigCell.empty();
      log.trainerSignedDate = '';
      log.trainerSignedTime = '';
      log.customerSignedDate = '';
      log.customerSignedTime = '';
      log.lockedAtDate = '';
      log.lockedAtTime = '';
    });

    _showSnack('확정 취소 완료 · 서명/시간이 초기화되었어요.');
  }

  Future<void> _tapSig(_TrainingLogItem log, String role) async {
    if (log.confirmCancelled) {
      _showSnack('확정취소된 레슨일지는 확인만 가능해요.');
      return;
    }

    if (log.locked) {
      _showSnack('이미 확정된 레슨입니다. 길게 눌러 확정 취소를 진행할 수 있어요.');
      return;
    }

    final isTrainer = role == 'trainer';
    final initial = isTrainer ? log.trainerSig : log.customerSig;

    final typedController = TextEditingController(
      text: isTrainer ? _lastTrainerTyped : _lastCustomerTyped,
    );

    final result = await showModalBottomSheet<SigCell>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => SignatureSheet(
            title: isTrainer ? '강사 서명' : '회원 서명',
            initial: initial,
            typedController: typedController,
          ),
    );

    if (result == null) return;

    final nowD = _nowIsoDate();
    final nowT = _nowHm();

    bool shouldApplyDeduction = false;

    setState(() {
      if (result.type == 'typed') {
        if (isTrainer) {
          _lastTrainerTyped = result.value;
        } else {
          _lastCustomerTyped = result.value;
        }
      }

      if (isTrainer) {
        log.trainerSig = result;
        log.trainerSignedDate = nowD;
        log.trainerSignedTime = nowT;

        if (log.waitingTrainerConfirm) {
          log.waitingTrainerConfirm = false;
        }
      } else {
        log.customerSig = result;
        log.customerSignedDate = nowD;
        log.customerSignedTime = nowT;
      }

      final wasLocked = log.locked;

      if (log.sessionStatus == 'no_show') {
        // 노쇼 차감은 강사 서명만으로 확정
        if (log.trainerSig.isSigned) {
          log.locked = true;
          log.lockedAtDate = nowD;
          log.lockedAtTime = nowT;
        }
      } else {
        // 일반 레슨은 강사 + 회원 서명 모두 완료되어야 확정
        if (log.trainerSig.isSigned && log.customerSig.isSigned) {
          log.locked = true;
          log.lockedAtDate = nowD;
          log.lockedAtTime = nowT;
        }
      }

      shouldApplyDeduction = !wasLocked && log.locked && !log.deductionApplied;
    });

    if (shouldApplyDeduction) {
      await _applyRemainingSessionDeductionIfNeeded(log);
    } else if (log.locked) {
      await _updateMemberLastLessonOnly(log);
    }
  }

  Future<void> _openNewLogSheet() async {
    final existingDraft = _findTodayDraft();

    if (existingDraft != null) {
      setState(() {
        _highlightDraftId = existingDraft.id;
      });
      _scrollToLog(existingDraft.id);
      _showSnack('오늘 작성 중인 레슨일지가 있어요. 먼저 확인해 주세요.');
      return;
    }

    final now = DateTime.now();

    setState(() {
      _selectedDateFilter = null;

      final draft = _TrainingLogItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: '레슨일지 작성 전',
        name:
            (widget.memberName ?? '').trim().isEmpty
                ? '회원 미지정'
                : (widget.memberName ?? '').trim(),
        time: _nowHm(),
        type: _lastSelectedSessionType,
        memo: '',
        date: now,
        performanceScore: 0,
        inputMethod: 'text',
        rawVoiceText: '',
        isDraft: true,
        draftEntryMode: '',
      );

      _logs.insert(0, draft);
      _highlightDraftId = draft.id;
    });

    _scrollToLog(_logs.first.id);
    _showSnack('새로운 레슨일지를 작성해 보세요.');
  }

  String _generateMemberSignToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random.secure();

    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _buildMemberSignUrl(String token) {
    return MemberSignUrlService.build(token).toString();
  }

  String _quickSignLogIdForCurrentLogPage() {
    final memberId = (widget.memberId ?? '').trim();
    final unique = DateTime.now().microsecondsSinceEpoch;

    return 'quick_sign_${memberId}_$unique';
  }

  Future<Map<String, String>?> _createMemberSignRequestFromLogPage() async {
    final memberId = (widget.memberId ?? '').trim();
    final memberName = (widget.memberName ?? '').trim();

    if (memberId.isEmpty) {
      _showSnack('회원 연결이 없어 서명 요청을 만들 수 없어요.');
      return null;
    }

    final token = _generateMemberSignToken();
    final link = _buildMemberSignUrl(token);
    final now = DateTime.now();
    final trainingLogId = _quickSignLogIdForCurrentLogPage();

    await FirebaseFirestore.instance
        .collection('sign_requests')
        .doc(token)
        .set({
          'token': token,
          'status': 'waiting_member_signature',
          'used': false,
          'memberId': memberId,
          'memberName': memberName.isEmpty ? '회원' : memberName,
          if ((widget.memberPhone ?? '').trim().isNotEmpty)
            'memberPhone': widget.memberPhone!.replaceAll(RegExp(r'\D'), ''),
          'trainingLogId': trainingLogId,
          'lessonType': _lastSelectedSessionType,
          'startAt': Timestamp.fromDate(now),
          'endAt': Timestamp.fromDate(now.add(const Duration(minutes: 50))),
          'requestType': 'member_signature',
          'source': 'training_log_page',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
        }, SetOptions(merge: true));

    return {'token': token, 'link': link, 'trainingLogId': trainingLogId};
  }

  Future<void> _openMemberSignRequestSheetFromLogPage() async {
    final result = await _createMemberSignRequestFromLogPage();

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
                    '${(widget.memberName ?? '').trim().isEmpty ? '회원' : widget.memberName!.trim()} 님에게 서명 링크를 공유하세요.',
                    style: TextStyle(
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
                            await Clipboard.setData(ClipboardData(text: link));

                            _showSnack('서명 링크를 복사했어요.');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            '링크 복사',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: BorderSide(
                              color: const Color(0xFF4F46E5).withOpacity(0.25),
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
                            backgroundColor: const Color(0xFF4F46E5),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmChangeDraftEntryMode(_TrainingLogItem log) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '작성 방식을 다시 선택할까요?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${log.title} 기록의 작성 내용을 초기화하고 작성 방식을 다시 선택합니다.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('다시 선택'),
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

    return result == true;
  }

  Future<void> _openAnatomyProAifcSheet() async {
    final result = await AifcChatSheet.show(
      context: context,
      question:
          '아나토미 기록은 부위 선택 기반으로 레슨 내용을 더 체계적으로 정리하는 PRO 기능이에요.\n\n'
          '지금은 텍스트, 카테고리, PDF 방식은 사용할 수 있고,\n'
          '아나토미는 PRO에서 열어둘게요.',
      inputLabel: '예: PRO 보기 / 나중에',
      autoCompleteHints: const ['PRO 보기', '나중에'],
      skipLabel: '나중에 볼게요',
      onSkip: () {},
      onSave: (value) async {
        final v = value.trim();

        if (v.contains('PRO') || v.contains('프로') || v.contains('보기')) {
          return '좋아요. PRO 안내로 연결해드릴게요.\n아나토미 기록은 부위 선택형 레슨일지로 준비해둘게요.';
        }

        return '좋아요. 지금은 기존 작성 방식으로 진행할게요.\n필요할 때 아나토미 기록을 다시 열어볼 수 있어요.';
      },
    );

    if (!mounted || result == null) return;

    final v = result.trim();

    if (v.contains('PRO') || v.contains('프로') || v.contains('보기')) {
      // TODO: 나중에 실제 PRO/업그레이드 페이지 연결
      _showSnack('PRO 안내 화면 연결 예정입니다.');
    }
  }

  Future<void> _openAnatomyLogPage(_TrainingLogItem log) async {
    final lessonLogId = _firestoreLogDocIdFromLog(log).trim();
    final scheduleDocId = log.scheduleDocId.trim();
    final memberId = (widget.memberId ?? '').trim();
    final trainerId = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    final missing = <String>[
      if (lessonLogId.isEmpty) 'lessonLogId',
      if (memberId.isEmpty) 'memberId',
      if (trainerId.isEmpty) 'trainerId',
    ];
    if (missing.isNotEmpty) {
      debugPrint(
        '[MTF_ANATOMY_IDENTITY] caller=_openAnatomyLogPage '
        'logId=${log.id} missing=${missing.join(',')}',
      );
      _showSnack('연결된 레슨일지·회원·트레이너 정보가 없어 해부학 기록을 저장할 수 없어요.');
      return;
    }

    // 회원카드의 성별로 남/여 바디를 고른다. 못 읽으면 아나토미 화면에서 직접 고른다.
    String? memberGender;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .doc(memberId)
          .get()
          // 느려도 아나토미 화면이 열리게 한다(성별은 화면에서 직접 고를 수 있다).
          .timeout(const Duration(seconds: 3));
      memberGender = snapshot.data()?['gender']?.toString();
    } catch (error) {
      _logFirestoreReadFailure(source: 'anatomy_member_gender', error: error);
    }
    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => PersonalTrainingLogAnatomyPage(
              lessonLogId: lessonLogId,
              recordedAt: _actualLessonDateTime(log),
              memberId: memberId,
              memberName: log.name,
              lessonType: log.type,
              trainerId: trainerId,
              scheduleDocId: scheduleDocId,
              memberGender: memberGender,
              exerciseStore: PersonalAnatomyExerciseStore(
                PersonalCustomExerciseService(uid: trainerId),
              ),
              historyStore: FirestoreAnatomyHistoryStore(),
            ),
      ),
    );

    if (!mounted || saved != true) return;
    setState(() {
      log.isDraft = false;
      log.draftEntryMode = 'anatomy';
      log.inputMethod = 'anatomy';
      log.title = '해부학 레슨일지';
      _highlightDraftId = null;
    });
    _loadAnatomySummaries();
  }

  // 레슨 전 체크리스트의 인바디 측정 줄. 회원이 정해진 개인 워크스페이스에서만 연다.
  Future<String?> Function()? _inbodyMeasureCallback() {
    final memberId = (widget.memberId ?? '').trim();
    if (!_isPersonalWorkspace || memberId.isEmpty) return null;
    return () async {
      final result = await runInbodyMeasureFlow(
        context,
        memberId: memberId,
        memberName: (widget.memberName ?? '').trim(),
      );
      if (result != null) await _loadInbodyHistory();
      return result?.summary;
    };
  }

  // 새 레슨일지는 작성 방식(텍스트·카테고리·PDF·아나토미)과 상관없이 먼저 레슨 전 체크리스트를 연다.
  // 설정에서 끄면 열지 않는다. 완료하면 서버 초안에도 저장해 어떤 방식으로 쓰든 남는다.
  Future<void> _runPreCheckForNewLog(_TrainingLogItem log) async {
    if (!log.isDraft || log.preCheckDone) return;
    if (log.memo.trim().isNotEmpty || log.exercises.isNotEmpty) return;
    final enabled = await TrainingLogPreferences.autoOpenPreCheck(
      _personalOwnerUid,
    );
    if (!enabled || !mounted) return;

    final data = TrainingLogPreCheckData(
      condition: log.preCondition,
      meal: log.preMeal,
      sleep: log.preSleep,
      pain: log.prePain,
      painDetail: log.prePainDetail,
      stretching: log.preStretching,
      note: log.preNote,
      inbodySummary: log.inbodySummary,
      issueChips: {...log.issueChips},
    )..dropImpliedAutoChips();
    final painC = TextEditingController(text: data.painDetail);
    final noteC = TextEditingController(text: data.note);
    final options = <String>[
      ...kDefaultManualIssueOptions,
      ...data.issueChips.where(
        (c) =>
            !kDefaultManualIssueOptions.contains(c) &&
            !kAutoIssueNames.contains(c),
      ),
    ];

    final done = await showTrainingLogPreCheckDialog(
      context,
      memberName: log.name,
      data: data,
      painDetailController: painC,
      noteController: noteC,
      issueOptions: options,
      onAddIssue: () async {
        final value = await showTrainingLogCustomIssueDialog(context);
        if (value != null && !options.contains(value)) options.add(value);
        return value;
      },
      onMeasureInbody: _inbodyMeasureCallback(),
      onChanged: () {},
    );
    painC.dispose();
    noteC.dispose();
    if (!mounted) return;

    setState(() {
      log.preCondition = data.condition;
      log.preMeal = data.meal;
      log.preSleep = data.sleep;
      log.prePain = data.pain;
      log.prePainDetail = data.painDetail.trim();
      log.preStretching = data.stretching;
      log.preNote = data.note.trim();
      log.inbodySummary = data.inbodySummary;
      log.issueChips = data.savedIssueChips;
      log.preCheckDone = done;
    });
    if (done) await _persistPersonalLogDraft(log);
  }

  Future<void> _openDraftEntryPicker(_TrainingLogItem log) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final tokens = sheetContext.mtfThemeTokens;
        return Container(
          decoration: BoxDecoration(
            color: tokens.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlueSheetHeader(
                  title: '레슨일지 작성 방식 선택',
                  subtitle: '레슨 스타일에 맞는 방식으로 빠르게 기록해요.',
                  icon: Icons.edit_note_rounded,
                  onClose: () => Navigator.pop(sheetContext),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    children: [
                      _EntryMethodTile(
                        title: '텍스트',
                        subtitle: '자유 입력 + 음성초안',
                        icon: Icons.edit_note_rounded,
                        onTap: () => Navigator.pop(sheetContext, 'text'),
                      ),
                      _EntryMethodTile(
                        title: '카테고리',
                        subtitle: '부위/운동 선택형 작성',
                        icon: Icons.grid_view_rounded,
                        onTap: () => Navigator.pop(sheetContext, 'category'),
                      ),
                      _EntryMethodTile(
                        title: 'PDF',
                        subtitle: '문서형 작성 / 생성',
                        icon: Icons.picture_as_pdf_rounded,
                        onTap: () => Navigator.pop(sheetContext, 'pdf'),
                      ),
                      _EntryMethodTile(
                        title: '아나토미',
                        subtitle: '부위 선택 기반 기록',
                        icon: Icons.accessibility_new_rounded,
                        locked: _tierAccess?.canUseAnatomy != true,
                        lockText: 'PRO 기능',
                        onTap: () async {
                          if (_tierAccess?.canUseAnatomy == true) {
                            Navigator.pop(sheetContext, 'anatomy');
                          } else {
                            Navigator.pop(sheetContext);
                            await Future.delayed(
                              const Duration(milliseconds: 180),
                            );
                            if (!mounted) return;
                            await _openAnatomyProAifcSheet();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      log.draftEntryMode = selected;
    });

    await _runPreCheckForNewLog(log);
    if (!mounted) return;

    if (selected == 'text' || selected == 'category') {
      await _openEditorForDraft(log, forcedMode: selected);
      return;
    }

    if (selected == 'pdf') {
      await _openPdfDraftPage(log);
      return;
    }

    if (selected == 'anatomy') {
      await _openAnatomyLogPage(log);
      return;
    }
  }

  Future<void> _openPdfDraftPage(_TrainingLogItem log) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PersonalTrainingLogPdfPage(
              memberName: log.name,
              sessionType: log.type,
            ),
      ),
    );
  }

  // 에디터(텍스트·카테고리) 결과 또는 서버 details를 평면 map으로 받아 항목에 채운다.
  // 키가 없으면 기본값을 쓴다. setState는 호출하는 쪽에서 감싼다.
  void _assignEditorMap(_TrainingLogItem log, Map<String, dynamic> map) {
    final String title = (map['title'] ?? '').toString().trim();
    final String memo = (map['memo'] ?? '').toString().trim();
    final String type = (map['type'] ?? '개인PT').toString();

    List<String> strings(Object? value) =>
        ((value as List?) ?? []).map((e) => e.toString()).toList();

    log.title = title.isEmpty ? '레슨일지' : title;
    log.name =
        (map['name'] ?? '').toString().trim().isEmpty
            ? ((widget.memberName ?? '').trim().isEmpty
                ? '회원 미지정'
                : (widget.memberName ?? '').trim())
            : (map['name'] ?? '').toString().trim();
    log.memo = memo;
    log.type = type;
    log.inputMethod = (map['inputMethod'] ?? 'text').toString();
    log.rawVoiceText = (map['rawVoiceText'] ?? '').toString();
    log.issueChips = strings(map['issueChips']);
    log.homeworkStatus = (map['homeworkStatus'] ?? '없음').toString();
    log.nextLessonCheckpoint =
        (map['nextLessonCheckpoint'] ?? '').toString().trim();

    log.preCondition = (map['preCondition'] ?? '보통').toString();
    log.preMeal = (map['preMeal'] ?? '1~3시간 전').toString();
    log.preNote = (map['preNote'] ?? '').toString().trim();
    log.preSleep = (map['preSleep'] ?? '보통').toString();
    log.prePain = (map['prePain'] ?? '없음').toString();
    log.prePainDetail = (map['prePainDetail'] ?? '').toString().trim();
    log.preStretching = (map['preStretching'] ?? '안 함').toString();

    log.duringGoals = strings(map['duringGoals']);
    log.duringFocusParts = strings(map['duringFocusParts']);
    log.duringReactions = strings(map['duringReactions']);
    log.duringPainDetail = (map['duringPainDetail'] ?? '').toString().trim();
    log.cognitiveResponse = (map['cognitiveResponse'] ?? '보통').toString();
    log.performanceResponse = (map['performanceResponse'] ?? '보통').toString();

    log.postPainChange = (map['postPainChange'] ?? '없음').toString();
    log.postPainDetail = (map['postPainDetail'] ?? '').toString().trim();
    log.postPerformance = (map['postPerformance'] ?? '보통').toString();
    log.postNextAction = (map['postNextAction'] ?? '유지').toString();
    log.postHomework = (map['postHomework'] ?? '없음').toString();

    log.internalMemo = (map['internalMemo'] ?? '').toString().trim();
    log.publicSummary = (map['publicSummary'] ?? '').toString().trim();
    log.publicGood = (map['publicGood'] ?? '').toString().trim();
    log.publicHomeworkNote =
        (map['publicHomeworkNote'] ?? '').toString().trim();
    log.publicCaution = (map['publicCaution'] ?? '').toString().trim();
    log.exercises = sanitizeLogExercises(map['exercises']);
  }

  void _applyDraftEditorResult(_TrainingLogItem log, Map<String, dynamic> map) {
    setState(() {
      _assignEditorMap(log, map);
      // 서버에 저장된 일지는 처음 저장한 시각을 유지한다.
      if (log.trainingLogDocId.trim().isEmpty) log.time = _nowHm();
      log.preCheckDone = map['preCheckConfirmed'] != false;
      log.inbodySummary = (map['inbodySummary'] ?? '').toString();
      log.isDraft = false;
      _lastSelectedSessionType = log.type;
      _highlightDraftId = null;
    });
  }

  // 항목을 서버 details 형식으로 바꾼다. 확정 전(초안) 저장에만 쓴다.
  Map<String, dynamic> _detailsFromLog(_TrainingLogItem log) {
    return personalTrainingLogDetailsFromEditorMap({
      'title': log.isDraft || log.title == '레슨일지 작성 전' ? '' : log.title,
      'inputMethod': log.isDraft ? '' : log.inputMethod,
      'rawVoiceText': log.rawVoiceText,
      'issueChips': log.issueChips,
      'homeworkStatus': log.homeworkStatus,
      'nextLessonCheckpoint': log.nextLessonCheckpoint,
      'preCondition': log.preCondition,
      'preMeal': log.preMeal,
      'preSleep': log.preSleep,
      'prePain': log.prePain,
      'prePainDetail': log.prePainDetail,
      'preStretching': log.preStretching,
      'preNote': log.preNote,
      'duringGoals': log.duringGoals,
      'duringFocusParts': log.duringFocusParts,
      'duringReactions': log.duringReactions,
      'duringPainDetail': log.duringPainDetail,
      'cognitiveResponse': log.cognitiveResponse,
      'performanceResponse': log.performanceResponse,
      'postPainChange': log.postPainChange,
      'postPainDetail': log.postPainDetail,
      'postPerformance': log.postPerformance,
      'postNextAction': log.postNextAction,
      'postHomework': log.postHomework,
      'internalMemo': log.internalMemo,
      'publicSummary': log.publicSummary,
      'publicGood': log.publicGood,
      'publicHomeworkNote': log.publicHomeworkNote,
      'publicCaution': log.publicCaution,
      'exercises': log.exercises,
    });
  }

  // 개인 워크스페이스의 초안 일지를 서버(training_logs)에 만들거나 갱신한다.
  // 서버에 쓰지 못해도 화면 입력은 유지하고, 다음 저장에서 다시 시도한다.
  Future<bool> _persistPersonalLogDraft(_TrainingLogItem log) async {
    if (!_isPersonalWorkspace || log.locked) return true;
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return true;

    String clip(String value, int max) =>
        value.length <= max ? value : value.substring(0, max);

    final start = _actualLessonDateTime(log);
    final lessonType = clip(
      log.type.trim().isEmpty ? '개인PT' : log.type.trim(),
      40,
    );
    final scheduleId = log.scheduleDocId.trim();
    final draft = PersonalTrainingLogDraft(
      memberId: memberId,
      scheduleDocId: scheduleId.isEmpty ? null : scheduleId,
      lessonDate: DateTime(start.year, start.month, start.day),
      startAt: start,
      endAt: start.add(const Duration(minutes: 50)),
      lessonType: lessonType,
      memo: clip(log.memo.trim(), 4000),
      details: _detailsFromLog(log),
    );

    try {
      final repository = PersonalTrainingLogRepository.firebase(
        uid: _personalOwnerUid,
      );
      final docId = log.trainingLogDocId.trim();
      if (docId.isEmpty) {
        final createdId = await repository.createDraft(draft);
        if (mounted) setState(() => log.trainingLogDocId = createdId);
      } else {
        await repository.autosave(docId, draft);
      }
      return true;
    } catch (error) {
      _logFirestoreReadFailure(source: 'formal_log_save', error: error);
      _showSnack('레슨일지를 서버에 저장하지 못했어요. 입력한 내용은 유지했어요.');
      return false;
    }
  }

  Future<void> _syncSmartAlarmContextFromLog(_TrainingLogItem log) async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    final trainingLogId = _firestoreLogDocIdFromLog(log);
    final lessonAt = _actualLessonDateTime(log);

    final conditionText = [
      if (log.preCondition.trim().isNotEmpty) '컨디션 ${log.preCondition}',
      if (log.preSleep.trim().isNotEmpty) '수면 ${log.preSleep}',
      if (log.prePain.trim().isNotEmpty) '통증 ${log.prePain}',
      if (log.prePainDetail.trim().isNotEmpty) log.prePainDetail.trim(),
      if (log.duringPainDetail.trim().isNotEmpty) log.duringPainDetail.trim(),
      if (log.postPainDetail.trim().isNotEmpty) log.postPainDetail.trim(),
    ].join(' · ');

    final summaryText = [
      if (log.title.trim().isNotEmpty) log.title.trim(),
      if (log.issueChips.isNotEmpty) log.issueChips.join(' · '),
      if (log.duringFocusParts.isNotEmpty) log.duringFocusParts.join(' · '),
      if (log.duringGoals.isNotEmpty) log.duringGoals.join(' · '),
      if (log.publicSummary.trim().isNotEmpty) log.publicSummary.trim(),
      if (log.publicCaution.trim().isNotEmpty) log.publicCaution.trim(),
    ].join(' · ');

    final nextHint = [
      if (log.nextLessonCheckpoint.trim().isNotEmpty)
        log.nextLessonCheckpoint.trim(),
      if (log.postNextAction.trim().isNotEmpty)
        '다음 진행: ${log.postNextAction.trim()}',
      if (log.publicHomeworkNote.trim().isNotEmpty)
        log.publicHomeworkNote.trim(),
    ].join(' · ');

    await MemberSmartAlarmContextService.updateFromLessonLog(
      memberId: memberId,
      trainingLogId: trainingLogId,
      lessonAt: lessonAt,
      summary: summaryText,
      memo: log.memo,
      conditionText: conditionText,
      painText: [
        log.prePainDetail,
        log.duringPainDetail,
        log.postPainDetail,
      ].where((e) => e.trim().isNotEmpty).join(' · '),
      nextLessonHint: nextHint,
    );
  }

  Future<void> _requestMoreCareSlotAfterLogSaved() async {
    final memberId = (widget.memberId ?? '').trim();

    if (memberId.isEmpty) return;

    final decision = await MoreCareSlotService.requestTemporarySlotForMember(
      memberId: memberId,
      reason: 'lesson_log_saved',
    );

    if (!mounted) return;

    if (decision.canUseAdvancedMoreCare &&
        decision.status == MoreCareSlotStatus.temporary) {
      _showSnack('MORE 관리도 잠시 열어두었어요. 관리자에게 승인 요청을 보내둘게요.');
    }
  }

  Future<void> _openTextVoiceDraftPage(_TrainingLogItem log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PersonalTrainingLogTextVoicePage(
              autoOpenPreCheck: false,
              onMeasureInbody: _inbodyMeasureCallback(),
              initialInbodySummary: log.inbodySummary,
              initialPreCheckConfirmed: log.preCheckDone,
              initialPrePainDetail: log.prePainDetail,
              initialDuringPainDetail: log.duringPainDetail,
              initialPostPainDetail: log.postPainDetail,
              initialPreNote: log.preNote,
              personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
              initialName: log.name,
              initialSessionLabel: _sessionDisplayText(log),
              initialTitle: log.title == '레슨일지 작성 전' ? '' : log.title,
              initialMemo: log.memo,
              initialType: log.type,
              initialIssueChips: log.issueChips,
              initialHomeworkStatus: log.homeworkStatus,
              initialNextLessonCheckpoint: log.nextLessonCheckpoint,
              initialPreCondition: log.preCondition,
              initialPreMeal: log.preMeal,
              initialPreSleep: log.preSleep,
              initialPrePain: log.prePain,
              initialPreStretching: log.preStretching,
              initialDuringGoals: log.duringGoals,
              initialDuringFocusParts: log.duringFocusParts,
              initialDuringReactions: log.duringReactions,
              initialPostPainChange: log.postPainChange,
              initialPostPerformance: log.postPerformance,
              initialPostNextAction: log.postNextAction,
              initialPostHomework: log.postHomework,
              initialInternalMemo: log.internalMemo,
              initialPublicSummary: log.publicSummary,
              initialPublicGood: log.publicGood,
              initialPublicHomeworkNote: log.publicHomeworkNote,
              initialPublicCaution: log.publicCaution,
            ),
      ),
    );

    if (result == null || !mounted) return;

    if (result is! Map<String, dynamic>) return;
    _applyDraftEditorResult(log, result);
    final saved = await _persistPersonalLogDraft(log);
    await _syncSmartAlarmContextFromLog(log);
    await _requestMoreCareSlotAfterLogSaved();

    if (!mounted) return;
    if (saved) _showSnack('텍스트 레슨일지가 저장되었어요.');
  }

  Future<void> _openCategoryDraftPage(_TrainingLogItem log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PersonalTrainingLogCategoryPage(
              initialName: log.name,
              initialSessionLabel: _sessionDisplayText(log),
              initialTitle: log.title == '레슨일지 작성 전' ? '' : log.title,
              initialMemo: log.memo,
              initialType: log.type,
              initialIssueChips: log.issueChips,
              initialHomeworkStatus: log.homeworkStatus,
              initialNextLessonCheckpoint: log.nextLessonCheckpoint,
              initialPreCondition: log.preCondition,
              initialPreMeal: log.preMeal,
              initialPreSleep: log.preSleep,
              initialPrePain: log.prePain,
              initialPreStretching: log.preStretching,
              initialDuringGoals: log.duringGoals,
              initialDuringFocusParts: log.duringFocusParts,
              initialDuringReactions: log.duringReactions,
              initialPostPainChange: log.postPainChange,
              initialPostPerformance: log.postPerformance,
              initialPostNextAction: log.postNextAction,
              initialPostHomework: log.postHomework,
              initialInternalMemo: log.internalMemo,
              initialPublicSummary: log.publicSummary,
              initialPublicGood: log.publicGood,
              initialPublicHomeworkNote: log.publicHomeworkNote,
              initialPublicCaution: log.publicCaution,
              initialExercises: log.exercises,
              initialPrePainDetail: log.prePainDetail,
              initialDuringPainDetail: log.duringPainDetail,
              initialPostPainDetail: log.postPainDetail,
              initialPreNote: log.preNote,
              autoOpenPreCheck: false,
              onMeasureInbody: _inbodyMeasureCallback(),
              initialInbodySummary: log.inbodySummary,
              initialPreCheckConfirmed: log.preCheckDone,
              initialCognitiveResponse: log.cognitiveResponse,
              initialPerformanceResponse: log.performanceResponse,
              personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
            ),
      ),
    );

    if (result is! Map<String, dynamic>) return;
    _applyDraftEditorResult(log, result);
    final saved = await _persistPersonalLogDraft(log);
    await _syncSmartAlarmContextFromLog(log);
    await _requestMoreCareSlotAfterLogSaved();

    if (!mounted) return;
    if (saved) _showSnack('카테고리 레슨일지가 저장되었어요.');
  }

  Future<void> _openEditorForDraft(
    _TrainingLogItem log, {
    String? forcedMode,
  }) async {
    final mode = forcedMode ?? log.draftEntryMode;

    if (mode == 'category') {
      await _openCategoryDraftPage(log);
      return;
    }

    await _openTextVoiceDraftPage(log);
  }

  void _openLogDetailSheet(_TrainingLogItem log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (log.confirmCancelled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '확정취소된 레슨일지입니다. 이 화면은 확인용이며, 서명이나 확정 상태를 다시 변경할 수 없어요.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (log.confirmCancelled) const SizedBox(height: 10),
                if (log.sessionStatus != 'normal')
                  SizedBox(
                    width: 96,
                    height: 24,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            log.sessionStatus == 'service'
                                ? const Color(0xFFF0FDFA)
                                : log.sessionStatus == 'no_show'
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              log.sessionStatus == 'service'
                                  ? const Color(0xFF99F6E4)
                                  : log.sessionStatus == 'no_show'
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Text(
                        log.sessionStatus == 'service'
                            ? '서비스'
                            : log.sessionStatus == 'no_show'
                            ? 'NO SHOW'
                            : '미차감 노쇼',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color:
                              log.sessionStatus == 'service'
                                  ? const Color(0xFF0F766E)
                                  : log.sessionStatus == 'no_show'
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (log.locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      log.lockedAtDate.isNotEmpty
                          ? '이 기록은 확정되었어요 · ${log.lockedAtDate} ${log.lockedAtTime}'
                          : '이 기록은 확정되었어요',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_tierAccess?.canUseAnatomy == true &&
                    log.scheduleDocId.trim().isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openAnatomyLogPage(log);
                      },
                      icon: const Icon(Icons.accessibility_new_rounded),
                      label: const Text('해부학 기록 열기'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  log.memo.isEmpty ? '(메모 없음)' : log.memo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (log.rawVoiceText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kLogBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '음성 원문',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log.rawVoiceText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _sigDetailBlock(
                        title: '강사 서명',
                        cell: log.trainerSig,
                        signedAt: _signedAtLabel(
                          log.trainerSignedDate,
                          log.trainerSignedTime,
                        ),
                        locked: log.locked || log.confirmCancelled,
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _tapSig(log, 'trainer');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _sigDetailBlock(
                        title: '회원 서명',
                        cell: log.customerSig,
                        signedAt: _signedAtLabel(
                          log.customerSignedDate,
                          log.customerSignedTime,
                        ),
                        locked: log.locked || log.confirmCancelled,
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _tapSig(log, 'customer');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (log.locked)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _tryUnlockLog(log);
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text(
                        '확정 취소(PIN)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _signedAtLabel(String d, String t) {
    if (d.isEmpty) return '';
    return '$d $t';
  }

  Widget _sigDetailBlock({
    required String title,
    required SigCell cell,
    required String signedAt,
    required bool locked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: locked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLogBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _sigViewMini(cell, big: true),
            const SizedBox(height: 6),
            if (signedAt.isNotEmpty)
              Text(
                '서명시각 · $signedAt',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (signedAt.isEmpty)
              Text(
                locked ? '확정' : '탭하여 서명',
                style: TextStyle(
                  fontSize: 10,
                  color: locked ? Colors.black38 : const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _weekdayKo(DateTime date) {
    const labels = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

    return labels[date.weekday - 1];
  }

  String _logLessonSummaryText(_TrainingLogItem log) {
    final dateText = _fmtDotYmd(log.date);
    final weekday = _weekdayKo(log.date);
    final time = log.time.trim().isEmpty ? '--:--' : log.time.trim();
    final type = log.type.trim().isEmpty ? '레슨' : log.type.trim();

    return '$dateText $weekday $time $type 레슨';
  }

  void _openLogMoreMenu(_TrainingLogItem log) {
    AifcLogManageChatSheet.show(
      context: context,
      memberName: log.name,
      currentStatus: log.sessionStatus,
      isLocked: log.locked,
      lessonSummaryText: _logLessonSummaryText(log),
      onChangeStatus: (newStatus) async {
        _updateSessionStatus(log, newStatus);
      },
      onConfirmCancel: (pin) async {
        return _confirmCancelLogWithPin(log, pin);
      },
      onViewDetail: () {
        _openLogDetailSheet(log);
      },
    );
  }

  void _updateSessionStatus(_TrainingLogItem log, String status) {
    setState(() {
      log.sessionStatus = status;
    });

    switch (status) {
      case 'service':
        _showSnack('서비스 처리로 변경했어요.');
        break;
      case 'no_show':
        _showSnack('노쇼 처리로 변경했어요.');
        break;
      case 'no_show_no_deduct':
        _showSnack('노쇼 미차감 처리로 변경했어요.');
        break;
      case 'normal':
      default:
        _showSnack('일반 레슨으로 변경했어요.');
        break;
    }
  }

  String _fmtYmd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _fmtDotYmd(DateTime d) =>
      "${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";

  bool _shouldDeductSessionOnLock(_TrainingLogItem log) {
    switch (log.sessionStatus) {
      case 'normal':
      case 'no_show':
        return true;

      case 'service':
      case 'no_show_no_deduct':
      default:
        return false;
    }
  }

  String _deductionKeyForLog(_TrainingLogItem log) {
    final id = log.id.trim();

    if (id.isEmpty) {
      throw StateError('stable_log_id_required');
    }

    return 'training_log_$id';
  }

  DateTime _actualLessonDateTime(_TrainingLogItem log) {
    final parts = log.time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(log.date.year, log.date.month, log.date.day, hour, minute);
  }

  Future<void> _applyRemainingSessionDeductionIfNeeded(
    _TrainingLogItem log,
  ) async {
    if (log.deductionApplied) return;
    if (!_shouldDeductSessionOnLock(log)) return;

    final memberId = (widget.memberId ?? '').trim();

    if (memberId.isEmpty) {
      _showSnack('회원 연결이 없어 잔여 레슨을 소진하지 않았어요.');
      return;
    }

    late final String deductionKey;

    try {
      deductionKey = _deductionKeyForLog(log);
    } catch (_) {
      _showSnack('레슨일지 식별값이 없어 잔여 레슨을 소진하지 않았어요.');
      return;
    }

    try {
      final memberRef = FirebaseFirestore.instance
          .collection('members')
          .doc(memberId);

      final logDocId =
          log.id.startsWith('quick_')
              ? log.id.replaceFirst('quick_', '')
              : log.id;

      final logRef = FirebaseFirestore.instance
          .collection('training_logs')
          .doc(logDocId);

      int? nextRemainForMessage;
      bool alreadyDeducted = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(memberRef);
        final data = snap.data() ?? <String, dynamic>{};

        final deductedLogIdsRaw = data['deductedTrainingLogIds'];

        final deductedLogIds =
            deductedLogIdsRaw is List
                ? deductedLogIdsRaw.map((e) => e.toString()).toSet()
                : <String>{};

        if (deductedLogIds.contains(deductionKey)) {
          alreadyDeducted = true;
          return;
        }

        final sessions =
            data['sessions'] is Map
                ? Map<String, dynamic>.from(data['sessions'] as Map)
                : <String, dynamic>{};

        final lessonType = (data['lessonType'] ?? '미입력').toString().trim();

        final lessonNotRegistered =
            sessions['notRegistered'] == true || lessonType == '미입력';

        if (lessonNotRegistered) {
          transaction.set(logRef, {
            'waitingTrainerConfirm': false,
            'confirmedByTrainer': true,
            'confirmedAt': FieldValue.serverTimestamp(),
            'locked': true,
            'deductionApplied': false,
            'deductionSkipReason': 'lesson_not_registered',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          nextRemainForMessage = null;
          return;
        }

        final rawRemain =
            data['remainSessions'] ??
            data['remainingSessions'] ??
            sessions['remain'] ??
            data['remainingPt'] ??
            data['ptRemaining'];

        final currentRemain =
            rawRemain is num
                ? rawRemain.toInt()
                : int.tryParse((rawRemain ?? '').toString()) ?? 0;

        final rawDone = data['doneSessions'] ?? sessions['done'];

        final currentDone =
            rawDone is num
                ? rawDone.toInt()
                : int.tryParse((rawDone ?? '').toString()) ?? 0;

        final nextRemain = currentRemain > 0 ? currentRemain - 1 : 0;
        final nextDone = currentRemain > 0 ? currentDone + 1 : currentDone;

        nextRemainForMessage = nextRemain;

        transaction.set(memberRef, {
          'remainSessions': nextRemain,
          'remainingSessions': nextRemain,
          'doneSessions': nextDone,
          'sessions.remain': nextRemain,
          'sessions.done': nextDone,
          'sessions.source': 'log',
          'deductedTrainingLogIds': FieldValue.arrayUnion([deductionKey]),
          'lessonSource': 'log',
          'lessonSync.source': 'log',
          'lessonSync.lastLogId': deductionKey,
          'lessonSync.updatedAt': FieldValue.serverTimestamp(),
          'lastLogAt': Timestamp.fromDate(_actualLessonDateTime(log)),
          'lastLessonAt': Timestamp.fromDate(_actualLessonDateTime(log)),
          'lastLessonType': log.type,
          'lastLessonStatus': log.sessionStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(logRef, {
          'waitingTrainerConfirm': false,
          'confirmedByTrainer': true,
          'confirmedAt': FieldValue.serverTimestamp(),
          'locked': true,
          'deductionApplied': true,
          'deductionKey': deductionKey,
          'remainAfterDeduct': nextRemain,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (alreadyDeducted) {
        if (!mounted) return;
        _showSnack('이미 레슨일지에 반영된 레슨이에요.');
        return;
      }

      log.deductionApplied = nextRemainForMessage != null;

      if (!mounted) return;

      if (nextRemainForMessage == null) {
        _showSnack('레슨일지가 확정되었어요. 레슨 미등록 회원이라 잔여 횟수는 소진하지 않았어요.');
      } else if ((nextRemainForMessage ?? 0) <= 0) {
        _showSnack('레슨일지가 확정되었어요. 잔여 레슨은 0회입니다.');
      } else {
        _showSnack('레슨일지가 확정되어 레슨 1회가 소진되었어요.');
      }
    } catch (e) {
      debugPrint('잔여 레슨 소진 실패: $e');

      if (!mounted) return;
      _showSnack('잔여 레슨 소진에 실패했어요. 회원카드에서 확인해 주세요.');
    }
  }

  Future<void> _updateMemberLastLessonOnly(_TrainingLogItem log) async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final lessonDateTime = _actualLessonDateTime(log);

      await FirebaseFirestore.instance.collection('members').doc(memberId).set({
        'lastLogAt': Timestamp.fromDate(lessonDateTime),
        'lastLessonAt': Timestamp.fromDate(lessonDateTime),
        'lastLessonType': log.type,
        'lastLessonStatus': log.sessionStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('마지막 레슨일 갱신 실패: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sigViewMini(SigCell cell, {bool big = false}) {
    final h = big ? 56.0 : 28.0;
    final textSize = big ? 14.0 : 11.0;

    if (cell.type == 'drawn' && cell.value.isNotEmpty) {
      return SizedBox(
        height: 24,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Image.memory(_dataUrlToBytes(cell.value)),
        ),
      );
    }

    if (cell.type == 'typed' && cell.value.isNotEmpty) {
      return Container(
        height: h,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✍ ', style: TextStyle(fontSize: textSize + 2)),
            Flexible(
              child: Text(
                cell.value,
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      height: h,
      alignment: Alignment.centerLeft,
      child: Text(
        '서명 없음',
        style: TextStyle(
          fontSize: textSize,
          color: Colors.black38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 브리핑의 `지난 레슨`: 가장 최근에 쓴 레슨일지의 운동(아나토미는 운동 이름을 `/` 로 이은 글).
  _TrainingLogItem? _briefingLastLog() {
    for (final log in _logsNewestFirst()) {
      if (!log.isDraft) return log;
    }
    return null;
  }

  String _briefingLastLesson() {
    final last = _briefingLastLog();
    if (last == null) return '아직 지난 레슨 기록이 없어요';
    if (last.inputMethod == 'anatomy') {
      final summary = _anatomySummaries[_firestoreLogDocIdFromLog(last)];
      if (summary == null) return '아나토미 레슨';
      return summary.exerciseNames.isEmpty ? '운동 기록 없음' : summary.exerciseLine;
    }
    final text = _exerciseSummaryFromLog(last);
    return text.isEmpty ? '운동 기록 없음' : text;
  }

  /// 지난 레슨에 적어 둔 통증·주의(아나토미 기록 또는 레슨 전·중·후 통증 메모). 없으면 빈 글자.
  String _briefingWarning() {
    final last = _briefingLastLog();
    if (last == null) return '';
    if (last.inputMethod == 'anatomy') {
      return _anatomySummaries[_firestoreLogDocIdFromLog(last)]?.reminderText ??
          '';
    }
    final details =
        [last.prePainDetail, last.duringPainDetail, last.postPainDetail]
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    if (details.isNotEmpty) return '통증 ${details.join(', ')}';
    return last.prePain == '있음' ? '레슨 전 통증이 있었어요' : '';
  }

  /// 아나토미 기록으로 본 최근 4주 동안 운동하지 않은 큰 부위. 기록이 없으면 빈 글자.
  String _briefingRested() {
    if (_anatomyRecords.isEmpty) return '';
    final history = AnatomyMemberHistory(_anatomyRecords);
    final rested = history.restedParts();
    if (rested.isEmpty) return '최근 4주 동안 고르게 운동했어요';
    return '최근 4주 동안 ${rested.join(' · ')} 운동이 없었어요';
  }

  String _exerciseSummaryFromLog(_TrainingLogItem log) {
    final memo = log.memo.trim();
    if (memo.isEmpty) return '';

    if (log.inputMethod == 'category') {
      final exercises = _extractCategoryExercisesFromMemo(memo);
      if (exercises.isNotEmpty) {
        if (exercises.length == 1) return exercises.first;
        return '${exercises.first} 외 ${exercises.length - 1}개';
      }
    }

    final lines =
        memo
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    if (lines.isEmpty) return '';

    var first = lines.first;
    if (first.length > 24) {
      first = '${first.substring(0, 24)}...';
    }
    return first;
  }

  List<String> _extractCategoryPartsFromMemo(String memo) {
    final lines = memo.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('부위:')) {
        final value = trimmed.replaceFirst('부위:', '').trim();
        if (value.isNotEmpty && !result.contains(value)) {
          result.add(value);
        }
      }
    }

    return result;
  }

  List<String> _extractCategoryExercisesFromMemo(String memo) {
    final lines = memo.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) {
        var text = trimmed.substring(2).trim();

        if (text.contains('·')) {
          text = text.split('·').first.trim();
        }

        text = text.replaceFirst(RegExp(r'\s+\d+세트$'), '').trim();

        if (text.isNotEmpty && !result.contains(text)) {
          result.add(text);
        }
      }
    }

    return result;
  }

  bool _isMonthChanged(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    return current.year != previous.year || current.month != previous.month;
  }

  String _monthSectionLabel(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildTimelineSectionHeader(String text) {
    const lineColor = Color(0xFFD1D5DB);
    // 라이트는 기존 회색 글자, 다크는 어두운 배경에서 보이도록 선과 같은 색.
    final textColor =
        Theme.of(context).brightness == Brightness.dark
            ? lineColor
            : Colors.black54;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: lineColor)),
        ],
      ),
    );
  }

  Uint8List _dataUrlToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final base64Part = (comma >= 0) ? dataUrl.substring(comma + 1) : dataUrl;
    return Uint8List.fromList(base64Decode(base64Part));
  }
}

class _EntryMethodTile extends StatelessWidget {
  const _EntryMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.locked = false,
    this.lockText = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;
  final String lockText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: locked ? scheme.surfaceContainerHighest : tokens.cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: locked ? scheme.outlineVariant : tokens.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          locked
                              ? scheme.surfaceContainerHighest
                              : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color:
                          locked
                              ? scheme.onSurfaceVariant
                              : scheme.onSecondaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                          locked ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: CustomPaint(
                      painter: _DiagonalLockRibbonPainter(),
                      child: Container(),
                    ),
                  ),
                ),
              ),
            if (locked)
              Positioned(
                top: 18,
                left: -30,
                child: Transform.rotate(
                  angle: -0.7,
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    color: Colors.black.withOpacity(0.78),
                    child: Text(
                      lockText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalLockRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66F3F4F6);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExerciseLogBlueHeader extends StatelessWidget {
  const _ExerciseLogBlueHeader({
    required this.title,
    required this.totalSessions,
    required this.remainingSessions,
    required this.lastLessonText,
    required this.reRegistrationLabel,
    required this.recentIssue,
    required this.openingMent,
    required this.inbodyPoints,
    required this.briefingLastLesson,
    required this.briefingWarning,
    required this.briefingRested,
    required this.initialGoalLabel,
    required this.goalDdayLabel,
    required this.isExpanded,
    required this.onBackTap,
    required this.onToggleExpand,
    required this.onInbodyTap,
    required this.onCalendarTap,
    required this.onSettingsTap,
    this.anatomyHistory,
    this.onAnatomyHistoryTap,
  });

  final String title;
  final int totalSessions;
  final int remainingSessions;
  final String lastLessonText;

  final String recentIssue;
  final String reRegistrationLabel;
  final String openingMent;
  final List<InbodyHistoryPoint> inbodyPoints;
  final String briefingLastLesson;
  final String briefingWarning;
  final String briefingRested;
  final String initialGoalLabel;
  final String goalDdayLabel;

  final bool isExpanded;

  final VoidCallback onBackTap;
  final VoidCallback onToggleExpand;
  final VoidCallback onInbodyTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onSettingsTap;

  /// 회원의 아나토미 기록(운동 변화 카드용). 상세 정보가 접혀 있거나 회원이 없으면 null.
  final AnatomyMemberHistory? anatomyHistory;

  /// 운동 변화 카드의 `자세히 보기`.
  final VoidCallback? onAnatomyHistoryTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return MtfHeaderNeonOverlay(
      isExpanded: isExpanded,
      intensity: 0.52,
      strokeWidth: 1.6,
      child: GestureDetector(
        // 머리말을 아래로 끌어 내리면 MORE 레슨브리핑을 열고, 열려 있을 때 위로 끌어 올리면 닫는다.
        key: const ValueKey<String>('log_header_swipe'),
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (isExpanded ? velocity < -250 : velocity > 250) onToggleExpand();
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topPadding + 14,
            left: 16,
            right: 16,
            bottom: 18,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    InkWell(
                      onTap: onBackTap,
                      borderRadius: BorderRadius.circular(999),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderTopActionButton(
                      icon: Icons.document_scanner_outlined,
                      tooltip: '인바디 입력',
                      onTap: onInbodyTap,
                    ),
                    const SizedBox(width: 8),
                    _HeaderTopActionButton(
                      icon: Icons.calendar_month_rounded,
                      tooltip: '달력 보기',
                      onTap: onCalendarTap,
                    ),
                    const SizedBox(width: 8),
                    _HeaderTopActionButton(
                      icon: Icons.settings_outlined,
                      tooltip: '레슨일지 설정',
                      onTap: onSettingsTap,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  recentIssue.isEmpty ? '최근 이슈' : recentIssue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HeaderStatCard(
                      icon: Icons.flag_circle_outlined,
                      label: '등록 목표',
                      value: initialGoalLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderStatCard(
                      icon: Icons.event_available_rounded,
                      label: '마지막 레슨일',
                      value: lastLessonText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderStatCard(
                      icon: Icons.flag_outlined,
                      label: 'D - DAY',
                      value: goalDdayLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    key: const ValueKey<String>('log_header_briefing'),
                    onTap: onToggleExpand,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MORE 레슨브리핑',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withOpacity(0.92),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child:
                    isExpanded
                        ? Padding(
                          key: const ValueKey('header_info_open'),
                          padding: const EdgeInsets.only(top: 12),
                          child: _HeaderMemberInfoBox(
                            openingMent: openingMent,
                            inbodyPoints: inbodyPoints,
                            onInbodyMeasure: onInbodyTap,
                            lastLesson: briefingLastLesson,
                            warning: briefingWarning,
                            rested: briefingRested,
                            anatomyHistory: anatomyHistory,
                            onAnatomyHistoryTap: onAnatomyHistoryTap,
                          ),
                        )
                        : const SizedBox.shrink(
                          key: ValueKey('header_info_closed'),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `MORE 레슨브리핑` 패널. 카드가 늘어도 머리말이 길어지지 않게 좌우로 넘겨 보는
/// 페이지로 나눈다(시작 멘트·추천 운동 / 인바디 추이 / 운동 변화).
class _HeaderMemberInfoBox extends StatefulWidget {
  const _HeaderMemberInfoBox({
    required this.openingMent,
    required this.inbodyPoints,
    required this.onInbodyMeasure,
    required this.lastLesson,
    required this.warning,
    required this.rested,
    this.anatomyHistory,
    this.onAnatomyHistoryTap,
  });

  final String openingMent;
  final List<InbodyHistoryPoint> inbodyPoints;
  final VoidCallback onInbodyMeasure;
  final String lastLesson;
  final String warning;
  final String rested;
  final AnatomyMemberHistory? anatomyHistory;
  final VoidCallback? onAnatomyHistoryTap;

  @override
  State<_HeaderMemberInfoBox> createState() => _HeaderMemberInfoBoxState();
}

class _HeaderMemberInfoBoxState extends State<_HeaderMemberInfoBox> {
  static const double _pageHeight = 292;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbodyPoints = widget.inbodyPoints;
    final history = widget.anatomyHistory;
    final showChange =
        history != null &&
        widget.onAnatomyHistoryTap != null &&
        !history.isEmpty;
    final pages = <Widget>[
      Column(
        children: [
          _HeaderMessageCard(
            title: '다음 레슨 시작 멘트 및 체크포인트',
            value: widget.openingMent,
          ),
          Divider(
            height: 20,
            thickness: 1,
            color: Colors.white.withOpacity(0.14),
          ),
          Divider(
            height: 20,
            thickness: 1,
            color: Colors.white.withOpacity(0.14),
          ),
          _HeaderMessageCard(title: '지난 레슨', value: widget.lastLesson),
          if (widget.warning.isNotEmpty)
            _HeaderMessageCard(
              key: const ValueKey<String>('briefing_warning'),
              title: '지난 레슨 통증·주의',
              value: widget.warning,
              valueColor: const Color(0xFFFCD34D),
            ),
          if (widget.rested.isNotEmpty) ...[
            Divider(
              height: 20,
              thickness: 1,
              color: Colors.white.withOpacity(0.14),
            ),
            _HeaderMessageCard(
              key: const ValueKey<String>('briefing_rested'),
              title: '쉬어간 부위',
              value: widget.rested,
            ),
          ],
        ],
      ),
      InbodyTrendCard(points: inbodyPoints, onMeasure: widget.onInbodyMeasure),
      if (showChange)
        AnatomyChangeCard(
          history: history,
          onOpenDetail: widget.onAnatomyHistoryTap!,
        ),
    ];
    final current = _page.clamp(0, pages.length - 1);

    // 상자 없이 머리말 배경 위에 바로 놓는다(페이지 점으로만 구분).
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Column(
        children: [
          SizedBox(
            height: _pageHeight,
            child: PageView(
              key: const ValueKey<String>('header_info_pages'),
              controller: _controller,
              onPageChanged: (index) => setState(() => _page = index),
              children: [
                for (final page in pages)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: page,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages.length; i++)
                Container(
                  key: ValueKey<String>('header_info_dot_$i'),
                  width: i == current ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(i == current ? 0.9 : 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoTile extends StatelessWidget {
  const _HeaderInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMessageCard extends StatelessWidget {
  const _HeaderMessageCard({
    super.key,
    required this.title,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTopActionButton extends StatelessWidget {
  const _HeaderTopActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  const _HeaderStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceLineChart extends StatelessWidget {
  const _PerformanceLineChart({required this.logs});

  final List<_TrainingLogItem> logs;

  @override
  Widget build(BuildContext context) {
    final values = logs.map((e) => e.performanceScore).toList();

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _PerformanceLineChartPainter(values: values),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children:
              logs.map((log) {
                final label =
                    '${log.date.month.toString().padLeft(2, '0')}/${log.date.day.toString().padLeft(2, '0')}';
                return Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _PerformanceLineChartPainter extends CustomPainter {
  _PerformanceLineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final gridPaint =
        Paint()
          ..color = const Color(0xFFE5E7EB)
          ..strokeWidth = 1;

    final linePaint =
        Paint()
          ..color = const Color(0xFF4F46E5)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final pointPaint =
        Paint()
          ..color = const Color(0xFF4F46E5)
          ..style = PaintingStyle.fill;

    const leftPad = 8.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 12.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    for (int i = 0; i < 4; i++) {
      final y = topPad + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    final minValue = math.min(values.reduce(math.min), 1);
    final maxValue = math.max(values.reduce(math.max), 10);
    final valueRange =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx =
          values.length == 1
              ? size.width / 2
              : leftPad + (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / valueRange;
      final dy = topPad + chartHeight - (normalized * chartHeight);
      points.add(Offset(dx, dy));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
      canvas.drawCircle(point, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceLineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.values,
    required this.lineColor,
    required this.pointColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color pointColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniSparklinePainter(
        values: values,
        lineColor: lineColor,
        pointColor: pointColor,
      ),
      child: Container(),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({
    required this.values,
    required this.lineColor,
    required this.pointColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final pointPaint =
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;

    const leftPad = 2.0;
    const rightPad = 2.0;
    const topPad = 4.0;
    const bottomPad = 4.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx =
          values.length == 1
              ? size.width / 2
              : leftPad + (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final dy = topPad + chartHeight - (normalized * chartHeight);
      points.add(Offset(dx, dy));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 2.8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor;
  }
}

class _LessonCalendarResult {
  final DateTime? selectedDate;
  final bool clearFilter;

  const _LessonCalendarResult._({this.selectedDate, this.clearFilter = false});

  factory _LessonCalendarResult.select(DateTime date) {
    return _LessonCalendarResult._(
      selectedDate: DateTime(date.year, date.month, date.day),
    );
  }

  factory _LessonCalendarResult.clear() {
    return const _LessonCalendarResult._(clearFilter: true);
  }
}

class _LessonCalendarSheet extends StatefulWidget {
  const _LessonCalendarSheet({
    required this.lessonDates,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
  });

  final Set<DateTime> lessonDates;
  final DateTime? selectedDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_LessonCalendarSheet> createState() => _LessonCalendarSheetState();
}

class _LessonCalendarSheetState extends State<_LessonCalendarSheet> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final base =
        widget.selectedDate ??
        widget.lastDate ??
        widget.firstDate ??
        DateTime.now();
    _visibleMonth = DateTime(base.year, base.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final daysInMonth = nextMonth.subtract(const Duration(days: 1)).day;
    final startOffset = firstDay.weekday % 7;

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final normalized = DateTime(date.year, date.month, date.day);
      final isLessonDay = widget.lessonDates.contains(normalized);
      final isSelected =
          widget.selectedDate != null &&
          _isSameDate(widget.selectedDate!, normalized);
      final isToday = _isSameDate(DateTime.now(), normalized);

      cells.add(
        InkWell(
          onTap:
              isLessonDay
                  ? () => Navigator.pop(
                    context,
                    _LessonCalendarResult.select(normalized),
                  )
                  : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFFEEF2FF)
                      : isLessonDay
                      ? Colors.white
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(color: const Color(0xFF4F46E5))
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLessonDay ? Colors.black87 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        isLessonDay
                            ? Colors.red
                            : (isToday ? Colors.black26 : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '레슨 달력',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                        1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${_visibleMonth.year}.${_visibleMonth.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                        1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                _WeekdayCell('일'),
                _WeekdayCell('월'),
                _WeekdayCell('화'),
                _WeekdayCell('수'),
                _WeekdayCell('목'),
                _WeekdayCell('금'),
                _WeekdayCell('토'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
              children: cells,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      Navigator.pop(
                        context,
                        _LessonCalendarResult.select(
                          DateTime(now.year, now.month, now.day),
                        ),
                      );
                    },
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('오늘로 돌아오기'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.firstDate == null
                            ? null
                            : () => Navigator.pop(
                              context,
                              _LessonCalendarResult.select(
                                DateTime(
                                  widget.firstDate!.year,
                                  widget.firstDate!.month,
                                  widget.firstDate!.day,
                                ),
                              ),
                            ),
                    icon: const Icon(Icons.first_page_rounded),
                    label: const Text('처음 레슨일'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.lastDate == null
                            ? null
                            : () => Navigator.pop(
                              context,
                              _LessonCalendarResult.select(
                                DateTime(
                                  widget.lastDate!.year,
                                  widget.lastDate!.month,
                                  widget.lastDate!.day,
                                ),
                              ),
                            ),
                    icon: const Icon(Icons.last_page_rounded),
                    label: const Text('마지막 레슨일'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        () => Navigator.pop(
                          context,
                          _LessonCalendarResult.clear(),
                        ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('전체 히스토리'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _GoalDdayItem {
  String id;
  String name;
  DateTime date;
  bool isCompleted;
  DateTime? completedAt;
  bool followUpCreated;
  String status;

  _GoalDdayItem({
    required this.id,
    required this.name,
    required this.date,
    this.isCompleted = false,
    this.completedAt,
    this.followUpCreated = false,
    this.status = 'active',
  });

  factory _GoalDdayItem.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawStatus = (data['status'] ?? '').toString().trim();

    final resolvedStatus =
        rawStatus.isNotEmpty
            ? rawStatus
            : data['isCompleted'] == true
            ? 'completed'
            : 'active';

    return _GoalDdayItem(
      id: id,
      name: (data['name'] ?? data['title'] ?? '').toString(),
      date: toDate(data['targetDate'] ?? data['date']) ?? DateTime.now(),
      isCompleted: data['isCompleted'] == true || resolvedStatus == 'completed',
      completedAt: toDate(data['completedAt']),
      followUpCreated: data['followUpCreated'] == true,
      status: resolvedStatus,
    );
  }

  Map<String, dynamic> toFirestorePayload() {
    return {
      'name': name,
      'targetDate': Timestamp.fromDate(date),
      'isCompleted': isCompleted,
      'completedAt':
          completedAt == null ? null : Timestamp.fromDate(completedAt!),
      'followUpCreated': followUpCreated,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class _GoalDdayManageSheet extends StatelessWidget {
  const _GoalDdayManageSheet({
    required this.goals,
    required this.onAdd,
    required this.onEdit,
    required this.onComplete,
    required this.onPause,
    required this.onStop,
    required this.onResume,
    required this.onDelete,
  });

  final List<_GoalDdayItem> goals;
  final VoidCallback onAdd;
  final ValueChanged<_GoalDdayItem> onEdit;
  final ValueChanged<_GoalDdayItem> onComplete;
  final ValueChanged<_GoalDdayItem> onPause;
  final ValueChanged<_GoalDdayItem> onStop;
  final ValueChanged<_GoalDdayItem> onResume;
  final ValueChanged<_GoalDdayItem> onDelete;

  String _dateText(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _ddayText(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return 'D+${diff.abs()}';
  }

  String _statusLabel(_GoalDdayItem goal) {
    if (goal.isCompleted || goal.status == 'completed') return '완료';
    if (goal.status == 'paused') return '보류';
    if (goal.status == 'stopped') return '중단';
    return '진행중';
  }

  Color _statusColor(BuildContext context, _GoalDdayItem goal) {
    final palette = context.mtfChartPalette;
    if (goal.isCompleted || goal.status == 'completed') {
      return palette.positiveSeries;
    }

    if (goal.status == 'paused') {
      return palette.warningSeries;
    }

    if (goal.status == 'stopped') {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final sortedGoals = List<_GoalDdayItem>.from(goals)..sort((a, b) {
      final aDone = a.isCompleted || a.status == 'completed';
      final bDone = b.isCompleted || b.status == 'completed';

      if (aDone != bDone) return aDone ? 1 : -1;

      return a.date.compareTo(b.date);
    });

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: tokens.sheetBackground,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.flag_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '목표 D-DAY 관리',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '수정, 완료, 보류, 중단, 삭제를 관리합니다.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    sortedGoals.isEmpty
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              '등록된 D-DAY가 없어요.\n바디프로필, 대회, 웨딩촬영 같은 목표를 먼저 추가해보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          itemCount: sortedGoals.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final goal = sortedGoals[index];
                            final statusColor = _statusColor(context, goal);
                            final isDone =
                                goal.isCompleted || goal.status == 'completed';
                            final isPaused = goal.status == 'paused';
                            final isStopped = goal.status == 'stopped';

                            return Container(
                              padding: const EdgeInsets.fromLTRB(
                                13,
                                12,
                                13,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.cardSurface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: tokens.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          goal.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: scheme.onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(goal),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_dateText(goal.date)} · ${_ddayText(goal.date)}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: [
                                      _GoalManageActionChip(
                                        label: '수정',
                                        icon: Icons.edit_outlined,
                                        onTap: () => onEdit(goal),
                                      ),
                                      if (!isDone && !isStopped)
                                        _GoalManageActionChip(
                                          label: '완료',
                                          icon: Icons.check_circle_outline,
                                          onTap: () => onComplete(goal),
                                        ),
                                      if (!isDone && !isPaused && !isStopped)
                                        _GoalManageActionChip(
                                          label: '보류',
                                          icon: Icons.pause_circle_outline,
                                          onTap: () => onPause(goal),
                                        ),
                                      if (!isDone && !isStopped)
                                        _GoalManageActionChip(
                                          label: '중단',
                                          icon: Icons.stop_circle_outlined,
                                          onTap: () => onStop(goal),
                                        ),
                                      if (!isDone && (isPaused || isStopped))
                                        _GoalManageActionChip(
                                          label: '다시 진행',
                                          icon: Icons.play_circle_outline,
                                          onTap: () => onResume(goal),
                                        ),
                                      _GoalManageActionChip(
                                        label: '삭제',
                                        icon: Icons.delete_outline,
                                        danger: true,
                                        onTap: () => onDelete(goal),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                          side: BorderSide(color: scheme.outline),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          '닫기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('D-DAY 추가'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalManageActionChip extends StatelessWidget {
  const _GoalManageActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractedInbodyData {
  final String date;
  final String weight;
  final String skeletalMuscle;
  final String bodyFatPercent;

  const _ExtractedInbodyData({
    required this.date,
    required this.weight,
    required this.skeletalMuscle,
    required this.bodyFatPercent,
  });
}

/// 카테고리 레슨의 운동 구성(`exercises`)을 공유 이미지 줄로 바꾼다: `이름 / 3세트 × 12회(+2)`.
List<ShareExerciseLine> categoryShareLines(
  List<Map<String, dynamic>> exercises,
) {
  final lines = <ShareExerciseLine>[];
  for (final exercise in exercises) {
    final name = (exercise['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final sets = (exercise['sets'] as num?)?.toInt() ?? 0;
    final reps = (exercise['reps'] as num?)?.toInt() ?? 0;
    final assist = (exercise['assist'] as num?)?.toInt() ?? 0;
    final summary =
        sets > 0 && reps > 0
            ? '${sets}세트 × ${reps}회${assist > 0 ? '(+$assist)' : ''}'
            : '';
    lines.add(ShareExerciseLine(name: name, summary: summary));
  }
  return lines;
}

/// 텍스트·음성 레슨의 공유 글. 회원 공개 메모(요약·잘한 점·숙제·주의)가 있으면 그것만,
/// 없으면 레슨 내용(메모)을 쓴다. 카테고리 레슨은 글 없이 운동 목록만 보낸다.
String textLessonShareBody({
  required String inputMethod,
  required String publicSummary,
  required String publicGood,
  required String publicHomeworkNote,
  required String publicCaution,
  required String memo,
}) {
  if (inputMethod == 'category') return '';
  final publicParts =
      [publicSummary, publicGood, publicHomeworkNote, publicCaution]
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
  if (publicParts.isNotEmpty) return publicParts.join('\n');
  return memo.trim();
}

/// 레슨일지 검색. 검색어를 공백으로 나눠 모두 들어 있으면 찾는다. 공백을 뺀 글자에서도
/// 찾아서 `무릎통증` 은 `무릎 통증` 을 찾는다.
bool logSearchMatches(String haystack, String query) {
  final text = haystack.toLowerCase();
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty);
  return tokens.every(
    (token) => text.contains(token) || compact.contains(token),
  );
}

class _TrainingLogItem {
  String title;
  String name;
  String time;
  String type;
  String memo;
  String id;
  DateTime date;
  double performanceScore;

  /// text | voice_draft | category
  String inputMethod;
  String source;

  /// 음성 초안 원문
  String rawVoiceText;
  String sessionStatus; // normal / service / no_show / no_show_no_deduct
  String registrationLabel;
  bool isRegistrationStart;
  bool isDraft;
  int packageCount;

  /// draft 상태에서 선택한 작성방식
  /// '' | text | category | pdf
  String draftEntryMode;

  List<String> issueChips;
  String homeworkStatus; // 완료 / 일부 / 미수행 / 없음
  String nextLessonCheckpoint;

  /// 시작 전 체크
  String preCondition; // 좋음 / 보통 / 나쁨
  String preMeal; // 1시간 이내 / 1~3시간 전 / 4시간 이상(공복) (옛 값: 공복 / 가볍게 먹음 / 충분히 먹음)
  String preNote; // 시작 전 특이사항 한 줄 메모
  bool preCheckDone; // 레슨 전 체크리스트를 완료했는지(화면 상태, 서버에 저장하지 않음)
  String inbodySummary; // 이번 레슨 전 인바디 측정 요약(화면 표시용, 측정값은 회원 건강정보에 기록)
  String preSleep; // 부족 / 보통 / 충분
  String prePain; // 없음 / 있음
  String preStretching; // 안 함 / 조금 함 / 충분히 함
  String prePainDetail;
  String duringPainDetail;
  String postPainDetail;

  /// 레슨 중 체크
  List<String> duringGoals; // 교정 / 통증관리 / 근력 / 가동성 / 체형
  List<String> duringFocusParts; // 하체 / 코어 / 어깨 / 허리 / 전신
  List<String> duringReactions; // 통증 / 집중도 / 밸런스 / 호흡 / 자세

  /// 종료 후 체크
  String postPainChange; // 없음 / 감소 / 유지 / 증가
  String postPerformance; // 낮음 / 보통 / 좋음
  String postNextAction; // 유지 / 진도업 / 통증재체크 / 숙제확인
  String postHomework; // 없음 / 스트레칭 / 복습운동 / 걷기 / 영상확인

  /// 공개/내부 메모 분리
  String internalMemo;
  String publicSummary;
  String publicGood;
  String publicHomeworkNote;
  String publicCaution;

  /// 카테고리 방식 운동 구성: {main, part, name, sets, reps, assist, note}
  List<Map<String, dynamic>> exercises;
  String cognitiveResponse; // 인지 잘됨 / 보통 / 어려움
  String performanceResponse; // 수행 좋음 / 보통 / 어려움 / 통증으로 제한

  SigCell trainerSig;
  SigCell customerSig;
  bool locked;
  bool deductionApplied;
  bool waitingTrainerConfirm;
  bool memberSignedFromWeb;
  bool confirmCancelled;
  String trainingLogDocId;
  String scheduleDocId;

  String trainerSignedDate;
  String trainerSignedTime;
  String customerSignedDate;
  String customerSignedTime;
  String lockedAtDate;
  String lockedAtTime;

  _TrainingLogItem({
    required this.title,
    required this.name,
    required this.time,
    required this.type,
    required this.memo,
    required this.date,
    required this.performanceScore,
    this.inputMethod = 'text',
    this.source = '',
    this.rawVoiceText = '',
    this.sessionStatus = 'normal',
    this.registrationLabel = '',
    this.isRegistrationStart = false,
    this.isDraft = false,
    this.draftEntryMode = '',
    this.issueChips = const [],
    this.homeworkStatus = '없음',
    this.nextLessonCheckpoint = '',
    this.preCondition = '보통',
    this.preMeal = '1~3시간 전',
    this.preNote = '',
    this.preCheckDone = false,
    this.inbodySummary = '',
    this.preSleep = '보통',
    this.prePain = '없음',
    this.prePainDetail = '',
    this.preStretching = '안 함',
    this.duringGoals = const [],
    this.duringFocusParts = const [],
    this.duringReactions = const [],
    this.duringPainDetail = '',
    this.postPainChange = '없음',
    this.postPainDetail = '',
    this.postPerformance = '보통',
    this.postNextAction = '유지',
    this.postHomework = '없음',
    this.internalMemo = '',
    this.publicSummary = '',
    this.publicGood = '',
    this.publicHomeworkNote = '',
    this.publicCaution = '',
    this.exercises = const [],
    this.cognitiveResponse = '보통',
    this.performanceResponse = '보통',
    SigCell? trainerSig,
    SigCell? customerSig,
    String? id,
    this.locked = false,
    this.deductionApplied = false,
    this.waitingTrainerConfirm = false,
    this.memberSignedFromWeb = false,
    this.confirmCancelled = false,
    this.trainingLogDocId = '',
    this.scheduleDocId = '',
    this.trainerSignedDate = '',
    this.trainerSignedTime = '',
    this.customerSignedDate = '',
    this.customerSignedTime = '',
    this.lockedAtDate = '',
    this.lockedAtTime = '',
    this.packageCount = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       trainerSig = trainerSig ?? SigCell.empty(),
       customerSig = customerSig ?? SigCell.empty();
}

class _TrainingLogCard extends StatelessWidget {
  const _TrainingLogCard({
    super.key,
    required this.item,
    required this.sessionNumber,
    required this.sessionDisplayText,
    required this.registrationStartText,
    required this.isHighlighted,
    required this.isExpanded,
    required this.goalDdayLabel,
    required this.femaleConditionVisible,
    required this.draftEntryMode,
    this.anatomySummary,
    this.onToggleExpand,
    this.onShareLesson,
    this.onFemaleConditionTap,
    this.onTap,
    this.onLongPress,
    this.onTapTrainerSig,
    this.onTapCustomerSig,
    this.onLongPressSig,
  });

  final _TrainingLogItem item;
  final int sessionNumber;
  final String registrationStartText;
  final String sessionDisplayText;
  final String goalDdayLabel;
  final bool femaleConditionVisible;
  final String draftEntryMode;
  final VoidCallback? onFemaleConditionTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapTrainerSig;
  final VoidCallback? onTapCustomerSig;
  final VoidCallback? onLongPressSig;
  final bool isHighlighted;
  final bool isExpanded;

  /// 아나토미 레슨일지의 요약. 있으면 운동 이름과 통증·주의·가동성 칩을 보여준다.
  final AnatomyLessonSummary? anatomySummary;

  /// 아나토미 카드의 펼침 화살표(카드 본문 탭은 레슨일지를 연다).
  final VoidCallback? onToggleExpand;

  /// 회원에게 레슨 요약 이미지를 보낸다(펼친 아나토미 카드).
  final VoidCallback? onShareLesson;

  String _issueChipSummary(_TrainingLogItem item) {
    if (item.issueChips.isEmpty) return '';
    return item.issueChips.join(', ');
  }

  String _draftEntryModeLabel(String value) {
    switch (value) {
      case 'text':
        return '텍스트';
      case 'category':
        return '카테고리';
      case 'pdf':
        return 'PDF';
      case 'anatomy':
        return '아나토미';
      default:
        return '작성방식 선택';
    }
  }

  String _inputMethodText(_TrainingLogItem item) {
    if (item.inputMethod == 'quick_sign') {
      if (item.memberSignedFromWeb ||
          item.source == 'member_signature_web' ||
          item.waitingTrainerConfirm) {
        return 'REMOTE SIGN';
      }

      return 'QUICK SIGN';
    }

    switch (item.inputMethod) {
      case 'category':
        return 'CATEGORY NOTE';
      case 'pdf':
        return 'PDF NOTE';
      case 'anatomy':
        return 'ANATOMY NOTE';
      case 'voice_draft':
      case 'text':
      default:
        return 'TEXT/VOICE NOTE';
    }
  }

  IconData _inputMethodIcon(_TrainingLogItem item) {
    if (item.inputMethod == 'quick_sign') {
      if (item.memberSignedFromWeb ||
          item.source == 'member_signature_web' ||
          item.waitingTrainerConfirm) {
        return Icons.link_rounded;
      }

      return Icons.draw_rounded;
    }

    switch (item.inputMethod) {
      case 'category':
        return Icons.sell_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'anatomy':
        return Icons.accessibility_new_rounded;
      case 'voice_draft':
      case 'text':
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _recordStatusText(_TrainingLogItem item) {
    if (item.confirmCancelled) {
      return '확정 취소';
    }

    if (item.waitingTrainerConfirm && item.memberSignedFromWeb) {
      return '확인 대기';
    }

    if (item.locked) {
      return '확정 완료';
    }

    if (item.trainerSig.isSigned || item.customerSig.isSigned) {
      return '서명 진행';
    }

    return '';
  }

  Color _inputMethodBgColor(String inputMethod) {
    switch (inputMethod) {
      case 'voice_draft':
        return const Color(0xFFEFF6FF);
      case 'category':
        return const Color(0xFFECFDF5);
      case 'text':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _inputMethodFgColor(String inputMethod) {
    switch (inputMethod) {
      case 'voice_draft':
        return const Color(0xFF1D4ED8);
      case 'category':
        return const Color(0xFF047857);
      case 'text':
      default:
        return Colors.black54;
    }
  }

  String _exerciseSummary(_TrainingLogItem item) {
    if (item.isDraft) return '탭해서 레슨일지 작성을 시작하세요';

    final memo = item.memo.trim();
    if (memo.isEmpty) return '(메모 없음)';

    if (item.inputMethod == 'category') {
      final exercises = _extractCategoryExercisesFromMemo(memo);
      if (exercises.isNotEmpty) {
        if (exercises.length == 1) return exercises.first;
        return '${exercises.first} 외 ${exercises.length - 1}개';
      }
    }

    final lines =
        memo
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    if (lines.isEmpty) return '(메모 없음)';

    var first = lines.first;
    if (first.length > 28) {
      first = '${first.substring(0, 28)}...';
    }
    return first;
  }

  /// 카드 2번째 줄: 아나토미 레슨은 운동 이름을 `/` 로 이어 한 줄로 보여준다.
  String _cardExerciseText(_TrainingLogItem item) {
    final summary = anatomySummary;
    if (summary == null) return _exerciseSummary(item);
    return summary.exerciseNames.isEmpty ? '운동 기록 없음' : summary.exerciseLine;
  }

  Widget _anatomyNoteChip(String label, int count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  /// 카드 3번째 줄: `통증 2  주의 1  가동성 1` (0개인 종류는 숨긴다).
  Widget _anatomyNoteChips(AnatomyLessonSummary summary, ColorScheme scheme) {
    if (!summary.hasNotes) {
      return Text(
        '특이사항 없음',
        style: TextStyle(
          fontSize: 11.5,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Wrap(
      key: const ValueKey<String>('log_card_note_chips'),
      spacing: 6,
      runSpacing: 4,
      children: [
        if (summary.painCount > 0)
          _anatomyNoteChip(
            '통증',
            summary.painCount,
            const Color(0xFFFEE2E2),
            const Color(0xFFB91C1C),
          ),
        if (summary.cautionCount > 0)
          _anatomyNoteChip(
            '주의',
            summary.cautionCount,
            const Color(0xFFFFEDD5),
            const Color(0xFF9A3412),
          ),
        if (summary.mobilityCount > 0)
          _anatomyNoteChip(
            '가동성',
            summary.mobilityCount,
            const Color(0xFFFEF9C3),
            const Color(0xFF854D0E),
          ),
      ],
    );
  }

  String _anatomyNoteTrailing(AnatomyLogRecord record) {
    switch (record.recordType) {
      case AnatomyRecordType.pain:
        return '${record.painLevel} / 10';
      case AnatomyRecordType.caution:
        return '주의';
      default:
        return switch (record.mobilityResult) {
          MobilityResult.normal => '○ 정상',
          MobilityResult.mild => '△ 보상',
          MobilityResult.severe => '× 제한',
          _ => '가동성',
        };
    }
  }

  Widget _anatomyNoteSection(
    String title,
    List<AnatomyLogRecord> records,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        for (final record in records)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anatomyNoteTitle(record),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        record.bodyPartLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      if (record.memo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            record.memo,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _anatomyNoteTrailing(record),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _thousands(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Widget _anatomyStatTile(String label, String value, {Key? key}) {
    return Expanded(
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// 펼친 카드(아나토미): 운동 개수·세트·볼륨과 한 운동 목록(세부 세트는 레슨일지에서).
  List<Widget> _anatomyStatWidgets(
    AnatomyLessonSummary summary,
    ColorScheme scheme,
  ) {
    final rows = summary.exerciseRows;
    if (rows.isEmpty) return const <Widget>[];
    final volume = summary.volumeKg;
    return [
      Row(
        key: const ValueKey<String>('log_card_stats'),
        children: [
          _anatomyStatTile('운동', '${rows.length}'),
          const SizedBox(width: 8),
          _anatomyStatTile('세트', '${summary.setCount}'),
          const SizedBox(width: 8),
          _anatomyStatTile('볼륨 kg', volume > 0 ? _thousands(volume) : '-'),
        ],
      ),
      const SizedBox(height: 10),
      for (final row in rows)
        Padding(
          key: ValueKey<String>('log_card_exercise_${row.name}'),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (row.pr)
                const Padding(
                  key: ValueKey<String>('log_card_pr'),
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 15,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              Text(
                row.part,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
    ];
  }

  /// 펼친 카드(아나토미): 통증·주의·가동성 상세. 세트·무게·횟수는 레슨일지를 열어 본다.
  List<Widget> _anatomyDetailWidgets(
    AnatomyLessonSummary summary,
    ColorScheme scheme,
  ) {
    return [
      if (summary.records.isNotEmpty) ...[
        AnatomyMiniFigures(records: summary.records),
        const SizedBox(height: 10),
      ],
      ..._anatomyStatWidgets(summary, scheme),
      if (!summary.hasNotes)
        Text(
          '통증·주의·가동성 기록이 없어요.',
          key: const ValueKey<String>('log_card_no_notes'),
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (summary.painCount > 0)
        _anatomyNoteSection('통증', summary.pain, scheme),
      if (summary.cautionCount > 0)
        _anatomyNoteSection('주의', summary.caution, scheme),
      if (summary.mobilityCount > 0)
        _anatomyNoteSection('가동성', summary.mobility, scheme),
      const SizedBox(height: 4),
      Text(
        '세트·무게·횟수는 카드를 눌러 레슨일지에서 확인해요.',
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      if (onShareLesson != null) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('log_card_share'),
            onPressed: onShareLesson,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('회원에게 레슨일지 보내기'),
          ),
        ),
      ],
    ];
  }

  String _memoSummary(_TrainingLogItem item) {
    final chipText = _issueChipSummary(item);
    final memo = item.memo.trim();

    if (chipText.isNotEmpty && memo.isNotEmpty) {
      var text = '$chipText, $memo';
      if (text.length > 42) {
        text = '${text.substring(0, 42)}...';
      }
      return text;
    }

    if (chipText.isNotEmpty) {
      return chipText;
    }

    if (memo.isEmpty) return '특이사항 없음';

    final lines =
        memo
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    if (lines.isEmpty) return '특이사항 없음';

    var text = lines.first;
    if (text.length > 42) {
      text = '${text.substring(0, 42)}...';
    }
    return text;
  }

  String _nextCheckpoint(_TrainingLogItem item) {
    if (item.waitingTrainerConfirm && item.memberSignedFromWeb) {
      return '회원 웹서명 완료 · 담당자 서명 대기';
    }

    if (item.memberSignedFromWeb && !item.locked) {
      return '회원 웹서명 완료 · 레슨 확정 전';
    }
    if (item.isDraft) return '레슨 전 · 중 · 후로 나눠서 기록하세요';
    if (item.sessionStatus == 'no_show') return '다음 레슨 일정 재확인';
    if (item.sessionStatus == 'no_show_no_deduct') return '노쇼 미차감 사유 확인';
    if (item.sessionStatus == 'service') return '서비스 처리 목적 확인';

    final parts = <String>[];

    if (item.postNextAction.isNotEmpty) {
      parts.add(item.postNextAction);
    }

    if (item.homeworkStatus.isNotEmpty && item.homeworkStatus != '없음') {
      parts.add('숙제 ${item.homeworkStatus}');
    }

    if (item.nextLessonCheckpoint.trim().isNotEmpty) {
      parts.add(item.nextLessonCheckpoint.trim());
    }

    if (parts.isEmpty && item.publicHomeworkNote.trim().isNotEmpty) {
      parts.add('회원 숙제 확인');
    }

    if (parts.isEmpty) {
      return '지난 레슨 체크사항 확인';
    }

    return parts.join(' · ');
  }

  IconData _bodyPartIcon(_TrainingLogItem item) {
    final body = _bodyPartSummary(item);

    if (body.contains('하체')) return Icons.accessibility_new_rounded;
    if (body.contains('코어')) return Icons.radio_button_checked_rounded;
    if (body.contains('어깨')) return Icons.pan_tool_alt_rounded;
    if (body.contains('허리')) return Icons.airline_seat_flat_rounded;
    if (body.contains('상체')) return Icons.fitness_center_rounded;
    return Icons.sports_gymnastics_rounded;
  }

  String _topLineLabel(_TrainingLogItem item, int sessionNumber) {
    final dateText =
        '${item.date.year}.${item.date.month.toString().padLeft(2, '0')}.${item.date.day.toString().padLeft(2, '0')} ${item.time}';

    switch (item.sessionStatus) {
      case 'service':
        return 'S.V · $dateText';
      case 'no_show':
        return '${sessionNumber}회차 · $dateText · NO SHOW';
      case 'no_show_no_deduct':
        return '${sessionNumber}회차 · $dateText · NO SHOW · 미차감';
      case 'normal':
      default:
        return '${sessionNumber}회차 · $dateText';
    }
  }

  String _bodyPartSummary(_TrainingLogItem item) {
    if (item.inputMethod == 'category') {
      final parts = _extractCategoryPartsFromMemo(item.memo);
      if (parts.isNotEmpty) {
        return parts.join(' · ');
      }
    }

    final memo = item.memo;
    if (memo.contains('하체')) return '하체';
    if (memo.contains('코어')) return '코어';
    if (memo.contains('어깨')) return '어깨';
    if (memo.contains('허리')) return '허리';
    if (memo.contains('상체')) return '상체';
    if (memo.contains('전신')) return '전신';
    return '';
  }

  List<String> _extractCategoryPartsFromMemo(String memo) {
    final lines = memo.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('부위:')) {
        final value = trimmed.replaceFirst('부위:', '').trim();
        if (value.isNotEmpty && !result.contains(value)) {
          result.add(value);
        }
      }
    }

    return result;
  }

  List<String> _extractCategoryExercisesFromMemo(String memo) {
    final lines = memo.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) {
        var text = trimmed.substring(2).trim();

        if (text.contains('·')) {
          text = text.split('·').first.trim();
        }

        text = text.replaceFirst(RegExp(r'\s+\d+세트$'), '').trim();

        if (text.isNotEmpty && !result.contains(text)) {
          result.add(text);
        }
      }
    }

    return result;
  }

  String _sessionDisplayLabel(_TrainingLogItem item, int sessionNumber) {
    switch (item.sessionStatus) {
      case 'service':
        return 'S.V';
      case 'no_show':
        return '${sessionNumber}회차 · NO SHOW';
      case 'no_show_no_deduct':
        return '${sessionNumber}회차 · NO SHOW(미차감)';
      case 'normal':
      default:
        return '${sessionNumber}회차';
    }
  }

  Color _statusAccentColor(_TrainingLogItem item) {
    switch (item.sessionStatus) {
      case 'service':
        return const Color(0xFF0F766E);
      case 'no_show':
        return const Color(0xFFB91C1C);
      case 'no_show_no_deduct':
        return const Color(0xFFEA580C);
      case 'normal':
      default:
        return Colors.black54;
    }
  }

  Uint8List _dataUrlToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final base64Part = (comma >= 0) ? dataUrl.substring(comma + 1) : dataUrl;
    return Uint8List.fromList(base64Decode(base64Part));
  }

  Widget _signaturePreview(SigCell cell) {
    if (!cell.isSigned) {
      return const Text(
        '대기',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.black45,
        ),
      );
    }

    if (cell.type == 'typed' && cell.value.isNotEmpty) {
      return Text(
        cell.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
        ),
      );
    }

    if (cell.type == 'drawn' && cell.value.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Image.memory(_dataUrlToBytes(cell.value)),
        ),
      );
    }

    return const Text(
      '완료',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _inlineSignatureChip({
    required String label,
    required SigCell cell,
    required String signedAt,
    required bool locked,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
  }) {
    final hasSignature = cell.isSigned;
    final isDrawnSignature =
        cell.type == 'drawn' && cell.value.startsWith('data:image/png;base64,');

    ImageProvider? signatureImage;
    if (isDrawnSignature) {
      final base64Body = cell.value.split(',').last;
      signatureImage = MemoryImage(base64Decode(base64Body));
    }

    return SizedBox(
      width: 130,
      child: InkWell(
        onTap: locked ? null : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  hasSignature
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE5E7EB),
            ),
          ),
          child: Stack(
            children: [
              if (signatureImage != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Image(
                        image: signatureImage,
                        fit: BoxFit.contain,
                        opacity: const AlwaysStoppedAnimation(0.32),
                      ),
                    ),
                  ),
                ),
              if (cell.type == 'typed' && cell.value.isNotEmpty)
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 0.18,
                      child: Text(
                        cell.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(hasSignature ? 0.50 : 0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasSignature
                                ? (signedAt.isEmpty ? '서명 완료' : signedAt)
                                : '미서명',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color:
                                  hasSignature
                                      ? const Color(0xFF2563EB)
                                      : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      hasSignature
                          ? Icons.check_circle_rounded
                          : Icons.draw_rounded,
                      size: 18,
                      color:
                          hasSignature
                              ? const Color(0xFF2563EB)
                              : Colors.black38,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlineNoShowSignatureChip({
    required bool noDeduct,
    required VoidCallback? onLongPress,
  }) {
    return SizedBox(
      width: 130,
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: noDeduct ? const Color(0xFFFFFBEB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  noDeduct ? const Color(0xFFFED7AA) : const Color(0xFFFECACA),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '회원 서명',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                noDeduct ? 'NO SHOW 미차감' : 'NO SHOW',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color:
                      noDeduct
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorSet = _colorSetForSessionType(item.type);
    final trainerOk = item.trainerSig.isSigned;
    final customerOk = item.customerSig.isSigned;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // 서비스·노쇼 카드는 상태 색을 입힌다. 다크모드에서는 어두운 상태 색을 쓴다
          // (밝은 파스텔 배경에 밝은 글자가 올라가 안 보이던 문제).
          color:
              item.sessionStatus == 'service'
                  ? (dark ? const Color(0xFF0F2E2B) : const Color(0xFFF0FDFA))
                  : item.sessionStatus == 'no_show'
                  ? (dark ? const Color(0xFF3A1F22) : const Color(0xFFFEF2F2))
                  : item.sessionStatus == 'no_show_no_deduct'
                  ? (dark ? const Color(0xFF3A2D14) : const Color(0xFFFFFBEB))
                  : tokens.trainingLogSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isHighlighted
                    ? const Color(0xFF2563EB)
                    : item.locked
                    ? const Color(0xFFD6D3D1)
                    : item.sessionStatus == 'service'
                    ? (dark ? const Color(0xFF2F7A72) : const Color(0xFF99F6E4))
                    : item.sessionStatus == 'no_show'
                    ? (dark ? const Color(0xFF8A4247) : const Color(0xFFFECACA))
                    : item.sessionStatus == 'no_show_no_deduct'
                    ? (dark ? const Color(0xFF8A6A2F) : const Color(0xFFFED7AA))
                    : tokens.trainingLogSetDivider,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1행
            // 1행: 날짜/시간은 단독으로 넓게 표시
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child:
                      item.sessionStatus == 'no_show_no_deduct'
                          ? RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    dark
                                        ? const Color(0xFFFDBA74)
                                        : const Color(0xFF92400E),
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${sessionNumber}회차 · ${item.date.year}.${item.date.month.toString().padLeft(2, '0')}.${item.date.day.toString().padLeft(2, '0')} ${item.time} · ',
                                ),
                                const TextSpan(text: 'NO SHOW '),
                                const TextSpan(
                                  text: '차감',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    decorationThickness: 3,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )
                          : Text(
                            _topLineLabel(item, sessionNumber),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color:
                                  item.sessionStatus == 'service'
                                      ? (dark
                                          ? const Color(0xFF5EEAD4)
                                          : const Color(0xFF0F766E))
                                      : item.sessionStatus == 'no_show'
                                      ? (dark
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFB91C1C))
                                      : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                ),
                const SizedBox(width: 6),
                if (onToggleExpand != null)
                  InkWell(
                    key: const ValueKey<String>('log_card_expand'),
                    onTap: onToggleExpand,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),

            const SizedBox(height: 7),

            // 1.5행: 상태 칩들은 별도 줄로 분리
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.inputMethod == 'quick_sign'
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          item.inputMethod == 'quick_sign'
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _inputMethodIcon(item),
                        size: 12,
                        color:
                            item.inputMethod == 'quick_sign'
                                ? const Color(0xFF4F46E5)
                                : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _inputMethodText(item),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color:
                              item.inputMethod == 'quick_sign'
                                  ? const Color(0xFF4F46E5)
                                  : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_recordStatusText(item).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          item.confirmCancelled
                              ? const Color(0xFFF3F4F6)
                              : item.waitingTrainerConfirm
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            item.confirmCancelled
                                ? const Color(0xFFD1D5DB)
                                : item.waitingTrainerConfirm
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Text(
                      _recordStatusText(item),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color:
                            item.confirmCancelled
                                ? const Color(0xFF6B7280)
                                : item.waitingTrainerConfirm
                                ? const Color(0xFFD97706)
                                : const Color(0xFF059669),
                      ),
                    ),
                  ),
                if (item.waitingTrainerConfirm && item.memberSignedFromWeb)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Text(
                      '담당자 대기',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                if (item.isDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          draftEntryMode.isEmpty
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            draftEntryMode.isEmpty
                                ? const Color(0xFFFED7AA)
                                : const Color(0xFFC7D2FE),
                      ),
                    ),
                    child: Text(
                      _draftEntryModeLabel(draftEntryMode),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            draftEntryMode.isEmpty
                                ? const Color(0xFF9A3412)
                                : const Color(0xFF4338CA),
                      ),
                    ),
                  ),
                if (femaleConditionVisible)
                  GestureDetector(
                    onTap: onFemaleConditionTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3DE),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFC0DD97)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.spa_outlined,
                            size: 12,
                            color: Color(0xFF3B6D11),
                          ),
                          SizedBox(width: 3),
                          Text(
                            '컨디션',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3B6D11),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    goalDdayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 2행
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorSet.softBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorSet.border),
                  ),
                  child: Icon(
                    _bodyPartIcon(item),
                    size: 18,
                    color: colorSet.fg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cardExerciseText(item),
                    maxLines: anatomySummary == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                item.sessionStatus == 'no_show'
                    ? _inlineNoShowSignatureChip(
                      noDeduct: false,
                      onLongPress: onLongPressSig,
                    )
                    : item.sessionStatus == 'no_show_no_deduct'
                    ? _inlineNoShowSignatureChip(
                      noDeduct: true,
                      onLongPress: onLongPressSig,
                    )
                    : _inlineSignatureChip(
                      label: '회원 서명',
                      cell: item.customerSig,
                      signedAt:
                          item.customerSignedTime.isEmpty
                              ? item.customerSignedDate
                              : item.customerSignedTime,
                      locked: item.locked || item.confirmCancelled,
                      onTap: item.confirmCancelled ? null : onTapCustomerSig,
                      onLongPress: onLongPressSig,
                    ),
              ],
            ),
            const SizedBox(height: 10),

            // 3행
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      anatomySummary != null
                          ? _anatomyNoteChips(anatomySummary!, scheme)
                          : Text(
                            _memoSummary(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                ),
                const SizedBox(width: 8),
                _inlineSignatureChip(
                  label: '담당자 서명',
                  cell: item.trainerSig,
                  signedAt:
                      item.trainerSignedTime.isEmpty
                          ? item.trainerSignedDate
                          : item.trainerSignedTime,
                  locked: item.locked || item.confirmCancelled,
                  onTap: item.confirmCancelled ? null : onTapTrainerSig,
                  onLongPress: onLongPressSig,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4행
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nextCheckpoint(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.confirmCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: const Text(
                      '확정취소',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                else if (item.locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Text(
                      '확정',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.trainingLogSetRow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.trainingLogSetDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            _inputMethodText(item),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (item.locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                              ),
                            ),
                            child: const Text(
                              '기록 확정',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (anatomySummary != null)
                      ..._anatomyDetailWidgets(anatomySummary!, scheme)
                    else ...[
                      Text(
                        '레슨 내용',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          item.memo.trim().isEmpty
                              ? '(메모 없음)'
                              : item.memo.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (item.rawVoiceText.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '음성 원문',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          item.rawVoiceText.trim(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (registrationStartText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '등록 시작 정보',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          registrationStartText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                    if (onShareLesson != null && anatomySummary == null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey<String>('log_card_share'),
                          onPressed: onShareLesson,
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('회원에게 레슨일지 보내기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SigMiniBox extends StatelessWidget {
  const _SigMiniBox({
    required this.label,
    required this.cell,
    required this.locked,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final SigCell cell;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  Uint8List _dataUrlToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final base64Part = (comma >= 0) ? dataUrl.substring(comma + 1) : dataUrl;
    return Uint8List.fromList(base64Decode(base64Part));
  }

  String _inputMethodLabel(String inputMethod) {
    switch (inputMethod) {
      case 'voice_draft':
        return '음성초안';
      case 'category':
        return '카테고리형';
      case 'text':
      default:
        return '텍스트';
    }
  }

  Color _inputMethodBgColor(String inputMethod) {
    switch (inputMethod) {
      case 'voice_draft':
        return const Color(0xFFEFF6FF);
      case 'category':
        return const Color(0xFFECFDF5);
      case 'text':
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _inputMethodFgColor(String inputMethod) {
    switch (inputMethod) {
      case 'voice_draft':
        return const Color(0xFF1D4ED8);
      case 'category':
        return const Color(0xFF047857);
      case 'text':
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;

    if (cell.type == 'drawn' && cell.value.isNotEmpty) {
      inner = Image.memory(
        _dataUrlToBytes(cell.value),
        height: 20,
        width: 92,
        fit: BoxFit.contain,
      );
    } else if (cell.type == 'typed' && cell.value.isNotEmpty) {
      inner = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✍', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              cell.value,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      inner = Text(
        '$label 서명',
        style: TextStyle(
          fontSize: 10,
          color: locked ? Colors.black26 : Colors.black45,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return InkWell(
      onTap: locked ? null : onTap,
      onLongPress: locked ? onLongPress : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF9FAFB) : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: locked ? Colors.grey.shade200 : const Color(0xFFC7D2FE),
          ),
        ),
        child: Center(child: inner),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final set = _colorSetForSessionType(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: set.softBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: set.fg,
        ),
      ),
    );
  }
}

class _SessionTypeChip extends StatelessWidget {
  const _SessionTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final set = _colorSetForSessionType(label);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? set.fg : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? set.fg : set.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : set.fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : set.fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SigCell {
  final String type; // '' | 'typed' | 'drawn'
  final String value;

  const SigCell({required this.type, required this.value});

  factory SigCell.empty() => const SigCell(type: '', value: '');

  bool get isSigned => type.isNotEmpty && value.isNotEmpty;
}

class SignatureSheet extends StatefulWidget {
  const SignatureSheet({
    super.key,
    required this.title,
    this.initial,
    required this.typedController,
  });

  final String title;
  final SigCell? initial;
  final TextEditingController typedController;

  @override
  State<SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<SignatureSheet> {
  bool _typedMode = false;
  bool _showTypedInput = false;
  final GlobalKey repaintKey = GlobalKey();
  final GlobalKey<_SimpleSignatureCanvasState> canvasKey =
      GlobalKey<_SimpleSignatureCanvasState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> _exportPngDataUrl() async {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final img = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;

    final b64 = base64Encode(bytes.buffer.asUint8List());
    return 'data:image/png;base64,$b64';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          builder: (context, controller) {
            return Material(
              color: tokens.sheetBackground,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _typedMode ? '타이핑 서명' : '손글씨 서명',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _typedMode = !_typedMode;
                                  });
                                },
                                child: Text(
                                  _typedMode ? '손글씨로 서명하기' : '타이핑으로 서명하기',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_typedMode) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.trainingLogSetRow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: tokens.trainingLogSetDivider,
                                ),
                              ),
                              child: Text(
                                '박스 안에 서명해주세요.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            RepaintBoundary(
                              key: repaintKey,
                              child: Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: tokens.signatureCanvasSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: tokens.contractDocumentBorder,
                                  ),
                                ),
                                child: SimpleSignatureCanvas(
                                  key: canvasKey,
                                  height: 200,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed:
                                      () => canvasKey.currentState?.clear(),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('지우기'),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextField(
                              controller: widget.typedController,
                              decoration: InputDecoration(
                                hintText: '이름 입력',
                                filled: true,
                                fillColor: tokens.trainingLogSetRow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(14),
                                color: tokens.signatureCanvasSurface,
                              ),
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: widget.typedController,
                                builder: (_, v, __) {
                                  return Text(
                                    v.text.isEmpty
                                        ? '입력한 이름이 여기에 보여요.'
                                        : v.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          v.text.isEmpty
                                              ? Colors.black38
                                              : Colors.black87,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            if (_typedMode) {
                              final name = widget.typedController.text.trim();
                              if (name.isEmpty) return;
                              Navigator.pop(
                                context,
                                SigCell(type: 'typed', value: name),
                              );
                              return;
                            }

                            final hasDrawn =
                                canvasKey.currentState?.hasStroke == true;
                            if (!hasDrawn) return;

                            final dataUrl = await _exportPngDataUrl();
                            if (dataUrl == null) return;

                            Navigator.pop(
                              context,
                              SigCell(type: 'drawn', value: dataUrl),
                            );
                          },
                          child: const Text('적용'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SimpleSignatureCanvas extends StatefulWidget {
  const SimpleSignatureCanvas({
    super.key,
    required this.height,
    required this.strokeWidth,
  });

  final double height;
  final double strokeWidth;

  @override
  State<SimpleSignatureCanvas> createState() => _SimpleSignatureCanvasState();
}

class _SimpleSignatureCanvasState extends State<SimpleSignatureCanvas> {
  final List<List<Offset>> _paths = [];

  bool get hasStroke => _paths.any((p) => p.length > 1);

  void clear() => setState(() => _paths.clear());

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        setState(() {
          _paths.add([details.localPosition]);
        });
      },
      onPanUpdate: (details) {
        setState(() {
          if (_paths.isEmpty) return;
          final dx = details.localPosition.dx.clamp(0.0, double.infinity);
          final dy = details.localPosition.dy.clamp(0.0, widget.height);
          _paths.last.add(Offset(dx, dy));
        });
      },
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _SigPainter(paths: _paths, stroke: widget.strokeWidth),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter({required this.paths, required this.stroke});

  final List<List<Offset>> paths;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final p =
        Paint()
          ..color = Colors.black
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    for (final path in paths) {
      if (path.length < 2) continue;
      final drawPath = Path()..moveTo(path.first.dx, path.first.dy);
      for (int i = 1; i < path.length; i++) {
        drawPath.lineTo(path[i].dx, path[i].dy);
      }
      canvas.drawPath(drawPath, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter oldDelegate) => true;
}

const List<String> _sessionTypes = ['개인PT', '재활', '필라테스', '요가', '그룹/자율'];

IconData _iconForSessionType(String type) {
  switch (type) {
    case '개인PT':
      return Icons.fitness_center_rounded;
    case '재활':
      return Icons.healing_rounded;
    case '필라테스':
      return Icons.self_improvement_rounded;
    case '요가':
      return Icons.spa_rounded;
    case '그룹/자율':
      return Icons.groups_2_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}

_SessionColorSet _colorSetForSessionType(String type) {
  switch (type) {
    case '개인PT':
      return const _SessionColorSet(
        fg: Color(0xFF4F46E5),
        softBg: Color(0xFFEDE9FE),
        border: Color(0xFFC7D2FE),
      );
    case '재활':
      return const _SessionColorSet(
        fg: Color(0xFFDC2626),
        softBg: Color(0xFFFEF2F2),
        border: Color(0xFFFECACA),
      );
    case '필라테스':
      return const _SessionColorSet(
        fg: Color(0xFF7C3AED),
        softBg: Color(0xFFF3E8FF),
        border: Color(0xFFD8B4FE),
      );
    case '요가':
      return const _SessionColorSet(
        fg: Color(0xFF0F766E),
        softBg: Color(0xFFCCFBF1),
        border: Color(0xFF99F6E4),
      );
    case '그룹/자율':
      return const _SessionColorSet(
        fg: Color(0xFFEA580C),
        softBg: Color(0xFFFFEDD5),
        border: Color(0xFFFED7AA),
      );
    default:
      return const _SessionColorSet(
        fg: Color(0xFF4F46E5),
        softBg: Color(0xFFEDE9FE),
        border: Color(0xFFC7D2FE),
      );
  }
}

class _SessionColorSet {
  final Color fg;
  final Color softBg;
  final Color border;

  const _SessionColorSet({
    required this.fg,
    required this.softBg,
    required this.border,
  });
}

class _PdfDraftPlaceholderPage extends StatelessWidget {
  const _PdfDraftPlaceholderPage({
    required this.memberName,
    required this.sessionType,
  });

  final String memberName;
  final String sessionType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text('PDF 작성')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF 작성 / 생성 준비중',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '회원: ${memberName.isEmpty ? '회원 미지정' : memberName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '레슨유형: $sessionType',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '지금 단계에서는 PDF 전용 페이지 틀만 먼저 연결합니다.\n다음 단계에서 회원용 / 내부보관용 PDF 생성으로 확장하면 됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 단계 추천',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. 회원 공개용 PDF 레이아웃\n'
                      '2. 내부 보관용 PDF 레이아웃\n'
                      '3. 저장된 운동일지 데이터를 PDF로 변환\n'
                      '4. 공유 / 저장 버튼 연결',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF3730A3),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _BlueSheetHeader extends StatelessWidget {
  const _BlueSheetHeader({
    required this.title,
    this.subtitle,
    this.icon = Icons.more_horiz_rounded,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final gradient = context.mtfHeaderGradient;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onClose ?? () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
