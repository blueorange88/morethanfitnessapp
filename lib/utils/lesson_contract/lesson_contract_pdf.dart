import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/lesson_contract/lesson_contract_form.dart';
import 'lesson_contract_document.dart';
import 'signature_strokes.dart';

const String kContractPdfFontAsset =
    'assets/fonts/NotoSansKR-VariableFont_wght.ttf';
const String kContractPdfRegularFontAsset =
    'assets/fonts/NotoSansKR-Regular.ttf';
const String kContractPdfBoldFontAsset = 'assets/fonts/NotoSansKR-Bold.ttf';

/// PDF 서명란에 들어가는 서명 하나. [strokes]가 비어 있으면 서명란은 비워 둔다.
class ContractPdfSignature {
  const ContractPdfSignature({
    required this.label,
    required this.strokes,
    this.signedAt,
    this.signerName = '',
  });

  final String label;
  final Strokes strokes;
  final DateTime? signedAt;
  final String signerName;
}

/// 한국 표준시(UTC+9)로 `yyyy-MM-dd HH:mm`.
String formatContractKst(DateTime time) {
  final kst = time.toUtc().add(const Duration(hours: 9));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${kst.year}-${two(kst.month)}-${two(kst.day)} '
      '${two(kst.hour)}:${two(kst.minute)}';
}

/// 문서확인번호: 계약 내용 해시(SHA-256 16진수)의 앞 16자를 대문자로 4자씩 끊은 것
/// (`ABCD-EF01-2345-6789`). 서버(`verifyPersonalContract`)가 같은 방식으로 계산해 맞춰 본다.
String contractVerificationCode(String contentHash) {
  final hex = contentHash.trim().toUpperCase();
  final head = hex.length >= 16 ? hex.substring(0, 16) : hex.padRight(16, '0');
  return [for (var i = 0; i < 16; i += 4) head.substring(i, i + 4)].join('-');
}

/// 계약서 진위 확인 주소(QR에 담긴다). [base]는 `https://<리전>-<프로젝트>.cloudfunctions.net`.
String contractVerifyUrl({
  required String base,
  required String contractId,
  required String contentHash,
}) {
  final code = contractVerificationCode(contentHash).replaceAll('-', '');
  return '$base/verifyPersonalContract?c=$contractId&k=$code';
}

/// PDF에 쓰는 글꼴 한 벌(보통·굵게).
class ContractPdfFonts {
  const ContractPdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  /// 앱에 들어 있는 가변 글꼴로 한 벌을 만든다. 가변 글꼴은 PDF에서 가장 가는 굵기로 나오고
  /// 굵게 표시도 되지 않으므로, 굵기가 정해진 글꼴을 읽지 못했을 때만 대신 쓴다.
  factory ContractPdfFonts.fromVariableBytes(Uint8List bytes) {
    final font = pw.Font.ttf(ByteData.sublistView(bytes));
    return ContractPdfFonts(regular: font, bold: font);
  }
}

ContractPdfFonts? _cachedFonts;

/// PDF 글꼴을 준비한다. 앱에 들어 있는 굵기가 정해진 Noto Sans KR(보통·굵게)을 쓰므로 인터넷이 없어도
/// 되고 기다릴 일이 없다(앱을 켜 둔 동안은 한 번만 읽는다). 번들 글꼴을 읽지 못하는 예외 상황에서만
/// 가변 글꼴로 대신한다.
Future<ContractPdfFonts> loadContractPdfFonts({
  Future<Uint8List> Function(String asset)? loadAsset,
  bool useCache = true,
}) async {
  if (useCache && _cachedFonts != null) return _cachedFonts!;
  Future<Uint8List> read(String asset) async =>
      loadAsset != null
          ? loadAsset(asset)
          : (await rootBundle.load(asset)).buffer.asUint8List();
  try {
    final bytes = await Future.wait<Uint8List>([
      read(kContractPdfRegularFontAsset),
      read(kContractPdfBoldFontAsset),
    ]);
    final loaded = ContractPdfFonts(
      regular: pw.Font.ttf(ByteData.sublistView(bytes[0])),
      bold: pw.Font.ttf(ByteData.sublistView(bytes[1])),
    );
    if (useCache) _cachedFonts = loaded;
    return loaded;
  } catch (error) {
    debugPrint('[MTF_CONTRACT_PDF] 번들 글꼴을 읽지 못해 가변 글꼴로 대신해요: $error');
    return ContractPdfFonts.fromVariableBytes(
      await read(kContractPdfFontAsset),
    );
  }
}

