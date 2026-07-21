class HomeWidgetBlockItem {
  const HomeWidgetBlockItem({
    required this.startAt,
    required this.endAt,
    required this.day,
    required this.name,
    required this.type,
    required this.colorHex,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String day;
  final String name;
  final String type;
  final String colorHex;
}

class HomeWidgetScheduleBlock {
  const HomeWidgetScheduleBlock({
    required this.day,
    required this.topRatio,
    required this.heightRatio,
    required this.columnIndex,
    required this.totalColumns,
    required this.label,
    required this.type,
    required this.colorHex,
  });

  final String day;
  final double topRatio;
  final double heightRatio;
  final int columnIndex;
  final int totalColumns;
  final String label;
  final String type;
  final String colorHex;

  String encode() {
    return [
      day,
      topRatio.toStringAsFixed(6),
      heightRatio.toStringAsFixed(6),
      columnIndex.toString(),
      totalColumns.toString(),
      label.replaceAll('|', '/'),
      type.replaceAll('|', '/'),
      colorHex,
    ].join('|');
  }
}

class HomeWidgetBlockMapper {
  const HomeWidgetBlockMapper._();

  static List<HomeWidgetScheduleBlock> buildBlocks({
    required int weekOffset,
    required DateTime currentTime,
    required int startHour,
    required int endHour,
    required List<String> visibleDays,
    required List<String> allWeekDays,
    required List<HomeWidgetBlockItem> items,
  }) {
    if (items.isEmpty) return const [];
    if (endHour <= startHour) return const [];

    final blocks = <HomeWidgetScheduleBlock>[];

    for (final day in visibleDays) {
      final dayIndex = allWeekDays.indexOf(day);
      if (dayIndex < 0) continue;

      final monday = _mondayOfWeek(currentTime).add(
        Duration(days: weekOffset * 7),
      );

      final baseDate = monday.add(Duration(days: dayIndex));

      final tableStart = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        startHour,
        0,
      );

      final tableEnd = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        endHour,
        0,
      );

      final totalMinutes = tableEnd.difference(tableStart).inMinutes;
      if (totalMinutes <= 0) continue;

      final dayItems = items.where((item) => item.day == day).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));

      for (final item in dayItems) {
        final clippedStart =
        item.startAt.isBefore(tableStart) ? tableStart : item.startAt;

        final clippedEnd =
        item.endAt.isAfter(tableEnd) ? tableEnd : item.endAt;

        if (!clippedEnd.isAfter(clippedStart)) continue;

        final topMinutes = clippedStart.difference(tableStart).inMinutes;
        final heightMinutes = clippedEnd.difference(clippedStart).inMinutes;

        blocks.add(
          HomeWidgetScheduleBlock(
            day: day,
            topRatio: (topMinutes / totalMinutes).clamp(0.0, 1.0),
            heightRatio: (heightMinutes / totalMinutes).clamp(0.0, 1.0),
            columnIndex: 0,
            totalColumns: 1,
            label: _displayName(item.name),
            type: item.type,
            colorHex: item.colorHex,
          ),
        );
      }
    }

    return blocks;
  }

  static DateTime _mondayOfWeek(DateTime base) {
    return DateTime(base.year, base.month, base.day).subtract(
      Duration(days: base.weekday - 1),
    );
  }

  static String _displayName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'ㆍ';

    final normalized = name.endsWith('님')
        ? name.substring(0, name.length - 1).trim()
        : name;

    final safe = normalized.isEmpty ? name : normalized;
    final chars = safe.runes.toList();

    if (chars.length <= 4) return safe;

    return String.fromCharCodes(chars.take(4));
  }
}