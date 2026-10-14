import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'mtf_firebase_functions.dart';

const int kCustomExerciseMaxPerPart = 30;
const int kCustomExerciseMaxLength = 40;

String normalizeCustomExerciseName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String customExerciseComparisonKey(String value) {
  return normalizeCustomExerciseName(value).toLowerCase();
}

/// 부위별 사용자 지정 운동 목록을 정규화한다. 서버 검증과 같은 기준으로
/// 빈 값·40자 초과·중복은 버리고, 부위당 30개까지만 남긴다.
Map<String, List<String>> normalizeCustomExercises(Object? raw) {
  if (raw is! Map) return const <String, List<String>>{};
  final result = <String, List<String>>{};
  for (final entry in raw.entries) {
    final part = normalizeCustomExerciseName(entry.key.toString());
    final list = entry.value;
    if (part.isEmpty || part.length > 20 || list is! Iterable) continue;
    final seen = <String>{};
    final values = <String>[];
    for (final item in list) {
      final value = normalizeCustomExerciseName(item.toString());
      if (value.isEmpty || value.length > kCustomExerciseMaxLength) continue;
      if (!seen.add(customExerciseComparisonKey(value))) continue;
      values.add(value);
      if (values.length >= kCustomExerciseMaxPerPart) break;
    }
    if (values.isNotEmpty) result[part] = values;
  }
  return result;
}

/// 추가하려는 운동 이름을 검증한다. 문제가 있으면 안내 문구를, 없으면 null.
String? validateNewCustomExercise({
  required String name,
  required Iterable<String> builtInExercises,
  required Iterable<String> currentCustomExercises,
}) {
  final normalized = normalizeCustomExerciseName(name);
  if (normalized.isEmpty) return '운동 이름을 입력해주세요.';
  if (normalized.length > kCustomExerciseMaxLength) {
    return '운동 이름은 $kCustomExerciseMaxLength자 이하로 입력해주세요.';
  }
  final key = customExerciseComparisonKey(normalized);
  final exists = [
    ...builtInExercises,
    ...currentCustomExercises,
  ].any((item) => customExerciseComparisonKey(item) == key);
  if (exists) return '이미 있는 운동이에요.';
  if (currentCustomExercises.length >= kCustomExerciseMaxPerPart) {
    return '부위당 내 운동은 $kCustomExerciseMaxPerPart개까지 추가할 수 있어요.';
  }
  return null;
}

class PersonalCustomExerciseService {
  PersonalCustomExerciseService({
    required String uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : uid = uid.trim(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      _firestore.collection('trainer_profiles').doc(uid);

  Future<Map<String, List<String>>> load() async {
    final snapshot = await _profileRef.get();
    return normalizeCustomExercises(snapshot.data()?['customExercises']);
  }

  /// 목록 전체를 서버에 저장하고, 서버에서 다시 읽어 같은지 확인한다.
  Future<Map<String, List<String>>> save(
    Map<String, List<String>> exercises,
  ) async {
    final normalized = normalizeCustomExercises(exercises);
    await MtfFirebaseFunctions.call(
      'updatePersonalTrainerProfile',
      functions: _functions,
      parameters: {'customExercises': normalized},
    );
    final snapshot = await _profileRef.get(
      const GetOptions(source: Source.server),
    );
    final readback = normalizeCustomExercises(
      snapshot.data()?['customExercises'],
    );
    if (_signature(readback) != _signature(normalized)) {
      throw StateError('custom_exercises_readback_mismatch');
    }
    return readback;
  }

  static String _signature(Map<String, List<String>> value) {
    final parts = value.keys.toList()..sort();
    return parts
        .map(
          (part) =>
              '$part:${value[part]!.map(customExerciseComparisonKey).join('|')}',
        )
        .join('\n');
  }
}
