import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/personal_member_card_save_service.dart';

void main() {
  group('Personal 회원 저장 필드 정규화', () {
    test('UI 성별 남과 여를 canonical 값으로 변환한다', () {
      expect(personalMemberGenderForSave('남'), 'male');
      expect(personalMemberGenderForSave('여'), 'female');
    });

    test('canonical 성별과 과거 표시값도 안전하게 정규화한다', () {
      expect(personalMemberGenderForSave('male'), 'male');
      expect(personalMemberGenderForSave('여성'), 'female');
      expect(
        () => personalMemberGenderForSave('미입력'),
        throwsArgumentError,
      );
    });

    test('생년월일을 canonical yyyy-MM-dd로 정규화한다', () {
      expect(personalMemberBirthDateForSave('1990.2.3'), '1990-02-03');
      expect(
        () => personalMemberBirthDateForSave('2099-01-01'),
        throwsArgumentError,
      );
    });
  });

  group('Personal 회원 그룹 선택 정규화', () {
    test('무그룹은 canonical 기본 상태로 유지한다', () {
      final result = normalizePersonalMemberGroupSelection(
        selectedGroupId: '__ungrouped__',
      );

      expect(result.type, PersonalMemberGroupSelectionType.canonicalDefault);
      expect(result.groupId, isNull);
      expect(result.isValid, isTrue);
      expect(result.fallbackApplied, isFalse);
    });

    test('전체·휴면·만료 가상 필터는 저장하지 않고 기본 상태로 전환한다', () {
      for (final id in [
        '__all__',
        '__system_dormant__',
        '__system_expired__',
      ]) {
        final result = normalizePersonalMemberGroupSelection(
          selectedGroupId: id,
        );

        expect(result.type, PersonalMemberGroupSelectionType.virtual);
        expect(result.groupId, isNull);
        expect(result.fallbackApplied, isTrue);
      }
    });

    test('legacy 또는 누락 그룹 cache는 서버 요청에서 제거한다', () {
      final result = normalizePersonalMemberGroupSelection(
        selectedGroupId: 'legacy_group_3',
      );

      expect(
        result.type,
        PersonalMemberGroupSelectionType.legacyOrMissing,
      );
      expect(result.groupId, isNull);
      expect(result.isValid, isTrue);
      expect(result.fallbackApplied, isTrue);
    });

    test('다른 owner 그룹은 명시적으로 거부한다', () {
      final result = normalizePersonalMemberGroupSelection(
        selectedGroupId: 'other_owner_group',
        otherOwnerGroupIds: const {'other_owner_group'},
      );

      expect(result.type, PersonalMemberGroupSelectionType.otherOwner);
      expect(result.isValid, isFalse);
      expect(result.fallbackApplied, isFalse);
    });

    test('검증된 canonical custom group만 보존한다', () {
      final result = normalizePersonalMemberGroupSelection(
        selectedGroupId: 'personal_group_1',
        canonicalCustomGroupIds: const {'personal_group_1'},
      );

      expect(result.type, PersonalMemberGroupSelectionType.canonicalCustom);
      expect(result.groupId, 'personal_group_1');
      expect(result.isValid, isTrue);
    });
  });
}
