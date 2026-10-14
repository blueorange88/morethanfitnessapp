import 'anatomy_log.dart';
import 'anatomy_trend.dart';

/// 레슨일지 목록 카드에 보여줄 한 레슨의 아나토미 기록 요약.
///
/// 운동 이름은 기록한 순서대로 중복 없이 모으고, 통증·주의·가동성은 개수와
/// 상세 목록을 따로 둔다. 세트·무게·횟수는 여기에 담지 않는다(저장한 레슨일지에서 본다).
class AnatomyLessonSummary {
  const AnatomyLessonSummary({
    this.exerciseNames = const <String>[],
    this.pain = const <AnatomyLogRecord>[],
    this.caution = const <AnatomyLogRecord>[],
    this.mobility = const <AnatomyLogRecord>[],
    this.records = const <AnatomyLogRecord>[],
    this.prExercises = const <String>{},
  });

  final List<String> exerciseNames;
  final List<AnatomyLogRecord> pain;
  final List<AnatomyLogRecord> caution;
  final List<AnatomyLogRecord> mobility;

  /// 이 레슨의 기록 전체(펼친 카드의 작은 몸 그림용).
  final List<AnatomyLogRecord> records;

  /// 이 레슨에서 최고 기록(PR)을 갱신한 운동 이름.
  final Set<String> prExercises;

  int get painCount => pain.length;
  int get cautionCount => caution.length;
  int get mobilityCount => mobility.length;

  bool get hasNotes => painCount + cautionCount + mobilityCount > 0;

  Iterable<AnatomyLogRecord> get _exerciseRecords =>
      records.where((r) => r.recordType == AnatomyRecordType.exercise);

  /// 이 레슨의 전체 세트 수(운동 기록의 세트를 모두 센다).
  int get setCount =>
      _exerciseRecords.fold<int>(0, (total, r) => total + r.sets.length);

  /// 이 레슨의 전체 볼륨(kg): 세트마다 무게 × 혼자 한 횟수의 합. 맨몸은 0.
  double get volumeKg => _exerciseRecords.fold<double>(
    0,
    (total, r) => total + r.sets.fold<double>(0, (t, s) => t + s.volumeKg),
  );

  /// 레슨일지 검색에 쓰는 글자: 운동 이름·부위, 통증·주의·가동성의 글자·메모·좌우.
  /// `무릎통증`, `왼쪽무릎통증` 처럼 붙여 쓴 검색어도 찾히게 이름과 종류를 이어 붙인 것도 넣는다.
  String get searchText {
    final parts = <String>[...exerciseNames];
    for (final row in exerciseRows) {
      parts.add(row.part);
    }
    void notes(String label, List<AnatomyLogRecord> list) {
      for (final record in list) {
        final title = record.exerciseName.trim();
        final side = switch (record.bodySide) {
          BodySide.left => '왼쪽',
          BodySide.right => '오른쪽',
          _ => '',
        };
        parts.addAll([
          label,
          title,
          record.memo,
          record.bodyPartLabel,
          '${side}${title}',
          '${title}${label}',
          '${side}${title}${label}',
          '${record.bodyPartLabel}${label}',
          '${label} ${title}',
        ]);
      }
    }

    notes('통증', pain);
    notes('주의', caution);
    notes('가동성', mobility);
    return parts.where((p) => p.trim().isNotEmpty).join(' ');
  }

  /// 다음 레슨 전에 상기시킬 통증·주의: `통증 왼쪽 무릎 4/10 · 주의 어깨`. 없으면 빈 글자.
  String get reminderText {
    String name(AnatomyLogRecord record) {
      final side = switch (record.bodySide) {
        BodySide.left => '왼쪽 ',
        BodySide.right => '오른쪽 ',
        _ => '',
      };
      final title = record.exerciseName.trim();
      return '${side}${title.isEmpty ? record.bodyPartLabel : title}';
    }

    final parts = <String>[
      if (pain.isNotEmpty)
        '통증 ${pain.map((r) => '${name(r)} ${r.painLevel}/10').join(', ')}',
      if (caution.isNotEmpty) '주의 ${caution.map(name).join(', ')}',
    ];
    return parts.join(' · ');
  }

  /// 운동 이름과 그 운동의 목표 부위 이름(기록한 순서, 중복 없이).
  List<({String name, String part, bool pr})> get exerciseRows {
    final rows = <({String name, String part, bool pr})>[];
    final seen = <String>{};
    for (final record in _exerciseRecords) {
      final name = record.exerciseName.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      rows.add((
        name: name,
        part: record.bodyPartLabel,
        pr: prExercises.contains(name),
      ));
    }
    return rows;
  }

  /// `스쿼트 / 힙쓰러스트 / 덤벨컬` 처럼 슬래시로 이은 운동 이름.
  String get exerciseLine => exerciseNames.join(' / ');

  /// 한 레슨의 기록으로 요약을 만든다.
  ///
  /// [history] 와 [lessonLogId] 를 주면 이 레슨에서 최고 기록(PR)을 갱신한 운동도 계산한다.
  factory AnatomyLessonSummary.fromRecords(
    Iterable<AnatomyLogRecord> records, {
    AnatomyMemberHistory? history,
    String? lessonLogId,
  }) {
    final ordered =
        records.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final names = <String>[];
    final pain = <AnatomyLogRecord>[];
    final caution = <AnatomyLogRecord>[];
    final mobility = <AnatomyLogRecord>[];
    for (final record in ordered) {
      switch (record.recordType) {
        case AnatomyRecordType.exercise:
          final name = record.exerciseName.trim();
          if (name.isNotEmpty && !names.contains(name)) names.add(name);
        case AnatomyRecordType.pain:
          pain.add(record);
        case AnatomyRecordType.caution:
          caution.add(record);
        case AnatomyRecordType.mobility:
          mobility.add(record);
      }
    }
    return AnatomyLessonSummary(
      exerciseNames: names,
      pain: pain,
      caution: caution,
      mobility: mobility,
      records: ordered,
      prExercises: {
        if (history != null && lessonLogId != null)
          for (final name in names)
            if (history.isPersonalRecord(name, lessonLogId)) name,
      },
    );
  }

  /// 한 회원의 전체 기록을 레슨일지 id별 요약으로 나눈다.
  static Map<String, AnatomyLessonSummary> groupByLesson(
    Iterable<AnatomyLogRecord> records,
  ) {
    final all = records.toList();
    final history = AnatomyMemberHistory(all);
    final byLesson = <String, List<AnatomyLogRecord>>{};
    for (final record in all) {
      final id = record.lessonLogId.trim();
      if (id.isEmpty) continue;
      byLesson.putIfAbsent(id, () => <AnatomyLogRecord>[]).add(record);
    }
    return {
      for (final entry in byLesson.entries)
        entry.key: AnatomyLessonSummary.fromRecords(
          entry.value,
          history: history,
          lessonLogId: entry.key,
        ),
    };
  }
}
