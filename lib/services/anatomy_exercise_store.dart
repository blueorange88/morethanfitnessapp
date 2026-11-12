import 'personal_custom_exercise_service.dart';

/// 아나토미 입력 창의 "내 운동"·위치 칩·검사 칩 저장소. 키는 `a:부위id`(운동),
/// `p:부위id`(위치 칩), `t:mobility`(가동성 검사 칩) 같은 구분 문자열이다.
abstract interface class AnatomyExerciseStore {
  Future<Map<String, List<String>>> load();

  Future<void> save(Map<String, List<String>> exercises);
}

/// 기존 개인 강사 내 운동 목록(서버 저장)을 그대로 쓴다.
class PersonalAnatomyExerciseStore implements AnatomyExerciseStore {
  PersonalAnatomyExerciseStore(this._service);

  final PersonalCustomExerciseService _service;

  @override
  Future<Map<String, List<String>>> load() => _service.load();

  /// 서버에는 레슨일지 카테고리용 목록과 한 문서에 같이 있으므로, 불러온 전체
  /// 목록 위에 아나토미 항목만 덮어써서 저장한다.
  @override
  Future<void> save(Map<String, List<String>> exercises) async {
    final current = await _service.load();
    final merged = Map<String, List<String>>.of(current);
    for (final entry in exercises.entries) {
      // a: 운동, p: 위치 칩, t: 가동성 검사 칩
      if (const ['a:', 'p:', 't:'].any(entry.key.startsWith)) {
        merged[entry.key] = entry.value;
      }
    }
    await _service.save(merged);
  }
}
