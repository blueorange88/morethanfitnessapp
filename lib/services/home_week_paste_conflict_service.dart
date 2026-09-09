import '../utils/home_schedule_move_plan.dart';

class HomeWeekPasteCandidate {
  const HomeWeekPasteCandidate({
    required this.sourceIndex,
    required this.day,
    required this.time,
    required this.endTime,
    required this.startAt,
    required this.endAt,
  });

  final int sourceIndex;
  final String day;
  final String time;
  final String endTime;
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

class HomeWeekPastePlan {
  const HomeWeekPastePlan({
    required this.pasteableSchedules,
    required this.conflictingSchedules,
  });

  final List<HomeWeekPasteCandidate> pasteableSchedules;
  final List<HomeWeekPasteCandidate> conflictingSchedules;

  int get pasteableCount => pasteableSchedules.length;
  int get conflictingCount => conflictingSchedules.length;
  bool get hasConflicts => conflictingSchedules.isNotEmpty;
  bool get allConflicting => hasConflicts && pasteableSchedules.isEmpty;

  Set<int> get pasteableSourceIndexes =>
      pasteableSchedules.map((candidate) => candidate.sourceIndex).toSet();

  Set<int> get conflictingSourceIndexes =>
      conflictingSchedules.map((candidate) => candidate.sourceIndex).toSet();

  bool hasSameConflicts(HomeWeekPastePlan other) {
    final current = conflictingSourceIndexes;
    final next = other.conflictingSourceIndexes;
    return current.length == next.length && current.containsAll(next);
  }
}

class HomeWeekPasteConflictService {
  const HomeWeekPasteConflictService._();

  static HomeWeekPastePlan classify({
    required List<HomeWeekPasteCandidate> candidates,
    required List<HomeWeekPasteExistingSchedule> existingSchedules,
    bool allowOverlappingCandidates = false,
  }) {
    final conflictingSourceIndexes = <int>{};

    for (final candidate in candidates) {
      if (!candidate.endAt.isAfter(candidate.startAt)) continue;

      for (final existing in existingSchedules) {
        if (existing.docId.trim().isEmpty) continue;
        if (existing.day != candidate.day) continue;

        if (!homeScheduleTimeRangesOverlap(
          startA: candidate.startAt,
          endA: candidate.endAt,
          startB: existing.startAt,
          endB: existing.endAt,
        )) {
          continue;
        }

        conflictingSourceIndexes.add(candidate.sourceIndex);
        break;
      }
    }

    if (!allowOverlappingCandidates) {
      for (var index = 0; index < candidates.length; index++) {
        final first = candidates[index];
        for (var otherIndex = index + 1;
            otherIndex < candidates.length;
            otherIndex++) {
          final second = candidates[otherIndex];
          if (!homeScheduleTimeRangesOverlap(
            startA: first.startAt,
            endA: first.endAt,
            startB: second.startAt,
            endB: second.endAt,
          )) {
            continue;
          }
          conflictingSourceIndexes
            ..add(first.sourceIndex)
            ..add(second.sourceIndex);
        }
      }
    }

    final pasteableSchedules = <HomeWeekPasteCandidate>[];
    final conflictingSchedules = <HomeWeekPasteCandidate>[];
    for (final candidate in candidates) {
      if (conflictingSourceIndexes.contains(candidate.sourceIndex)) {
        conflictingSchedules.add(candidate);
      } else {
        pasteableSchedules.add(candidate);
      }
    }

    return HomeWeekPastePlan(
      pasteableSchedules: List.unmodifiable(pasteableSchedules),
      conflictingSchedules: List.unmodifiable(conflictingSchedules),
    );
  }
}
