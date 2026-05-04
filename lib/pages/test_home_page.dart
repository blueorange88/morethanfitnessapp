import 'package:flutter/material.dart';

/// =========================================================
/// Dark / Premium / Focused Weekly Timetable (7-day)
/// - Sticky top header (days)
/// - Sticky left time column
/// - Horizontal scroll for 7 days (keeps columns readable)
/// - Vertical scroll for time range
/// - Occupancy strip (day load bar)
/// - Fast actions: tap empty cell -> quick add, tap session -> detail sheet
/// =========================================================

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  // ----- Theme tokens (premium dark) -----
  static const _bg = Color(0xFF0B0F17);
  static const _surface = Color(0xFF111827);
  static const _surface2 = Color(0xFF0F172A);
  static const _stroke = Color(0xFF1F2937);
  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);
  static const _muted2 = Color(0xFF6B7280);

  static const _accent = Color(0xFF7C3AED); // purple
  static const _accent2 = Color(0xFF22C55E); // green

  // session colors by type
  static const _cPt = Color(0xFF7C3AED); // PT
  static const _cGroup = Color(0xFF2563EB); // Group
  static const _cConsult = Color(0xFFF59E0B); // Consult
  static const _cOt = Color(0xFF22C55E); // OT
  static const _cBlock = Color(0xFF374151); // Blocked

  // ----- Timetable settings -----
  int _weekOffset = 0; // 0 this week
  int _startHour = 6;
  int _endHour = 22; // inclusive end hour for labels, grid uses slots count
  bool _compact = true; // density toggle
  String _typeFilter = 'ALL'; // ALL/PT/GROUP/CONSULT/OT/BLOCK

  final List<String> _days = const ["월", "화", "수", "목", "금", "토", "일"];

  // Scroll controllers (shared)
  final ScrollController _hCtrl = ScrollController(); // horizontal (days)
  final ScrollController _vCtrl = ScrollController(); // vertical (times)

  // ----- Data model (in-memory for test) -----
  // key: "$weekOffset-$dayIndex-$slotIndex"
  final Map<String, Session> _sessions = {};

  @override
  void initState() {
    super.initState();
    _seedSample();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  void _seedSample() {
    // Simple sample: create some sessions this week
    _put(0, 0, 3, Session(name: "홍길동", type: SessionType.pt));      // Mon 09:00
    _put(0, 1, 6, Session(name: "Mina", type: SessionType.group));    // Tue 12:00
    _put(0, 2, 5, Session(name: "상담-김", type: SessionType.consult));// Wed 11:00
    _put(0, 3, 8, Session(name: "OT-박", type: SessionType.ot));      // Thu 14:00
    _put(0, 4, 2, Session(name: "세이노", type: SessionType.pt));     // Fri 08:00
    _put(0, 5, 4, Session(name: "그룹 A", type: SessionType.group));  // Sat 10:00
    _put(0, 6, 1, Session(name: "휴무", type: SessionType.block));    // Sun 07:00
  }

  void _put(int weekOffset, int dayIndex, int slotIndex, Session s) {
    _sessions["$weekOffset-$dayIndex-$slotIndex"] = s;
  }

  Session? _get(int weekOffset, int dayIndex, int slotIndex) {
    return _sessions["$weekOffset-$dayIndex-$slotIndex"];
  }

  void _remove(int weekOffset, int dayIndex, int slotIndex) {
    _sessions.remove("$weekOffset-$dayIndex-$slotIndex");
  }

  int get _slotCount => (_endHour - _startHour + 1); // labels per hour
  double get _rowH => _compact ? 30 : 40;
  double get _timeColW => 60;
  double get _dayColW => 84; // keep readable on mobile

  DateTime _mondayForOffset(int offset) {
    final now = DateTime.now();
    final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
    return mondayThisWeek.add(Duration(days: 7 * offset));
  }

  String _weekLabel() {
    final monday = _mondayForOffset(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    String fmt(DateTime d) => "${d.month}.${d.day.toString().padLeft(2, '0')}";
    if (_weekOffset == 0) return "이번 주  ${fmt(monday)} - ${fmt(sunday)}";
    if (_weekOffset == -1) return "지난 주  ${fmt(monday)} - ${fmt(sunday)}";
    if (_weekOffset == 1) return "다음 주  ${fmt(monday)} - ${fmt(sunday)}";
    final sign = _weekOffset > 0 ? "+$_weekOffset" : "$_weekOffset";
    return "주 $sign  ${fmt(monday)} - ${fmt(sunday)}";
  }

  Color _colorForType(SessionType t) {
    switch (t) {
      case SessionType.pt:
        return _cPt;
      case SessionType.group:
        return _cGroup;
      case SessionType.consult:
        return _cConsult;
      case SessionType.ot:
        return _cOt;
      case SessionType.block:
        return _cBlock;
    }
  }

  bool _passesFilter(Session s) {
    if (_typeFilter == 'ALL') return true;
    switch (_typeFilter) {
      case 'PT':
        return s.type == SessionType.pt;
      case 'GROUP':
        return s.type == SessionType.group;
      case 'CONSULT':
        return s.type == SessionType.consult;
      case 'OT':
        return s.type == SessionType.ot;
      case 'BLOCK':
        return s.type == SessionType.block;
      default:
        return true;
    }
  }

  // Day occupancy 0..1
  double _dayLoad(int dayIndex) {
    int total = _slotCount;
    int used = 0;
    for (int si = 0; si < _slotCount; si++) {
      final s = _get(_weekOffset, dayIndex, si);
      if (s != null && _passesFilter(s)) used++;
    }
    return total == 0 ? 0 : used / total;
  }

  Future<void> _quickAdd(int dayIndex, int slotIndex) async {
    final hour = _startHour + slotIndex;
    final timeLabel = "${hour.toString().padLeft(2, '0')}:00";
    SessionType selectedType = SessionType.pt;
    final nameCtrl = TextEditingController();

    final result = await showModalBottomSheet<_QuickAddResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${_days[dayIndex]} · $timeLabel  빠른 등록",
                          style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: _muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _TypeChipsDark(
                    value: selectedType,
                    onChanged: (t) => setModal(() => selectedType = t),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: _text),
                    decoration: InputDecoration(
                      hintText: "이름/메모 (예: 홍길동, 그룹A, 휴무)",
                      hintStyle: const TextStyle(color: _muted2),
                      filled: true,
                      fillColor: _surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _stroke.withOpacity(0.9)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _stroke.withOpacity(0.9)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _accent, width: 1.2),
                      ),
                      prefixIcon: const Icon(Icons.person_outline, color: _muted),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _text,
                            side: BorderSide(color: _stroke.withOpacity(0.9)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(
                              ctx,
                              _QuickAddResult(delete: true),
                            );
                          },
                          child: const Text("비우기"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(
                              ctx,
                              _QuickAddResult(
                                session: Session(name: name, type: selectedType),
                              ),
                            );
                          },
                          child: const Text("저장"),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    nameCtrl.dispose();

    if (!mounted || result == null) return;

    setState(() {
      if (result.delete) {
        _remove(_weekOffset, dayIndex, slotIndex);
      } else if (result.session != null) {
        _put(_weekOffset, dayIndex, slotIndex, result.session!);
      }
    });
  }

  void _openSessionDetail(int dayIndex, int slotIndex, Session session) {
    final hour = _startHour + slotIndex;
    final timeLabel = "${hour.toString().padLeft(2, '0')}:00";
    final typeText = session.type.name.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colorForType(session.type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${_days[dayIndex]} · $timeLabel",
                      style: const TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _stroke.withOpacity(0.9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "TYPE · $typeText",
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        side: BorderSide(color: _stroke.withOpacity(0.9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _quickAdd(dayIndex, slotIndex);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text("수정"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent2,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("완료 처리(출석) - 테스트")),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("완료"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
                  onPressed: () {
                    setState(() => _remove(_weekOffset, dayIndex, slotIndex));
                    Navigator.pop(ctx);
                  },
                  child: const Text("삭제"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          surface: _surface,
          primary: _accent,
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: _weekLabel(),
                compact: _compact,
                filter: _typeFilter,
                onPrevWeek: () => setState(() => _weekOffset--),
                onNextWeek: () => setState(() => _weekOffset++),
                onToggleDensity: () => setState(() => _compact = !_compact),
                onChangeFilter: (v) => setState(() => _typeFilter = v),
                onSearch: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("검색(회원/세션) - 테스트")),
                  );
                },
                onAdd: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("+ 추가 - 시간표에서 빈칸 탭으로 등록 추천")),
                  );
                },
              ),
              const SizedBox(height: 8),
              _OccupancyStrip(
                days: _days,
                load: (i) => _dayLoad(i),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildTimetable()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimetable() {
    final today = DateTime.now().weekday - 1; // 0..6 (Mon..Sun)

    // Sticky header heights
    const double headerH = 42;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke.withOpacity(0.9)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Scrollable content (both directions)
              Positioned.fill(
                top: headerH,
                left: _timeColW,
                child: Scrollbar(
                  controller: _vCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vCtrl,
                    child: SingleChildScrollView(
                      controller: _hCtrl,
                      scrollDirection: Axis.horizontal,
                      child: _GridBody(
                        days: _days,
                        dayColW: _dayColW,
                        rowH: _rowH,
                        startHour: _startHour,
                        slotCount: _slotCount,
                        todayIndex: today,
                        cellBuilder: (dayIndex, slotIndex) {
                          final s = _get(_weekOffset, dayIndex, slotIndex);
                          if (s == null) {
                            return _GridCell.empty(
                              rowH: _rowH,
                              dayColW: _dayColW,
                              today: dayIndex == today,
                              onTap: () => _quickAdd(dayIndex, slotIndex),
                            );
                          }

                          // Filter effect: dim others
                          final pass = _passesFilter(s);
                          return _GridCell.session(
                            rowH: _rowH,
                            dayColW: _dayColW,
                            today: dayIndex == today,
                            color: _colorForType(s.type),
                            name: s.name,
                            dim: !pass,
                            onTap: () => _openSessionDetail(dayIndex, slotIndex, s),
                            onLongPress: () {
                              // You can later replace this with drag-to-move.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("롱프레스: 드래그 이동(추후)")),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Sticky top header (days)
              Positioned(
                top: 0,
                left: _timeColW,
                right: 0,
                height: headerH,
                child: SingleChildScrollView(
                  controller: _hCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: List.generate(_days.length, (i) {
                      final isToday = i == today;
                      return Container(
                        width: _dayColW,
                        height: headerH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _surface2,
                          border: Border(
                            right: BorderSide(color: _stroke.withOpacity(0.9)),
                            bottom: BorderSide(color: _stroke.withOpacity(0.9)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _days[i],
                              style: TextStyle(
                                color: isToday ? _text : _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _accent2,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Sticky top-left corner cell
              Positioned(
                top: 0,
                left: 0,
                width: _timeColW,
                height: headerH,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _surface2,
                    border: Border(
                      right: BorderSide(color: _stroke.withOpacity(0.9)),
                      bottom: BorderSide(color: _stroke.withOpacity(0.9)),
                    ),
                  ),
                  child: const Text(
                    "TIME",
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // Sticky left time column (scrolls vertically)
              Positioned(
                top: headerH,
                left: 0,
                width: _timeColW,
                bottom: 0,
                child: SingleChildScrollView(
                  controller: _vCtrl,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: List.generate(_slotCount, (si) {
                      final hour = _startHour + si;
                      final label = "${hour.toString().padLeft(2, '0')}:00";
                      return Container(
                        width: _timeColW,
                        height: _rowH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _surface2,
                          border: Border(
                            right: BorderSide(color: _stroke.withOpacity(0.9)),
                            bottom: BorderSide(color: _stroke.withOpacity(0.65)),
                          ),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== Components =====

class _TopBar extends StatelessWidget {
  final String title;
  final bool compact;
  final String filter;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToggleDensity;
  final ValueChanged<String> onChangeFilter;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  const _TopBar({
    required this.title,
    required this.compact,
    required this.filter,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onToggleDensity,
    required this.onChangeFilter,
    required this.onSearch,
    required this.onAdd,
  });

  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);
  static const _surface = Color(0xFF111827);
  static const _stroke = Color(0xFF1F2937);
  static const _accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke.withOpacity(0.9)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onPrevWeek,
                  icon: const Icon(Icons.chevron_left, color: _muted),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onNextWeek,
                  icon: const Icon(Icons.chevron_right, color: _muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PillButton(
                  icon: compact ? Icons.view_agenda_outlined : Icons.view_day_outlined,
                  label: compact ? "컴팩트" : "표준",
                  onTap: onToggleDensity,
                ),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: filter,
                  onChanged: onChangeFilter,
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, color: _muted),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline, color: _accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);
  static const _surface2 = Color(0xFF0F172A);
  static const _stroke = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _stroke.withOpacity(0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);
  static const _surface2 = Color(0xFF0F172A);
  static const _stroke = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke.withOpacity(0.9)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: _surface2,
          value: value,
          icon: const Icon(Icons.expand_more, color: _muted),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text("전체")),
            DropdownMenuItem(value: 'PT', child: Text("PT")),
            DropdownMenuItem(value: 'GROUP', child: Text("그룹")),
            DropdownMenuItem(value: 'CONSULT', child: Text("상담")),
            DropdownMenuItem(value: 'OT', child: Text("OT")),
            DropdownMenuItem(value: 'BLOCK', child: Text("차단")),
          ],
          onChanged: (v) => onChanged(v ?? 'ALL'),
          style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _OccupancyStrip extends StatelessWidget {
  final List<String> days;
  final double Function(int dayIndex) load;

  const _OccupancyStrip({required this.days, required this.load});

  static const _surface = Color(0xFF111827);
  static const _stroke = Color(0xFF1F2937);
  static const _muted = Color(0xFF9CA3AF);
  static const _text = Color(0xFFE5E7EB);
  static const _accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke.withOpacity(0.9)),
        ),
        child: Row(
          children: List.generate(days.length, (i) {
            final v = load(i).clamp(0.0, 1.0);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days[i],
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF0F172A),
                        valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${(v * 100).round()}%",
                      style: const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GridBody extends StatelessWidget {
  final List<String> days;
  final double dayColW;
  final double rowH;
  final int startHour;
  final int slotCount;
  final int todayIndex;
  final Widget Function(int dayIndex, int slotIndex) cellBuilder;

  const _GridBody({
    required this.days,
    required this.dayColW,
    required this.rowH,
    required this.startHour,
    required this.slotCount,
    required this.todayIndex,
    required this.cellBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(slotCount, (slotIndex) {
        return Row(
          children: List.generate(days.length, (dayIndex) {
            return cellBuilder(dayIndex, slotIndex);
          }),
        );
      }),
    );
  }
}

class _GridCell extends StatelessWidget {
  final double rowH;
  final double dayColW;
  final bool today;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  final bool hasSession;
  final String? name;
  final Color? color;
  final bool dim;

  const _GridCell._({
    required this.rowH,
    required this.dayColW,
    required this.today,
    required this.onTap,
    this.onLongPress,
    required this.hasSession,
    this.name,
    this.color,
    required this.dim,
  });

  static const _surface = Color(0xFF111827);
  static const _surface2 = Color(0xFF0F172A);
  static const _stroke = Color(0xFF1F2937);
  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);

  factory _GridCell.empty({
    required double rowH,
    required double dayColW,
    required bool today,
    required VoidCallback onTap,
  }) {
    return _GridCell._(
      rowH: rowH,
      dayColW: dayColW,
      today: today,
      onTap: onTap,
      hasSession: false,
      dim: false,
    );
  }

  factory _GridCell.session({
    required double rowH,
    required double dayColW,
    required bool today,
    required Color color,
    required String name,
    required bool dim,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return _GridCell._(
      rowH: rowH,
      dayColW: dayColW,
      today: today,
      onTap: onTap,
      onLongPress: onLongPress,
      hasSession: true,
      name: name,
      color: color,
      dim: dim,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBg = today ? _surface2.withOpacity(0.35) : _surface;
    final border = Border(
      right: BorderSide(color: _stroke.withOpacity(0.9)),
      bottom: BorderSide(color: _stroke.withOpacity(0.65)),
    );

    if (!hasSession) {
      return InkWell(
        onTap: onTap,
        child: Container(
          width: dayColW,
          height: rowH,
          decoration: BoxDecoration(color: baseBg, border: border),
          child: const Center(
            child: Icon(Icons.add, size: 14, color: _muted),
          ),
        ),
      );
    }

    final c = color ?? _muted;
    final opacity = dim ? 0.22 : 1.0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: dayColW,
        height: rowH,
        decoration: BoxDecoration(color: baseBg, border: border),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Container(
          decoration: BoxDecoration(
            color: c.withOpacity(0.18 * opacity + 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(0.6 * opacity + 0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            name ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text.withOpacity(dim ? 0.35 : 1.0),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChipsDark extends StatelessWidget {
  final SessionType value;
  final ValueChanged<SessionType> onChanged;

  const _TypeChipsDark({required this.value, required this.onChanged});

  static const _text = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF9CA3AF);
  static const _surface2 = Color(0xFF0F172A);
  static const _stroke = Color(0xFF1F2937);

  Color _color(SessionType t) {
    switch (t) {
      case SessionType.pt:
        return const Color(0xFF7C3AED);
      case SessionType.group:
        return const Color(0xFF2563EB);
      case SessionType.consult:
        return const Color(0xFFF59E0B);
      case SessionType.ot:
        return const Color(0xFF22C55E);
      case SessionType.block:
        return const Color(0xFF374151);
    }
  }

  String _label(SessionType t) {
    switch (t) {
      case SessionType.pt:
        return "PT";
      case SessionType.group:
        return "그룹";
      case SessionType.consult:
        return "상담";
      case SessionType.ot:
        return "OT";
      case SessionType.block:
        return "차단";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SessionType.values.map((t) {
        final selected = value == t;
        final c = _color(t);
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.withOpacity(0.22) : _surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? c.withOpacity(0.8) : _stroke.withOpacity(0.9),
              ),
            ),
            child: Text(
              _label(t),
              style: TextStyle(
                color: selected ? _text : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// ===== Simple data classes =====

enum SessionType { pt, group, consult, ot, block }

class Session {
  final String name;
  final SessionType type;

  const Session({required this.name, required this.type});
}

class _QuickAddResult {
  final Session? session;
  final bool delete;

  const _QuickAddResult({this.session, this.delete = false});
}