import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service =
      File(
        'lib/services/personal_member_card_save_service.dart',
      ).readAsStringSync();
  final card = File('lib/pages/client_card_page.dart').readAsStringSync();

  test('개인 회원카드 저장 서비스는 등록·수정 모두 건강정보(health)를 서버에 보낸다', () {
    expect(
      RegExp(r'Map<String, dynamic>\? health,').allMatches(service).length,
      2,
    );
    expect(
      RegExp(
        r"if \(health != null\) 'health': health,",
      ).allMatches(service).length,
      2,
    );
    expect(service, contains("'updateManagedMember'"));
  });

  test('회원카드는 개인 워크스페이스 등록·수정 저장에서 건강정보를 함께 보낸다', () {
    expect(
      RegExp(r'health: _personalHealthPayload\(\),').allMatches(card).length,
      2,
    );
  });

  test('건강정보 payload는 서버 규칙과 같은 키와 안전한 숫자만 보낸다', () {
    final builder =
        RegExp(
          r'Map<String, dynamic> _personalHealthPayload\(\) \{[\s\S]*?\n  \}\n',
        ).firstMatch(card)!.group(0)!;

    for (final key in const [
      "'inbodyNotProvided'",
      "'diseaseHistory'",
      "'medicineHistory'",
      "'inbody'",
      "'heightCm'",
      "'weightKg'",
      "'bodyFatPct'",
      "'skeletalMuscleKg'",
      "'bodyFatKg'",
      "'bmi'",
      "'inbodyMeasuredAt'",
      "'femaleCondition'",
      "'enabled'",
      "'lastStartAt'",
      "'cycleDays'",
      "'memo'",
    ]) {
      expect(builder, contains(key), reason: key);
    }
    // 서버가 받지 않는 키(이미지 URL·updatedAt)와 날짜 객체는 보내지 않는다.
    expect(builder, isNot(contains('inbodyImageUrl')));
    expect(builder, isNot(contains('serverTimestamp')));
    expect(builder, isNot(contains('Timestamp.fromDate')));
    expect(builder, contains('personalMemberCalendarDateForSave('));
    expect(builder, contains('.clamp(10, 90)'));
  });

  test('인바디 값은 비어 있는 것이 기본이고 입력한 값만 저장한다', () {
    // 임의 샘플 값(170/65/18.5/29/12)이 기본으로 채워지거나 저장되지 않는다.
    for (final sample in const ['170.0', '65.0', '18.5', '29.0', '12.0']) {
      expect(card, isNot(contains("text: '$sample'")), reason: sample);
      expect(card, isNot(contains(".text = '$sample'")), reason: sample);
    }
    for (final controller in const [
      '_heightC',
      '_weightC',
      '_bfPctC',
      '_smmC',
      '_bfKgC',
    ]) {
      expect(
        card,
        contains('final $controller = TextEditingController();'),
        reason: controller,
      );
    }

    final builder =
        RegExp(
          r'Map<String, dynamic> _personalHealthPayload\(\) \{[\s\S]*?\n  \}\n',
        ).firstMatch(card)!.group(0)!;
    // 빈 칸·0은 보내지 않고, 입력한 값이 하나도 없으면 inbody는 null.
    expect(builder, contains('parsed > 0'));
    expect(builder, contains('if (height != null)'));
    expect(builder, contains('inbody.isEmpty ? null : inbody'));
    expect(builder, isNot(contains('?? 0')));
  });
}