/// 한 장에 들어가도록 글자 크기를 줄여 가며 시도하는 배율. 내용이 짧으면 큰 글씨로, 길면 작게.
const List<double> kContractPdfScales = [
  1.3,
  1.22,
  1.15,
  1.08,
  1.0,
  0.95,
  0.9,
  0.85,
  0.8,
  0.76,
  0.72,
  0.68,
];

/// PDF `센터(상호)` 칸의 값. 센터와 연결된 계약일 때만 상호를 쓰고, 강사 개인 계약이거나 상호가 없으면
/// 비워 둔다(개인 계약의 `상호(성명)`에는 강사 이름이 들어 있어 센터 칸에 쓰면 안 된다).
String contractPdfCenterName(List<(String, String)> partyRows) {
  if (_lookup(partyRows, '구분') != '센터') return '';
  final name = _lookup(partyRows, '상호(성명)').trim();
  return name == '-' ? '' : name;
}

/// 계약서 제목. 센터와 연결된 계약이면 `센터명 레슨 계약서`, 아니면 문서 제목(`레슨 계약서`) 그대로.
String contractTitle(ContractDocument document) {
  final center = contractPdfCenterName(document.partyRows);
  return center.isEmpty ? document.title : '$center ${document.title}';
}

/// `2,400,000원 (25% 할인)` 형태의 정상가 값을 `정상가 2,400,000원에서 25% 할인`으로. 할인 표기가 없으면
/// `정상가 값` 그대로.
String contractDiscountLine(String listPrice) {
  final match = RegExp(r'^(.*?)\s*\((.+?)\s*할인\)\s*$').firstMatch(listPrice);
  if (match == null) return '정상가 $listPrice';
  return '정상가 ${match.group(1)}에서 ${match.group(2)} 할인';
}

/// `2026-10-20 ~ 2027-01-20` 형태의 사용 기간에서 시작일만.
String _periodStart(String period) {
  final start = period.split('~').first.trim();
  return start == '-' ? '' : start;
}

String _lookup(List<(String, String)> rows, String label) {
  for (final (key, value) in rows) {
    if (key == label) return value;
  }
  return '';
}

/// 완료된 레슨계약서 PDF(A4 한 장). 종이 계약서 양식을 따른다: 제목 → 계약 내용 칸 → 조항 → 설명 확인
/// 서명(회원 서명 ①) → 회원·강사 서명 → 문서 진위 확인(문서확인번호·QR·내용 해시).
///
/// 내용이 길면 글자 크기를 [kContractPdfScales] 순서로 줄여 한 장에 맞춘다. 가장 작은 크기로도 안 맞을
/// 때만 두 장 이상이 된다. [signatures]는 회원 서명 ①(설명 확인) · 회원 서명 ②(전체 동의) · 강사
/// 서명 순서다. [verifyUrl]이 비어 있으면 서명 전 미리보기용으로 QR·문서확인번호 자리를 안내만 둔다.
Future<Uint8List> buildLessonContractPdf({
  required ContractDocument document,
  required List<ContractPdfSignature> signatures,
  required String contentHash,
  required ContractPdfFonts fonts,
  required String verifyUrl,
  String versionLabel = '',
  DateTime? completedAt,
}) async {
  pw.Document? last;
  for (final scale in kContractPdfScales) {
    final pdf = _composeContractPdf(
      document: document,
      signatures: signatures,
      contentHash: contentHash,
      fonts: fonts,
      verifyUrl: verifyUrl,
      versionLabel: versionLabel,
      completedAt: completedAt,
      scale: scale,
    );
    last = pdf;
    if (pdf.document.pdfPageList.pages.length <= 1) break;
  }
  return Uint8List.fromList(await last!.save());
}

