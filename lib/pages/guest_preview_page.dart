import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_account_service.dart';
import '../services/home_guest_capabilities.dart';
import '../services/home_guest_schedule_repository.dart';
import '../widgets/aifc_toast.dart';
import '../widgets/home/sections/home_bottom_nav_bar.dart';
import '../widgets/home/sections/home_header_section.dart';
import '../widgets/home/sections/home_this_week_schedule_section.dart';
import 'email_auth_page.dart';

const _guestPrimaryColor = Color(0xFF4F46E5);
const _guestSecondaryColor = Color(0xFF9333EA);

class GuestPreviewPage extends StatefulWidget {
  const GuestPreviewPage({
    super.key,
    required this.service,
    this.scheduleRepository,
    this.capabilities = const HomeGuestCapabilities(),
  });

  final AppAccountService service;
  final GuestScheduleRepository? scheduleRepository;
  final HomeGuestCapabilities capabilities;

  @override
  State<GuestPreviewPage> createState() => _GuestPreviewPageState();
}

class _GuestPreviewPageState extends State<GuestPreviewPage> {
  static const _totalWeeks = 9;
  static const _initialWeekIndex = 4;
  static const _headerMessages = [
    '함께하길 꿈꿔요.',
    '앞으로의 재밌고 즐거운 일을 함께하고 싶어요.',
    '우리, 차근차근 같이 성장해나가요.',
    '앞으로 펼쳐질 많은 일들을 함께 만들어가요.',
    '오늘의 작은 시작도 함께할게요.',
    '조금씩, 오래 함께해나가요.',
  ];

  late final GuestScheduleRepository _repository;
  late final PageController _weekController;
  List<GuestScheduleRecord> _records = const [];
  int _weekPageIndex = _initialWeekIndex;
  int _activeNavIndex = -1;
  bool _headerExpanded = false;
  bool _showScheduleHelp = false;
  String _dayFilter = 'all';

  @override
  void initState() {
    super.initState();
    _repository = widget.scheduleRepository ??
        GuestScheduleRepository(limit: widget.capabilities.localScheduleLimit);
    _weekController = PageController(initialPage: _initialWeekIndex);
    unawaited(_reload());
  }

  @override
  void dispose() {
    AifcToast.hide();
    _weekController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final records = await _repository.load();
    if (!mounted) return;
    setState(() => _records = records);
  }

  String get _headerMessage {
    final today = DateTime.now();
    return _headerMessages[(today.day + today.month) % _headerMessages.length];
  }

  int get _todayCount {
    final now = DateTime.now();
    return _records.where((record) => _sameDate(record.startAt, now)).length;
  }

  int _indexToOffset(int index) => index - _initialWeekIndex;

