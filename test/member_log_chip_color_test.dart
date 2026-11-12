import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/client_list_page.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('회원 관리 레슨일지 칩 배경이 홈 레슨 등록의 레슨계약서 칩 배경과 같다', () {
    final source =
        File(
          'lib/widgets/home/lesson_editor/home_lesson_quick_actions_section.dart',
        ).readAsStringSync();
    // 홈 칩이 쓰는 계약 칩 배경(어두운 모드 → 밝은 모드 순서)
    expect(
      source,
      contains('isDark ? const Color(0xFF4A401F) : const Color(0xFFFFF1C2)'),
    );
    expect(memberLogChipBackground(true), const Color(0xFF4A401F));
    expect(memberLogChipBackground(false), const Color(0xFFFFF1C2));
  });

  test('두 모드 모두 칩 안의 글씨와 아이콘이 배경 위에서 읽힌다', () {
    for (final dark in [false, true]) {
      final bg = memberLogChipBackground(dark);
      expect(_contrast(memberLogChipTextColor(dark), bg), greaterThan(4.5));
      expect(_contrast(memberLogChipIconColor(dark), bg), greaterThan(3.0));
    }
  });
}
