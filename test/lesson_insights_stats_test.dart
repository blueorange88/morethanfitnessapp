import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/lesson_insights_stats.dart';

void main() {
  final start = DateTime(2026, 7, 1);
  final end = DateTime(2026, 8, 1);
  final now = DateTime(2026, 7, 14, 12);

  test('실제 레슨 상태와 예정 레슨만 집계한다', () {
    final stats = LessonInsightStats.calculate(
      periodStart: start,
      periodEndExclusive: end,
      now: now,
      lessons: [
        LessonInsightEntry(
          startAt: DateTime(2026, 7, 6, 10),
          status: 'completed',
          type: 'PT',
        ),
        LessonInsightEntry(
          startAt: DateTime(2026, 7, 7, 10),
          status: 'no_show_deducted',
          type: '필라테스',
        ),
        LessonInsightEntry(
          startAt: DateTime(2026, 7, 20, 10),
          status: '',
          type: 'PT',
        ),
        LessonInsightEntry(
          startAt: DateTime(2026, 8, 2, 10),
          status: '',
          type: 'PT',
        ),
      ],
      members: const [],
    );

    expect(stats.registeredLessons, 3);
    expect(stats.completedLessons, 1);
    expect(stats.noShowDeducted, 1);
    expect(stats.upcomingLessons, 1);
    expect(stats.actualLessonRate, 50);
    expect(stats.typeCounts, {'PT': 2, '필라테스': 1});
  });

  test('확정 결과가 없으면 실제 수업률을 만들지 않는다', () {
    final stats = LessonInsightStats.calculate(
      periodStart: start,
      periodEndExclusive: end,
      now: now,
      lessons: const [],
      members: const [],
    );

    expect(stats.actualLessonRate, isNull);
  });

  test('회원 상태와 기간·행동 지표를 실제 필드로 집계한다', () {
    final stats = LessonInsightStats.calculate(
      periodStart: start,
      periodEndExclusive: end,
      now: now,
      lessons: const [],
      members: [
        LessonInsightMember(
          status: '활성',
          remainingSessions: 5,
          totalSessions: 10,
          createdAt: DateTime(2026, 7, 3),
          membershipEndAt: DateTime(2026, 7, 30),
          lastLessonAt: DateTime(2026, 6, 20),
        ),
        const LessonInsightMember(
          status: '휴면',
          remainingSessions: 0,
          totalSessions: 0,
        ),
        const LessonInsightMember(
          status: '만료',
          remainingSessions: 0,
          totalSessions: 0,
        ),
      ],
    );

    expect(stats.activeMembers, 1);
    expect(stats.dormantMembers, 1);
    expect(stats.expiredMembers, 1);
    expect(stats.newMembers, 1);
    expect(stats.lowRemainingMembers, 1);
    expect(stats.expiringMembers, 1);
    expect(stats.longAbsentMembers, 1);
  });

  test('마지막 레슨이 정확히 14일 전이면 장기 미방문에 포함한다', () {
    final stats = LessonInsightStats.calculate(
      periodStart: start,
      periodEndExclusive: end,
      now: now,
      lessons: const [],
      members: [
        LessonInsightMember(
          status: '활성',
          remainingSessions: 8,
          totalSessions: 10,
          lastLessonAt: DateTime(2026, 6, 30, 23, 30),
        ),
      ],
    );

    expect(stats.longAbsentMembers, 1);
  });
}
