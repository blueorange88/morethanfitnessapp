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
import 'personal_training_log_anatomy_dummy_page.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const Color kLogBgColor = Color(0xFFF3F4F6);
const Color kLogCardColor = Colors.white;
const Color kLogBorderColor = Color(0xFFE5E7EB);
const double kLogPageHorizontalPadding = 16;
const double kLogMaxContentWidth = 520;

const String kMemberSignBaseUrl = 'https://more-than-fitness-f6adb.web.app/sign';

class PersonalTrainingLogPage extends StatefulWidget {
  final String? memberId;
  final String? memberName;
  final String? trainerName;
  final String? memberPhone;
  final int? totalSessions;
  final int? remainingSessions;
  final DateTime? lastLogAt;

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
    this.quickMemo,
    this.recentIssue,
    this.reRegistrationLabel,
    this.openingMent,
  });

  @override
  State<PersonalTrainingLogPage> createState() =>
      _PersonalTrainingLogPageState();
}

class _PersonalTrainingLogPageState extends State<PersonalTrainingLogPage> {
  static const String kResetPin = '0000';

  final List<_TrainingLogItem> _logs = [];

  String _lastTrainerTyped = '';
  String _lastCustomerTyped = '';
  bool _isHeaderInfoExpanded = false;
  String _logFilter = 'all';
  String _searchQuery = '';
  String? _highlightDraftId;
  String? _expandedLogId;

  /// 마지막 작성 타입 유지
  String _lastSelectedSessionType = '개인PT';

  /// 달력/빠른 이동용 날짜 필터
  DateTime? _selectedDateFilter;

  /// 샘플 인바디 추이
  final List<double> _inbodyTrend = [31.5, 31.9, 32.4, 32.8, 33.2];
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  final Map<String, GlobalKey> _logCardKeys = {};
  final List<_GoalDdayItem> _goalDdays = [];

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

    _GoalDdayItem? _nearestGoalDday() {
      if (_goalDdays.isEmpty) return null;

      final now = DateTime.now();
      final sorted = [..._goalDdays]
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final goal in sorted) {
        final goalDate = DateTime(goal.date.year, goal.date.month, goal.date.day);
        final today = DateTime(now.year, now.month, now.day);
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

    if (diff >= 0) {
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

    final now = DateTime.now();
    final d1 = now.subtract(const Duration(days: 18));
    final d2 = now.subtract(const Duration(days: 14));
    final d3 = now.subtract(const Duration(days: 11));
    final d4 = now.subtract(const Duration(days: 8));
    final d5 = now.subtract(const Duration(days: 5));
    final d6 = now.subtract(const Duration(days: 2));
    final d7 = now.subtract(const Duration(days: 1));

    _logs.addAll([
      _TrainingLogItem(
        title: '하체 패턴 교정',
        name: '김유신',
        time: '09:00',
        type: '개인PT',
        memo: '흉추 회전 체크 후 스쿼트 패턴 교정 진행',
        date: d1,
        performanceScore: 5.8,
        inputMethod: 'text',
        registrationLabel: '재등록 3회차',
        isRegistrationStart: true,
        packageCount: 30,
      ),
      _TrainingLogItem(
        title: '자율운동 체크',
        name: '김유신',
        time: '19:00',
        type: '그룹/자율',
        memo: '플랭크, 데드버그, 밴드 워크 수행 상태 확인',
        date: d6,
        performanceScore: 8.1,
        inputMethod: 'text',
        sessionStatus: 'service',
      ),
      _TrainingLogItem(
        title: '무릎 부담 조절',
        name: '김유신',
        time: '10:00',
        type: '재활',
        memo: '선피로 트레이닝으로 무릎 부담 감소 유도',
        date: d2,
        performanceScore: 6.2,
        inputMethod: 'text',
      ),
      _TrainingLogItem(
        title: '코어 안정화',
        name: '김유신',
        time: '11:30',
        type: '필라테스',
        memo: '호흡 + 코어 연결감 위주로 진행',
        date: d3,
        performanceScore: 6.8,
        inputMethod: 'text',
      ),
      _TrainingLogItem(
        title: '무릎 부담 감소 재확인',
        name: '김유신',
        time: '09:20',
        type: '재활',
        memo: '무릎 불편감 감소, 런지 깊이 조절하면서 진행',
        date: d7,
        performanceScore: 8.5,
        inputMethod: 'text',
        sessionStatus: 'no_show',
      ),
      _TrainingLogItem(
        title: '상체 가동성 회복',
        name: '김유신',
        time: '07:50',
        type: '개인PT',
        memo: 'T-spine 모빌리티와 어깨 움직임 재확인',
        date: d5,
        performanceScore: 7.8,
        inputMethod: 'text',
      ),
      _TrainingLogItem(
        title: '전신 밸런스',
        name: '김유신',
        time: '08:30',
        type: '요가',
        memo: '고관절 정렬과 좌우 밸런스 중심',
        date: d4,
        performanceScore: 7.1,
        inputMethod: 'text',
      ),

    ]);

    _loadQuickSignedLogsFromFirestore();

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
      case 'completed':
      default:
        return 'normal';
    }
  }

