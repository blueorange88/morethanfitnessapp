import 'package:shared_preferences/shared_preferences.dart';

import 'app_environment.dart';

enum PersonalProfileNudgeKey {
  displayName,
  phone,
  activityRegion,
  primaryActivity,
  affiliationType,
}

abstract interface class PersonalMyPageNudgeStore {
  Future<String?> readLastKey(String uid);

  Future<void> writeLastKey(String uid, String key);
}

class SharedPreferencesPersonalMyPageNudgeStore
    implements PersonalMyPageNudgeStore {
  const SharedPreferencesPersonalMyPageNudgeStore();

  String _storageKey(String uid) => AppEnvironmentConfig.personalPreferenceKey(
        uid: uid,
        featureKey: 'personal_my_page_last_nudge',
      );

  @override
  Future<String?> readLastKey(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_storageKey(uid));
  }

  @override
  Future<void> writeLastKey(String uid, String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey(uid), key);
  }
}

PersonalProfileNudgeKey? selectNextPersonalProfileNudge({
  required List<PersonalProfileNudgeKey> missing,
  required String? lastKey,
}) {
  if (missing.isEmpty) return null;
  final lastIndex = PersonalProfileNudgeKey.values.indexWhere(
    (value) => value.name == lastKey,
  );
  for (var offset = 1;
      offset <= PersonalProfileNudgeKey.values.length;
      offset++) {
    final index = (lastIndex + offset) % PersonalProfileNudgeKey.values.length;
    final candidate = PersonalProfileNudgeKey.values[index];
    if (missing.contains(candidate)) return candidate;
  }
  return missing.first;
}

String personalProfileNudgeMessage(
  PersonalProfileNudgeKey key, {
  required String nickname,
}) {
  final name = nickname.trim().isEmpty ? '선생님' : nickname.trim();
  return switch (key) {
    PersonalProfileNudgeKey.activityRegion =>
      '활동 지역을 알려주시면\n홈에서 날씨와 이동 정보를 먼저 준비해둘게요.\n\n'
          '향후 원하실 때,\n$name 같은 선생님을 찾는 근처 고객과\n'
          '연결되는 데에도 활용할 수 있어요.',
    PersonalProfileNudgeKey.primaryActivity =>
      '잘하는 운동 분야를 알려주세요.\n향후 $name의 전문 분야를 찾는 고객에게\n'
          '더 잘 소개할 수 있어요.',
    PersonalProfileNudgeKey.affiliationType =>
      '현재 활동 형태를 알려주세요.\n프리랜서·센터 소속·개인샵에 맞는\n'
          '관리 기능을 더 알맞게 안내해드릴게요.',
    PersonalProfileNudgeKey.displayName =>
      '선생님을 어떤 이름으로 소개하면 좋을까요?\n명함과 향후 프로필에서도 사용할 수 있어요.',
    PersonalProfileNudgeKey.phone => '연락처를 등록해두면\n계정 확인과 향후 회원·센터 연결을\n'
        '더 안전하게 준비할 수 있어요.',
  };
}
