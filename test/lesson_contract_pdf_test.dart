import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_document.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_pdf.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';

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

const _hash =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
final _verifyUrl = contractVerifyUrl(
  base: 'https://asia-northeast3-demo.cloudfunctions.net',
  contractId: 'contract_1',
  contentHash: _hash,
);

Strokes _strokes(double offset) => [
  [
    for (var i = 0; i < 14; i++) [10 + i * 20 + offset, 40 + (i % 3) * 14.0],
  ],
  [
    [30 + offset, 90],
    [120 + offset, 95],
    [220 + offset, 85],
  ],
];

Future<Uint8List> _build({
  String golden = 'basic',
  LessonContractForm Function(LessonContractForm form)? tweak,
  List<ContractPdfSignature>? signatures,
  ContractPdfFonts? fonts,
}) async {
  final data = _golden(golden);
  var form = LessonContractForm.fromContract(data);
  if (tweak != null) form = tweak(form);
  final party = ContractParty.fromMap(
    Map<String, dynamic>.from(data['party'] as Map),
  );
  final document = buildLessonContractDocument(
    form: form,
    party: party,
    contractNo: 'PT-2610-0001',
  );
  final font =
      await File('assets/fonts/NotoSansKR-VariableFont_wght.ttf').readAsBytes();
  return buildLessonContractPdf(
    document: document,
    signatures:
        signatures ??
        [
          ContractPdfSignature(
            label: document.signatureLabels[0],
            strokes: _strokes(0),
            signedAt: DateTime.utc(2026, 10, 20, 6, 10),
            signerName: form.memberName,
          ),
          ContractPdfSignature(
            label: document.signatureLabels[1],
            strokes: _strokes(5),
            signedAt: DateTime.utc(2026, 10, 20, 6, 15),
            signerName: form.memberName,
          ),
          ContractPdfSignature(
            label: document.signatureLabels[2],
            strokes: _strokes(9),
            signedAt: DateTime.utc(2026, 10, 20, 6, 30),
            signerName: party.trainerName,
          ),
        ],
    contentHash: _hash,
    fonts: fonts ?? ContractPdfFonts.fromVariableBytes(font),
    verifyUrl: _verifyUrl,
    versionLabel: '1번째 버전',
    completedAt: DateTime.utc(2026, 10, 20, 6, 30),
  );
}

