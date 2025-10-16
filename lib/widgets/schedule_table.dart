// lib/widgets/schedule_table.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';

/// ==== 데이터 모델 ====
class ScheduleCellData {
  final String time; // '09:00'
  final int di; // 1~7 (월~일)
  final String name;
  final int enrolled;
  final int cap;

  ScheduleCellData({
    required this.time,
    required this.di,
    required this.name,
    required this.enrolled,
    required this.cap,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'di': di,
    'name': name,
    'enrolled': enrolled,
    'cap': cap,
  };

  factory ScheduleCellData.fromJson(Map<String, dynamic> j) => ScheduleCellData(
    time: j['time'] as String,
    di: (j['di'] as num).toInt(),
    name: (j['name'] as String?) ?? '',
    enrolled: (j['enrolled'] as num?)?.toInt() ?? 0,
    cap: (j['cap'] as num?)?.toInt() ?? 0,
  );
}

/// ==== 위젯 ====
class ScheduleTable extends StatefulWidget {
  final int weekOffset;
  final VoidCallback? onChanged;

  const ScheduleTable({
    super.key,
    required this.weekOffset,
    this.onChanged,
  });

  @override
  State<ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  // SharedPreferences 키
  String get _spDataKey => 'scheduleData_${widget.weekOffset}';
  static const _spRangeKey = 'scheduleRange'; // {start,end}
  static const _spMinuteMapKey = 'minuteMap'; // {"06":0,"07":30,...}

  // 상태
  int _startHour = 6; // inclusive
  int _endHour = 21; // inclusive (아래 _hourRows에서 <= 처리)
  final Map<String, int> _minuteByHour = {}; // "06" -> 0/10/20/30/40/50
  final Map<String, ScheduleCellData> _cells = {}; // 'di|time' -> data
  final Set<String> _conflicts = <String>{}; // ⬅️ 충돌 표시용

  Timer? _ticker; // 타임라인 갱신용

  @override
  void initState() {
    super.initState();
    _loadAll();
    // 현재시간 타임라인 갱신(1분마다)
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ScheduleTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 주간 바뀌면 해당 주의 데이터 로드
    if (oldWidget.weekOffset != widget.weekOffset) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ===== 로드/저장 =====
  Future<void> _loadAll() async {
    final sp = await SharedPreferences.getInstance();

    // 시간 범위
    final rangeRaw = sp.getString(_spRangeKey);
    if (rangeRaw != null && rangeRaw.isNotEmpty) {
      try {
        final m = jsonDecode(rangeRaw) as Map<String, dynamic>;
        final s = (m['start'] as num?)?.toInt();
        final e = (m['end'] as num?)?.toInt();
        if (s != null && e != null && e > s && e - s >= 3 && e - s <= 24) {
          _startHour = s;
          _endHour = e;
        }
      } catch (_) {}
    }

    // 분 매핑
    final minuteRaw = sp.getString(_spMinuteMapKey);
    if (minuteRaw != null && minuteRaw.isNotEmpty) {
      try {
        final m = jsonDecode(minuteRaw) as Map<String, dynamic>;
        _minuteByHour
          ..clear()
          ..addEntries(
            m.entries.map((e) => MapEntry(e.key, (e.value as num).toInt())),
          );
      } catch (_) {}
    }

    // 셀 데이터
    final dataRaw = sp.getString(_spDataKey);
    _cells.clear();
    _conflicts.clear();
    if (dataRaw != null && dataRaw.isNotEmpty) {
      try {
        final list = (jsonDecode(dataRaw) as List)
            .map((e) => ScheduleCellData.fromJson(e as Map<String, dynamic>));
        _cells.addEntries(list.map((d) => MapEntry('${d.di}|${d.time}', d)));
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveCells() async {
    final sp = await SharedPreferences.getInstance();
    final list = _cells.values.map((e) => e.toJson()).toList();
    await sp.setString(_spDataKey, jsonEncode(list));
  }

  Future<void> _saveRange() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_spRangeKey, jsonEncode({'start': _startHour, 'end': _endHour}));
  }

  Future<void> _saveMinuteMap() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_spMinuteMapKey, jsonEncode(_minuteByHour));
  }

