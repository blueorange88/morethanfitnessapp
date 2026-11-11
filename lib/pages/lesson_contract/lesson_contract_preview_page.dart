import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart' show Printing;

import '../../utils/lesson_contract/lesson_contract_document.dart';
import '../../utils/lesson_contract/lesson_contract_pdf.dart';
import '../../utils/lesson_contract/signature_strokes.dart';
import 'lesson_contract_widgets.dart';

const double kLessonContractPreviewMaxWidth = 520;

const Color _paper = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF111111);
const Color _rule = Color(0xFF3A3A3A);
const Color _shade = Color(0xFFF1F1F1);
const Color _muted = Color(0xFF666666);

const List<String> _circled = [
  '①',
  '②',
  '③',
  '④',
  '⑤',
  '⑥',
  '⑦',
  '⑧',
  '⑨',
  '⑩',
];

/// 실제 계약서 PDF를 쪽별 이미지(PNG)로 바꾼다. 테스트에서는 이 함수를 바꿔 끼운다.
typedef ContractPdfRasterizer = Future<List<Uint8List>> Function(Uint8List pdf);

Future<List<Uint8List>> _rasterizeWithPrinting(Uint8List pdf) async {
  final pages = <Uint8List>[];
  // 확대해서 읽을 수 있도록 넉넉한 해상도로 그린다(A4 폭 기준 약 1650px).
  await for (final raster in Printing.raster(pdf, dpi: 200)) {
    pages.add(await raster.toPng());
  }
  return pages;
}

/// 계약서 미리보기. 서명 뒤에 회원에게 가는 **실제 계약서 PDF**와 같은 문서를 그려 보여 준다(두 손가락으로
/// 확대 가능). PDF를 만들거나 그리지 못하면 같은 내용을 종이 문서 형식(제목, 당사자 표, 조항, 별첨,
/// 서명란)으로 보여 주는 화면으로 대신한다. 화면 테마와 상관없이 흰 바탕에 검은 글씨로 그린다.
class LessonContractPreviewPage extends StatefulWidget {
  const LessonContractPreviewPage({
    super.key,
    required this.document,
    this.signatures = const [],
    this.signedDate = '',
    this.contentHash = '',
    this.verifyUrl = '',
    this.completedAt,
    this.watermark = '',
    this.pdfBuilder,
    this.rasterizer,
  });

  /// 실제 PDF로 미리보기를 보여 줄지. 테스트에서 PDF 만들기·그리기 없이 종이 문서 화면만 확인하려고
  /// 끌 때만 바꾼다.
  static bool realPdfEnabled = true;

  final ContractDocument document;

  /// 서명란 순서(회원 ① · 회원 ② · 강사)대로 받은 서명. 없거나 짧으면 빈 서명란.
  final List<Strokes?> signatures;

  /// 계약일(`2026년 10월 17일`). 비어 있으면 빈칸으로 둔다.
  final String signedDate;

  /// 서명이 끝난 계약이면 PDF 맨 아래 문서 진위 확인(QR·번호)에 쓰는 값. 비어 있으면 서명 전 미리보기다.
  final String contentHash;
  final String verifyUrl;
  final DateTime? completedAt;

  /// 비어 있지 않으면 각 쪽 위에 대각선으로 겹쳐 그리는 표시 문구(예: `해지 완료`). 화면에만 그리고
  /// 계약서 PDF·문서 해시는 바꾸지 않는다(이미 회원에게 간 파일과 같게 둔다).
  final String watermark;

  /// 실제 PDF를 만드는 함수와 쪽 이미지로 바꾸는 함수(기본값은 앱의 실제 구현).
  final Future<Uint8List> Function()? pdfBuilder;
  final ContractPdfRasterizer? rasterizer;

  @override
  State<LessonContractPreviewPage> createState() =>
      _LessonContractPreviewPageState();
}

class _LessonContractPreviewPageState extends State<LessonContractPreviewPage> {
  Future<List<Uint8List>>? _pages;

  @override
  void initState() {
    super.initState();
    if (LessonContractPreviewPage.realPdfEnabled) _pages = _load();
  }

