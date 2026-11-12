import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_form_page.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_preview_page.dart';
import 'package:mtf_app/services/managed_member_workspace_service.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/utils/lesson_contract/lesson_contract_rules.dart';

const _party = ContractParty(
  kind: ContractPartyKind.individual,
  name: '김트레이너',
  trainerName: '김트레이너',
  phone: '010-1234-5678',
  place: '서울 강남구 테스트로 1',
);

LessonContractForm _validForm() => const LessonContractForm(
  memberId: 'm1',
  memberName: '홍회원',
  memberPhone: '010-9999-8888',
  productName: 'PT 10회',
  sessionCount: 10,
  sessionMinutes: 50,
  paidAmount: 1000000,
  paymentMethod: 'card',
  paymentDate: '2026-10-20',
  periodStart: '2026-10-20',
  periodEnd: '2027-01-20',
);

class _FakeGateway extends PersonalContractGateway {
  _FakeGateway({this.settings, this.contract, this.failSave = false})
    : super(callable: (name, parameters) async => throw UnimplementedError());

  final ContractSettings? settings;
  final Map<String, dynamic>? contract;
  final bool failSave;
  final Map<String, Map<String, dynamic>> cards = const {
    'm1': {'name': '홍회원', 'phone': '010-9999-8888', 'birthDate': '1990-05-17'},
    'm2': {'name': '김다른', 'phone': '', 'birthDate': ''},
  };
  final List<Map<String, Object?>> drafts = [];
  final List<List<ContractProductPreset>> savedProducts = [];

  @override
  Future<Map<String, dynamic>?> loadMemberCard(String memberId) async =>
      cards[memberId];

  @override
  Future<void> saveSettings({
    ContractParty? party,
    ContractDefaults? defaults,
    List<ContractProductPreset>? products,
  }) async {
    if (products != null) savedProducts.add(products);
  }

  @override
  Future<ContractSettings> loadSettings(String uid) async =>
      settings ?? const ContractSettings();

  @override
  Future<Map<String, dynamic>?> loadContract(String contractId) async =>
      contract;

  @override
  Future<ContractDraftResult> saveDraft({
    String? idempotencyKey,
    String? contractId,
    required String memberId,
    required Map<String, Object?> content,
  }) async {
    if (failSave) throw StateError('boom');
    drafts.add({
      'idempotencyKey': idempotencyKey,
      'contractId': contractId,
      'memberId': memberId,
      'content': content,
    });
    return ContractDraftResult(
      contractId: contractId ?? 'pc_${'a' * 32}',
      contractNo: 'PT-2610-0001',
      version: 1,
      status: 'draft',
      contentHash: 'h' * 64,
      created: contractId == null,
    );
  }
}

const _readySettings = ContractSettings(party: _party);

Stream<List<ManagedMemberSummary>> _members() => Stream.value(const [
  ManagedMemberSummary(
    memberId: 'm1',
    name: '홍회원',
    phone: '010-9999-8888',
    managementState: 'active',
  ),
  ManagedMemberSummary(
    memberId: 'm2',
    name: '김다른',
    phone: '',
    managementState: 'active',
  ),
]);

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
  await tester.pump(const Duration(seconds: 8));
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeGateway gateway, {
  String? contractId,
}) async {
  tester.view.physicalSize = const Size(800, 10000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: LessonContractFormPage(
        personalOwnerUid: 'trainer-a',
        contractId: contractId,
        gateway: gateway,
        membersStream: _members,
        clock: () => DateTime(2026, 10, 20, 15),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey<String>(key)), text);
  await tester.pump();
}

/// 키보드 위 빠른 선택 막대는 가로로 밀리므로, 눌러야 할 칩을 보이게 한 뒤 누른다.
Future<void> _tapQuick(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester
        .widget<TextField>(find.byKey(ValueKey<String>(key)))
        .controller!
        .text;

Future<void> _openRefundExample(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('refund_example_toggle')));
  await tester.pumpAndSettle();
}

Future<void> _pickEndPlus3(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('contract_form_end_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('contract_form_end_plus_3')));
  await tester.pumpAndSettle();
}

/// 빈칸을 눌러 포커스를 주면 키보드 위 빠른 선택 막대가 나타난다.
Future<void> _focusBlank(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pumpAndSettle();
  // 환급 영업일 칸을 누르면 안내 토스트가 뜬다. 남은 타이머가 없도록 비운다.
  if (key.contains('refund')) await _flushToast(tester);
}

Future<void> _fillBasics(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('contract_form_pick_member')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('contract_member_m1')));
  await tester.pumpAndSettle();
  await _type(tester, 'contract_form_product_name', 'PT 10회');
  await _type(tester, 'contract_form_session_count', '10');
  await _type(tester, 'contract_form_paid_amount', '1000000');
  await _pickEndPlus3(tester);
  await tester.pump();
}

