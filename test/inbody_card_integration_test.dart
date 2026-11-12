import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final card = File('lib/pages/client_card_page.dart').readAsStringSync();

  test('개인 워크스페이스 회원카드는 인바디 읽기를 공용 해석·본인 확인 화면으로 처리한다', () {
    expect(
      RegExp(
        r'if \(_isPersonalWorkspace\) \{\s*if \(!mounted\) return;\s*'
        r'await _applyInbodyScanToPersonalCard\(\s*'
        r'parseInbodyText\(recognizedText\.text\),\s*\);\s*return;\s*\}',
      ).hasMatch(card),
      isTrue,
    );
  });

  test('확정한 값만 입력칸에 채우고 사진은 저장하지 않으며 저장은 사용자가 누른다', () {
    final method =
        RegExp(
          r'Future<void> _applyInbodyScanToPersonalCard\(InbodyScanResult scan\) async \{[\s\S]*?\n  \}\n',
        ).firstMatch(card)!.group(0)!;

    expect(method, contains('showInbodyReviewSheet('));
    expect(method, contains('cardBirthDate: _birthDate'));
    expect(method, contains('cardGender: _gender'));
    expect(method, contains('showRawText: kDebugMode'));
    // 성별 수정은 사용자가 고른 경우에만, 생년월일은 자동으로 바꾸지 않는다.
    expect(method, contains('outcome.updateGender'));
    expect(method, isNot(contains('_birthDate =')));
    expect(method, isNot(contains('_birthTextC')));
    // 서버·Storage 직접 쓰기 없음.
    expect(method, isNot(contains('FirebaseStorage')));
    expect(method, isNot(contains('putFile')));
    expect(method, isNot(contains('FirebaseFirestore')));
    expect(method, contains('저장을 눌러 반영해 주세요'));
  });
}
