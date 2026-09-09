import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/my_page_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('초안 키는 projectId와 uid로 분리된다', () {
    final a = myPageDraftPreferenceKey(
      uid: 'uid-a',
      projectId: 'more-than-fitness-dev-mft',
    );
    final b = myPageDraftPreferenceKey(
      uid: 'uid-b',
      projectId: 'more-than-fitness-dev-mft',
    );
    final prod = myPageDraftPreferenceKey(
      uid: 'uid-a',
      projectId: 'more-than-fitness-f6adb',
    );
    expect(a, isNot(b));
    expect(a, isNot(prod));
  });

  test('normalize된 값으로 dirty field를 판정한다', () {
    expect(
      changedMyPageDraftFields(
        const {'realName': ' 홍길동 ', 'phone': '010-1234-5678'},
        const {'realName': '홍길동', 'phone': '01012345678'},
      ),
      isEmpty,
    );
    expect(
      changedMyPageDraftFields(
        const {'gender': 'unset'},
        const {'gender': 'female'},
      ),
      contains('gender'),
    );
  });

  test('로컬 초안 저장·복원·폐기는 uid 범위 안에서 동작한다', () async {
    SharedPreferences.setMockInitialValues({});
    const store = MyPageDraftStore(projectId: 'more-than-fitness-dev-mft');
    await store.save(
      uid: 'uid-a',
      values: const {
        'nickname': '라디오',
        'phone': '010-0000-0001',
        'activityRegions': ['서울특별시 강남구', '경기도 성남시'],
      },
    );
    expect((await store.load(uid: 'uid-a'))?['nickname'], '라디오');
    expect(
      (await store.load(uid: 'uid-a'))?['activityRegions'],
      ['서울특별시 강남구', '경기도 성남시'],
    );
    expect(await store.load(uid: 'uid-b'), isNull);
    await store.clear(uid: 'uid-a');
    expect(await store.load(uid: 'uid-a'), isNull);
  });
}
