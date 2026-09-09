import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/monthly_lesson_record.dart';

enum MonthlyLessonViewState {
  loading,
  success,
  empty,
  permissionDenied,
  networkError
}

class MonthlyLessonCalendar extends StatelessWidget {
  const MonthlyLessonCalendar({
    super.key,
    required this.month,
    required this.state,
    required this.summary,
    required this.selectedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onCurrentMonth,
    required this.onDaySelected,
    required this.onRetry,
    this.onMemberTap,
  });

  final DateTime month;
  final MonthlyLessonViewState state;
  final MonthlyLessonSummary? summary;
  final DateTime? selectedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onCurrentMonth;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onRetry;
  final ValueChanged<MonthlyLessonRecord>? onMemberTap;

  static const _completedColor = Color(0xFFC1D1DC);
  static const _serviceColor = Color(0xFF8A6A22);
  static const _noShowDeductedColor = Color(0xFF374151);
  static const _noShowNotDeductedColor = Color(0xFF7F3D3D);
  static const _cancelledColor = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('monthly_lesson_calendar'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 14),
          if (state == MonthlyLessonViewState.loading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state == MonthlyLessonViewState.permissionDenied)
            _buildError(
              icon: Icons.lock_outline_rounded,
              message: '이 작업공간의 레슨 기록을 볼 권한이 없어요.',
            )
          else if (state == MonthlyLessonViewState.networkError)
            _buildError(
              icon: Icons.cloud_off_rounded,
              message: '월간 레슨 기록을 불러오지 못했어요.',
            )
          else ...[
            _buildSummary(),
            const SizedBox(height: 16),
            _buildCalendar(),
            if (state == MonthlyLessonViewState.empty) ...[
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '이 달에 확정된 레슨 기록이 없어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ],
            if (selectedDay != null) ...[
              const SizedBox(height: 18),
              _buildSelectedDayDetails(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          key: const Key('monthly_lesson_previous'),
          tooltip: '이전 달',
          onPressed: onPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '${month.year}년 ${month.month}월',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          key: const Key('monthly_lesson_next'),
          tooltip: '다음 달',
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(
          key: const Key('monthly_lesson_current'),
          onPressed: onCurrentMonth,
          child: const Text('이번 달'),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final value = summary ?? MonthlyLessonSummary(records: const []);
    final items = [
      ('총 확정', value.totalConfirmed, const Color(0xFF4F46E5)),
      ('소진', value.completed, _completedColor),
      ('서비스', value.service, _serviceColor),
      ('노쇼 차감', value.noShowDeducted, _noShowDeductedColor),
      ('노쇼 미차감', value.noShowNotDeducted, _noShowNotDeductedColor),
      ('실제 회원', value.actualMemberCount, const Color(0xFF059669)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: item.$3.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.$3.withValues(alpha: 0.28)),
              ),
              child: Text(
                '${item.$1} ${item.$2}',
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyCount = firstDay.weekday % 7;
    final cellCount = ((leadingEmptyCount + dayCount + 6) ~/ 7) * 7;
    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      children: [
        Row(
          children: weekdayLabels
              .map(
                (label) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 72,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingEmptyCount + 1;
            if (dayNumber < 1 || dayNumber > dayCount) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNumber);
            final records = summary?.recordsForDay(day) ?? const [];
            final count = summary?.countForDay(day) ?? 0;
            final selected = selectedDay?.year == day.year &&
                selectedDay?.month == day.month &&
                selectedDay?.day == day.day;
            final statuses = records
                .where((record) => record.isConfirmed)
                .map((record) => record.status)
                .toSet()
                .take(4);
            return InkWell(
              key: Key('monthly_lesson_day_$dayNumber'),
              onTap: () => onDaySelected(day),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$dayNumber',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (count > 0)
                      Text(
                        '$count회',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: statuses
                          .map(
                            (status) => Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetails() {
    final day = selectedDay!;
    final records = summary?.recordsForDay(day) ?? const [];
    return Column(
      key: const Key('monthly_lesson_day_details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${day.month}월 ${day.day}일 레슨 기록',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        if (records.isEmpty)
          const Text(
            '이 날짜에는 확정된 레슨 기록이 없어요.',
            style: TextStyle(color: Color(0xFF6B7280)),
          )
        else
          ...records.map(_buildRecordTile),
      ],
    );
  }

  Widget _buildRecordTile(MonthlyLessonRecord record) {
    final name = record.memberNameSnapshot.isEmpty
        ? '이름 기록 없음'
        : record.memberNameSnapshot;
    final session =
        record.lessonNumberSnapshot > 0 && record.sessionTotalSnapshot > 0
            ? '${record.lessonNumberSnapshot}/${record.sessionTotalSnapshot}회차'
            : '';
    final canOpenMember = record.memberId.isNotEmpty && onMemberTap != null;
    return InkWell(
      onTap: canOpenMember ? () => onMemberTap!(record) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 42,
              decoration: BoxDecoration(
                color: _statusColor(record.status),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('HH:mm').format(record.startAt)} '
                    '$name · ${record.lessonType.isEmpty ? '레슨' : record.lessonType}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [statusLabel(record.status), session]
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (canOpenMember)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildError({required IconData icon, required String message}) {
    return SizedBox(
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF6B7280), size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 불러오기')),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'completed' => _completedColor,
        'service' => _serviceColor,
        'no_show_deducted' => _noShowDeductedColor,
        'no_show_not_deducted' => _noShowNotDeductedColor,
        'confirm_cancelled' => _cancelledColor,
        _ => _cancelledColor,
      };

  static String statusLabel(String status) => switch (status) {
        'completed' => '소진',
        'service' => '서비스',
        'no_show_deducted' => '노쇼 차감',
        'no_show_not_deducted' => '노쇼 미차감',
        'confirm_cancelled' => '확정취소',
        _ => '기록',
      };
}