  // ===== 유틸 =====
  // 시간 목록 만들기 (끝 시간 포함!)
  List<String> _hourRows() {
    final out = <String>[];
    for (int h = _startHour; h <= _endHour; h++) {
      final hh = h.toString().padLeft(2, '0');
      final mm = (_minuteByHour[hh] ?? 0).toString().padLeft(2, '0');
      out.add('$hh:$mm');
    }
    return out;
  }

  String _weekdayLabel(int di) => const ['월', '화', '수', '목', '금', '토', '일'][di - 1];

  Color _colorFor(String name) {
    if (name.isEmpty) return Colors.transparent;
    int hash = 0;
    for (final r in name.runes) {
      hash = (hash * 31 + r) & 0x7fffffff;
    }
    final base = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.deepPurple,
      Colors.cyan,
      Colors.amber,
      Colors.red,
    ][hash % 10];
    return base.withOpacity(.85);
  }

  bool _isTodayColumn(int di) {
    if (widget.weekOffset != 0) return false;
    return DateTime.now().weekday == di;
  }

  String _koreanHour(String hh) {
    final h = int.tryParse(hh) ?? 0;
    final isAM = h < 12;
    final h12 = ((h % 12) == 0) ? 12 : (h % 12);
    return '${isAM ? '오전' : '오후'} $h12시';
  }

  // ===== 시간 범위 설정 (헤더 '시간' 클릭) =====
  Future<void> _openRangeDialog() async {
    int s = _startHour, e = _endHour;
    final hours = List.generate(24, (i) => i);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시간 범위 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Text('시작  '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: s,
                items: hours
                    .map((h) => DropdownMenuItem(
                  value: h,
                  child: Text('${h.toString().padLeft(2, '0')}:00'),
                ))
                    .toList(),
                onChanged: (v) => setState(() => s = v ?? s),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('종료  '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: e,
                items: hours
                    .map((h) => DropdownMenuItem(
                  value: h,
                  child: Text('${h.toString().padLeft(2, '0')}:00'),
                ))
                    .toList(),
                onChanged: (v) => setState(() => e = v ?? e),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('※ 최소 3시간, 시작 < 종료 (같은 날 기준)', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('적용')),
        ],
      ),
    );

    if (ok != true) return;

