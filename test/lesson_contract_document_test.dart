import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_preview_page.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_document.dart';

const _party = ContractParty(
  kind: ContractPartyKind.center,
  name: '모어짐 강남',
  trainerName: '김트레이너',
  phone: '010-1234-5678',
  place: '서울 강남구 테스트로 1',
  businessNo: '123-45-67890',
);

const _form = LessonContractForm(
  memberId: 'm1',
  memberName: '홍회원',
  memberPhone: '010-9999-8888',
  memberBirthDate: '1990-05-17',
  productName: '퍼스널 트레이닝 10회',
  sessionCount: 10,
  sessionMinutes: 50,
  paidAmount: 1000000,
  vatIncluded: true,
  paymentMethod: 'card',
  periodStart: '2026-10-20',
  periodEnd: '2027-01-20',
);

String _all(ContractDocument document) => [
  for (final article in document.articles) ...[
    article.heading,
    for (final (label, value) in article.rows) '$label $value',
    ...article.paragraphs,
  ],
  ...document.exampleLines,
].join('\n');

void main() {
  setUpAll(() => LessonContractPreviewPage.realPdfEnabled = false);
  group('서비스 내용 자동 작성', () {
    test('상품명·횟수·1회 시간으로 만든다', () {
      expect(_form.serviceContent, '퍼스널 트레이닝 10회 (총 10회, 1회 50분)');
      expect(const LessonContractForm().serviceContent, '');
      expect(
        const LessonContractForm(productName: '필라테스').serviceContent,
        '필라테스',
      );
      expect(
        _form.toContent(_party)['product'],
        containsPair('serviceContent', '퍼스널 트레이닝 10회 (총 10회, 1회 50분)'),
      );
    });
  });

  group('조항 문구', () {
    test('취소와 레슨 진행 불가 기준은 제1조 한 문단에 또한으로 이어진다', () {
      final text = cancelClauseText(_form);
      expect(
        text,
        '회원은 레슨 시작 24시간 전까지 예약을 변경하거나 취소할 수 있습니다. '
        '취소 가능 시간이 지난 후에 취소하는 경우에는 레슨 1회가 차감됩니다. '
        '또한 레슨 시작시간 30분 이후는 레슨 진행이 불가하며, '
        '이 경우 불참으로 보아 레슨 1회가 차감됩니다.',
      );
      expect(text, isNot(contains('마감')));
      expect(text, isNot(contains('지각')));
      expect(text, isNot(contains('어려울 수')));
    });

    test('당일 취소 불가와 진행 불가 기준 없음 변형', () {
      final sameDay = _form.copyWith(
        cancelDeadline: const ContractCancelDeadline.sameDay(),
        clearLateNoShow: true,
      );
      expect(
        cancelClauseText(sameDay),
        '회원은 당일 예약을 변경하거나 취소할 수 없으며, 당일에 취소하는 경우에는 레슨 1회가 차감됩니다.',
      );
    });

    test('위약금과 환급 문장', () {
      expect(
        refundClauseText(_form),
        contains('위약금은 총 결제금액의 10%로 하되 10%를 초과하지 않으며'),
      );
      expect(refundClauseText(_form), endsWith('영업일 3일 이내에 처리합니다.'));
      final long = _form.copyWith(penaltyPercent: 5, refundBusinessDays: 30);
      expect(refundClauseText(long), contains('5%로'));
      expect(refundClauseText(long), endsWith('영업일 30일 이내에 처리합니다.'));
    });

    test('이용분 계산 기준과 양도 문장', () {
      expect(basisClauseText(_form), contains('1회 금액 × 받은 횟수'));
      expect(basisClauseText(_form), contains('실제 낸 금액을 총 횟수로 나눈 금액'));
      final list = _form.copyWith(listPrice: 1500000, refundByListPrice: true);
      expect(basisClauseText(list), contains('할인 전 정상가를 총 횟수로 나눈 금액'));
      expect(basisClauseText(list), contains('이용분과 위약금의 합계가 실제 낸 금액을 넘지 않습니다'));
      expect(
        refundClauseText(_form),
        contains('이미 받은 레슨의 값(이용분)과 위약금을 공제한 금액'),
      );
      expect(transferClauseText(_form), '회원권의 양도는 조건부로 하며, 양도 수수료는 없음입니다.');
      expect(
        transferClauseText(
          _form.copyWith(
            transferPolicy: ContractTransferPolicy.allowed,
            transferFeeType: ContractTransferFeeType.percent,
            transferFeeValue: 5,
          ),
        ),
        contains('5%입니다.'),
      );
      expect(
        transferClauseText(
          _form.copyWith(transferPolicy: ContractTransferPolicy.denied),
        ),
        '회원권의 양도는 불허로 하며 양도할 수 없습니다.',
      );
    });
  });

  group('문서 구성', () {
    test('계약 내용 표에 회당 금액·VAT·정상가 할인율·기간이 들어간다', () {
      final document = buildLessonContractDocument(
        form: _form.copyWith(listPrice: 1500000),
        party: _party,
        contractNo: 'PT-2610-0001',
      );
      expect(document.title, '레슨 계약서');
      expect(document.contractNo, 'PT-2610-0001');
      final rows = document.articles.first.rows;
      expect(rows, contains(('레슨명', '퍼스널 트레이닝 10회')));
      expect(rows, contains(('총 횟수', '10회')));
      expect(rows, contains(('회당 금액', '100,000원')));
      expect(rows, contains(('실결제금액', '1,000,000원 (VAT 포함)')));
      expect(rows, contains(('정상가', '1,500,000원 (33.3% 할인)')));
      expect(rows, contains(('결제 방법', '카드')));
      expect(rows, contains(('사용 가능 기간', '2026-10-20 ~ 2027-01-20')));
      expect(document.partyRows, contains(('상호(성명)', '모어짐 강남')));
      expect(document.partyRows, contains(('사업자등록번호', '123-45-67890')));
      expect(document.memberRows, contains(('생년월일', '1990-05-17')));
    });

    test('유효기간 종료일이 없는 계약: 표·소멸 문구·핵심 고지가 종료일 없음으로 바뀐다', () {
      final unlimited = _form.copyWith(
        periodEnd: '',
        periodUnlimited: true,
        expiryExtensionClause: true,
      );
      final document = buildLessonContractDocument(
        form: unlimited,
        party: _party,
      );
      expect(
        document.articles.first.rows,
        contains(('사용 가능 기간', '2026-10-20 ~ 종료일 없음')),
      );
      final text = _all(document);
      expect(text, contains(kNoExpiryText));
      expect(text, isNot(contains(kExpiryText)));
      // 종료일이 없으면 기간 연장 협의 문구도 의미가 없어 뺀다.
      expect(text, isNot(contains(kExtensionClause)));

      final validity = buildDisclosureCards(
        unlimited,
        _party,
      ).firstWhere((card) => card.id == 'validity');
      expect(validity.rows.single.$2, '2026-10-20 ~ 종료일 없음');
      expect(validity.lines, contains(kNoExpiryText));
      expect(validity.lines, isNot(contains(kExpiryText)));
      expect(validity.lines, isNot(contains(kExtensionClause)));

      // 종료일이 있는 계약은 그대로다.
      final normal = buildDisclosureCards(
        _form.copyWith(expiryExtensionClause: true),
        _party,
      ).firstWhere((card) => card.id == 'validity');
      expect(normal.lines, contains(kExpiryText));
      expect(normal.lines, contains(kExtensionClause));
    });

    test('종료일 없음은 종료일을 비운 채 검증을 통과하고 서버에는 periodUnlimited로 보낸다', () {
      final unlimited = _form.copyWith(periodEnd: '', periodUnlimited: true);
      expect(unlimited.validate().containsKey('periodEnd'), isFalse);
      final product =
          unlimited.toContent(_party)['product']! as Map<String, Object?>;
      expect(product['periodEnd'], '');
      expect(product['periodUnlimited'], true);
      // 체크하지 않은 계약은 필드를 보내지 않고 종료일이 필수다.
      final normal = _form.copyWith(periodEnd: '');
      expect(normal.validate()['periodEnd'], isNotNull);
      expect(
        (_form.toContent(_party)['product']! as Map).containsKey(
          'periodUnlimited',
        ),
        isFalse,
      );
      // 저장된 계약에서 복원해도 유지된다.
      final restored = LessonContractForm.fromContract(
        unlimited.toContent(_party),
      );
      expect(restored.periodUnlimited, isTrue);
      expect(restored.periodEnd, '');
    });

    test('비고는 입력했을 때만 서버에 보내고, 금지 문구·길이를 검사하고, 문서 칸에 들어간다', () {
      // 비고가 없으면 필드를 보내지 않는다(이전 서버·기존 계약과 같은 내용).
      expect(
        (_form.toContent(_party)['product']! as Map).containsKey('remarks'),
        isFalse,
      );
      final noted = _form.copyWith(remarks: '  11월 50만원, 12월 50만원 분할 결제  ');
      expect(noted.validate().containsKey('remarks'), isFalse);
      expect(
        (noted.toContent(_party)['product']! as Map)['remarks'],
        '11월 50만원, 12월 50만원 분할 결제',
      );
      // 저장된 계약에서 복원해도 유지된다.
      expect(
        LessonContractForm.fromContract(noted.toContent(_party)).remarks,
        '11월 50만원, 12월 50만원 분할 결제',
      );
      // 특약과 같은 금지 문구 검사를 받아 비고로 우회할 수 없다.
      expect(_form.copyWith(remarks: '환불불가').validate()['remarks'], isNotNull);
      expect(
        _form
            .copyWith(remarks: '가' * (kContractMaxRemarksLength + 1))
            .validate()['remarks'],
        isNotNull,
      );
      // 문서 `제1조` 표에 비고가 들어가고, 없으면 줄이 없다.
      final rows =
          buildLessonContractDocument(
            form: noted,
            party: _party,
          ).articles.first.rows;
      expect(rows, contains(('비고', '11월 50만원, 12월 50만원 분할 결제')));
      expect(
        buildLessonContractDocument(
          form: _form,
          party: _party,
        ).articles.first.rows.any((r) => r.$1 == '비고'),
        isFalse,
      );
      // 추가 특약은 비고와 별개로 조항에 남는다.
      final both = noted.copyWith(extraTerms: '샤워실 이용은 별도 안내');
      final doc = buildLessonContractDocument(form: both, party: _party);
      expect(doc.articles.any((a) => a.heading == '특약'), isTrue);
    });

    test('필수 조항이 모두 있고 환불불가·전면 면책 문구는 없다', () {
      final document = buildLessonContractDocument(form: _form, party: _party);
      final headings = document.articles.map((a) => a.heading).toList();
      expect(
        headings,
        containsAll([
          '계약의 내용',
          '예약 변경 및 취소',
          '강사 사정에 의한 취소',
          '유효기간과 소멸',
          '위약금 및 환불',
          '이용분 계산 기준',
          '양도',
          '강사 변경',
          '건강 상태 확인과 안전',
          '개인정보의 수집 및 이용',
          '계약의 변경',
          '분쟁의 해결',
        ]),
      );
      final text = _all(document);
      expect(text, contains('유효기간 종료일이 지나면 남은 횟수는 소멸합니다.'));
      expect(text, contains('카드수수료는 공제하지 않습니다.'));
      expect(text, contains('1372'));
      expect(text, isNot(contains('환불불가')));
      expect(text, isNot(contains('환불은 불가')));
      expect(text, isNot(contains('어려울 수')));
      expect(text, isNot(contains('모든 사고')));
      expect(text, isNot(contains('재판관할')));
      // 강사 귀책이 있으면 책임을 진다는 균형 문구가 있다.
      expect(text, contains('강사에게 귀책 사유가 있는 범위에서는 책임을 집니다'));
    });

    test('선택 조항과 특약은 선택했을 때만 나온다', () {
      final plain = _all(
        buildLessonContractDocument(
          form: _form.copyWith(
            expiryExtensionClause: false,
            unavoidableRefundClause: false,
          ),
          party: _party,
        ),
      );
      expect(plain, isNot(contains('유효기간의 연장을 협의합니다')));
      expect(plain, isNot(contains('위약금을 면제하고 이용분만 공제합니다')));
      expect(plain, isNot(contains('특약')));

      final withAll = buildLessonContractDocument(
        form: _form.copyWith(
          expiryExtensionClause: true,
          unavoidableRefundClause: true,
          extraTerms: '센터 샤워실은 별도 안내에 따릅니다.',
        ),
        party: _party,
      );
      final text = _all(withAll);
      expect(text, contains('유효기간의 연장을 협의합니다'));
      expect(text, contains('위약금을 면제하고 이용분만 공제합니다'));
      expect(withAll.articles.last.heading, '특약');
      expect(withAll.articles.last.paragraphs, ['센터 샤워실은 별도 안내에 따릅니다.']);
    });

    test('환불 계산 예시는 입력값으로 계산된다', () {
      final document = buildLessonContractDocument(form: _form, party: _party);
      expect(document.exampleLines.first, contains('결제 1,000,000원, 총 10회'));
      expect(document.exampleLines.join('\n'), contains('환불 900,000원'));
      expect(document.exampleLines.join('\n'), contains('환불 600,000원'));

      final byList = buildLessonContractDocument(
        form: _form.copyWith(listPrice: 1500000, refundByListPrice: true),
        party: _party,
      );
      expect(byList.exampleLines.join('\n'), contains('환불 450,000원'));

      final empty = buildLessonContractDocument(
        form: const LessonContractForm(),
        party: _party,
      );
      expect(empty.exampleLines, isEmpty);
      expect(empty.articles.first.rows.first, ('레슨명', '-'));
    });
  });

  group('미리보기 화면', () {
    Future<void> pump(WidgetTester tester, {String contractNo = ''}) async {
      tester.view.physicalSize = const Size(800, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: LessonContractPreviewPage(
            document: buildLessonContractDocument(
              form: _form,
              party: _party,
              contractNo: contractNo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('문서 양식으로 제목·당사자·조항·별첨·서명란이 보인다', (tester) async {
      await pump(tester, contractNo: 'PT-2610-0001');
      expect(
        find.byKey(const ValueKey('contract_preview_title')),
        findsOneWidget,
      );
      expect(find.text('모어짐 강남 레슨 계약서'), findsOneWidget);
      expect(find.text('계약번호  PT-2610-0001'), findsOneWidget);
      expect(find.text('사업자(강사)'), findsOneWidget);
      expect(find.text('회원'), findsOneWidget);
      expect(find.text('모어짐 강남'), findsOneWidget);
      expect(find.text('제1조  계약의 내용'), findsOneWidget);
      expect(find.text('제2조  예약 변경 및 취소'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contract_preview_appendix')),
        findsOneWidget,
      );
      expect(find.text('회원 서명 (핵심 고지 확인)'), findsOneWidget);
      expect(find.text('회원 서명 (계약 전체 동의)'), findsOneWidget);
      expect(find.text('강사 서명'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contract_preview_note')),
        findsOneWidget,
      );
    });

    testWidgets('저장 전에는 계약번호가 저장 시 부여된다고 표시한다', (tester) async {
      await pump(tester);
      expect(find.text('계약번호  저장 시 부여'), findsOneWidget);
    });

    testWidgets('다크 모드에서도 종이는 흰 바탕에 검은 글씨다', (tester) async {
      await pump(tester);
      final paper = tester.widget<Container>(
        find.byKey(const ValueKey('contract_preview_paper')),
      );
      final decoration = paper.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('contract_preview_title')),
      );
      expect(title.style!.color, const Color(0xFF111111));
    });
  });
}
