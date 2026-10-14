import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/personal_member_card_save_service.dart';
import 'package:mtf_app/widgets/home/sections/home_weekly_goal_dialog.dart';

void main() {
  group('Personal 회원 저장 callable 계약', () {
    test('AIFC 회원권 일수 입력을 canonical 양의 정수로 정규화한다', () {
      for (final value in const [
        '120',
        '120일',
        '120 일',
        '120days',
        '120 days',
        '120day',
        '120 day',
        '120DAY',
        '120DAYS',
        '120Days',
        ' 45 ',
        '45일',
        '45day',
      ]) {
        expect(
          normalizePersonalMembershipDaysInput(value),
          value.contains('45') ? 45 : 120,
          reason: value,
        );
      }
      for (final value in const [
        '0',
        '-1',
        '-10',
        'abc',
        '12개월',
        '1month',
        '3months',
        '1.5',
        '1.5일',
      ]) {
        expect(
          normalizePersonalMembershipDaysInput(value),
          isNull,
          reason: value,
        );
      }
    });

    test('callable 오류 진단은 code message details를 한 줄로 남긴다', () {
      expect(
        personalMemberCallableErrorDiagnostic(
          code: 'invalid-argument',
          message: 'unknown_fields',
          details: null,
        ),
        'code=invalid-argument message=unknown_fields details=none',
      );
      expect(
        personalMemberCallableErrorDiagnostic(
          code: 'invalid-argument',
          message: 'first\nsecond',
          details: const {'field': 'membership'},
        ),
        "code=invalid-argument message=first second details={field: membership}",
      );
    });

    test('회원 수정 실패는 단계와 네트워크 오류를 보존해 재시도 문구를 만든다', () {
      final failure = PersonalMemberCardUpdateException(
        stage: PersonalMemberCardUpdateStage.callable,
        cause: FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      );

      expect(failure.stage, PersonalMemberCardUpdateStage.callable);
      expect(personalMemberUpdateErrorCode(failure), 'unavailable');
      expect(
        personalMemberUpdateErrorMessage(failure),
        '네트워크 연결을 확인한 뒤 다시 시도해주세요. 입력한 내용은 그대로 유지했어요.',
      );
      expect(failure.toString(), contains('stage=callable'));
      expect(failure.toString(), isNot(contains('network unavailable')));
    });

    test('host lookup 실패도 네트워크 재시도 안내로 분류한다', () {
      final error = Exception(
        'UnknownHostException: Unable to resolve host firestore.googleapis.com',
      );

      expect(personalMemberUpdateIsNetworkError(error), isTrue);
      expect(
        personalMemberUpdateErrorMessage(error),
        contains('네트워크 연결을 확인한 뒤 다시 시도해주세요.'),
      );
    });

    test('readback timeout과 callable 입력 오류를 다른 안내로 구분한다', () {
      expect(
        personalMemberUpdateErrorMessage(TimeoutException('readback')),
        contains('네트워크 연결'),
      );
      expect(
        personalMemberUpdateErrorMessage(
          FirebaseFunctionsException(
            code: 'invalid-argument',
            message: 'membership_period_invalid',
          ),
        ),
        '입력한 회원 정보를 다시 확인해주세요.',
      );
    });

    test('누적 회원 계정 연결 요구를 입력 오류로 숨기지 않는다', () {
      final error = PersonalMemberCardUpdateException(
        stage: PersonalMemberCardUpdateStage.callable,
        cause: FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'account_link_required',
        ),
      );

      final message = personalMemberUpdateErrorMessage(error);
      expect(personalMemberUpdateRequiresAccountLink(error), isTrue);
      expect(message, contains('계정 연결이 필요해요'));
      expect(message, contains('마이페이지'));
      expect(message, contains('입력한 내용은 그대로 유지했어요'));
      expect(message, isNot(contains('입력한 회원 정보를 다시 확인')));
    });

    test('Auth 연결 후 profile 전환 미완료 오류는 연결 재개 대상으로 분류한다', () {
      final error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'workspace_not_eligible',
      );

      expect(personalMemberUpdateRequiresAccountLink(error), isFalse);
      expect(personalMemberUpdateNeedsLinkedProfileCompletion(error), isTrue);
    });

    test('신규 고객카드는 불완전한 회원권 시작일을 자동 생성하지 않는다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();

      expect(card, contains('bool _membershipNotRegistered = true;'));
      expect(card, isNot(contains('_passStart = widget.initialVisitDate;')));
      expect(card, contains("if (!_membershipNotRegistered &&"));
      expect(
        card,
        contains('personalMemberUpdateNeedsLinkedProfileCompletion(e)'),
      );
    });

    test('회원권 기간과 날짜를 canonical membership map으로 직렬화한다', () {
      for (final months in const [1, 3, 6, 12]) {
        final days = months * 30;
        final start = DateTime(2026, 8, 1);
        final update = PersonalMemberMembershipUpdate(
          notRegistered: false,
          termMonths: months,
          customDays: null,
          startAt: start,
          endAt: start.add(Duration(days: days - 1)),
          days: days,
          lastRegisteredAt: start,
          reregisterCount: 0,
          lastReregisterAt: null,
        );

        expect(update.toCallableMap(), {
          'notRegistered': false,
          'termMonths': months,
          'customDays': null,
          'startAt': '2026-08-01',
          'endAt': personalMemberCalendarDateForSave(
            start.add(Duration(days: days - 1)),
          ),
          'days': days,
          'lastRegisteredAt': '2026-08-01',
          'reregisterCount': 0,
          'lastReregisterAt': null,
        });
      }
    });

    test('직접입력 120일과 직접 날짜 선택을 동일한 계약으로 보낸다', () {
      final start = DateTime(2026, 8, 15);
      final custom =
          PersonalMemberMembershipUpdate(
            notRegistered: false,
            termMonths: null,
            customDays: 120,
            startAt: start,
            endAt: start.add(const Duration(days: 119)),
            days: 120,
            lastRegisteredAt: start,
            reregisterCount: 1,
            lastReregisterAt: start,
          ).toCallableMap();

      expect(custom['termMonths'], isNull);
      expect(custom['customDays'], 120);
      expect(custom['days'], 120);
      expect(custom['startAt'], '2026-08-15');
      expect(custom['endAt'], '2026-12-12');
    });

    test('고객카드 update가 회원권과 D-DAY를 누락하지 않는다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();
      final service =
          File(
            'lib/services/personal_member_card_save_service.dart',
          ).readAsStringSync();
      final functions =
          File('functions/src/managed_members.ts').readAsStringSync();

      expect(card, contains('membership: PersonalMemberMembershipUpdate('));
      expect(card, contains('anniversaryDate: _anniversaryDate,'));
      expect(card, contains("'client_card_anniversary_clear'"));
      expect(card, contains('_anniversaryDate = null;'));
      expect(service, contains("'membership': membership.toCallableMap()"));
      expect(service, contains("'anniversaryDate':"));
      expect(service, contains("stage: 'callable_start'"));
      expect(service, contains("stage: 'callable_complete'"));
      expect(service, contains('personalMemberUpdateCallableTimeout,'));
      expect(personalMemberUpdateCallableTimeout, const Duration(seconds: 20));
      expect(
        service,
        contains("stage = PersonalMemberCardUpdateStage.readback"),
      );
      expect(
        service,
        contains("stage = PersonalMemberCardUpdateStage.snapshot"),
      );
      expect(card, contains('personalMemberUpdateRequiresAccountLink(e)'));
      expect(card, contains('_runAccountLinkRequiredFlow()'));
      expect(card, contains('AifcAccountLinkRequiredChatSheet.showLinked('));
      expect(
        card,
        isNot(contains('if (mounted && confirmed) await _submitAndStay();')),
      );
      expect(
        card,
        contains('await AifcAccountLinkRequiredChatSheet.showLinked('),
      );
      expect(card, contains('bool _accountLinkSheetOpen = false;'));
      for (final field in const [
        'notRegistered',
        'termMonths',
        'customDays',
        'startAt',
        'endAt',
        'days',
        'lastRegisteredAt',
        'reregisterCount',
        'lastReregisterAt',
      ]) {
        expect(functions, contains('membership.$field'));
      }
      expect(functions, contains('canonicalUpdate.anniversaryDate'));
      expect(functions, contains('canonicalUpdate.anniversaryLabel'));
    });

    test('Personal 고객카드 저장 8단계가 하나의 trace로 연결된다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();
      final service =
          File(
            'lib/services/personal_member_card_save_service.dart',
          ).readAsStringSync();

      expect(card, contains('PersonalMemberSaveTrace.start()'));
      for (final stage in const [
        'saveButtonTap',
        'localValidate',
        'phoneDuplicateCheck',
        'uiSuccess',
      ]) {
        expect(
          card,
          contains('PersonalMemberSaveTraceStage.$stage'),
          reason: '$stage client trace가 필요합니다.',
        );
      }
      for (final stage in const [
        'callableStart',
        'callableResponse',
        'canonicalReadback',
        'ownerSnapshotConfirm',
      ]) {
        expect(
          service,
          contains('PersonalMemberSaveTraceStage.$stage'),
          reason: '$stage service trace가 필요합니다.',
        );
      }
      expect(card, contains('trace: trace'));
      expect(service, isNot(contains("'traceId':")));
    });

    test('full 신규와 수정은 등급·회원권·D-DAY를 같은 canonical 계약으로 보낸다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();
      final service =
          File(
            'lib/services/personal_member_card_save_service.dart',
          ).readAsStringSync();
      final functions =
          File('functions/src/managed_members.ts').readAsStringSync();

      final createStart = card.indexOf(').createAndVerify(');
      final updateStart = card.indexOf(').updateAndVerify(');
      final createBody = card.substring(createStart, updateStart);
      final updateBody = card.substring(
        updateStart,
        card.indexOf(
          'final postSaveSucceeded = await _runPostCanonicalSaveTasks();',
          updateStart,
        ),
      );

      for (final body in [createBody, updateBody]) {
        expect(body, contains('membershipGrade: _membershipGrade'));
        expect(body, contains('membership: PersonalMemberMembershipUpdate('));
        expect(body, contains('anniversaryDate: _anniversaryDate'));
      }
      expect(service, contains("'membershipGrade': normalizedMembershipGrade"));
      expect(service, contains("'membership': membership.toCallableMap()"));
      expect(
        service,
        contains('member[\'membershipGrade\'] == membershipGrade'),
      );
      expect(
        functions,
        contains('...(membershipGrade == null ? {} : {membershipGrade})'),
      );
      expect(
        functions,
        contains('...(membership == null ? {} : {membership})'),
      );
      expect(
        functions,
        contains('canonicalUpdate.membershipGrade = membershipGrade'),
      );
    });

    test('Home Personal 빠른등록은 canonical create와 readback 뒤 성공 처리한다', () {
      final home = File('lib/pages/home_page.dart').readAsStringSync();
      final sheet =
          File(
            'lib/widgets/aifc_quick_register_chat_sheet.dart',
          ).readAsStringSync();
      final service =
          File(
            'lib/services/personal_member_card_save_service.dart',
          ).readAsStringSync();
      final functions =
          File('functions/src/managed_members.ts').readAsStringSync();

      final canonicalCreate = home.indexOf('.createQuickAndVerify(');
      final sheetResult = home.indexOf(
        'final result = await AifcQuickRegisterChatSheet.show(',
      );
      expect(canonicalCreate, greaterThanOrEqualTo(0));
      expect(canonicalCreate, greaterThan(sheetResult));
      expect(home, contains('final quickRegistrationId ='));
      expect(home, contains('idempotencyKey: quickRegistrationId'));
      expect(sheet, contains('await widget.onFastSave(result);'));
      expect(
        sheet,
        contains('errorTextBuilder: personalMemberUpdateErrorMessage'),
      );
      expect(sheet, contains('closeAfterReply: true'));
      expect(service, contains("'registrationMode': 'quick'"));
      expect(service, contains(".where('trainerId', isEqualTo: uid)"));
      expect(
        service,
        contains(".where('workspaceType', isEqualTo: 'personal')"),
      );
      expect(service, contains("member['createdAt'] is! Timestamp"));
      expect(functions, contains('"registrationMode", "nextReservationAt"'));
      expect(functions, contains('registrationMode === "quick"'));
      expect(functions, contains('trainerId: uid'));
      expect(functions, contains('workspaceType: "personal"'));
    });

    test('canonical 저장 성공 후 보조 작업 실패를 저장 실패로 다시 표시하지 않는다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();
      final canonicalUpdate = card.indexOf(').updateAndVerify(');
      final postSave = card.indexOf(
        'final postSaveSucceeded = await _runPostCanonicalSaveTasks();',
        canonicalUpdate,
      );
      final successMessage = card.indexOf("? '회원 정보를 저장했어요.'", postSave);
      expect(canonicalUpdate, greaterThanOrEqualTo(0));
      expect(postSave, greaterThan(canonicalUpdate));
      expect(successMessage, greaterThan(postSave));
      expect(card, contains('[MTF_MEMBER_SAVE_POST] task=customLessonType'));
      expect(card, contains('[MTF_MEMBER_SAVE_POST] task=draftCleanup'));
    });

    test('Personal 삭제는 owner-scoped callable과 서버 readback을 사용한다', () {
      final card = File('lib/pages/client_card_page.dart').readAsStringSync();
      final service =
          File(
            'lib/services/personal_member_card_save_service.dart',
          ).readAsStringSync();
      final functions =
          File('functions/src/managed_members.ts').readAsStringSync();

      expect(card, contains('.deleteAndVerify(memberId: widget.memberId)'));
      expect(service, contains("'transitionManagedMemberState'"));
      expect(service, contains("'nextState': 'deleted'"));
      expect(functions, contains('member.trainerId !== uid'));
      expect(functions, contains('member.workspaceType !== "personal"'));
      expect(functions, contains('deleteStatus: "pending_delete"'));
    });
  });

  group('주간 목표 dialog lifecycle', () {
    for (final mode in ThemeMode.values) {
      testWidgets('${mode.name}에서 저장·취소·재열기 시 예외가 없다', (tester) async {
        String? submitted;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: FilledButton(
                      onPressed: () async {
                        submitted = await showDialog<String>(
                          context: context,
                          builder:
                              (_) => const HomeWeeklyGoalDialog(
                                initialValue: '40',
                              ),
                        );
                      },
                      child: const Text('열기'),
                    ),
                  ),
            ),
          ),
        );

        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('home-weekly-goal-field')),
          '55',
        );
        await tester.tap(find.text('저장'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(submitted, '55');

        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
