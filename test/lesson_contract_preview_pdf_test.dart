import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_preview_page.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_document.dart';

// 1x1 투명 PNG
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

ContractDocument _document() {
  final golden =
      jsonDecode(
            File(
              'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final data = Map<String, dynamic>.from(golden['basic'] as Map);
  return buildLessonContractDocument(
    form: LessonContractForm.fromContract(data),
    party: ContractParty.fromMap(
      Map<String, dynamic>.from(data['party'] as Map),
    ),
    contractNo: 'PT-2610-0001',
  );
}

void main() {
  setUpAll(() => LessonContractPreviewPage.realPdfEnabled = true);

  Future<void> pumpPreview(
    WidgetTester tester, {
    required Future<Uint8List> Function() pdfBuilder,
    required ContractPdfRasterizer rasterizer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonContractPreviewPage(
          document: _document(),
          pdfBuilder: pdfBuilder,
          rasterizer: rasterizer,
        ),
      ),
    );
  }

  testWidgets('PDF를 만드는 동안 안내를 보여 주고 끝나면 실제 PDF 쪽 이미지를 보여 준다', (tester) async {
    final done = Completer<Uint8List>();
    var rasterized = 0;
    await pumpPreview(
      tester,
      pdfBuilder: () => done.future,
      rasterizer: (pdf) async {
        rasterized += 1;
        expect(pdf, [1, 2, 3]);
        return [_png];
      },
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('contract_preview_loading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('contract_preview_paper')), findsNothing);

    done.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(rasterized, 1);
    expect(
      find.byKey(const ValueKey('contract_preview_loading')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('contract_preview_pdf')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // 예전 표 화면이 아니라 PDF가 보인다.
    expect(find.byKey(const ValueKey('contract_preview_paper')), findsNothing);
  });

  testWidgets('다크 모드에서도 흰 종이 밖 안내 글씨는 테마 글자색으로 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(onSurface: Color(0xFFF5F5F5)),
        ),
        home: LessonContractPreviewPage(
          document: _document(),
          pdfBuilder: () async => Uint8List.fromList([1]),
          rasterizer: (_) async => [_png],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final note = tester.widget<Text>(
      find.byKey(const ValueKey('contract_preview_pdf_note')),
    );
    expect(note.style?.color, const Color(0xFFF5F5F5));
  });

  testWidgets('표시 문구가 있으면 쪽마다 대각선 워터마크를 겹치고 없으면 그리지 않는다', (tester) async {
    Widget app({String watermark = ''}) => MaterialApp(
      home: LessonContractPreviewPage(
        document: _document(),
        watermark: watermark,
        pdfBuilder: () async => Uint8List.fromList([1]),
        rasterizer: (_) async => [_png, _png],
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('해지 완료'), findsNothing);

    await tester.pumpWidget(app(watermark: '해지 완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('해지 완료'), findsNWidgets(2), reason: '두 쪽 모두에 표시');
    // 터치·확대를 가로막지 않는다(IgnorePointer 안에 있다).
    final inside = find.ancestor(
      of: find.byKey(const ValueKey('contract_preview_watermark_0')).first,
      matching: find.byType(IgnorePointer),
    );
    expect(inside, findsWidgets);
    expect(find.byKey(const ValueKey('contract_preview_pdf')), findsOneWidget);
  });

  testWidgets('PDF를 못 그려 문서 화면으로 대신해도 워터마크가 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LessonContractPreviewPage(
          document: _document(),
          watermark: '해지 완료',
          pdfBuilder: () async => throw StateError('font'),
          rasterizer: (_) async => [_png],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );
    expect(find.text('해지 완료'), findsWidgets);
  });

  testWidgets('여러 쪽이면 쪽마다 이미지를 보여 준다', (tester) async {
    await pumpPreview(
      tester,
      pdfBuilder: () async => Uint8List.fromList([1]),
      rasterizer: (_) async => [_png, _png],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('PDF를 만들거나 그리지 못하면 같은 내용의 문서 화면으로 대신한다', (tester) async {
    await pumpPreview(
      tester,
      pdfBuilder: () async => throw StateError('font'),
      rasterizer: (_) async => [_png],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('contract_preview_pdf')), findsNothing);

    await pumpPreview(
      tester,
      pdfBuilder: () async => Uint8List.fromList([1]),
      rasterizer: (_) async => throw StateError('raster'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );

    await pumpPreview(
      tester,
      pdfBuilder: () async => Uint8List.fromList([1]),
      rasterizer: (_) async => const [],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('contract_preview_paper')),
      findsOneWidget,
    );
  });
}
