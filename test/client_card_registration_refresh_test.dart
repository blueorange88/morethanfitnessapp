import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/pages/client_card_page.dart').readAsStringSync();

  test('회원카드는 불러올 때 마지막 등록(lastRegistration)을 읽는다', () {
    expect(source, contains('_applyLastRegistration(d);'));
    expect(source, contains("member['lastRegistration']"));
  });

  test('계약서 화면에서 돌아오면 서버가 합산한 횟수를 카드에 반영한다', () {
    // 새로고침이 없으면 카드가 예전 횟수를 들고 있다가 저장할 때 덮어쓴다.
    final manage = source.substring(
      source.indexOf('onOpenMembership: _openMembershipContractDraft,'),
    );
    expect(
      manage.indexOf('await _refreshRegistrationAfterContract();'),
      greaterThan(-1),
    );
    final newContract = source.substring(
      source.indexOf('Future<void> _openNewLessonContract()'),
      source.indexOf('Future<void> _openContract()'),
    );
    expect(newContract, contains('await _refreshRegistrationAfterContract();'));
  });

  test('새로고침은 서버 값을 읽고, 마지막 등록이 바뀐 경우에만 횟수를 바꾼다', () {
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshRegistrationAfterContract()'),
      source.indexOf('Future<void> _openNewLessonContract()'),
    );
    expect(refresh, contains('Source.server'));
    expect(refresh, contains('if (!changed) return;'));
    expect(refresh, contains('_totalSessionsC.text'));
    expect(refresh, contains('_remainSessionsC.text'));
  });

  test('레슨 등록 칩은 공통 규칙(registrationChipStyle)으로 그린다', () {
    expect(source, contains('registrationChipStyle('));
    expect(source, contains("Key('client_card_session_chip')"));
  });

  test('칩 문구: 재등록 · 총소진레슨 N회', () {
    expect(source, contains(r'재등록 · 총소진레슨 $done회'));
    expect(source, isNot(contains('레슨 등록 · 완료')));
  });

  test('레슨계약서로 등록된 횟수는 회원카드에서 직접 못 바꾼다(스위치·총·잔여 칸 잠금)', () {
    expect(source, contains('bool get _registrationLockedByContract =>'));
    expect(
      source,
      contains(
        '_isPersonalWorkspace && _lastRegistrationContractId.isNotEmpty',
      ),
    );
    final section = source.substring(
      source.indexOf("Key('client_card_lesson_register_switch')"),
      source.indexOf("Key('client_card_session_chip')"),
    );
    // 스위치 + 총 횟수 + 잔여 횟수 칸이 모두 잠금 조건을 쓴다.
    expect(
      '_registrationLockedByContract'.allMatches(section).length,
      greaterThanOrEqualTo(4),
    );
    expect(section, contains("Key('client_card_registration_locked_note')"));
  });

  test('계약 뒤 새로고침은 카드 뒷면 재등록 횟수·최근 재등록일도 읽는다', () {
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshRegistrationAfterContract()'),
      source.indexOf('Future<void> _openNewLessonContract()'),
    );
    expect(refresh, contains("membership['reregisterCount']"));
    expect(refresh, contains('_reregisterCountC.text'));
    expect(refresh, contains("membership['lastReregisterAt']"));
  });

  test('계약 뒤 새로고침은 서버가 맞춘 회원권 기간·상태(만료→활동)도 읽는다', () {
    // 안 읽으면 카드가 예전 종료일·만료 상태를 들고 있다가 저장할 때 덮어쓴다.
    final refresh = source.substring(
      source.indexOf('Future<void> _refreshRegistrationAfterContract()'),
      source.indexOf('Future<void> _openNewLessonContract()'),
    );
    expect(refresh, contains("_passStart = _parseDate(d['passStart']"));
    expect(refresh, contains("_passEnd = _parseDate(d['passEnd']"));
    expect(refresh, contains("d['membershipNotRegistered'] == true"));
    expect(refresh, contains('personalMemberStatusFromCanonical(d)'));
  });

  test('레슨 등록 현황은 칩 두 개(두 줄)가 아니라 한 줄 글자로 보여 준다', () {
    final section = source.substring(
      source.indexOf("Key('client_card_registration_locked_note')"),
      source.indexOf("'멤버십 등록'"),
    );
    expect(section, contains('FittedBox('));
    expect(section, contains('softWrap: false'));
    expect(section, isNot(contains('Wrap(')));
    expect(section, isNot(contains('_SoftInfoChip(')));
  });

  test('100번째 레슨 문구는 총 횟수가 아니라 받은 레슨(총 − 잔여) 기준이다', () {
    expect(source, isNot(contains('if (total >= 100)')));
    expect(
      RegExp(
        r'\(total - remain\)\.clamp\(0, total\) >= 100',
      ).allMatches(source).length,
      2,
    );
  });
}
