import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_form_page.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_preview_page.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_sign_flow_page.dart';
import 'package:mtf_app/services/managed_member_workspace_service.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_document.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';
import 'package:mtf_app/widgets/contract_signature_pad.dart';

Strokes _strokes([double offset = 0]) => [
  [
    for (var i = 0; i < 12; i++) [10 + i * 20 + offset, 40 + (i % 3) * 10.0],
  ],
];

Map<String, dynamic> _golden(String name) {
  final all =
      jsonDecode(
            File(
              'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return Map<String, dynamic>.from(all[name] as Map);
}

Map<String, dynamic> _contractDoc({
  String status = 'draft',
  String golden = 'basic',
  Map<String, dynamic>? signatures,
}) => {
  ..._golden(golden),
  'memberId': 'm1',
  'contractNo': 'PT-2610-0001',
  'version': 1,
  'status': status,
  'contentHash': 'h' * 64,
  'signatures':
      signatures ?? {'disclosure': null, 'member': null, 'trainer': null},
  'completedAt': status == 'completed' ? DateTime(2026, 10, 20, 15, 30) : null,
};

/// 같은 회원의 뒤에 등록된 계약이 있는 서버.
class _LaterContractServer extends _FakeServer {
  _LaterContractServer(super.contract, {required this.later});

  final Map<String, dynamic> later;

  @override
  Future<Map<String, dynamic>?> findLaterRegisteredContract(
    Map<String, dynamic> contract,
  ) async => later;
}

/// 서버처럼 순서·확인 항목·해시를 검사하는 메모리 서버.
class _FakeServer extends PersonalContractGateway {
  _FakeServer(this.contract, {this.failWith})
    : super(callable: (name, parameters) async => throw UnimplementedError());

  Map<String, dynamic> contract;
  final Object? Function(String step)? failWith;
  final List<Map<String, Object?>> signCalls = [];
  final Map<String, Strokes> stored = {};
  int loads = 0;

  @override
  Future<Map<String, dynamic>?> loadContract(String contractId) async {
    loads += 1;
    return Map<String, dynamic>.from(contract);
  }

  @override
  Future<Strokes> loadSignatureStrokes(
    String contractId,
    String eventId,
  ) async => stored[eventId] ?? const [];

  @override
  Future<ContractSignResult> signContract({
    required String contractId,
    required String step,
    required String contentHash,
    List<String> checkedItems = const [],
    required Strokes strokes,
  }) async {
    final error = failWith?.call(step);
    if (error != null) throw error;
    signCalls.add({
      'contractId': contractId,
      'step': step,
      'hash': contentHash,
      'items': [...checkedItems]..sort(),
      'strokes': strokes,
    });
    const order = {
      'disclosure': ('draft', 'disclosed'),
      'member': ('disclosed', 'member_signed'),
      'trainer': ('member_signed', 'completed'),
    };
    final rule = order[step]!;
    if (contract['status'] != rule.$1) {
      throw FirebaseFunctionsException(
        message: 'invalid_state',
        code: 'failed-precondition',
      );
    }
    final signatures = Map<String, dynamic>.from(contract['signatures'] as Map);
    final eventId = 'e_$step';
    stored[eventId] = strokes;
    signatures[step] = {
      'eventId': eventId,
      'signedAt': DateTime(2026, 10, 20, 15, 10),
    };
    contract = {
      ...contract,
      'status': rule.$2,
      'signatures': signatures,
      if (step == 'trainer') 'completedAt': DateTime(2026, 10, 20, 15, 30),
    };
    return ContractSignResult(status: rule.$2, contractNo: 'PT-2610-0001');
  }

  @override
  Future<ContractSettings> loadSettings(String uid) async =>
      const ContractSettings(
        party: ContractParty(
          kind: ContractPartyKind.individual,
          name: '김트레이너',
          trainerName: '김트레이너',
          phone: '010-1234-5678',
          place: '서울 강남구 테스트로 1',
        ),
      );

  @override
  Future<Map<String, dynamic>?> loadMemberCard(String memberId) async => {
    'name': '홍회원',
    'phone': '010-9999-8888',
    'birthDate': '1990-05-17',
  };

  @override
  Future<ContractDraftResult> saveDraft({
    String? idempotencyKey,
    String? contractId,
    required String memberId,
    required Map<String, Object?> content,
  }) async => ContractDraftResult(
    contractId: contractId ?? 'pc_${'a' * 32}',
    contractNo: 'PT-2610-0001',
    version: 1,
    status: 'draft',
    contentHash: 'h' * 64,
    created: contractId == null,
  );
}

class _Capture {
  _Capture({this.cancelFirst = false});

  final bool cancelFirst;
  final List<String> titles = [];
  int calls = 0;

  Future<Strokes?> call(BuildContext context, {required String title}) async {
    calls += 1;
    titles.add(title);
    if (cancelFirst && calls == 1) return null;
    return _strokes(calls * 3.0);
  }
}

/// 호출 순서대로 정해 둔 서명을 돌려준다(서명 ①, 서명 ②, 다시 서명 …).
class _ScriptCapture extends _Capture {
  _ScriptCapture(this.script);

  final List<Strokes> script;

  @override
  Future<Strokes?> call(BuildContext context, {required String title}) async {
    calls += 1;
    titles.add(title);
    return script[(calls - 1).clamp(0, script.length - 1)];
  }
}

/// 서명 ①과 전혀 다른 모양의 서명(작고 점이 적음).
Strokes _differentStrokes() => [
  [
    for (var i = 0; i < 6; i++) [400 + i * 3.0, 100 + i * 2.0],
  ],
];

Future<void> _pumpFlow(
  WidgetTester tester,
  _FakeServer server,
  _Capture capture, {
  ThemeMode mode = ThemeMode.light,
  Size size = const Size(800, 9000),
  void Function(bool?)? onPop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: mode,
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('open_flow'),
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder:
                            (_) => LessonContractSignFlowPage(
                              contractId: 'pc_${'a' * 32}',
                              gateway: server,
                              capture: capture.call,
                            ),
                      ),
                    );
                    onPop?.call(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open_flow')));
  await tester.pumpAndSettle();
}

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _checkAll(WidgetTester tester, List<String> ids) async {
  for (final id in ids) {
    final finder = find.byKey(ValueKey('disclosure_check_$id'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

const _basicIds = [
  'amount',
  'refund',
  'validity',
  'cancel_noshow',
  'health_risk',
];

void main() {
  setUpAll(() => LessonContractPreviewPage.realPdfEnabled = false);
  group('서명 획 변환', () {
    test('가로 1000 기준으로 맞추고 획을 null에서 나눈다', () {
      final strokes = strokesFromOffsets(const [
        Offset(0, 0),
        Offset(100, 50),
        null,
        Offset(200, 100),
        Offset(400, 20),
        null,
      ], const Size(400, 200));
      expect(strokes, hasLength(2));
      expect(strokes[0], [
        [0.0, 0.0],
        [250.0, 125.0],
      ]);
      expect(strokes[1], [
        [500.0, 250.0],
        [1000.0, 50.0],
      ]);
    });

    test('범위를 벗어난 점은 0~1000으로 맞추고 너무 많으면 덜어 낸다', () {
      final clamped = strokesFromOffsets(const [
        Offset(-5, -5),
        Offset(500, 500),
        null,
      ], const Size(400, 200));
      expect(clamped.first.first, [0.0, 0.0]);
      expect(clamped.first.last[0], 1000.0);

      final many = strokesFromOffsets([
        for (var i = 0; i < 9000; i++) Offset(i % 400.0, (i % 100).toDouble()),
      ], const Size(400, 200));
      expect(signaturePointCount(many), lessThanOrEqualTo(3600));
      expect(isMeaningfulSignature(many), isTrue);
    });

    test('한 점이나 아주 작은 표시는 서명으로 인정하지 않는다', () {
      expect(isMeaningfulSignature(const []), isFalse);
      expect(
        isMeaningfulSignature([
          [
            [10.0, 10.0],
          ],
        ]),
        isFalse,
      );
      expect(
        isMeaningfulSignature([
          [
            for (var i = 0; i < 12; i++) [100.0 + i * 0.5, 100.0],
          ],
        ]),
        isFalse,
      );
      expect(isMeaningfulSignature(_strokes()), isTrue);
    });

    test('서버 저장 형식({points:[x,y,...]})을 다시 읽는다', () {
      final stored = [
        {
          'points': [10, 20, 30.5, 40],
        },
        {
          'points': [1, 2],
        },
      ];
      expect(strokesFromStored(stored), [
        [
          [10.0, 20.0],
          [30.5, 40.0],
        ],
        [
          [1.0, 2.0],
        ],
      ]);
      expect(strokesFromStored(null), isEmpty);
      expect(strokesFromStored('x'), isEmpty);
    });
  });

  group('핵심 고지 카드', () {
    final form = LessonContractForm.fromContract(_contractDoc());
    final party = ContractParty.fromMap(
      Map<String, dynamic>.from(_golden('basic')['party'] as Map),
    );

    test('다섯 장이고 확인 항목 이름이 서버 요구와 같다', () {
      final cards = buildDisclosureCards(form, party);
      expect(cards.map((c) => c.number), ['①', '②', '③', '④', '⑤']);
      expect(disclosureCheckIds(cards), _basicIds);
      expect(cards.first.rows, contains(('회당 금액', '100,000원')));
      expect(
        cards[1].lines.join('\n'),
        allOf(contains('환불 900,000원'), contains('환불 600,000원')),
      );
      expect(cards[3].lines.first, contains('또한 레슨 시작시간 30분 이후는'));
      expect(cards.last.lines, kHealthRiskParagraphs);
    });

    test('정상가 기준이면 확인 항목이 하나 더 생기고 정상가 정보가 금액 카드에 나온다', () {
      final listForm = form.copyWith(
        listPrice: 1500000,
        refundByListPrice: true,
      );
      final cards = buildDisclosureCards(listForm, party);
      expect(disclosureCheckIds(cards).toSet(), {
        ..._basicIds,
        'list_price_basis',
      });
      expect(
        cards.first.rows,
        containsAll([
          ('정상가', '1,500,000원 (33.3% 할인)'),
          ('정상가 기준 회당 금액', '150,000원'),
        ]),
      );
      expect(cards.first.extraChecks.single.$2, contains('1,500,000원'));
    });

    test('나머지 조항에는 핵심 고지에 있던 조항이 들어가지 않는다', () {
      final document = buildLessonContractDocument(form: form, party: party);
      final rest = remainingArticles(document);
      final headings = rest.map((e) => e.$2.heading).toList();
      expect(headings, contains('양도'));
      expect(headings, contains('개인정보의 수집 및 이용'));
      expect(headings, isNot(contains('위약금 및 환불')));
      expect(headings, isNot(contains('건강 상태 확인과 안전')));
      // 번호는 전체 문서 기준이다.
      final transfer = rest.firstWhere((e) => e.$2.heading == '양도');
      expect(
        document.articles.indexWhere((a) => a.heading == '양도') + 1,
        transfer.$1,
      );
    });
  });

  group('서명판', () {
    testWidgets('그린 서명은 서버 형식으로 돌려주고 짧은 점은 완료할 수 없다', (tester) async {
      Strokes? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: FilledButton(
                    key: const ValueKey('open_pad'),
                    onPressed: () async {
                      result = await showContractSignaturePad(
                        context,
                        title: '서명',
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open_pad')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('signature_pad_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      // 점 하나만 찍으면 완료할 수 없다.
      await tester.tap(find.byKey(const ValueKey('signature_pad_canvas')));
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      // 선을 그으면 완료할 수 있다.
      final canvas = find.byKey(const ValueKey('signature_pad_canvas'));
      final start = tester.getTopLeft(canvas) + const Offset(20, 40);
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(start + Offset(i * 14.0, (i % 3) * 8.0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(isMeaningfulSignature(result!), isTrue);
      for (final stroke in result!) {
        for (final point in stroke) {
          expect(point[0], inInclusiveRange(0, 1000));
          expect(point[1], inInclusiveRange(0, 1000));
        }
      }
    });

    testWidgets('지우기는 서명을 비우고 취소하면 null을 돌려준다', (tester) async {
      Strokes? result = [
        [
          [1.0, 1.0],
        ],
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: FilledButton(
                    key: const ValueKey('open_pad'),
                    onPressed: () async {
                      result = await showContractSignaturePad(
                        context,
                        title: '서명',
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open_pad')));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('signature_pad_canvas'));
      final start = tester.getTopLeft(canvas) + const Offset(20, 40);
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(start + Offset(i * 14.0, 5));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('signature_pad_confirm')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('signature_pad_clear')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('signature_pad_confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('signature_pad_cancel')));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('서명 흐름', () {
    testWidgets('핵심 고지 → 서명 ① → 조항 동의 → 서명 ② → 강사 서명 → 완료 순서로 서버에 기록한다', (
      tester,
    ) async {
      final server = _FakeServer(_contractDoc());
      final capture = _Capture();
      bool? popped;
      await _pumpFlow(tester, server, capture, onPop: (v) => popped = v);

      // 폰을 회원에게 전달
      expect(find.byKey(const ValueKey('sign_handoff_member')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();

      // 핵심 고지 5장: 모두 확인하기 전에는 서명할 수 없다.
      expect(
        find.byKey(const ValueKey('disclosure_card_amount')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('disclosure_sign_button')),
            )
            .onPressed,
        isNull,
      );
      await _checkAll(tester, _basicIds.sublist(0, 4));
      expect(capture.calls, 0);
      expect(find.text('확인 4/5'), findsOneWidget);
      // 마지막 항목을 확인하면 서명판이 자동으로 열린다.
      await _checkAll(tester, ['health_risk']);
      expect(capture.calls, 1);
      expect(capture.titles.single, '서명 ① 핵심 고지 확인');
      expect(server.signCalls, hasLength(1));
      expect(server.signCalls.first['step'], 'disclosure');
      expect(server.signCalls.first['hash'], 'h' * 64);
      expect(server.signCalls.first['items'], [..._basicIds]..sort());
      expect(
        isMeaningfulSignature(server.signCalls.first['strokes']! as Strokes),
        isTrue,
      );

      // 나머지 조항 + 서명 ②
      expect(find.byKey(const ValueKey('terms_articles')), findsOneWidget);
      expect(find.textContaining('양도'), findsWidgets);
      final signTerms = find.byKey(const ValueKey('terms_sign_button'));
      expect(tester.widget<FilledButton>(signTerms).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('terms_check_terms')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(signTerms).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('terms_check_privacy')));
      await tester.pumpAndSettle();
      await tester.tap(signTerms);
      await tester.pumpAndSettle();
      expect(server.signCalls.last['step'], 'member');
      expect(server.signCalls.last['items'], ['privacy', 'terms']);
      expect(capture.titles.last, '서명 ② 계약 전체 동의');

      // 폰을 강사에게 돌려줌 → 강사 서명
      expect(
        find.byKey(const ValueKey('sign_handoff_trainer')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_trainer_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign_summary')), findsOneWidget);
      expect(find.text('PT-2610-0001'), findsWidgets);
      // 회원 서명 그림과 서명 시각이 보인다.
      expect(
        find.byKey(const ValueKey('trainer_member_sig_1_time')),
        findsOneWidget,
      );
      expect(find.text('2026-10-20 15:10'), findsWidgets);
      final trainerSign = find.byKey(const ValueKey('trainer_sign_button'));
      expect(tester.widget<FilledButton>(trainerSign).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('trainer_confirm')));
      await tester.pumpAndSettle();
      await tester.tap(trainerSign);
      await tester.pumpAndSettle();
      expect(server.signCalls.last['step'], 'trainer');
      expect(server.signCalls.last['items'], isEmpty);
      expect(capture.titles.last, '강사 서명');

      // 완료
      expect(find.byKey(const ValueKey('sign_done_title')), findsOneWidget);
      expect(find.text('완료 시각 2026-10-20 15:30'), findsOneWidget);
      expect(server.contract['status'], 'completed');
      expect(server.signCalls.map((c) => c['step']), [
        'disclosure',
        'member',
        'trainer',
      ]);
      await tester.tap(find.byKey(const ValueKey('done_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(popped, isTrue);
      // 방금 완료했으니 저장 완료와 이어서 할 일을 알려 준다.
      expect(find.textContaining('계약서 저장이 완료되었습니다'), findsOneWidget);
      expect(find.textContaining('계약서관리 페이지에서 가능합니다'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('상태에 따라 이어서 진행한다', (tester) async {
      // 서명 ①이 끝난 계약: 폰 전달 뒤 바로 조항 동의
      var server = _FakeServer(
        _contractDoc(
          status: 'disclosed',
          signatures: {
            'disclosure': {
              'eventId': 'e_disclosure',
              'signedAt': DateTime(2026, 10, 20, 15, 10),
            },
            'member': null,
            'trainer': null,
          },
        ),
      );
      await _pumpFlow(tester, server, _Capture());
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('terms_articles')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('disclosure_card_amount')),
        findsNothing,
      );
    });

    testWidgets('회원 서명이 끝난 계약은 강사 서명부터, 완료된 계약은 완료 화면, 취소된 계약은 막는다', (
      tester,
    ) async {
      var server = _FakeServer(_contractDoc(status: 'member_signed'));
      await _pumpFlow(tester, server, _Capture());
      expect(find.byKey(const ValueKey('trainer_sign_button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('disclosure_card_amount')),
        findsNothing,
      );
    });

    testWidgets('완료된 계약은 완료 화면을 보여 준다', (tester) async {
      final server = _FakeServer(_contractDoc(status: 'completed'));
      await _pumpFlow(tester, server, _Capture());
      expect(find.byKey(const ValueKey('sign_done_title')), findsOneWidget);
      expect(find.byKey(const ValueKey('trainer_sign_button')), findsNothing);
    });

    testWidgets('뒤에 등록된 계약이 있으면 파기 전에 그 계약을 알려 준다', (tester) async {
      final server = _LaterContractServer(
        {
          ..._contractDoc(status: 'completed'),
          'completedAt': DateTime.now(),
          'registration': {'registered': 10},
        },
        later: {
          'status': 'completed',
          'completedAt': DateTime(2026, 5, 16, 10),
          'product': {'name': 'PT 30회'},
        },
      );
      await _pumpFlow(tester, server, _Capture());
      await tester.tap(find.byKey(const ValueKey('done_more_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계약 파기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('2026.05.16 계약한 [PT 30회]'), findsOneWidget);
      expect(find.textContaining('파기할 수 없어요'), findsOneWidget);
      expect(find.byKey(const Key('contract_void_sheet')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('이미 완료된 계약서를 열어 닫을 때는 저장 안내를 띄우지 않는다', (tester) async {
      final server = _FakeServer(_contractDoc(status: 'completed'));
      await _pumpFlow(tester, server, _Capture());
      await tester.tap(find.byKey(const ValueKey('done_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('계약서 저장이 완료되었습니다'), findsNothing);
    });

    testWidgets('취소되었거나 대체된 계약은 서명할 수 없다', (tester) async {
      for (final status in ['cancelled', 'superseded']) {
        final server = _FakeServer(_contractDoc(status: status));
        await _pumpFlow(tester, server, _Capture());
        expect(find.byKey(const ValueKey('sign_locked')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('disclosure_sign_button')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('sign_locked_close')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('정상가 기준이면 추가 확인까지 해야 서명할 수 있다', (tester) async {
      final doc = _contractDoc();
      final product = Map<String, dynamic>.from(doc['product'] as Map)
        ..['listPrice'] = 1500000;
      final terms = Map<String, dynamic>.from(doc['terms'] as Map)
        ..['refundBasis'] = 'list_price';
      final server = _FakeServer({...doc, 'product': product, 'terms': terms});
      final capture = _Capture();
      await _pumpFlow(tester, server, capture);
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await _checkAll(tester, _basicIds);
      // 다섯 가지만 확인해서는 서명판이 열리지 않는다.
      expect(capture.calls, 0);
      expect(find.text('확인 5/6'), findsOneWidget);
      await _checkAll(tester, ['list_price_basis']);
      expect(capture.calls, 1);
      expect(
        server.signCalls.single['items'],
        [..._basicIds, 'list_price_basis']..sort(),
      );
    });

    testWidgets('서명판을 취소하면 서버에 기록하지 않고 버튼으로 다시 열 수 있다', (tester) async {
      final server = _FakeServer(_contractDoc());
      final capture = _Capture(cancelFirst: true);
      await _pumpFlow(tester, server, capture);
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await _checkAll(tester, _basicIds);
      expect(capture.calls, 1);
      expect(server.signCalls, isEmpty);
      final button = find.byKey(const ValueKey('disclosure_sign_button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(capture.calls, 2);
      expect(server.signCalls, hasLength(1));
    });

    testWidgets('일시적인 오류는 체크를 그대로 두고, 내용이 바뀐 오류는 처음부터 다시 시작한다', (tester) async {
      var calls = 0;
      final server = _FakeServer(
        _contractDoc(),
        failWith: (step) {
          calls += 1;
          if (calls == 1) {
            return FirebaseFunctionsException(
              message: 'internal',
              code: 'unavailable',
            );
          }
          if (calls == 2) {
            return FirebaseFunctionsException(
              message: 'content_changed',
              code: 'failed-precondition',
            );
          }
          return null;
        },
      );
      final capture = _Capture();
      await _pumpFlow(tester, server, capture);
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await _checkAll(tester, _basicIds);
      await _flushToast(tester);
      // 네트워크 오류: 같은 화면에서 체크가 유지된다.
      expect(
        find.byKey(const ValueKey('disclosure_card_amount')),
        findsOneWidget,
      );
      expect(find.text('확인 5/5'), findsOneWidget);

      final button = find.byKey(const ValueKey('disclosure_sign_button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await _flushToast(tester);
      // 내용 변경 오류: 서버 상태를 다시 읽어 처음(폰 전달)부터 시작한다.
      expect(find.byKey(const ValueKey('sign_handoff_member')), findsOneWidget);
      expect(server.signCalls, isEmpty);
    });

    testWidgets('진행 중에 뒤로 가면 확인창이 나오고 계속 진행할 수 있다', (tester) async {
      final server = _FakeServer(_contractDoc());
      await _pumpFlow(tester, server, _Capture());
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign_back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign_leave_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign_leave_stay')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('disclosure_card_amount')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sign_back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign_leave_exit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open_flow')), findsOneWidget);
    });

    testWidgets('계약서를 불러오지 못하면 다시 시도할 수 있다', (tester) async {
      final server = _FakeServer({});
      server.contract = {};
      // 비어 있는 계약 문서는 불러오기 실패와 같게 취급한다.
      final broken = _BrokenServer();
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractSignFlowPage(
            contractId: 'pc_${'a' * 32}',
            gateway: broken,
            capture: _Capture().call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign_retry')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign_retry')));
      await tester.pumpAndSettle();
      expect(broken.loads, 2);
    });

    testWidgets('다크 모드 320dp 폭에서도 모든 단계가 넘침 없이 그려진다', (tester) async {
      final server = _FakeServer(_contractDoc());
      await _pumpFlow(
        tester,
        server,
        _Capture(),
        mode: ThemeMode.dark,
        size: const Size(640, 9000),
      );
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await _checkAll(tester, _basicIds);
      await tester.tap(find.byKey(const ValueKey('terms_check_terms')));
      await tester.tap(find.byKey(const ValueKey('terms_check_privacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms_sign_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_trainer_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('trainer_confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trainer_sign_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('sign_done_title')), findsOneWidget);
    });
  });

  group('서명 ① ↔ 서명 ② 비교', () {
    Future<void> toTermsAndSign(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const ValueKey('sign_handoff_member_button')),
      );
      await tester.pumpAndSettle();
      await _checkAll(tester, _basicIds);
      await tester.tap(find.byKey(const ValueKey('terms_check_terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms_check_privacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms_sign_button')));
      // 확인창은 채팅 애니메이션이 있어 시간을 정해 넘긴다.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    test('비슷한 서명은 1에 가깝고 많이 다르면 기준 아래로 떨어진다', () {
      expect(signatureSimilarity(_strokes(), _strokes(3)), greaterThan(0.9));
      expect(
        signatureSimilarity(_strokes(), _differentStrokes()),
        lessThan(kSignatureSimilarityReject),
      );
      // 점이 너무 적어 비교할 수 없으면 같은 것으로 본다.
      expect(
        signatureSimilarity(_strokes(), [
          [
            [1, 1],
            [2, 2],
          ],
        ]),
        1.0,
      );
    });

    /// 서명 ①과 모양은 닮았지만 세로 비율이 많이 달라 `확인` 구간에 드는 서명.
    Strokes midStrokes() => [
      [
        for (final p in _strokes().first) [p[0], 40 + (p[1] - 40) * 5],
      ],
    ];

    Future<void> settleSheet(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    test('시험용 서명이 의도한 구간에 있다', () {
      expect(
        signatureMatchLevel(signatureSimilarity(_strokes(), _strokes(5))),
        SignatureMatch.same,
      );
      expect(
        signatureMatchLevel(signatureSimilarity(_strokes(), midStrokes())),
        SignatureMatch.uncertain,
      );
      expect(
        signatureMatchLevel(
          signatureSimilarity(_strokes(), _differentStrokes()),
        ),
        SignatureMatch.different,
      );
    });

    testWidgets('애매하게 다르면 확인창이 뜨고 다시 서명을 고르면 기록하지 않는다', (tester) async {
      final server = _FakeServer(_contractDoc());
      final capture = _ScriptCapture([_strokes(), midStrokes(), _strokes(6)]);
      await _pumpFlow(tester, server, capture);
      await toTermsAndSign(tester);

      expect(find.text('회원 서명을 확인하시겠습니까?'), findsOneWidget);
      expect(find.textContaining('서명 유사도'), findsOneWidget);
      await tester.tap(find.text('다시 서명'));
      await settleSheet(tester);
      // 서명 ②는 서버에 기록되지 않았다(서명 ①만 있음).
      expect(server.signCalls.map((c) => c['step']), ['disclosure']);
      expect(find.byKey(const ValueKey('terms_sign_button')), findsOneWidget);

      // 다시 서명하면(이번엔 비슷한 서명) 확인창 없이 기록된다.
      await tester.tap(find.byKey(const ValueKey('terms_sign_button')));
      await tester.pumpAndSettle();
      expect(find.text('회원 서명을 확인하시겠습니까?'), findsNothing);
      expect(server.signCalls.map((c) => c['step']), ['disclosure', 'member']);
    });

    testWidgets('애매해도 그대로 사용을 고르면 서명 ②가 기록된다', (tester) async {
      final server = _FakeServer(_contractDoc());
      final capture = _ScriptCapture([_strokes(), midStrokes()]);
      await _pumpFlow(tester, server, capture);
      await toTermsAndSign(tester);

      expect(find.text('회원 서명을 확인하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('그대로 사용'));
      await settleSheet(tester);
      await tester.pumpAndSettle();
      expect(server.signCalls.map((c) => c['step']), ['disclosure', 'member']);
    });

    testWidgets('전혀 다른 서명은 그대로 쓸 수 없고 다시 서명해야 한다', (tester) async {
      final server = _FakeServer(_contractDoc());
      final capture = _ScriptCapture([
        _strokes(),
        _differentStrokes(),
        _strokes(6),
      ]);
      await _pumpFlow(tester, server, capture);
      await toTermsAndSign(tester);

      // 확인 시트(그대로 사용)가 아니라 거절 안내가 뜬다.
      expect(find.text('회원 서명을 확인하시겠습니까?'), findsNothing);
      expect(
        find.byKey(const ValueKey('signature_mismatch_dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('서명 유사도'), findsOneWidget);
      expect(find.text('그대로 사용'), findsNothing);
      // 첫 번째 거절에서는 강사 확인으로 넘길 수 없다.
      expect(
        find.byKey(const ValueKey('signature_mismatch_override')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('signature_mismatch_retry')));
      await tester.pumpAndSettle();
      expect(server.signCalls.map((c) => c['step']), ['disclosure']);

      // 같은 방식으로 다시 서명하면 통과해 기록된다.
      await tester.tap(find.byKey(const ValueKey('terms_sign_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('signature_mismatch_dialog')),
        findsNothing,
      );
      expect(server.signCalls.map((c) => c['step']), ['disclosure', 'member']);
    });

    testWidgets('계속 맞지 않으면 세 번째부터 강사가 본인 서명임을 확인하고 진행할 수 있다', (tester) async {
      final server = _FakeServer(_contractDoc());
      final capture = _ScriptCapture([
        _strokes(),
        _differentStrokes(),
        _differentStrokes(),
        _differentStrokes(),
      ]);
      await _pumpFlow(tester, server, capture);
      await toTermsAndSign(tester);

      for (var attempt = 1; attempt <= 2; attempt++) {
        expect(
          find.byKey(const ValueKey('signature_mismatch_override')),
          findsNothing,
          reason: '$attempt번째 거절',
        );
        await tester.tap(
          find.byKey(const ValueKey('signature_mismatch_retry')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('terms_sign_button')));
        await tester.pumpAndSettle();
      }
      // 세 번째 거절부터 확인 버튼이 생긴다.
      expect(
        find.byKey(const ValueKey('signature_mismatch_override')),
        findsOneWidget,
      );
      expect(server.signCalls.map((c) => c['step']), ['disclosure']);
      await tester.tap(
        find.byKey(const ValueKey('signature_mismatch_override')),
      );
      await tester.pumpAndSettle();
      expect(server.signCalls.map((c) => c['step']), ['disclosure', 'member']);
    });
  });

  group('미리보기의 서명', () {
    testWidgets('받은 서명과 계약일이 서명란에 그려진다', (tester) async {
      tester.view.physicalSize = const Size(800, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final form = LessonContractForm.fromContract(_contractDoc());
      final party = ContractParty.fromMap(
        Map<String, dynamic>.from(_golden('basic')['party'] as Map),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractPreviewPage(
            document: buildLessonContractDocument(form: form, party: party),
            signatures: [_strokes(), _strokes(5), null],
            signedDate: '2026년 10월 20일',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026년 10월 20일'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_preview_signature_0')),
          matching: find.byType(SignatureStrokesView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_preview_signature_1')),
          matching: find.byType(SignatureStrokesView),
        ),
        findsOneWidget,
      );
      // 강사 서명은 아직 없어 빈 서명란이다.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_preview_signature_2')),
          matching: find.text('(서명)'),
        ),
        findsOneWidget,
      );
    });
  });

  group('입력 화면의 서명 진행', () {
    Stream<List<ManagedMemberSummary>> members() => Stream.value(const [
      ManagedMemberSummary(
        memberId: 'm1',
        name: '홍회원',
        phone: '010-9999-8888',
        managementState: 'active',
      ),
    ]);

    Future<void> pumpForm(
      WidgetTester tester,
      _FakeServer server, {
      String? contractId,
    }) async {
      tester.view.physicalSize = const Size(800, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractFormPage(
            personalOwnerUid: 'trainer-a',
            contractId: contractId,
            gateway: server,
            membersStream: members,
            clock: () => DateTime(2026, 10, 20),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('완료된 계약은 고치거나 서명을 이어 갈 수 없고 안내가 나온다', (tester) async {
      final server = _FakeServer(_contractDoc(status: 'completed'));
      await pumpForm(tester, server, contractId: 'pc_${'a' * 32}');
      expect(
        find.byKey(const ValueKey('contract_form_status_banner')),
        findsOneWidget,
      );
      expect(find.textContaining('서명이 완료된 계약서라 고칠 수 없어요'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('contract_form_save')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('contract_form_start_signing')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('서명 중인 계약은 내용을 바꾸면 서명이 무효가 된다고 알리고 이어서 진행 버튼이 나온다', (
      tester,
    ) async {
      final server = _FakeServer(_contractDoc(status: 'disclosed'));
      await pumpForm(tester, server, contractId: 'pc_${'a' * 32}');
      expect(find.textContaining('내용을 바꾸면 서명이 무효가 되어'), findsOneWidget);
      expect(find.text('회원 서명 이어서 진행'), findsOneWidget);
    });

    testWidgets('저장하고 회원 서명 받기: 먼저 저장하고 서명 흐름 화면을 연다', (tester) async {
      final server = _FakeServer(_contractDoc());
      await pumpForm(tester, server, contractId: 'pc_${'a' * 32}');
      expect(find.text('저장하고 회원 서명 받기'), findsOneWidget);
      final button = find.byKey(const ValueKey('contract_form_start_signing'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      // 서명 흐름 첫 화면(폰 전달)이 열렸다.
      expect(find.byKey(const ValueKey('sign_handoff_member')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sign_back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_start_signing')),
        findsOneWidget,
      );
    });

    testWidgets('입력이 비어 있으면 서명 흐름으로 넘어가지 않는다', (tester) async {
      final server = _FakeServer(_contractDoc());
      await pumpForm(tester, server);
      final button = find.byKey(const ValueKey('contract_form_start_signing'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(find.byKey(const ValueKey('sign_handoff_member')), findsNothing);
    });
  });
}

class _BrokenServer extends PersonalContractGateway {
  _BrokenServer()
    : super(callable: (name, parameters) async => throw UnimplementedError());

  int loads = 0;

  @override
  Future<Map<String, dynamic>?> loadContract(String contractId) async {
    loads += 1;
    throw StateError('offline');
  }
}
