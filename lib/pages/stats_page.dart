import 'dart:ui';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_tier_access_service.dart';
import '../utils/lesson_insights_stats.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/mtf_floating_more_menu.dart';
import 'monthly_lesson_history_page.dart';
import '../theme/app_colors.dart';

import '../aifc/core/aifc_avatar.dart';
import '../widgets/mtf_header_neon_overlay.dart';

@visibleForTesting
bool blocksEntireStatsPage({
  required bool isPersonalWorkspace,
  required bool canUseAdvancedInsights,
}) =>
    !canUseAdvancedInsights;

class StatsPage extends StatefulWidget {
  final Map<String, dynamic> scheduleData;
  final String? personalOwnerUid;

  const StatsPage({
    super.key,
    this.scheduleData = const {},
    this.personalOwnerUid,
  });

  @override
  State<StatsPage> createState() => _LessonInsightsPageState();
}

enum _StatsPeriod { week, month, threeMonths, custom }

class _StatsDateRange {
  const _StatsDateRange(this.start, this.endExclusive);

  final DateTime start;
  final DateTime endExclusive;
}

class _LessonInsightsPageState extends State<StatsPage> {
  AppTierAccessSnapshot? _tierAccess;
  bool _isTierAccessLoading = true;
  bool _tierAccessFailed = false;
  bool _didShowPersonalTierGate = false;
  bool _isStatsLoading = true;
  String? _loadError;
  LessonInsightStats? _stats;
  _StatsPeriod _period = _StatsPeriod.month;
  DateTimeRange? _customRange;

  bool get _isPersonalWorkspace =>
      (widget.personalOwnerUid ?? '').trim().isNotEmpty;
  String get _personalOwnerUid => widget.personalOwnerUid!.trim();

  bool get _canUseStatsPage => (_tierAccess?.tierRank ?? 0) >= 3;

  @override
  void initState() {
    super.initState();
    _loadTierAccess();
  }

  Future<void> _loadTierAccess() async {
    try {
      final access = _isPersonalWorkspace
          ? await AppTierAccessService.loadPersonalTrainerAccess(
              uid: _personalOwnerUid,
            )
          : await AppTierAccessService.loadTrainerAccess();
      if (!mounted) return;
      setState(() {
        _tierAccess = access;
        _tierAccessFailed = false;
        _isTierAccessLoading = false;
      });
      if (!_isPersonalWorkspace || access.tierRank >= 3) {
        await _loadStats();
      } else if (mounted) {
        setState(() => _isStatsLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _didShowPersonalTierGate) return;
          _didShowPersonalTierGate = true;
          AifcTierFeatureGateSheet.show(
            context: context,
            access: access,
            feature: AppTierFeatureKey.lessonInsights,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tierAccess = null;
        _tierAccessFailed = true;
        _isStatsLoading = false;
        _isTierAccessLoading = false;
      });
    }
  }

