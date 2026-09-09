String? membershipPauseElapsedLabel({
  required bool isPaused,
  required DateTime? pausedAt,
  DateTime? now,
}) {
  if (!isPaused || pausedAt == null) return null;

  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final pausedDate = DateTime(pausedAt.year, pausedAt.month, pausedAt.day);
  final elapsed = today.difference(pausedDate).inDays;
  final safeElapsed = elapsed <= 0 ? 1 : elapsed;

  return '정지 $safeElapsed일째';
}

String? membershipResumeDueLabel({
  required bool isPaused,
  required DateTime? resumeDueAt,
}) {
  if (!isPaused || resumeDueAt == null) return null;

  final month = resumeDueAt.month.toString().padLeft(2, '0');
  final day = resumeDueAt.day.toString().padLeft(2, '0');

  return '재개 예정 $month.$day';
}
