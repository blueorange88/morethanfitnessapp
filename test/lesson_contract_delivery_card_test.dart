import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_delivery_card.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';

const _contractId = 'pc_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Strokes _strokes() => [
  [
    for (var i = 0; i < 12; i++) [10 + i * 20.0, 40 + (i % 3) * 10.0],
  ],
];

class _FakeGateway extends PersonalContractGateway {
  _FakeGateway({this.uploaded = false, this.missingStrokes = false})
    : super(
        callable: (name, parameters) async {
          throw UnimplementedError(name);
        },
      );

  bool uploaded;
  bool missingStrokes;
  Object? attachError;
  Object? uploadError;
  final List<Map<String, Object?>> attachCalls = [];
  final List<Map<String, Object?>> uploads = [];
  final List<String> shared = [];

  @override
  Future<Strokes> loadSignatureStrokes(
    String contractId,
    String eventId,
  ) async => missingStrokes ? const [] : _strokes();

  @override
  Future<ContractDeliveryInfo> attachPdf(
    String contractId, {
    bool issueLink = true,
  }) async {
    attachCalls.add({'contractId': contractId, 'issueLink': issueLink});
    if (attachError != null) throw attachError!;
    if (!uploaded) {
      throw FirebaseFunctionsException(
        message: 'pdf_not_uploaded',
        code: 'failed-precondition',
      );
    }
    return ContractDeliveryInfo(
      contractId: contractId,
      version: 1,
      pdfHash: 'h' * 64,
      pdfSize: 1234,
      viewUrl:
          'https://asia-northeast3-p.cloudfunctions.net/viewPersonalContract'
          '?c=$contractId&t=token${attachCalls.length}',
      linkExpiresAt: DateTime.utc(2027, 1, 19, 3),
    );
  }

