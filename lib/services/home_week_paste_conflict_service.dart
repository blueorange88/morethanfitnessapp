class HomeWeekPasteCandidate {
  const HomeWeekPasteCandidate({
    required this.day,
    required this.time,
    required this.endTime,
    required this.copyKey,
    required this.startAt,
    required this.endAt,
  });

  final String day;
  final String time;
  final String endTime;
  final String copyKey;
  final DateTime startAt;
  final DateTime endAt;
}

class HomeWeekPasteExistingSchedule {
  const HomeWeekPasteExistingSchedule({
    required this.docId,
    required this.day,
    required this.time,
    required this.endTime,
    required this.startAt,
    required this.endAt,
    required this.name,
    required this.memberId,
    required this.isConfirmed,
  });

  final String docId;
  final String day;
  final String time;
  final String endTime;
  final DateTime startAt;
  final DateTime endAt;
  final String name;
  final String memberId;
  final bool isConfirmed;
}

class HomeWeekPasteConflictService {
  const HomeWeekPasteConflictService._();

  static List<Map<String, dynamic>> findConflicts({
    required List<HomeWeekPasteCandidate> candidates,
    required List<HomeWeekPasteExistingSchedule> existingSchedules,
  }) {
    final conflicts = <Map<String, dynamic>>[];
    final seenConflictKeys = <String>{};

    for (final candidate in candidates) {
      if (!candidate.endAt.isAfter(candidate.startAt)) continue;

      for (final existing in existingSchedules) {
        if (existing.docId.trim().isEmpty) continue;
        if (existing.day != candidate.day) continue;

        final overlaps = _timeRangeOverlaps(
          startA: candidate.startAt,
          endA: candidate.endAt,
          startB: existing.startAt,
          endB: existing.endAt,
        );

        if (!overlaps) continue;

        final conflictKey = '${candidate.copyKey}|${existing.docId}';
        if (seenConflictKeys.contains(conflictKey)) continue;

        seenConflictKeys.add(conflictKey);

        conflicts.add({
          'docId': existing.docId,
          'isConfirmed': existing.isConfirmed,

          // 복사해서 붙여넣으려는 일정 정보
          'copyKey': candidate.copyKey,
          'copyDay': candidate.day,
          'copyTime': candidate.time,
          'copyEndTime': candidate.endTime,

          // 기존에 이미 있는 충돌 일정 정보
          'day': existing.day,
          'time': existing.time,
          'endTime': existing.endTime,
          'name': existing.name,
          'memberId': existing.memberId,
        });
      }
    }

    return conflicts;
  }

  static bool _timeRangeOverlaps({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }
}