  _StatsDateRange _dateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _StatsPeriod.week:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return _StatsDateRange(start, start.add(const Duration(days: 7)));
      case _StatsPeriod.month:
        return _StatsDateRange(
          DateTime(today.year, today.month),
          DateTime(today.year, today.month + 1),
        );
      case _StatsPeriod.threeMonths:
        return _StatsDateRange(
          DateTime(today.year, today.month - 2),
          DateTime(today.year, today.month + 1),
        );
      case _StatsPeriod.custom:
        final range = _customRange;
        if (range == null) {
          return _StatsDateRange(today, today.add(const Duration(days: 1)));
        }
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1));
        return _StatsDateRange(start, end);
    }
  }

  Future<void> _loadStats() async {
    final now = DateTime.now();
    final range = _dateRange(now);
    if (mounted) {
      setState(() {
        _isStatsLoading = true;
        _loadError = null;
      });
    }

    try {
      Query<Map<String, dynamic>> scheduleQuery = FirebaseFirestore.instance
          .collection('schedules')
          .where(
            'startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where(
            'startAt',
            isLessThan: Timestamp.fromDate(range.endExclusive),
          );
      Query<Map<String, dynamic>> memberQuery =
          FirebaseFirestore.instance.collection('members');
      if (_isPersonalWorkspace) {
        scheduleQuery = scheduleQuery
            .where('trainerId', isEqualTo: _personalOwnerUid)
            .where('workspaceType', isEqualTo: 'personal');
        memberQuery = memberQuery
            .where('trainerId', isEqualTo: _personalOwnerUid)
            .where('workspaceType', isEqualTo: 'personal');
      }
      final results = await Future.wait<dynamic>([
        scheduleQuery.get(),
        memberQuery.get(),
      ]);
      final scheduleSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final memberSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      final lessons = scheduleSnapshot.docs
          .map((doc) => doc.data())
          .where((data) => !_isDeleted(data))
          .map((data) {
        final startAt = _dateFromAny(data['startAt']);
        if (startAt == null) return null;
        return LessonInsightEntry(
          startAt: startAt,
          status: (data['lessonConfirmStatus'] ?? '').toString().trim(),
          type: (data['typeName'] ?? data['type'] ?? '기타').toString(),
        );
      }).whereType<LessonInsightEntry>();

      final members = memberSnapshot.docs
          .map((doc) => doc.data())
          .where((data) => !_isDeleted(data))
          .map((data) {
        final sessions = data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};
        final membership = data['membership'] is Map
            ? Map<String, dynamic>.from(data['membership'] as Map)
            : <String, dynamic>{};
        return LessonInsightMember(
          status: (data['memberStatus'] ?? '').toString().trim(),
          remainingSessions: _intFromAny(
            sessions['remain'] ??
                data['remainSessions'] ??
                data['remainingSessions'],
          ),
          totalSessions: _intFromAny(
            sessions['total'] ?? data['totalSessions'],
          ),
          createdAt: _dateFromAny(data['createdAt']),
          membershipEndAt: _dateFromAny(
            membership['endAt'] ??
                membership['passEnd'] ??
                data['membershipEndAt'] ??
                data['expireAt'],
          ),
          lastLessonAt: _dateFromAny(
            data['lastLessonAt'] ?? data['lastLogAt'],
          ),
        );
      });

      final stats = LessonInsightStats.calculate(
        lessons: lessons,
        members: members,
        periodStart: range.start,
        periodEndExclusive: range.endExclusive,
        now: now,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isStatsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isStatsLoading = false;
        _loadError = error.toString();
      });
    }
  }

  static bool _isDeleted(Map<String, dynamic> data) {
    if (data['isDeleted'] == true ||
        data['deleted'] == true ||
        data['voided'] == true ||
        data['archived'] == true ||
        data['deletedAt'] != null) {
      return true;
    }
    final status = [
      data['status'],
      data['scheduleStatus'],
      data['lessonStatus'],
      data['deleteStatus'],
    ].map((value) => (value ?? '').toString().trim().toLowerCase()).join(' ');
    return status.contains('deleted') ||
        status.contains('delete') ||
        status.contains('removed') ||
        status.contains('archived') ||
        status.contains('voided') ||
        status.contains('pending_delete');
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  Future<void> _selectPeriod(_StatsPeriod period) async {
    if (period == _StatsPeriod.custom) {
      final now = DateTime.now();
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1),
        initialDateRange: _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
        helpText: '조회 기간 선택',
        saveText: '적용',
      );
      if (selected == null || !mounted) return;
      setState(() {
        _period = period;
        _customRange = selected;
      });
    } else {
      if (_period == period) return;
      setState(() => _period = period);
    }
    await _loadStats();
  }

  Future<void> _openTierGuideSheet() async {
    final access = _tierAccess ??
        (_isPersonalWorkspace
            ? await AppTierAccessService.loadPersonalTrainerAccess(
                uid: _personalOwnerUid,
              )
            : await AppTierAccessService.loadTrainerAccess());
    if (!mounted) return;
    await AifcTierFeatureGateSheet.show(
      context: context,
      access: access,
      feature: AppTierFeatureKey.lessonInsights,
    );
  }

  String get _periodLabel {
    final range = _dateRange(DateTime.now());
    final end = range.endExclusive.subtract(const Duration(days: 1));
    return '${DateFormat('yyyy.MM.dd').format(range.start)} - '
        '${DateFormat('yyyy.MM.dd').format(end)}';
  }

  String _rateText(double? rate) =>
      rate == null ? '-' : '${rate.toStringAsFixed(1)}%';

  Future<void> _openMonthlyLessonHistory() async {
    if (!_isPersonalWorkspace || !_canUseStatsPage) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthlyLessonHistoryPage(
          personalOwnerUid: _personalOwnerUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _StatsHeader(
                title: 'MORE 인사이트',
                subtitle: '실제 레슨과 회원 데이터를 기간별로 확인해보세요',
                onBackTap: () => Navigator.of(context).maybePop(),
                trailing: _isPersonalWorkspace && _canUseStatsPage
                    ? MtfFloatingMoreMenuButton<String>(
                        items: const [
                          MtfMoreMenuItem(
                            value: 'monthly',
                            icon: Icons.calendar_month_rounded,
                            label: '월간 레슨 기록',
                            subLabel: '확정 레슨을 날짜별로 확인',
                          ),
                        ],
                        onSelected: (_) => _openMonthlyLessonHistory(),
                        tooltip: '인사이트 더보기',
                      )
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isTierAccessLoading)
                          const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _buildPeriodSelector(),
                          const SizedBox(height: 14),
                          if (_isStatsLoading)
                            const SizedBox(
                              height: 260,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_loadError != null)
                            _buildLoadError()
                          else ...[
                            _buildSummary(),
                            const SizedBox(height: 18),
                            _buildLessonSection(),
                            const SizedBox(height: 18),
                            _buildMemberSection(),
                            const SizedBox(height: 18),
                            _buildIncomeSection(),
                          ],
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isTierAccessLoading)
            Positioned.fill(
              child: Container(
                color:
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.74),
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_tierAccessFailed)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  '등급 정보를 확인하지 못했어요.\n잠시 후 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else if (blocksEntireStatsPage(
            isPersonalWorkspace: _isPersonalWorkspace,
            canUseAdvancedInsights: _canUseStatsPage,
          )) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                  child: Container(
                    color: scheme.surface.withValues(alpha: 0.04),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatsProGateChatCard(
                    currentTierLabel: _tierAccess?.tierLabel ?? 'Beginner',
                    onTap: _openTierGuideSheet,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const labels = {
      _StatsPeriod.week: '이번 주',
      _StatsPeriod.month: '이번 달',
      _StatsPeriod.threeMonths: '3개월',
      _StatsPeriod.custom: '직접 선택',
    };
    return _DashboardCard(
      title: '조회 기간',
      trailing: Text(
        _periodLabel,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _StatsPeriod.values.map((period) {
          return ChoiceChip(
            label: Text(labels[period]!),
            selected: _period == period,
            onSelected: (_) => _selectPeriod(period),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadError() {
    return _DashboardCard(
      title: '데이터를 불러오지 못했어요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('잠시 후 다시 시도해주세요.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadStats, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final stats = _stats!;
    final palette = context.mtfChartPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('요약'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _KpiCard(
              title: '완료 레슨',
              value: '${stats.completedLessons}회',
              subtitle: '선택 기간 확정 완료',
              icon: Icons.task_alt_rounded,
              colors: [palette.primarySeries, palette.tertiarySeries],
            ),
            _KpiCard(
              title: '예정 레슨',
              value: '${stats.upcomingLessons}회',
              subtitle: '현재 시각 이후 미확정',
              icon: Icons.upcoming_rounded,
              colors: [palette.secondarySeries, palette.primarySeries],
            ),
            _KpiCard(
              title: '실제 수업률',
              value: _rateText(stats.actualLessonRate),
              subtitle: '확정 결과 기준',
              icon: Icons.insights_rounded,
              colors: [palette.warningSeries, palette.tertiarySeries],
            ),
            _KpiCard(
              title: '활성 회원',
              value: '${stats.activeMembers}명',
              subtitle: '현재 회원 상태 기준',
              icon: Icons.groups_rounded,
              colors: [palette.positiveSeries, palette.secondarySeries],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLessonSection() {
    final stats = _stats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('레슨'),
        const SizedBox(height: 10),
        _DashboardCard(
          title: '레슨 결과',
          child: Column(
            children: [
              _metricRow('등록 레슨', stats.registeredLessons, '회'),
              _metricRow('완료', stats.completedLessons, '회'),
              _metricRow('노쇼 · 차감', stats.noShowDeducted, '회'),
              _metricRow('노쇼 · 미차감', stats.noShowNotDeducted, '회'),
              _metricRow('서비스', stats.serviceLessons, '회', isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DashboardCard(
          title: '요일별 등록 레슨',
          child: SizedBox(
            height: 170,
            child: _WeekdayBarChart(values: stats.weekdayCounts),
          ),
        ),
        const SizedBox(height: 12),
        _DashboardCard(
          title: '레슨 종류 비중',
          child: stats.typeCounts.isEmpty
              ? const _EmptyMetricText('선택 기간에 등록된 레슨이 없어요.')
              : _SessionTypeDonut(typeCounts: stats.typeCounts),
        ),
      ],
    );
  }

  Widget _buildMemberSection() {
    final stats = _stats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('회원'),
        const SizedBox(height: 10),
        _DashboardCard(
          title: '회원 현황',
          child: Column(
            children: [
              _metricRow('활성', stats.activeMembers, '명'),
              _metricRow('휴면', stats.dormantMembers, '명'),
              _metricRow('만료', stats.expiredMembers, '명'),
              _metricRow('기간 내 신규', stats.newMembers, '명', isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DashboardCard(
          title: '확인할 회원',
          child: Column(
            children: [
              _metricRow('잔여 5회 이하', stats.lowRemainingMembers, '명'),
              _metricRow('기간 내 회원권 만료 예정', stats.expiringMembers, '명'),
              _metricRow('14일 이상 미방문', stats.longAbsentMembers, '명',
                  isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('수입'),
        SizedBox(height: 10),
        _DashboardCard(
          title: '확정 수입',
          child: _EmptyMetricText(
            '데이터 연결 준비 중\n결제 금액과 결제일이 확인되는 실제 수납 데이터만 연결할 예정이에요.',
          ),
        ),
      ],
    );
  }

  Widget _metricRow(
    String label,
    int value,
    String unit, {
    bool isLast = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _EmptyMetricText extends StatelessWidget {
  const _EmptyMetricText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        height: 1.5,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.title,
    required this.subtitle,
    required this.onBackTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBackTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final tokens = context.mtfThemeTokens;

    return MtfHeaderNeonOverlay(
      isExpanded: false,
      intensity: 0.52,
      bottomRadius: 28,
      strokeWidth: 1.6,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + 12,
          left: 16,
          right: 16,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          color: tokens.drawerHeaderBackground,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: onBackTap,
                      borderRadius: BorderRadius.circular(999),
                      child: const Center(
                        child: Text(
                          '<',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.04),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(colors.first) == Brightness.dark
            ? Colors.white
            : const Color(0xFF0B1E32);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.86),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: foreground.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: foreground, size: 24),
          ),
        ],
      ),
    );
  }
}

class _WeekdayBarChart extends StatelessWidget {
  const _WeekdayBarChart({
    required this.values,
  });

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final maxValue = math.max(1, values.fold<int>(0, math.max));
    final palette = context.mtfChartPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final ratio = values[index] / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${values[index]}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.axisText,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 120 * ratio.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: index >= 5
                          ? palette.tertiarySeries
                          : palette.primarySeries,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.axisText,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SessionTypeDonut extends StatelessWidget {
  const _SessionTypeDonut({
    required this.typeCounts,
  });

  final Map<String, int> typeCounts;

  @override
  Widget build(BuildContext context) {
    final total = typeCounts.values.fold<int>(0, (a, b) => a + b);
    final entries = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = context.mtfChartPalette;
    final colors = palette.categoricalSeries;

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _MultiDonutPainter(
              values: entries.map((e) => e.value.toDouble()).toList(),
              colors: colors,
            ),
            child: Center(
              child: Text(
                '$total회',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (index) {
              final item = entries[index];
              final color = colors[index % colors.length];
              final rate = total == 0 ? 0 : (item.value / total) * 100;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${item.value}회 · ${rate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.axisText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MultiDonutPainter extends CustomPainter {
  const _MultiDonutPainter({
    required this.values,
    required this.colors,
  });

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;

    final stroke = 18.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    double start = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiDonutPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _StatsProGateChatCard extends StatelessWidget {
  const _StatsProGateChatCard({
    required this.currentTierLabel,
    required this.onTap,
  });

  final String currentTierLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 380,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: scheme.shadow.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AifcAvatar(
                  size: 34,
                  isAnimating: true,
                  backgroundColor: tokens.cardSurface,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                    child: Text(
                      '인사이트는 Pro부터 열려요.\n\n'
                      '현재 등급은 $currentTierLabel 입니다.\n'
                      '완료·예정 레슨, 회원 현황, 요일별 레슨 패턴처럼 실제 데이터로 확인되는 지표를 볼 수 있어요.',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsGateBenefitRow(
                    icon: Icons.trending_up_rounded,
                    text: '기간별 완료·예정 레슨 확인',
                  ),
                  SizedBox(height: 8),
                  _StatsGateBenefitRow(
                    icon: Icons.groups_rounded,
                    text: '활성·신규 회원 현황 확인',
                  ),
                  SizedBox(height: 8),
                  _StatsGateBenefitRow(
                    icon: Icons.calendar_view_week_rounded,
                    text: '요일별 레슨 패턴 분석',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  '등급 안내 보기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _StatsGateBenefitRow extends StatelessWidget {
  const _StatsGateBenefitRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 1),
        Icon(
          icon,
          size: 16,
          color: Color(0xFF4F46E5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF312E81),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