  @override
  Future<void> uploadContractPdf({
    required String trainerUid,
    required String contractId,
    required int version,
    required Uint8List bytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    uploads.add({
      'trainerUid': trainerUid,
      'contractId': contractId,
      'version': version,
      'length': bytes.length,
    });
    uploaded = true;
  }

  @override
  Future<void> markShared(String contractId, {required String channel}) async {
    shared.add(channel);
  }
}

Map<String, dynamic> _contract({Map<String, dynamic>? delivery}) => {
  'trainerId': 'trainer-a',
  'contractNo': 'PT-2610-0001',
  'version': 1,
  'party': {'name': '모어짐 강남'},
  'signatures': {
    for (final step in kDeliverySteps) step: {'eventId': 'ev_$step'},
  },
  'delivery': delivery ?? <String, dynamic>{},
};

Future<void> _pump(
  WidgetTester tester,
  _FakeGateway gateway, {
  Map<String, dynamic>? contract,
  List<Map<String, Strokes>>? builtWith,
  Future<bool> Function(String text)? share,
  Future<void> Function(String text)? copyText,
  Future<void> Function(Uint8List bytes, String fileName)? savePdf,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContractDeliveryCard(
            contractId: _contractId,
            contract: contract ?? _contract(),
            gateway: gateway,
            buildPdf: (contract, strokes) async {
              builtWith?.add(strokes);
              return Uint8List.fromList(List.filled(2048, 1));
            },
            share: share,
            copyText: copyText,
            savePdf: savePdf,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('PDF로 저장·공유: 링크를 만든 뒤에도, 이전에 링크를 만든 계약에서도 파일을 만들어 넘긴다', (
    tester,
  ) async {
    final saved = <({int length, String name})>[];
    final gateway = _FakeGateway();
    await _pump(
      tester,
      gateway,
      savePdf:
          (bytes, name) async => saved.add((length: bytes.length, name: name)),
    );
    expect(find.byKey(const ValueKey('done_save_pdf')), findsOneWidget);
    final uploadsBefore = gateway.uploads.length;
    await tester.tap(find.byKey(const ValueKey('done_save_pdf')));
    await tester.pumpAndSettle();
    expect(saved, [(length: 2048, name: '레슨계약서_PT-2610-0001.pdf')]);
    // 저장은 서버 등록·링크·보낸 기록과 무관하다.
    expect(gateway.uploads.length, uploadsBefore);
    expect(gateway.shared, isEmpty);

    // 이전에 링크를 만든 계약에서도 보이고, 새 링크를 만들지 않는다.
    final issued = _FakeGateway(uploaded: true);
    final savedAgain = <String>[];
    await _pump(
      tester,
      issued,
      contract: _contract(delivery: {'linkTokenHash': 'h' * 64}),
      savePdf: (bytes, name) async => savedAgain.add(name),
    );
    expect(issued.attachCalls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('done_save_pdf')));
    await tester.pumpAndSettle();
    expect(savedAgain, ['레슨계약서_PT-2610-0001.pdf']);
    expect(issued.attachCalls, isEmpty);
  });

  testWidgets('PDF로 저장·공유: 서명 정보를 못 불러오거나 저장이 실패하면 안내하고 다시 누를 수 있다', (
    tester,
  ) async {
    final gateway = _FakeGateway(uploaded: true);
    var calls = 0;
    await _pump(
      tester,
      gateway,
      contract: _contract(delivery: {'linkTokenHash': 'h' * 64}),
      savePdf: (bytes, name) async {
        calls += 1;
        throw StateError('disk');
      },
    );
    await tester.tap(find.byKey(const ValueKey('done_save_pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(find.text('PDF를 만들지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await _flushToast(tester);
    await tester.tap(find.byKey(const ValueKey('done_save_pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);

    final noStrokes = _FakeGateway(uploaded: true, missingStrokes: true);
    await _flushToast(tester);
    await _pump(
      tester,
      noStrokes,
      contract: _contract(delivery: {'linkTokenHash': 'h' * 64}),
      savePdf: (bytes, name) async => fail('서명이 없으면 저장하지 않는다'),
    );
    await tester.tap(find.byKey(const ValueKey('done_save_pdf')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('서명 정보를 불러오지 못해 PDF를 만들 수 없어요'), findsOneWidget);
    await _flushToast(tester);
  });

  testWidgets('링크가 없는 완료 계약은 PDF를 만들어 올리고 등록한 뒤 보내기 버튼을 보여 준다', (tester) async {
    final gateway = _FakeGateway();
    final built = <Map<String, Strokes>>[];
    await _pump(tester, gateway, builtWith: built);

    // 서명 그림 3개를 모두 불러와 PDF를 한 번 만들었다.
    expect(built, hasLength(1));
    expect(built.single.keys, containsAll(kDeliverySteps));
    // 이미 올라간 PDF가 있는지 먼저 확인(없음) → 올림 → 다시 등록.
    expect(gateway.attachCalls, hasLength(2));
    expect(gateway.uploads.single, {
      'trainerUid': 'trainer-a',
      'contractId': _contractId,
      'version': 1,
      'length': 2048,
    });
    expect(find.byKey(const ValueKey('done_delivery_ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('done_share')), findsOneWidget);
    expect(find.byKey(const ValueKey('done_copy_link')), findsOneWidget);
    // 만료일은 한국 시각 기준 날짜로 보인다.
    expect(find.textContaining('2027-01-19까지'), findsOneWidget);
  });

  testWidgets('이미 올라간 PDF가 있으면 다시 만들지 않고 링크만 발급한다', (tester) async {
    final gateway = _FakeGateway(uploaded: true);
    final built = <Map<String, Strokes>>[];
    await _pump(tester, gateway, builtWith: built);
    expect(built, isEmpty);
    expect(gateway.uploads, isEmpty);
    expect(gateway.attachCalls, hasLength(1));
    expect(find.byKey(const ValueKey('done_share')), findsOneWidget);
  });

  testWidgets('문자·카톡 보내기: 안내 문구와 링크를 공유하고 보낸 기록을 남긴다', (tester) async {
    final gateway = _FakeGateway();
    String? text;
    await _pump(
      tester,
      gateway,
      share: (value) async {
        text = value;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('done_share')));
    await tester.pumpAndSettle();

    expect(text, contains('모어짐 강남 레슨 계약서가 완료됐어요.'));
    expect(text, contains('계약번호 PT-2610-0001'));
    expect(text, contains('(2027-01-19까지)'));
    expect(
      text,
      contains(
        'https://asia-northeast3-p.cloudfunctions.net/viewPersonalContract'
        '?c=$_contractId&t=token2',
      ),
    );
    expect(gateway.shared, ['share_sheet']);
  });

  testWidgets('공유 시트를 보내지 않고 닫으면 보낸 기록을 남기지 않는다', (tester) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway, share: (_) async => false);
    await tester.tap(find.byKey(const ValueKey('done_share')));
    await tester.pumpAndSettle();
    expect(gateway.shared, isEmpty);
  });

  testWidgets('링크 복사: 링크만 복사하고 안내하며 기록을 남긴다', (tester) async {
    final gateway = _FakeGateway();
    String? copied;
    await _pump(tester, gateway, copyText: (value) async => copied = value);
    await tester.tap(find.byKey(const ValueKey('done_copy_link')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('https://asia-northeast3-p.cloudfunctions.net/'));
    expect(copied, isNot(contains('\n')));
    expect(find.text('열람 링크를 복사했어요.'), findsOneWidget);
    await _flushToast(tester);
    expect(gateway.shared, ['copy_link']);
  });

  testWidgets('서명 그림을 불러오지 못하면 PDF를 만들지 않고 다시 시도할 수 있다', (tester) async {
    final gateway = _FakeGateway(missingStrokes: true);
    final built = <Map<String, Strokes>>[];
    await _pump(tester, gateway, builtWith: built);
    expect(built, isEmpty);
    expect(gateway.uploads, isEmpty);
    expect(find.byKey(const ValueKey('done_delivery_failed')), findsOneWidget);
    expect(find.textContaining('서명 정보를 불러오지 못해'), findsOneWidget);

    gateway.missingStrokes = false;
    await tester.tap(find.byKey(const ValueKey('done_delivery_retry')));
    await tester.pumpAndSettle();
    expect(built, hasLength(1));
    expect(find.byKey(const ValueKey('done_delivery_ready')), findsOneWidget);
  });

  testWidgets('업로드나 서버 등록이 실패하면 안내하고 다시 시도하면 이어서 된다', (tester) async {
    final gateway = _FakeGateway()..uploadError = StateError('network');
    await _pump(tester, gateway);
    expect(find.byKey(const ValueKey('done_delivery_failed')), findsOneWidget);
    expect(gateway.uploads, isEmpty);

    gateway.uploadError = null;
    await tester.tap(find.byKey(const ValueKey('done_delivery_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('done_delivery_ready')), findsOneWidget);
    expect(gateway.uploads, hasLength(1));
  });

  testWidgets('서버가 거부하면 그 이유를 안내한다', (tester) async {
    final gateway =
        _FakeGateway()
          ..attachError = FirebaseFunctionsException(
            message: 'contract_not_completed',
            code: 'failed-precondition',
          );
    await _pump(tester, gateway);
    expect(find.text('서명이 모두 끝난 계약서만 보낼 수 있어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('done_delivery_retry')), findsOneWidget);
  });

  group('이전에 링크를 만든 계약', () {
    Map<String, dynamic> issued() => _contract(
      delivery: {
        'linkTokenHash': 'a' * 64,
        'shareCount': 2,
        'viewCount': 3,
        'firstViewedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 2, 1)),
      },
    );

    testWidgets('자동으로 새 링크를 만들지 않고 보낸·열람 현황을 보여 준다', (tester) async {
      final gateway = _FakeGateway(uploaded: true);
      await _pump(tester, gateway, contract: issued());
      expect(gateway.attachCalls, isEmpty, reason: '새 링크를 만들면 이전 링크가 무효가 된다');
      expect(
        find.byKey(const ValueKey('done_delivery_issued')),
        findsOneWidget,
      );
      expect(find.textContaining('보낸 기록 2회'), findsOneWidget);
      expect(find.textContaining('회원이 연 횟수 3회'), findsOneWidget);
      expect(find.textContaining('처음 연 날짜 2026-11-02'), findsOneWidget);
      expect(find.byKey(const ValueKey('done_share')), findsNothing);
    });

    testWidgets('새 링크 만들어 보내기는 확인한 뒤에만 발급하고 이어서 보낼 수 있다', (tester) async {
      final gateway = _FakeGateway(uploaded: true);
      await _pump(tester, gateway, contract: issued());

      await tester.tap(find.byKey(const ValueKey('done_new_link')));
      await tester.pumpAndSettle();
      expect(find.text('새 링크를 만들까요?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delivery_reissue_cancel')));
      await tester.pumpAndSettle();
      expect(gateway.attachCalls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('done_new_link')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delivery_reissue_confirm')));
      await tester.pumpAndSettle();
      expect(gateway.attachCalls, hasLength(1));
      expect(gateway.attachCalls.single['issueLink'], isTrue);
      expect(find.byKey(const ValueKey('done_share')), findsOneWidget);
    });
  });
}
