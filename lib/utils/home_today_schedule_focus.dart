int resolveHomeTodayTargetHour({
  required DateTime now,
  required Iterable<DateTime> lessonStartTimes,
  required int startHour,
  required int endHourExclusive,
}) {
  final upcoming = lessonStartTimes
      .where((start) =>
          start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          !start.isBefore(now))
      .toList()
    ..sort();
  final candidate = upcoming.isEmpty ? now.hour : upcoming.first.hour;
  return candidate.clamp(startHour, endHourExclusive - 1).toInt();
}
