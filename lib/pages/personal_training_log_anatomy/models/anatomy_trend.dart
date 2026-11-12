import 'anatomy_log.dart';
import 'exercise_muscles.dart';

/// 운동 추이 지표(Flic식 1RM·최대 무게·볼륨·최대 횟수).
enum TrendMetric { oneRm, maxWeight, volume, maxReps }

String trendMetricLabel(TrendMetric metric) => switch (metric) {
  TrendMetric.oneRm => '추정 1RM',
  TrendMetric.maxWeight => '최대 무게',
  TrendMetric.volume => '볼륨',
  TrendMetric.maxReps => '최대 횟수',
};

String trendMetricUnit(TrendMetric metric) =>
    metric == TrendMetric.maxReps ? '회' : 'kg';

/// 운동 이름 비교용 정규화(공백 정리, 대소문자 무시).
String normalizeExerciseName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// 한 번의 레슨에서 한 운동을 한 기록 묶음. 같은 레슨에 같은 운동을 여러 번
/// 기록했으면 세트를 합친다.
class ExerciseSession {
  const ExerciseSession({
    required this.lessonLogId,
    required this.date,
    required this.sets,
  });

  final String lessonLogId;
  final DateTime date;
  final List<AnatomySet> sets;

  String get summary => anatomySetsSummary(sets);

  /// 이 레슨의 [metric] 값. 계산할 수 없으면(맨몸이라 무게가 없는 등) null.
  double? value(TrendMetric metric) {
    switch (metric) {
      case TrendMetric.oneRm:
        double? best;
        for (final set in sets) {
          final v = set.estimatedOneRepMaxKg;
          if (v != null && (best == null || v > best)) best = v;
        }
        return best;
      case TrendMetric.maxWeight:
        double best = 0;
        for (final set in sets) {
          if (set.weightKg > best) best = set.weightKg;
        }
        return best > 0 ? best : null;
      case TrendMetric.volume:
        final total = sets.fold<double>(0, (sum, s) => sum + s.volumeKg);
        return total > 0 ? total : null;
      case TrendMetric.maxReps:
        var best = 0;
        for (final set in sets) {
          if (set.reps > best) best = set.reps;
        }
        return best > 0 ? best.toDouble() : null;
    }
  }
}

class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// 운동 목록의 한 줄(운동 하나의 최근 상태).
class ExerciseOverview {
  const ExerciseOverview({required this.name, required this.sessions});

  /// 화면에 보이는 이름(가장 최근 기록의 표기).
  final String name;

  /// 날짜 오름차순.
  final List<ExerciseSession> sessions;

  ExerciseSession get last => sessions.last;

  ExerciseSession? get previous =>
      sessions.length >= 2 ? sessions[sessions.length - 2] : null;
}

/// 최근 집중 부위 한 줄.
class FocusEntry {
  const FocusEntry({
    required this.partId,
    required this.label,
    required this.sessions,
    required this.sets,
  });

  final String partId;
  final String label;

  /// 목표 부위로 운동한 레슨 수.
  final int sessions;
  final int sets;
}

/// 목표 부위를 정한 기록에서 보조 부위를 기억해 두는 값.
class RelatedMemory {
  const RelatedMemory({required this.mainPartId, required this.related});

  final String mainPartId;
  final List<String> related;
}

/// 한 회원의 아나토미 기록 전체(여러 레슨일지)와 그 위의 조회·계산.
class AnatomyMemberHistory {
  AnatomyMemberHistory(Iterable<AnatomyLogRecord> records)
    : records = List<AnatomyLogRecord>.unmodifiable(_sortedDesc(records));

  /// 서버에서 읽은 기록 중 [lessonLogId] 레슨의 것은 화면에서 편집 중인
  /// [current] 로 바꿔서(저장 전 변경도 반영) 이력을 만든다.
  factory AnatomyMemberHistory.merge({
    required Iterable<AnatomyLogRecord> fetched,
    required Iterable<AnatomyLogRecord> current,
    required String lessonLogId,
  }) => AnatomyMemberHistory([
    ...fetched.where((r) => r.lessonLogId != lessonLogId),
    ...current,
  ]);

  /// 최신순(같은 시각이면 만든 시각 최신순).
  final List<AnatomyLogRecord> records;

