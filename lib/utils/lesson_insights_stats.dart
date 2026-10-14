class LessonInsightEntry {
  const LessonInsightEntry({
    required this.startAt,
    required this.status,
    required this.type,
  });

  final DateTime startAt;
  final String status;
  final String type;
}

class LessonInsightMember {
  const LessonInsightMember({
    required this.status,
    required this.remainingSessions,
    required this.totalSessions,
    this.createdAt,
    this.membershipEndAt,
    this.lastLessonAt,
  });

  final String status;
  final int remainingSessions;
  final int totalSessions;
  final DateTime? createdAt;
  final DateTime? membershipEndAt;
  final DateTime? lastLessonAt;
}

class LessonInsightStats {
  const LessonInsightStats({
    required this.registeredLessons,
    required this.completedLessons,
    required this.upcomingLessons,
    required this.noShowDeducted,
    required this.noShowNotDeducted,
    required this.serviceLessons,
    required this.weekdayCounts,
    required this.typeCounts,
    required this.activeMembers,
    required this.dormantMembers,
    required this.expiredMembers,
    required this.newMembers,
    required this.lowRemainingMembers,
    required this.expiringMembers,
    required this.longAbsentMembers,
  });

  factory LessonInsightStats.calculate({
    required Iterable<LessonInsightEntry> lessons,
    required Iterable<LessonInsightMember> members,
    required DateTime periodStart,
    required DateTime periodEndExclusive,
    required DateTime now,
  }) {
    final weekdayCounts = List<int>.filled(7, 0);
    final typeCounts = <String, int>{};
    var registeredLessons = 0;
    var completedLessons = 0;
    var upcomingLessons = 0;
    var noShowDeducted = 0;
    var noShowNotDeducted = 0;
    var serviceLessons = 0;

    for (final lesson in lessons) {
      if (lesson.startAt.isBefore(periodStart) ||
          !lesson.startAt.isBefore(periodEndExclusive)) {
        continue;
      }

      registeredLessons++;
      weekdayCounts[lesson.startAt.weekday - 1]++;
      final type = lesson.type.trim().isEmpty ? '기타' : lesson.type.trim();
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;

      switch (lesson.status) {
        case 'completed':
          completedLessons++;
          break;
        case 'no_show_deducted':
          noShowDeducted++;
          break;
        case 'no_show_not_deducted':
          noShowNotDeducted++;
          break;
        case 'service':
          serviceLessons++;
          break;
      }

      if (lesson.startAt.isAfter(now) && lesson.status.trim().isEmpty) {
        upcomingLessons++;
      }
    }

    var activeMembers = 0;
    var dormantMembers = 0;
    var expiredMembers = 0;
    var newMembers = 0;
    var lowRemainingMembers = 0;
    var expiringMembers = 0;
    var longAbsentMembers = 0;
    final today = DateTime(now.year, now.month, now.day);
    final longAbsenceCutoff = today.subtract(const Duration(days: 14));

    for (final member in members) {
      switch (member.status) {
        case '활성':
          activeMembers++;
          break;
        case '휴면':
          dormantMembers++;
          break;
        case '만료':
          expiredMembers++;
          break;
      }

      final createdAt = member.createdAt;
      if (createdAt != null &&
          !createdAt.isBefore(periodStart) &&
          createdAt.isBefore(periodEndExclusive)) {
        newMembers++;
      }

      if (member.status != '활성') continue;

      if (member.totalSessions > 0 &&
          member.remainingSessions >= 0 &&
          member.remainingSessions <= 5) {
        lowRemainingMembers++;
      }

      final membershipEndAt = member.membershipEndAt;
      if (membershipEndAt != null &&
          !membershipEndAt.isBefore(today) &&
          membershipEndAt.isBefore(periodEndExclusive)) {
        expiringMembers++;
      }

      final lastLessonAt = member.lastLessonAt;
      if (lastLessonAt != null) {
        final lastLessonDate = DateTime(
          lastLessonAt.year,
          lastLessonAt.month,
          lastLessonAt.day,
        );
        if (!lastLessonDate.isAfter(longAbsenceCutoff)) {
          longAbsentMembers++;
        }
      }
    }

    return LessonInsightStats(
      registeredLessons: registeredLessons,
      completedLessons: completedLessons,
      upcomingLessons: upcomingLessons,
      noShowDeducted: noShowDeducted,
      noShowNotDeducted: noShowNotDeducted,
      serviceLessons: serviceLessons,
      weekdayCounts: weekdayCounts,
      typeCounts: typeCounts,
      activeMembers: activeMembers,
      dormantMembers: dormantMembers,
      expiredMembers: expiredMembers,
      newMembers: newMembers,
      lowRemainingMembers: lowRemainingMembers,
      expiringMembers: expiringMembers,
      longAbsentMembers: longAbsentMembers,
    );
  }

  final int registeredLessons;
  final int completedLessons;
  final int upcomingLessons;
  final int noShowDeducted;
  final int noShowNotDeducted;
  final int serviceLessons;
  final List<int> weekdayCounts;
  final Map<String, int> typeCounts;
  final int activeMembers;
  final int dormantMembers;
  final int expiredMembers;
  final int newMembers;
  final int lowRemainingMembers;
  final int expiringMembers;
  final int longAbsentMembers;

  int get confirmedOutcomeLessons =>
      completedLessons + noShowDeducted + noShowNotDeducted + serviceLessons;

  double? get actualLessonRate {
    final denominator = confirmedOutcomeLessons;
    if (denominator == 0) return null;
    return completedLessons / denominator * 100;
  }
}