void main() {
  setUpAll(() => LessonContractPreviewPage.realPdfEnabled = false);
  group('문구 가드 (서버와 같은 사례)', () {
    test('환불을 막거나 책임을 면제하는 문구는 걸러진다', () {
      for (final bad in [
        '환불 불가',
        '환불불가 상품',
        '단순 변심 환불 안 됨',
        '카드 수수료 공제 후 환불',
        '환불 신청 7일 이내',
        '재판관할은 서울중앙지방법원',
        '모든 사고에 대해 책임을 지지 않음',
        '구두 약정은 효력이 없다',
        '환불은 불가합니다',
      ]) {
        expect(findForbiddenPhrase(bad), isNotNull, reason: bad);
      }
    });

    test('정상 문구는 통과한다', () {
      for (final ok in [
        '1:1 개인 트레이닝 50분',
        '환불은 신청일부터 3영업일 이내 처리합니다',
        '수업은 센터 2층에서 진행합니다',
        '',
      ]) {
        expect(findForbiddenPhrase(ok), isNull, reason: ok);
      }
    });
  });

  group('환불 계산 (서버와 같은 결과)', () {
    RefundResult calc(
      RefundKind kind, {
      int used = 3,
      bool list = false,
      int penalty = 10,
    }) => computeRefund(
      kind: kind,
      paidAmount: 1000000,
      sessionCount: 10,
      usedSessions: used,
      listPrice: 1500000,
      listPriceBasis: list,
      penaltyPercent: penalty,
    );

    test('명세서 예시: 계약 단가 60만 · 정상가 45만 · 첫 수업 전 90만', () {
      expect(calc(RefundKind.memberReason).refund, 600000);
      expect(calc(RefundKind.memberReason, list: true).refund, 450000);
      expect(calc(RefundKind.beforeFirstLesson, used: 0).refund, 900000);
    });

    test('소진분 + 위약금이 결제금액을 넘으면 0원이고 음수가 없다', () {
      expect(calc(RefundKind.memberReason, used: 7, list: true).refund, 0);
    });

    test('강사 귀책은 위약금 없이 잔여 × 계약 단가, 불가피 사유는 위약금 면제', () {
      final provider = calc(RefundKind.providerFault, list: true);
      expect(provider.penalty, 0);
      expect(provider.refund, 700000);
      expect(calc(RefundKind.unavoidable).refund, 700000);
    });

    test('위약금 상한을 넘기면 계산하지 않는다', () {
      expect(
        () => calc(RefundKind.memberReason, penalty: 11),
        throwsArgumentError,
      );
    });

    test('예시 소진 횟수와 원화 표기', () {
      expect(refundExampleUsedSessions(1), 0);
      expect(refundExampleUsedSessions(2), 1);
      expect(refundExampleUsedSessions(10), 3);
      expect(refundExampleUsedSessions(200), 60);
      expect(formatWon(1000000), '1,000,000');
      expect(formatWon(999), '999');
      expect(formatWon(0), '0');
    });

    test('종료일 빠른 선택은 말일을 넘기지 않는다', () {
      expect(
        addContractMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        addContractMonths(DateTime(2026, 10, 20), 3),
        DateTime(2027, 1, 20),
      );
      expect(
        addContractMonths(DateTime(2026, 12, 15), 2),
        DateTime(2027, 2, 15),
      );
    });
  });

  group('LessonContractForm', () {
    test('비어 있는 새 입력은 필수 칸마다 오류가 나온다', () {
      final errors =
          LessonContractForm.fromDefaults(
            ContractDefaults.standard,
            today: DateTime(2026, 10, 20),
          ).validate();
      expect(
        errors.keys.toSet(),
        containsAll([
          'member',
          'memberName',
          'memberPhone',
          'productName',
          'sessionCount',
          'paidAmount',
          'periodEnd',
        ]),
      );
      expect(errors.containsKey('periodStart'), isFalse);
    });

    test('올바른 입력은 오류가 없고 기본안과 같다', () {
      final form = _validForm();
      expect(form.validate(), isEmpty);
      expect(form.differencesFromStandard(), isEmpty);
      expect(form.unitPrice, 100000);
    });

    test('서버 상한: 위약금·환급 기한·기간·정상가·수수료', () {
      expect(
        _validForm().copyWith(penaltyPercent: 11).validate().keys,
        contains('penaltyPercent'),
      );
      expect(
        _validForm().copyWith(refundBusinessDays: 131).validate().keys,
        contains('refundBusinessDays'),
      );
      expect(
        _validForm().copyWith(periodEnd: '2026-10-19').validate().keys,
        contains('periodEnd'),
      );
      expect(
        _validForm().copyWith(periodEnd: '2031-01-01').validate().keys,
        contains('periodEnd'),
      );
      expect(
        _validForm().copyWith(listPrice: 900000).validate().keys,
        contains('listPrice'),
      );
      expect(
        _validForm().copyWith(refundByListPrice: true).validate().keys,
        contains('refundBasis'),
      );
      expect(
        _validForm()
            .copyWith(
              transferFeeType: ContractTransferFeeType.amount,
              transferFeeValue: 200000,
            )
            .validate()
            .keys,
        contains('transferFee'),
      );
      expect(
        _validForm()
            .copyWith(
              transferFeeType: ContractTransferFeeType.amount,
              transferFeeValue: 100000,
            )
            .validate(),
        isEmpty,
      );
    });

    test('금지 문구는 상품명·서비스 내용·추가 특약에서 막힌다', () {
      expect(
        _validForm().copyWith(extraTerms: '환불불가').validate()['extraTerms'],
        contains('환불'),
      );
      expect(
        _validForm().copyWith(productName: '환불 불가 상품').validate().keys,
        contains('productName'),
      );
    });

    test('기본안과 다른 항목이 표시된다', () {
      final form = _validForm().copyWith(
        cancelDeadline: const ContractCancelDeadline.sameDay(),
        penaltyPercent: 5,
        listPrice: 1500000,
        refundByListPrice: true,
        extraTerms: '특약',
      );
      expect(
        form.differencesFromStandard(),
        containsAll(['취소 마감 시간', '위약금', '정상가 기준 환불', '추가 특약']),
      );
    });

    test('서버 전송 형식은 공유 골든 파일과 같다', () {
      final golden =
          jsonDecode(
                File(
                  'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(
        jsonDecode(jsonEncode(_validForm().toContent(_party))),
        golden['basic'],
      );

      const fullParty = ContractParty(
        kind: ContractPartyKind.center,
        name: '모어짐 강남',
        trainerName: '김트레이너',
        phone: '010-1234-5678',
        place: '서울 강남구 테스트로 1',
        businessNo: '123-45-67890',
        logoPath: 'contract_logos/trainer-a/logo_1700000000000.png',
      );
      const full = LessonContractForm(
        memberId: 'm1',
        memberName: '홍회원',
        memberPhone: '010-9999-8888',
        memberBirthDate: '1990-05-17',
        memberEmail: 'member@example.com',
        productName: 'PT 20회',
        sessionCount: 20,
        sessionMinutes: 60,
        paidAmount: 1800000,
        vatIncluded: true,
        listPrice: 2400000,
        paymentMethod: 'transfer',
        paymentDate: '2026-10-21',
        periodStart: '2026-10-21',
        periodEnd: '2027-04-21',
        cancelDeadline: ContractCancelDeadline.sameDay(),
        lateNoShowMinutes: 15,
        penaltyPercent: 5,
        refundBusinessDays: 2,
        refundByListPrice: true,
        transferPolicy: ContractTransferPolicy.allowed,
        transferFeeType: ContractTransferFeeType.amount,
        transferFeeValue: 50000,
        expiryExtensionClause: false,
        unavoidableRefundClause: true,
        extraTerms: '센터 샤워실 이용은 별도 안내에 따릅니다.',
      );
      expect(full.validate(), isEmpty);
      expect(jsonDecode(jsonEncode(full.toContent(fullParty))), golden['full']);
    });

    test('저장된 계약 문서에서 같은 입력으로 복원된다', () {
      final golden =
          jsonDecode(
                File(
                  'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final full = Map<String, dynamic>.from(golden['full'] as Map);
      final restored = LessonContractForm.fromContract({
        ...full,
        'memberId': 'm1',
      });
      expect(restored.validate(), isEmpty);
      expect(restored.usesListPriceBasis, isTrue);
      expect(restored.transferFeeType, ContractTransferFeeType.amount);
      expect(restored.cancelDeadline.sameDay, isTrue);
      expect(
        jsonDecode(jsonEncode(restored.toContent(_party))),
        isNot(equals(full)),
        reason: '당사자는 설정 값으로 다시 채워진다',
      );
    });
  });

  group('LessonContractFormPage', () {
    testWidgets('당사자 정보가 없으면 설정 안내가 나오고 저장되지 않는다', (tester) async {
      final gateway = _FakeGateway();
      await _pumpPage(tester, gateway);
      expect(
        find.byKey(const ValueKey('contract_form_party_missing')),
        findsOneWidget,
      );
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, isEmpty);
    });

    testWidgets('회원을 고르고 입력하면 서버 형식으로 초안을 저장한다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      // 계약 당사자 카드는 접혀 있고, 제목에 당사자 종류가 들어간다.
      expect(find.text('계약 당사자 (강사 개인)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contract_form_party_summary')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('contract_form_party_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_party_summary')),
        findsOneWidget,
      );
      await _fillBasics(tester);

      expect(_text(tester, 'contract_form_per_session'), '100,000');
      expect(_text(tester, 'contract_form_paid_amount'), '1,000,000');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);

      expect(gateway.drafts, hasLength(1));
      final draft = gateway.drafts.single;
      expect(draft['memberId'], 'm1');
      expect(draft['contractId'], isNull);
      expect(draft['idempotencyKey'], isNotNull);
      final content = draft['content']! as Map<String, Object?>;
      final product = content['product']! as Map;
      expect(product['paidAmount'], 1000000);
      expect(product['periodStart'], '2026-10-20');
      expect(product['periodEnd'], '2027-01-20');
      final terms = content['terms']! as Map;
      expect(terms['refundBasis'], 'contract_unit');
      expect(terms['penaltyPercent'], 10);
      // 저장 뒤 계약번호가 머리말에 표시된다.
      expect(find.text('PT-2610-0001'), findsOneWidget);
    });

    testWidgets('한 번 저장한 뒤 다시 저장하면 새로 만들지 않고 같은 계약을 고친다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      await _type(tester, 'contract_form_paid_amount', '900000');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);

      expect(gateway.drafts, hasLength(2));
      expect(gateway.drafts[0]['idempotencyKey'], isNotNull);
      expect(gateway.drafts[1]['idempotencyKey'], isNull);
      expect(gateway.drafts[1]['contractId'], 'pc_${'a' * 32}');
    });

    testWidgets('필수 칸이 비어 있으면 저장하지 않고 오류를 보여 준다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, isEmpty);
      expect(find.text('회원을 선택해 주세요.'), findsOneWidget);
      expect(find.text('레슨명을 1~40자로 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('금액과 횟수를 입력하면 환불 계산 예시가 나온다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.byKey(const ValueKey('refund_example_card')), findsNothing);
      await _openRefundExample(tester);
      expect(
        find.byKey(const ValueKey('refund_example_empty')),
        findsOneWidget,
      );
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      expect(find.textContaining('환불 900,000원'), findsOneWidget);
      expect(find.textContaining('환불 600,000원'), findsOneWidget);
    });

    testWidgets('정상가를 입력하면 정상가 기준을 고를 수 있고 예시와 전송 값이 바뀐다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      expect(
        find.byKey(const ValueKey('form_refund_by_list_price')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await _type(tester, 'contract_form_list_price', '1500000');
      await tester.tap(find.byKey(const ValueKey('form_refund_by_list_price')));
      await tester.pump();

      await _openRefundExample(tester);
      expect(find.textContaining('환불 450,000원'), findsOneWidget);
      expect(find.textContaining('정상가 기준 환불'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final content = gateway.drafts.single['content']! as Map<String, Object?>;
      expect((content['terms']! as Map)['refundBasis'], 'list_price');
      expect((content['product']! as Map)['listPrice'], 1500000);
    });

    testWidgets('이용분 계산 기준은 할인가(기본)와 정상가 중 하나만 고를 수 있다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await _type(tester, 'contract_form_list_price', '1500000');

      bool checked(String key) =>
          tester.widget<CheckboxListTile>(find.byKey(ValueKey(key))).value ??
          false;
      // 기본은 할인가 기준.
      expect(checked('form_refund_by_discount'), isTrue);
      expect(checked('form_refund_by_list_price'), isFalse);
      expect(find.text('할인가 ÷ 총 레슨 진행 횟수'), findsOneWidget);
      expect(find.text('할인 전 정상가 ÷ 총 레슨 진행 횟수'), findsOneWidget);
      expect(find.text('※ 이용분과 위약금의 합계는 낸 금액을 넘지 않습니다.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('form_refund_by_list_price')));
      await tester.pump();
      expect(checked('form_refund_by_discount'), isFalse);
      expect(checked('form_refund_by_list_price'), isTrue);
      // 이미 고른 줄을 다시 눌러도 둘 다 꺼지지 않는다.
      await tester.tap(find.byKey(const ValueKey('form_refund_by_list_price')));
      await tester.pump();
      expect(checked('form_refund_by_list_price'), isTrue);

      await tester.tap(find.byKey(const ValueKey('form_refund_by_discount')));
      await tester.pump();
      expect(checked('form_refund_by_discount'), isTrue);
      expect(checked('form_refund_by_list_price'), isFalse);
    });

    testWidgets('정상가를 지우면 정상가 기준도 함께 꺼진다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await _type(tester, 'contract_form_list_price', '1500000');
      await tester.tap(find.byKey(const ValueKey('form_refund_by_list_price')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final content = gateway.drafts.single['content']! as Map<String, Object?>;
      expect((content['terms']! as Map)['refundBasis'], 'contract_unit');
      expect((content['product']! as Map)['listPrice'], isNull);
    });

    testWidgets('추가 특약에 금지 문구가 있으면 저장을 막는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await _type(tester, 'form_extra_terms', '단순 변심 환불 불가');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, isEmpty);
      expect(find.text('환불을 막거나 제한하는 문구는 쓸 수 없어요.'), findsOneWidget);
    });

    testWidgets('조건을 바꾸면 기본안과 다른 항목이 표시된다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.byKey(const ValueKey('form_differences')), findsNothing);
      await _focusBlank(tester, 'form_deadline_hours');
      await _tapQuick(tester, 'form_deadline_3');
      await tester.pump();
      await _focusBlank(tester, 'form_refund_days_value');
      await _tapQuick(tester, 'form_refund_days_1');
      await tester.pump();
      expect(find.byKey(const ValueKey('form_differences')), findsOneWidget);
      expect(find.textContaining('취소 마감 시간'), findsWidgets);
      expect(find.textContaining('환급 처리 기한'), findsWidgets);
    });

    testWidgets('저장된 초안을 열면 값이 채워지고 같은 계약을 고친다', (tester) async {
      final golden =
          jsonDecode(
                File(
                  'firebase-emulator-tests/fixtures/lesson_contract_content_golden.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final basic = Map<String, dynamic>.from(golden['basic'] as Map);
      final gateway = _FakeGateway(
        settings: _readySettings,
        contract: {
          ...basic,
          'memberId': 'm1',
          'contractNo': 'PT-2610-0007',
          'version': 2,
          'status': 'draft',
        },
      );
      await _pumpPage(tester, gateway, contractId: 'pc_${'b' * 32}');
      expect(find.text('PT-2610-0007-v2'), findsOneWidget);
      expect(find.text('PT 10회'), findsWidgets);
      // 이어쓰기에서는 회원을 바꿀 수 없다.
      final field = tester.widget<InkWell>(
        find.byKey(const ValueKey('contract_form_pick_member')),
      );
      expect(field.onTap, isNull);

      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts.single['contractId'], 'pc_${'b' * 32}');
      expect(gateway.drafts.single['idempotencyKey'], isNull);
    });

    testWidgets('저장하지 않은 내용이 있을 때 뒤로 가면 확인창이 나온다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _type(tester, 'contract_form_product_name', 'PT 10회');
      await tester.tap(find.byKey(const ValueKey('contract_form_back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_leave_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_leave_stay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contract_form_save')), findsOneWidget);
    });

    testWidgets('초안 저장은 머리말 저장 버튼 하나이고, 아래에는 회원 서명 받기만 있다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      // 머리말(스크롤하지 않아도 보이는 곳)에 저장이 있다.
      final save = find.byKey(const ValueKey('contract_form_save'));
      expect(save, findsOneWidget);
      expect(
        find.descendant(of: save, matching: find.text('저장')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(save).dy, lessThan(200));
      // 아래의 큰 버튼은 회원 서명 받기 하나뿐이다.
      expect(find.text('초안 저장'), findsNothing);
      expect(
        find.byKey(const ValueKey('contract_form_start_signing')),
        findsOneWidget,
      );
      expect(find.text('저장하고 회원 서명 받기'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('contract_form_start_signing')),
            )
            .runtimeType
            .toString(),
        contains('FilledButton'),
      );
    });

    testWidgets('나가기 확인창에서 저장하고 나가기를 고르면 저장한 뒤 나가고, 실패하면 남는다', (tester) async {
      tester.view.physicalSize = const Size(800, 10000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> open(_FakeGateway gateway) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        key: const ValueKey('open_form'),
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => LessonContractFormPage(
                                      personalOwnerUid: 'trainer-a',
                                      gateway: gateway,
                                      membersStream: _members,
                                      clock: () => DateTime(2026, 10, 20, 15),
                                    ),
                              ),
                            ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open_form')));
        await tester.pumpAndSettle();
      }

      final ok = _FakeGateway(settings: _readySettings);
      await open(ok);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_leave_save')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_leave_save')));
      await tester.pumpAndSettle();
      expect(ok.drafts, hasLength(1), reason: '저장하고');
      expect(
        find.byKey(const ValueKey('contract_form_save')),
        findsNothing,
        reason: '나갔다',
      );
      expect(find.byKey(const ValueKey('open_form')), findsOneWidget);

      // 저장이 실패하면(여기서는 서버 오류) 나가지 않고 입력 화면에 남는다.
      final bad = _FakeGateway(settings: _readySettings, failSave: true);
      await open(bad);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_leave_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(bad.drafts, isEmpty);
      expect(find.byKey(const ValueKey('contract_form_save')), findsOneWidget);
    });

    testWidgets('저장 실패 시 화면에 남고 다시 저장할 수 있다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings, failSave: true);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(find.byKey(const ValueKey('contract_form_save')), findsOneWidget);
      expect(gateway.drafts, isEmpty);
    });

    testWidgets('다크 모드 320dp 폭에서도 넘침 없이 그려진다', (tester) async {
      tester.view.physicalSize = const Size(640, 12000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: LessonContractFormPage(
            personalOwnerUid: 'trainer-a',
            gateway: _FakeGateway(settings: _readySettings),
            membersStream: _members,
            clock: () => DateTime(2026, 10, 20),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await _type(tester, 'contract_form_list_price', '1500000');
      await tester.tap(find.byKey(const ValueKey('form_refund_by_list_price')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('refund_example_toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('refund_example_card')), findsOneWidget);
    });

    testWidgets('회원을 고르면 고객카드의 이름·연락처·생년월일을 가져오고 직접 고치지 못한다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      expect(
        find.byKey(const ValueKey('contract_form_member_card')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('contract_form_member_phone')),
            )
            .data,
        '010-9999-8888',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('contract_form_member_birth')),
            )
            .data,
        '1990-05-17',
      );
      // 이름·연락처·생년월일은 입력 칸이 아니라 읽기 전용 표시다.
      expect(
        find.byKey(const ValueKey('contract_form_member_email')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final member =
          (gateway.drafts.single['content']! as Map<String, Object?>)['member']!
              as Map;
      expect(member['name'], '홍회원');
      expect(member['phone'], '010-9999-8888');
      expect(member['birthDate'], '1990-05-17');
      expect(member['email'], '');
    });

    testWidgets('고객카드에 연락처가 없으면 저장을 막고 회원카드에서 입력하라고 알린다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_pick_member')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_member_m2')));
      await tester.pumpAndSettle();
      await _type(tester, 'contract_form_product_name', 'PT 10회');
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      await _pickEndPlus3(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, isEmpty);
      expect(
        find.byKey(const ValueKey('contract_form_member_card_error')),
        findsOneWidget,
      );
    });

    testWidgets('이메일은 필수가 아니라서 비워도 저장된다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, hasLength(1));
    });

    testWidgets('기간 칸 이름은 사용 시작일·유효기간 종료일이다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.text('사용 가능 기간'), findsOneWidget);
      expect(find.text('사용 시작일'), findsOneWidget);
      expect(find.text('유효기간 종료일'), findsOneWidget);
      expect(find.text('유효 종료일'), findsNothing);
      expect(find.text('계약 종료일'), findsNothing);
    });

    testWidgets('필수 칸이 비면 그 칸으로 이동하고 토스트로 알린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _FakeGateway(settings: _readySettings);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractFormPage(
            personalOwnerUid: 'trainer-a',
            gateway: gateway,
            membersStream: _members,
            clock: () => DateTime(2026, 10, 20),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_pick_member')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_member_m1')));
      await tester.pumpAndSettle();
      await _type(tester, 'contract_form_product_name', 'PT 10회');
      await _type(tester, 'contract_form_session_count', '10');
      // 금액과 유효 종료일이 비어 있다. 저장 버튼은 화면 아래에 있다.
      final save = find.byKey(const ValueKey('contract_form_save'));
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(gateway.drafts, isEmpty);
      final paid = find.byKey(const ValueKey('contract_form_paid_amount'));
      final top = tester.getTopLeft(paid).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(800));
      await _flushToast(tester);
    });

    testWidgets('내 수업 상품 불러오기: 저장된 상품을 고르면 상품 칸이 채워진다', (tester) async {
      final gateway = _FakeGateway(
        settings: const ContractSettings(
          party: _party,
          products: [
            ContractProductPreset(
              name: 'PT 20회',
              serviceContent: '1:1 개인 트레이닝 60분',
              sessionCount: 20,
              sessionMinutes: 60,
              paidAmount: 1800000,
              listPrice: 2400000,
            ),
          ],
        ),
      );
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_load_preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_preset_PT 20회')));
      await tester.pumpAndSettle();
      expect(find.text('PT 20회'), findsWidgets);
      expect(_text(tester, 'contract_form_paid_amount'), '1,800,000');
      expect(_text(tester, 'contract_form_list_price'), '2,400,000');
      expect(
        find.byKey(const ValueKey('contract_form_list_price')),
        findsOneWidget,
      );
      expect(_text(tester, 'contract_form_per_session'), '90,000');
    });

    testWidgets('저장된 상품이 없으면 저장 방법을 안내한다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_load_preset')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_preset_empty')),
        findsOneWidget,
      );
    });

    testWidgets('저장된 상품이 없을 때 시트는 화면의 절반보다 낮게 열린다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_load_preset')));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(
        find.ancestor(
          of: find.byKey(const ValueKey('contract_preset_empty')),
          matching: find.byType(BottomSheet),
        ),
      );
      expect(sheet.height, lessThan(tester.view.physicalSize.height / 2));
    });

    testWidgets('정상가와 회당 정상가는 한쪽을 쓰면 다른 쪽이 횟수로 계산된다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester); // 10회
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();

      await _type(tester, 'contract_form_list_price', '1500000');
      expect(_text(tester, 'contract_form_list_per_session'), '150,000');

      await _type(tester, 'contract_form_list_per_session', '160000');
      expect(_text(tester, 'contract_form_list_price'), '1,600,000');

      // 횟수를 바꾸면 마지막에 쓴 칸(회당 정상가)을 기준으로 정상가가 다시 맞춰진다.
      await _type(tester, 'contract_form_session_count', '20');
      expect(_text(tester, 'contract_form_list_price'), '3,200,000');
      expect(_text(tester, 'contract_form_list_per_session'), '160,000');
    });

    testWidgets('입력한 상품을 내 수업 상품으로 저장하고 같은 이름은 바꾼다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _type(tester, 'contract_form_product_name', 'PT 10회');
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      await tester.tap(find.byKey(const ValueKey('contract_form_save_preset')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.savedProducts, hasLength(1));
      expect(gateway.savedProducts.single.single.name, 'PT 10회');
      expect(gateway.savedProducts.single.single.paidAmount, 1000000);

      // 내용이 그대로면 다시 저장하지 않고 이미 저장됐다고 알려 준다.
      await tester.tap(find.byKey(const ValueKey('contract_form_save_preset')));
      await tester.pumpAndSettle();
      expect(find.text('이미 저장된 상품입니다.'), findsOneWidget);
      expect(
        find.byKey(const Key('contract_preset_replace_dialog')),
        findsNothing,
      );
      await _flushToast(tester);
      expect(gateway.savedProducts, hasLength(1));

      // 내용을 바꾸면 바로 덮어쓰지 않고 묻는다. 취소하면 저장하지 않는다.
      await _type(tester, 'contract_form_paid_amount', '900000');
      await tester.tap(find.byKey(const ValueKey('contract_form_save_preset')));
      await tester.pumpAndSettle();
      expect(find.text('새 내용으로 저장할까요?'), findsOneWidget);
      expect(gateway.savedProducts, hasLength(1));
      await tester.tap(find.byKey(const Key('contract_preset_replace_cancel')));
      await tester.pumpAndSettle();
      expect(gateway.savedProducts, hasLength(1));

      // 저장을 고르면 같은 이름의 상품이 새 내용으로 바뀐다.
      await tester.tap(find.byKey(const ValueKey('contract_form_save_preset')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('contract_preset_replace_confirm')),
      );
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.savedProducts, hasLength(2));
      expect(gateway.savedProducts.last, hasLength(1));
      expect(gateway.savedProducts.last.single.paidAmount, 900000);
    });

    testWidgets('상품 정보가 모자라면 내 수업 상품으로 저장하지 않는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_save_preset')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.savedProducts, isEmpty);
    });

    testWidgets('상품 불러오기 시트에는 삭제 버튼이 없고 수정·삭제 위치를 안내한다', (tester) async {
      final gateway = _FakeGateway(
        settings: const ContractSettings(
          party: _party,
          products: [
            ContractProductPreset(
              name: 'PT 10회',
              serviceContent: '1:1 개인 트레이닝 50분',
              sessionCount: 10,
              sessionMinutes: 50,
              paidAmount: 1000000,
            ),
          ],
        ),
      );
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_load_preset')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_preset_PT 10회')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('contract_preset_hint')),
        findsOneWidget,
      );
      expect(gateway.savedProducts, isEmpty);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('앱 테마(${mode.name})에서 입력 글씨와 칸 배경의 대비가 충분하다', (tester) async {
        tester.view.physicalSize = const Size(800, 10000);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme(),
            darkTheme: darkTheme(),
            themeMode: mode,
            home: LessonContractFormPage(
              personalOwnerUid: 'trainer-a',
              gateway: _FakeGateway(settings: _readySettings),
              membersStream: _members,
              clock: () => DateTime(2026, 10, 20),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(
          find.byKey(const ValueKey('contract_form_period_end')),
        );
        final theme = Theme.of(context);
        final fill = theme.inputDecorationTheme.fillColor!;
        double contrast(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          final hi = la > lb ? la : lb;
          final lo = la > lb ? lb : la;
          return (hi + 0.05) / (lo + 0.05);
        }

        // 날짜 칸 글씨, 직접 입력 칸 글씨, 칸 이름(라벨), 칸 배경 모두 읽을 수 있어야 한다.
        final dateText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('contract_form_period_end')),
            matching: find.text('선택'),
          ),
        );
        final dateColor =
            DefaultTextStyle.of(
              tester.element(find.byWidget(dateText)),
            ).style.merge(dateText.style).color!;
        expect(contrast(dateColor, fill), greaterThan(4.5));
        final editable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('contract_form_product_name')),
            matching: find.byType(EditableText),
          ),
        );
        expect(contrast(editable.style.color!, fill), greaterThan(4.5));
        expect(
          contrast(theme.inputDecorationTheme.labelStyle!.color!, fill),
          greaterThan(3.0),
        );
      });
    }

    testWidgets('조건은 조항 문장의 빈칸에 직접 입력하고 슬라이더·스위치는 쓰지 않는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.text('제1조 예약 변경 및 취소'), findsOneWidget);
      expect(find.text('제2조 위약금 및 환불'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.byType(SegmentedButton<ContractTransferPolicy>),
        findsNothing,
      );
      // 빈칸에 값이 들어 있다.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('form_penalty_percent')),
            )
            .controller!
            .text,
        '10',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('form_late_minutes')))
            .controller!
            .text,
        '30',
      );
    });

    testWidgets('위약금 빈칸에 직접 입력하고 상한을 넘기면 저장을 막는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await _type(tester, 'form_penalty_percent', '5');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final terms =
          (gateway.drafts.single['content']! as Map<String, Object?>)['terms']!
              as Map;
      expect(terms['penaltyPercent'], 5);

      await _type(tester, 'form_penalty_percent', '15');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, hasLength(1));
      expect(find.text('위약금은 0~10%예요.'), findsWidgets);
    });

    testWidgets('빠른 선택 칩을 누르면 빈칸 값이 바뀐다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      // 빈칸을 누르기 전에는 빠른 선택이 보이지 않는다.
      expect(find.byKey(const ValueKey('form_deadline_12')), findsNothing);
      expect(find.byKey(const ValueKey('form_quick_bar')), findsNothing);
      await _focusBlank(tester, 'form_deadline_hours');
      expect(find.byKey(const ValueKey('form_quick_bar')), findsOneWidget);
      await _tapQuick(tester, 'form_deadline_12');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('form_deadline_hours')),
            )
            .controller!
            .text,
        '12',
      );
      await _focusBlank(tester, 'form_late_minutes');
      expect(find.byKey(const ValueKey('form_deadline_12')), findsNothing);
      await _tapQuick(tester, 'form_late_20');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('form_late_minutes')))
            .controller!
            .text,
        '20',
      );
      // 당일 취소 불가를 고르면 시간 빈칸이 사라지고 문장이 바뀐다.
      await _focusBlank(tester, 'form_deadline_hours');
      await _tapQuick(tester, 'form_deadline_same_day');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('form_deadline_hours')), findsNothing);
      expect(find.textContaining('당일 예약을 변경하거나 취소할 수 없으며'), findsOneWidget);
      // 다시 시간으로 지정하는 길이 있다.
      await tester.tap(find.byKey(const ValueKey('form_deadline_set_hours')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'form_deadline_hours'), '24');
    });

    testWidgets('양도를 불허로 바꾸면 수수료 칸이 사라진다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(
        find.byKey(const ValueKey('form_transfer_fee_type')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('form_transfer_policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('불허').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('form_transfer_fee_type')),
        findsNothing,
      );
      expect(find.textContaining('양도할 수 없습니다'), findsOneWidget);
    });

    testWidgets('횟수와 총액을 넣으면 회당 금액이, 회당 금액과 횟수를 넣으면 총액이 자동으로 채워진다', (
      tester,
    ) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      expect(_text(tester, 'contract_form_paid_amount'), '1,000,000');
      expect(_text(tester, 'contract_form_per_session'), '100,000');

      // 회당 금액을 고치면 총액이 따라 바뀐다.
      await _type(tester, 'contract_form_per_session', '90000');
      expect(_text(tester, 'contract_form_paid_amount'), '900,000');
      // 횟수를 바꿔도 마지막에 고친 회당 금액 기준으로 총액이 다시 계산된다.
      await _type(tester, 'contract_form_session_count', '20');
      expect(_text(tester, 'contract_form_paid_amount'), '1,800,000');
      // 총액을 다시 고치면 회당 금액이 계산된다(원 단위 반올림).
      await _type(tester, 'contract_form_paid_amount', '1000000');
      await _type(tester, 'contract_form_session_count', '3');
      expect(_text(tester, 'contract_form_per_session'), '333,333');
      expect(_text(tester, 'contract_form_paid_amount'), '1,000,000');
    });

    testWidgets('VAT 체크박스는 실결제금액 칸 안에 있고 전송 값에 반영된다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_form_paid_amount')),
          matching: find.byKey(const ValueKey('contract_form_vat')),
        ),
        findsOneWidget,
        reason: 'VAT 체크박스는 실결제금액 칸 오른쪽 끝(칸 안)에 있다',
      );
      expect(find.byKey(const ValueKey('contract_form_vat')), findsOneWidget);
      Color? vatColor() =>
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(const ValueKey('contract_form_vat')),
                  matching: find.text('VAT'),
                ),
              )
              .style
              ?.color;
      final off = vatColor();
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      // 금액이 입력돼 있으므로 VAT 처리 방법을 묻는다. 이미 포함된 금액으로 답한다.
      await tester.tap(find.byKey(const ValueKey('contract_form_vat_already')));
      await tester.pumpAndSettle();
      final on = vatColor();
      // 선택하면 글씨가 더 또렷해진다(회색 → 밝은 글씨).
      expect(on!.a, greaterThan(off!.a));
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final product =
          (gateway.drafts.single['content']!
                  as Map<String, Object?>)['product']!
              as Map;
      expect(product['vatIncluded'], true);
    });

    testWidgets('VAT를 체크하면 금액이 이미 VAT 포함인지, VAT를 더할지 묻는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '100000');
      expect(_text(tester, 'contract_form_per_session'), '10,000');

      // 이미 포함: 금액은 그대로, VAT 포함으로 표시된다.
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_vat_dialog')),
        findsOneWidget,
      );
      expect(find.text('이미 VAT가 포함된 금액이에요'), findsOneWidget);
      expect(find.text('100,000원 (VAT 포함) 그대로'), findsOneWidget);
      expect(find.text('VAT 10%를 더할게요'), findsOneWidget);
      expect(find.text('100,000원 + 10,000원 = 110,000원'), findsOneWidget);
      // 두 선택 카드는 같은 크기다.
      expect(
        tester.getSize(find.byKey(const ValueKey('contract_form_vat_already'))),
        tester.getSize(find.byKey(const ValueKey('contract_form_vat_add'))),
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_vat_already')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'contract_form_paid_amount'), '100,000');

      // 해제하면 묻지 않고 금액도 그대로.
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_vat_dialog')),
        findsNothing,
      );
      expect(_text(tester, 'contract_form_paid_amount'), '100,000');

      // VAT를 더함: 실결제금액이 110,000원이 되고 회당 금액도 다시 계산된다.
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_vat_add')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'contract_form_paid_amount'), '110,000');
      expect(_text(tester, 'contract_form_per_session'), '11,000');
    });

    testWidgets('비고(선택)를 적으면 저장 내용에 들어가고, 비우면 보내지 않는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract_form_remarks')),
      );
      await _type(tester, 'contract_form_remarks', '11월 50만원, 12월 50만원 분할 결제');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      var product =
          (gateway.drafts.last['content']! as Map<String, Object?>)['product']!
              as Map;
      expect(product['remarks'], '11월 50만원, 12월 50만원 분할 결제');

      await _type(tester, 'contract_form_remarks', '');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      product =
          (gateway.drafts.last['content']! as Map<String, Object?>)['product']!
              as Map;
      expect(product.containsKey('remarks'), isFalse);
    });

    testWidgets('유효기간 종료일 옆 없음 체크: 종료일 없이 저장되고 달력·기간 메뉴가 잠긴다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_form_period_end')),
          matching: find.byKey(const ValueKey('contract_form_no_expiry')),
        ),
        findsOneWidget,
        reason: '없음 체크는 종료일 칸 안(달력 아이콘 옆)에 있다',
      );
      expect(
        find.byKey(const ValueKey('contract_form_end_menu')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract_form_no_expiry')),
      );
      await tester.tap(find.byKey(const ValueKey('contract_form_no_expiry')));
      await tester.pumpAndSettle();
      expect(find.text('종료일 없음'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contract_form_end_menu')),
        findsNothing,
      );
      expect(find.textContaining('남은 횟수가 소멸하지 않습니다'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final product =
          (gateway.drafts.single['content']!
                  as Map<String, Object?>)['product']!
              as Map;
      expect(product['periodEnd'], '');
      expect(product['periodUnlimited'], true);

      // 체크를 풀면 종료일을 다시 고를 수 있다.
      await tester.tap(find.byKey(const ValueKey('contract_form_no_expiry')));
      await tester.pumpAndSettle();
      expect(find.text('종료일 없음'), findsNothing);
      expect(
        find.byKey(const ValueKey('contract_form_end_menu')),
        findsOneWidget,
      );
    });

    testWidgets('맨 아래 저장 버튼은 폰 내비게이션 바 위에 있어 눌러진다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      // 화면이 짧아 스크롤해야 하고, 아래 48dp는 내비게이션 바가 차지한다.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(bottom: 96);
      tester.view.viewPadding = const FakeViewPadding(bottom: 96);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractFormPage(
            personalOwnerUid: 'trainer-a',
            gateway: gateway,
            membersStream: _members,
            clock: () => DateTime(2026, 10, 20, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('contract_form_save'));
      await tester.dragUntilVisible(
        save,
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      // 맨 끝까지 내린다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(save).dy;
      // 논리 높이 600 중 아래 48은 내비게이션 바.
      expect(bottom, lessThanOrEqualTo(600 - 48));
    });

    testWidgets('VAT 창은 320dp 폭·큰 글씨에서도 넘침 없이 선택지가 한 줄씩 나온다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonContractFormPage(
            personalOwnerUid: 'trainer-a',
            gateway: gateway,
            membersStream: _members,
            clock: () => DateTime(2026, 10, 20, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '10000000');
      // 화면 안에 들어올 때까지 목록을 끌어 올린다.
      for (var i = 0; i < 20; i++) {
        final y =
            tester
                .getCenter(find.byKey(const ValueKey('contract_form_vat')))
                .dy;
        if (y > 80 && y < 560) break;
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      // 넘침(노랑·검정 줄무늬) 오류가 없어야 한다.
      expect(tester.takeException(), isNull);
      final already = tester.getSize(
        find.byKey(const ValueKey('contract_form_vat_already')),
      );
      final add = tester.getSize(
        find.byKey(const ValueKey('contract_form_vat_add')),
      );
      expect(already, add);
      // 카드 안 글자는 각각 한 줄이다(제목+설명 = 두 줄 높이).
      expect(already.height, lessThan(96));
    });

    testWidgets('저장할 때 필수 칸이 비어 있으면 그 칸으로 이동하고 커서를 놓는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      // 회원만 고르고 상품명은 비워 둔다.
      await tester.tap(find.byKey(const ValueKey('contract_form_pick_member')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_member_m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      TextField field(String key) =>
          tester.widget<TextField>(find.byKey(ValueKey<String>(key)));
      expect(field('contract_form_product_name').focusNode!.hasFocus, isTrue);

      // 상품명을 채우면 다음 빈 필수 칸(횟수)으로 커서가 간다.
      await _type(tester, 'contract_form_product_name', 'PT 10회');
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(field('contract_form_session_count').focusNode!.hasFocus, isTrue);
      expect(field('contract_form_product_name').focusNode!.hasFocus, isFalse);
    });

    testWidgets('조항 안 빈칸이 틀리면 그 빈칸에 커서를 놓는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('form_penalty_percent')),
      );
      await tester.pumpAndSettle();
      await _type(tester, 'form_penalty_percent', '15');
      // 입력 칸을 벗어나게 한 뒤 저장한다.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final penalty = tester.widget<TextField>(
        find.byKey(const ValueKey('form_penalty_percent')),
      );
      expect(penalty.focusNode!.hasFocus, isTrue);
      expect(gateway.drafts, isEmpty);
    });

    testWidgets('VAT 창에서 취소하면 체크도 금액도 바뀌지 않는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      final before = _text(tester, 'contract_form_paid_amount');
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_vat_cancel')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'contract_form_paid_amount'), before);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final product =
          (gateway.drafts.single['content']!
                  as Map<String, Object?>)['product']!
              as Map;
      expect(product.containsKey('vatIncluded'), false);
    });

    testWidgets('금액이 없을 때 VAT를 체크하면 묻지 않고 바로 체크된다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_vat')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_form_vat_dialog')),
        findsNothing,
      );
    });

    testWidgets('할인율 보기를 펼치면 정상가 대비 할인율이 나온다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _type(tester, 'contract_form_session_count', '10');
      await _type(tester, 'contract_form_paid_amount', '1000000');
      await tester.tap(find.byKey(const ValueKey('contract_form_discounted')));
      await tester.pump();
      await _type(tester, 'contract_form_list_price', '1500000');
      expect(
        find.byKey(const ValueKey('contract_form_discount_rate')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('contract_form_discount_toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('정상가 대비 33.3% 할인'), findsOneWidget);
    });

    testWidgets('고객카드 값을 누르면 누른 곳 근처에 안내 토스트가 뜬다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      // 화면에 고정 안내 문구는 없다.
      expect(find.textContaining('고객카드 기준'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('contract_form_member_phone_row')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('고객카드 기준입니다. 바꾸려면 회원카드에서 수정해 주세요.'),
        findsOneWidget,
      );
      await _flushToast(tester);
    });

    testWidgets('회원 선택은 아이콘 버튼이 아니라 선택 칸이고 고른 이름이 보인다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('회원 선택'), findsOneWidget);
      await _fillBasics(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contract_form_pick_member')),
          matching: find.text('홍회원'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('빠른 선택 막대는 입력을 마치면 사라진다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _focusBlank(tester, 'form_penalty_percent');
      expect(find.byKey(const ValueKey('form_quick_bar')), findsOneWidget);
      await _tapQuick(tester, 'form_penalty_5');
      expect(_text(tester, 'form_penalty_percent'), '5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('form_quick_bar')), findsNothing);
    });

    testWidgets('제1조에 취소 기한과 레슨 진행 불가 기준이 또한으로 이어지고 괄호·마감·지각 표현이 없다', (
      tester,
    ) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.textContaining('또한 레슨 시작시간'), findsOneWidget);
      expect(find.textContaining('취소 가능 시간이 지난 후에 취소하는 경우'), findsOneWidget);
      expect(find.textContaining('(지각)'), findsNothing);
      expect(find.textContaining('마감 이후'), findsNothing);
      // 조항 제목에는 괄호가 없다.
      expect(find.text('제1조 예약 변경 및 취소'), findsOneWidget);
      expect(find.text('제2조 위약금 및 환불'), findsOneWidget);
      expect(find.text('제3조 계약해지 환불 시 이용분 계산 기준'), findsOneWidget);
      expect(find.text('제4조 양도'), findsOneWidget);
      expect(find.text('제5조 기타 사항'), findsOneWidget);
      expect(find.text('제6조 특약'), findsOneWidget);
      // 안내 문구는 화면에 늘어놓지 않는다.
      expect(find.textContaining('카드수수료 공제는 계약서에 넣을 수 없습니다'), findsNothing);
    });

    testWidgets('모든 조항 문장의 글자 크기가 같다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      double? sizeOf(Finder finder) =>
          tester.widget<RichText>(finder.first).text.style?.fontSize;
      final first = sizeOf(
        find.ancestor(
          of: find.byKey(const ValueKey('form_deadline_hours')),
          matching: find.byType(RichText),
        ),
      );
      final second = sizeOf(
        find.ancestor(
          of: find.byKey(const ValueKey('form_penalty_percent')),
          matching: find.byType(RichText),
        ),
      );
      final third = sizeOf(
        find.descendant(
          of: find.byKey(const ValueKey('form_refund_basis_contract_unit')),
          matching: find.byType(RichText),
        ),
      );
      expect(first, isNotNull);
      expect(second, first);
      expect(third, first);
    });

    testWidgets('영업일 칸을 누르면 환불 문구 제한의 근거가 토스트로 뜬다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('form_refund_days_value')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('약관의 규제에 관한 법률 제9조 제1호'), findsOneWidget);
      expect(find.textContaining('고시 제2019-9호 제4조 제1항'), findsOneWidget);
      expect(find.textContaining('제5조 제1항'), findsOneWidget);
      expect(find.textContaining('환불불가 문구는 계약서에 넣을 수 없습니다'), findsOneWidget);
      // 원문에서 확인하지 못한 내용은 법 조항으로 안내하지 않는다.
      expect(find.textContaining('카드수수료'), findsNothing);
      expect(find.textContaining('3영업일'), findsNothing);
      await _flushToast(tester);
    });

    testWidgets('환급 영업일은 6개월(130영업일)까지 입력되고 그 이상은 막는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('form_refund_days_value')));
      await tester.pump(const Duration(milliseconds: 300));
      await _flushToast(tester);
      await tester.enterText(
        find.byKey(const ValueKey('form_refund_days_value')),
        '5',
      );
      await tester.pump(const Duration(milliseconds: 300));
      // 3영업일을 넘겨도 추가 안내 토스트는 없다.
      expect(find.textContaining('일반적인 기준'), findsNothing);
      await _flushToast(tester);
      await tester.enterText(
        find.byKey(const ValueKey('form_refund_days_value')),
        '130',
      );
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final terms =
          (gateway.drafts.single['content']! as Map<String, Object?>)['terms']!
              as Map;
      expect(terms['refundBusinessDays'], 130);
      expect(find.text('기본안과 다른 항목'), findsNothing);
      expect(find.byKey(const ValueKey('form_differences')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('form_refund_days_value')),
        '131',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.drafts, hasLength(1));
      expect(find.textContaining('1~130영업일'), findsWidgets);
    });

    testWidgets('머리말 미리보기 아이콘으로 문서 양식 미리보기를 연다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_preview_paper')),
        findsOneWidget,
      );
      expect(find.text('레슨 계약서'), findsOneWidget);
      expect(find.text('홍회원'), findsWidgets);
      expect(find.text('제1조  계약의 내용'), findsOneWidget);
      expect(
        find.textContaining('또한 레슨 시작시간 30분 이후는 레슨 진행이 불가하며'),
        findsOneWidget,
      );
    });

    testWidgets('당사자 정보가 없으면 미리보기 대신 안내한다', (tester) async {
      final gateway = _FakeGateway();
      await _pumpPage(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_form_preview')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('contract_preview_paper')),
        findsNothing,
      );
      await _flushToast(tester);
    });

    testWidgets('서비스 내용 입력 칸은 없고 계약서에는 자동 작성된 내용이 담긴다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(find.text('서비스 내용'), findsNothing);
      await _fillBasics(tester);
      await tester.tap(find.byKey(const ValueKey('contract_form_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      final product =
          (gateway.drafts.single['content']!
                  as Map<String, Object?>)['product']!
              as Map;
      expect(product['serviceContent'], 'PT 10회 (총 10회, 1회 50분)');
    });

    testWidgets('환불불가·카드수수료 안내를 화면에 늘어놓지 않는다', (tester) async {
      final gateway = _FakeGateway(settings: _readySettings);
      await _pumpPage(tester, gateway);
      expect(
        find.byKey(const ValueKey('contract_form_fixed_terms')),
        findsNothing,
      );
      expect(find.textContaining('카드수수료 공제'), findsNothing);
      expect(find.textContaining('환불불가'), findsNothing);
    });
  });
}
