import 'lesson_insights_stats.dart';

/// 인사이트 추이 차트의 묶음 단위. 두 손가락으로 모으면 일별 → 주별 → 월별로 거칠어진다.
enum TrendGranularity {
  day('일별', 14),
  week('주별', 12),
  month('월별', 12);

  const TrendGranularity(this.label, this.visibleCount);
  final String label;

  /// 한 화면에 보이는 묶음 수.
  final int visibleCount;

  /// 한 단계 더 거친 단위(월별이면 그대로).
  TrendGranularity get coarser => switch (this) {
    TrendGranularity.day => TrendGranularity.week,
    TrendGranularity.week => TrendGranularity.month,
    TrendGranularity.month => TrendGranularity.month,
  };

  /// 한 단계 더 세밀한 단위(일별이면 그대로).
  TrendGranularity get finer => switch (this) {
    TrendGranularity.day => TrendGranularity.day,
    TrendGranularity.week => TrendGranularity.day,
    TrendGranularity.month => TrendGranularity.week,
  };
}

/// 차트로 보는 값.
enum TrendMetric {
  completed('완료 레슨', '회'),
  registered('등록 레슨', '회'),
  newMembers('신규 회원', '명');

  const TrendMetric(this.label, this.unit);
  final String label;
  final String unit;
}

/// 묶음 하나: [start] 이상 [endExclusive] 미만.
class TrendBucket {
  const TrendBucket({
    required this.start,
    required this.endExclusive,
    required this.value,
  });

  final DateTime start;
  final DateTime endExclusive;
  final int value;
}

/// [date]가 속한 묶음의 시작일(일별: 그날, 주별: 월요일, 월별: 1일).
DateTime trendBucketStart(DateTime date, TrendGranularity granularity) {
  final day = DateTime(date.year, date.month, date.day);
  return switch (granularity) {
    TrendGranularity.day => day,
    TrendGranularity.week => DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - 1),
    ),
    TrendGranularity.month => DateTime(day.year, day.month),
  };
}

/// 묶음 시작일 다음 묶음의 시작일([steps]가 음수면 이전).
DateTime trendShiftBucket(
  DateTime start,
  TrendGranularity granularity,
  int steps,
) {
  return switch (granularity) {
    TrendGranularity.day => DateTime(
      start.year,
      start.month,
      start.day + steps,
    ),
    TrendGranularity.week => DateTime(
      start.year,
      start.month,
      start.day + 7 * steps,
    ),
    TrendGranularity.month => DateTime(start.year, start.month + steps),
  };
}

/// 차트에 쓸 날짜들: 지표에 맞는 항목의 날짜만 골라낸다.
List<DateTime> trendDates({
  required TrendMetric metric,
  required Iterable<LessonInsightEntry> lessons,
  required Iterable<DateTime> memberCreatedAts,
}) {
  switch (metric) {
    case TrendMetric.completed:
      return [
        for (final l in lessons)
          if (l.status == 'completed') l.startAt,
      ];
    case TrendMetric.registered:
      return [for (final l in lessons) l.startAt];
    case TrendMetric.newMembers:
      return [...memberCreatedAts];
  }
}

/// [anchor]가 속한 묶음을 맨 오른쪽으로 하고 그 앞으로 [granularity.visibleCount]개 묶음을 만든다.
List<TrendBucket> buildTrendBuckets({
  required Iterable<DateTime> dates,
  required TrendGranularity granularity,
  required DateTime anchor,
}) {
  final lastStart = trendBucketStart(anchor, granularity);
  final count = granularity.visibleCount;
  final firstStart = trendShiftBucket(lastStart, granularity, -(count - 1));
  final counts = <DateTime, int>{};
  for (final date in dates) {
    final key = trendBucketStart(date, granularity);
    if (key.isBefore(firstStart) || key.isAfter(lastStart)) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return [
    for (var i = 0; i < count; i++)
      () {
        final start = trendShiftBucket(firstStart, granularity, i);
        return TrendBucket(
          start: start,
          endExclusive: trendShiftBucket(start, granularity, 1),
          value: counts[start] ?? 0,
        );
      }(),
  ];
}

/// 보이는 구간의 맨 오른쪽 날짜([anchor])를 오늘 이전, 그리고 맨 왼쪽 묶음이 [earliest] 이후가
/// 되도록 맞춘다.
DateTime clampTrendAnchor({
  required DateTime anchor,
  required TrendGranularity granularity,
  required DateTime today,
  required DateTime earliest,
}) {
  var result = anchor.isAfter(today) ? today : anchor;
  final earliestStart = trendBucketStart(earliest, granularity);
  final count = granularity.visibleCount;
  for (var i = 0; i < count; i++) {
    final lastStart = trendBucketStart(result, granularity);
    final firstStart = trendShiftBucket(lastStart, granularity, -(count - 1));
    if (!firstStart.isBefore(earliestStart)) break;
    final nextStart = trendShiftBucket(lastStart, granularity, 1);
    if (nextStart.isAfter(today)) break;
    result = nextStart;
  }
  return result;
}

/// 묶음 단위로 [steps]만큼 옮긴 [anchor](양수는 미래 쪽). 결과는 마지막 묶음 안의 날짜다.
DateTime shiftTrendAnchor({
  required DateTime anchor,
  required TrendGranularity granularity,
  required int steps,
  required DateTime today,
  required DateTime earliest,
}) {
  final lastStart = trendBucketStart(anchor, granularity);
  final moved = trendShiftBucket(lastStart, granularity, steps);
  final clamped = clampTrendAnchor(
    anchor: moved,
    granularity: granularity,
    today: today,
    earliest: earliest,
  );
  // 묶음 안의 마지막 날로 맞춰 두면, 단위를 바꿔도 같은 기간 끝을 본다(오늘을 넘지 않는다).
  final bucketStart = trendBucketStart(clamped, granularity);
  final lastDay = trendShiftBucket(
    bucketStart,
    granularity,
    1,
  ).subtract(const Duration(days: 1));
  final day = DateTime(lastDay.year, lastDay.month, lastDay.day);
  return day.isAfter(today) ? today : day;
}
