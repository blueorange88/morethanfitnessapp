import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_environment.dart';

const String myPageDraftFeatureKey = 'my_page_profile_draft_v1';

String myPageDraftPreferenceKey({
  required String uid,
  String? projectId,
}) {
  return AppEnvironmentConfig.personalPreferenceKey(
    uid: uid,
    featureKey: myPageDraftFeatureKey,
    projectId: projectId,
  );
}

Map<String, dynamic> normalizeMyPageDraft(Map<String, dynamic> values) {
  String text(String key) => (values[key] ?? '').toString().trim();
  final activityRegions = values['activityRegions'] is Iterable
      ? (values['activityRegions'] as Iterable)
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(3)
          .toList()
      : <String>[];

  return <String, dynamic>{
    'realName': text('realName'),
    'nameEn': text('nameEn'),
    'nickname': text('nickname'),
    'gymName': text('gymName'),
    'centerLocation': text('centerLocation'),
    'activityArea': text('activityArea'),
    'activityRegions': activityRegions,
    'jobTitle': text('jobTitle'),
    'birth': text('birth'),
    'phone': text('phone').replaceAll(RegExp(r'\D'), ''),
    'intro': text('intro'),
    'primaryActivity': text('primaryActivity'),
    'contractTrainerCustomName': text('contractTrainerCustomName'),
    'affiliationType': text('affiliationType'),
    'gender': text('gender'),
    'contractTrainerNameSource': text('contractTrainerNameSource'),
  };
}

Set<String> changedMyPageDraftFields(
  Map<String, dynamic> initial,
  Map<String, dynamic> current,
) {
  final before = normalizeMyPageDraft(initial);
  final after = normalizeMyPageDraft(current);
  return after.keys.where((key) {
    final left = before[key];
    final right = after[key];
    if (left is List && right is List) {
      return jsonEncode(left) != jsonEncode(right);
    }
    return left != right;
  }).toSet();
}

class MyPageDraftStore {
  const MyPageDraftStore({this.projectId});

  final String? projectId;

  Future<Map<String, dynamic>?> load({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      myPageDraftPreferenceKey(uid: uid, projectId: projectId),
    );
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return normalizeMyPageDraft(Map<String, dynamic>.from(decoded));
  }

  Future<void> save({
    required String uid,
    required Map<String, dynamic> values,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      myPageDraftPreferenceKey(uid: uid, projectId: projectId),
      jsonEncode(normalizeMyPageDraft(values)),
    );
  }

  Future<void> clear({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      myPageDraftPreferenceKey(uid: uid, projectId: projectId),
    );
  }
}
