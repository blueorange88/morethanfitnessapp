import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_header_message_engine.dart';

void main() {
  final now = DateTime(2026, 7, 20, 10, 0);

  test('시간대 인사는 nickname에 님을 한 번만 붙인다', () {
    expect(
      HomeHeaderMessageEngine.greeting(now: now, nickname: '모어'),
      '오늘도 잘 시작해볼까요, 모어님?',
    );
    expect(
      HomeHeaderMessageEngine.greeting(now: now, nickname: '모어님'),
      '오늘도 잘 시작해볼까요, 모어님?',
    );
  });

  test('같은 진입과 같은 조건에서는 build 횟수와 무관하게 같은 문장이다', () {
    final a = _select(now: now, entry: 1);
    final b = _select(now: now, entry: 1);
    expect(a.fcKey, b.fcKey);
    expect(a.fcText, b.fcText);
  });

  test('최근 본 문장은 다음 진입 후보에서 제외된다', () {
    final first = _select(now: now, entry: 1);
    final next = _select(now: now, entry: 2, recent: {first.fcKey});
    expect(next.fcKey, isNot(first.fcKey));
  });

  test('이미 오늘 노출한 질문은 다시 선택하지 않는다', () {
    final result = _select(
      now: now,
      entry: 3,
      asked: const {
        'mood_future',
        'gap_long_question',
        'gap_meal',
        'weather_umbrella',
      },
    );
    expect(result.questionKey, isNull);
  });

  test('지난 첫 레슨은 첫 레슨 후보로 만들지 않는다', () {
    final result = _select(
      now: DateTime(2026, 7, 20, 15),
      entry: 1,
      lessons: [
        HomeHeaderLessonContext(
          startAt: DateTime(2026, 7, 20, 9),
          endAt: DateTime(2026, 7, 20, 10),
        ),
      ],
      recent: const {
        'mood_future',
        'mood_good',
        'mood_self',
        'mood_slow',
        'mood_breathe',
        'mood_together',
      },
    );
    expect(result.fcKey, 'lesson_done');
  });

  test('실제 긴 공백에서만 공백 후보가 만들어진다', () {
    final lessons = [
      HomeHeaderLessonContext(
        startAt: DateTime(2026, 7, 20, 8),
        endAt: DateTime(2026, 7, 20, 9),
      ),
      HomeHeaderLessonContext(
        startAt: DateTime(2026, 7, 20, 13),
        endAt: DateTime(2026, 7, 20, 14),
      ),
    ];
    final result = _select(
      now: now,
      entry: 5,
      lessons: lessons,
      recent: const {
        'mood_future',
        'mood_good',
        'mood_self',
        'mood_slow',
        'mood_breathe',
        'mood_together',
        'lesson_next_minutes',
        'lesson_last',
      },
    );
    expect(result.fcKey, startsWith('gap_long'));
  });

  test('실제 MORE 센스 사건은 FC와 펼친 문장에서 중복하지 않는다', () {
    final result = _select(
      now: now,
      entry: 2,
      events: const [
        HomeMoreSenseContext(
          key: 'birthday:a',
          kind: HomeMoreSenseKind.birthday,
          memberName: '김민지',
        ),
        HomeMoreSenseContext(
          key: 'expiry:b',
          kind: HomeMoreSenseKind.membershipExpiry,
          memberName: '홍길동',
        ),
      ],
      recent: const {
        'mood_future',
        'mood_good',
        'mood_self',
        'mood_slow',
        'mood_breathe',
        'mood_together',
        'lesson_none',
        'lesson_relaxed',
      },
    );
    expect(result.fcText, isNot(result.moreSenseText));
  });

  test('날씨 입력이 없으면 날씨 문장을 만들지 않는다', () {
    final result = _select(now: now, entry: 9);
    expect(result.fcKey, isNot(startsWith('weather_')));
  });

  test('오늘 레슨 수에 따라 확장 헤더 workload 문구를 고른다', () {
    final cases = <int, HomeHeaderWorkloadBucket>{
      0: HomeHeaderWorkloadBucket.empty,
      1: HomeHeaderWorkloadBucket.light,
      5: HomeHeaderWorkloadBucket.steady,
      8: HomeHeaderWorkloadBucket.full,
      9: HomeHeaderWorkloadBucket.busy,
      12: HomeHeaderWorkloadBucket.veryBusy,
    };
    for (final entry in cases.entries) {
      final result = HomeHeaderMessageEngine.workloadFeedback(
        todayCount: entry.key,
        scheduleReady: true,
      );
      expect(result.bucket, entry.value);
    }
    expect(
      HomeHeaderMessageEngine.workloadFeedback(
        todayCount: 0,
        scheduleReady: false,
      ).bucket,
      HomeHeaderWorkloadBucket.loading,
    );
  });
}

HomeHeaderMessageSelection _select({
  required DateTime now,
  required int entry,
  List<HomeHeaderLessonContext> lessons = const [],
  List<HomeMoreSenseContext> events = const [],
  Set<String> recent = const {},
  Set<String> asked = const {},
}) {
  return HomeHeaderMessageEngine.select(
    now: now,
    lessons: lessons,
    moreSenseItems: events,
    moreSenseCount: events.length,
    memberCount: 3,
    entrySerial: entry,
    recentKeys: recent,
    askedQuestionKeysToday: asked,
  );
}
