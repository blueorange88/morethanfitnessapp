import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // 이미 등록된 회원의 카드를 여는 곳은 모두 수정 모드여야 한다. 기본값(false)이면 신규 등록
  // 화면이 되어 서버 값을 불러오지 않고(성별·전화번호가 비어 보임), 저장하면 새 회원이
  // 만들어진다(이름을 바꾸면 카드가 둘이 되는 문제).
  test('기존 회원 카드를 여는 ClientCardPage 호출은 isEditMode: true를 쓴다', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('client_card_page.dart'));

    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // `ClientCardPage(` 기본 생성자 호출만 검사한다(.edit/.fromQuickRegistration/.newMember 제외).
        if (!RegExp(r'(?<![\w.])ClientCardPage\(').hasMatch(lines[i])) continue;
        final window = lines.skip(i).take(10).join('\n');
        final isNewMemberOrQuick =
            window.contains('initialName:') ||
            window.contains('isEditMode: false');
        if (isNewMemberOrQuick) continue;
        if (!window.contains('isEditMode: true')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty, reason: '수정 모드 없이 기존 회원 카드를 여는 곳: $offenders');
  });

  test('일정(레슨)에서 회원카드를 여는 곳은 수정 모드이고 이유를 주석으로 남긴다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<void> _openClientCardFromSchedule[\s\S]*?'
        r'ClientCardPage\(\s*memberId: resolvedMemberId,[\s\S]*?'
        r'isEditMode: true,',
      ).hasMatch(source),
      isTrue,
    );
  });
}
