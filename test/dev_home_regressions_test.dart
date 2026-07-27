import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/home_page.dart';
import 'package:mtf_app/widgets/home/sections/home_weekly_goal_section.dart';

void main() {
  test('주간 이동 시 이번 주와 다음 주 목표 제목을 복원한다', () {
    expect(
      homeWeeklyGoalTitleForOffset(0, fallbackWeekTitle: 'fallback'),
      '이번 주 목표',
    );
    expect(
      homeWeeklyGoalTitleForOffset(1, fallbackWeekTitle: 'fallback'),
      '다음 주 목표',
    );
  });

  test('legacy 고객카드 복귀 뒤 그룹 목록을 다시 읽는다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();

    expect(source, contains('Future<void> _openEdit(Member member) async'));
    expect(
      RegExp(
        r'await Navigator\.push\([\s\S]*?'
        r'if \(!mounted \|\| _isPersonalWorkspace\) return;[\s\S]*?'
        r'await _loadGroups\(\);',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('personal 고객카드는 unscoped legacy 그룹을 조회하거나 노출하지 않는다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<void> _loadMemberGroupOptions\(\) async \{[\s\S]*?'
        r'if \(_isPersonalWorkspace\) \{[\s\S]*?'
        r"id: '__ungrouped__'[\s\S]*?return;[\s\S]*?"
        r"collection\('member_groups'\)",
      ).hasMatch(source),
      isTrue,
    );
    expect(
      source,
      contains(
        'else if (!_isPersonalWorkspace &&\n'
        '          groupId != null &&',
      ),
    );
  });

  test('MyPage 저장 오류는 특정 필드 특례 없이 첫 오류 필드를 찾는다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();

    expect(source, contains('_scrollToFirstInvalidProfileField()'));
    expect(source, contains('state.hasError'));
    expect(source, contains('Scrollable.ensureVisible('));
    expect(
      source,
      isNot(
        contains(
          'if (validateTrainerEnglishName(_nameEnController.text) != null)',
        ),
      ),
    );
  });

  test('Personal 주간 목표 입력은 빈 값과 0을 기본값으로 복원한다', () {
    expect(parseHomeWeeklyGoalInput('17'), 17);
    expect(parseHomeWeeklyGoalInput(''), 40);
    expect(parseHomeWeeklyGoalInput('0'), 40);
  });

  testWidgets('Personal 주간 목표 카드가 편집 callback을 한 번 호출한다', (tester) async {
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeWeeklyGoalSection(
            title: '이번 주 목표',
            weekCount: 3,
            goalTarget: 17,
            progress: 3 / 17,
            topFirst: 'PT',
            topSecond: 'OT',
            primaryColor: Colors.indigo,
            onEdit: () => editCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('주간 레슨 목표 수정'));

    expect(editCount, 1);
  });
}
