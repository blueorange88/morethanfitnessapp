import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';
import 'package:mtf_app/services/personal_member_preferences_service.dart';

void main() {
  group('Personal 기본 그룹 표시명', () {
    test('필드가 없거나 비어 있으면 MORE THAN GYM을 사용한다', () {
      expect(
        PersonalMemberPreferences.fromProfile(null).defaultGroupLabel,
        kPersonalDefaultGroupLabel,
      );
      expect(
          normalizePersonalDefaultGroupLabel('  '), kPersonalDefaultGroupLabel);
    });

    test('trim 후 2~30자만 허용한다', () {
      expect(normalizePersonalDefaultGroupLabel('  MY GYM  '), 'MY GYM');
      expect(validatePersonalDefaultGroupLabel('A'), isNotNull);
      expect(validatePersonalDefaultGroupLabel('AB'), isNull);
      expect(validatePersonalDefaultGroupLabel('가' * 31), isNotNull);
    });
  });

  group('사용자 레슨 종류', () {
    test('공백과 대소문자를 정규화해 중복을 제거한다', () {
      expect(
        normalizeCustomLessonTypes([
          '  그룹레슨 ',
          '그룹레슨',
          'Power   PT',
          'power pt',
          '발레핏',
        ]),
        ['그룹레슨', 'Power PT', '발레핏'],
      );
    });

    test('빈 값과 40자 초과 값은 목록에서 제외한다', () {
      expect(
        normalizeCustomLessonTypes(['', ' ', '가' * 41, '자이로토닉']),
        ['자이로토닉'],
      );
    });

    test('추가·중복·삭제는 profile 목록만 변경하고 기존 회원 값은 건드리지 않는다', () {
      final added = normalizeCustomLessonTypes([
        'DEV UNIQUE',
        ' 발레핏 ',
        '발레핏',
      ]);
      final removed = added
          .where(
            (value) =>
                customLessonTypeComparisonKey(value) !=
                customLessonTypeComparisonKey('발레핏'),
          )
          .toList();
      final page = File('lib/pages/client_card_page.dart').readAsStringSync();

      expect(added, ['DEV UNIQUE', '발레핏']);
      expect(removed, ['DEV UNIQUE']);
      expect(
        page,
        contains('선택 목록에서만 제거되며 기존 회원과 일정의 저장값은 유지돼요.'),
      );
      expect(page, contains('..._customLessonTypes.map('));
      expect(page, isNot(contains("'lessonType': FieldValue.delete()")));
    });
  });

  test('Personal 기본 그룹 표시명은 목록과 고객카드가 같은 profile stream을 사용한다', () {
    final list = File('lib/pages/client_list_page.dart').readAsStringSync();
    final card = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(
      list,
      contains('PersonalMemberPreferencesService(uid: owner).watch().listen('),
    );
    expect(
      list,
      contains('..[_ungroupedGroupId] = preferences.defaultGroupLabel'),
    );
    expect(
      card,
      contains('_headerGroupLabel = preferences.defaultGroupLabel;'),
    );
    expect(
      card,
      contains('label: preferences.defaultGroupLabel,'),
    );
    expect(card, contains('groupLabel: _membershipCardGroupLabelText(),'));
    expect(card, contains("decoration: _inputDecoration('소속 그룹')"));
  });

  test('레슨일지는 Semi-Pro 등급을 요구한다', () {
    final info =
        AppTierAccessService.featureInfo(AppTierFeatureKey.trainingLog);
    expect(info.requiredRank, 2);
    expect(info.requiredTierLabel, 'Semi-Pro');
  });
}
