import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_lesson_summary.dart';
import 'package:mtf_app/pages/personal_training_log_page.dart'
    show categoryShareLines, logSearchMatches, textLessonShareBody;
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_log.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/exercise_muscles.dart'
    show bodyPartLabels;
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_trend.dart';

AnatomyLogRecord _rec({
  required String lesson,
  required DateTime at,
  String exercise = '',
  AnatomyRecordType type = AnatomyRecordType.exercise,
  String id = '',
  String memo = '',
  int pain = 0,
  List<AnatomySet> sets = const [],
}) {
  return AnatomyLogRecord(
    anatomyLogId: id.isEmpty ? '$lesson-$exercise-${type.name}-$memo' : id,
    trainerId: 't',
    memberId: 'm',
    lessonLogId: lesson,
    scheduleDocId: '',
    recordedAt: at,
    bodyGender: BodyGender.male,
    bodyView: BodyView.front,
    bodySide: BodySide.both,
    bodyPartId: 'quad',
    bodyPartLabel: '대퇴사두',
    recordType: type,
    exerciseName: exercise,
    painLevel: pain,
    memo: memo,
    sets: sets,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  final t0 = DateTime(2026, 10, 12, 16);
  DateTime after(int minutes) => t0.add(Duration(minutes: minutes));

  group('AnatomyLessonSummary', () {
    test('운동 이름은 기록한 순서대로 중복 없이 슬래시로 잇는다', () {
      final summary = AnatomyLessonSummary.fromRecords([
        _rec(lesson: 'l1', at: after(3), exercise: '힙쓰러스트'),
        _rec(lesson: 'l1', at: after(1), exercise: ' 스쿼트 '),
        _rec(lesson: 'l1', at: after(5), exercise: '스쿼트', id: 'dup'),
        _rec(lesson: 'l1', at: after(7), exercise: '덤벨컬'),
      ]);
      expect(summary.exerciseNames, ['스쿼트', '힙쓰러스트', '덤벨컬']);
      expect(summary.exerciseLine, '스쿼트 / 힙쓰러스트 / 덤벨컬');
      expect(summary.hasNotes, isFalse);
    });

    test('통증·주의·가동성은 운동 이름에 섞이지 않고 개수로 센다', () {
      final summary = AnatomyLessonSummary.fromRecords([
        _rec(lesson: 'l1', at: after(1), exercise: '스쿼트'),
        _rec(
          lesson: 'l1',
          at: after(2),
          type: AnatomyRecordType.pain,
          memo: '무릎',
          pain: 4,
        ),
        _rec(
          lesson: 'l1',
          at: after(3),
          type: AnatomyRecordType.pain,
          memo: '허리',
          pain: 2,
        ),
        _rec(
          lesson: 'l1',
          at: after(4),
          type: AnatomyRecordType.caution,
          memo: '어깨 수술',
        ),
        _rec(
          lesson: 'l1',
          at: after(5),
          type: AnatomyRecordType.mobility,
          memo: '발목',
        ),
      ]);
      expect(summary.exerciseNames, ['스쿼트']);
      expect(summary.painCount, 2);
      expect(summary.cautionCount, 1);
      expect(summary.mobilityCount, 1);
      expect(summary.hasNotes, isTrue);
      expect(summary.pain.map((r) => r.memo), ['무릎', '허리']);
    });

    test('운동 이름이 비어 있는 기록은 이름에 넣지 않는다', () {
      final summary = AnatomyLessonSummary.fromRecords([
        _rec(lesson: 'l1', at: after(1), exercise: '  '),
      ]);
      expect(summary.exerciseNames, isEmpty);
      expect(summary.exerciseLine, '');
    });

    test('운동 수·세트 수·볼륨·운동 목록(부위 포함)을 센다', () {
      final summary = AnatomyLessonSummary.fromRecords([
        _rec(
          lesson: 'l1',
          at: after(1),
          exercise: '스쿼트',
          sets: const [
            AnatomySet(weightKg: 60, reps: 5),
            AnatomySet(weightKg: 60, reps: 5, assist: 2),
          ],
        ),
        _rec(
          lesson: 'l1',
          at: after(2),
          exercise: '푸쉬업',
          sets: const [AnatomySet(weightKg: 0, reps: 20)],
        ),
        _rec(
          lesson: 'l1',
          at: after(3),
          type: AnatomyRecordType.pain,
          memo: '무릎',
          sets: const [AnatomySet(weightKg: 999, reps: 9)],
        ),
      ]);
      expect(summary.setCount, 3);
      // 600 + 맨몸 0. 통증 기록은 세지 않고 보조 횟수는 볼륨에 넣지 않는다.
      expect(summary.volumeKg, 600);
      expect(summary.exerciseRows.map((r) => r.name), ['스쿼트', '푸쉬업']);
      expect(summary.exerciseRows.first.part, '대퇴사두');
    });

    test('회원의 전체 기록을 레슨일지 id별로 나눈다', () {
      final map = AnatomyLessonSummary.groupByLesson([
        _rec(lesson: 'l1', at: after(1), exercise: '스쿼트'),
        _rec(lesson: 'l2', at: after(2), exercise: '데드리프트'),
        _rec(
          lesson: 'l2',
          at: after(3),
          type: AnatomyRecordType.caution,
          memo: '허리',
        ),
        _rec(lesson: '  ', at: after(4), exercise: '버려짐'),
      ]);
      expect(map.keys.toSet(), {'l1', 'l2'});
      expect(map['l1']!.exerciseLine, '스쿼트');
      expect(map['l2']!.exerciseLine, '데드리프트');
      expect(map['l2']!.cautionCount, 1);
    });
  });

  group('MORE 레슨브리핑 데이터', () {
    AnatomyLogRecord rec(
      String lesson,
      DateTime at,
      String part, {
      String label = '',
      AnatomyRecordType type = AnatomyRecordType.exercise,
      List<String> related = const [],
      String title = '운동',
      BodySide side = BodySide.both,
      int pain = 0,
    }) => AnatomyLogRecord(
      anatomyLogId: '$lesson-$part-${type.name}-$title',
      trainerId: 't',
      memberId: 'm',
      lessonLogId: lesson,
      scheduleDocId: '',
      recordedAt: at,
      bodyGender: BodyGender.male,
      bodyView: BodyView.front,
      bodySide: side,
      bodyPartId: part,
      bodyPartLabel: label,
      recordType: type,
      exerciseName: title,
      painLevel: pain,
      memo: '',
      relatedPartIds: related,
      createdAt: at,
      updatedAt: at,
    );

    final now = DateTime(2026, 10, 14, 12);
    DateTime ago(int d) => now.subtract(Duration(days: d));

    test('최근 4주 안 한 큰 부위를 오래 쉰 순으로 최대 3개 보여준다', () {
      final history = AnatomyMemberHistory([
        rec('a', ago(2), 'quad', related: ['glute', 'hamstring']),
        rec('a', ago(2), 'chest'),
        rec('b', ago(40), 'lat'), // 4주보다 전: 쉰 부위, 마지막으로 한 날이 있다
        rec('c', ago(70), 'biceps'), // 더 오래 쉼
      ]);
      final rested = history.restedParts(now: now);
      expect(rested.length, 3);
      // 한 번도 안 한 부위가 먼저(목록 순서), 한 적 있는 부위는 오래 쉰 순
      final all = history.restedParts(now: now, limit: 20);
      expect(
        all,
        bodyPartLabels([
          'delt_side',
          'upper_back',
          'triceps',
          'abs',
          'lower_back',
          'calf',
          'biceps',
          'lat',
        ]),
      );
      expect(rested, all.take(3).toList());
    });

    test('코어를 함께 쓴 부위로 하면 복근·허리를 한 것으로 본다', () {
      final history = AnatomyMemberHistory([
        rec('a', ago(1), 'quad', related: ['core']),
      ]);
      final all = history.restedParts(now: now, limit: 20);
      expect(all, isNot(contains('복근')));
      expect(all, isNot(contains('기립근·허리')));
    });

    test('최근 통증·주의를 적은 부위는 쉬어간 부위로 권하지 않는다', () {
      final history = AnatomyMemberHistory([
        rec('a', ago(2), 'chest'),
        rec(
          'a',
          ago(2),
          'quad',
          type: AnatomyRecordType.pain,
          title: '무릎',
          pain: 4,
        ),
      ]);
      expect(history.restedParts(now: now, limit: 20), isNot(contains('대퇴사두')));
    });

    test('운동 기록이 없으면 빈 목록', () {
      expect(AnatomyMemberHistory(const []).restedParts(now: now), isEmpty);
      final onlyPain = AnatomyMemberHistory([
        rec('a', ago(2), 'quad', type: AnatomyRecordType.pain, title: '무릎'),
      ]);
      expect(onlyPain.restedParts(now: now), isEmpty);
    });

    test('모든 큰 부위를 했으면 빈 목록(고르게 운동한 상태)', () {
      final history = AnatomyMemberHistory([
        for (final part in AnatomyMemberHistory.briefingPartIds)
          rec('a', ago(3), part),
      ]);
      expect(history.restedParts(now: now), isEmpty);
    });

    test('지난 레슨의 통증·주의를 한 줄로 상기시킨다', () {
      final summary = AnatomyLessonSummary.fromRecords([
        rec(
          'a',
          ago(1),
          'quad',
          type: AnatomyRecordType.pain,
          title: '무릎',
          pain: 4,
          side: BodySide.left,
        ),
        rec(
          'a',
          ago(1),
          'delt_side',
          type: AnatomyRecordType.caution,
          title: '어깨 수술',
        ),
        rec('a', ago(1), 'quad', type: AnatomyRecordType.mobility, title: '발목'),
      ]);
      expect(summary.reminderText, '통증 왼쪽 무릎 4/10 · 주의 어깨 수술');
      expect(AnatomyLessonSummary.fromRecords(const []).reminderText, '');
    });
  });

  group('텍스트·카테고리 레슨 공유 내용', () {
    test('카테고리: 운동 이름과 세트×횟수(+보조)로 줄을 만든다', () {
      final lines = categoryShareLines([
        {'name': '스쿼트', 'sets': 3, 'reps': 12, 'assist': 0},
        {'name': '벤치프레스', 'sets': 4, 'reps': 8, 'assist': 2},
        {'name': ' ', 'sets': 3, 'reps': 10},
        {'name': '플랭크'},
      ]);
      expect(lines.map((l) => l.name), ['스쿼트', '벤치프레스', '플랭크']);
      expect(lines[0].summary, '3세트 × 12회');
      expect(lines[1].summary, '4세트 × 8회(+2)');
      expect(lines[2].summary, '');
    });

    test('텍스트: 회원 공개 메모가 있으면 그것만, 없으면 레슨 내용을 쓴다', () {
      expect(
        textLessonShareBody(
          inputMethod: 'text',
          publicSummary: '하체 위주로 진행했어요',
          publicGood: '자세가 좋아졌어요',
          publicHomeworkNote: '',
          publicCaution: '',
          memo: '무릎 통증 호소, 내부 확인 필요',
        ),
        '하체 위주로 진행했어요\n자세가 좋아졌어요',
      );
      expect(
        textLessonShareBody(
          inputMethod: 'voice_draft',
          publicSummary: ' ',
          publicGood: '',
          publicHomeworkNote: '',
          publicCaution: '',
          memo: '  스쿼트 위주로 했어요  ',
        ),
        '스쿼트 위주로 했어요',
      );
    });

    test('카테고리는 글 없이 운동 목록만 보낸다', () {
      expect(
        textLessonShareBody(
          inputMethod: 'category',
          publicSummary: '공개',
          publicGood: '',
          publicHomeworkNote: '',
          publicCaution: '',
          memo: '내용',
        ),
        '',
      );
    });
  });

  group('레슨일지 검색', () {
    final summary = AnatomyLessonSummary.fromRecords([
      _rec(lesson: 'l1', at: after(1), exercise: '스쿼트'),
      _rec(
        lesson: 'l1',
        at: after(2),
        type: AnatomyRecordType.pain,
        exercise: '무릎',
        memo: '내려갈 때 시큰',
      ),
      _rec(
        lesson: 'l1',
        at: after(3),
        type: AnatomyRecordType.mobility,
        exercise: '발목 굽히기',
      ),
    ]);

    test('아나토미 레슨은 운동 이름과 붙여 쓴 통증 검색어(스쿼트 무릎통증)로 찾힌다', () {
      final text = summary.searchText;
      expect(logSearchMatches(text, '스쿼트 무릎통증'), isTrue);
      expect(logSearchMatches(text, '무릎 통증'), isTrue);
      expect(logSearchMatches(text, '시큰'), isTrue);
      expect(logSearchMatches(text, '발목 가동성'), isTrue);
      expect(logSearchMatches(text, '대퇴사두'), isTrue);
      expect(logSearchMatches(text, '스쿼트 어깨통증'), isFalse);
    });

    test('붙여 쓴 검색어는 띄어 쓴 메모에서도, 띄어 쓴 검색어는 붙여 쓴 메모에서도 찾는다', () {
      expect(logSearchMatches('스쿼트 · 무릎 통증 호소', '스쿼트 무릎통증'), isTrue);
      expect(logSearchMatches('무릎통증 있음', '무릎 통증'), isTrue);
      expect(logSearchMatches('힙쓰러스트 40kg', '스쿼트'), isFalse);
      expect(logSearchMatches('아무 글자', ''), isTrue);
      expect(logSearchMatches('Squat 무릎', 'SQUAT'), isTrue);
    });
  });

  group('최고 기록(PR)', () {
    AnatomyLogRecord squat(String lesson, DateTime at, double kg, int reps) =>
        _rec(
          lesson: lesson,
          at: at,
          exercise: '스쿼트',
          sets: [AnatomySet(weightKg: kg, reps: reps)],
        );
    final records = [
      squat('l1', DateTime(2026, 9, 1, 16), 60, 10),
      squat('l2', DateTime(2026, 9, 8, 16), 70, 10),
      squat('l3', DateTime(2026, 9, 15, 16), 65, 10),
    ];

    test('이전 기록보다 추정 1RM이 높을 때만 PR이다(처음 한 운동은 아니다)', () {
      final history = AnatomyMemberHistory(records);
      expect(history.isPersonalRecord('스쿼트', 'l1'), isFalse);
      expect(history.isPersonalRecord('스쿼트', 'l2'), isTrue);
      expect(history.isPersonalRecord('스쿼트', 'l3'), isFalse);
      expect(history.isPersonalRecord('스쿼트', 'none'), isFalse);
      expect(history.isPersonalRecord('데드리프트', 'l2'), isFalse);
    });

    test('같은 무게를 반복하거나 1RM을 계산할 수 없으면 PR이 아니다', () {
      final same = AnatomyMemberHistory([
        squat('a', DateTime(2026, 9, 1), 60, 10),
        squat('b', DateTime(2026, 9, 8), 60, 10),
      ]);
      expect(same.isPersonalRecord('스쿼트', 'b'), isFalse);
      final highReps = AnatomyMemberHistory([
        squat('a', DateTime(2026, 9, 1), 20, 20),
        squat('b', DateTime(2026, 9, 8), 30, 20),
      ]);
      expect(highReps.isPersonalRecord('스쿼트', 'b'), isFalse);
    });

    test('레슨 요약의 운동 목록에 PR 표시가 붙는다', () {
      final map = AnatomyLessonSummary.groupByLesson(records);
      expect(map['l2']!.prExercises, {'스쿼트'});
      expect(map['l2']!.exerciseRows.single.pr, isTrue);
      expect(map['l1']!.prExercises, isEmpty);
      expect(map['l3']!.exerciseRows.single.pr, isFalse);
    });
  });

  group('세트 보조 횟수', () {
    test('보조가 있을 때만 저장하고 읽는다', () {
      expect(const AnatomySet(weightKg: 40, reps: 8).toMap(), {
        'w': 40.0,
        'r': 8,
      });
      final withAssist = const AnatomySet(weightKg: 40, reps: 8, assist: 2);
      expect(withAssist.toMap(), {'w': 40.0, 'r': 8, 'a': 2});
      expect(AnatomySet.fromMap(withAssist.toMap()), withAssist);
      // 예전 기록(보조 없음)과 범위 밖 값
      expect(AnatomySet.fromMap({'w': 40, 'r': 8})!.assist, 0);
      expect(AnatomySet.fromMap({'w': 40, 'r': 8, 'a': -1})!.assist, 0);
      expect(AnatomySet.fromMap({'w': 40, 'r': 8, 'a': 500})!.assist, 0);
    });

    test('요약은 혼자 한 횟수 뒤에 (+보조)를 붙이고 볼륨·1RM에는 넣지 않는다', () {
      expect(
        anatomySetsSummary(const [
          AnatomySet(weightKg: 40, reps: 8, assist: 2),
          AnatomySet(weightKg: 40, reps: 8),
        ]),
        '2 X 40kg | 16(+2)회',
      );
      expect(
        anatomySetsSummary(const [
          AnatomySet(weightKg: 0, reps: 10, assist: 3),
        ]),
        '1세트 | 10(+3)회',
      );
      const set = AnatomySet(weightKg: 40, reps: 8, assist: 2);
      expect(set.volumeKg, 320);
      expect(set.estimatedOneRepMaxKg, closeTo(40 * (1 + 8 / 30), 0.0001));
    });
  });

  group('부위 이름', () {
    test('저장된 옛 이름 대신 현재 이름(윗등)으로 읽는다', () {
      final record = AnatomyLogRecord.fromFirestore(<String, dynamic>{
        'anatomyLogId': 'a1',
        'bodyPartId': 'upper_back',
        'bodyPartLabel': '어퍼백',
      });
      expect(record.bodyPartLabel, '윗등');
    });

    test('목록에 없는 부위 id 는 저장된 이름을 그대로 쓴다', () {
      final record = AnatomyLogRecord.fromFirestore(<String, dynamic>{
        'anatomyLogId': 'a2',
        'bodyPartId': 'unknown_part',
        'bodyPartLabel': '예전 부위',
      });
      expect(record.bodyPartLabel, '예전 부위');
    });
  });

  group('레슨일지 카드 소스 가드', () {
    final source = File(
      'lib/pages/personal_training_log_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    test('회원·담당자 서명 칸과 서명 동작은 그대로 있다', () {
      expect(source, contains("label: '회원 서명'"));
      expect(source, contains("label: '담당자 서명'"));
      expect(
        source,
        contains("onTapCustomerSig: () => _tapSig(log, 'customer')"),
      );
      expect(
        source,
        contains("onTapTrainerSig: () => _tapSig(log, 'trainer')"),
      );
      // 서명 칸 크기(130x52)를 줄이지 않는다.
      expect(source, contains('width: 130,'));
      expect(source, contains('height: 52,'));
    });

    test('월 구분 머리말 글자는 다크모드에서 선과 같은 색이다', () {
      final start = source.indexOf('Widget _buildTimelineSectionHeader(');
      expect(start, greaterThan(0));
      final end = source.indexOf('Uint8List _dataUrlToBytes', start);
      final body = source.substring(start, end);
      expect(body, contains('Brightness.dark'));
      expect(body, contains('? lineColor'));
      expect(body, contains('color: lineColor'));
    });

    test('펼친 아나토미 카드의 글자는 배경에 맞춰 테마 색을 쓴다', () {
      final start = source.indexOf('Widget _anatomyNoteChips(');
      final end = source.indexOf('String _memoSummary(', start);
      final body = source.substring(start, end);
      expect(body, contains('scheme.onSurfaceVariant'));
      expect(body, contains('scheme.onSurface'));
      // 배경 위에 바로 놓이는 글자에 어두운 고정색을 쓰지 않는다(흰 상자 안 글자는 예외)
      expect(body.contains('Colors.black45'), isFalse);
    });

    test('예시(가짜) 레슨일지를 목록에 넣지 않는다', () {
      expect(source, isNot(contains('김유신')));
      expect(source, isNot(contains('_logs.addAll([')));
      expect(source, isNot(contains('performanceScore: 8.5')));
    });

    test('서비스·노쇼 카드의 배경은 다크모드에서 어두운 상태 색을 쓴다', () {
      final start = source.indexOf(
        'Widget build(BuildContext context) {\n    final colorSet = _colorSetForSessionType',
      );
      expect(start, greaterThan(0));
      final body = source.substring(start, start + 2500);
      expect(body, contains('final dark = Theme.of(context).brightness'));
      for (final light in ['0xFFF0FDFA', '0xFFFEF2F2', '0xFFFFFBEB']) {
        expect(body, contains('dark ? const Color'), reason: light);
        expect(body, contains(light));
      }
      expect(body, contains('0xFF0F2E2B'));
      expect(body, contains('0xFF3A1F22'));
      expect(body, contains('0xFF3A2D14'));
    });

    test('작성 방식 표시: TEXT/VOICE·CATEGORY·PDF·ANATOMY NOTE', () {
      expect(source, contains("'TEXT/VOICE NOTE'"));
      expect(source, contains("'CATEGORY NOTE'"));
      expect(source, contains("'PDF NOTE'"));
      expect(source, contains("'ANATOMY NOTE'"));
      expect(source, isNot(contains("'TAG NOTE'")));
      expect(source, isNot(contains("'TEXT NOTE'")));
    });

    test('MORE 레슨브리핑: 이름만 있는 토글·끌어서 열고 닫기·글자 색', () {
      expect(source, contains("'MORE 레슨브리핑'"));
      // 타원과 보기/닫기 글자는 없다
      expect(source, isNot(contains('MORE 브리핑 보기')));
      expect(source, isNot(contains('MORE 브리핑 닫기')));
      expect(source, isNot(contains('레슨 상세 정보 보기')));
      expect(
        source,
        contains("key: const ValueKey<String>('log_header_swipe')"),
      );
      expect(source, contains('velocity < -250'));
      expect(source, contains('velocity > 250'));
      // 일반 카드 펼침의 '레슨 내용' 소제목은 배경에 맞춰 테마 색
      final start = source.indexOf("'레슨 내용',");
      final body = source.substring(start, start + 200);
      expect(body, contains('scheme.onSurface'));
    });

    test('아나토미 카드는 탭하면 레슨일지가 열리고 펼침은 화살표로 한다', () {
      expect(
        source,
        contains(
          "if (log.inputMethod == 'anatomy') {\n                _openAnatomyLogPage(log);",
        ),
      );
      expect(
        source,
        contains("key: const ValueKey<String>('log_card_expand')"),
      );
      expect(source, contains('onToggleExpand'));
    });

    test('펼친 아나토미 카드에는 세트·무게·횟수 표를 넣지 않는다', () {
      final start = source.indexOf('List<Widget> _anatomyDetailWidgets(');
      expect(start, greaterThan(0));
      final end = source.indexOf('String _memoSummary(', start);
      final body = source.substring(start, end);
      expect(body.contains('.sets'), isFalse);
      expect(body.contains('anatomySetsSummary'), isFalse);
    });
  });
}
