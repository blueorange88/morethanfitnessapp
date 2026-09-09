import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final clientCardSource =
      File('lib/pages/client_card_page.dart').readAsStringSync();
  final saveServiceSource = File(
    'lib/services/personal_member_card_save_service.dart',
  ).readAsStringSync();
  final trainingLogSource =
      File('lib/pages/personal_training_log_page.dart').readAsStringSync();
  final homeSource = File('lib/pages/home_page.dart').readAsStringSync();
  final scheduleServiceSource = File(
    'lib/services/home_schedule_firestore_service.dart',
  ).readAsStringSync();

  test('신규와 수정 고객카드는 서로 다른 callable 경로를 사용한다', () {
    expect(clientCardSource, contains('.createAndVerify('));
    expect(clientCardSource, contains('.updateAndVerify('));
    expect(clientCardSource, contains("? '수정 저장'"));
    expect(clientCardSource, contains(": '회원 저장'"));
    expect(clientCardSource, contains("? '저장 중…'"));
  });

  test('수정 저장은 전체 회원 readback과 일정 이름 동기화를 확인한다', () {
    expect(saveServiceSource, contains('_hasExpectedMemberUpdate('));
    expect(saveServiceSource, contains("collection('schedules')"));
    expect(saveServiceSource, contains("where('trainerId', isEqualTo: uid)"));
    expect(
      saveServiceSource,
      contains("where('workspaceType', isEqualTo: 'personal')"),
    );
    expect(
      saveServiceSource,
      contains("where('memberId', isEqualTo: memberId)"),
    );
    expect(saveServiceSource, contains('Source.server'));
    expect(saveServiceSource, contains('scheduleNameSyncSucceeded'));
  });

  test('일반 고객카드에는 동의 초기화 동작이 노출되지 않는다', () {
    expect(clientCardSource, isNot(contains('동의 초기화')));
    expect(clientCardSource, isNot(contains('_resetTrainingLogConsent')));
  });

  test('고객카드 레슨일지는 목록으로 진입하고 작성은 명시 버튼에서 시작한다', () {
    final openStart = clientCardSource.indexOf(
      'Future<void> _openTrainingLogWithConsent()',
    );
    final openEnd = clientCardSource.indexOf(
      'Future<void> _persistTrainingLogConsent',
      openStart,
    );
    final openFlow = clientCardSource.substring(openStart, openEnd);
    expect(openFlow, contains('PersonalTrainingLogEntryGuard'));
    expect(openFlow, contains('PersonalTrainingLogPage('));
    expect(openFlow, isNot(contains('_openNewLogSheet')));
    expect(trainingLogSource, contains("'오늘 레슨일지 작성'"));
    expect(trainingLogSource, contains('onPressed: _openNewLogSheet'));
  });

  test('일정 삭제는 단일 병렬 preflight와 서버 readback 뒤 완료된다', () {
    expect(homeSource, contains('sourceSnapshotById'));
    expect(homeSource, contains('Future.wait(sourceDocIds.map'));
    expect(homeSource, contains('source: Source.server'));
    expect(homeSource, contains('stage=server_delete_verified'));
    expect(homeSource, contains('_queueScheduleDeleteAuxiliarySync'));
    expect(
      scheduleServiceSource,
      contains('await Future.wait(sourceDocIds.map'),
    );
  });
}
