import 'package:cloud_firestore/cloud_firestore.dart';

/// 회원 건강정보(`health`)에 쌓인 인바디 측정 이력의 한 건.
class InbodyHistoryPoint {
  const InbodyHistoryPoint({
    required this.measuredAt,
    this.heightCm,
    this.weightKg,
    this.skeletalMuscleKg,
    this.bodyFatPct,
    this.bodyFatKg,
    this.bmi,
    this.source = 'manual',
  });

  final DateTime measuredAt;
  final double? heightCm;
  final double? weightKg;
  final double? skeletalMuscleKg;
  final double? bodyFatPct;
  final double? bodyFatKg;
  final double? bmi;
  final String source;

  double? valueOf(InbodyMetric metric) => switch (metric) {
    InbodyMetric.weight => weightKg,
    InbodyMetric.skeletalMuscle => skeletalMuscleKg,
    InbodyMetric.bodyFatPercent => bodyFatPct,
  };
}

enum InbodyMetric {
  weight('체중', 'kg'),
  skeletalMuscle('골격근량', 'kg'),
  bodyFatPercent('체지방률', '%');

  const InbodyMetric(this.label, this.unit);
  final String label;
  final String unit;
}

DateTime? _asDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

double? _asPositive(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

InbodyHistoryPoint? _pointFrom(
  Map<dynamic, dynamic> map, {
  DateTime? fallbackDate,
}) {
  final at = _asDate(map['measuredAt']) ?? fallbackDate;
  if (at == null) return null;
  final point = InbodyHistoryPoint(
    measuredAt: DateTime(at.year, at.month, at.day),
    heightCm: _asPositive(map['heightCm']),
    weightKg: _asPositive(map['weightKg']),
    skeletalMuscleKg: _asPositive(map['skeletalMuscleKg']),
    bodyFatPct: _asPositive(map['bodyFatPct']),
    bodyFatKg: _asPositive(map['bodyFatKg']),
    bmi: _asPositive(map['bmi']),
    source: (map['source'] ?? 'manual').toString(),
  );
  final hasValue =
      point.weightKg != null ||
      point.skeletalMuscleKg != null ||
      point.bodyFatPct != null ||
      point.bodyFatKg != null ||
      point.heightCm != null;
  return hasValue ? point : null;
}

/// 회원 문서의 `health` 맵에서 인바디 이력을 측정일 순으로 읽는다.
///
/// 서버 이력(`inbodyHistory`)이 없으면 회원카드에서 직접 입력한 최신 값(`inbody` + 측정일)을
/// 한 건으로 본다. 측정일이 없는 값은 이력으로 쓰지 않는다.
List<InbodyHistoryPoint> parseInbodyHistory(Object? health) {
  if (health is! Map) return const <InbodyHistoryPoint>[];
  final result = <InbodyHistoryPoint>[];

  final raw = health['inbodyHistory'];
  if (raw is Iterable) {
    for (final item in raw) {
      if (item is! Map) continue;
      final point = _pointFrom(item);
      if (point != null) result.add(point);
    }
  }
  if (result.isEmpty && health['inbody'] is Map) {
    final point = _pointFrom(
      health['inbody'] as Map,
      fallbackDate: _asDate(health['inbodyMeasuredAt']),
    );
    if (point != null) result.add(point);
  }

  result.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  return result;
}

String inbodyDateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// 가장 최근 두 측정값의 차이(최신 - 직전). 비교할 값이 없으면 null.
double? inbodyMetricChange(
  List<InbodyHistoryPoint> points,
  InbodyMetric metric,
) {
  final values = [
    for (final point in points)
      if (point.valueOf(metric) != null) point.valueOf(metric)!,
  ];
  if (values.length < 2) return null;
  return values[values.length - 1] - values[values.length - 2];
}
