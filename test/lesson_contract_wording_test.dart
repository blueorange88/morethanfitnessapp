import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_rules.dart';

void main() {
  test('지각 기준 문장은 진행 불가로 못박는다', () {
    expect(lateLimitSentence(30), '레슨 시작시간 30분 이후는 레슨 진행이 불가합니다.');
    expect(lateLimitSentence(15), contains('15분'));
  });

  test('기본 조건의 지각 기준은 시작 30분 후이고 저장된 값이 없으면 같은 값을 쓴다', () {
    expect(ContractDefaults.standard.lateNoShowMinutes, 30);
    expect(ContractDefaults.fromMap(const {}).lateNoShowMinutes, 30);
    // 이미 `기준 없음`으로 저장한 값은 그대로 유지한다.
    expect(
      ContractDefaults.fromMap(const {
        'lateNoShowMinutes': null,
      }).lateNoShowMinutes,
      isNull,
    );
    expect(const LessonContractForm().lateNoShowMinutes, 30);
  });

  test('계약 문구에서 모호한 표현이 남아 있지 않다', () {
    final legacy = File('lib/pages/contract_page.dart').readAsStringSync();
    expect(legacy, contains('레슨 시작시간 '));
    expect(legacy, contains('분 이후는 레슨 진행이 불가합니다.'));
    expect(legacy, isNot(contains('레슨 약속시간')));
    expect(legacy, isNot(contains('레슨 진행이 어려울 수 있습니다')));
    expect(legacy, isNot(contains('계약서 사본이 제공될 수 있')));

    for (final directory in [
      Directory('lib/pages/lesson_contract'),
      Directory('lib/utils/lesson_contract'),
      Directory('lib/models/lesson_contract'),
    ]) {
      for (final file in directory.listSync().whereType<File>()) {
        final text = file.readAsStringSync();
        expect(
          text,
          isNot(contains('어려울 수')),
          reason: '${file.path}에 모호한 표현이 있어요.',
        );
        expect(text, isNot(contains('약속시간')), reason: file.path);
      }
    }
  });
}
