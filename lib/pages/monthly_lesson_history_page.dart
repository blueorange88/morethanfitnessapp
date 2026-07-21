import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/monthly_lesson_record.dart';
import '../services/app_tier_access_service.dart';
import '../services/monthly_lesson_stats_repository.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/monthly_lesson_calendar.dart';
import 'client_card_page.dart';

class MonthlyLessonHistoryPage extends StatefulWidget {
  const MonthlyLessonHistoryPage({
    super.key,
    required this.personalOwnerUid,
    this.repository,
    this.accessLoader,
  });

  final String personalOwnerUid;
  final PersonalMonthlyLessonStatsRepository? repository;
  final Future<AppTierAccessSnapshot> Function()? accessLoader;

  @override
  State<MonthlyLessonHistoryPage> createState() =>
      _MonthlyLessonHistoryPageState();
}

class _MonthlyLessonHistoryPageState extends State<MonthlyLessonHistoryPage> {
  late DateTime _selectedMonth;
  DateTime? _selectedDay;
  MonthlyLessonSummary? _summary;
  MonthlyLessonViewState _state = MonthlyLessonViewState.loading;
  AppTierAccessSnapshot? _access;
  bool _tierLoading = true;
  bool _tierFailed = false;

  String get _ownerUid => widget.personalOwnerUid.trim();
  PersonalMonthlyLessonStatsRepository get _repository =>
      widget.repository ?? PersonalMonthlyLessonStatsRepository(uid: _ownerUid);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _prepareAccess();
  }

  Future<void> _prepareAccess() async {
    try {
      final access = await (widget.accessLoader?.call() ??
          AppTierAccessService.loadPersonalTrainerAccess(uid: _ownerUid));
      if (!mounted) return;
      final allowed = AppTierAccessService.canUseFeature(
        access,
        AppTierFeatureKey.lessonInsights,
      );
      setState(() {
        _access = access;
        _tierLoading = false;
      });
      if (allowed) await _loadMonth();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tierLoading = false;
        _tierFailed = true;
      });
    }
  }

  bool get _canUseLessonInsights =>
      _access != null &&
      AppTierAccessService.canUseFeature(
        _access!,
        AppTierFeatureKey.lessonInsights,
      );

  Future<void> _showTierGuide() async {
    final access = _access;
    if (access == null) return;
    await AifcTierFeatureGateSheet.show(
      context: context,
      access: access,
      feature: AppTierFeatureKey.lessonInsights,
    );
  }

  Future<void> _loadMonth() async {
    final requestedMonth = _selectedMonth;
    setState(() {
      _state = MonthlyLessonViewState.loading;
      _summary = null;
      _selectedDay = null;
    });
    try {
      final summary = await _repository.loadMonth(requestedMonth);
      if (!mounted ||
          requestedMonth.year != _selectedMonth.year ||
          requestedMonth.month != _selectedMonth.month) {
        return;
      }
      setState(() {
        _summary = summary;
        _state = summary.totalConfirmed == 0
            ? MonthlyLessonViewState.empty
            : MonthlyLessonViewState.success;
      });
    } on FirebaseException catch (error) {
      if (!mounted ||
          requestedMonth.year != _selectedMonth.year ||
          requestedMonth.month != _selectedMonth.month) {
        return;
      }
      setState(() {
        _state = error.code == 'permission-denied'
            ? MonthlyLessonViewState.permissionDenied
            : MonthlyLessonViewState.networkError;
      });
    } catch (_) {
      if (!mounted ||
          requestedMonth.year != _selectedMonth.year ||
          requestedMonth.month != _selectedMonth.month) {
        return;
      }
      setState(() => _state = MonthlyLessonViewState.networkError);
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadMonth();
  }

  void _returnToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month));
    _loadMonth();
  }

  Future<void> _openMember(MonthlyLessonRecord record) async {
    final memberId = record.memberId.trim();
    if (memberId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .doc(memberId)
          .get();
      final data = snapshot.data();
      final owned = snapshot.exists &&
          data?['memberId'] == memberId &&
          data?['trainerId'] == _ownerUid &&
          data?['workspaceType'] == 'personal' &&
          data?['managementState'] != 'deleted';
      debugPrint(
        '[MTF_MONTHLY_LESSON_MEMBER] workspace=personal owned=$owned',
      );
      if (!owned || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientCardPage(
            memberId: memberId,
            isEditMode: true,
            personalOwnerUid: _ownerUid,
          ),
        ),
      );
    } catch (_) {
      debugPrint(
        '[MTF_MONTHLY_LESSON_MEMBER] workspace=personal owned=false',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4BDB),
        foregroundColor: Colors.white,
        title: const Text(
          '월간 레슨 기록',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _tierLoading
            ? const Center(child: CircularProgressIndicator())
            : _tierFailed
                ? const Center(
                    child: Text(
                      '등급 정보를 확인하지 못했어요.\n잠시 후 다시 시도해주세요.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : !_canUseLessonInsights
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '인사이트는 Pro부터 사용할 수 있어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF312E81),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _showTierGuide,
                                child: const Text('등급 안내 보기'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        child: MonthlyLessonCalendar(
                          month: _selectedMonth,
                          state: _state,
                          summary: _summary,
                          selectedDay: _selectedDay,
                          onPreviousMonth: () => _moveMonth(-1),
                          onNextMonth: () => _moveMonth(1),
                          onCurrentMonth: _returnToCurrentMonth,
                          onDaySelected: (day) =>
                              setState(() => _selectedDay = day),
                          onRetry: _loadMonth,
                          onMemberTap: _openMember,
                        ),
                      ),
      ),
    );
  }
}
