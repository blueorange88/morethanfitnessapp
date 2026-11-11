import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_preview_page.dart';
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
  Map<String, dynamic>? termination,
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
    'signatures': {'disclosure': null, 'member': null, 'trainer': null},
    'completedAt': completedAt,
    'delivery': {'linkTokenHash': 'h' * 64},
    if (termination != null) 'termination': termination,
  };
}

class _Call {
  _Call(this.id, this.args, this.strokeCount);
  final String id;
  final Map<String, Object?> args;
  final int strokeCount;
}

class _Gateway extends PersonalContractGateway {
  _Gateway(this.contract, {this.error})
    : super(callable: (name, parameters) async => throw UnimplementedError());

  Map<String, dynamic> contract;
  final Object? error;
  final List<_Call> terminated = [];

  @override
  Future<Map<String, dynamic>?> loadContract(String contractId) async =>
      Map<String, dynamic>.from(contract);

  @override
  Future<Strokes> loadSignatureStrokes(
    String contractId,
    String eventId,
  ) async => const [];

  @override
  Future<ContractTerminateResult> terminateContract(
    String contractId, {
    required String reasonCode,
    String reasonNote = '',
    required String noticeChannel,
    required String noticeDate,
    bool markExpired = false,
    Strokes? strokes,
  }) async {
    if (error != null) throw error!;
    final signed = strokes != null && strokes.isNotEmpty;
    terminated.add(
      _Call(contractId, {
        'reasonCode': reasonCode,
        'reasonNote': reasonNote,
        'noticeChannel': noticeChannel,
        'noticeDate': noticeDate,
        'markExpired': markExpired,
      }, strokes?.length ?? 0),
    );
    contract = {
      ...contract,
      'status': 'terminated',
      'terminatedAt': DateTime.now(),
      'termination': {
        'reasonCode': reasonCode,
        'reasonNote': reasonNote,
        'noticeChannel': noticeChannel,
        'noticeDate': noticeDate,
        'evidence': signed ? 'member_signed' : 'trainer_only',
        'snapshot': {'total': 40, 'done': 25, 'remain': 15},
      },
    };
    return ContractTerminateResult(
      evidence: signed ? 'member_signed' : 'trainer_only',
    );
  }
}

