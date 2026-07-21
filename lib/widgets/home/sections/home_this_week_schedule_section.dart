import 'package:flutter/material.dart';

import 'home_day_filter_button.dart';
import '../schedule/home_weekly_schedule_table.dart';

class HomeThisWeekScheduleSection extends StatelessWidget {
  const HomeThisWeekScheduleSection({
    super.key,
    required this.title,
    required this.dayFilter,
    required this.showScheduleHelp,
    required this.weekPageController,
    required this.totalWeeks,
    required this.weekPageIndex,
    required this.indexToOffset,
    required this.timeSlots,
    required this.currentTime,
    required this.primaryColor,
    required this.shouldShowScheduleExamples,
    required this.buildWeekSlice,
    required this.buildScheduleExampleSlice,
    required this.onToggleHelp,
    required this.onDayFilterChanged,
    required this.onPageChanged,
    required this.onWeekActionMenu,
    required this.onHideScheduleExamples,
    required this.onCellTap,
    required this.onTimeHeaderTap,
    required this.onTimeHeaderLongPress,
    required this.onTimeRowLongPress,
    required this.onEventTap,
    required this.onScheduleMoreMenu,
    this.onExampleTap,
  });

  final String title;
  final String dayFilter;
  final bool showScheduleHelp;
  final PageController weekPageController;
  final int totalWeeks;
  final int weekPageIndex;
  final int Function(int index) indexToOffset;
  final List<String> timeSlots;
  final DateTime currentTime;
  final Color primaryColor;

  final bool Function(int weekOffset) shouldShowScheduleExamples;
  final Map<String, dynamic> Function(int weekOffset) buildWeekSlice;
  final Map<String, dynamic> Function(int weekOffset) buildScheduleExampleSlice;

  final VoidCallback onToggleHelp;
  final ValueChanged<String> onDayFilterChanged;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(int weekOffset) onWeekActionMenu;
  final ValueChanged<int> onScheduleMoreMenu;
  final VoidCallback onHideScheduleExamples;

  final void Function(
      int weekOffset,
      String day,
      String time,
      bool hasSession,
      ) onCellTap;

  final VoidCallback onTimeHeaderTap;
  final VoidCallback onTimeHeaderLongPress;
  final void Function(String timeLabel) onTimeRowLongPress;
  final void Function(int weekOffset, Map<String, dynamic> session) onEventTap;
  final VoidCallback? onExampleTap;

  static const double _rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final rows = timeSlots.length + 1;
    final tableHeight = rows * _rowHeight;
    final weekOffset = indexToOffset(weekPageIndex);

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
                          await onWeekActionMenu(weekOffset);
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
                      onTap: onToggleHelp,
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
                    tooltip: '스케줄표 관리',
                    icon: const Icon(Icons.more_vert_rounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onScheduleMoreMenu(weekOffset),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: weekPageIndex > 0
                        ? () {
                      weekPageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: weekPageIndex < totalWeeks - 1
                        ? () {
                      weekPageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (showScheduleHelp) ...[
            const Text(
              "· 좌우 스와이프해서 지난 주 / 이번 주 / 다음 주는 물론 앞뒤 4주까지 볼 수 있어요.\n"
                  "· 빈 칸을 탭하면 레슨일정을 등록할 수 있어요.\n"
                  "· ‘시간’ 칸을 누르면 첫/마지막 시간을 설정할 수 있고, 길게 누르면 전체 시작 분을 바꿀 수 있어요.\n"
                  "· 06시, 07시 같은 숫자 시간 칸을 길게 누르면 해당 시간 줄만 조정할 수 있어요.\n"
                  "· 제목을 길게 누르거나 ⋮ 버튼을 누르면 스케줄표 관리 메뉴가 열려요.",
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
                child: HomeDayFilterButton(
                  label: '전체 (7일)',
                  isSelected: dayFilter == 'all',
                  primaryColor: primaryColor,
                  onTap: () => onDayFilterChanged('all'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: HomeDayFilterButton(
                  label: '평일 (5일)',
                  isSelected: dayFilter == 'weekday',
                  primaryColor: primaryColor,
                  onTap: () => onDayFilterChanged('weekday'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: HomeDayFilterButton(
                  label: '주말 (2일)',
                  isSelected: dayFilter == 'weekend',
                  primaryColor: primaryColor,
                  onTap: () => onDayFilterChanged('weekend'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shouldShowScheduleExamples(weekOffset)) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
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
                      '저 AI FC가 예시 레슨을 먼저 올려뒀어요. 실제 레슨을 3개 이상 등록하면 자연스럽게 사라져요.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onHideScheduleExamples,
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
              controller: weekPageController,
              itemCount: totalWeeks,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final offset = indexToOffset(index);
                final weekSchedule = buildWeekSlice(offset);

                return HomeWeeklyScheduleTable(
                  dayFilter: dayFilter,
                  weekOffset: offset,
                  scheduleData: weekSchedule,
                  exampleScheduleData: buildScheduleExampleSlice(offset),
                  currentTime: currentTime,
                  timeSlots: timeSlots,
                  onCellTap: (day, time, hasSession) {
                    onCellTap(offset, day, time, hasSession);
                  },
                  onTimeHeaderTap: onTimeHeaderTap,
                  onTimeHeaderLongPress: onTimeHeaderLongPress,
                  onTimeRowLongPress: onTimeRowLongPress,
                  onExampleTap: onExampleTap,
                  onEventTap: (session) {
                    onEventTap(offset, session);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}