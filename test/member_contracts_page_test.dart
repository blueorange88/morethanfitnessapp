import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/lesson_contract/member_contracts_page.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';

Map<String, dynamic> _doc({
  String status = 'completed',
  int version = 1,
  String no = 'PT-2610-0001',
  String name = 'PT 10회',
  DateTime? updated,
  DateTime? completed,
}) => {
  'status': status,
  'version': version,
  'contractNo': no,
  'product': {'name': name, 'sessionCount': 10, 'paidAmount': 500000},
  'updatedAt': Timestamp.fromDate(updated ?? DateTime.utc(2026, 10, 20)),
  'completedAt': completed == null ? null : Timestamp.fromDate(completed),
};

class _FakeGateway extends PersonalContractGateway {
  _FakeGateway({this.error})
    : super(
        callable: (name, parameters) async {
          throw UnimplementedError(name);
        },
      );

  final Object? error;
  final List<({String id, String reason})> cancelled = [];

  @override
  Future<void> cancelContract(
    String contractId, {
    required String reason,
  }) async {
    if (error != null) throw error!;
    cancelled.add((id: contractId, reason: reason));
  }
}

MemberContractItem _item(String id, Map<String, dynamic> data) =>
    MemberContractItem.fromDoc(id, data);

void main() {
  group('MemberContractItem', () {
    test('문서에서 계약번호(새 버전은 -v), 상품, 횟수, 금액을 읽는다', () {
      final item = _item('a', _doc(version: 2, no: 'PT-2610-0003'));
      expect(item.contractNo, 'PT-2610-0003-v2');
      expect(item.productName, 'PT 10회');
      expect(item.sessionCount, 10);
      expect(item.paidAmount, 500000);
      expect(_item('b', _doc()).contractNo, 'PT-2610-0001');
    });

    test('상태 이름과 열린 계약 여부', () {
      final labels = {
        'draft': '작성 중',
        'disclosed': '회원 서명 대기',
        'member_signed': '강사 서명 대기',
        'completed': '완료',
        'superseded': '이전 버전',
        'cancelled': '취소됨',
      };
      labels.forEach((status, label) {
        expect(_item('x', _doc(status: status)).statusLabel, label);
      });
      expect(_item('x', _doc(status: 'draft')).isOpen, isTrue);
      expect(_item('x', _doc(status: 'member_signed')).isOpen, isTrue);
      expect(_item('x', _doc(status: 'completed')).isOpen, isFalse);
      expect(_item('x', _doc(status: 'cancelled')).isOpen, isFalse);
    });

    test('완료일이 있으면 완료일, 없으면 수정일을 보이고 최근 것이 위에 온다', () {
      final done = _item(
        'done',
        _doc(
          completed: DateTime.utc(2026, 10, 22),
          updated: DateTime.utc(2026, 10, 22),
        ),
      );
      final draft = _item(
        'draft',
        _doc(status: 'draft', updated: DateTime.utc(2026, 10, 25)),
      );
      final old = _item(
        'old',
        _doc(status: 'superseded', updated: DateTime.utc(2026, 10, 1)),
      );
      expect(
        done.shownDate!.isAtSameMomentAs(DateTime.utc(2026, 10, 22)),
        isTrue,
      );
      expect(
        draft.shownDate!.isAtSameMomentAs(DateTime.utc(2026, 10, 25)),
        isTrue,
      );
      expect(sortMemberContracts([old, done, draft]).map((e) => e.id), [
        'draft',
        'done',
        'old',
      ]);
    });
  });

  group('MemberContractsPage', () {
    Future<void> pump(
      WidgetTester tester, {
      required Stream<List<MemberContractItem>> stream,
      bool autoStart = true,
      List<String>? opened,
      Future<void> Function()? onOpenMembership,
      PersonalContractGateway? gateway,
    }) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberContractsPage(
            personalOwnerUid: 'uid',
            memberId: 'member',
            memberName: '홍회원',
            autoStartWhenEmpty: autoStart,
            onOpenMembership: onOpenMembership,
            gateway: gateway,
            loader: (_, __) => stream,
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

    testWidgets('불러오는 동안 진행 표시를 보이고, 목록에 상태와 요약을 보여 준다', (tester) async {
      final controller = StreamController<List<MemberContractItem>>();
      addTearDown(controller.close);
      await pump(tester, stream: controller.stream);
      expect(
        find.byKey(const ValueKey('member_contracts_loading')),
        findsOneWidget,
      );
      controller.add([
        _item('a', _doc(completed: DateTime.utc(2026, 10, 22))),
        _item('b', _doc(status: 'draft', no: 'PT-2610-0002')),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('홍회원 레슨계약서'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_contract_a')), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      expect(find.text('작성 중'), findsOneWidget);
      expect(
        find.textContaining('PT-2610-0001 · 10회 · 500,000원'),
        findsOneWidget,
      );
    });

    testWidgets('작성 중은 초안 화면으로, 그 밖에는 서명·완료 화면으로 연다', (tester) async {
      final opened = <String>[];
      await pump(
        tester,
        opened: opened,
        stream: Stream.value([
          _item('draft', _doc(status: 'draft')),
          _item('done', _doc(completed: DateTime.utc(2026, 10, 22))),
        ]),
      );
      // 한 번 누르면 펼쳐지고, 한 번 더 누르면 계약서가 열린다.
      await tester.tap(find.byKey(const ValueKey('member_contract_draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_draft')));
      await tester.pumpAndSettle();
      expect(opened, ['form:draft']);
      expect(find.text('FORM'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_contract_done')));
      await tester.pumpAndSettle();
      expect(opened, ['form:draft', 'flow:done']);
    });

    testWidgets('새 레슨계약서 작성 버튼은 이 회원으로 새 계약을 시작한다', (tester) async {
      final opened = <String>[];
      await pump(
        tester,
        opened: opened,
        stream: Stream.value([_item('a', _doc())]),
      );
      await tester.tap(find.byKey(const ValueKey('member_contracts_new')));
      await tester.pumpAndSettle();
      expect(opened, ['form:new']);
    });

    testWidgets('계약서가 하나도 없으면 바로 새 계약 작성 화면으로 간다', (tester) async {
      final opened = <String>[];
      await pump(tester, opened: opened, stream: Stream.value(const []));
      await tester.pumpAndSettle();
      expect(opened, ['form:new']);
      expect(find.text('FORM'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_contracts_new')), findsNothing);
    });

    testWidgets('자동 시작을 끄면 빈 목록 안내와 작성 버튼을 보여 준다', (tester) async {
      await pump(tester, autoStart: false, stream: Stream.value(const []));
      expect(
        find.byKey(const ValueKey('member_contracts_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contracts_new')),
        findsOneWidget,
      );
    });

    testWidgets('회원권계약서 동작을 주면 회원권계약서 작성 버튼을 함께 보여 준다', (tester) async {
      var membershipOpened = 0;
      await pump(
        tester,
        autoStart: false,
        stream: Stream.value(const []),
        onOpenMembership: () async => membershipOpened += 1,
      );
      expect(
        find.byKey(const ValueKey('member_contracts_new')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('member_contracts_membership')),
      );
      await tester.pump();
      expect(membershipOpened, 1);
    });

    testWidgets('회원권계약서 동작이 없으면 그 버튼은 보이지 않는다', (tester) async {
      await pump(tester, autoStart: false, stream: Stream.value(const []));
      expect(
        find.byKey(const ValueKey('member_contracts_membership')),
        findsNothing,
      );
    });

    // 확인창이 답장 애니메이션 뒤에 닫히고 토스트가 잠깐 떠 있으므로, 토스트가 보일 때까지 조금씩 넘긴다.
    Future<void> pumpUntilToast(WidgetTester tester) async {
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.textContaining('삭제했어요').evaluate().isNotEmpty ||
            find.textContaining('저장하지 못했어요').evaluate().isNotEmpty) {
          return;
        }
      }
    }

    Future<void> flushToast(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('작성 중인 계약서를 길게 눌러 확인하면 취소 처리하고, 확인하지 않으면 그대로 둔다', (
      tester,
    ) async {
      final gateway = _FakeGateway();
      await pump(
        tester,
        gateway: gateway,
        stream: Stream.value([_item('draft', _doc(status: 'draft'))]),
      );
      expect(
        find.byKey(const ValueKey('member_contracts_hint')),
        findsOneWidget,
      );

      // 취소하면 아무것도 하지 않는다.
      await tester.longPress(
        find.byKey(const ValueKey('member_contract_draft')),
      );
      await tester.pumpAndSettle();
      expect(find.text('이 계약서를 삭제할까요?'), findsOneWidget);
      expect(find.textContaining('회원이 이미 서명한 내용'), findsNothing);
      await tester.tap(find.text('취소').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(gateway.cancelled, isEmpty);

      await tester.longPress(
        find.byKey(const ValueKey('member_contract_draft')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제').last);
      await pumpUntilToast(tester);
      expect(gateway.cancelled, [(id: 'draft', reason: '강사가 삭제함')]);
      expect(find.text('계약서를 삭제했어요.'), findsOneWidget);
      await flushToast(tester);
    });

    testWidgets('회원이 서명한 계약서는 확인 문구에 서명 정리 안내가 더 붙는다', (tester) async {
      await pump(
        tester,
        gateway: _FakeGateway(),
        stream: Stream.value([_item('s', _doc(status: 'member_signed'))]),
      );
      await tester.longPress(find.byKey(const ValueKey('member_contract_s')));
      await tester.pumpAndSettle();
      expect(find.textContaining('회원이 이미 서명한 내용도 함께 정리돼요'), findsOneWidget);
    });

    testWidgets('완료·이전 버전 계약서는 길게 눌러도 삭제할 수 없다고 안내한다', (tester) async {
      final gateway = _FakeGateway();
      await pump(
        tester,
        gateway: gateway,
        stream: Stream.value([
          _item('done', _doc(completed: DateTime.utc(2026, 10, 22))),
          _item('old', _doc(status: 'superseded')),
        ]),
      );
      await tester.longPress(
        find.byKey(const ValueKey('member_contract_done')),
      );
      await tester.pump();
      expect(find.text('완료된 계약서는 삭제할 수 없어요.'), findsOneWidget);
      expect(find.text('이 계약서를 삭제할까요?'), findsNothing);
      await flushToast(tester);
      await tester.longPress(find.byKey(const ValueKey('member_contract_old')));
      await tester.pump();
      expect(find.text('완료된 계약서는 삭제할 수 없어요.'), findsOneWidget);
      expect(gateway.cancelled, isEmpty);
      await flushToast(tester);
    });

    testWidgets('삭제가 서버에서 거부되면 이유를 안내한다', (tester) async {
      await pump(
        tester,
        gateway: _FakeGateway(error: StateError('boom')),
        stream: Stream.value([_item('draft', _doc(status: 'draft'))]),
      );
      await tester.longPress(
        find.byKey(const ValueKey('member_contract_draft')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제').last);
      await pumpUntilToast(tester);
      expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
      await flushToast(tester);
    });

    testWidgets('취소된 계약서는 기본으로 숨기고 보기 버튼으로 펼친다', (tester) async {
      await pump(
        tester,
        stream: Stream.value([
          _item('done', _doc(completed: DateTime.utc(2026, 10, 22))),
          _item('gone', _doc(status: 'cancelled')),
        ]),
      );
      expect(
        find.byKey(const ValueKey('member_contract_done')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('member_contract_gone')), findsNothing);
      expect(find.text('취소·파기된 계약서 보기 (1)'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_toggle_cancelled')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('member_contract_gone')),
        findsOneWidget,
      );
      expect(find.text('취소됨'), findsOneWidget);
      expect(find.text('취소·파기된 계약서 숨기기'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('member_contracts_toggle_cancelled')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('member_contract_gone')), findsNothing);
    });

    testWidgets('모든 계약서가 취소됐으면 빈 목록 안내를 보이고 보기 버튼은 남는다', (tester) async {
      await pump(
        tester,
        autoStart: false,
        stream: Stream.value([_item('gone', _doc(status: 'cancelled'))]),
      );
      expect(
        find.byKey(const ValueKey('member_contracts_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('member_contracts_toggle_cancelled')),
        findsOneWidget,
      );
    });

    testWidgets('목록을 불러오지 못하면 안내한다', (tester) async {
      await pump(
        tester,
        stream: Stream<List<MemberContractItem>>.error(StateError('x')),
      );
      expect(
        find.byKey(const ValueKey('member_contracts_failed')),
        findsOneWidget,
      );
    });
  });
}
