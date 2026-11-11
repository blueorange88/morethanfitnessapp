import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('회원 목록: 잔여 횟수 0은 자동 이동 없이 소진으로만 표시한다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();
    expect(source, contains("member.remainingSessions == 0"));
    expect(source, contains("? '소진'"));
    // 소진 회원을 자동으로 만료 그룹으로 옮기는 코드는 앱에 두지 않는다.
    expect(source, isNot(contains("'잔여 0회'")));
  });
}