    if (e <= s || (e - s) < 3 || (e - s) > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 올바르지 않습니다. (최소 3시간, 시작<종료)')),
      );
      return;
    }

    setState(() {
      _startHour = s;
      _endHour = e;
    });
    await _saveRange();
    widget.onChanged?.call();
  }

  // ===== 분 단위 설정 (왼쪽 시간칸 클릭) =====
  Future<void> _editMinuteForHour(String hh) async {
    final options = const [0, 10, 20, 30, 40, 50];
    int selected = _minuteByHour[hh] ?? 0;

    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('분 단위 설정 · ${_koreanHour(hh)}'),
        children: options
            .map((m) => RadioListTile<int>(
          value: m,
          groupValue: selected,
          onChanged: (v) => Navigator.pop(ctx, v),
          title: Text(m.toString().padLeft(2, '0')),
        ))
            .toList(),
      ),
    );

    if (res == null) return;

    final oldTime = '$hh:${(_minuteByHour[hh] ?? 0).toString().padLeft(2, '0')}';
    final newTime = '$hh:${res.toString().padLeft(2, '0')}';

    // 시간 문자열 치환
    final newMap = <String, ScheduleCellData>{};
    _cells.forEach((k, v) {
      if (v.time == oldTime) {
        final nv = ScheduleCellData(
          time: newTime,
          di: v.di,
          name: v.name,
          enrolled: v.enrolled,
          cap: v.cap,
        );
        newMap['${nv.di}|${nv.time}'] = nv;
      } else {
        newMap[k] = v;
      }
    });

    setState(() {
      _minuteByHour[hh] = res;
      _cells
        ..clear()
        ..addAll(newMap);
      // 시간 변경되면 충돌키도 새 키로 이관
      final toAdd = <String>{};
      final toDel = <String>{};
      for (final k in _conflicts) {
        if (k.contains(oldTime)) {
          toDel.add(k);
          toAdd.add(k.replaceAll(oldTime, newTime));
        }
      }
      _conflicts.removeAll(toDel);
      _conflicts.addAll(toAdd);
    });

    await _saveMinuteMap();
    await _saveCells();
    widget.onChanged?.call();
  }

  // ===== 셀 입력 다이얼로그 (다중 요일 선택 포함) =====
  Future<void> _openCellEditor(String time, int di) async {
    final prev = _cells['$di|$time'];

    final nameC = TextEditingController(text: prev?.name ?? '');
    final enC = TextEditingController(text: prev?.enrolled.toString() ?? '');
    final capC = TextEditingController(text: prev?.cap.toString() ?? '');
    final memberIdC = TextEditingController(); // 검색창 느낌(추가 예정)
    final Set<int> selectedDays = {di};

    final res = await showDialog<_EditResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text('레슨 입력 · ${_weekdayLabel(di)} $time'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (i) {
                        final d = i + 1;
                        final selected = selectedDays.contains(d);
                        return FilterChip(
                          label: Text(_weekdayLabel(d)),
                          selected: selected,
                          onSelected: (_) {
                            setStateDialog(() {
                              if (selected) {
                                selectedDays.remove(d);
                                if (selectedDays.isEmpty) selectedDays.add(d);
                              } else {
                                selectedDays.add(d);
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: '회원 이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: enC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '회차',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: capC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '총',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: memberIdC,
                      readOnly: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('회원 검색/선택 기능은 추가 예정입니다.')),
                        );
                      },
                      decoration: const InputDecoration(
                        labelText: '회원ID(전화, 선택)',
                        hintText: 'ID나 전화번호로 검색 (추가 예정)',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (prev != null)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, const _EditResult.delete()),
                    child: const Text('삭제'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, const _EditResult.cancel()),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameC.text.trim();
                    final en = int.tryParse(enC.text) ?? 0;
                    final cap = int.tryParse(capC.text) ?? 0;
                    if (name.isEmpty && en == 0 && cap == 0) {
                      Navigator.pop(ctx, const _EditResult.cancel());
                      return;
                    }
                    Navigator.pop(
                      ctx,
                      _EditResult.save(
                        ScheduleCellData(
                          time: time,
                          di: di, // 저장 시 selectedDays로 반영
                          name: name,
                          enrolled: en,
                          cap: cap,
                        ),
                      ),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || res == null || res.isCancel) return;

    // 삭제
    if (res.isDelete) {
      setState(() {
        for (final d in selectedDays) {
          _cells.remove('$d|$time');
          _conflicts.remove('$d|$time');
        }
      });
      await _saveCells();
      widget.onChanged?.call();
      return;
    }

    // 저장: 선택된 요일 모두 반영 (+충돌 마킹)
    final data = res.data!;
    final List<String> newlyConflicted = [];

    setState(() {
      for (final d in selectedDays) {
        final key = '$d|$time';
        final existed = _cells[key];

        final isOverwrite = existed != null && (
            existed.name != data.name ||
                existed.enrolled != data.enrolled ||
                existed.cap != data.cap
        );

        final logicalError = (data.cap > 0 && data.enrolled > data.cap);

        _cells[key] = ScheduleCellData(
          time: time,
          di: d,
          name: data.name,
          enrolled: data.enrolled,
          cap: data.cap,
        );

        if (isOverwrite || logicalError) {
          _conflicts.add(key);
          newlyConflicted.add(key);
        } else {
          _conflicts.remove(key);
        }
      }
    });

    if (newlyConflicted.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일부 칸이 충돌 상태입니다(빨간 테두리). 확인해주세요.')),
      );
    }

    await _saveCells();
    widget.onChanged?.call();
  }

  // ===== 롱프레스 퀵액션 =====
  void _openQuickActions(String time, int di, ScheduleCellData? data) async {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final has = data != null;
        final who = data?.name.isNotEmpty == true ? ' · ${data!.name}' : '';
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('소진 처리 (–1)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('소진 처리 예정: ${_weekdayLabel(di)} $time$who')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('소진 취소 (+1)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('소진 취소 예정: ${_weekdayLabel(di)} $time$who')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('노쇼 차감 (–1)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('노쇼 차감 예정: ${_weekdayLabel(di)} $time$who')),
                  );
                },
              ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('히스토리'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('히스토리 보기(추가 예정)')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('재등록(+회차)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('재등록 팝업(추가 예정)')),
                  );
                },
              ),
              if (has)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('프로필 열기'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('프로필 열기(추가 예정): ${data!.name}')),
                    );
                  },
                ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('삭제 확인'),
                      content: Text('${_weekdayLabel(di)} $time 스케줄을 삭제할까요?$who'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    setState(() {
                      _cells.remove('$di|$time');
                      _conflicts.remove('$di|$time');
                    });
                    await _saveCells();
                    widget.onChanged?.call();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('삭제되었습니다.')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ===== 빌드 =====
  @override
  Widget build(BuildContext context) {
    final hours = _hourRows();

    return LayoutBuilder(
      builder: (context, outer) {
        const headerH = 36.0;
        const bottomGap = 12.0; // 네비게이션 바와 살짝 띄움
        final gridColor = Theme.of(context)
            .colorScheme
            .outlineVariant
            .withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.6 : 0.7,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '※ 왼쪽 “시간”을 누르면 시작/종료 시각을, 각 시간칸(예: 09:00)을 누르면 분(00·10·20·30·40·50)을 바꿀 수 있어요.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: bottomGap),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final totalW = c.maxWidth;
                    final availableH = c.maxHeight;
                    final colW = totalW / 8.0;
                    final rows = hours.length;
                    final rowH = rows == 0 ? 0.0 : (availableH - headerH) / rows;

                    return Table(
                      border: TableBorder.all(color: gridColor, width: 1),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: { for (int i = 0; i < 8; i++) i: FixedColumnWidth(colW) },
                      children: [
                        // 헤더
                        TableRow(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          children: [
                            _th('시간', height: headerH, onTap: _openRangeDialog),
                            for (int di = 1; di <= 7; di++)
                              _th(_weekdayLabel(di), height: headerH, highlight: _isTodayColumn(di)),
                          ],
                        ),
                        // 데이터
                        for (final t in hours)
                          TableRow(
                            children: [
                              _tdTime(t, rowH),
                              for (int di = 1; di <= 7; di++) _buildCell(t, di, rowH),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _th(String text, {bool highlight = false, double height = 36, VoidCallback? onTap}) {
    final style = TextStyle(
      fontWeight: FontWeight.w700,
      color: highlight ? Theme.of(context).colorScheme.primary : null,
    );
    final child = Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(text, style: style),
    );
    return onTap == null ? child : InkWell(onTap: onTap, child: child);
  }

  Widget _tdTime(String time, double height) {
    final hh = time.substring(0, 2);
    return InkWell(
      onTap: () => _editMinuteForHour(hh),
      child: Container(
        height: height,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Text(time),
      ),
    );
  }

  // ── 현재시간 타임라인: 오늘 컬럼의 "현재 시각" 위치에 빨간 선 표시
  Widget _buildCell(String time, int di, double height) {
    final key = '$di|$time';
    final data = _cells[key];
    final has = data != null;
    final bg = has ? _colorFor(data!.name) : Colors.transparent;

    final isTodayCol = _isTodayColumn(di);
    bool showLine = false;
    double lineTop = 0;

    if (isTodayCol && widget.weekOffset == 0) {
      final now = DateTime.now();
      final rowHH = int.tryParse(time.substring(0, 2)) ?? -1;
      if (now.hour == rowHH) {
        showLine = true;
        lineTop = height * (now.minute / 60.0);
      }
    }

    final isConflict = _conflicts.contains(key);

    final content = has
        ? Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          data!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (data.cap > 0)
          Text(
            '${data.enrolled}/${data.cap}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    )
        : const SizedBox.shrink();

    return InkWell(
      onTap: () => _openCellEditor(time, di),
      onLongPress: () => _openQuickActions(time, di, data), // 롱프레스 퀵액션
      child: Stack(
        children: [
          Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: bg == Colors.transparent ? null : bg,
              border: isConflict ? Border.all(color: Colors.redAccent, width: 2) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: content,
          ),
          if (showLine)
            Positioned(
              top: lineTop.clamp(1.0, height - 2.0),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
    );
  }
}

class _EditResult {
  final ScheduleCellData? data;
  final bool isDelete;
  final bool isCancel;
  const _EditResult.save(this.data)
      : isDelete = false,
        isCancel = false;
  const _EditResult.delete()
      : data = null,
        isDelete = true,
        isCancel = false;
  const _EditResult.cancel()
      : data = null,
        isDelete = false,
        isCancel = true;
}
