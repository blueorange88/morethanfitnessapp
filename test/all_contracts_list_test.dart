import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_type_item.dart';
import 'package:mtf_app/pages/lesson_contract/member_contracts_page.dart';
import 'package:mtf_app/services/personal_member_preferences_service.dart';
import 'package:mtf_app/widgets/lesson_type_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _doc({
  String status = 'completed',
  String no = 'PT-2610-0001',
  String product = 'PT 10회',
  String member = '홍길동',
  String memberId = '',
  DateTime? updated,
}) => {
  'status': status,
  'version': 1,
  'contractNo': no,
  'memberId': memberId,
  'member': {'name': member},
  'product': {'name': product, 'sessionCount': 10, 'paidAmount': 500000},
  'updatedAt': Timestamp.fromDate(updated ?? DateTime.utc(2026, 10, 20)),
};

MemberContractItem _item(String id, Map<String, dynamic> data) =>
    MemberContractItem.fromDoc(id, data);

void main() {
  group('filterContracts', () {
    final items = [
      _item('a', _doc(member: '홍길동', no: 'PT-2610-0001')),
      _item(
        'b',
        _doc(
          status: 'draft',
          member: '김영희',
          no: 'PT-2610-0002',
          product: '요가 20회',
        ),
      ),
      _item(
        'c',
        _doc(status: 'member_signed', member: '박철수', no: 'PT-2610-0003'),
      ),
      _item('d', _doc(status: 'superseded', member: '홍길동', no: 'PT-2610-0004')),
    ];

    test('회원 이름을 문서의 member.name에서 읽는다', () {
      expect(items.first.memberName, '홍길동');
      expect(_item('x', {'status': 'draft'}).memberName, '');
    });

    test('상태 필터: 진행 중은 작성·서명 대기, 완료는 완료만, 전체는 모두', () {
      List<String> ids(ContractListFilter f) =>
          filterContracts(items, filter: f).map((e) => e.id).toList();
      expect(ids(ContractListFilter.all), ['a', 'b', 'c', 'd']);
      expect(ids(ContractListFilter.open), ['b', 'c']);
      expect(ids(ContractListFilter.completed), ['a']);
    });

    test('검색: 회원 이름·계약번호·상품명, 대소문자·앞뒤 공백 무시', () {
      List<String> ids(String q) =>
          filterContracts(items, query: q).map((e) => e.id).toList();
      expect(ids('홍길'), ['a', 'd']);
      expect(ids(' 김영희 '), ['b']);
      expect(ids('pt-2610-0003'), ['c']);
      expect(ids('요가'), ['b']);
      expect(ids('없는사람'), isEmpty);
      expect(ids(''), ['a', 'b', 'c', 'd']);
    });

    test('검색과 상태 필터를 함께 쓴다', () {
      expect(
        filterContracts(
          items,
          query: '홍길동',
          filter: ContractListFilter.completed,
        ).map((e) => e.id),
        ['a'],
      );
    });
  });

  group('전체 목록 화면', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<MemberContractItem> items,
      List<ContractMemberItem> members = const [],
      List<String>? asked,
      List<String>? opened,
      Future<void> Function()? onOpenMembership,
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberContractsPage(
            personalOwnerUid: 'uid',
            memberId: null,
            autoStartWhenEmpty: true,
            onOpenMembership: onOpenMembership,
            membersLoader: (uid) => Stream.value(members),
            loader: (uid, memberId) {
              asked?.add('$uid:${memberId ?? 'ALL'}');
              return Stream.value(items);
            },
            formBuilder: (id) {
              opened?.add('form:${id ?? 'new'}');
              return const Scaffold(body: Text('FORM'));
            },
            flowBuilder: (id) {
              opened?.add('flow:$id');
              return const Scaffold(body: Text('FLOW'));
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('회원 이름이 제목이고 상품·계약번호가 아래에 보이며 전체 조회를 요청한다', (tester) async {
      final asked = <String>[];
      await pump(
        tester,
        asked: asked,
        items: [_item('a', _doc(member: '홍길동'))],
      );
      expect(asked, ['uid:ALL']);
      expect(find.text('계약서 관리'), findsOneWidget);
      // 인덱스 탭에는 이름과 레슨 종류, 종이에는 상품과 계약번호가 보인다.
      expect(find.text('홍길동 PT'), findsOneWidget);
      expect(find.text('PT 10회'), findsOneWidget);
      expect(find.textContaining('PT-2610-0001'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('member_contracts_search')),
        findsOneWidget,
      );
    });

    testWidgets('계약서가 하나도 없어도 새 작성으로 자동 이동하지 않는다', (tester) async {
      final opened = <String>[];
      await pump(tester, items: const [], opened: opened);
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(
        find.byKey(const ValueKey('member_contracts_empty')),
        findsOneWidget,
      );
    });

    testWidgets('검색어와 상태 필터로 줄이고, 맞는 게 없으면 안내한다', (tester) async {
      await pump(
        tester,
        items: [
          _item('a', _doc(member: '홍길동')),
          _item('b', _doc(status: 'draft', member: '김영희', no: 'PT-2610-0002')),
        ],
      );
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('member_contract_b')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('member_contracts_search')),
        '김영',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsNothing);
      expect(find.byKey(const ValueKey('member_contract_b')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_filter_completed')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_b')), findsNothing);
      expect(find.text('조건에 맞는 계약서가 없어요.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_search_clear')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
    });

    testWidgets('계약서를 열면 작성 중은 초안으로, 그 밖은 서명·완료 화면으로 간다', (tester) async {
      final opened = <String>[];
      await pump(
        tester,
        opened: opened,
        items: [_item('draft', _doc(status: 'draft')), _item('done', _doc())],
      );
      await tester.tap(find.byKey(const ValueKey('member_contract_draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_draft')));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_done')));
      await tester.pumpAndSettle();
      expect(opened, ['form:draft', 'flow:done']);
    });

    testWidgets('목록 맨 끝의 새 계약서 작성 카드로 레슨계약서를 시작한다(회원은 작성 화면에서 고른다)', (
      tester,
    ) async {
      final opened = <String>[];
      await pump(tester, opened: opened, items: [_item('a', _doc())]);
      await tester.tap(find.byKey(const ValueKey('member_contracts_add_card')));
      await tester.pumpAndSettle();
      expect(opened, ['form:new']);
    });

    testWidgets('회원권계약서로 갈 수 있으면 새 계약서를 누를 때 레슨·회원권 중 고른다', (tester) async {
      final opened = <String>[];
      var membership = 0;
      await pump(
        tester,
        opened: opened,
        items: [_item('a', _doc())],
        onOpenMembership: () async => membership++,
      );
      // 머리말 +와 맨 끝 카드가 같은 선택 시트를 연다.
      await tester.tap(find.byKey(const ValueKey('member_contracts_add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aifc_contract_chooser')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('aifc_membership_contract_action')),
      );
      await tester.pumpAndSettle();
      expect(membership, 1);
      expect(opened, isEmpty);

      await tester.tap(find.byKey(const ValueKey('member_contracts_add_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aifc_lesson_contract_action')));
      await tester.pumpAndSettle();
      expect(opened, ['form:new']);
    });

    testWidgets('머리말 요약 3칸: 진행 중 계약·미작성 회원·체결된 계약 수를 보여 준다', (tester) async {
      await pump(
        tester,
        items: [
          _item('a', _doc(memberId: 'm1')), // 체결(완료)
          _item('b', _doc(status: 'draft', memberId: 'm2', no: 'PT-2610-0002')),
          _item('c', _doc(memberId: 'm3', no: 'PT-2610-0003')),
        ],
        members: const [
          ContractMemberItem(
            id: 'm1',
            name: '홍길동',
            active: true,
            contractSigned: false,
          ),
          ContractMemberItem(
            id: 'm2',
            name: '이순신',
            active: true,
            contractSigned: false,
          ), // 작성 중 계약만 있어 미완료
          ContractMemberItem(
            id: 'm4',
            name: '신사임당',
            active: true,
            contractSigned: true,
          ), // 회원 문서에 계약 표시가 있어 완료
          ContractMemberItem(
            id: 'm5',
            name: '강감찬',
            active: false,
            contractSigned: false,
          ), // 휴면·만료는 센 대상이 아님
          ContractMemberItem(
            id: 'm6',
            name: '유관순',
            active: true,
            contractSigned: false,
          ), // 계약 없음
        ],
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member_contracts_stat_missing')),
          matching: find.text('2명'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member_contracts_stat_done')),
          matching: find.text('2건'),
        ),
        findsOneWidget,
      );

      // 계약 미완료 회원을 누르면 이름순 목록이 열리고, 고르면 그 회원의 새 계약 작성으로 간다.
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_missing')),
      );
      await tester.pumpAndSettle();
      expect(find.text('계약서가 없는 회원 2명'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('member_contracts_missing_m2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contracts_missing_m6')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contracts_missing_m1')),
        findsNothing,
      );
    });

    testWidgets('체결된 계약 카드를 누르면 완료된 계약만 보인다', (tester) async {
      await pump(
        tester,
        items: [
          _item('done', _doc()),
          _item('draft', _doc(status: 'draft', no: 'PT-2610-0002')),
        ],
      );
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_done')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('member_contract_done')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member_contract_draft')), findsNothing);
    });

    testWidgets('진행 중 계약 카드는 서명이 안 끝난 계약만 거르고 다시 누르면 풀린다', (tester) async {
      await pump(
        tester,
        items: [
          _item('done', _doc()),
          _item('draft', _doc(status: 'draft', no: 'PT-2610-0002')),
          _item('wait', _doc(status: 'disclosed', no: 'PT-2610-0003')),
        ],
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member_contracts_stat_open')),
          matching: find.text('2건'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_open')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('member_contract_draft')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contract_wait')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member_contract_done')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_open')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('member_contract_done')),
        findsOneWidget,
      );
    });

    testWidgets('머리말에는 안내 문구 없이 아이콘·이름·숫자만 있다', (tester) async {
      await pump(tester, items: [_item('a', _doc())]);
      expect(find.text('눌러서 확인'), findsNothing);
      expect(find.text('회원권 합산은 준비 중'), findsNothing);
      expect(find.text('진행 중 계약'), findsOneWidget);
      expect(find.text('미작성 회원'), findsOneWidget);
      expect(find.text('체결된 계약'), findsOneWidget);
    });

    testWidgets('취소·파기된 계약서는 목록에서 숨기고 더보기의 별도 화면에서 본다', (tester) async {
      await pump(
        tester,
        items: [
          _item('done', _doc()),
          _item('void', _doc(status: 'voided', no: 'PT-2610-0002')),
          _item('cancel', _doc(status: 'cancelled', no: 'PT-2610-0003')),
        ],
      );
      expect(
        find.byKey(const ValueKey('member_contract_done')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member_contract_void')), findsNothing);
      expect(
        find.byKey(const ValueKey('member_contracts_toggle_cancelled')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('member_contracts_more')));
      await tester.pumpAndSettle();
      expect(find.text('2건 · 지난 기록 보기'), findsOneWidget);
      await tester.tap(find.text('취소·파기된 계약서'));
      await tester.pumpAndSettle();
      expect(find.text('취소·파기된 계약서'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('member_contract_void')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contract_cancel')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member_contract_done')), findsNothing);
    });

    testWidgets('좁은 화면(320·360dp)에서도 머리말 카드와 목록이 넘치지 않는다', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in const <double>[320, 360]) {
        tester.view.devicePixelRatio = 2.0;
        tester.view.physicalSize = Size(width * 2, 1800);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: MemberContractsPage(
              personalOwnerUid: 'uid',
              memberId: null,
              membersLoader: (uid) => Stream.value(const []),
              loader:
                  (uid, memberId) => Stream.value([
                    _item('a', _doc(member: '매우 긴 회원 이름 테스트 홍길동')),
                    _item('b', _doc(status: 'draft', no: 'PT-2610-0002')),
                  ]),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'width=$width');
        expect(
          find.byKey(const ValueKey('member_contracts_add_card')),
          findsOneWidget,
          reason: 'width=$width',
        );
      }
    });

    testWidgets('회원 목록을 못 받아도 계약서 목록은 그대로 보이고 미완료 수는 -', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberContractsPage(
            personalOwnerUid: 'uid',
            memberId: null,
            loader: (uid, memberId) => Stream.value([_item('a', _doc())]),
            membersLoader: (uid) => Stream<List<ContractMemberItem>>.error('x'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member_contracts_stat_missing')),
          matching: find.text('-'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('0건인 머리말 카드를 누르면 안내 토스트가 뜨고 목록은 그대로다', (tester) async {
      await pump(tester, items: [_item('a', _doc())]);
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_open')),
      );
      await tester.pump();
      expect(find.text('진행 중인 계약이 없습니다.'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_missing')),
      );
      await tester.pump();
      expect(find.text('미작성 회원이 없습니다.'), findsOneWidget);
      expect(find.text('계약서가 없는 회원 0명'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('체결된 계약이 0건이면 안내 토스트가 뜬다', (tester) async {
      await pump(tester, items: [_item('a', _doc(status: 'draft'))]);
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_stat_done')),
      );
      await tester.pump();
      expect(find.text('체결된 계약이 없습니다.'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('계약서 카드는 종이를 누르면 요약이 펼쳐지고, 인덱스 탭으로 접고, 펼친 종이를 누르면 연다', (
      tester,
    ) async {
      final opened = <String>[];
      await pump(
        tester,
        opened: opened,
        items: [
          _item(
            'a',
            _doc(memberId: 'm1')
              ..['member'] = {'name': '홍길동', 'phone': '010-1234-5678'}
              ..['product'] = {
                'name': 'PT 10회',
                'sessionCount': 10,
                'periodEnd': '2099-12-31',
              },
          ),
        ],
        members: [
          ContractMemberItem.fromDoc('m1', {
            'name': '홍길동',
            'sessions': {'total': 10, 'remain': 7},
            'membership': {'endAt': Timestamp.fromDate(DateTime(2099, 12, 31))},
          }),
        ],
      );
      expect(
        find.byKey(const ValueKey('member_contract_summary_a')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('member_contract_a')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      final summary = find.byKey(const ValueKey('member_contract_summary_a'));
      expect(summary, findsOneWidget);
      for (final text in [
        '홍길동님 레슨계약서',
        '010-1234-5678',
        'PT 10회',
        '총 10회 / 소진 3회',
        '총 결제금액',
      ]) {
        expect(
          find.descendant(of: summary, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }

      // 인덱스 탭을 누르면 접힌다(계약서는 열리지 않는다).
      await tester.tap(find.byKey(const ValueKey('member_contract_tab_a')));
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(opened, isEmpty);

      // 펼친 뒤 머리(제목 줄)를 누르면 접히고, 계약서는 열리지 않는다.
      await tester.tap(find.byKey(const ValueKey('member_contract_head_a')));
      await tester.pumpAndSettle();
      expect(summary, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('member_contract_head_a')));
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(opened, isEmpty);

      // 머리를 눌러 다시 펼친 뒤 펼친 내용을 누르면 계약서를 연다.
      await tester.tap(find.byKey(const ValueKey('member_contract_head_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_summary_a')));
      await tester.pumpAndSettle();
      expect(opened, ['flow:a']);
    });

    testWidgets('펼친 요약도 좁은 화면(320dp)에서 넘치지 않는다', (tester) async {
      await pump(
        tester,
        items: [
          _item(
            'a',
            _doc(product: '아주아주 긴 이름의 프리미엄 퍼스널 트레이닝 상품 100회권')
              ..['member'] = {'name': '홍길동', 'phone': '010-1234-5678'},
          ),
        ],
      );
      tester.view.physicalSize = const Size(640, 2000);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('member_contract_a')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('member_contract_summary_a')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('addRecentContractQuery', () {
    test('맨 앞에 넣고, 같은 검색어(대소문자 무시)는 하나로 합치고, 최대 개수를 지킨다', () {
      expect(addRecentContractQuery(['a', 'b'], ' c '), ['c', 'a', 'b']);
      expect(addRecentContractQuery(['a', 'B'], 'b'), ['b', 'a']);
      expect(addRecentContractQuery(['a'], '   '), ['a']);
      final many = [for (var n = 0; n < 5; n++) 'q$n'];
      final next = addRecentContractQuery(many, 'new');
      expect(next.length, 5);
      expect(next.first, 'new');
      expect(next.contains('q4'), isFalse);
    });
  });

  group('최근 검색어 화면', () {
    Future<void> pumpPage(WidgetTester tester) async {
      // 칩 줄이 옆으로 밀리는 목록이라 화면 밖 칩은 만들어지지 않는다. 넓은 화면에서 확인한다.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(3000, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberContractsPage(
            personalOwnerUid: 'uid',
            memberId: null,
            autoStartWhenEmpty: false,
            membersLoader: (uid) => Stream.value(const []),
            loader:
                (uid, memberId) => Stream.value([
                  _item('a', _doc(member: '홍길동')),
                  _item('b', _doc(member: '김영희', no: 'PT-2610-0002')),
                ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('검색 키를 누르면 칩 줄에 최근 검색어가 생기고, 눌러서 다시 검색하고, x로 지운다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPage(tester);
      final search = find.byKey(const ValueKey('member_contracts_search'));

      // 아직 기록이 없으면 최근 검색어 칩이 없다.
      expect(
        find.byKey(const ValueKey('member_contracts_recent_김영')),
        findsNothing,
      );

      await tester.enterText(search, '김영');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.enterText(search, '');
      await tester.pump();
      final chip = find.byKey(const ValueKey('member_contracts_recent_김영'));
      expect(chip, findsOneWidget);

      // 저장돼 있다.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('member_contracts_recent_uid'), ['김영']);

      // 눌러서 다시 검색한다.
      await tester.tap(chip);
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsNothing);
      expect(find.byKey(const ValueKey('member_contract_b')), findsOneWidget);

      // 칩의 x로 지운다.
      await tester.tap(
        find.descendant(of: chip, matching: find.byType(Icon)).last,
      );
      await tester.pump();
      expect(chip, findsNothing);
      expect(prefs.getStringList('member_contracts_recent_uid'), isEmpty);
    });

    testWidgets('저장된 최근 검색어는 5개까지만 칩으로 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'member_contracts_recent_uid': ['a1', 'a2', 'a3', 'a4', 'a5', 'a6'],
      });
      await pumpPage(tester);
      await tester.pump();
      for (final text in ['a1', 'a2', 'a3', 'a4', 'a5']) {
        expect(
          find.byKey(ValueKey('member_contracts_recent_$text')),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.byKey(const ValueKey('member_contracts_recent_a6')),
        findsNothing,
      );
    });

    testWidgets('상태·종류·최근 검색어 칩은 한 줄로 옆으로 밀어서 본다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'member_contracts_recent_uid': ['홍', '이'],
      });
      await pumpPage(tester);
      await tester.pump();
      final row = find.byKey(const ValueKey('member_contracts_chip_row'));
      final list = tester.widget<ListView>(row);
      expect(list.scrollDirection, Axis.horizontal);
      // 같은 줄(같은 세로 위치)에 상태 칩과 종류 칩이 있다.
      final y1 =
          tester
              .getCenter(
                find.byKey(const ValueKey('member_contracts_filter_all')),
              )
              .dy;
      final y2 =
          tester
              .getCenter(
                find.byKey(const ValueKey('member_contracts_kind_lesson')),
              )
              .dy;
      expect(y1, y2);
    });

    testWidgets('최근 검색어 칩은 전체 칩 바로 뒤, 진행 중·완료 칩 앞에 늘어선다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'member_contracts_recent_uid': ['홍', '이'],
      });
      await pumpPage(tester);
      await tester.pump();
      double x(String key) => tester.getCenter(find.byKey(ValueKey(key))).dx;
      expect(
        x('member_contracts_filter_all') < x('member_contracts_recent_홍'),
        isTrue,
      );
      expect(
        x('member_contracts_recent_홍') < x('member_contracts_recent_이'),
        isTrue,
      );
      expect(
        x('member_contracts_recent_이') < x('member_contracts_filter_open'),
        isTrue,
      );
      expect(
        x('member_contracts_filter_open') <
            x('member_contracts_filter_completed'),
        isTrue,
      );
    });

    testWidgets('회원권·양도권 칩은 아직 계약서가 없어 준비 중 안내를 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_kind_membership')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsNothing);
      expect(find.text('회원권계약서는 준비 중이에요.'), findsOneWidget);

      // 레슨 칩은 레슨계약서를 보이고, 다시 누르면 해제된다.
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_kind_lesson')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_kind_lesson')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
    });
  });

  group('바인더 종류·색 규칙', () {
    test('내 레슨 종류 이름이 상품 이름에 있으면 그 이름, 없으면 서비스 내용, 그래도 없으면 PT', () {
      final known = [...kBuiltInLessonTypes, '발레핏', '바레'];
      expect(contractLessonTypeNameOf('PT 10회', known: known), 'PT');
      expect(contractLessonTypeNameOf('필라테스 20회', known: known), '필라테스');
      expect(contractLessonTypeNameOf('발레핏 30회', known: known), '발레핏');
      expect(contractLessonTypeNameOf('재활 10회', known: known), '재활');
      // 이름이 숫자뿐이면 서비스 내용에서, 그래도 없으면 PT.
      expect(
        contractLessonTypeNameOf('10', serviceContent: '바레 레슨', known: known),
        '바레',
      );
      expect(contractLessonTypeNameOf('30회 패키지', known: known), 'PT');
      // 상품 이름이 서비스 내용보다 먼저다.
      expect(
        contractLessonTypeNameOf(
          '요가 10회',
          serviceContent: '필라테스 겸용',
          known: known,
        ),
        '요가',
      );
    });

    test('기본 색은 정해 둔 종류는 고정이고, 나머지는 이름마다 일정하다', () {
      expect(defaultContractBinderColor('PT'), kLessonTypePalette[0]);
      expect(defaultContractBinderColor('필라테스'), kLessonTypePalette[1]);
      expect(defaultContractBinderColor('요가'), kLessonTypePalette[4]);
      expect(
        defaultContractBinderColor('발레핏'),
        defaultContractBinderColor('발레핏'),
      );
      expect(kLessonTypePalette, contains(defaultContractBinderColor('댄스')));
    });

    test('바인더 색은 이름이 같은 홈 레슨 종류의 색이 먼저, 없으면 기본 색이다', () {
      const gyro = Color(0xFF123456);
      final home = {customLessonTypeComparisonKey('자이로토닉'): gyro};
      expect(resolveContractBinderColor('자이로토닉', home), gyro);
      // 대소문자·공백이 달라도 같은 이름으로 본다.
      expect(resolveContractBinderColor(' 자이로토닉 ', home), gyro);
      expect(
        resolveContractBinderColor('PT', home),
        defaultContractBinderColor('PT'),
      );
    });

    test('탭 글씨는 어두운 색 위에서는 흰색, 밝은 색 위에서는 짙은 색이다', () {
      const darkInk = Color(0xFF1F2937);
      expect(lessonTypeInkColor(const Color(0xFF1F3A8A)), Colors.white);
      expect(lessonTypeInkColor(const Color(0xFF4F46E5)), Colors.white);
      expect(lessonTypeInkColor(const Color(0xFFFFE082)), darkInk);
      expect(lessonTypeInkColor(const Color(0xFFFFFFFF)), darkInk);
      // 모든 공용 팔레트 색에서 글씨 대비가 3 이상이다.
      for (final color in kLessonTypePalette) {
        final ink = lessonTypeInkColor(color);
        final l1 = color.computeLuminance();
        final l2 = ink.computeLuminance();
        final hi = l1 > l2 ? l1 : l2;
        final lo = l1 > l2 ? l2 : l1;
        expect((hi + 0.05) / (lo + 0.05), greaterThan(3));
      }
    });

    test('인덱스 탭 위치는 레슨 왼쪽, 회원권 가운데, 양도권 오른쪽이다', () {
      expect(ContractFileKind.lesson.tabSlot, -1);
      expect(ContractFileKind.membership.tabSlot, 0);
      expect(ContractFileKind.transfer.tabSlot, 1);
    });

    test('해지·이전 버전, 기간이 지났거나 횟수를 모두 쓴 체결 계약은 끝난 계약이다', () {
      MemberContractItem item(
        String status, {
        String? periodEnd,
        bool unlimited = false,
      }) => MemberContractItem.fromDoc('x', {
        'status': status,
        'product': {
          'name': 'PT 10회',
          if (periodEnd != null) 'periodEnd': periodEnd,
          'periodUnlimited': unlimited,
        },
      });
      final now = DateTime(2026, 11, 9);
      expect(item('terminated').isEnded(now: now), isTrue);
      expect(item('superseded').isEnded(now: now), isTrue);
      expect(item('draft', periodEnd: '2020-01-01').isEnded(now: now), isFalse);
      expect(
        item('completed', periodEnd: '2026-11-08').isEnded(now: now),
        isTrue,
      );
      expect(
        item('completed', periodEnd: '2026-11-09').isEnded(now: now),
        isFalse,
      );
      expect(
        item(
          'completed',
          periodEnd: '2020-01-01',
          unlimited: true,
        ).isEnded(now: now),
        isFalse,
      );
      final used = ContractMemberItem.fromDoc('m', {
        'sessions': {'total': 10, 'remain': 0},
      });
      expect(item('completed').isEnded(member: used, now: now), isTrue);
    });
  });

  group('홈 레슨 종류와 바인더', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberContractsPage(
            personalOwnerUid: 'uid',
            memberId: null,
            autoStartWhenEmpty: false,
            membersLoader: (uid) => Stream.value(const []),
            lessonTypesLoader: (uid) async => const [],
            loader:
                (uid, memberId) => Stream.value([
                  _item('a', _doc(member: '홍길동', product: '자이로토닉 10회')),
                ]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('홈에서 만든 레슨 종류 이름이 인덱스 탭에 붙는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        kHomeLessonTypesPrefsKey:
            '[{"id":"t1","name":"자이로토닉","colorHex":"#123456"}]',
      });
      await pumpPage(tester);
      expect(find.text('홍길동 자이로토닉'), findsOneWidget);
    });

    testWidgets('홈 레슨 종류가 없으면 PT로 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPage(tester);
      expect(find.text('홍길동 PT'), findsOneWidget);
    });

    testWidgets('더보기 메뉴에는 바인더 색 설정이 없다(색은 홈 레슨 종류에서 정한다)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('member_contracts_more')));
      await tester.pumpAndSettle();
      expect(find.text('바인더 색 설정'), findsNothing);
      expect(find.text('취소·파기된 계약서'), findsOneWidget);
    });

    test('저장된 홈 레슨 종류를 읽고, 깨진 값은 빈 목록으로 본다', () {
      final items = parseHomeLessonTypes(
        '[{"id":"t1","name":"발레핏","colorHex":"#D64545"},{"id":"","name":"x"},{"id":"t3","name":" "}]',
      );
      expect(items.map((e) => e.name), ['발레핏']);
      expect(parseHomeLessonTypes(null), isEmpty);
      expect(parseHomeLessonTypes('not json'), isEmpty);
      expect(lessonTypeColorTryParse('#D64545'), const Color(0xFFD64545));
      expect(lessonTypeColorTryParse('D64545'), const Color(0xFFD64545));
      expect(lessonTypeColorTryParse('zz'), isNull);
    });
  });

  group('contractCardSummary', () {
    test('체결된 계약은 회원 문서의 총/소진을, 아직인 계약은 계약서의 횟수를 보여 준다', () {
      final member = ContractMemberItem.fromDoc('m1', {
        'name': '홍길동',
        'sessions': {'total': 20, 'remain': 5},
      });
      final done = contractCardSummary(
        _item('a', _doc(memberId: 'm1')),
        member,
      );
      expect(done.sessions, '총 20회 / 소진 15회');
      expect(done.heading, '홍길동님 레슨계약서');
      final draft = contractCardSummary(
        _item('b', _doc(status: 'draft', memberId: 'm1')),
        member,
      );
      expect(draft.sessions, '총 10회');
      expect(draft.phone, '-');
    });

    test('남은 기간: 종료일 없음·기간 제한 없음·지남·오늘·남음', () {
      final now = DateTime(2026, 11, 2);
      expect(remainingPeriodLabel(null, now: now), '-');
      expect(remainingPeriodLabel(DateTime(2026, 11, 1), now: now), '만료');
      expect(remainingPeriodLabel(DateTime(2026, 11, 2), now: now), 'D-day');
      expect(remainingPeriodLabel(DateTime(2026, 11, 9), now: now), 'D-7');
      final unlimited =
          _doc()..['product'] = {'name': 'PT', 'periodUnlimited': true};
      expect(
        contractCardSummary(_item('u', unlimited), null).period,
        '기간 제한 없음',
      );
    });
  });

  group('membersWithoutContract', () {
    test('해지로 계약 표시가 지워진 회원과 이름 없는 회원 처리', () {
      final members = [
        ContractMemberItem.fromDoc('m1', {
          'name': '홍길동',
          'contractSigned': true,
          'contractStatus': 'terminated', // 해지: 계약 표시가 있어도 미완료
        }),
        ContractMemberItem.fromDoc('m2', {
          'name': '이순신',
          'lessonSync': {'contractSigned': true},
        }),
        ContractMemberItem.fromDoc('m3', {'name': '', 'memberStatus': '활성'}),
        ContractMemberItem.fromDoc('m4', {'name': '유관순', 'isDeleted': true}),
        ContractMemberItem.fromDoc('m5', {
          'name': '강감찬',
          'managementState': 'expired',
        }),
        ContractMemberItem.fromDoc('m6', {'name': '가나다'}),
      ];
      expect(membersWithoutContract(members, const []).map((m) => m.name), [
        '가나다',
        '홍길동',
      ]);
    });
  });

  test('MY 페이지의 계약서 관리는 개인 워크스페이스에서 새 계약서 전체 목록을 연다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    final open = source.substring(
      source.indexOf('void _openContractListPage()'),
      source.indexOf('Future<void> _openStatsPage()'),
    );
    expect(open, contains('if (_isPersonalWorkspace)'));
    expect(open, contains('MemberContractsPage('));
    expect(open, contains('memberId: null'));
    // 개인이 아닌 워크스페이스는 기존 목록 그대로.
    expect(open, contains('ContractListPage('));
  });
}