/// 지정한 글자 배율로 계약서 한 부를 구성한다(몇 쪽이 되는지는 호출한 쪽이 확인한다).
pw.Document _composeContractPdf({
  required ContractDocument document,
  required List<ContractPdfSignature> signatures,
  required String contentHash,
  required ContractPdfFonts fonts,
  required String verifyUrl,
  required String versionLabel,
  required DateTime? completedAt,
  required double scale,
}) {
  double f(double size) => size * scale;
  final theme = pw.ThemeData.withFont(
    base: fonts.regular,
    bold: fonts.bold,
    italic: fonts.regular,
    boldItalic: fonts.bold,
  );
  const ink = PdfColor.fromInt(0xFF111827);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFF9CA3AF);
  const soft = PdfColor.fromInt(0xFFF3F4F6);

  final product =
      document.articles.isEmpty
          ? const <(String, String)>[]
          : document.articles.first.rows;
  final member = document.memberRows;
  final party = document.partyRows;
  final code = contractVerificationCode(contentHash);
  // 서명 전 미리보기: 문서확인번호·QR 자리는 비워 두고 안내만 보여 준다.
  final preview = verifyUrl.isEmpty;

  ContractPdfSignature signatureAt(int index) =>
      index < signatures.length
          ? signatures[index]
          : const ContractPdfSignature(label: '', strokes: []);
  final explain = signatureAt(0);
  final agree = signatureAt(1);
  final trainer = signatureAt(2);

  pw.Widget cell(
    String label,
    String value, {
    pw.Widget? extra,
    bool blankIfEmpty = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: f(6), vertical: f(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: f(7.5),
              fontWeight: pw.FontWeight.bold,
              color: muted,
            ),
          ),
          pw.SizedBox(height: f(2)),
          pw.Text(
            value.isEmpty && !blankIfEmpty ? '-' : value,
            style: pw.TextStyle(
              fontSize: f(9.5),
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }

  // 결제 방법: 종이 양식처럼 ■(선택)·□(미선택)로 보여 준다.
  final method = _lookup(product, '결제 방법');
  final methodLine = [
    for (final (_, label) in kContractPaymentMethods)
      '${label == method ? '■' : '□'}$label',
  ].join('  ');

  final listPrice = _lookup(product, '정상가');

  // 비고: 안내용 메모(분할결제 일정 등). 추가 특약은 조항(제N조 특약)으로 따로 들어간다.
  final remarks = _lookup(product, '비고');

  pw.Widget grid() => pw.Table(
    border: pw.TableBorder.all(color: line, width: 0.6),
    columnWidths: const {
      0: pw.FlexColumnWidth(),
      1: pw.FlexColumnWidth(),
      2: pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        children: [
          cell('회원성명', _lookup(member, '성명')),
          cell('회원 연락처', _lookup(member, '연락처')),
          cell('담당 강사', _lookup(party, '담당 강사')),
        ],
      ),
      pw.TableRow(
        children: [
          cell('레슨명', _lookup(product, '레슨명')),
          cell('총 수강횟수', _lookup(product, '총 횟수')),
          cell('1회 수업 시간', _lookup(product, '1회 수업 시간')),
        ],
      ),
      pw.TableRow(
        children: [
          cell('사용 기간', _lookup(product, '사용 가능 기간')),
          cell('센터(상호)', contractPdfCenterName(party), blankIfEmpty: true),
          cell('레슨 시작일', _periodStart(_lookup(product, '사용 가능 기간'))),
        ],
      ),
      pw.TableRow(
        children: [
          cell('1회 수강료', _lookup(product, '회당 금액')),
          cell(
            '강습비 합계',
            _lookup(product, '실결제금액'),
            extra:
                listPrice.isEmpty
                    ? null
                    : pw.Padding(
                      padding: pw.EdgeInsets.only(top: f(2)),
                      child: pw.Text(
                        contractDiscountLine(listPrice),
                        style: pw.TextStyle(fontSize: f(8), color: ink),
                      ),
                    ),
          ),
          cell('결제 방법', methodLine),
        ],
      ),
    ],
  );

  pw.Widget remarksBox() => pw.Table(
    border: pw.TableBorder.all(color: line, width: 0.6),
    columnWidths: {
      0: pw.FixedColumnWidth(f(58)),
      1: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(horizontal: f(6), vertical: f(5)),
            child: pw.Text(
              '비고',
              style: pw.TextStyle(
                fontSize: f(7.5),
                fontWeight: pw.FontWeight.bold,
                color: muted,
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(horizontal: f(6), vertical: f(4)),
            child: pw.ConstrainedBox(
              constraints: pw.BoxConstraints(minHeight: f(18)),
              child: pw.Text(
                remarks,
                style: pw.TextStyle(
                  fontSize: f(8.6),
                  lineSpacing: f(1.4),
                  color: ink,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // 결재란: 센터(비즈니스) 연결 기능에서 쓸 자리. 지금은 빈칸 세 개만 둔다.
  pw.Widget approvalBox() => pw.Table(
    border: pw.TableBorder.all(color: line, width: 0.6),
    defaultColumnWidth: pw.FixedColumnWidth(f(46)),
    children: [
      pw.TableRow(
        children: [
          for (var i = 0; i < 3; i++) pw.Container(height: f(11), color: soft),
        ],
      ),
      pw.TableRow(
        children: [for (var i = 0; i < 3; i++) pw.Container(height: f(30))],
      ),
    ],
  );

  pw.Widget signatureDrawing(Strokes strokes, double width, double height) {
    if (strokes.isEmpty) return pw.SizedBox(width: width, height: height);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p[0] < minX) minX = p[0];
        if (p[0] > maxX) maxX = p[0];
        if (p[1] < minY) minY = p[1];
        if (p[1] > maxY) maxY = p[1];
      }
    }
    final contentW = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;
    final contentH = (maxY - minY).abs() < 1 ? 1.0 : maxY - minY;
    const pad = 3.0;
    final scaleW = (width - pad * 2) / contentW;
    final scaleH = (height - pad * 2) / contentH;
    final fit = scaleW < scaleH ? scaleW : scaleH;
    final offsetX = (width - contentW * fit) / 2 - minX * fit;
    final offsetY = (height - contentH * fit) / 2 - minY * fit;
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (PdfGraphics canvas, PdfPoint size) {
        canvas
          ..setStrokeColor(const PdfColor.fromInt(0xFF111111))
          ..setLineWidth(1.2)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        for (final stroke in strokes) {
          if (stroke.isEmpty) continue;
          // PDF 좌표는 아래에서 위로 늘어난다.
          double px(List<double> p) => p[0] * fit + offsetX;
          double py(List<double> p) => size.y - (p[1] * fit + offsetY);
          canvas.moveTo(px(stroke.first), py(stroke.first));
          if (stroke.length == 1) {
            canvas.lineTo(px(stroke.first) + 0.1, py(stroke.first));
          }
          for (final p in stroke.skip(1)) {
            canvas.lineTo(px(p), py(p));
          }
          canvas.strokePath();
        }
      },
    );
  }

  String timeText(ContractPdfSignature s) =>
      s.signedAt == null ? '' : formatContractKst(s.signedAt!);

  // ---- 조항 ----
  const explainAfter = ['이용분 계산 기준', '위약금 및 환불'];
  final rest = document.articles.skip(1).toList();
  var explainIndex = -1;
  for (final heading in explainAfter) {
    explainIndex = rest.indexWhere((a) => a.heading == heading);
    if (explainIndex >= 0) break;
  }
  if (explainIndex < 0 && rest.isNotEmpty) explainIndex = rest.length - 1;

  pw.Widget articleBlock(ContractDocArticle article, int number) {
    final paragraphs = article.paragraphs;
    final style = pw.TextStyle(
      fontSize: f(8.2),
      lineSpacing: f(1.6),
      color: ink,
    );
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: f(3.2)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              style: style,
              children: [
                pw.TextSpan(
                  text: '제$number조 ${article.heading}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (paragraphs.isNotEmpty)
                  pw.TextSpan(text: '  ${paragraphs.first}'),
              ],
            ),
          ),
          for (final text in paragraphs.skip(1)) pw.Text(text, style: style),
        ],
      ),
    );
  }

  pw.Widget explainBox() {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: f(4), top: f(1)),
      padding: pw.EdgeInsets.symmetric(horizontal: f(7), vertical: f(4)),
      decoration: pw.BoxDecoration(
        color: soft,
        border: pw.Border.all(color: line, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(
                  '(본인은 계약 금액, 환불 기준, 당일 취소·노쇼에 따른 횟수 차감, 사용 기간과 소멸에 대한 '
                  '설명을 들었으며 이해하고 동의합니다.)',
                  style: pw.TextStyle(
                    fontSize: f(8),
                    fontWeight: pw.FontWeight.bold,
                    lineSpacing: f(1.4),
                    color: ink,
                  ),
                ),
              ),
              pw.SizedBox(width: f(8)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: f(104),
                    height: f(34),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border(
                        bottom: pw.BorderSide(color: line, width: 0.6),
                      ),
                    ),
                    child: signatureDrawing(explain.strokes, f(104), f(34)),
                  ),
                  pw.Text(
                    '서명 ① ${timeText(explain)}',
                    style: pw.TextStyle(fontSize: f(6.6), color: muted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget bottomSignature(String title, ContractPdfSignature signature) {
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: f(7), vertical: f(4)),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: ink, width: 0.9)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: f(8.6),
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.Text(
                  signature.signedAt == null
                      ? '날짜 -'
                      : '날짜 ${timeText(signature).substring(0, 10)}',
                  style: pw.TextStyle(fontSize: f(8), color: ink),
                ),
              ],
            ),
            pw.SizedBox(
              height: f(46),
              child: signatureDrawing(signature.strokes, f(190), f(46)),
            ),
            pw.Text(
              [
                if (signature.signerName.trim().isNotEmpty)
                  signature.signerName.trim(),
                if (signature.signedAt != null) '서명 ${timeText(signature)}',
              ].join(' · '),
              style: pw.TextStyle(fontSize: f(6.8), color: muted),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget verifyBox() {
    return pw.Container(
      padding: pw.EdgeInsets.all(f(6)),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: ink, width: 0.9),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (preview)
            pw.Container(
              width: f(56),
              height: f(56),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: line, width: 0.8),
              ),
              child: pw.Text(
                'QR',
                style: pw.TextStyle(fontSize: f(12), color: muted),
              ),
            )
          else
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: verifyUrl,
              width: f(56),
              height: f(56),
              drawText: false,
            ),
          pw.SizedBox(width: f(8)),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  preview
                      ? '문서 진위 확인  ·  문서확인번호는 서명 완료 후 부여됩니다'
                      : '문서 진위 확인  ·  문서확인번호 $code',
                  style: pw.TextStyle(
                    fontSize: f(9),
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.SizedBox(height: f(2)),
                pw.Text(
                  '왼쪽 QR 코드를 스캔하면 서버에 기록된 원본 계약서인지 확인할 수 있습니다. '
                  '확인 화면에 이 PDF 파일을 올리면 내용이 바뀌지 않았는지 원본과 대조합니다. '
                  '계약 내용이 한 글자라도 바뀌면 문서확인번호와 대조 결과가 달라집니다.',
                  style: pw.TextStyle(
                    fontSize: f(7),
                    lineSpacing: f(1.3),
                    color: ink,
                  ),
                ),
                pw.SizedBox(height: f(2)),
                pw.Text(
                  [
                    if (completedAt != null)
                      '계약 완료 ${formatContractKst(completedAt)}',
                    if (!preview) '계약 내용 SHA-256 $contentHash',
                  ].join('  ·  '),
                  style: pw.TextStyle(fontSize: f(5.8), color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final subtitle =
      '계약번호 ${document.contractNo}'
      '${versionLabel.isEmpty ? '' : ' · $versionLabel'}';

  final pdf = pw.Document(
    title: '${document.title} ${document.contractNo}',
    author: 'MORE THAN FITNESS',
    creator: 'MORE THAN FITNESS',
    theme: theme,
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 26),
      build:
          (context) => [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        contractTitle(document),
                        style: pw.TextStyle(
                          fontSize: f(21),
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      pw.Text(
                        'Personal Training Contract  ·  $subtitle',
                        style: pw.TextStyle(fontSize: f(8), color: muted),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: f(10)),
                approvalBox(),
              ],
            ),
            pw.SizedBox(height: f(8)),
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: f(3)),
              child: pw.Text(
                '제1조 계약의 내용',
                style: pw.TextStyle(
                  fontSize: f(9),
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
            grid(),
            remarksBox(),
            pw.SizedBox(height: f(7)),
            for (var i = 0; i < rest.length; i++) ...[
              articleBlock(rest[i], i + 2),
              if (i == explainIndex) explainBox(),
            ],
            pw.SizedBox(height: f(5)),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                bottomSignature('회원 서명 (계약 전체 동의)', agree),
                pw.SizedBox(width: f(10)),
                bottomSignature('강사 서명', trainer),
              ],
            ),
            pw.SizedBox(height: f(5)),
            verifyBox(),
          ],
    ),
  );
  return pdf;
}
