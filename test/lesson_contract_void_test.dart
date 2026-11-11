import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_sign_flow_page.dart';
import 'package:mtf_app/pages/lesson_contract/member_contracts_page.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';

const _id = 'pc_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Strokes _strokes() => [
  [
    for (var i = 0; i < 12; i++) [10 + i * 20.0, 40 + (i % 3) * 10.0],
  ],
];

Map<String, dynamic> _contract({
  required DateTime completedAt,
  String status = 'completed',
  bool memberSignatures = false,
}) {
  final golden =
      jsonDecode(
            File(
              'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    ...Map<String, dynamic>.from(golden['basic'] as Map),
    'memberId': 'm1',
    'trainerId': 'trainer-a',
    'contractNo': 'PT-2610-0001',
    'version': 1,
    'status': status,
    'contentHash': 'h' * 64,
    'signatures': {
      'disclosure': memberSignatures ? {'eventId': 'ev-disclosure'} : null,
      'member': memberSignatures ? {'eventId': 'ev-member'} : null,
      'trainer': null,
    },
    'completedAt': completedAt,
    // 이미 열람 링크가 있어 완료 화면이 PDF 준비를 자동으로 시작하지 않는다.
    'delivery': {'linkTokenHash': 'h' * 64},
  };
}

class _Gateway extends PersonalContractGateway {
  _Gateway(this.contract, {this.error, this.savedStrokes = const {}})
    : super(callable: (name, parameters) async => throw UnimplementedError());

  Map<String, dynamic> contract;
  final Object? error;
  // 이벤트 id → 계약서에 남은 서명 획.
  final Map<String, Strokes> savedStrokes;
  final List<({String id, String reason, int strokeCount})> voided = [];

  @override
  Future<Map<String, dynamic>?> loadContract(String contractId) async =>
      Map<String, dynamic>.from(contract);

  @override
  Future<Strokes> loadSignatureStrokes(
    String contractId,
    String eventId,
  ) async => savedStrokes[eventId] ?? const [];

  @override
  Future<void> voidContract(
    String contractId, {
    required String reason,
    required Strokes strokes,
  }) async {
    if (error != null) throw error!;
    voided.add((id: contractId, reason: reason, strokeCount: strokes.length));
    contract = {...contract, 'status': 'voided'};
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Gateway gateway, {
    Future<Strokes?> Function(BuildContext, {required String title})? capture,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LessonContractSignFlowPage(
          contractId: _id,
          gateway: gateway,
          capture: capture,
          buildPdf: (_, __) async => Uint8List.fromList(List.filled(2048, 1)),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openVoid(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('done_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계약 파기'));
    await tester.pumpAndSettle();
  }

  testWidgets('계약 완료 후 3일 안에는 계약 파기 버튼이 보이고 3일이 지나면 보이지 않는다', (tester) async {
    await pump(
      tester,
      _Gateway(
        _contract(
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ),
    );
    // 화면 아래에 늘어놓지 않고 머리말 더보기(⋮) 메뉴 안에 둔다.
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
    expect(find.text('계약 파기'), findsNothing, reason: '메뉴를 열기 전에는 보이지 않는다');
    await tester.tap(find.byKey(const ValueKey('done_more_menu')));
    await tester.pumpAndSettle();
    expect(find.text('계약 파기'), findsOneWidget);
    expect(find.text('완료 후 3일 이내'), findsOneWidget);
    // 예전의 내용 수정(새 버전) 버튼은 파기로 대체되어 없다.
    expect(find.byKey(const ValueKey('done_new_version')), findsNothing);
  });

  testWidgets('3일이 지난 계약서에는 계약 파기 버튼이 없다', (tester) async {
    await pump(
      tester,
      _Gateway(
        _contract(
          completedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ),
    );
    // 파기 항목은 없어지고, 해지만 더보기(⋮) 메뉴에 남는다.
    await tester.tap(find.byKey(const ValueKey('done_more_menu')));
    await tester.pumpAndSettle();
    expect(find.text('계약 파기'), findsNothing);
    expect(find.text('계약 해지'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('done_close')), findsOneWidget);
  });

  testWidgets('파기: 사유를 고르고 회원이 서명하면 서버에 파기를 기록하고 파기된 계약서 화면이 된다', (
    tester,
  ) async {
    final gateway = _Gateway(
      _contract(completedAt: DateTime.now().subtract(const Duration(hours: 5))),
    );
    var pads = 0;
    String? padTitle;
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async {
        pads += 1;
        padTitle = title;
        return _strokes();
      },
    );
    await openVoid(tester);
    await tester.pumpAndSettle();
    expect(find.text('계약을 파기할까요?'), findsOneWidget);
    expect(find.textContaining('3일 안에, 레슨을 받기 전에만'), findsOneWidget);
    expect(find.textContaining('회원이 파기 확인 서명을 해야 해요'), findsOneWidget);
    expect(gateway.voided, isEmpty, reason: '서명 전에는 기록하지 않는다');

    await tester.tap(find.byKey(const ValueKey('contract_void_reason_회원 요청')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contract_void_continue')));
    await tester.pumpAndSettle();
    expect(pads, 1);
    expect(padTitle, contains('파기 확인 서명'));
    expect(gateway.voided, [(id: _id, reason: '회원 요청', strokeCount: 1)]);
    // 다시 불러와 파기된 계약서 화면으로 바뀐다.
    expect(find.byKey(const ValueKey('sign_locked')), findsOneWidget);
    expect(find.textContaining('파기된 계약서입니다'), findsOneWidget);
    expect(find.text('계약 파기'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('사유 시트에서 취소하거나 서명을 하지 않으면 파기하지 않는다', (tester) async {
    final gateway = _Gateway(
      _contract(completedAt: DateTime.now().subtract(const Duration(hours: 5))),
    );
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => null,
    );
    // 시트에서 취소.
    await openVoid(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract_void_cancel')));
    await tester.pumpAndSettle();
    expect(gateway.voided, isEmpty);

    // 서명 창을 닫으면(서명 없음) 파기하지 않는다.
    await openVoid(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract_void_continue')));
    await tester.pumpAndSettle();
    expect(gateway.voided, isEmpty);
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
  });

  testWidgets('이미 레슨을 받았다면 서버가 거부한 이유를 안내하고 화면은 그대로다', (tester) async {
    final gateway = _Gateway(
      _contract(completedAt: DateTime.now().subtract(const Duration(hours: 5))),
      error: FirebaseFunctionsException(
        message: 'void_lessons_taken',
        code: 'failed-precondition',
      ),
    );
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => _strokes(),
    );
    await openVoid(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract_void_continue')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('이미 레슨을 받아서 파기할 수 없어요').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('이미 레슨을 받아서 파기할 수 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  });

  // 서명 ①·②와 같은 글씨 / 전혀 다른 글씨.
  Strokes zigzag() => [
    [
      for (var i = 0; i < 14; i++) [20 + i * 8.0, i.isEven ? 10.0 : 190.0],
    ],
  ];

  testWidgets('파기 서명이 계약서의 회원 서명과 비슷하면 그대로 파기된다', (tester) async {
    final gateway = _Gateway(
      _contract(
        completedAt: DateTime.now().subtract(const Duration(hours: 5)),
        memberSignatures: true,
      ),
      savedStrokes: {'ev-disclosure': _strokes(), 'ev-member': zigzag()},
    );
    await pump(
      tester,
      gateway,
      // 서명 ①과 같은 글씨(서명 ②와는 달라도 둘 중 하나와 비슷하면 통과).
      capture: (context, {required title}) async => _strokes(),
    );
    await openVoid(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract_void_continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('signature_mismatch_dialog')),
      findsNothing,
    );
    expect(gateway.voided.length, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('파기 서명이 계약서의 회원 서명과 많이 다르면 다시 서명을 요구하고 파기하지 않는다', (tester) async {
    final gateway = _Gateway(
      _contract(
        completedAt: DateTime.now().subtract(const Duration(hours: 5)),
        memberSignatures: true,
      ),
      savedStrokes: {'ev-disclosure': _strokes(), 'ev-member': _strokes()},
    );
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => zigzag(),
    );
    await openVoid(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract_void_continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('signature_mismatch_dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('계약서의 회원 서명과 많이 달라요'), findsOneWidget);
    expect(gateway.voided, isEmpty);
    await tester.tap(find.byKey(const ValueKey('signature_mismatch_retry')));
    await tester.pumpAndSettle();
    expect(gateway.voided, isEmpty);
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
  });

  test('목록: 파기된 계약은 파기됨 칩이고 취소된 계약처럼 기본으로 숨겨진다', () {
    final item = MemberContractItem.fromDoc(_id, {
      'status': 'voided',
      'version': 1,
      'contractNo': 'PT-2610-0001',
    });
    expect(item.statusLabel, '파기됨');
    expect(item.isOpen, isFalse);
    expect(item.isInactive, isTrue);
    expect(
      MemberContractItem.fromDoc(_id, {'status': 'cancelled'}).isInactive,
      isTrue,
    );
    expect(
      MemberContractItem.fromDoc(_id, {'status': 'completed'}).isInactive,
      isFalse,
    );
  });
}