int _pageCount(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length;

void main() {
  test('한국 표준시 표기', () {
    expect(
      formatContractKst(DateTime.utc(2026, 10, 20, 6, 10)),
      '2026-10-20 15:10',
    );
    expect(
      formatContractKst(DateTime.utc(2026, 12, 31, 16, 5)),
      '2027-01-01 01:05',
    );
  });

  test('완료된 계약서를 한글 폰트가 들어간 올바른 PDF로 만든다', () async {
    final pdf = await _build();
    // PDF 머리와 끝, 크기 상한(서버·규칙은 10MB 이하만 받는다).
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(pdf.sublist(pdf.length - 1024)), contains('%%EOF'));
    expect(pdf.length, greaterThan(20 * 1024), reason: '폰트가 포함됐어야 한다');
    expect(pdf.length, lessThan(10 * 1024 * 1024));
    final text = latin1.decode(pdf);
    expect(text, contains('/FontFile2'));
    // 종이 계약서처럼 한 장에 모두 들어간다.
    expect(_pageCount(pdf), 1);
  });

  test('문서확인번호는 계약 내용 해시 앞 16자를 대문자로 4자씩 끊은 것이다', () {
    expect(contractVerificationCode(_hash), 'A1B2-C3D4-E5F6-0718');
    expect(contractVerificationCode('abc'), 'ABC0-0000-0000-0000');
  });

  test('진위 확인 주소에는 계약 ID와 하이픈 없는 확인번호가 들어간다', () {
    expect(
      _verifyUrl,
      'https://asia-northeast3-demo.cloudfunctions.net/verifyPersonalContract'
      '?c=contract_1&k=A1B2C3D4E5F60718',
    );
  });

  test('서명 전 미리보기(진위 확인 주소 없음)도 한 장 PDF로 만든다', () async {
    final data = _golden('full');
    final form = LessonContractForm.fromContract(data);
    final party = ContractParty.fromMap(
      Map<String, dynamic>.from(data['party'] as Map),
    );
    final font =
        await File(
          'assets/fonts/NotoSansKR-VariableFont_wght.ttf',
        ).readAsBytes();
    final pdf = await buildLessonContractPdf(
      document: buildLessonContractDocument(form: form, party: party),
      signatures: const [],
      contentHash: '',
      fonts: ContractPdfFonts.fromVariableBytes(font),
      verifyUrl: '',
    );
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_pageCount(pdf), 1);
  });

  test('센터 칸은 센터 계약일 때만 상호를 쓰고 개인 계약·상호 없음이면 비운다', () {
    expect(
      contractPdfCenterName(const [('상호(성명)', '모어짐 강남'), ('구분', '센터')]),
      '모어짐 강남',
    );
    expect(
      contractPdfCenterName(const [('상호(성명)', '김트레이너'), ('구분', '강사 개인')]),
      '',
    );
    expect(contractPdfCenterName(const [('상호(성명)', '-'), ('구분', '센터')]), '');
    expect(contractPdfCenterName(const []), '');
  });

  test('제목은 센터 계약이면 센터명이 앞에 붙고 아니면 레슨 계약서 그대로다', () {
    ContractDocument doc(List<(String, String)> party) => ContractDocument(
      title: '레슨 계약서',
      contractNo: '',
      partyRows: party,
      memberRows: const [],
      articles: const [],
      exampleLines: const [],
      signatureLabels: const [],
    );
    expect(
      contractTitle(doc(const [('상호(성명)', '모어짐 강남'), ('구분', '센터')])),
      '모어짐 강남 레슨 계약서',
    );
    expect(
      contractTitle(doc(const [('상호(성명)', '김트레이너'), ('구분', '강사 개인')])),
      '레슨 계약서',
    );
  });

  test('정상가는 할인율과 한 문장으로 보여 준다', () {
    expect(
      contractDiscountLine('2,400,000원 (25% 할인)'),
      '정상가 2,400,000원에서 25% 할인',
    );
    expect(contractDiscountLine('2,400,000원'), '정상가 2,400,000원');
  });

  test('비고와 특약이 모두 있어도 한 장 PDF로 만든다', () async {
    final pdf = await _build(
      golden: 'full',
      tweak: (form) => form.copyWith(remarks: '11월 50만원, 12월 50만원 분할 결제'),
    );
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_pageCount(pdf), 1);
  });

  test('서명 그림이 있으면 없는 것보다 내용이 늘어난다', () async {
    final withSig = await _build();
    final withoutSig = await _build(
      signatures: [
        const ContractPdfSignature(label: '회원 서명', strokes: []),
        const ContractPdfSignature(label: '강사 서명', strokes: []),
      ],
    );
    expect(withSig.length, isNot(withoutSig.length));
  });

  test('정상가 기준·종료일 없음·특약·큰 글자 내용도 오류 없이 만든다', () async {
    final full = await _build(golden: 'full');
    expect(latin1.decode(full.sublist(0, 5)), '%PDF-');
    // 정상가·할인·결제일까지 모두 들어간 계약도 한 장에 맞춘다.
    expect(_pageCount(full), 1);
    final unlimited = await _build(
      tweak:
          (form) => form.copyWith(
            periodEnd: '',
            periodUnlimited: true,
            extraTerms: List.filled(30, '추가 특약 문장입니다.').join(' '),
          ),
    );
    expect(latin1.decode(unlimited.sublist(0, 5)), '%PDF-');
    // 특약이 아주 길면 한 장을 넘을 수 있지만 오류 없이 만들어진다.
    expect(_pageCount(unlimited), greaterThanOrEqualTo(1));
  });

  test('같은 입력이면 문서 구성이 같아 크기가 같다(생성 시각은 제외)', () async {
    final a = await _build();
    final b = await _build();
    // PDF 안의 생성 시각 때문에 바이트가 완전히 같지는 않지만 크기는 같다.
    expect((a.length - b.length).abs(), lessThan(64));
  });

  group('글꼴 준비', () {
    test('번들 글꼴(굵기가 정해진 보통·굵게)을 읽어 서로 다른 글꼴로 쓴다', () async {
      final loaded = <String>[];
      final fonts = await loadContractPdfFonts(
        useCache: false,
        loadAsset: (asset) async {
          loaded.add(asset);
          return File(asset).readAsBytes();
        },
      );
      expect(loaded, [kContractPdfRegularFontAsset, kContractPdfBoldFontAsset]);
      expect(fonts.regular, isNot(same(fonts.bold)));
    });

    test('번들 글꼴만으로(인터넷 없이) 한 장 PDF를 만든다', () async {
      final fonts = await loadContractPdfFonts(
        useCache: false,
        loadAsset: (asset) => File(asset).readAsBytes(),
      );
      final pdf = await _build(golden: 'full', fonts: fonts);
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(_pageCount(pdf), 1);
      // 글꼴은 쓰인 글자만 담기므로 번들 글꼴이 커도 PDF는 작다(서버·규칙 상한 10MB).
      expect(pdf.length, lessThan(2 * 1024 * 1024));
    });

    test('번들 글꼴을 읽지 못하면 가변 글꼴로 대신해 PDF는 그대로 만들어진다', () async {
      final requested = <String>[];
      final fonts = await loadContractPdfFonts(
        useCache: false,
        loadAsset: (asset) async {
          requested.add(asset);
          if (asset != kContractPdfFontAsset) throw StateError('missing');
          return File(asset).readAsBytes();
        },
      );
      expect(requested.last, kContractPdfFontAsset);
      expect(fonts.regular, same(fonts.bold));
    });
  });
}
