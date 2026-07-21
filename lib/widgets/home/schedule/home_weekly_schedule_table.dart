import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const double _kScheduleRowHeight = 40.0;
const double _kScheduleHeaderCellHeight = 34.0;

const Color _kPrimaryColor = Color(0xFF4F46E5);

const Color _kScheduleLightBg = Color(0xFFFFFFFF);
const Color _kScheduleRowEven = Color(0xFFEFF6FF);
const Color _kScheduleRowOdd = Color(0xFFFFFFFF);

const Color _kScheduleTimeColTop = Color(0xFFFFFFFF);
const Color _kScheduleTimeColMid = Color(0xFFF8FAFC);
const Color _kScheduleTimeColBottom = Color(0xFFEFF6FF);

const Color _kScheduleGridLine = Color(0xFFE5E7EB);
const Color _kScheduleTimeColLine = Color(0xFFD1D5DB);
const Color _kScheduleTimeText = Color(0xFF475569);

const Color _kScheduleTodayHeader = Color(0xFFFBBF24);
const Color _kScheduleTodayHeaderDeep = Color(0xFFF59E0B);
const Color _kScheduleTodayEven = Color(0x33FBBF24);
const Color _kScheduleTodayOdd = Color(0x22FBBF24);
const Color _kScheduleCurrentLine = Color(0xFFE11D48);

const Color _kScheduleSoftTodayHeader = Color(0xFFFFF3C4);
const Color _kScheduleSoftTodayHeaderDeep = Color(0xFFF6D97B);
const Color _kScheduleSoftTodayEven = Color(0xFFFFFAEB);
const Color _kScheduleSoftTodayOdd = Color(0xFFFFFDF5);

class HomeWeeklyScheduleTable extends StatelessWidget {
  const HomeWeeklyScheduleTable({
    super.key,
    required this.dayFilter,
    required this.weekOffset,
    required this.scheduleData,
    this.exampleScheduleData = const {},
    required this.currentTime,
    required this.timeSlots,
    required this.onCellTap,
    this.onTimeHeaderTap,
    this.onTimeHeaderLongPress,
    this.onExampleTap,
    this.onTimeRowLongPress,
    this.onEventTap,
  });

  final String dayFilter;
  final int weekOffset;
  final Map<String, dynamic> scheduleData;
  final Map<String, dynamic> exampleScheduleData;
  final DateTime currentTime;
  final List<String> timeSlots;
  final void Function(String day, String time, bool hasSession) onCellTap;
  final VoidCallback? onTimeHeaderTap;
  final VoidCallback? onTimeHeaderLongPress;
  final VoidCallback? onExampleTap;
  final void Function(String timeLabel)? onTimeRowLongPress;
  final void Function(Map<String, dynamic> session)? onEventTap;

  static const int _defaultLessonDurationMinutes = 50;

  List<String> get _weekDaysAll => const ['월', '화', '수', '목', '금', '토', '일'];

  List<String> _filteredDays() {
    const weekdayDays = ['월', '화', '수', '목', '금'];
    const weekendDays = ['토', '일'];

    switch (dayFilter) {
      case 'weekday':
        return weekdayDays;
      case 'weekend':
        return weekendDays;
      default:
        return _weekDaysAll;
    }
  }

  int _findTodayIndex(List<String> days) {
    final todayName = _weekDaysAll[currentTime.weekday - 1];
    return days.indexOf(todayName);
  }