  Future<List<Uint8List>> _load() async {
    final bytes = await (widget.pdfBuilder ?? _defaultBuild)();
    return (widget.rasterizer ?? _rasterizeWithPrinting)(bytes);
  }

  Future<Uint8List> _defaultBuild() async {
    final fonts = await loadContractPdfFonts();
    final labels = widget.document.signatureLabels;
    return buildLessonContractPdf(
      document: widget.document,
      signatures: [
        for (var i = 0; i < 3; i++)
          ContractPdfSignature(
            label: i < labels.length ? labels[i] : '',
            strokes:
                i < widget.signatures.length
                    ? (widget.signatures[i] ?? const [])
                    : const [],
          ),
      ],
      contentHash: widget.contentHash,
      fonts: fonts,
      verifyUrl: widget.contentHash.isEmpty ? '' : widget.verifyUrl,
      completedAt: widget.completedAt,
    );
  }

  /// [child] 위에 [LessonContractPreviewPage.watermark]를 겹친다(문구가 없으면 그대로).
  Widget _withWatermark(Widget child) {
    if (widget.watermark.isEmpty) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(child: _Watermark(label: widget.watermark)),
        ),
      ],
    );
  }

  Widget _paperFallback() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kLessonContractPreviewMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          children: [
            _withWatermark(
              _Paper(
                document: widget.document,
                signatures: widget.signatures,
                signedDate: widget.signedDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final pages = _pages;
    if (pages == null) return _paperFallback();
    return FutureBuilder<List<Uint8List>>(
      future: pages,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            key: ValueKey<String>('contract_preview_loading'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('계약서를 만드는 중이에요'),
              ],
            ),
          );
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null || data.isEmpty) {
          debugPrint(
            '[MTF_CONTRACT_PREVIEW] PDF 미리보기를 만들지 못해 문서 화면으로 대신해요: '
            '${snapshot.error}',
          );
          return _paperFallback();
        }
        return LayoutBuilder(
          builder:
              (context, constraints) => InteractiveViewer(
                key: const ValueKey<String>('contract_preview_pdf'),
                constrained: false,
                minScale: 1,
                maxScale: 5,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final page in data)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: _paper,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _withWatermark(
                                Image.memory(
                                  page,
                                  fit: BoxFit.fitWidth,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                        // 흰 종이 밖(앱 배경 위)의 안내라 다크 모드에서도 보이도록 테마 글자색을 쓴다.
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '※ 서명 뒤 회원에게 전달되는 계약서와 같은 모양입니다. 두 손가락으로 확대할 수 있어요.',
                            key: const ValueKey<String>(
                              'contract_preview_pdf_note',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: Column(
        children: [
          LessonContractHeader(
            title: '계약서 미리보기',
            backKey: const ValueKey<String>('contract_preview_back'),
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

/// 쪽 위에 대각선으로 겹쳐 그리는 반투명 표시. 쪽이 길면 세로로 여러 번 반복한다.
class _Watermark extends StatelessWidget {
  const _Watermark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        final count = (height / (width * 0.9)).round().clamp(1, 4);
        return ClipRect(
          child: Stack(
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: height * (i + 0.5) / count - width * 0.12,
                  height: width * 0.24,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        label,
                        key: ValueKey<String>('contract_preview_watermark_$i'),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: width * 0.17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: width * 0.01,
                          color: const Color(0x40D32F2F),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({
    required this.document,
    required this.signatures,
    required this.signedDate,
  });

  final ContractDocument document;
  final List<Strokes?> signatures;
  final String signedDate;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: _ink, height: 1.75, fontSize: 14);
    return DefaultTextStyle(
      style: base ?? const TextStyle(color: _ink),
      child: Container(
        key: const ValueKey<String>('contract_preview_paper'),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
        decoration: BoxDecoration(
          color: _paper,
          border: Border.all(color: _rule, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              contractTitle(document),
              key: const ValueKey<String>('contract_preview_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const _DoubleRule(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                document.contractNo.isEmpty
                    ? '계약번호  저장 시 부여'
                    : '계약번호  ${document.contractNo}',
                key: const ValueKey<String>('contract_preview_no'),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
            const SizedBox(height: 12),
            const Text('아래 당사자는 다음과 같이 레슨 계약을 체결합니다.'),
            const SizedBox(height: 14),
            _DocTable(heading: '사업자(강사)', rows: document.partyRows),
            const SizedBox(height: 10),
            _DocTable(heading: '회원', rows: document.memberRows),
            const SizedBox(height: 18),
            for (var i = 0; i < document.articles.length; i++)
              _Article(number: i + 1, article: document.articles[i]),
            if (document.exampleLines.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                '별첨  환불 계산 예시',
                key: ValueKey<String>('contract_preview_appendix'),
                style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 4),
              for (final line in document.exampleLines)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                  child: Text('· $line', textAlign: TextAlign.justify),
                ),
              const SizedBox(height: 14),
            ],
            const _DoubleRule(),
            const SizedBox(height: 16),
            const Text(
              '위 계약 내용을 확인하고 동의하여 계약을 체결합니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              signedDate.isEmpty ? '20      년      월      일' : signedDate,
              key: const ValueKey<String>('contract_preview_date'),
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < document.signatureLabels.length; i++)
              _SignatureLine(
                label: document.signatureLabels[i],
                strokes: i < signatures.length ? signatures[i] : null,
                lineKey: ValueKey<String>('contract_preview_signature_$i'),
              ),
            const SizedBox(height: 14),
            const Text(
              '※ 미리보기입니다. 서명 전의 내용이며, 문구는 법률 검토 전 초안입니다.',
              key: ValueKey<String>('contract_preview_note'),
              style: TextStyle(fontSize: 11, color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoubleRule extends StatelessWidget {
  const _DoubleRule();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 2, color: _rule),
        const SizedBox(height: 2),
        Container(height: 0.8, color: _rule),
      ],
    );
  }
}

class _DocTable extends StatelessWidget {
  const _DocTable({required this.heading, required this.rows});

  final String heading;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final border = TableBorder.all(color: _rule, width: 0.8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _shade,
            border: Border.all(color: _rule, width: 0.8),
          ),
          child: Text(
            heading,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
        ),
        Table(
          border: border,
          columnWidths: const {0: FixedColumnWidth(104), 1: FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final (label, value) in rows)
              TableRow(
                children: [
                  Container(
                    color: _shade,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(value, style: const TextStyle(color: _ink)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Article extends StatelessWidget {
  const _Article({required this.number, required this.article});

  final int number;
  final ContractDocArticle article;

  @override
  Widget build(BuildContext context) {
    final numbered = article.paragraphs.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '제$number조  ${article.heading}',
            key: ValueKey<String>('contract_preview_article_$number'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
          const SizedBox(height: 4),
          if (article.rows.isNotEmpty) _rowsTable(article.rows),
          for (var i = 0; i < article.paragraphs.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                numbered && i < _circled.length
                    ? '${_circled[i]} ${article.paragraphs[i]}'
                    : article.paragraphs[i],
                textAlign: TextAlign.justify,
              ),
            ),
        ],
      ),
    );
  }
}

/// 조항 안의 표(제목 줄 없이 항목·값만).
Widget _rowsTable(List<(String, String)> rows) {
  return Table(
    border: TableBorder.all(color: _rule, width: 0.8),
    columnWidths: const {0: FixedColumnWidth(104), 1: FlexColumnWidth()},
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [
      for (final (label, value) in rows)
        TableRow(
          children: [
            Container(
              color: _shade,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(value, style: const TextStyle(color: _ink)),
            ),
          ],
        ),
    ],
  );
}

class _SignatureLine extends StatelessWidget {
  const _SignatureLine({
    required this.label,
    required this.strokes,
    required this.lineKey,
  });

  final String label;
  final Strokes? strokes;
  final Key lineKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
          ),
          Expanded(
            child: Container(
              key: lineKey,
              height: strokes == null ? 26 : 52,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _rule, width: 0.8)),
              ),
              alignment: Alignment.centerRight,
              child:
                  strokes == null
                      ? const Text(
                        '(서명)',
                        style: TextStyle(fontSize: 12, color: _muted),
                      )
                      : SizedBox(
                        width: 140,
                        child: SignatureStrokesView(strokes: strokes!),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
