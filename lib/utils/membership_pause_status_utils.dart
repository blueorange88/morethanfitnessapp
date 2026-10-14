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

/// 정지 기간이 끝났는데(재개 예정일 당일 포함) 아직 정지 상태일 때, 예정일부터 지난 일수.
/// 당일이면 0. 정지 중이 아니거나 예정일이 없거나 아직 안 됐으면 null.
/// 재개는 트레이너가 직접 누르는 동작이라 기간이 끝나도 저절로 풀리지 않는다.
int? membershipPauseOverdueDays({
  required bool isPaused,
  required DateTime? resumeDueAt,
  DateTime? now,
}) {
  if (!isPaused || resumeDueAt == null) return null;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final due = DateTime(resumeDueAt.year, resumeDueAt.month, resumeDueAt.day);
  final days = today.difference(due).inDays;
  return days >= 0 ? days : null;
}

/// 재개 예정일까지 남은 일수(내일이면 1). 정지 중이 아니거나 예정일이 없거나 이미 당일/지났으면 null.
int? membershipResumeDaysLeft({
  required bool isPaused,
  required DateTime? resumeDueAt,
  DateTime? now,
}) {
  if (!isPaused || resumeDueAt == null) return null;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final due = DateTime(resumeDueAt.year, resumeDueAt.month, resumeDueAt.day);
  final days = due.difference(today).inDays;
  return days > 0 ? days : null;
}

/// 고객카드 알림: 재개 [withinDays]일 전부터 `재개 5일 전 · 10.20에 자동으로 재개돼요` 처럼 알린다.
String? membershipResumeCountdownText({
  required bool isPaused,
  required DateTime? resumeDueAt,
  DateTime? now,
  int withinDays = 5,
}) {
  final left = membershipResumeDaysLeft(
    isPaused: isPaused,
    resumeDueAt: resumeDueAt,
    now: now,
  );
  if (left == null || left > withinDays || resumeDueAt == null) return null;
  final month = resumeDueAt.month.toString().padLeft(2, '0');
  final day = resumeDueAt.day.toString().padLeft(2, '0');
  return '재개 $left일 전 · $month.$day에 자동으로 재개돼요';
}

String? membershipResumeDueLabel({
  required bool isPaused,
  required DateTime? resumeDueAt,
  DateTime? now,
}) {
  if (!isPaused || resumeDueAt == null) return null;

  final overdue = membershipPauseOverdueDays(
    isPaused: isPaused,
    resumeDueAt: resumeDueAt,
    now: now,
  );
  if (overdue != null) {
    return overdue == 0 ? '오늘 재개 예정' : '재개 예정일 $overdue일 지남';
  }

  final month = resumeDueAt.month.toString().padLeft(2, '0');
  final day = resumeDueAt.day.toString().padLeft(2, '0');

  return '재개 예정 $month.$day';
}
