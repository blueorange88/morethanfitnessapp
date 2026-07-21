class HomeWidgetGridMapper {
  const HomeWidgetGridMapper._();

  static List<String> buildWeekRows({
    required int weekOffset,
    required List<String> timeSlots,
    required List<String> visibleDays,
    required DateTime currentTime,
  }) {
    final rows = <String>[];

    for (final time in timeSlots) {
      final parts = time.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? -1 : -1;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final rowStartMinutes = hour * 60 + minute;
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;

      final isCurrent = weekOffset == 0 &&
          hour >= 0 &&
          currentMinutes >= rowStartMinutes &&
          currentMinutes < rowStartMinutes + 60;

      final cells = List<String>.filled(visibleDays.length, 'ㆍ');

      rows.add('$time|${isCurrent ? '1' : '0'}|${cells.join('|')}');
    }

    return rows;
  }

  static double? buildCurrentMarkerRatio({
    required int weekOffset,
    required DateTime currentTime,
    required int startHour,
    required int endHour,
  }) {
    if (weekOffset != 0) return null;
    if (endHour <= startHour) return null;

    final tableStart = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      startHour,
    );

    final tableEnd = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      endHour,
    );

    if (!currentTime.isAfter(tableStart) || !currentTime.isBefore(tableEnd)) {
      return null;
    }

    final totalMinutes = tableEnd.difference(tableStart).inMinutes;
    if (totalMinutes <= 0) return null;

    final passedMinutes = currentTime.difference(tableStart).inMinutes;

    return (passedMinutes / totalMinutes).clamp(0.0, 1.0);
  }
}