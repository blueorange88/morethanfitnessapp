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

  test('레슨일지 목록은 전체를 기본으로 하고 전체 칩을 맨 앞에 둔다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(source, contains("String _logFilter = 'all';"));
    expect(
      RegExp(
        r"_buildFilterChip\('전체', 'all'\),[\s\S]*?"
        r"_buildFilterChip\('확정완료', 'locked'\),[\s\S]*?"
        r'_buildMoreFilterToggleChip\(\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('에디터 저장은 서버(training_logs)에 저장하고 열 때 다시 불러온다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    // 에디터를 결과 없이 닫아도 예외 없이 끝난다(두 방식 모두).
    expect(
      RegExp(
        r'if \(result is! Map<String, dynamic>\) return;',
      ).allMatches(source).length,
      2,
    );
    // 결과 반영 직후 서버 저장을 하고, 저장 성공일 때만 완료 안내를 보여준다.
    expect(
      RegExp(
        r'_applyDraftEditorResult\(log, result\);\s*'
        r'final saved = await _persistPersonalLogDraft\(log\);',
      ).allMatches(source).length,
      2,
    );
    expect(source, contains("if (saved) _showSnack('텍스트 레슨일지가 저장되었어요.');"));
    expect(source, contains("if (saved) _showSnack('카테고리 레슨일지가 저장되었어요.');"));
    // 새 일지는 createDraft, 이미 서버 문서가 있으면 autosave.
    expect(source, contains('repository.createDraft(draft)'));
    expect(source, contains('repository.autosave(docId, draft)'));
    // 확정된 일지는 초안 저장을 건너뛴다.
    expect(
      RegExp(
        r'Future<bool> _persistPersonalLogDraft[\s\S]*?'
        r'if \(!_isPersonalWorkspace \|\| log\.locked\) return true;',
      ).hasMatch(source),
      isTrue,
    );
    // 진입 시 서버 일지를 불러오고, 운동 구성·인지/수행 반응도 저장 대상이다.
    expect(
      RegExp(
        r'_loadQuickSignedLogsFromFirestore\(\);\s*'
        r'if \(_isPersonalWorkspace\) \{\s*_loadFormalLogsFromFirestore\(\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains("'exercises': log.exercises,"));
    expect(source, contains("'cognitiveResponse': log.cognitiveResponse,"));
    expect(source, contains("'performanceResponse': log.performanceResponse,"));
    expect(source, contains('initialExercises: log.exercises,'));
  });

  test('카테고리 에디터는 운동 구성과 인지·수행 반응을 저장하고 복원한다', () {
    final source =
        File(
          'lib/pages/personal_training_log_category_page.dart',
        ).readAsStringSync();

    expect(source, contains("'exercises': _exercisesForSave(),"));
    expect(source, contains("'cognitiveResponse': _cognitiveResponse,"));
    expect(source, contains("'performanceResponse': _performanceResponse,"));
    expect(
      source,
      contains('_restoreExerciseGroups(widget.initialExercises);'),
    );
    expect(
      source,
      contains(
        '_applyAutoSummary(force: _publicSummaryC.text.trim().isEmpty);',
      ),
    );
  });

  test('레슨일지 헤더에 설정이 있고 시작 전 체크 자동 열기를 끄고 켤 수 있다', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    // 달력 아이콘 바로 옆에 설정 아이콘.
    expect(
      RegExp(
        r"icon: Icons\.calendar_month_rounded,[\s\S]*?"
        r"icon: Icons\.settings_outlined,\s*tooltip: '레슨일지 설정',\s*"
        r'onTap: onSettingsTap',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('onSettingsTap: _openLogSettings,'));
    expect(source, contains("key: const Key('log_setting_auto_pre_check')"));
    expect(source, contains('TrainingLogPreferences.setAutoOpenPreCheck('));
  });
}
