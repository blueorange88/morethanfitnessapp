import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/lesson_contract_delivery_service.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_pdf.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';

class _Gateway extends PersonalContractGateway {
  _Gateway({required this.attachResults})
    : super(
        callable: (name, parameters) async {
          throw UnimplementedError(name);
        },
      );

  /// 호출 순서대로 돌려줄 값(예외면 던진다).
  final List<Object> attachResults;
  final List<String> log = [];

  @override
  Future<ContractDeliveryInfo> attachPdf(
    String contractId, {
    bool issueLink = true,
  }) async {
    log.add('attach:$issueLink');
    final next = attachResults.removeAt(0);
    if (next is Exception) throw next;
    return next as ContractDeliveryInfo;
  }

  @override
  Future<void> uploadContractPdf({
    required String trainerUid,
    required String contractId,
    required int version,
    required Uint8List bytes,
  }) async {
    log.add('upload:$trainerUid/$contractId/v$version');
  }
}

ContractDeliveryInfo _info() => const ContractDeliveryInfo(
  contractId: 'pc_x',
  version: 1,
  pdfHash: 'h',
  pdfSize: 1,
  viewUrl: 'https://x',
);

FirebaseFunctionsException _error(String message) =>
    FirebaseFunctionsException(message: message, code: 'failed-precondition');

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

Strokes _strokes() => [
  [
    for (var i = 0; i < 12; i++) [10 + i * 20.0, 40 + (i % 3) * 10.0],
  ],
];

void main() {
  group('ContractDeliveryInfo', () {
    test('서버 응답을 읽는다(링크가 있을 때와 없을 때)', () {
      final withLink = ContractDeliveryInfo.fromCallable({
        'contractId': 'pc_x',
        'version': 2,
        'pdfHash': 'abc',
        'pdfSize': 4096,
        'viewUrl': 'https://x/v?c=1&t=2',
        'linkExpiresAtMs': DateTime.utc(2027, 1, 19).millisecondsSinceEpoch,
      });
      expect(withLink.version, 2);
      expect(withLink.pdfSize, 4096);
      expect(withLink.viewUrl, 'https://x/v?c=1&t=2');
      expect(withLink.linkExpiresAt, DateTime.utc(2027, 1, 19).toLocal());

      final noLink = ContractDeliveryInfo.fromCallable({
        'contractId': 'pc_x',
        'pdfHash': 'abc',
      });
      expect(noLink.viewUrl, isNull);
      expect(noLink.linkExpiresAt, isNull);
      expect(ContractDeliveryInfo.fromCallable(null).pdfHash, '');
    });

    test('새 서버 오류 코드를 사용자 문구로 바꾼다', () {
      for (final code in [
        'pdf_not_uploaded',
        'pdf_invalid',
        'pdf_too_large',
        'contract_not_completed',
        'link_not_issued',
      ]) {
        final message = contractErrorMessage(_error(code));
        expect(message, isNot(contains('저장하지 못했어요. 잠시 뒤에')), reason: code);
      }
    });
  });

  group('ContractDeliveryService.prepare', () {
    test('서버에 PDF가 있으면 만들지도 올리지도 않는다', () async {
      final gateway = _Gateway(attachResults: [_info()]);
      var built = 0;
      final info = await ContractDeliveryService(gateway).prepare(
        contractId: 'pc_x',
        trainerUid: 'u1',
        version: 1,
        buildPdf: () async {
          built += 1;
          return Uint8List(1);
        },
      );
      expect(info.viewUrl, 'https://x');
      expect(built, 0);
      expect(gateway.log, ['attach:true']);
    });

    test('PDF가 없으면 만들어 올린 뒤 다시 등록한다', () async {
      final gateway = _Gateway(
        attachResults: [_error('pdf_not_uploaded'), _info()],
      );
      var built = 0;
      await ContractDeliveryService(gateway).prepare(
        contractId: 'pc_x',
        trainerUid: 'u1',
        version: 3,
        issueLink: false,
        buildPdf: () async {
          built += 1;
          return Uint8List(1);
        },
      );
      expect(built, 1);
      expect(gateway.log, [
        'attach:false',
        'upload:u1/pc_x/v3',
        'attach:false',
      ]);
    });

    test('PDF 없음이 아닌 서버 오류는 만들지 않고 그대로 던진다', () async {
      final gateway = _Gateway(
        attachResults: [_error('contract_not_completed')],
      );
      var built = 0;
      await expectLater(
        ContractDeliveryService(gateway).prepare(
          contractId: 'pc_x',
          trainerUid: 'u1',
          version: 1,
          buildPdf: () async {
            built += 1;
            return Uint8List(1);
          },
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(built, 0);
      expect(gateway.log, ['attach:true']);
    });
  });

  group('buildContractPdfFromRecord', () {
    test('저장된 계약 문서(서명 시각 포함)로 PDF를 만든다', () async {
      final record = {
        ..._golden('full'),
        'contractNo': 'PT-2610-0001',
        'version': 2,
        'contentHash': 'c' * 64,
        'completedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20, 6, 30)),
        'signatures': {
          for (final step in ['disclosure', 'member', 'trainer'])
            step: {
              'eventId': 'ev_$step',
              'signedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20, 6, 10)),
            },
        },
      };
      final font =
          await File(
            'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
          ).readAsBytes();
      final pdf = await buildContractPdfFromRecord(
        contractId: 'contract_1',
        verifyBase: 'https://asia-northeast3-demo.cloudfunctions.net',
        contract: record,
        strokes: {
          'disclosure': _strokes(),
          'member': _strokes(),
          'trainer': _strokes(),
        },
        fonts: ContractPdfFonts.fromVariableBytes(font),
      );
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(latin1.decode(pdf.sublist(pdf.length - 1024)), contains('%%EOF'));
      expect(pdf.length, lessThan(10 * 1024 * 1024));
    });
  });
}
