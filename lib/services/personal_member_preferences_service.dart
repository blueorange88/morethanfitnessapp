import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'mtf_firebase_functions.dart';

const String kPersonalDefaultGroupLabel = 'MORE THAN GYM';

String normalizePersonalDefaultGroupLabel(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? kPersonalDefaultGroupLabel : normalized;
}

String? validatePersonalDefaultGroupLabel(String value) {
  final normalized = value.trim();
  if (normalized.length < 2 || normalized.length > 30) {
    return '기본 그룹 이름은 2~30자로 입력해주세요.';
  }
  return null;
}

String normalizeCustomLessonType(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String customLessonTypeComparisonKey(String value) {
  return normalizeCustomLessonType(value).toLowerCase();
}

List<String> normalizeCustomLessonTypes(Object? raw) {
  if (raw is! Iterable) return const <String>[];
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    final value = normalizeCustomLessonType(item.toString());
    if (value.isEmpty || value.length > 40) continue;
    if (seen.add(customLessonTypeComparisonKey(value))) {
      result.add(value);
    }
  }
  return result;
}

class PersonalMemberPreferences {
  const PersonalMemberPreferences({
    required this.defaultGroupLabel,
    required this.customLessonTypes,
  });

  factory PersonalMemberPreferences.fromProfile(
    Map<String, dynamic>? profile,
  ) {
    return PersonalMemberPreferences(
      defaultGroupLabel: normalizePersonalDefaultGroupLabel(
        profile?['memberDefaultGroupLabel'],
      ),
      customLessonTypes:
          normalizeCustomLessonTypes(profile?['customLessonTypes']),
    );
  }

  final String defaultGroupLabel;
  final List<String> customLessonTypes;
}

class PersonalMemberPreferencesService {
  PersonalMemberPreferencesService({
    required String uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : uid = uid.trim(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      _firestore.collection('trainer_profiles').doc(uid);

  Stream<PersonalMemberPreferences> watch() {
    return _profileRef.snapshots().map(
          (snapshot) => PersonalMemberPreferences.fromProfile(snapshot.data()),
        );
  }

  Future<PersonalMemberPreferences> loadFromServer() async {
    final snapshot = await _profileRef.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) {
      throw StateError('personal_profile_not_found');
    }
    return PersonalMemberPreferences.fromProfile(snapshot.data());
  }

  Future<PersonalMemberPreferences> saveDefaultGroupLabel(String value) async {
    final normalized = value.trim();
    final error = validatePersonalDefaultGroupLabel(normalized);
    if (error != null) throw ArgumentError(error);
    await _updateProfile({'memberDefaultGroupLabel': normalized});
    final readback = await loadFromServer();
    if (readback.defaultGroupLabel != normalized) {
      throw StateError('personal_group_label_readback_mismatch');
    }
    return readback;
  }

  Future<PersonalMemberPreferences> saveCustomLessonTypes(
    Iterable<String> values,
  ) async {
    final normalized = normalizeCustomLessonTypes(values);
    await _updateProfile({'customLessonTypes': normalized});
    final readback = await loadFromServer();
    final expectedKeys =
        normalized.map(customLessonTypeComparisonKey).toList(growable: false);
    final actualKeys = readback.customLessonTypes
        .map(customLessonTypeComparisonKey)
        .toList(growable: false);
    if (expectedKeys.join('\n') != actualKeys.join('\n')) {
      throw StateError('custom_lesson_types_readback_mismatch');
    }
    return readback;
  }

  Future<void> _updateProfile(Map<String, dynamic> parameters) async {
    await MtfFirebaseFunctions.call(
      'updatePersonalTrainerProfile',
      functions: _functions,
      parameters: parameters,
    );
  }
}
