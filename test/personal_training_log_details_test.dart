import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/personal_training_log_details.dart';

void main() {
  final editorMap = <String, dynamic>{
    'title': '하체운동 + 근력',
    'inputMethod': 'category',
    'rawVoiceText': '',
    'issueChips': ['피로', 'PMS', '피로'],
    'homeworkStatus': '없음',
    'nextLessonCheckpoint': '무릎 통증 확인',
    'preCondition': '나쁨',
    'preMeal': '4시간 이상(공복)',
    'preSleep': '부족',
    'prePain': '있음',
    'prePainDetail': '오른쪽 어깨가 당김',
    'preStretching': '안 함',
    'duringGoals': ['근력'],
    'duringFocusParts': ['하체'],
    'duringReactions': <String>[],
    'duringPainDetail': '',
    'focusResponse': '보통',
    'cognitiveResponse': '인지 잘됨',
    'performanceResponse': '수행 좋음',
    'postPainChange': '없음',
    'postPerformance': '보통',
    'postNextAction': '유지',
    'postHomework': '없음',
    'internalMemo': '내부 기록',
    'publicSummary': '요약',
    'exercises': [
      {
        'main': '웨이트 트레이닝',
        'part': '하체',
        'name': '스쿼트',
        'sets': 3,
        'reps': 12,
        'assist': 2,
        'note': '무릎 정렬',
      },
    ],
  };

  test('에디터 map은 rules의 details 구조(최상위 + 묶음)로 바뀐다', () {
    final details = personalTrainingLogDetailsFromEditorMap(editorMap);

    expect(details['v'], 1);
    expect(details['title'], '하체운동 + 근력');
    expect(details['issueChips'], ['피로', 'PMS']);
    expect(details['pre'], {
      'condition': '나쁨',
      'meal': '4시간 이상(공복)',
      'sleep': '부족',
      'pain': '있음',
      'painDetail': '오른쪽 어깨가 당김',
      'stretching': '안 함',
    });
    expect(details['during'], {
      'goals': ['근력'],
      'focusParts': ['하체'],
      'focusResponse': '보통',
      'cognitiveResponse': '인지 잘됨',
      'performanceResponse': '수행 좋음',
    });
    expect(details['post'], {
      'painChange': '없음',
      'performance': '보통',
      'nextAction': '유지',
      'homework': '없음',
    });
    expect(details['notes'], {'internal': '내부 기록', 'publicSummary': '요약'});
    expect((details['exercises'] as List).single, {
      'main': '웨이트 트레이닝',
      'part': '하체',
      'name': '스쿼트',
      'sets': 3,
      'reps': 12,
      'assist': 2,
      'note': '무릎 정렬',
    });
    // rules가 허용하지 않는 최상위 키가 섞이지 않는다.
    expect(
      details.keys.toSet().difference({
        'v',
        'title',
        'inputMethod',
        'rawVoiceText',
        'issueChips',
        'homeworkStatus',
        'nextLessonCheckpoint',
        'exercises',
        'pre',
        'during',
        'post',
        'notes',
      }),
      isEmpty,
    );
  });

  test('저장했다가 다시 읽으면 에디터가 쓰는 값이 그대로 복원된다', () {
    final restored = editorMapFromPersonalTrainingLogDetails(
      personalTrainingLogDetailsFromEditorMap(editorMap),
    );

    for (final key in const [
      'title',
      'inputMethod',
      'homeworkStatus',
      'nextLessonCheckpoint',
      'preCondition',
      'preMeal',
      'preSleep',
      'prePain',
      'prePainDetail',
      'preStretching',
      'focusResponse',
      'cognitiveResponse',
      'performanceResponse',
      'postPainChange',
      'postPerformance',
      'postNextAction',
      'postHomework',
      'internalMemo',
      'publicSummary',
    ]) {
      expect(restored[key], editorMap[key], reason: key);
    }
    expect(restored['issueChips'], ['피로', 'PMS']);
    expect(restored['duringGoals'], ['근력']);
    expect(restored['duringFocusParts'], ['하체']);
    expect(restored.containsKey('duringReactions'), isFalse);
    expect((restored['exercises'] as List).single['name'], '스쿼트');
  });

  test('길이·개수 제한을 넘는 값은 잘라서 저장한다', () {
    final details = personalTrainingLogDetailsFromEditorMap({
      'title': '가' * 150,
      'nextLessonCheckpoint': '나' * 700,
      'issueChips': List.generate(30, (index) => '특이$index'),
      'exercises': List.generate(
        60,
        (index) => {'name': '운동$index', 'sets': 500, 'reps': 0},
      ),
    });

    expect((details['title'] as String).length, 100);
    expect((details['nextLessonCheckpoint'] as String).length, 500);
    expect((details['issueChips'] as List).length, 20);
    final exercises = details['exercises'] as List;
    expect(exercises.length, 40);
    expect(exercises.first['sets'], 99);
    expect(exercises.first['reps'], 1);
  });

  test('details가 없으면 빈 map이라 에디터 기본값이 쓰인다', () {
    expect(editorMapFromPersonalTrainingLogDetails(null), isEmpty);
    expect(editorMapFromPersonalTrainingLogDetails({'v': 1}), isEmpty);
  });

  test('이름 없는 운동은 버린다', () {
    final names =
        sanitizeLogExercises([
          {'name': '  '},
          'text',
          {'name': '플랭크'},
        ]).map((e) => e['name']).toList();
    expect(names, ['플랭크']);
  });
}
