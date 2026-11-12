import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('계약서 작성 화면 스크롤 하단 여백에 시스템 내비게이션 바 높이를 더한다', () {
    final source = File('lib/pages/contract_page.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildEditView()');
    expect(start, isNonNegative);
    final body = source.substring(start, start + 700);

    expect(body, contains('24 + MediaQuery.of(context).padding.bottom'));
  });

  test('인사이트 화면 스크롤 하단 여백에 시스템 내비게이션 바 높이를 더한다', () {
    final source = File('lib/pages/stats_page.dart').readAsStringSync();
    final start = source.indexOf("title: 'MORE 인사이트'");
    expect(start, isNonNegative);
    final body = source.substring(start, start + 2200);

    expect(body, contains('28 + MediaQuery.of(context).padding.bottom'));
  });
}
