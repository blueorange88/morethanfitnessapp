import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/personal_training_log_entry_guard.dart';

void main() {
  Map<String, dynamic> member({
    String trainerId = 'owner',
    String workspaceType = 'personal',
    String memberId = 'member',
    bool contractSigned = false,
    Object? contractSignedAt,
    String contractId = '',
    bool consentAgreed = false,
  }) {
    return {
      'trainerId': trainerId,
      'workspaceType': workspaceType,
      'memberId': memberId,
      'contractSigned': contractSigned,
      if (contractSignedAt != null) 'contractSignedAt': contractSignedAt,
      'lessonSync': {'contractId': contractId},
      'trainingLogConsentAgreed': consentAgreed,
    };
  }

  test('canonical owner 회원만 레슨일지 동의 판정을 진행한다', () {
    for (final data in <Map<String, dynamic>>[
      member(trainerId: 'other'),
      member(workspaceType: 'legacy'),
      member(memberId: 'other'),
    ]) {
      expect(
        resolvePersonalTrainingLogMemberAccess(
          ownerUid: 'owner',
          memberId: 'member',
          memberExists: true,
          memberData: data,
        ),
        PersonalTrainingLogMemberAccess.denied,
      );
    }
  });

  test('미동의 회원은 동의가 필요하고 동의한 회원은 허용한다', () {
    expect(
      resolvePersonalTrainingLogMemberAccess(
        ownerUid: 'owner',
        memberId: 'member',
        memberExists: true,
        memberData: member(),
      ),
      PersonalTrainingLogMemberAccess.consentRequired,
    );
    expect(
      resolvePersonalTrainingLogMemberAccess(
        ownerUid: 'owner',
        memberId: 'member',
        memberExists: true,
        memberData: member(consentAgreed: true),
      ),
      PersonalTrainingLogMemberAccess.allowed,
    );
  });

  test('서명된 계약서는 건강정보 동의를 대신하지 않는다', () {
    for (final data in <Map<String, dynamic>>[
      member(contractSigned: true),
      member(contractSignedAt: DateTime(2026, 7, 26)),
      member(contractId: 'contract'),
    ]) {
      expect(
        resolvePersonalTrainingLogMemberAccess(
          ownerUid: 'owner',
          memberId: 'member',
          memberExists: true,
          memberData: data,
        ),
        PersonalTrainingLogMemberAccess.consentRequired,
      );
    }
    expect(
      resolvePersonalTrainingLogMemberAccess(
        ownerUid: 'owner',
        memberId: 'member',
        memberExists: true,
        memberData: member(contractSigned: true, consentAgreed: true),
      ),
      PersonalTrainingLogMemberAccess.allowed,
    );
  });

  test('저장 전 신규 회원카드는 동의를 먼저 받아두고 회원 저장 직후 서버에 반영한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    final openBlock =
        RegExp(
          r'Future<void> _openTrainingLogConsent\(\) async \{\s*'
          r'if \(_isPersonalWorkspace && !_isEditMode\) \{[\s\S]*?return;\s*\}',
        ).firstMatch(source)!.group(0)!;
    expect(openBlock, contains('_consentPendingPersist = true'));
    expect(openBlock, isNot(contains('_persistTrainingLogConsent')));

    expect(
      RegExp(
        r'\.createAndVerify\([\s\S]*?\);\s*'
        r'var consentSaveFailed = false;\s*'
        r'if \(_consentPendingPersist\) \{[\s\S]*?'
        r'\.update\(memberId: result\.memberId, agreed: true\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('신규 회원카드 동의서 배너는 필수 항목을 채운 뒤 회원 정보와 회원 현황 사이에 둔다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(source, contains('bool get _usesInlineConsentCard'));
    expect(
      RegExp(
        r'_basicInfoSection\(\),[\s\S]*?'
        r'_usesInlineConsentCard &&[\s\S]*?'
        r'_missingRequiredFields\(\)\.isEmpty\)[\s\S]*?'
        r'_trainingLogConsentCard\(\),[\s\S]*?_memberSetupSection\(\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal mutation 진입점은 공통 동의 guard를 사용한다', () {
    final card = File('lib/pages/client_card_page.dart').readAsStringSync();
    final list = File('lib/pages/client_list_page.dart').readAsStringSync();
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final log =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();
    final quickSign =
        File(
          'lib/pages/personal_training_log_quick_sign_page.dart',
        ).readAsStringSync();

    expect(card, contains("entryPoint: 'client_card_training_log'"));
    expect(list, contains("entryPoint: 'client_list_training_log'"));
    for (final entryPoint in <String>[
      'home_schedule_training_log_consent',
      'home_schedule_quick_sign_consent',
      'home_schedule_lesson_finalize_consent',
      'home_schedule_member_signature_request_consent',
    ]) {
      expect(home, contains("entryPoint: '$entryPoint'"));
    }
    expect(log, contains('PersonalTrainingLogEntryGuard.guard('));
    expect(quickSign, contains('PersonalTrainingLogEntryGuard.guard('));
  });

  test('동의 guard는 callable 뒤 server readback을 다시 확인한다', () {
    final source =
        File(
          'lib/widgets/personal_training_log_entry_guard.dart',
        ).readAsStringSync();

    expect(source, contains('PersonalMemberConsentService('));
    expect(source, contains('uid: owner,'));
    expect(source, contains(').update(memberId: member, agreed: true)'));
    expect(
      RegExp(
        r'final readback = await memberRef\.get\([\s\S]*?Source\.server',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains("identifiersLogged=false"));
  });

  test('Personal 레슨일지 초기 로더는 owner 범위 query만 사용한다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Query<Map<String, dynamic>> _trainingLogsQuery\(String memberId\) '
        r'\{[\s\S]*?'
        r"where\('memberId', isEqualTo: memberId\)[\s\S]*?"
        r"where\('trainerId', isEqualTo: _personalOwnerUid\)[\s\S]*?"
        r"where\('workspaceType', isEqualTo: 'personal'\)",
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _loadQuickSignedLogsFromFirestore\(\) async '
        r'\{[\s\S]*?final snapshot = await '
        r'_trainingLogsQuery\(memberId\)\.get\(\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _loadAnatomyLogsFromFirestore\(\) async '
        r'\{[\s\S]*?final snapshot = await '
        r'_trainingLogsQuery\(memberId\)\.get\(\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal 초기 진입은 legacy member 하위 collection을 시작하지 않는다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'void _loadTrainingLogDataSources\(\) \{[\s\S]*?'
        r'if \(_isPersonalWorkspace\) \{[\s\S]*?return;[\s\S]*?'
        r'_loadGoalDdaysFromFirestore\(\)',
      ).hasMatch(source),
      isTrue,
    );
    for (final method in <String>['_goalDdaysRef', '_careMilestonesRef']) {
      expect(
        RegExp(
          'CollectionReference<Map<String, dynamic>>\\? $method\\(\\) '
          r'\{\s*if \(_isPersonalWorkspace\) return null;',
        ).hasMatch(source),
        isTrue,
      );
    }
    expect(
      RegExp(
        r'Future<void> _createAchievementBadgeFromGoal\([\s\S]*?'
        r'if \(_isPersonalWorkspace\) return;',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal 일정 fallback query는 owner workspace member를 모두 제한한다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<DocumentReference<Map<String, dynamic>>\?> '
        r'_findScheduleRefForLog\([\s\S]*?'
        r"where\('trainerId', isEqualTo: _personalOwnerUid\)[\s\S]*?"
        r"where\('workspaceType', isEqualTo: 'personal'\)[\s\S]*?"
        r"where\('memberId', isEqualTo: memberId\)",
      ).hasMatch(source),
      isTrue,
    );
  });

  test('레슨일지 read 실패 로그는 오류 코드만 기록한다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(source, contains('[MTF_TRAINING_LOG_READ]'));
    expect(source, contains('errorCode=\$errorCode'));
    expect(source, contains('identifiersLogged=false'));
    expect(source, isNot(contains('[MTF_TRAINING_LOG_READ] memberId=')));
  });

  test('동의 완료 후 고객카드 완료 표시만 유지하고 초기화는 숨긴다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    final hideBlock =
        RegExp(
          r'bool get _hideTopActionCards \{[\s\S]*?\n  \}',
        ).firstMatch(source)!.group(0)!;
    expect(hideBlock, contains('if (_trainingLogConsentAgreed) return true;'));
    expect(hideBlock, isNot(contains('_contractSigned')));
    expect(hideBlock, isNot(contains('_canUseSemiProFeatures')));
    expect(
      source,
      contains("if (_trainingLogConsentAgreed) return '개인정보동의 완료';"),
    );
    expect(source, isNot(contains('_resetTrainingLogConsent')));
    expect(source, isNot(contains('동의 초기화')));
  });
}