  DateTime _mondayForOffset(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: offset * 7));
  }

  String _weekTitle(int offset) {
    final monday = _mondayForOffset(offset);
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('M.d').format(monday)} ~ ${DateFormat('M.d').format(sunday)} 주간 레슨일정';
  }

  Map<String, dynamic> _weekSlice(int offset) {
    final start = _mondayForOffset(offset);
    final end = start.add(const Duration(days: 7));
    return {
      for (final record in _records)
        if (!record.startAt.isBefore(start) && record.startAt.isBefore(end))
          record.guestScheduleId: record.toScheduleMap(),
    };
  }

  DateTime _cellDate(int offset, String day, String time) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final dayIndex = days.indexOf(day).clamp(0, 6);
    final parts = time.split(':');
    final base = _mondayForOffset(offset).add(Duration(days: dayIndex));
    return DateTime(
      base.year,
      base.month,
      base.day,
      int.tryParse(parts.first) ?? 9,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  Future<void> _openEditor({
    GuestScheduleRecord? record,
    DateTime? initialStartAt,
  }) async {
    if (!widget.capabilities.canCreateLocalSchedule) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GuestScheduleEditor(
        service: widget.service,
        repository: _repository,
        record: record,
        initialStartAt: initialStartAt,
      ),
    );
    await _reload();
  }

  void _showGate(String message) {
    AifcToast.show(
      context: context,
      message: message,
      duration: const Duration(milliseconds: 1800),
      bottomOffset: 104,
    );
  }

  void _showSample(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('예시'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(body, style: const TextStyle(height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }

  void _onBottomNav(int index) {
    setState(() => _activeNavIndex = index);
    switch (index) {
      case 0:
        _showSample(
          '인사이트',
          '이번 주 체험 일정의 흐름을 살펴보는 예시 화면이에요. 기록이 쌓이면 흐름도 함께 살펴볼 수 있어요.',
        );
        break;
      case 1:
        _showGate('함께 시작하면 계약서 작성도 차분하게 도와드릴게요.');
        break;
      case 2:
        _showSample(
          'MORE 포커스',
          '회원과 함께할 준비가 되면 제가 옆에서 상담 흐름과 다음 할 일을 차근차근 챙겨드릴게요.',
        );
        break;
      case 3:
        _showSample(
          '회원관리',
          '예시 회원의 레슨 흐름을 둘러보는 화면이에요. 함께하면 회원 기록도 안전하게 이어갈 수 있어요.',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekOffset = _indexToOffset(_weekPageIndex);
    return Scaffold(
      key: const Key('guest_home_scaffold'),
      backgroundColor: const Color(0xFFF3F4F6),
      endDrawer: _GuestHomeDrawer(onAction: _showGate),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeaderSection(
                      key: const Key('guest_home_header'),
                      isExpanded: _headerExpanded,
                      todayCount: _todayCount,
                      weekCount: _records.length,
                      moreSenseCount: 1,
                      aiFcHeaderNotice: _headerMessage,
                      notificationsOn: false,
                      primaryColor: _guestPrimaryColor,
                      secondaryColor: _guestSecondaryColor,
                      loadProfileFromFirestore: false,
                      profileDisplayName: '체험',
                      headerGreetingText: '우리, 같이 시작해볼까요',
                      allowGreetingEdit: false,
                      onToggleExpanded: () => setState(
                        () => _headerExpanded = !_headerExpanded,
                      ),
                      onQuickMemberTap: () => _showGate(
                        '함께하면 회원 기록도 안전하게 이어갈 수 있어요.',
                      ),
                      onNotificationTap: () => _showGate(
                        '함께하면 필요한 순간을 놓치지 않게 챙겨드릴게요.',
                      ),
                      onTodayTap: () => _showSample(
                        '오늘 일정',
                        '오늘의 체험 일정 $_todayCount개를 이 기기에서만 확인하고 있어요.',
                      ),
                      onMoreSenseTap: () => _showSample(
                        'MORE 포커스',
                        '조금씩 익숙해지면, 회원에게 필요한 관리 포인트도 함께 살펴볼 수 있어요.',
                      ),
                      onWeekTap: () => _showSample(
                        '이번 주 흐름',
                        '체험 일정 ${_records.length}개가 있어요. 실제 회원 데이터는 불러오지 않았어요.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GuestTrialNotice(
                      onAddSchedule: () {
                        final now = DateTime.now();
                        _openEditor(
                          initialStartAt: DateTime(
                            now.year,
                            now.month,
                            now.day,
                            (now.hour + 1).clamp(0, 23),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _GuestFeatureShortcuts(
                      onLessonLog: () => _showSample(
                        '레슨일지',
                        '스쿼트 자세와 무릎 정렬을 확인한 예시 기록이에요. 앞으로의 레슨 기록도 차근차근 같이 쌓아가요.',
                      ),
                      onInsights: () => _onBottomNav(0),
                      onContract: () => _showGate(
                        '함께 시작하면 계약서 작성도 차분하게 도와드릴게요.',
                      ),
                      onSignature: () => _showGate(
                        '계정을 연결하면 서명 기록도 안전하게 이어갈 수 있어요.',
                      ),
                    ),
                    const SizedBox(height: 22),
                    HomeThisWeekScheduleSection(
                      key: const Key('guest_weekly_schedule'),
                      title: _weekTitle(weekOffset),
                      dayFilter: _dayFilter,
                      showScheduleHelp: _showScheduleHelp,
                      weekPageController: _weekController,
                      totalWeeks: _totalWeeks,
                      weekPageIndex: _weekPageIndex,
                      indexToOffset: _indexToOffset,
                      timeSlots: [
                        for (var hour = 6; hour <= 22; hour++)
                          '${hour.toString().padLeft(2, '0')}:00',
                      ],
                      currentTime: DateTime.now(),
                      primaryColor: _guestPrimaryColor,
                      shouldShowScheduleExamples: (_) => false,
                      buildWeekSlice: _weekSlice,
                      buildScheduleExampleSlice: (_) => const {},
                      onToggleHelp: () => setState(
                        () => _showScheduleHelp = !_showScheduleHelp,
                      ),
                      onDayFilterChanged: (value) =>
                          setState(() => _dayFilter = value),
                      onPageChanged: (index) =>
                          setState(() => _weekPageIndex = index),
                      onWeekActionMenu: (_) async => _showGate(
                        '체험 일정은 한 번에 하나씩 차근차근 정리해볼 수 있어요.',
                      ),
                      onScheduleMoreMenu: (_) => _showGate(
                        '지금은 가볍게 둘러보고, 준비되면 같이 시작해요.',
                      ),
                      onHideScheduleExamples: () {},
                      onCellTap: (offset, day, time, _) => _openEditor(
                        initialStartAt: _cellDate(offset, day, time),
                      ),
                      onTimeHeaderTap: () => _showGate(
                        '체험 일정 시간은 각 일정에서 편하게 바꿀 수 있어요.',
                      ),
                      onTimeHeaderLongPress: () => _showGate(
                        '함께하면 스케줄표 설정도 차근차근 맞춰드릴게요.',
                      ),
                      onTimeRowLongPress: (_) => _showGate(
                        '체험 일정 시간은 각 일정에서 편하게 바꿀 수 있어요.',
                      ),
                      onEventTap: (_, session) {
                        final id =
                            (session['guestScheduleId'] ?? '').toString();
                        final record = _records
                            .where((item) => item.guestScheduleId == id)
                            .firstOrNull;
                        if (record != null) _openEditor(record: record);
                      },
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GuestMoreFocusCard(
                        onTap: () => _showSample(
                          'MORE 포커스',
                          '앞으로의 많은 일들을 차근차근 같이 해나가 봐요. 실제 회원 정보 없이 안전한 예시만 보여드리고 있어요.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -10,
                child: HomeBottomNavBar(
                  key: const Key('guest_home_bottom_nav'),
                  activeIndex: _activeNavIndex,
                  primaryColor: _guestPrimaryColor,
                  secondaryColor: _guestSecondaryColor,
                  onChanged: _onBottomNav,
                  onCenterTap: () => _showGate(
                    '함께하면 회원 기록도 안전하게 이어갈 수 있어요.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _GuestTrialNotice extends StatelessWidget {
  const _GuestTrialNotice({required this.onAddSchedule});

  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          key: const Key('guest_local_only_notice'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 17, color: Color(0xFF6D28D9)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '체험 중 · 일정은 이 기기에만 저장돼요',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                key: const Key('guest_add_schedule_button'),
                onPressed: onAddSchedule,
                child: const Text('일정 추가'),
              ),
            ],
          ),
        ),
      );
}

class _GuestFeatureShortcuts extends StatelessWidget {
  const _GuestFeatureShortcuts({
    required this.onLessonLog,
    required this.onInsights,
    required this.onContract,
    required this.onSignature,
  });

  final VoidCallback onLessonLog;
  final VoidCallback onInsights;
  final VoidCallback onContract;
  final VoidCallback onSignature;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.note_alt_outlined, size: 18),
              label: const Text('레슨일지'),
              onPressed: onLessonLog,
            ),
            ActionChip(
              avatar: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('인사이트'),
              onPressed: onInsights,
            ),
            ActionChip(
              avatar: const Icon(Icons.description_outlined, size: 18),
              label: const Text('계약서'),
              onPressed: onContract,
            ),
            ActionChip(
              avatar: const Icon(Icons.draw_outlined, size: 18),
              label: const Text('서명'),
              onPressed: onSignature,
            ),
          ],
        ),
      );
}

class _GuestMoreFocusCard extends StatelessWidget {
  const _GuestMoreFocusCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
          title: const Text(
            'MORE 포커스',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('함께 성장할 다음 흐름을 예시로 살펴보세요.'),
          trailing: const Chip(label: Text('체험')),
        ),
      );
}

class _GuestHomeDrawer extends StatelessWidget {
  const _GuestHomeDrawer({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (
        Icons.person_add_alt_1_rounded,
        '빠른 회원등록',
        '함께하면 회원 기록도 안전하게 이어갈 수 있어요.'
      ),
      (Icons.description_outlined, '빠른 계약등록', '함께 시작하면 계약서 작성도 차분하게 도와드릴게요.'),
      (Icons.task_alt_rounded, '레슨 확정', '앞으로의 레슨 기록도 차근차근 같이 쌓아가요.'),
      (Icons.notifications_outlined, '알림', '함께하면 필요한 순간을 놓치지 않게 챙겨드릴게요.'),
      (Icons.widgets_outlined, '홈 위젯', '함께하면 필요한 순간을 놓치지 않게 챙겨드릴게요.'),
      (Icons.settings_outlined, '설정', '지금은 가볍게 둘러보고, 준비되면 같이 시작해요.'),
    ];
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title:
                  Text('MORE', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('모든 동선을 가볍게 체험해보세요.'),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.$1),
                title: Text(item.$2),
                onTap: () {
                  Navigator.of(context).pop();
                  onAction(item.$3);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GuestScheduleEditor extends StatefulWidget {
  const _GuestScheduleEditor({
    required this.service,
    required this.repository,
    this.record,
    this.initialStartAt,
  });

  final AppAccountService service;
  final GuestScheduleRepository repository;
  final GuestScheduleRecord? record;
  final DateTime? initialStartAt;

  @override
  State<_GuestScheduleEditor> createState() => _GuestScheduleEditorState();
}

class _GuestScheduleEditorState extends State<_GuestScheduleEditor> {
  static const _colors = [
    '#4F46E5',
    '#7C3AED',
    '#2563EB',
    '#0F766E',
    '#16A34A',
    '#F97316',
    '#DB2777',
  ];
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _lessonType;
  late String _colorHex;
  bool _saving = false;
  bool _limitReached = false;

  @override
  void initState() {
    super.initState();
    final start =
        widget.record?.startAt ?? widget.initialStartAt ?? DateTime.now();
    final end = widget.record?.endAt ?? start.add(const Duration(minutes: 50));
    _date = DateTime(start.year, start.month, start.day);
    _startTime = TimeOfDay.fromDateTime(start);
    _endTime = TimeOfDay.fromDateTime(end);
    _lessonType = widget.record?.lessonType ?? 'PT';
    _colorHex = widget.record?.colorHex ?? _colors.first;
    _nameController.text = widget.record?.nameOrAlias ?? '';
    _memoController.text = widget.record?.memo ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameController.text.trim().isEmpty) {
      AifcToast.show(context: context, message: '이름이나 별칭을 입력해주세요.');
      return;
    }
    final startAt = _dateTime(_startTime);
    var endAt = _dateTime(_endTime);
    if (!endAt.isAfter(startAt)) endAt = endAt.add(const Duration(days: 1));
    setState(() => _saving = true);
    final result = await widget.repository.save(
      guestScheduleId: widget.record?.guestScheduleId,
      nameOrAlias: _nameController.text,
      lessonType: _lessonType,
      startAt: startAt,
      endAt: endAt,
      memo: _memoController.text,
      colorHex: _colorHex,
    );
    if (!mounted) return;
    if (result.status == GuestScheduleSaveStatus.limitReached) {
      setState(() {
        _saving = false;
        _limitReached = true;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.record?.guestScheduleId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    await widget.repository.delete(id);
    if (mounted) Navigator.of(context).pop();
  }

  DateTime _dateTime(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime(bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
    });
  }

  Future<void> _connectAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmailAuthPage(service: widget.service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.record == null ? '체험 일정 등록' : '체험 일정 수정',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  '체험 중에는 실제 이름 대신 별칭을 사용해도 좋아요.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _lessonType,
                  decoration: const InputDecoration(labelText: '레슨 종류'),
                  items: const ['PT', '필라테스', '그룹', '요가']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _lessonType = value ?? 'PT'),
                ),
                TextField(
                  key: const Key('guest_schedule_alias'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '이름 또는 별칭'),
                ),
                TextField(
                  key: const Key('guest_schedule_memo'),
                  controller: _memoController,
                  decoration: const InputDecoration(labelText: '간단한 메모'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _pickDate,
                        child: Text(DateFormat('yyyy.MM.dd').format(_date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _pickTime(true),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _pickTime(false),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color in _colors)
                      ChoiceChip(
                        label: const SizedBox(width: 10),
                        selected: _colorHex == color,
                        avatar: CircleAvatar(backgroundColor: _hexColor(color)),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _colorHex = color),
                      ),
                  ],
                ),
                if (_limitReached) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const Key('guest_schedule_limit_message'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '체험 일정 5개를 모두 사용했어요.\n\n계정을 연결하면 일정과 회원 기록을\n안전하게 저장하고 계속 이어갈 수 있어요.',
                      style:
                          TextStyle(height: 1.45, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('guest_schedule_connect_account'),
                    onPressed: _connectAccount,
                    child: const Text('계정 연결'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _limitReached = false),
                    child: const Text('조금 더 둘러보기'),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.record != null)
                      TextButton(
                        key: const Key('delete_guest_schedule'),
                        onPressed: _saving ? null : _delete,
                        child: const Text('삭제'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('save_guest_schedule'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '저장 중' : '저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _hexColor(String value) {
    final parsed = int.parse(value.replaceFirst('#', 'FF'), radix: 16);
    return Color(parsed);
  }
}