void main() {
  setUpAll(() => LessonContractPreviewPage.realPdfEnabled = false);

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

  Future<void> openTerminate(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('done_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계약 해지'));
    await tester.pumpAndSettle();
  }

  Future<void> settleToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  }

  DateTime longAgo() => DateTime.now().subtract(const Duration(days: 40));

  testWidgets('해지는 완료 후 며칠이 지났어도 더보기 메뉴에 있고, 환불은 앱이 하지 않는다고 알린다', (
    tester,
  ) async {
    await pump(tester, _Gateway(_contract(completedAt: longAgo())));
    await openTerminate(tester);
    expect(
      find.byKey(const ValueKey('contract_terminate_sheet')),
      findsOneWidget,
    );
    expect(find.text('계약을 해지할까요?'), findsOneWidget);
    expect(find.textContaining('환불 금액 계산과 송금은 앱이 하지 않고'), findsOneWidget);
    // 해지하면 횟수는 항상 0으로 정리되므로 선택 스위치는 없다.
    expect(
      find.byKey(const ValueKey('contract_terminate_zero_remain')),
      findsNothing,
    );
    expect(find.textContaining('0(미등록)으로 정리'), findsOneWidget);
    // 서명은 선택이라 끄고 진행할 수 있다.
    expect(find.text('증빙 등급: 회원 서명 확인'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('contract_terminate_with_signature')),
    );
    await tester.pump();
    expect(find.textContaining('증빙 등급: 강사 단독 기록'), findsOneWidget);
    expect(find.text('서명 없이 해지하기'), findsOneWidget);
  });

  testWidgets('서명 없이 해지: 서명 창 없이 확인 뒤 강사 단독 기록으로 해지되고 해지 기록 화면이 된다', (
    tester,
  ) async {
    final gateway = _Gateway(_contract(completedAt: longAgo()));
    var pads = 0;
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async {
        pads += 1;
        return _strokes();
      },
    );
    await openTerminate(tester);
    await tester.tap(
      find.byKey(const ValueKey('contract_terminate_with_signature')),
    );
    await tester.tap(
      find.byKey(const ValueKey('contract_terminate_channel_kakao')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contract_terminate_continue')));
    await tester.pumpAndSettle();
    expect(pads, 0, reason: '서명을 끄면 서명 창을 열지 않는다');
    expect(
      find.byKey(const ValueKey('terminate_confirm_dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('회원 서명 없이 강사 단독 기록으로 해지해요'), findsOneWidget);
    expect(gateway.terminated, isEmpty, reason: '확인 전에는 기록하지 않는다');

    await tester.tap(find.byKey(const ValueKey('terminate_confirm_ok')));
    await tester.pumpAndSettle();
    expect(gateway.terminated.length, 1);
    final call = gateway.terminated.single;
    expect(call.id, _id);
    expect(call.strokeCount, 0);
    expect(call.args['reasonCode'], 'member_request');
    expect(call.args['noticeChannel'], 'kakao');
    expect(call.args['markExpired'], false);
    expect(
      RegExp(
        r'^\d{4}-\d{2}-\d{2}$',
      ).hasMatch(call.args['noticeDate'] as String),
      isTrue,
    );

    // 다시 불러와 해지된 계약서의 읽기 전용 화면이 된다.
    expect(find.text('해지된 계약서예요'), findsOneWidget);
    expect(find.byKey(const ValueKey('termination_card')), findsOneWidget);
    expect(find.text('강사 단독 기록'), findsOneWidget);
    expect(find.textContaining('총 40회 · 소진 25회 · 잔여 15회'), findsOneWidget);
    expect(find.text('카톡 · ${call.args['noticeDate']}'), findsOneWidget);
    expect(find.byKey(const ValueKey('done_more_menu')), findsNothing);
    expect(find.byKey(const ValueKey('done_preview')), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('회원 서명을 받으면 서명 창 제목에 해지 확인이 들어가고 증빙은 회원 서명 확인이 된다', (
    tester,
  ) async {
    final gateway = _Gateway(_contract(completedAt: longAgo()));
    String? padTitle;
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async {
        padTitle = title;
        return _strokes();
      },
    );
    await openTerminate(tester);
    await tester.tap(find.byKey(const ValueKey('contract_terminate_continue')));
    await tester.pumpAndSettle();
    expect(padTitle, contains('해지 확인 서명'));
    await tester.tap(find.byKey(const ValueKey('terminate_confirm_ok')));
    await tester.pumpAndSettle();
    expect(gateway.terminated.single.strokeCount, 1);
    expect(find.text('회원 서명 확인'), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('사유가 기타이면 내용을 적어야 진행할 수 있다', (tester) async {
    final gateway = _Gateway(_contract(completedAt: longAgo()));
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => _strokes(),
    );
    await openTerminate(tester);
    await tester.tap(
      find.byKey(const ValueKey('contract_terminate_reason_other')),
    );
    await tester.pump();
    final button = find.byKey(const ValueKey('contract_terminate_continue'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('contract_terminate_note')),
      '이사',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terminate_confirm_ok')));
    await tester.pumpAndSettle();
    expect(gateway.terminated.single.args['reasonCode'], 'other');
    expect(gateway.terminated.single.args['reasonNote'], '이사');
    await settleToasts(tester);
  });

  testWidgets('시트·서명·확인에서 취소하면 해지하지 않는다', (tester) async {
    final gateway = _Gateway(_contract(completedAt: longAgo()));
    var sign = true;
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => sign ? null : _strokes(),
    );
    // 시트에서 취소.
    await openTerminate(tester);
    await tester.tap(find.byKey(const ValueKey('contract_terminate_cancel')));
    await tester.pumpAndSettle();
    expect(gateway.terminated, isEmpty);

    // 서명 창을 닫으면 해지하지 않는다.
    await openTerminate(tester);
    await tester.tap(find.byKey(const ValueKey('contract_terminate_continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('terminate_confirm_dialog')),
      findsNothing,
    );
    expect(gateway.terminated, isEmpty);

    // 확인 창에서 취소해도 해지하지 않는다.
    sign = false;
    await openTerminate(tester);
    await tester.tap(find.byKey(const ValueKey('contract_terminate_continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terminate_confirm_cancel')));
    await tester.pumpAndSettle();
    expect(gateway.terminated, isEmpty);
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
  });

  testWidgets('더 나중 계약이 있으면 서버가 거부한 이유를 안내하고 화면은 그대로다', (tester) async {
    final gateway = _Gateway(
      _contract(completedAt: longAgo()),
      error: FirebaseFunctionsException(
        message: 'terminate_not_latest',
        code: 'failed-precondition',
      ),
    );
    await pump(
      tester,
      gateway,
      capture: (context, {required title}) async => _strokes(),
    );
    await openTerminate(tester);
    await tester.tap(find.byKey(const ValueKey('contract_terminate_continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terminate_confirm_ok')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('더 나중에 완료된 계약서').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('더 나중에 완료된 계약서'), findsOneWidget);
    expect(find.byKey(const ValueKey('done_more_menu')), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('이미 해지된 계약서를 열면 읽기 전용 기록만 보이고 메뉴·전달 카드가 없다', (tester) async {
    await pump(
      tester,
      _Gateway(
        _contract(
          completedAt: longAgo(),
          status: 'terminated',
          termination: {
            'reasonCode': 'other',
            'reasonNote': '이사',
            'noticeChannel': 'visit',
            'noticeDate': '2026-10-30',
            'evidence': 'member_signed',
            'snapshot': {'total': 30, 'done': 30, 'remain': 0},
          },
        ),
      ),
    );
    expect(find.text('해지된 계약서예요'), findsOneWidget);
    expect(find.text('기타 · 이사'), findsOneWidget);
    expect(find.text('방문 · 2026-10-30'), findsOneWidget);
    expect(find.text('회원 서명 확인'), findsOneWidget);
    expect(find.byKey(const ValueKey('done_more_menu')), findsNothing);
    expect(find.byKey(const ValueKey('delivery_$_id')), findsNothing);
    expect(find.byKey(const ValueKey('sign_locked')), findsNothing);
  });

  testWidgets('해지된 계약서의 계약서 보기에는 해지 완료 워터마크가 있고 완료 계약에는 없다', (tester) async {
    Future<void> openPreview(Map<String, dynamic> contract) async {
      // 앞서 연 미리보기 화면이 남지 않도록 화면 트리를 비운다.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, _Gateway(contract));
      await tester.tap(find.byKey(const ValueKey('done_preview')));
      await tester.pumpAndSettle();
    }

    await openPreview(
      _contract(
        completedAt: longAgo(),
        status: 'terminated',
        termination: {
          'reasonCode': 'member_request',
          'noticeChannel': 'verbal',
          'noticeDate': '2026-10-30',
          'evidence': 'trainer_only',
        },
      ),
    );
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );
    expect(find.text('해지 완료'), findsWidgets);

    await openPreview(_contract(completedAt: longAgo()));
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );
    expect(find.text('해지 완료'), findsNothing);
  });

  test('목록: 해지된 계약은 해지됨 칩이고 숨기지 않으며 열기만 한다', () {
    final item = MemberContractItem.fromDoc(_id, {
      'status': 'terminated',
      'version': 1,
      'contractNo': 'PT-2610-0001',
    });
    expect(item.statusLabel, '해지됨');
    expect(item.isOpen, isFalse);
    expect(item.isInactive, isFalse);
  });

  test('게이트웨이: 해지 호출은 서명이 있을 때만 strokes를 보내고 응답 증빙 등급을 읽는다', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final gateway = PersonalContractGateway(
      callable: (name, parameters) async {
        calls.add((name, parameters));
        return {
          'alreadyTerminated': false,
          'evidence':
              parameters.containsKey('strokes')
                  ? 'member_signed'
                  : 'trainer_only',
          'zeroedRemain': true,
          'markedExpired': false,
        };
      },
    );
    final none = await gateway.terminateContract(
      _id,
      reasonCode: 'trainer_reason',
      noticeChannel: 'verbal',
      noticeDate: '2026-11-01',
    );
    expect(calls.single.$1, 'terminatePersonalContract');
    expect(calls.single.$2.containsKey('strokes'), isFalse);
    expect(calls.single.$2.containsKey('zeroRemain'), isFalse);
    expect(calls.single.$2['markExpired'], false);
    expect(none.evidence, 'trainer_only');
    expect(none.zeroedRemain, true);

    final signed = await gateway.terminateContract(
      _id,
      reasonCode: 'member_request',
      noticeChannel: 'sms',
      noticeDate: '2026-11-01',
      strokes: _strokes(),
    );
    expect(calls.last.$2.containsKey('strokes'), isTrue);
    expect(signed.evidence, 'member_signed');
  });
}
