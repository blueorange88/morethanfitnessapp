// lib/pages/home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/schedule_table.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // PageView로 주간 스와이프
  static const int _kBasePage = 10000;
  late final PageController _pageController =
  PageController(initialPage: _kBasePage);

  int _weekOffset = 0;
  int _rebuildTick = 0; // 상단 "다음 레슨" FutureBuilder 새로고침용

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _reloadNext() {
    setState(() => _rebuildTick++);
  }

  // 좌/우 화살표
  void _goPrevWeek() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNextWeek() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _jumpToThisWeek() {
    _pageController.jumpToPage(_kBasePage);
    setState(() => _weekOffset = 0);
  }

  Future<List<_LessonItem>> _loadNext() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('scheduleData_0'); // 이번 주만 대상
    if (raw == null || raw.isEmpty) return const [];

    final now = DateTime.now();
    final todayDi = now.weekday; // 1~7
    final nowMin = now.hour * 60 + now.minute;

    final list = (jsonDecode(raw) as List)
        .cast<Map>()
        .map((m) {
      final di = (m['di'] as num?)?.toInt() ?? 0;
      final time = (m['time'] as String?) ?? '00:00';
      final name = (m['name'] as String?) ?? '';
      final enrolled = (m['enrolled'] as num?)?.toInt() ?? 0;
      final cap = (m['cap'] as num?)?.toInt() ?? 0;
      return _LessonItem(
          di: di, time: time, name: name, enrolled: enrolled, cap: cap);
    })
        .where((e) => e.di == todayDi)
        .toList()
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

    return list.where((e) => e.minutesOfDay >= nowMin).take(2).toList();
  }

  String _weekRangeLabel(int weekOffset) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final start = monday.add(Duration(days: 7 * weekOffset));
    final end = start.add(const Duration(days: 6));
    String fmt(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    return '${fmt(start)} - ${fmt(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w800);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 헤더: 좌/우 화살표 + 범위 + 오늘 버튼
            Row(
              children: [
                IconButton(
                  tooltip: '지난 주',
                  onPressed: _goNextWeek, // PageView는 오른쪽이 이전 페이지
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '이번 주 스케줄  (${_weekRangeLabel(_weekOffset)})',
                      style: labelStyle,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _jumpToThisWeek,
                  icon: const Icon(Icons.today),
                  label: const Text('오늘'),
                ),
                IconButton(
                  tooltip: '다음 주',
                  onPressed: _goPrevWeek,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 이번 주일 때만 "오늘 다음 레슨"
            if (_weekOffset == 0) ...[
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FutureBuilder<List<_LessonItem>>(
                          key: ValueKey(_rebuildTick),
                          future: _loadNext(),
                          builder: (context, snap) {
                            final items = snap.data ?? const [];
                            if (items.isEmpty) {
                              return const Text('오늘 남은 레슨이 없습니다.',
                                  style: TextStyle(fontSize: 13));
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: items
                                  .map((e) => Padding(
                                padding:
                                const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${e.time}  ${e.name}'
                                      '${e.cap > 0 ? ' (${e.enrolled}/${e.cap})' : ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ))
                                  .toList(),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: '새로고침',
                        onPressed: _reloadNext,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 주간 스와이프
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _weekOffset = page - _kBasePage);
                },
                itemBuilder: (context, index) {
                  final offset = index - _kBasePage;
                  return ScheduleTable(
                    weekOffset: offset,
                    onChanged: _reloadNext,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonItem {
  final int di;
  final String time; // 'HH:MM'
  final String name;
  final int enrolled;
  final int cap;
  _LessonItem({
    required this.di,
    required this.time,
    required this.name,
    required this.enrolled,
    required this.cap,
  });
  int get minutesOfDay {
    final h = int.tryParse(time.substring(0, 2)) ?? 0;
    final m = int.tryParse(time.substring(3, 5)) ?? 0;
    return h * 60 + m;
  }
}
