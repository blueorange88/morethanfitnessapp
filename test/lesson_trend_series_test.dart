import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/lesson_insights_stats.dart';
import 'package:mtf_app/utils/lesson_trend_series.dart';

LessonInsightEntry _lesson(DateTime at, {String status = 'completed'}) =>
    LessonInsightEntry(startAt: at, status: status, type: 'PT');

void main() {
  group('묶음 시작일', () {
    test('일별은 그날, 주별은 월요일, 월별은 1일', () {
      final wed = DateTime(2026, 11, 11, 15, 30); // 수요일
      expect(
        trendBucketStart(wed, TrendGranularity.day),
        DateTime(2026, 11, 11),
      );
      expect(
        trendBucketStart(wed, TrendGranularity.week),
        DateTime(2026, 11, 9),
      );
      expect(
        trendBucketStart(wed, TrendGranularity.month),
        DateTime(2026, 11, 1),
      );
      // 일요일은 그 주의 마지막 날이다.
      expect(
        trendBucketStart(DateTime(2026, 11, 15), TrendGranularity.week),
        DateTime(2026, 11, 9),
      );
    });

    test('다음·이전 묶음(월 경계·연 경계 포함)', () {
      expect(
        trendShiftBucket(DateTime(2026, 12, 1), TrendGranularity.month, 1),
        DateTime(2027, 1, 1),
      );
      expect(
        trendShiftBucket(DateTime(2026, 1, 1), TrendGranularity.month, -1),
        DateTime(2025, 12, 1),
      );
      expect(
        trendShiftBucket(DateTime(2026, 11, 9), TrendGranularity.week, -1),
        DateTime(2026, 11, 2),
      );
      expect(
        trendShiftBucket(DateTime(2026, 11, 30), TrendGranularity.day, 1),
        DateTime(2026, 12, 1),
      );
    });

    test('단위를 한 단계씩 거칠게·세밀하게', () {
      expect(TrendGranularity.day.coarser, TrendGranularity.week);
      expect(TrendGranularity.week.coarser, TrendGranularity.month);
      expect(TrendGranularity.month.coarser, TrendGranularity.month);
      expect(TrendGranularity.month.finer, TrendGranularity.week);
      expect(TrendGranularity.week.finer, TrendGranularity.day);
      expect(TrendGranularity.day.finer, TrendGranularity.day);
    });
  });

  group('trendDates', () {
    final lessons = [
      _lesson(DateTime(2026, 11, 2)),
      _lesson(DateTime(2026, 11, 3), status: ''),
      _lesson(DateTime(2026, 11, 4), status: 'no_show_deducted'),
    ];
    final created = [DateTime(2026, 10, 1)];

    test('완료는 completed만, 등록은 전부, 신규 회원은 회원 등록일', () {
      expect(
        trendDates(
          metric: TrendMetric.completed,
          lessons: lessons,
          memberCreatedAts: created,
        ),
        [DateTime(2026, 11, 2)],
      );
      expect(
        trendDates(
          metric: TrendMetric.registered,
          lessons: lessons,
          memberCreatedAts: created,
        ).length,
        3,
      );
      expect(
        trendDates(
          metric: TrendMetric.newMembers,
          lessons: lessons,
          memberCreatedAts: created,
        ),
        created,
      );
    });
  });

  group('buildTrendBuckets', () {
    final dates = [
      DateTime(2026, 11, 10, 9), // 화
      DateTime(2026, 11, 10, 18), // 화
      DateTime(2026, 11, 12), // 목
      DateTime(2026, 11, 3), // 지난주 화
      DateTime(2026, 9, 20),
    ];

    test('일별은 14칸이고 맨 오른쪽이 기준일', () {
      final buckets = buildTrendBuckets(
        dates: dates,
        granularity: TrendGranularity.day,
        anchor: DateTime(2026, 11, 12),
      );
      expect(buckets.length, 14);
      expect(buckets.last.start, DateTime(2026, 11, 12));
      expect(buckets.last.value, 1);
      expect(buckets[buckets.length - 3].value, 2); // 11/10
      expect(buckets.first.start, DateTime(2026, 10, 30));
    });

    test('주별은 12칸이고 같은 주 레슨이 합쳐진다', () {
      final buckets = buildTrendBuckets(
        dates: dates,
        granularity: TrendGranularity.week,
        anchor: DateTime(2026, 11, 12),
      );
      expect(buckets.length, 12);
      expect(buckets.last.start, DateTime(2026, 11, 9));
      expect(buckets.last.value, 3);
      expect(buckets[buckets.length - 2].value, 1); // 11/2 주
    });

    test('월별은 12칸이고 범위 밖 날짜는 세지 않는다', () {
      final buckets = buildTrendBuckets(
        dates: [...dates, DateTime(2024, 1, 1)],
        granularity: TrendGranularity.month,
        anchor: DateTime(2026, 11, 12),
      );
      expect(buckets.length, 12);
      expect(buckets.last.start, DateTime(2026, 11, 1));
      expect(buckets.last.value, 4);
      expect(buckets.first.start, DateTime(2025, 12, 1));
      expect(buckets.fold<int>(0, (s, b) => s + b.value), 5);
    });

    test('같은 레슨을 일·주·월로 묶은 합계는 보이는 범위 안에서 같다', () {
      int total(TrendGranularity g) => buildTrendBuckets(
        dates: dates.take(4),
        granularity: g,
        anchor: DateTime(2026, 11, 12),
      ).fold<int>(0, (s, b) => s + b.value);
      expect(total(TrendGranularity.day), 4);
      expect(total(TrendGranularity.week), 4);
      expect(total(TrendGranularity.month), 4);
    });
  });

  group('기준일 이동·제한', () {
    final today = DateTime(2026, 11, 12);
    final earliest = DateTime(2026, 8, 14);

    test('오늘보다 미래로는 갈 수 없다', () {
      expect(
        shiftTrendAnchor(
          anchor: today,
          granularity: TrendGranularity.week,
          steps: 3,
          today: today,
          earliest: earliest,
        ),
        today,
      );
    });

    test('지난 쪽으로 한 묶음 옮기면 그 묶음의 마지막 날이 기준일', () {
      final moved = shiftTrendAnchor(
        anchor: today,
        granularity: TrendGranularity.week,
        steps: -1,
        today: today,
        earliest: earliest,
      );
      expect(moved, DateTime(2026, 11, 8)); // 지난주 일요일
    });

    test('불러온 가장 이른 날보다 앞으로는 갈 수 없다', () {
      var anchor = today;
      for (var i = 0; i < 30; i++) {
        anchor = shiftTrendAnchor(
          anchor: anchor,
          granularity: TrendGranularity.day,
          steps: -1,
          today: today,
          earliest: earliest,
        );
      }
      final first =
          buildTrendBuckets(
            dates: const [],
            granularity: TrendGranularity.day,
            anchor: anchor,
          ).first.start;
      expect(first.isBefore(earliest), isFalse);
    });

    test('단위를 바꿔도 기준일이 오늘을 넘지 않는다', () {
      final clamped = clampTrendAnchor(
        anchor: DateTime(2026, 11, 12),
        granularity: TrendGranularity.month,
        today: today,
        earliest: DateTime(2025, 12, 1),
      );
      expect(clamped.isAfter(today), isFalse);
      expect(clamped.month, 11);
    });
  });
}
