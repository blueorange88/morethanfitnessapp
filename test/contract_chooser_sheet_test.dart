import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/contract_chooser_sheet.dart';

void main() {
  Future<ContractKind?> openAndPick(WidgetTester tester, Key? tapKey) async {
    ContractKind? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showContractChooserSheet(context);
                    done = true;
                  },
                  child: const Text('열기'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 계약서를 열까요?'), findsOneWidget);
    expect(find.text('레슨계약서'), findsOneWidget);
    expect(find.text('회원권계약서'), findsOneWidget);
    if (tapKey != null) {
      await tester.tap(find.byKey(tapKey));
    } else {
      await tester.tapAt(const Offset(10, 10));
    }
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return result;
  }

  testWidgets('레슨계약서·회원권계약서를 골라 돌려준다', (tester) async {
    expect(
      await openAndPick(tester, const Key('aifc_lesson_contract_action')),
      ContractKind.lesson,
    );
    expect(
      await openAndPick(tester, const Key('aifc_membership_contract_action')),
      ContractKind.membership,
    );
  });

  testWidgets('그냥 닫으면 null', (tester) async {
    expect(await openAndPick(tester, null), isNull);
  });

  test('회원카드 상단 계약서 아이콘은 선택 시트를 거쳐 두 계약서로 간다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _openContractChooser()');
    final end = source.indexOf('Widget _buildBasicInfoPagerHeader()', start);
    expect(start, greaterThan(0));
    final body = source.substring(start, end);

    expect(body, contains('showContractChooserSheet(context)'));
    expect(body, contains('ContractKind.lesson'));
    expect(body, contains('_openContract()'));
    expect(body, contains('_openMembershipContractDraft()'));
    expect(body, contains('onTap: _openContractChooser'));
    // 아이콘이 바로 레슨계약서로 가지 않는다.
    expect(body, isNot(contains('onTap: _openContract,')));
  });

  test('회원카드 상단 카드의 계약서 아이콘도 선택 시트로 연결된다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    expect(source, contains('onContractTap: _openContractChooser,'));
    expect(source, isNot(contains('onContractTap: _openContract,')));
  });

  test('회원카드 하단 바는 아이콘+글씨 한 줄이고 스크롤에 따라 숨고 나타난다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    expect(source, contains('ScrollRevealBottomBar('));
    expect(source, contains("Key('client_card_bottom_bar')"));
    // 저장 중에는 숨지 않는다.
    expect(source, contains('forceVisible: _isSaving'));
    final button = source.substring(
      source.indexOf('class _ClientCardBottomActionButton'),
      source.indexOf('class _KoreaPhoneTextInputFormatter'),
    );
    expect(button, contains('Row('));
    expect(button, isNot(contains('Column(')));
    expect(button, contains('maxLines: 1'));
  });

  test('회원카드 하단 바: 레슨계약서(새로 작성)가 왼쪽, 레슨일지가 저장 버튼 옆(오른손 엄지 쪽)이다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final bar = source.substring(
      source.indexOf("Key('client_card_bottom_bar')"),
      source.indexOf(
        'body: Column(',
        source.indexOf("Key('client_card_bottom_bar')"),
      ),
    );
    final contract = bar.indexOf("label: '레슨계약서'");
    final log = bar.indexOf("label: '레슨일지'");
    final save = bar.indexOf('회원 저장');
    expect(contract, greaterThan(-1));
    expect(contract, lessThan(log));
    expect(log, lessThan(save));
    expect(bar, contains('onTap: _openNewLessonContract'));
    expect(bar, contains('onTap: _openTrainingLogWithConsent'));
    // 새 작성은 이 회원으로 바로 시작한다.
    expect(source, contains('initialMemberId: widget.memberId,'));
  });

  test('회원권계약서 작성할 회원 선택 시트는 하드코딩 색 없이 테마 색(다크 모드 대응)을 쓴다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf(
      '_showMembershipContractMemberPicker() async {',
    );
    final end = source.indexOf(
      'String _homeMembershipDateText(DateTime? value)',
      start,
    );
    final body = source.substring(start, end);
    expect(body, contains('Theme.of(sheetContext).colorScheme'));
    expect(body, contains('color: colors.surface,'));
    expect(body, contains('color: colors.onSurface,'));
    expect(body, contains('colors.onSurfaceVariant'));
    // 라이트 전용 흰색·회색 하드코딩이 남지 않는다.
    expect(body, isNot(contains('Colors.white')));
    for (final hex in [
      '0xFFE5E7EB',
      '0xFFF8FAFC',
      '0xFFEEF2FF',
      '0xFF111827',
      '0xFF6B7280',
      '0xFF9CA3AF',
      '0xFF4F46E5',
    ]) {
      expect(body, isNot(contains(hex)), reason: hex);
    }
  });
}