  double? _getTimeLinePos(String time, DateTime now, double cellHeight) {
    final parts = time.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]) ?? -1;
    final baseMinute = int.tryParse(parts[1]) ?? 0;

    if (hour != now.hour) return null;

    final diff = now.minute - baseMinute;
    if (diff < 0 || diff >= 60) return null;

    return (diff / 60) * cellHeight;
  }

  String _compactRunes(String value, int maxLength) {
    final chars = value.runes.toList();
    if (chars.length <= maxLength) return value;
    return String.fromCharCodes(chars.take(maxLength));
  }

  String _normalizeSchedulePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _scheduleIdentityKey(Map<String, dynamic> session) {
    final memberId = (session['memberId'] ?? '').toString().trim();
    if (memberId.isNotEmpty) return 'member:$memberId';

    final phone = _normalizeSchedulePhone(
      (session['phone'] ?? '').toString(),
    );
    if (phone.isNotEmpty) return 'phone:$phone';

    final docId = (session['docId'] ?? '').toString().trim();
    if (docId.isNotEmpty) return 'doc:$docId';

    final name = (session['name'] ?? '').toString().trim();
    return 'name:$name';
  }

  Map<String, int> _buildScheduleDuplicateNameIndexMap() {
    final grouped = <String, Map<String, Map<String, dynamic>>>{};

    void collectFrom(Map<String, dynamic> source) {
      for (final value in source.values) {
        if (value is! Map<String, dynamic>) continue;
        if (value['isExample'] == true) continue;

        final name = (value['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final identityKey = _scheduleIdentityKey(value);

        grouped.putIfAbsent(name, () => <String, Map<String, dynamic>>{});
        grouped[name]![identityKey] = Map<String, dynamic>.from(value);
      }
    }

    collectFrom(scheduleData);
    collectFrom(exampleScheduleData);

    final result = <String, int>{};

    for (final entry in grouped.entries) {
      final sameNameItems = entry.value.entries.toList();

      if (sameNameItems.length <= 1) continue;

      sameNameItems.sort((a, b) {
        final aSession = a.value;
        final bSession = b.value;

        final aPhone = _normalizeSchedulePhone(
          (aSession['phone'] ?? '').toString(),
        );
        final bPhone = _normalizeSchedulePhone(
          (bSession['phone'] ?? '').toString(),
        );

        final phoneCompare = aPhone.compareTo(bPhone);
        if (phoneCompare != 0) return phoneCompare;

        final aMemberId = (aSession['memberId'] ?? '').toString();
        final bMemberId = (bSession['memberId'] ?? '').toString();

        final memberCompare = aMemberId.compareTo(bMemberId);
        if (memberCompare != 0) return memberCompare;

        return a.key.compareTo(b.key);
      });

      for (int i = 0; i < sameNameItems.length; i++) {
        result[sameNameItems[i].key] = i + 1;
      }
    }

    return result;
  }

  String _scheduleBlockDisplayName(
      Map<String, dynamic> session,
      Map<String, int> duplicateNameIndexMap,
      ) {
    final rawName = (session['name'] ?? '').toString().trim();
    if (rawName.isEmpty) return '';

    final identityKey = _scheduleIdentityKey(session);
    final duplicateIndex = duplicateNameIndexMap[identityKey];

    if (duplicateIndex == null) {
      return _compactRunes(rawName, 4);
    }

    final suffix = duplicateIndex.toString();
    final chars = rawName.runes.toList();

    if (chars.length <= 3 && suffix.length == 1) {
      return '$rawName$suffix';
    }

    final baseMaxLength = math.max(1, 4 - suffix.length - 1);
    final base = String.fromCharCodes(chars.take(baseMaxLength));

    return '$base-$suffix';
  }

  int _hourIndexOfSlot(String slotTime) {
    final parts = slotTime.split(':');
    if (parts.length != 2) return -1;
    return int.tryParse(parts[0]) ?? -1;
  }

  int _startHourFromTimeSlots() {
    if (timeSlots.isEmpty) return 0;
    return _hourIndexOfSlot(timeSlots.first);
  }

  int _endHourExclusiveFromTimeSlots() {
    if (timeSlots.isEmpty) return 24;
    return _hourIndexOfSlot(timeSlots.last) + 1;
  }

  List<Map<String, dynamic>> _collectDaySessions(String day) {
    final sessions = <Map<String, dynamic>>[];

    void collectFrom(Map<String, dynamic> source) {
      for (final value in source.values) {
        if (value is! Map<String, dynamic>) continue;

        final rawStartAt = value['startAt'];
        if (rawStartAt is! DateTime) continue;

        final valueDay = _weekDaysAll[rawStartAt.weekday - 1];
        if (valueDay != day) continue;

        sessions.add(Map<String, dynamic>.from(value));
      }
    }

    collectFrom(scheduleData);
    collectFrom(exampleScheduleData);

    sessions.sort((a, b) {
      final aStart = a['startAt'];
      final bStart = b['startAt'];

      if (aStart is DateTime && bStart is DateTime) {
        return aStart.compareTo(bStart);
      }

      return 0;
    });

    return sessions;
  }

  DateTime _sessionEndAt(Map<String, dynamic> session) {
    final rawStartAt = session['startAt'];

    if (rawStartAt is! DateTime) {
      return DateTime.now().add(
        const Duration(minutes: _defaultLessonDurationMinutes),
      );
    }

    final rawEndAt = session['endAt'];

    if (rawEndAt is DateTime && rawEndAt.isAfter(rawStartAt)) {
      return rawEndAt;
    }

    return rawStartAt.add(
      const Duration(minutes: _defaultLessonDurationMinutes),
    );
  }

  bool _sessionsOverlap(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
      ) {
    final aStart = a['startAt'];
    final bStart = b['startAt'];

    if (aStart is! DateTime || bStart is! DateTime) return false;

    final aEnd = _sessionEndAt(a);
    final bEnd = _sessionEndAt(b);

    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  List<Map<String, dynamic>> _buildSessionLayouts(
      List<Map<String, dynamic>> sessions,
      ) {
    if (sessions.isEmpty) return [];

    final sorted = List<Map<String, dynamic>>.from(sessions)
      ..sort((a, b) {
        final aStart = a['startAt'];
        final bStart = b['startAt'];

        if (aStart is DateTime && bStart is DateTime) {
          return aStart.compareTo(bStart);
        }

        return 0;
      });

    final layouts = <Map<String, dynamic>>[];
    int i = 0;

    while (i < sorted.length) {
      final group = <Map<String, dynamic>>[];
      DateTime groupEnd = _sessionEndAt(sorted[i]);

      group.add(sorted[i]);
      int j = i + 1;

      while (j < sorted.length) {
        final next = sorted[j];
        final nextStart = next['startAt'];

        if (nextStart is! DateTime) {
          j++;
          continue;
        }

        if (nextStart.isBefore(groupEnd)) {
          group.add(next);

          final nextEnd = _sessionEndAt(next);
          if (nextEnd.isAfter(groupEnd)) {
            groupEnd = nextEnd;
          }

          j++;
        } else {
          break;
        }
      }

      final columns = <List<Map<String, dynamic>>>[];

      for (final session in group) {
        var placed = false;

        for (int col = 0; col < columns.length; col++) {
          final last = columns[col].last;

          if (!_sessionsOverlap(last, session)) {
            columns[col].add(session);

            layouts.add({
              'session': session,
              'columnIndex': col,
              'totalColumns': 0,
            });

            placed = true;
            break;
          }
        }

        if (!placed) {
          columns.add([session]);

          layouts.add({
            'session': session,
            'columnIndex': columns.length - 1,
            'totalColumns': 0,
          });
        }
      }

      final groupColumnCount = columns.length;

      for (int k = layouts.length - group.length; k < layouts.length; k++) {
        layouts[k]['totalColumns'] = groupColumnCount;
      }

      i = j;
    }

    return layouts;
  }

  double _topFromStartAt({
    required DateTime startAt,
    required int firstHour,
    required double rowHeight,
  }) {
    final totalMinutes =
        ((startAt.hour - firstHour) * 60) + startAt.minute.toDouble();

    return (totalMinutes / 60.0) * rowHeight;
  }

  double _heightFromDuration({
    required int durationMinutes,
    required double rowHeight,
  }) {
    return (durationMinutes / 60.0) * rowHeight;
  }

  Widget _buildEventBlock({
    required Map<String, dynamic> session,
    required int columnIndex,
    required int totalColumns,
    required double dayColWidth,
    required double rowHeight,
    required int firstHour,
    required Map<String, int> duplicateNameIndexMap,
    VoidCallback? onTap,
  }) {
    final rawStartAt = session['startAt'];
    if (rawStartAt is! DateTime) return const SizedBox.shrink();

    const columnGap = 2.0;
    const horizontalPadding = 3.0;
    const verticalPadding = 1.5;

    final startAt = rawStartAt;
    final endAt = _sessionEndAt(session);

    var durationMinutes = endAt.difference(startAt).inMinutes;
    if (durationMinutes <= 0) {
      durationMinutes = _defaultLessonDurationMinutes;
    }

    final top = _topFromStartAt(
      startAt: startAt,
      firstHour: firstHour,
      rowHeight: rowHeight,
    ) +
        verticalPadding;

    final rawHeight = _heightFromDuration(
      durationMinutes: durationMinutes,
      rowHeight: rowHeight,
    );

    final height = math.max(10.0, rawHeight - (verticalPadding * 2));

    final availableWidth = dayColWidth -
        (horizontalPadding * 2) -
        ((totalColumns - 1) * columnGap);

    final blockWidth = totalColumns <= 1
        ? dayColWidth - (horizontalPadding * 2)
        : availableWidth / totalColumns;

    final left = horizontalPadding + columnIndex * (blockWidth + columnGap);

    final rawName = (session['name'] ?? '').toString().trim();
    final isExample = session['isExample'] == true;

    Color blockColor;

    if (isExample) {
      blockColor = const Color(0xFF9CA3AF);
    } else {
      final colorHex = session['typeColorHex']?.toString();

      if (colorHex != null && colorHex.isNotEmpty) {
        var value = colorHex.trim().replaceFirst('#', '');
        if (value.length == 6) value = 'FF$value';

        final parsed = int.tryParse(value, radix: 16);
        blockColor = parsed != null ? Color(parsed) : AppColors.lessonPt;
      } else {
        final typeName =
        (session['typeName'] ?? session['type'] ?? '').toString();

        blockColor = AppColors.lessonBlockColor(typeName);
      }
    }

    final attendanceOverride = session['attendanceOverride']?.toString();
    final attended = session['attended'] == true;

    final lessonConfirmed = session['lessonConfirmed'] == true ||
        session['lessonConfirmedAt'] != null ||
        (session['lessonConfirmStatus'] ?? '').toString().trim().isNotEmpty ||
        (session['trainingLogId'] ?? '').toString().trim().isNotEmpty;

    final confirmStatus =
    (session['lessonConfirmStatus'] ?? '').toString().trim();

    final isNoShow = confirmStatus == 'no_show_deducted' ||
        confirmStatus == 'no_show_not_deducted' ||
        attendanceOverride == 'no_show_deducted' ||
        attendanceOverride == 'no_show_not_deducted';

    final isService = confirmStatus == 'service';

    final isDone = attended || lessonConfirmed || isNoShow || isService;

    final confirmedBlockColor = (() {
      if (!lessonConfirmed) {
        return blockColor;
      }

      switch (confirmStatus) {
        case 'no_show_deducted':
          return const Color(0xFF374151);
        case 'no_show_not_deducted':
          return const Color(0xFF7F3D3D);
        case 'service':
          return const Color(0xFF8A6A22);
        case 'completed':
        default:
          return const Color(0xFFC1D1DC);
      }
    })();

    final confirmedBorderColor = (() {
      if (!lessonConfirmed) {
        return blockColor.withOpacity(0.95);
      }

      switch (confirmStatus) {
        case 'no_show_deducted':
          return const Color(0xFF1F2937);
        case 'no_show_not_deducted':
          return const Color(0xFF5F2727);
        case 'service':
          return const Color(0xFF9F7E2D);
        case 'completed':
        default:
          return const Color(0xFF6B7280);
      }
    })();

    final confirmedTextColor =
    lessonConfirmed ? Colors.white.withOpacity(0.92) : Colors.white;

    final confirmedOpacity = lessonConfirmed ? 0.86 : 1.0;

    final blockOpacity = isExample
        ? 0.42
        : isDone
        ? AppColors.schedulerDoneOpacity
        : 1.0;

    final showName = durationMinutes >= 20 && rawName.isNotEmpty;

    final displayName = _scheduleBlockDisplayName(
      session,
      duplicateNameIndexMap,
    );

    return Positioned(
      left: left,
      top: top,
      width: blockWidth,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: isExample ? 0.70 : blockOpacity,
          child: Container(
            decoration: BoxDecoration(
              color: isExample
                  ? const Color(0xFFE5E7EB)
                  : confirmedBlockColor.withOpacity(confirmedOpacity),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isExample
                    ? const Color(0xFFD1D5DB)
                    : confirmedBorderColor,
                width: lessonConfirmed ? 1.1 : 0.7,
              ),
            ),
            child: Stack(
              children: [
                if (showName)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isExample
                                ? const Color(0xFF4B5563)
                                : confirmedTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isExample)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.55,
                          child: Text(
                            '예시용',
                            style: TextStyle(
                              color:
                              const Color(0xFF111827).withOpacity(0.13),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeaderCell(
      String day, {
        required double width,
        required bool isToday,
        bool isSoftToday = false,
      }) {
    final bool showSoftToday = !isToday && isSoftToday;

    return Container(
      width: width,
      height: _kScheduleHeaderCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isToday
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kScheduleTodayHeaderDeep,
            _kScheduleTodayHeader,
          ],
        )
            : showSoftToday
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kScheduleSoftTodayHeaderDeep,
            _kScheduleSoftTodayHeader,
          ],
        )
            : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kPrimaryColor,
            Color(0xFF9333EA),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.14),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: isToday
                ? const Color(0xFFD97706).withOpacity(0.35)
                : showSoftToday
                ? const Color(0xFFB45309).withOpacity(0.16)
                : _kPrimaryColor.withOpacity(0.35),
            width: 0.8,
          ),
        ),
      ),
      child: Text(
        day,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: showSoftToday
              ? const Color(0xFF92400E).withOpacity(0.78)
              : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
  Widget _buildTimeHeaderCell(
      String label, {
        double width = 70,
        double height = _kScheduleHeaderCellHeight,
        VoidCallback? onTap,
        VoidCallback? onLongPress,
      }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kScheduleTimeColTop,
              _kScheduleTimeColMid,
              _kScheduleTimeColBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          border: Border(
            right: BorderSide(
              color: _kScheduleTimeColLine,
              width: 1.6,
            ),
            bottom: BorderSide(
              color: _kScheduleGridLine,
              width: 0.8,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kScheduleTimeText,
            fontSize: 11.2,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCell(
      String time, {
        double width = 70,
        double height = 40,
        VoidCallback? onLongPress,
      }) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kScheduleTimeColTop,
              _kScheduleTimeColMid,
              _kScheduleTimeColBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          border: Border(
            right: BorderSide(
              color: _kScheduleTimeColLine,
              width: 1.6,
            ),
            bottom: BorderSide(
              color: _kScheduleGridLine,
              width: 0.6,
            ),
          ),
        ),
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
            color: _kScheduleTimeText,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _filteredDays();
    final duplicateNameIndexMap = _buildScheduleDuplicateNameIndexMap();
    final bool isCurrentWeek = weekOffset == 0;
    final todayIndex = _findTodayIndex(weekDays);

    final todayName = todayIndex >= 0 && todayIndex < weekDays.length
        ? weekDays[todayIndex]
        : null;

    const rowHeight = _kScheduleRowHeight;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeekendMode = weekDays.length == 2;
          final totalCols = weekDays.length + 1;

          final double timeColWidth = isWeekendMode
              ? math.min(88.0, constraints.maxWidth * 0.18).toDouble()
              : constraints.maxWidth / totalCols;

          final double dayColWidth = isWeekendMode
              ? (constraints.maxWidth - timeColWidth) / weekDays.length
              : timeColWidth;

          final firstHour = _startHourFromTimeSlots();
          final endHourExclusive = _endHourExclusiveFromTimeSlots();
          final bodyHeight = timeSlots.length * rowHeight;

          return Column(
            children: [
              Row(
                children: [
                  _buildTimeHeaderCell(
                    '시간',
                    width: timeColWidth,
                    height: _kScheduleHeaderCellHeight,
                    onTap: onTimeHeaderTap,
                    onLongPress: onTimeHeaderLongPress,
                  ),
                  ...weekDays.map((day) {
                    final isTodayCol =
                        isCurrentWeek && todayName != null && day == todayName;

                    final isSoftTodayCol =
                        !isCurrentWeek && todayName != null && day == todayName;

                    return _buildDayHeaderCell(
                      day,
                      width: dayColWidth,
                      isToday: isTodayCol,
                      isSoftToday: isSoftTodayCol,
                    );
                  }),
                ],
              ),
              SizedBox(
                height: bodyHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: timeColWidth,
                      child: Column(
                        children: timeSlots.map((time) {
                          return _buildTimeCell(
                            time,
                            width: timeColWidth,
                            height: rowHeight,
                            onLongPress: onTimeRowLongPress == null
                                ? null
                                : () => onTimeRowLongPress!(time),
                          );
                        }).toList(),
                      ),
                    ),
                    ...weekDays.map((day) {
                      final isTodayColumn =
                          isCurrentWeek && todayName != null && day == todayName;

                      final isSoftTodayColumn =
                          !isCurrentWeek && todayName != null && day == todayName;

                      final daySessions = _collectDaySessions(day).where(
                            (session) {
                          final rawStartAt = session['startAt'];
                          if (rawStartAt is! DateTime) return false;

                          final startAt = rawStartAt;
                          final endAt = _sessionEndAt(session);

                          final tableStart = DateTime(
                            startAt.year,
                            startAt.month,
                            startAt.day,
                            firstHour,
                          );

                          final tableEnd = DateTime(
                            startAt.year,
                            startAt.month,
                            startAt.day,
                            endHourExclusive,
                          );

                          return endAt.isAfter(tableStart) &&
                              startAt.isBefore(tableEnd);
                        },
                      ).toList();

                      final sessionLayouts = _buildSessionLayouts(daySessions);

                      return Container(
                        width: dayColWidth,
                        height: bodyHeight,
                        decoration: const BoxDecoration(
                          color: _kScheduleLightBg,
                        ),
                        child: Stack(
                          children: [
                            for (int i = 0; i < timeSlots.length; i++)
                              Positioned(
                                top: i * rowHeight,
                                left: 0,
                                right: 0,
                                height: rowHeight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    final tappedTime = timeSlots[i];
                                    onCellTap(day, tappedTime, false);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isTodayColumn
                                          ? (i % 2 == 0
                                          ? _kScheduleTodayEven
                                          : _kScheduleTodayOdd)
                                          : isSoftTodayColumn
                                          ? (i % 2 == 0
                                          ? _kScheduleSoftTodayEven
                                          : _kScheduleSoftTodayOdd)
                                          : (i % 2 == 0
                                          ? _kScheduleRowEven
                                          : _kScheduleRowOdd),
                                      border: const Border(
                                        right: BorderSide(
                                          color: _kScheduleGridLine,
                                          width: 0.5,
                                        ),
                                        bottom: BorderSide(
                                          color: _kScheduleGridLine,
                                          width: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (final layout in sessionLayouts)
                              Builder(
                                builder: (_) {
                                  final session = Map<String, dynamic>.from(
                                    layout['session'] as Map,
                                  );

                                  final isExample = session['isExample'] == true;

                                  return _buildEventBlock(
                                    session: session,
                                    columnIndex: layout['columnIndex'] as int,
                                    totalColumns: layout['totalColumns'] as int,
                                    dayColWidth: dayColWidth,
                                    rowHeight: rowHeight,
                                    firstHour: firstHour,
                                    duplicateNameIndexMap:
                                    duplicateNameIndexMap,
                                    onTap: isExample
                                        ? onExampleTap
                                        : onEventTap == null
                                        ? null
                                        : () => onEventTap!(session),
                                  );
                                },
                              ),
                            if (isTodayColumn || isSoftTodayColumn)
                              ...timeSlots.map((time) {
                                final showLine = _getTimeLinePos(
                                  time,
                                  currentTime,
                                  rowHeight,
                                );

                                if (showLine == null) {
                                  return const SizedBox.shrink();
                                }

                                final rowIndex = timeSlots.indexOf(time);

                                return Positioned(
                                  top: rowIndex * rowHeight + showLine,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: isTodayColumn ? 2.2 : 1.5,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: isTodayColumn ? 3 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTodayColumn
                                          ? _kScheduleCurrentLine
                                          : _kScheduleCurrentLine.withOpacity(0.34),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: isTodayColumn
                                          ? [
                                        BoxShadow(
                                          color: _kScheduleCurrentLine.withOpacity(0.35),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                          : [
                                        BoxShadow(
                                          color: _kScheduleCurrentLine.withOpacity(0.12),
                                          blurRadius: 2.5,
                                          offset: const Offset(0, 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}