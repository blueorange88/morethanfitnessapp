import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
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

    test('회원 등급은 지원값만 canonical 대문자로 정규화한다', () {
      for (final grade in const ['VVIP', 'VIP', 'gold', 'Silver', 'BRONZE']) {
        expect(personalMemberGradeForSave(grade), grade.toUpperCase());
      }
      expect(
        () => personalMemberGradeForSave('PLATINUM'),
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

  group('Personal 회원 저장 trace', () {
    test('동일한 비식별 trace id로 단계와 상태를 연결한다', () {
      final logs = <String>[];
      final trace = PersonalMemberSaveTrace.start(sink: logs.add);

      trace.record(
        PersonalMemberSaveTraceStage.saveButtonTap,
        PersonalMemberSaveTraceStatus.start,
      );
      trace.record(
        PersonalMemberSaveTraceStage.callableResponse,
        PersonalMemberSaveTraceStatus.ok,
        functionName: 'updateManagedMember',
      );

      expect(trace.id, startsWith('SAVE-'));
      expect(logs, hasLength(2));
      expect(logs.every((log) => log.contains('trace=${trace.id}')), isTrue);
      expect(logs.first, contains('stage=SAVE_BUTTON_TAP status=START'));
      expect(
        logs.last,
        contains('stage=CALLABLE_RESPONSE status=OK'),
      );
      expect(logs.join('\n'), isNot(contains('memberId=')));
      expect(logs.join('\n'), isNot(contains('phone=')));
      expect(logs.join('\n'), isNot(contains('uid=')));
    });

    test('timeout과 DNS 실패를 민감정보 없는 상태로 분류한다', () {
      final timeout = TimeoutException('readback');
      final dns = StateError('UnknownHostException: unable to resolve host');

      expect(
        personalMemberSaveTraceFailureStatus(timeout),
        PersonalMemberSaveTraceStatus.timeout,
      );
      expect(personalMemberSaveTraceFailureOutcome(timeout), 'TIMEOUT');
      expect(personalMemberSaveTraceFailureOutcome(dns), 'DNS_FAIL');
    });

    test('허용된 callable 사유 코드만 trace outcome으로 남긴다', () {
      final known = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'member_count_conflict',
      );
      final unknown = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'raw server detail',
      );

      expect(
        personalMemberSaveTraceFailureOutcome(known),
        'MEMBER_COUNT_CONFLICT',
      );
      expect(personalMemberSaveTraceServerReason(unknown), isNull);
      expect(personalMemberSaveTraceFailureOutcome(unknown), 'FAIL');
    });

    test('trace token은 공백과 구분문자를 로그 안전 문자열로 제한한다', () {
      final logs = <String>[];
      final trace = PersonalMemberSaveTrace.start(sink: logs.add);

      trace.record(
        PersonalMemberSaveTraceStage.uiSuccess,
        PersonalMemberSaveTraceStatus.fail,
        outcome: 'NETWORK FAIL\nraw detail',
      );

      expect(logs.single, contains('outcome=NETWORK_FAIL_raw_detail'));
      expect(logs.single, isNot(contains('\nraw detail')));
    });
  });
}
