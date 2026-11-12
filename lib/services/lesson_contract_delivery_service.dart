import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/lesson_contract/lesson_contract_form.dart';
import '../models/lesson_contract/lesson_contract_settings.dart';
import '../utils/lesson_contract/lesson_contract_document.dart';
import '../utils/lesson_contract/lesson_contract_pdf.dart';
import '../utils/lesson_contract/signature_strokes.dart';
import 'mtf_firebase_functions.dart';
import 'personal_contract_gateway.dart';

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// 진위 확인 주소의 앞부분(`https://<리전>-<프로젝트>.cloudfunctions.net`). 지금 연결된 Firebase
/// 프로젝트(개발·운영)를 따라간다.
String defaultContractVerifyBase() =>
    'https://${MtfFirebaseFunctions.region}-${Firebase.app().options.projectId}.cloudfunctions.net';

/// 저장된 계약 문서(서명 완료본)로 PDF를 만든다. 서명 그림은 [strokes]에 단계별(`disclosure`·
/// `member`·`trainer`)로 넘기고, 없으면 그 서명란은 비워 둔다.
Future<Uint8List> buildContractPdfFromRecord({
  required String contractId,
  required Map<String, dynamic> contract,
  required Map<String, Strokes> strokes,
  required ContractPdfFonts fonts,
  String? verifyBase,
}) {
  final party = ContractParty.fromMap(
    contract['party'] is Map
        ? Map<String, dynamic>.from(contract['party'] as Map)
        : <String, dynamic>{},
  );
  final form = LessonContractForm.fromContract(contract);
  final version = (contract['version'] as num?)?.toInt() ?? 1;
  final no = (contract['contractNo'] ?? '').toString();
  final contractNo = version > 1 ? '$no-v$version' : no;
  final document = buildLessonContractDocument(
    form: form,
    party: party,
    contractNo: contractNo,
  );
  final signatures =
      contract['signatures'] is Map
          ? Map<String, dynamic>.from(contract['signatures'] as Map)
          : <String, dynamic>{};

  DateTime? signedAt(String step) {
    final entry = signatures[step];
    return entry is Map ? _date(entry['signedAt']) : null;
  }

  final contentHash = (contract['contentHash'] ?? '').toString();
  return buildLessonContractPdf(
    document: document,
    signatures: [
      ContractPdfSignature(
        label: document.signatureLabels[0],
        strokes: strokes['disclosure'] ?? const [],
        signedAt: signedAt('disclosure'),
        signerName: form.memberName,
      ),
      ContractPdfSignature(
        label: document.signatureLabels[1],
        strokes: strokes['member'] ?? const [],
        signedAt: signedAt('member'),
        signerName: form.memberName,
      ),
      ContractPdfSignature(
        label: document.signatureLabels[2],
        strokes: strokes['trainer'] ?? const [],
        signedAt: signedAt('trainer'),
        signerName: party.trainerName,
      ),
    ],
    contentHash: contentHash,
    fonts: fonts,
    verifyUrl: contractVerifyUrl(
      base: verifyBase ?? defaultContractVerifyBase(),
      contractId: contractId,
      contentHash: contentHash,
    ),
    versionLabel: version > 1 ? '$version번째 버전' : '',
    completedAt: _date(contract['completedAt']),
  );
}

/// 완료된 계약서를 회원에게 보낼 수 있게 준비한다: PDF 생성 → 업로드 → 서버 등록 → 열람 링크 발급.
class ContractDeliveryService {
  ContractDeliveryService(this.gateway);

  final PersonalContractGateway gateway;

  /// 서버에 이미 PDF가 올라가 있으면 다시 만들지 않고 등록·링크 발급만 한다(앱이 중간에 꺼졌다가
  /// 다시 시도하는 경우와 링크 재발급). 올라간 PDF가 없을 때만 [buildPdf]로 만들어 올린다.
  Future<ContractDeliveryInfo> prepare({
    required String contractId,
    required String trainerUid,
    required int version,
    required Future<Uint8List> Function() buildPdf,
    bool issueLink = true,
  }) async {
    try {
      return await gateway.attachPdf(contractId, issueLink: issueLink);
    } on FirebaseFunctionsException catch (error) {
      if (contractErrorCode(error) != 'pdf_not_uploaded') rethrow;
    }
    final bytes = await buildPdf();
    await gateway.uploadContractPdf(
      trainerUid: trainerUid,
      contractId: contractId,
      version: version,
      bytes: bytes,
    );
    return gateway.attachPdf(contractId, issueLink: issueLink);
  }
}