  Future<void> _loadQuickSignedLogsFromFirestore() async {
    final memberId = (widget.memberId ?? '').trim();
    if (memberId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('training_logs')
          .where('memberId', isEqualTo: memberId)
          .where('quickSignedOnly', isEqualTo: true)
          .get();

      if (!mounted) return;

      final nextLogs = <_TrainingLogItem>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final rawStartAt = data['startAt'];
        final startAt = _quickLogDateFromAny(rawStartAt) ?? DateTime.now();

        final statusRaw = (data['sessionStatus'] ?? '').toString();
        final localStatus = _quickLogStatusToLocalStatus(statusRaw);

        final title = (data['title'] ?? '빠른 서명').toString();
        final memo = (data['memo'] ?? '').toString();
        final type = (data['lessonType'] ?? data['type'] ?? '개인PT').toString();
        final name = (data['memberName'] ?? widget.memberName ?? '회원').toString();

        final trainerSignature = data['trainerSignature'];
        final memberSignature = data['memberSignature'];

        final trainerSignedAt = trainerSignature is Map
            ? _quickLogDateFromAny(trainerSignature['signedAt'])
            : null;

        final memberSignedAt = memberSignature is Map
            ? _quickLogDateFromAny(memberSignature['signedAt'])
            : null;

        final trainerSignedDate = trainerSignedAt == null
            ? ''
            : _quickLogDateText(trainerSignedAt);
        final trainerSignedTime = trainerSignedAt == null
            ? ''
            : _quickLogTimeText(trainerSignedAt);

        final memberSignedDate = memberSignedAt == null
            ? ''
            : _quickLogDateText(memberSignedAt);
        final memberSignedTime = memberSignedAt == null
            ? ''
            : _quickLogTimeText(memberSignedAt);

        final trainerSigned = data['trainerSigned'] == true;
        final memberSigned = data['memberSigned'] == true;

        nextLogs.add(
          _TrainingLogItem(
            id: 'quick_${doc.id}',
            title: title,
            name: name,
            time: _quickLogTimeText(startAt),
            type: type,
            memo: memo.isEmpty ? '빠른 서명으로 저장된 수업일지입니다.' : memo,
            date: DateTime(startAt.year, startAt.month, startAt.day),
            performanceScore: 0,
            inputMethod: 'quick_sign',
            source: (data['source'] ?? '').toString(),
            waitingTrainerConfirm: data['waitingTrainerConfirm'] == true,
            memberSignedFromWeb: memberSignature is Map &&
                (memberSignature['signedBy'] ?? '').toString() == 'member_web',
            sessionStatus: localStatus,
            isDraft: false,
            trainerSig: trainerSigned
                ? const SigCell(type: 'typed', value: '서명 완료')
                : SigCell.empty(),
            customerSig: memberSigned
                ? const SigCell(type: 'typed', value: '서명 완료')
                : SigCell.empty(),
            locked: data['locked'] == true,
            trainerSignedDate: trainerSignedDate,
            trainerSignedTime: trainerSignedTime,
            customerSignedDate: memberSignedDate,
            customerSignedTime: memberSignedTime,
            lockedAtDate: data['lockedAt'] is Timestamp
                ? _quickLogDateText((data['lockedAt'] as Timestamp).toDate())
                : '',
            lockedAtTime: data['lockedAt'] is Timestamp
                ? _quickLogTimeText((data['lockedAt'] as Timestamp).toDate())
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
    } catch (e) {
      debugPrint('빠른 서명 로그 불러오기 실패: $e');
    }
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
          log.sessionStatus == 'service' || log.sessionStatus == 'no_show_no_deduct';

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
      items = items
          .where((e) => _isSameDate(e.date, _selectedDateFilter!))
          .toList();
    }

    switch (_logFilter) {
      case 'unsigned':
        items = items.where((e) {
          final trainerOk = e.trainerSig.isSigned;
          final customerOk = e.customerSig.isSigned;
          return !(trainerOk && customerOk);
        }).toList();
        break;
      case 'locked':
        items = items.where((e) => e.locked).toList();
        break;
      case 'rehab':
        items = items.where((e) => e.type == '재활').toList();
        break;
      case 'all':
      default:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((e) {
        final dateText =
            '${e.date.year}.${e.date.month.toString().padLeft(2, '0')}.${e.date.day.toString().padLeft(2, '0')}';

        final target = [
          e.title,
          e.memo,
          e.type,
          dateText,
        ].join(' ').toLowerCase();

        return target.contains(_searchQuery);
      }).toList();
    }

    return items;
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
      builder: (_) => _LessonCalendarSheet(
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

  Future<void> _openGoalDdayManager() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> saveGoal({required _GoalDdayItem? editing}) async {
              final nameController = TextEditingController(
                text: editing?.name ?? '',
              );
              DateTime selectedDate = editing?.date ?? DateTime.now();

              final result = await showModalBottomSheet<bool>(
                context: sheetContext,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (innerContext) {
                  return StatefulBuilder(
                    builder: (innerContext, setInnerState) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: MediaQuery.of(innerContext).viewInsets.bottom + 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                editing == null ? '목표 D-DAY 추가' : '목표 D-DAY 수정',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: '목표 이름',
                                  hintText: '예: 바디프로필 / 결혼식 / 촬영',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: innerContext,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  );
                                  if (picked != null) {
                                    setInnerState(() {
                                      selectedDate = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(
                                    '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    if (nameController.text.trim().isEmpty) return;
                                    if (editing == null && _goalDdays.length >= 3) return;

                                    setState(() {
                                      if (editing == null) {
                                        _goalDdays.add(
                                          _GoalDdayItem(
                                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                                            name: nameController.text.trim(),
                                            date: selectedDate,
                                          ),
                                        );
                                      } else {
                                        editing.name = nameController.text.trim();
                                        editing.date = selectedDate;
                                      }
                                    });

                                    Navigator.pop(innerContext, true);
                                  },
                                  child: Text(editing == null ? '추가' : '수정 저장'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );

              if (result == true) {
                setModalState(() {});
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '목표 D-DAY 관리',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (_goalDdays.length < 3)
                            TextButton.icon(
                              onPressed: () => saveGoal(editing: null),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('추가'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_goalDdays.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '등록된 목표가 없어요. 최대 3개까지 추가할 수 있어요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ..._goalDdays.map((goal) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final dateOnly = DateTime(goal.date.year, goal.date.month, goal.date.day);
                        final diff = dateOnly.difference(today).inDays;
                        final ddayText = diff >= 0 ? 'D-$diff' : 'D+${diff.abs()}';

                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${goal.date.year}.${goal.date.month.toString().padLeft(2, '0')}.${goal.date.day.toString().padLeft(2, '0')} · $ddayText',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => saveGoal(editing: goal),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: sheetContext,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: const Text('목표 삭제'),
                                        content: Text('${goal.name} 목표를 삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogContext, false),
                                            child: const Text('취소'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(dialogContext, true),
                                            child: const Text('삭제'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    setState(() {
                                      _goalDdays.removeWhere((e) => e.id == goal.id);
                                    });
                                    setModalState(() {});
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }),
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
                  title: const Text('수업 달력 보기'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openLessonCalendar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('목표 D-DAY 관리'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openGoalDdayManager();
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

      final recognizer = TextRecognizer(
        script: TextRecognitionScript.korean,
      );

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
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String findValue(List<String> keywords) {
      for (int i = 0; i < lines.length; i++) {
        final compact = lines[i].replaceAll(' ', '').toLowerCase();
        final hasKeyword = keywords.any(
              (keyword) => compact.contains(keyword.replaceAll(' ', '').toLowerCase()),
        );

        if (!hasKeyword) continue;

        final currentMatch =
        RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)').firstMatch(lines[i]);
        if (currentMatch != null) {
          return currentMatch.group(1)!.replaceAll(',', '.');
        }

        if (i + 1 < lines.length) {
          final nextMatch =
          RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)').firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            return nextMatch.group(1)!.replaceAll(',', '.');
          }
        }
      }

      return '';
    }

    final dateMatch =
    RegExp(r'(20\d{2}[.\-/]\d{1,2}[.\-/]\d{1,2})').firstMatch(raw);

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: StatefulBuilder(
              builder: (sheetContext, setModalState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '인바디 자동입력',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          imageFile,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '자동 인식된 값이에요. 틀린 값만 수정하고 저장하세요.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateC,
                        decoration: InputDecoration(
                          labelText: '측정일',
                          hintText: '예: 2026.03.21',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: weightC,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '체중(kg)',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: skeletalC,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '골격근량',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bodyFatC,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '체지방률(%)',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            final skeletalValue =
                            _tryParseDouble(skeletalC.text.trim());

                            setState(() {
                              _latestInbodyDate = dateC.text.trim();
                              _latestWeight = weightC.text.trim();
                              _latestBodyFatPercent = bodyFatC.text.trim();

                              if (skeletalValue != null) {
                                _inbodyTrend.add(skeletalValue);
                              }
                            });

                            Navigator.pop(sheetContext);
                            _showSnack('인바디 수치를 적용했어요.');
                          },
                          child: const Text(
                            '인바디 적용',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
    final headerName = (widget.memberName ?? '').trim();
    final headerTrainer = (widget.trainerName ?? '').trim();

    final headerTitle =
    headerName.isNotEmpty ? '$headerName 님 수업일지' : '수업일지';

    final latestLessonDate = widget.lastLogAt ?? _latestLogDate();
    final lastLessonText =
    latestLessonDate == null ? '기록없음' : _fmtDotYmd(latestLessonDate);

    final recentIssue = (widget.recentIssue ?? '').trim().isNotEmpty
        ? widget.recentIssue!.trim()
        : '최근 이슈 · 무릎 통증 호소';

    final reRegistrationLabel =
    (widget.reRegistrationLabel ?? '').trim().isNotEmpty
        ? widget.reRegistrationLabel!.trim()
        : '3회차';

    final openingMent = (widget.openingMent ?? '').trim().isNotEmpty
        ? widget.openingMent!.trim()
        : '지난수업에 상체근력 트레이닝 진행하여, 오늘은 하체근력 트레이닝을 진행해볼게요.';
    final headerInitialGoal = _initialGoalLabel();
    final headerGoalDday = _goalDdayLabel();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
        isTablet ? kLogMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kLogBgColor,
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
                    inbodyTrend: _inbodyTrend,
                    todayRecommendedExercise: _todayRecommendedExercise(),
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
                    onInbodyTap: _showInbodyScanOptions,
                    onCalendarTap: _openCalendarMenu,
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

    final changeLabel = change == 0
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            child: chartLogs.isEmpty
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('전체', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('미서명', 'unsigned'),
          const SizedBox(width: 8),
          _buildFilterChip('잠금완료', 'locked'),
          const SizedBox(width: 8),
          _buildFilterChip('재활수업', 'rehab'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: Colors.black45,
          ),
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
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.black45,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSectionHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Text(
            _fmtDotYmd(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _logFilter == value;

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
          color: selected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openNewLogSheet,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '오늘 수업일지 작성',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMemberSignRequestSheetFromLogPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              side: BorderSide(
                color: const Color(0xFF4F46E5).withOpacity(0.24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text(
              '회원 서명 요청',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7EAFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF1D4ED8),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "• 달력에서 표시된 날만 수업 기록이 있어요\n"
                  "• 날짜를 누르면 당일의 수업일지만 바로 볼 수 있어요\n"
                  "• 전체 기록으로 다시 흐름을 확인할 수 있어요\n"
                  "• 카드에는 핵심만, 자세한 내용은 탭해서 확인해요",
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF1F2937),
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

    if (logs.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 20,
              color: Colors.grey,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _searchQuery.isNotEmpty
                    ? "검색 결과가 없어요.\n다른 키워드로 다시 검색해보세요."
                    : "조건에 맞는 수업일지가 없어요.\n필터를 바꾸거나 새 기록을 작성해보세요.",
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black54,
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
        children.add(_buildTimelineSectionHeader(_monthSectionLabel(currentDate)));
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
            goalDdayLabel: _goalDdayLabel(),
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

                _openDraftEntryPicker(log);
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
                  });
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Future<void> _tryUnlockLog(_TrainingLogItem log) async {
    if (!log.locked) return;

    final pin = await _askPin(context);
    if (pin != kResetPin) {
      _showSnack('PIN 불일치');
      return;
    }

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

    _showSnack('잠금 해제 완료 · 서명/시간이 초기화되었어요.');
  }

  Future<void> _tapSig(_TrainingLogItem log, String role) async {
    if (log.locked) {
      _showSnack('이미 잠긴 기록입니다. 길게 눌러 PIN으로 잠금 해제하세요.');
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
      builder: (_) => SignatureSheet(
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
        // 일반 수업은 강사 + 회원 서명 모두 완료되어야 확정
        if (log.trainerSig.isSigned && log.customerSig.isSigned) {
          log.locked = true;
          log.lockedAtDate = nowD;
          log.lockedAtTime = nowT;
        }
      }

      shouldApplyDeduction =
          !wasLocked && log.locked && !log.deductionApplied;
    });

    if (shouldApplyDeduction) {
      await _applyRemainingSessionDeductionIfNeeded(log);
    }
  }

  Future<void> _openNewLogSheet() async {
    final existingDraft = _findTodayDraft();

    if (existingDraft != null) {
      setState(() {
        _highlightDraftId = existingDraft.id;
      });
      _scrollToLog(existingDraft.id);
      _showSnack('오늘 작성 중인 수업일지가 있어요. 먼저 확인해 주세요.');
      return;
    }

    final now = DateTime.now();

    setState(() {
      _selectedDateFilter = null;

      final draft = _TrainingLogItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: '레슨일지 작성 전',
        name: (widget.memberName ?? '').trim().isEmpty
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
    _showSnack('새로운 수업일지를 작성해 보세요.');
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

  String _quickSignLogIdForCurrentLogPage() {
    final memberId = (widget.memberId ?? '').trim();
    final now = DateTime.now();

    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');

    return 'quick_sign_${memberId}_${y}${m}${d}_$h$min';
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

    await FirebaseFirestore.instance.collection('sign_requests').doc(token).set({
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

    return {
      'token': token,
      'link': link,
      'trainingLogId': trainingLogId,
    };
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BlueSheetHeader(
                  title: '작성방법 변경',
                  subtitle: '현재 작성 중인 내용이 삭제될 수 있어요.',
                  icon: Icons.swap_horiz_rounded,
                  onClose: () => Navigator.pop(sheetContext, false),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '작성방법을 변경하시겠습니까?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        log.title.trim().isEmpty
                            ? '기존 입력 내용은 초기화될 수 있습니다.'
                            : '"${log.title}"의 기존 입력 내용은 초기화될 수 있습니다.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 18),
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
                              child: const Text('변경하기'),
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
        );
      },
    );

    return result == true;
  }

  Future<void> _openDraftEntryPicker(_TrainingLogItem log) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlueSheetHeader(
                  title: '수업일지 작성 방식 선택',
                  subtitle: '수업 스타일에 맞는 방식으로 빠르게 기록해요.',
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
                        locked: true,
                        lockText: 'PRO 업데이트 필요',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showSnack('아나토미버전 작성은 PRO 프리미엄 결제 해주세요.');
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

    if (selected == 'text' || selected == 'category') {
      await _openEditorForDraft(log, forcedMode: selected);
      return;
    }

    if (selected == 'pdf') {
      await _openPdfDraftPage(log);
      return;
    }
  }
  Future<void> _openPdfDraftPage(_TrainingLogItem log) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPdfPage(
          memberName: log.name,
          sessionType: log.type,
        ),
      ),
    );
  }
  void _applyDraftEditorResult(
      _TrainingLogItem log,
      Map<String, dynamic> map,
      ) {
    final String title = (map['title'] ?? '').toString().trim();
    final String memo = (map['memo'] ?? '').toString().trim();
    final String type = (map['type'] ?? '개인PT').toString();

    setState(() {
      log.title = title.isEmpty ? '레슨일지' : title;
      log.name = (map['name'] ?? '').toString().trim().isEmpty
          ? ((widget.memberName ?? '').trim().isEmpty
          ? '회원 미지정'
          : (widget.memberName ?? '').trim())
          : (map['name'] ?? '').toString().trim();
      log.memo = memo;
      log.type = type;
      log.time = _nowHm();
      log.inputMethod = (map['inputMethod'] ?? 'text').toString();
      log.rawVoiceText = (map['rawVoiceText'] ?? '').toString();
      log.issueChips =
          ((map['issueChips'] as List?) ?? []).map((e) => e.toString()).toList();
      log.homeworkStatus = (map['homeworkStatus'] ?? '없음').toString();
      log.nextLessonCheckpoint =
          (map['nextLessonCheckpoint'] ?? '').toString().trim();

      log.preCondition = (map['preCondition'] ?? '보통').toString();
      log.preMeal = (map['preMeal'] ?? '가볍게 먹음').toString();
      log.preSleep = (map['preSleep'] ?? '보통').toString();
      log.prePain = (map['prePain'] ?? '없음').toString();
      log.prePainDetail = (map['prePainDetail'] ?? '').toString().trim();
      log.preStretching = (map['preStretching'] ?? '안 함').toString();

      log.duringGoals =
          ((map['duringGoals'] as List?) ?? []).map((e) => e.toString()).toList();
      log.duringFocusParts =
          ((map['duringFocusParts'] as List?) ?? []).map((e) => e.toString()).toList();
      log.duringReactions =
          ((map['duringReactions'] as List?) ?? []).map((e) => e.toString()).toList();
      log.duringPainDetail = (map['duringPainDetail'] ?? '').toString().trim();

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

      log.isDraft = false;
      _lastSelectedSessionType = type;
      _highlightDraftId = null;
    });
  }

  Future<void> _openTextVoiceDraftPage(_TrainingLogItem log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogTextVoicePage(
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
    _applyDraftEditorResult(log, result as Map<String, dynamic>);
    _showSnack('텍스트 수업일지가 저장되었어요.');
  }

    Future<void> _openCategoryDraftPage(_TrainingLogItem log) async {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonalTrainingLogCategoryPage(
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
      _applyDraftEditorResult(log, result as Map<String, dynamic>);
      _showSnack('카테고리 운동일지가 저장되었어요.');
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
                if (log.sessionStatus != 'normal')
                  SizedBox(
                    width: 96,
                    height: 24,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: log.sessionStatus == 'service'
                            ? const Color(0xFFF0FDFA)
                            : log.sessionStatus == 'no_show'
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: log.sessionStatus == 'service'
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
                          color: log.sessionStatus == 'service'
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
                          ? '이 기록은 잠겼어요 · ${log.lockedAtDate} ${log.lockedAtTime}'
                          : '이 기록은 잠겼어요',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
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
                        locked: log.locked,
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
                        locked: log.locked,
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
                        '잠금 해제(PIN)',
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
                locked ? '잠김' : '탭하여 서명',
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

  void _openLogMoreMenu(_TrainingLogItem log) {
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
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              _BlueSheetHeader(
                title: '수업 상태 관리',
              subtitle: log.title,
              icon: Icons.tune_rounded,
              onClose: () => Navigator.pop(sheetContext),
            ),
            Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('상세 보기'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openLogDetailSheet(log);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('일반 수업으로 변경'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateSessionStatus(log, 'normal');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined),
                  title: const Text('서비스 처리'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateSessionStatus(log, 'service');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('노쇼 처리'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateSessionStatus(log, 'no_show');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: const Text('노쇼 미차감 처리'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateSessionStatus(log, 'no_show_no_deduct');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_open_rounded),
                  title: const Text('잠금 해제(PIN)'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _tryUnlockLog(log);
                  },
                ),
              ],
            ),
            ]
          ),
          ),
        );
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
      _showSnack('일반 수업으로 변경했어요.');
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
    final id = (log.id ?? '').trim();

    if (id.isNotEmpty) {
      return id;
    }

    // 혹시 id가 비어있는 예전 더미/임시 로그가 있을 때를 위한 fallback입니다.
    final title = log.title.trim();
    final date =
        '${log.date.year.toString().padLeft(4, '0')}-'
        '${log.date.month.toString().padLeft(2, '0')}-'
        '${log.date.day.toString().padLeft(2, '0')}';

    final time = log.time.toString().trim();
    return [
      widget.memberId ?? '',
      date,
      time,
      title,
    ].where((e) => e.trim().isNotEmpty).join('|');
  }

  Future<void> _applyRemainingSessionDeductionIfNeeded(
      _TrainingLogItem log,
      ) async {
    if (log.deductionApplied) return;
    if (!_shouldDeductSessionOnLock(log)) return;

    final memberId = (widget.memberId ?? '').trim();

    if (memberId.isEmpty) {
      _showSnack('회원 연결이 없어 잔여 수업을 차감하지 않았어요.');
      return;
    }

    final deductionKey = _deductionKeyForLog(log);

    if (deductionKey.isEmpty) {
      _showSnack('수업일지 식별값이 없어 잔여 수업을 차감하지 않았어요.');
      return;
    }

    try {
      final memberRef =
      FirebaseFirestore.instance.collection('members').doc(memberId);

      final logDocId = log.id.startsWith('quick_')
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

        final deductedLogIds = deductedLogIdsRaw is List
            ? deductedLogIdsRaw.map((e) => e.toString()).toSet()
            : <String>{};

        if (deductedLogIds.contains(deductionKey)) {
          alreadyDeducted = true;
          return;
        }

        final sessions = data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};

        final rawRemain = data['remainSessions'] ??
            data['remainingSessions'] ??
            sessions['remain'] ??
            data['remainingPt'] ??
            data['ptRemaining'];

        final currentRemain = rawRemain is num
            ? rawRemain.toInt()
            : int.tryParse((rawRemain ?? '').toString()) ?? 0;

        final rawDone = data['doneSessions'] ?? sessions['done'];

        final currentDone = rawDone is num
            ? rawDone.toInt()
            : int.tryParse((rawDone ?? '').toString()) ?? 0;

        final nextRemain = currentRemain > 0 ? currentRemain - 1 : 0;
        final nextDone = currentRemain > 0 ? currentDone + 1 : currentDone;

        nextRemainForMessage = nextRemain;

        transaction.set(
          memberRef,
          {
            'remainSessions': nextRemain,
            'remainingSessions': nextRemain,
            'doneSessions': nextDone,
            'sessions.remain': nextRemain,
            'sessions.done': nextDone,

            // 이 수업일지는 이미 차감됐다는 기록입니다.
            'deductedTrainingLogIds': FieldValue.arrayUnion([deductionKey]),

            'lastLogAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          logRef,
          {
            'waitingTrainerConfirm': false,
            'confirmedByTrainer': true,
            'confirmedAt': FieldValue.serverTimestamp(),
            'locked': true,
            'deductionApplied': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      log.deductionApplied = true;

      if (!mounted) return;

      if (alreadyDeducted) {
        _showSnack('이미 잔여 수업에 반영된 수업일지예요.');
        return;
      }

      if ((nextRemainForMessage ?? 0) <= 0) {
        _showSnack('수업일지가 확정되었어요. 잔여 수업은 0회입니다.');
      } else {
        _showSnack('수업일지가 확정되어 잔여 수업 1회가 차감되었어요.');
      }
    } catch (e) {
      debugPrint('잔여 수업 차감 실패: $e');

      if (!mounted) return;
      _showSnack('잔여 수업 차감에 실패했어요. 회원카드에서 확인해 주세요.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
          child: Image.memory(
            _dataUrlToBytes(cell.value),
          ),
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

  String _todayRecommendedExercise() {
    if (_logs.isEmpty) return '추천 운동 없음';

    final latest = _logsNewestFirst().first;
    final summary = _exerciseSummaryFromLog(latest);

    if (summary.isEmpty) return '추천 운동 없음';
    return summary;
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

    final lines = memo
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
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFD1D5DB),
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: locked ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                      color: locked
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: locked
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: locked ? Colors.black54 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: locked ? Colors.black45 : Colors.black54,
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
    required this.inbodyTrend,
    required this.todayRecommendedExercise,
    required this.initialGoalLabel,
    required this.goalDdayLabel,
    required this.isExpanded,
    required this.onBackTap,
    required this.onToggleExpand,
    required this.onInbodyTap,
    required this.onCalendarTap,
  });

  final String title;
  final int totalSessions;
  final int remainingSessions;
  final String lastLessonText;

  final String recentIssue;
  final String reRegistrationLabel;
  final String openingMent;
  final List<double> inbodyTrend;
  final String todayRecommendedExercise;
  final String initialGoalLabel;
  final String goalDdayLabel;

  final bool isExpanded;

  final VoidCallback onBackTap;
  final VoidCallback onToggleExpand;
  final VoidCallback onInbodyTap;
  final VoidCallback onCalendarTap;


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 14,
        left: 16,
        right: 16,
        bottom: 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  tooltip: '인바디 스캔',
                  onTap: onInbodyTap,
                ),
                const SizedBox(width: 8),
                _HeaderTopActionButton(
                  icon: Icons.calendar_month_rounded,
                  tooltip: '달력 보기',
                  onTap: onCalendarTap,
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
                  label: '마지막 수업일',
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
          Center(
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? '수업 상세 정보 닫기' : '수업 상세 정보 보기',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
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
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isExpanded
                ? Padding(
              key: const ValueKey('header_info_open'),
              padding: const EdgeInsets.only(top: 12),
              child: _HeaderMemberInfoBox(
                openingMent: openingMent,
                inbodyTrend: inbodyTrend,
                todayRecommendedExercise: todayRecommendedExercise,
              ),
            )
                : const SizedBox.shrink(
              key: ValueKey('header_info_closed'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMemberInfoBox extends StatelessWidget {
  const _HeaderMemberInfoBox({
    required this.openingMent,
    required this.inbodyTrend,
    required this.todayRecommendedExercise,
  });

  final String openingMent;
  final List<double> inbodyTrend;
  final String todayRecommendedExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        children: [
          _HeaderMessageCard(
            title: '다음 수업 시작 멘트 및 체크포인트',
            value: openingMent,
          ),
          const SizedBox(height: 10),
          _HeaderMessageCard(
            title: '오늘 추천 운동',
            value: todayRecommendedExercise,
          ),
          const SizedBox(height: 10),
          _MiniTrendCard(
            title: '인바디 추이',
            values: inbodyTrend,
            unitLabel: '최근 인바디',
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoTile extends StatelessWidget {
  const _HeaderInfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
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
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
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
            style: const TextStyle(
              color: Colors.white,
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

class _MiniTrendCard extends StatelessWidget {
  const _MiniTrendCard({
    required this.title,
    required this.values,
    required this.unitLabel,
  });

  final String title;
  final List<double> values;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final last = values.isEmpty ? 0.0 : values.last;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
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
          const SizedBox(height: 4),
          Text(
            '${last.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unitLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: _MiniSparkline(
              values: values,
              lineColor: Colors.white,
              pointColor: Colors.white,
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
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
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
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.2,
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
  const _PerformanceLineChart({
    required this.logs,
  });

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
          children: logs.map((log) {
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
  _PerformanceLineChartPainter({
    required this.values,
  });

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
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
    final valueRange = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : (maxValue - minValue);

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx = values.length == 1
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
      canvas.drawCircle(
        point,
        2.2,
        Paint()..color = Colors.white,
      );
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

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
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
    final range = (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx = values.length == 1
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

  const _LessonCalendarResult._({
    this.selectedDate,
    this.clearFilter = false,
  });

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
    final base = widget.selectedDate ??
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
      final isSelected = widget.selectedDate != null &&
          _isSameDate(widget.selectedDate!, normalized);
      final isToday = _isSameDate(DateTime.now(), normalized);

      cells.add(
        InkWell(
          onTap: isLessonDay
              ? () => Navigator.pop(
            context,
            _LessonCalendarResult.select(normalized),
          )
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEEF2FF)
                  : isLessonDay
                  ? Colors.white
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
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
                    color: isLessonDay
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
                  '수업 달력',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
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
                      _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
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
                    onPressed: widget.firstDate == null
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
                    onPressed: widget.lastDate == null
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
                    onPressed: () => Navigator.pop(
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

  _GoalDdayItem({
    required this.id,
    required this.name,
    required this.date,
  });
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
  String preMeal; // 공복 / 가볍게 먹음 / 충분히 먹음
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

  SigCell trainerSig;
  SigCell customerSig;
  bool locked;
  bool deductionApplied;
  bool waitingTrainerConfirm;
  bool memberSignedFromWeb;

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
    this.preMeal = '가볍게 먹음',
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

    SigCell? trainerSig,
    SigCell? customerSig,
    String? id,
    this.locked = false,
    this.deductionApplied = false,
    this.waitingTrainerConfirm = false,
    this.memberSignedFromWeb = false,
    this.trainerSignedDate = '',
    this.trainerSignedTime = '',
    this.customerSignedDate = '',
    this.customerSignedTime = '',
    this.lockedAtDate = '',
    this.lockedAtTime = '',
    this.packageCount = 0,





  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
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
    required this.draftEntryMode,
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
  final String draftEntryMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapTrainerSig;
  final VoidCallback? onTapCustomerSig;
  final VoidCallback? onLongPressSig;
  final bool isHighlighted;
  final bool isExpanded;


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
        return 'TAG NOTE';
      case 'pdf':
        return 'PDF NOTE';
      case 'voice_draft':
      case 'text':
      default:
        return 'TEXT NOTE';
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
      case 'voice_draft':
      case 'text':
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _recordStatusText(_TrainingLogItem item) {
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

    final lines = memo
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

    final lines = memo
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
      return '회원 웹서명 완료 · 수업 확정 전';
    }
    if (item.isDraft) return '수업 전 · 중 · 후로 나눠서 기록하세요';
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
          child: Image.memory(
            _dataUrlToBytes(cell.value),
          ),
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
              color: hasSignature
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                              color: hasSignature
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
                      color: hasSignature
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
              color: noDeduct ? const Color(0xFFFED7AA) : const Color(0xFFFECACA),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '고객 서명',
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
                  color: noDeduct
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

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.sessionStatus == 'service'
              ? const Color(0xFFF0FDFA)
              : item.sessionStatus == 'no_show'
              ? const Color(0xFFFEF2F2)
              : item.sessionStatus == 'no_show_no_deduct'
              ? const Color(0xFFFFFBEB)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF2563EB)
                : item.locked
                ? const Color(0xFFD6D3D1)
                : item.sessionStatus == 'service'
                ? const Color(0xFF99F6E4)
                : item.sessionStatus == 'no_show'
                ? const Color(0xFFFECACA)
                : item.sessionStatus == 'no_show_no_deduct'
                ? const Color(0xFFFED7AA)
                : colorSet.border,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1행
            Row(
              children: [
                Expanded(
                  child: item.sessionStatus == 'no_show_no_deduct'
                      ? RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
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
                      color: item.sessionStatus == 'service'
                          ? const Color(0xFF0F766E)
                          : item.sessionStatus == 'no_show'
                          ? const Color(0xFFB91C1C)
                          : Colors.black45,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.inputMethod == 'quick_sign'
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: item.inputMethod == 'quick_sign'
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
                        color: item.inputMethod == 'quick_sign'
                            ? const Color(0xFF4F46E5)
                            : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _inputMethodText(item),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: item.inputMethod == 'quick_sign'
                              ? const Color(0xFF4F46E5)
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_recordStatusText(item).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.waitingTrainerConfirm
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: item.waitingTrainerConfirm
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Text(
                      _recordStatusText(item),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: item.waitingTrainerConfirm
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.waitingTrainerConfirm && item.memberSignedFromWeb)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: draftEntryMode.isEmpty
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: draftEntryMode.isEmpty
                                ? const Color(0xFFFED7AA)
                                : const Color(0xFFC7D2FE),
                          ),
                        ),
                        child: Text(
                          _draftEntryModeLabel(draftEntryMode),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: draftEntryMode.isEmpty
                                ? const Color(0xFF9A3412)
                                : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        goalDdayLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.black38,
                    ),
                  ],
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
                    _exerciseSummary(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
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
                  label: '고객 서명',
                  cell: item.customerSig,
                  signedAt: item.customerSignedTime.isEmpty
                      ? item.customerSignedDate
                      : item.customerSignedTime,
                  locked: item.locked,
                  onTap: onTapCustomerSig,
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
                  child: Text(
                    _memoSummary(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _inlineSignatureChip(
                  label: '담당자 서명',
                  cell: item.trainerSig,
                  signedAt: item.trainerSignedTime.isEmpty
                      ? item.trainerSignedDate
                      : item.trainerSignedTime,
                  locked: item.locked,
                  onTap: onTapTrainerSig,
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.locked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Text(
                      '잠김',
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFFED7AA)),
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
                    const Text(
                      '레슨 내용',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
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
                        item.memo.trim().isEmpty ? '(메모 없음)' : item.memo.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.rawVoiceText.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '음성 원문',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
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
                      const Text(
                        '등록 시작 정보',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
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
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
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
          border: Border.all(
            color: isSelected ? set.fg : set.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : set.fg,
            ),
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
    return SafeArea(
      child: Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          builder: (context, controller) {
            return Material(
              color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Text(
                                '박스 안에 서명해주세요.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
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
                                  onPressed: () => canvasKey.currentState?.clear(),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
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
                                fillColor: const Color(0xFFF8FAFC),
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
                                color: Colors.white,
                              ),
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: widget.typedController,
                                builder: (_, v, __) {
                                  return Text(
                                    v.text.isEmpty ? '입력한 이름이 여기에 보여요.' : v.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: v.text.isEmpty ? Colors.black38 : Colors.black87,
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

                            final hasDrawn = canvasKey.currentState?.hasStroke == true;
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
        painter: _SigPainter(
          paths: _paths,
          stroke: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter({
    required this.paths,
    required this.stroke,
  });

  final List<List<Offset>> paths;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final p = Paint()
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

const List<String> _sessionTypes = [
  '개인PT',
  '재활',
  '필라테스',
  '요가',
  '그룹/자율',
];

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
      appBar: AppBar(
        title: const Text('PDF 작성'),
      ),
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
                      '수업유형: $sessionType',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
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
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}