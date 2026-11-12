// 레슨일지 세부 기록(details)의 저장 형식.
//
// 레슨일지 에디터(텍스트·카테고리)는 평평한 map(`preCondition`, `postHomework` ...)을
// 돌려주고, Firestore에는 firestore.rules의 `details` 구조(최상위 + pre/during/post/notes
// 묶음)로 저장한다. 이 파일이 두 형식을 서로 바꾼다.

const int kPersonalTrainingLogDetailsVersion = 1;

const int _titleMax = 100;
const int _inputMethodMax = 20;
const int _rawVoiceTextMax = 4000;
const int _checkpointMax = 500;
const int _shortMax = 40;
const int _noteMax = 1000;
const int _listMax = 20;
const int _exerciseMax = 40;

// 에디터 평면 키 → (묶음, 묶음 안 키)
const Map<String, (String, String)> _groupedKeys = {
  'preCondition': ('pre', 'condition'),
  'preMeal': ('pre', 'meal'),
  'preSleep': ('pre', 'sleep'),
  'prePain': ('pre', 'pain'),
  'prePainDetail': ('pre', 'painDetail'),
  'preStretching': ('pre', 'stretching'),
  'preNote': ('pre', 'note'),
  'duringPainDetail': ('during', 'painDetail'),
  'focusResponse': ('during', 'focusResponse'),
  'cognitiveResponse': ('during', 'cognitiveResponse'),
  'performanceResponse': ('during', 'performanceResponse'),
  'postPainChange': ('post', 'painChange'),
  'postPainDetail': ('post', 'painDetail'),
  'postPerformance': ('post', 'performance'),
  'postNextAction': ('post', 'nextAction'),
  'postHomework': ('post', 'homework'),
  'internalMemo': ('notes', 'internal'),
  'publicSummary': ('notes', 'publicSummary'),
  'publicGood': ('notes', 'publicGood'),
  'publicHomeworkNote': ('notes', 'publicHomeworkNote'),
  'publicCaution': ('notes', 'publicCaution'),
};

const Map<String, (String, String)> _groupedLists = {
  'duringGoals': ('during', 'goals'),
  'duringFocusParts': ('during', 'focusParts'),
  'duringReactions': ('during', 'reactions'),
};

String _clip(Object? value, int max) {
  final text = (value ?? '').toString().trim();
  return text.length <= max ? text : text.substring(0, max);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  final result = <String>[];
  for (final item in value) {
    final text = _clip(item, _shortMax);
    if (text.isNotEmpty && !result.contains(text)) result.add(text);
    if (result.length >= _listMax) break;
  }
  return result;
}

int _boundedInt(Object? value, int min, int max, int fallback) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null) return fallback;
  return parsed.clamp(min, max);
}

/// 운동 구성 항목을 저장 가능한 형태로 정리한다.
List<Map<String, dynamic>> sanitizeLogExercises(Object? raw) {
  if (raw is! Iterable) return const <Map<String, dynamic>>[];
  final result = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = _clip(item['name'], _shortMax);
    if (name.isEmpty) continue;
    result.add({
      'main': _clip(item['main'], _shortMax),
      'part': _clip(item['part'], _shortMax),
      'name': name,
      'sets': _boundedInt(item['sets'], 1, 99, 3),
      'reps': _boundedInt(item['reps'], 1, 999, 12),
      'assist': _boundedInt(item['assist'], 0, 99, 0),
      if (_clip(item['note'], _noteMax).isNotEmpty)
        'note': _clip(item['note'], _noteMax),
    });
    if (result.length >= _exerciseMax) break;
  }
  return result;
}

/// 에디터가 돌려준 평면 map을 Firestore `details` 형식으로 바꾼다.
Map<String, dynamic> personalTrainingLogDetailsFromEditorMap(
  Map<String, dynamic> map,
) {
  final groups = <String, Map<String, dynamic>>{
    'pre': {},
    'during': {},
    'post': {},
    'notes': {},
  };

  _groupedKeys.forEach((flatKey, target) {
    if (!map.containsKey(flatKey)) return;
    final text = _clip(map[flatKey], _noteMax);
    if (text.isEmpty) return;
    groups[target.$1]![target.$2] = text;
  });
  _groupedLists.forEach((flatKey, target) {
    if (!map.containsKey(flatKey)) return;
    final list = _stringList(map[flatKey]);
    if (list.isEmpty) return;
    groups[target.$1]![target.$2] = list;
  });

  final details = <String, dynamic>{'v': kPersonalTrainingLogDetailsVersion};
  void putText(String key, Object? value, int max) {
    final text = _clip(value, max);
    if (text.isNotEmpty) details[key] = text;
  }

  putText('title', map['title'], _titleMax);
  putText('inputMethod', map['inputMethod'], _inputMethodMax);
  putText('rawVoiceText', map['rawVoiceText'], _rawVoiceTextMax);
  putText('homeworkStatus', map['homeworkStatus'], _inputMethodMax);
  putText('nextLessonCheckpoint', map['nextLessonCheckpoint'], _checkpointMax);

  final chips = _stringList(map['issueChips']);
  if (chips.isNotEmpty) details['issueChips'] = chips;

  final exercises = sanitizeLogExercises(map['exercises']);
  if (exercises.isNotEmpty) details['exercises'] = exercises;

  groups.forEach((name, value) {
    if (value.isNotEmpty) details[name] = value;
  });
  return details;
}

/// Firestore `details`를 에디터가 읽는 평면 map으로 되돌린다.
/// 저장된 값이 없는 키는 포함하지 않아 에디터의 기본값이 쓰인다.
Map<String, dynamic> editorMapFromPersonalTrainingLogDetails(
  Map<String, dynamic>? details,
) {
  final result = <String, dynamic>{};
  if (details == null) return result;

  for (final key in const [
    'title',
    'inputMethod',
    'rawVoiceText',
    'homeworkStatus',
    'nextLessonCheckpoint',
  ]) {
    final value = details[key];
    if (value is String && value.isNotEmpty) result[key] = value;
  }
  final chips = _stringList(details['issueChips']);
  if (chips.isNotEmpty) result['issueChips'] = chips;
  final exercises = sanitizeLogExercises(details['exercises']);
  if (exercises.isNotEmpty) result['exercises'] = exercises;

  Map<String, dynamic> group(String name) {
    final raw = details[name];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  _groupedKeys.forEach((flatKey, target) {
    final value = group(target.$1)[target.$2];
    if (value is String && value.isNotEmpty) result[flatKey] = value;
  });
  _groupedLists.forEach((flatKey, target) {
    final list = _stringList(group(target.$1)[target.$2]);
    if (list.isNotEmpty) result[flatKey] = list;
  });
  return result;
}