  static List<AnatomyLogRecord> _sortedDesc(Iterable<AnatomyLogRecord> input) {
    final list = List<AnatomyLogRecord>.of(input);
    list.sort((a, b) {
      final byDate = b.recordedAt.compareTo(a.recordedAt);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  bool get isEmpty => records.isEmpty;

  Iterable<AnatomyLogRecord> get _exerciseRecords => records.where(
    (r) =>
        r.recordType == AnatomyRecordType.exercise &&
        r.exerciseName.trim().isNotEmpty,
  );

  List<AnatomyLogRecord> byType(AnatomyRecordType type) =>
      records.where((r) => r.recordType == type).toList(growable: false);

  /// 최근에 한 운동 이름(최신순, 중복 제거).
  List<String> recentExerciseNames({int limit = 6}) {
    final seen = <String>{};
    final names = <String>[];
    for (final record in _exerciseRecords) {
      if (seen.add(normalizeExerciseName(record.exerciseName))) {
        names.add(record.exerciseName.trim());
        if (names.length >= limit) break;
      }
    }
    return names;
  }

  /// [name] 운동의 레슨별 기록(날짜 오름차순). 세트가 없는 기록은 뺀다.
  List<ExerciseSession> sessionsFor(String name) {
    final key = normalizeExerciseName(name);
    final byLesson = <String, List<AnatomyLogRecord>>{};
    for (final record in _exerciseRecords) {
      if (normalizeExerciseName(record.exerciseName) != key) continue;
      byLesson.putIfAbsent(record.lessonLogId, () => []).add(record);
    }
    final sessions = <ExerciseSession>[];
    for (final entry in byLesson.entries) {
      final sets = [for (final r in entry.value) ...r.sets];
      if (sets.isEmpty) continue;
      final date = entry.value
          .map((r) => r.recordedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      sessions.add(
        ExerciseSession(lessonLogId: entry.key, date: date, sets: sets),
      );
    }
    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  /// [lessonLogId] 레슨의 [name] 운동이 이 회원의 이전 기록보다 추정 1RM이 높아
  /// 최고 기록(PR)을 갱신했는지. 처음 한 운동이거나 1RM을 계산할 수 없으면 false.
  bool isPersonalRecord(String name, String lessonLogId) {
    final sessions = sessionsFor(name);
    final index = sessions.indexWhere((s) => s.lessonLogId == lessonLogId);
    if (index <= 0) return false;
    final current = sessions[index].value(TrendMetric.oneRm);
    if (current == null) return false;
    double? best;
    for (var i = 0; i < index; i++) {
      final value = sessions[i].value(TrendMetric.oneRm);
      if (value != null && (best == null || value > best)) best = value;
    }
    return best != null && current > best;
  }

  /// 브리핑에서 `최근 안 한 부위` 후보로 보는 큰 부위(손·발·전완 같은 작은 부위는 뺀다).
  static const List<String> briefingPartIds = [
    'chest',
    'delt_side',
    'lat',
    'upper_back',
    'biceps',
    'triceps',
    'abs',
    'lower_back',
    'quad',
    'hamstring',
    'glute',
    'calf',
  ];

  /// 최근 [days]일 동안 운동하지 않은 큰 부위의 이름(오래 쉰 순, 최대 [limit]개).
  /// 목표·함께 쓴 부위로 한 번이라도 썼으면 한 것으로 본다. 같은 기간에 통증·주의를
  /// 적은 부위는 운동을 권하지 않도록 뺀다. 운동 기록이 하나도 없으면 빈 목록.
  List<String> restedParts({DateTime? now, int days = 28, int limit = 3}) {
    final exerciseRecords = _exerciseRecords.toList();
    if (exerciseRecords.isEmpty) return const <String>[];
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final trained = <String>{};
    final protected = <String>{};
    final lastTrained = <String, DateTime>{};

    void mark(String id, DateTime at) {
      final ids = id == kCorePartId ? kCoreComponentParts : [id];
      for (final part in ids) {
        final previous = lastTrained[part];
        if (previous == null || at.isAfter(previous)) lastTrained[part] = at;
        if (!at.isBefore(cutoff)) trained.add(part);
      }
    }

    for (final record in exerciseRecords) {
      mark(record.bodyPartId, record.recordedAt);
      for (final id in record.relatedPartIds) {
        mark(id, record.recordedAt);
      }
    }
    for (final record in records) {
      if (record.recordedAt.isBefore(cutoff)) continue;
      if (record.recordType == AnatomyRecordType.pain ||
          record.recordType == AnatomyRecordType.caution) {
        protected.add(record.bodyPartId);
      }
    }

    final candidates = [
      for (final id in briefingPartIds)
        if (!trained.contains(id) && !protected.contains(id)) id,
    ];
    // 한 번도 안 한 부위가 가장 먼저, 그다음 마지막으로 한 날이 오래된 순.
    final order = {
      for (var i = 0; i < candidates.length; i++) candidates[i]: i,
    };
    candidates.sort((a, b) {
      final da = lastTrained[a];
      final db = lastTrained[b];
      if (da == null && db == null) return order[a]!.compareTo(order[b]!);
      if (da == null) return -1;
      if (db == null) return 1;
      final byDate = da.compareTo(db);
      return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
    });
    return bodyPartLabels(candidates.take(limit));
  }

  /// 지난번 레슨의 [name] 기록. [excludeLessonLogId] 레슨(지금 쓰는 레슨)은 뺀다.
  ExerciseSession? lastSession(String name, {String? excludeLessonLogId}) {
    final sessions =
        sessionsFor(
          name,
        ).where((s) => s.lessonLogId != excludeLessonLogId).toList();
    return sessions.isEmpty ? null : sessions.last;
  }

  List<TrendPoint> trend(String name, TrendMetric metric) => [
    for (final session in sessionsFor(name))
      if (session.value(metric) != null)
        TrendPoint(date: session.date, value: session.value(metric)!),
  ];

  /// 운동별 최근 상태(가장 최근에 한 운동이 위).
  List<ExerciseOverview> exercises() {
    final display = <String, String>{};
    for (final record in _exerciseRecords) {
      display.putIfAbsent(
        normalizeExerciseName(record.exerciseName),
        () => record.exerciseName.trim(),
      );
    }
    final overviews = <ExerciseOverview>[];
    for (final entry in display.entries) {
      final sessions = sessionsFor(entry.value);
      if (sessions.isEmpty) continue;
      overviews.add(ExerciseOverview(name: entry.value, sessions: sessions));
    }
    overviews.sort((a, b) => b.last.date.compareTo(a.last.date));
    return overviews;
  }

  /// 이 회원에게 [name] 운동을 마지막으로 기록했을 때의 목표·함께 쓴 부위.
  /// 내 운동처럼 기본 사용 부위가 없는 운동에서 지난번 선택을 다시 불러온다.
  RelatedMemory? lastRelatedFor(String name) {
    final key = normalizeExerciseName(name);
    for (final record in _exerciseRecords) {
      if (normalizeExerciseName(record.exerciseName) != key) continue;
      if (record.relatedPartIds.isEmpty) continue;
      return RelatedMemory(
        mainPartId: record.bodyPartId,
        related: record.relatedPartIds,
      );
    }
    return null;
  }

  /// 최근 [days]일 동안 목표 부위로 운동한 부위 순위(레슨 수, 세트 수 순).
  List<FocusEntry> focus({int days = 28, DateTime? now, int limit = 5}) {
    final since = (now ?? DateTime.now()).subtract(Duration(days: days));
    final lessons = <String, Set<String>>{};
    final sets = <String, int>{};
    final labels = <String, String>{};
    for (final record in records) {
      if (record.recordType != AnatomyRecordType.exercise) continue;
      if (record.recordedAt.isBefore(since)) continue;
      lessons
          .putIfAbsent(record.bodyPartId, () => <String>{})
          .add(record.lessonLogId);
      sets[record.bodyPartId] =
          (sets[record.bodyPartId] ?? 0) +
          (record.sets.isEmpty ? 1 : record.sets.length);
      labels.putIfAbsent(record.bodyPartId, () => record.bodyPartLabel);
    }
    final entries = [
      for (final id in lessons.keys)
        FocusEntry(
          partId: id,
          label: labels[id] ?? id,
          sessions: lessons[id]!.length,
          sets: sets[id] ?? 0,
        ),
    ];
    entries.sort((a, b) {
      final bySessions = b.sessions.compareTo(a.sessions);
      return bySessions != 0 ? bySessions : b.sets.compareTo(a.sets);
    });
    return entries.take(limit).toList(growable: false);
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// `2026.10.12` 형식.
String formatAnatomyDate(DateTime date) =>
    '${date.year}.${_two(date.month)}.${_two(date.day)}';

/// `10/12` 형식(그래프 축).
String formatAnatomyShortDate(DateTime date) => '${date.month}/${date.day}';

/// 숫자를 보기 좋게: 100 이상은 정수, 그보다 작으면 소수 한 자리(.0 은 생략).
String formatAnatomyNumber(double value) {
  if (value >= 100) return value.round().toString();
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}
